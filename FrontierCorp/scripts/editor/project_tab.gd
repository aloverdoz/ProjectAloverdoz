class_name EdProjectTab
extends ScrollContainer
## Вкладка «Проект и сборка»: название и версия игры, список игр, сборка готовой игры,
## открытие старой сборки для обновления, дополнения (DLC) и моды.

var ed
var body: VBoxContainer
var log_lbl: RichTextLabel


func _init(editor) -> void:
	ed = editor
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	add_child(body)


func _ready() -> void:
	refresh()


func _section(t: String, tip := "") -> VBoxContainer:
	var pc := PanelContainer.new()
	body.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	pc.add_child(v)
	v.add_child(UI.title(t, 18))
	if tip != "":
		var l := UI.small(tip)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	return v


func refresh() -> void:
	for c in body.get_children():
		c.queue_free()
	var balance := _section("Баланс колонии", "Пресет включает здания, рецепты, исследования, ресурсы, дронов и экономику.")
	var buttons := HFlowContainer.new()
	balance.add_child(buttons)
	for action in ["Сохранить пресет", "Загрузить пресет", "Деплой", "Создать промпт для ИИ"]:
		buttons.add_child(UI.button(action, func(): _balance_dialog(action)))
	# --- игра
	var g := _section("Ваша игра", "Название, версия и описание попадут в собранную игру. Версию поднимайте перед каждым обновлением.")
	var info := {"name": DB.project.get("name", DB.game_name()), "version": DB.project.get("version", "1.0"),
		"author": DB.project.get("author", ""), "desc": DB.project.get("desc", ""), "changelog": DB.project.get("changelog", ""),
		"icon": DB.project.get("icon", "")}
	var f := EdForm.make(info, [
		["name", "Название игры", "str", ""], ["version", "Версия", "str", "Например 1.0, 1.1, 2.0"],
		["author", "Автор / студия", "str", ""], ["desc", "Описание", "text", ""],
		["changelog", "Что нового в этой версии", "text", "Список изменений для игроков"],
		["icon", "Иконка игры (PNG)", "file:image", ""]], false)
	f.changed.connect(func():
		DB.save_project_info(info)
		ed.set_status("Сохранено")
		ed._update_title())
	g.add_child(f)
	var vb := HBoxContainer.new()
	g.add_child(vb)
	vb.add_child(UI.button("Версия +0.1", func():
		var v := str(info.version).split(".")
		var major := int(v[0]) if v.size() > 0 else 1
		var minor := int(v[1]) if v.size() > 1 else 0
		info.version = "%d.%d" % [major, minor + 1]
		DB.save_project_info(info)
		refresh()
		ed._update_title(), "Поднять номер версии для обновления"))
	vb.add_child(UI.button("Версия +1.0", func():
		var v := str(info.version).split(".")
		info.version = "%d.0" % (int(v[0]) + 1)
		DB.save_project_info(info)
		refresh()
		ed._update_title(), "Большое обновление"))
	# --- сборка
	var b := _section("Собрать игру", "Получится папка с готовой игрой без редактора: её можно выкладывать в Steam или отдавать друзьям. Сборки лежат в папке builds рядом с редактором.")
	var bh := HBoxContainer.new()
	b.add_child(bh)
	bh.add_child(UI.button("Собрать игру", ask_build, "Собрать готовую игру текущей версии"))
	bh.add_child(UI.button("Открыть папку сборок", func(): OS.shell_open(DB.builds_dir())))
	bh.add_child(UI.button("Открыть старую сборку…", _open_build, "Загрузить уже собранную игру, чтобы делать обновление"))
	if DB.runtime_exe() == "":
		var w := UI.rich("[color=#ff6b5a]Не найден движок игры (папка runtime рядом с редактором). Без него сборка не получится — распакуйте архив редактора целиком.[/color]", 13)
		b.add_child(w)
	log_lbl = UI.rich("", 13)
	b.add_child(log_lbl)
	# --- что правим
	var t := _section("Что сейчас редактируется", "Правки записываются в выбранное место: в саму игру или в дополнение. Так дополнение хранит только своё.")
	var th := HBoxContainer.new()
	t.add_child(th)
	var ob := OptionButton.new()
	ob.focus_mode = Control.FOCUS_NONE
	var targets := [["Игра «%s»" % DB.game_name(), DB.project_path()]]
	for d in DB.dlcs:
		targets.append(["Дополнение «%s»" % d.name, d.path])
	var mods_all: Array = DB._scan(DB.mods_dir(), "mod")
	for m in mods_all:
		targets.append(["Мод «%s»" % m.name, m.path])
	for i in targets.size():
		ob.add_item(targets[i][0])
		if targets[i][1] == DB.edit_target:
			ob.select(i)
	ob.item_selected.connect(func(i):
		ed.flush_all()
		DB.edit_target = targets[i][1]
		DB.load_all()
		ed.refresh_all()
		ed.set_status("Теперь правки идут в: " + targets[i][0])
		ed._update_title())
	th.add_child(ob)
	# --- дополнения
	var dl := _section("Дополнения (DLC)", "Дополнение — отдельный пакет с новыми предметами, зданиями, монстрами и картами. Игрок кладёт файл в папку dlc собранной игры.")
	for d in DB.dlcs:
		var row := HBoxContainer.new()
		row.add_child(UI.label("%s  v%s" % [d.name, d.version], 15))
		var did: String = d.id
		row.add_child(UI.button("Править", func():
			ed.flush_all()
			DB.edit_target = d.path
			DB.load_all()
			ed.refresh_all()
			ed._update_title()
			ed.set_status("Правки идут в дополнение " + str(d.name))
			refresh()))
		row.add_child(UI.button("Название…", func():
			ed.ask_text("Название дополнения:", str(d.name), func(nm: String):
				if nm.strip_edges() != "":
					DB.update_addon_info(d.path, {"name": nm.strip_edges()})
					DB.load_all()
					refresh())))
		row.add_child(UI.button("Версия +0.1", func():
			DB.update_addon_info(d.path, {"version": DB.bump_version(str(d.version))})
			DB.load_all()
			refresh(), "Поднять версию дополнения перед новой сборкой"))
		row.add_child(UI.button("Собрать файл дополнения", func(): _log(DB.build_dlc(did))))
		dl.add_child(row)
	dl.add_child(UI.button("+ Новое дополнение", func():
		ed.ask_text("Название дополнения:", "Новое дополнение", func(nm: String):
			var id := DB.make_id(nm)
			if id == "":
				ed.set_status("Название не может быть пустым")
				return
			if DirAccess.dir_exists_absolute(DB.project_path().path_join("dlc").path_join(id)):
				ed.set_status("Дополнение «%s» уже есть — выберите его в списке или придумайте другое название" % nm)
				return
			ed.flush_all()
			var p := DB.project_path().path_join("dlc").path_join(id)
			DB.ensure_dir_info(DB.project_path(), {"name": DB.game_name(), "version": DB.game_version()}, "project.json")
			DB.ensure_dir_info(p, {"name": nm, "version": "1.0", "author": DB.project.get("author", ""), "desc": ""})
			DB.load_all()
			DB.edit_target = p
			ed.refresh_all()
			ed.set_status("Создано дополнение «%s». Все правки теперь идут в него." % nm))))
	# --- проекты
	var pr := _section("Мои игры", "Можно вести несколько игр. Каждая хранится в папке projects рядом с редактором.")
	var ph := HBoxContainer.new()
	pr.add_child(ph)
	var po := OptionButton.new()
	po.focus_mode = Control.FOCUS_NONE
	var plist := DB.list_projects()
	if not DB.project_id in plist:
		plist.push_front(DB.project_id)
	for i in plist.size():
		po.add_item(plist[i])
		if plist[i] == DB.project_id:
			po.select(i)
	ph.add_child(po)
	ph.add_child(UI.button("Открыть", func():
		ed.flush_all()
		DB.open_project(plist[po.selected])
		DB.use_mods = false
		DB.load_all()
		ed.refresh_all()))
	ph.add_child(UI.button("+ Новая игра", func():
		ed.ask_text("Название новой игры:", "Моя игра", func(nm: String):
			var id := DB.make_id(nm)
			if id == "":
				ed.set_status("Название не может быть пустым")
				return
			if DirAccess.dir_exists_absolute(DB.project_path(id)):
				ed.set_status("Игра «%s» уже есть — откройте её в списке или придумайте другое название" % nm)
				return
			ed.flush_all()
			DB.ensure_dir_info(DB.project_path(id), {"name": nm, "version": "1.0"}, "project.json")
			DB.open_project(id)
			DB.use_mods = false
			DB.load_all()
			ed.refresh_all()
			ed.set_status("Создана игра «%s» на основе базового контента" % nm))))
	# --- моды
	var md := _section("Моды", "Моды делают игроки. Здесь можно сделать мод для своей же игры и упаковать его в zip.")
	for m in mods_all:
		var row := HBoxContainer.new()
		row.add_child(UI.label("%s  v%s" % [m.name, m.version], 15))
		var mid: String = m.id
		row.add_child(UI.button("Править", func():
			ed.flush_all()
			DB.edit_target = m.path
			DB.load_all()
			ed.refresh_all()
			ed._update_title()
			refresh()))
		row.add_child(UI.button("Версия +0.1", func():
			DB.update_addon_info(m.path, {"version": DB.bump_version(str(m.version))})
			refresh()))
		row.add_child(UI.button("Упаковать в zip", func(): _log(DB.pack_mod(mid))))
		md.add_child(row)
	md.add_child(UI.button("+ Новый мод", func():
		ed.ask_text("Название мода:", "Мой мод", func(nm: String):
			var id := DB.make_id(nm)
			if id == "":
				ed.set_status("Название не может быть пустым")
				return
			if DirAccess.dir_exists_absolute(DB.mods_dir().path_join(id)):
				ed.set_status("Мод «%s» уже есть — выберите его в списке или придумайте другое название" % nm)
				return
			ed.flush_all()
			DB.ensure_dir_info(DB.mods_dir().path_join(id), {"name": nm, "version": "1.0", "author": "", "desc": ""})
			DB.edit_target = DB.mods_dir().path_join(id)
			DB.load_all()
			ed.refresh_all()
			ed._update_title())))
	md.add_child(UI.button("Открыть папку модов", func(): OS.shell_open(DB.mods_dir())))


func _log(r: Dictionary) -> void:
	if log_lbl == null:
		return
	log_lbl.text = ("[color=#7dff9a]%s[/color]" if r.get("ok", false) else "[color=#ff6b5a]%s[/color]") % r.get("msg", "")
	ed.set_status(r.get("msg", ""))
	if r.get("ok", false) and r.has("path"):
		var p: String = r.path
		ed.confirm(str(r.msg) + "\n\nОткрыть папку?", func(): OS.shell_open(p if DirAccess.dir_exists_absolute(p) else p.get_base_dir()))


func ask_build() -> void:
	ed.flush_all()
	var out := DB.builds_dir().path_join("%s_v%s" % [DB.game_name().validate_filename().replace(" ", "_"), DB.game_version()])
	if DirAccess.dir_exists_absolute(out):
		ed.confirm("Сборка версии %s уже есть и будет заменена.\nЧтобы сохранить старую (для обновлений), сначала нажмите «Версия +0.1».\n\nЗаменить?" % DB.game_version(), _ask_build_text)
		return
	_ask_build_text()


func _ask_build_text() -> void:
	ed.ask_text("Что нового в версии %s? (увидят игроки)" % DB.game_version(), str(DB.project.get("changelog", "")), func(t: String):
		DB.save_project_info({"changelog": t})
		_log(DB.build_game(t)), true)


func _open_build() -> void:
	var fd := FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.current_dir = DB.builds_dir()
	fd.title = "Выберите папку собранной игры"
	add_child(fd)
	fd.dir_selected.connect(func(dir: String):
		ed.flush_all()
		var r := DB.open_build(dir)
		DB.use_mods = false
		DB.load_all()
		ed.refresh_all()
		_log(r)
		fd.queue_free())
	fd.canceled.connect(fd.queue_free)
	fd.popup_centered(Vector2i(900, 600))


## Проверка сборки: игра с правкой модели, дополнение с новым предметом, сборка и открытие сборки.
func _test_build() -> void:
	var made_runtime := false
	if DB.runtime_exe() == "":
		DirAccess.make_dir_recursive_absolute(DB.base_dir().path_join("runtime"))
		var fa := FileAccess.open(DB.base_dir().path_join("runtime/Game.exe"), FileAccess.WRITE)
		fa.store_string("dummy runtime")
		fa.close()
		made_runtime = true
	DB.save_project_info({"name": "Test Game", "version": "1.2"})
	DB.save_object("models", "my_test_model", {"name": "Тест", "parts": [{"shape": "box", "size": [1, 1, 1], "pos": [0, 0.5, 0], "color": "#ff0000"}]})
	var p := DB.project_path().path_join("dlc").path_join("test_dlc")
	DB.ensure_dir_info(p, {"name": "Тестовое DLC", "version": "1.0"})
	DB.load_all()
	DB.edit_target = p
	DB.save_object("items", "dlc_gem", {"name": "Самоцвет DLC", "color": "#40ffd0", "stack": 50})
	DB.edit_target = DB.project_path()
	var r := DB.build_game("Проверка")
	print("BUILD game ", r)
	var d := DB.build_dlc("test_dlc")
	print("BUILD dlc ", d)
	if r.ok and d.ok:
		DirAccess.copy_absolute(d.path, str(r.path).path_join("dlc").path_join(str(d.path).get_file()))
	var o := DB.open_build(r.path)
	print("BUILD open ", o, " project=", DB.project_id, " has_model=", DB.data.models.has("my_test_model"), " dlcs=", DB.dlcs.map(func(x): return x.id))
	if made_runtime:
		DirAccess.remove_absolute(DB.base_dir().path_join("runtime/Game.exe"))
		DirAccess.remove_absolute(DB.base_dir().path_join("runtime"))

func _balance_dialog(action: String) -> void:
	ed.flush_all()
	var fd := FileDialog.new()
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.title = action
	fd.file_mode = FileDialog.FILE_MODE_OPEN_DIR if action == "Деплой" else (FileDialog.FILE_MODE_OPEN_FILE if action == "Загрузить пресет" else FileDialog.FILE_MODE_SAVE_FILE)
	if fd.file_mode != FileDialog.FILE_MODE_OPEN_DIR:
		fd.add_filter("*.txt" if action == "Создать промпт для ИИ" else "*.json")
		if fd.file_mode == FileDialog.FILE_MODE_SAVE_FILE:
			fd.current_file = "Frontier-balance.txt" if action == "Создать промпт для ИИ" else "Frontier-balance.json"
	var selected := func(path: String):
		var service := preload("res://scripts/balance_preset.gd")
		var preset := service.capture(DB.data)
		var error := ""
		match action:
			"Деплой":
				error = service.deploy(path, preset)
			"Загрузить пресет":
				var incoming = JSON.parse_string(FileAccess.get_file_as_string(path))
				error = service.issue(incoming)
				if error == "":
					for table in service.TABLES:
						DB.data[table] = incoming.tables[table].duplicate(true)
					DB.revision += 1
					ed.refresh_all()
			_:
				error = service.issue(preset)
				if error == "":
					var content := service.prompt(preset) if action == "Создать промпт для ИИ" else JSON.stringify(preset, "\t")
					if service.write_text(path, content) != OK:
						error = "Ошибка записи"
		ed.set_status(error if error != "" else action + " · " + path)
		fd.queue_free()
	fd.file_selected.connect(selected)
	fd.dir_selected.connect(selected)
	fd.canceled.connect(fd.queue_free)
	add_child(fd)
	fd.popup_centered(Vector2i(900, 600))
