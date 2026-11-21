class_name SavesUI
## Список ячеек сохранения: в главном меню («Загрузить») и в паузе («Сохранить», «Загрузить»).
## Рядом с каждым сохранением лежит маленький файл <ячейка>.meta.json — по нему список
## строится быстро, не читая всю карту.


static func slot_ids(with_auto := true) -> Array:
	var out := []
	if with_auto:
		out.append("autosave")
	for i in max(1, int(DB.menu("save_slots", 8))):
		out.append("save%d" % (i + 1))
	if with_auto:
		out.append_array(net_slots())   # 1.1.15: миры сетевых комнат — только для загрузки, сохранять поверх них нельзя
	return out


## 18: миры сетевых комнат (сохраняет хозяин, ячейка net_<комната>).
static func net_slots() -> Array:
	var out := []
	var d := DirAccess.open(DB.saves_dir())
	if d == null:
		return out
	for fn in d.get_files():
		if fn.begins_with("net_") and fn.ends_with(".json") and not fn.ends_with(".meta.json"):
			out.append(fn.get_basename())
	out.sort()
	return out


static func path(slot: String) -> String:
	return DB.saves_dir().path_join("%s.json" % slot)


static func exists(slot: String) -> bool:
	return FileAccess.file_exists(path(slot))


## Короткие сведения о сохранении: когда, сколько играли, день, уровень.
static func info(slot: String) -> Dictionary:
	if not exists(slot):
		return {}
	var m = DB.read_file(DB.saves_dir().path_join("%s.meta.json" % slot))
	var d: Dictionary = m if m is Dictionary else {}
	d["mtime"] = FileAccess.get_modified_time(path(slot))
	if not d.has("saved_at"):
		d["saved_at"] = Time.get_datetime_string_from_unix_time(int(d.mtime), true)
	return d


## Самое свежее сохранение (для кнопки «Продолжить»). "" — нет ни одного.
static func newest() -> String:
	var best := ""
	var bt := -1
	for s in slot_ids(true):
		if exists(s):
			var t := FileAccess.get_modified_time(path(s))
			if t > bt:
				bt = t
				best = s
	return best


static func delete(slot: String) -> void:
	DirAccess.remove_absolute(path(slot))
	var mp := DB.saves_dir().path_join("%s.meta.json" % slot)
	if FileAccess.file_exists(mp):
		DirAccess.remove_absolute(mp)


static func slot_name(slot: String) -> String:
	if slot == "autosave":
		return DB.tx("autosave", "Автосохранение")
	if slot.begins_with("net_"):
		return "Сетевой мир «%s»" % str(info(slot).get("room", slot.substr(4)))
	return "%s %s" % [DB.tx("slot", "Ячейка"), slot.substr(4)]


static func time_text(sec: float) -> String:
	var m := int(sec) / 60
	return "%d:%02d" % [m / 60, m % 60] if m >= 60 else "%d мин" % m


static func describe(d: Dictionary) -> String:
	var parts := [str(d.get("saved_at", "")).replace("T", " ").substr(0, 16)]
	if d.has("play_time"):
		parts.append("%s %s" % [DB.tx("st_time", "Время в игре").to_lower(), time_text(float(d.play_time))])
	if d.has("day"):
		parts.append("%s %d" % [DB.tx("day", "день"), int(d.day)])
	if d.has("level"):
		parts.append("ур. %d" % int(d.level))
	var pr := str(d.get("profession", ""))
	if pr != "" and DB.data.professions.has(pr):
		parts.append(str(DB.data.professions[pr].get("name", pr)))
	return " · ".join(parts)


## Построить список. mode = "save" или "load".
## on_pick(slot) вызывается после второго подтверждающего нажатия (если ячейка занята)
## или сразу (если пустая / загрузка).
static func build(parent: Control, mode: String, on_pick: Callable) -> void:
	UI.clear(parent)
	var any := false
	for s in slot_ids(mode == "load"):
		var have := exists(s)
		if mode == "load" and not have:
			continue
		any = true
		var row := UI.hbox(10)
		var col := UI.vbox(2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UI.label(slot_name(s), 16, UI.ACCENT if s == "autosave" else UI.TEXT))
		col.add_child(UI.small(describe(info(s)) if have else DB.tx("slot_empty", "Пустая ячейка")))
		row.add_child(col)
		var slot: String = s
		if mode == "save":
			var b := UI.button(DB.tx("btn_save", "Сохранить сюда"), func(): pass)
			b.pressed.connect(func():
				if have and not b.has_meta("sure"):
					b.set_meta("sure", true)
					b.text = DB.tx("overwrite_q", "Перезаписать?")
					return
				on_pick.call(slot))
			row.add_child(b)
		else:
			row.add_child(UI.button(DB.tx("btn_load", "Загрузить"), func(): on_pick.call(slot)))
		if have:
			var del := UI.button(DB.tx("btn_delete", "Удалить"), func(): pass)
			del.pressed.connect(func():
				if not del.has_meta("sure"):
					del.set_meta("sure", true)
					del.text = DB.tx("delete_q", "Удалить?")
					return
				delete(slot)
				build(parent, mode, on_pick))
			row.add_child(del)
		parent.add_child(row)
	if not any:
		parent.add_child(UI.small(DB.tx("no_saves", "Сохранений пока нет.")))


## Прочитать сохранение и запустить игру с ним (через экран загрузки).
static func start_from(tree: SceneTree, slot: String) -> bool:
	var d = DB.read_file(path(slot))
	if not d is Dictionary:
		return false
	DB.set_meta("new_game", {"profession": d.get("profession", "engineer"), "save": d, "map_mode": "save"})
	LoadingScreen.go(tree, "res://scenes/main.tscn")
	return true
