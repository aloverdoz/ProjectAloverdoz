class_name EdDataTab
extends HSplitContainer
## Вкладка «Данные»: все предметы, рецепты, здания, монстры, навыки, профессии, команды...
## Слева — разделы и список объектов, справа — форма. Правки сохраняются сами.

var ed                       # главный редактор
var type_list: ItemList
var obj_list: ItemList
var search: LineEdit
var right: VBoxContainer
var form_holder: ScrollContainer
var header: RichTextLabel
var cur_type := "items"
var cur_id := ""
var ids: Array = []
var _save_t := -1.0
var types: Array = []

const ORDER := ["items", "recipes", "buildings", "categories", "resources", "enemies", "waves", "skills", "attributes", "professions", "quests", "tech", "contracts", "events", "factions",
	"levels", "world", "settings", "options", "menu", "texts", "commands", "sounds", "music", "animations", "models"]


func _init(editor) -> void:
	ed = editor
	split_offset = 470
	var left := HBoxContainer.new()
	left.custom_minimum_size = Vector2(460, 0)
	add_child(left)
	type_list = ItemList.new()
	type_list.custom_minimum_size = Vector2(190, 0)
	type_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for t in ORDER:
		types.append(t)
		type_list.add_item(DB.TYPE_NAMES.get(t, t))
	type_list.item_selected.connect(func(i): select_type(types[i]))
	left.add_child(type_list)
	var lv := VBoxContainer.new()
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(lv)
	search = LineEdit.new()
	search.placeholder_text = "Поиск по названию, id или семейству"
	search.clear_button_enabled = true
	search.text_changed.connect(func(_t): _fill_objects())
	lv.add_child(search)
	obj_list = ItemList.new()
	obj_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	obj_list.fixed_icon_size = Vector2i(24, 24)
	obj_list.item_selected.connect(func(i): select_obj(ids[i]))
	lv.add_child(obj_list)
	var bh := HBoxContainer.new()
	lv.add_child(bh)
	bh.add_child(UI.button("Создать", _create, "Новый объект этого вида"))
	bh.add_child(UI.button("Копия", _duplicate, "Скопировать выбранный под новым id"))
	bh.add_child(UI.button("Удалить", _delete, "Удалить из игры (можно вернуть кнопкой «Как было»)"))
	bh.add_child(UI.button("Каталог…", func(): open_catalog(), "Сотни готовых предметов, зданий, растений и моделей: выберите и добавьте в свою игру"))
	right = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(right)
	header = UI.rich("", 15)
	header.mouse_filter = Control.MOUSE_FILTER_PASS
	right.add_child(header)
	var tools := HBoxContainer.new()
	right.add_child(tools)
	tools.add_child(UI.button("Переименовать id…", _rename, "Поменять внутреннее имя (ссылки на него тоже поменяются)"))
	tools.add_child(UI.button("Как было", _revert, "Убрать все ваши правки этого объекта"))
	tools.add_child(UI.button("Где используется", _usages, "Найти, кто ссылается на этот объект"))
	form_holder = ScrollContainer.new()
	form_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	form_holder.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(form_holder)


func _ready() -> void:
	Icons.baked.connect(func(_k): obj_list.queue_redraw())
	select_type(cur_type)


func _process(delta: float) -> void:
	if _save_t >= 0.0:
		_save_t -= delta
		if _save_t < 0.0:
			_save_now()


func is_single(t: String) -> bool:
	return t in DB.SINGLE_TYPES


func select_type(t: String) -> void:
	_flush()
	cur_type = t
	type_list.select(types.find(t))
	cur_id = ""
	search.text = ""
	search.editable = not is_single(t)
	obj_list.visible = not is_single(t)
	if is_single(t):
		_show_form()
	else:
		_fill_objects()
		if not ids.is_empty():
			select_obj(ids[0])
			obj_list.select(0)
		else:
			_show_form()


func _fill_objects() -> void:
	obj_list.clear()
	ids.clear()
	var d: Dictionary = DB.data.get(cur_type, {})
	var q := search.text.strip_edges().to_lower()
	var keys: Array = d.keys()
	keys.sort_custom(func(a, b): return str(_name(a)).naturalnocasecmp_to(str(_name(b))) < 0)
	for id in keys:
		var nm := _name(id)
		var fam := str(d[id].get("family", "")).to_lower() if d[id] is Dictionary else ""
		if q != "" and not (q in str(id).to_lower() or q in nm.to_lower() or q in fam):
			continue
		var icon: Texture2D = null
		match cur_type:
			"items": icon = Icons.get_icon("item:" + id)
			"buildings": icon = Icons.get_icon("building:" + id)
			"models": icon = Icons.get_icon("model:" + id)
		var src := DB.source_of(cur_type, id)
		var mark := "  ✎" if src.begins_with("project") or src.begins_with("dlc") else ""
		obj_list.add_item("%s%s" % [nm, mark], icon)
		obj_list.set_item_tooltip(obj_list.item_count - 1, "%s\nid: %s\nиз: %s" % [nm, id, _src_name(src)])
		ids.append(id)
		if id == cur_id:
			obj_list.select(obj_list.item_count - 1)


func _name(id) -> String:
	var o = DB.data.get(cur_type, {}).get(id, {})
	if o is Dictionary:
		return str(o.get("name", o.get("text", o.get("desc", o.get("ru", id)))))
	return str(id)


static func _src_name(src: String) -> String:
	if src.begins_with("core"):
		return "базовый контент"
	if src.begins_with("project"):
		return "ваша игра (изменено)"
	if src.begins_with("dlc"):
		return "дополнение " + src.substr(4)
	if src.begins_with("game"):
		return "собранная игра"
	return src


func select_obj(id: String) -> void:
	_flush()
	cur_id = id
	_show_form()


func _obj() -> Dictionary:
	if is_single(cur_type):
		return DB.data[cur_type]
	return DB.data[cur_type].get(cur_id, {})


func _show_form() -> void:
	for c in form_holder.get_children():
		c.queue_free()
	var o := _obj()
	var title := DB.TYPE_NAMES.get(cur_type, cur_type)
	if is_single(cur_type):
		header.text = "[b][color=#ffa040]%s[/color][/b]\nПравки сохраняются сами. Наведите на подпись — появится подсказка." % title
	elif cur_id == "":
		header.text = "[b][color=#ffa040]%s[/color][/b]\nПусто. Нажмите «Создать»." % title
		return
	else:
		header.text = "[b][color=#ffa040]%s[/color][/b]   id: [color=#7fdcff]%s[/color]   ·   %s" % [str(o.get("name", o.get("desc", cur_id))), cur_id, _src_name(DB.source_of(cur_type, cur_id))]
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_holder.add_child(v)
	if cur_type == "models":
		v.add_child(UI.button("Открыть в редакторе моделей", func(): ed.open_model(cur_id)))
	if cur_type == "options":
		v.add_child(UI.small("Меню настроек: разделы и пункты. Пункт: key, name, type (bool, slider, choice, key), default, min, max, step, options."))
	var fields := EdSchema.fields(cur_type)
	var f := EdForm.make(o, fields, true)
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	f.changed.connect(_on_changed)
	v.add_child(f)
	if cur_type == "items":
		_item_extras(v)
	if cur_type == "buildings":
		v.add_child(UI.small("Модель здания с дымом, анимациями и искрами настраивается во вкладке «Модели»."))


func _item_extras(v: VBoxContainer) -> void:
	# где этот предмет делается и откуда падает
	var made := []
	var used := []
	for rid in DB.data.recipes:
		var r: Dictionary = DB.data.recipes[rid]
		if r.get("out", {}).has(cur_id):
			made.append(r.get("name", rid))
		if r.get("in", {}).has(cur_id):
			used.append(r.get("name", rid))
	var drops := []
	for t in ["resources", "enemies"]:
		for id in DB.data[t]:
			for d in DB.data[t][id].get("drops", []):
				if d is Dictionary and d.get("item", "") == cur_id:
					drops.append("%s (%d%%)" % [DB.data[t][id].get("name", id), int(float(d.get("chance", 1)) * 100)])
	var txt := "[color=#8a93a3]Делается: %s\nНужен для: %s\nВыпадает: %s[/color]" % [", ".join(made) if made else "—", ", ".join(used) if used else "—", ", ".join(drops) if drops else "—"]
	v.add_child(UI.rich(txt, 13))


func _on_changed() -> void:
	_save_t = 0.6
	ed.set_status("Есть несохранённые правки…")


func flush() -> void:
	_flush()


func _flush() -> void:
	if _save_t >= 0.0:
		_save_t = -1.0
		_save_now()


func _save_now() -> void:
	if is_single(cur_type):
		DB.save_object(cur_type, "", DB.data[cur_type])
	elif cur_id != "" and DB.data[cur_type].has(cur_id):
		DB.save_object(cur_type, cur_id, DB.data[cur_type][cur_id])
	ed.set_status("Сохранено")
	ed.content_changed()


func _new_id(base: String) -> String:
	var b := DB.latin_id(base)
	if b == "":
		b = "new"
	var id := b
	var i := 2
	while DB.data[cur_type].has(id):
		id = "%s_%d" % [b, i]
		i += 1
	return id


func _create() -> void:
	if is_single(cur_type):
		return
	_flush()
	var id := _new_id("my_" + cur_type.trim_suffix("s"))
	DB.save_object(cur_type, id, EdSchema.blank(cur_type))
	cur_id = id
	_fill_objects()
	_show_form()
	ed.content_changed()


func _duplicate() -> void:
	if is_single(cur_type) or cur_id == "":
		return
	_flush()
	var id := _new_id(cur_id + "_copy")
	var o: Dictionary = DB.data[cur_type][cur_id].duplicate(true)
	if o.has("name"):
		o.name = str(o.name) + " (копия)"
	DB.save_object(cur_type, id, o)
	cur_id = id
	_fill_objects()
	_show_form()
	ed.content_changed()


func _delete() -> void:
	if is_single(cur_type) or cur_id == "":
		return
	var id := cur_id
	ed.confirm("Удалить «%s» из игры?" % _name(id), func():
		_save_t = -1.0
		DB.save_object(cur_type, id, null)
		cur_id = ""
		_fill_objects()
		if not ids.is_empty():
			select_obj(ids[0])
		else:
			_show_form()
		ed.content_changed())


func _revert() -> void:
	var id := cur_id
	ed.confirm("Вернуть «%s» как было? Ваши правки этого объекта пропадут." % (_name(id) if id != "" else DB.TYPE_NAMES.get(cur_type, cur_type)), func():
		_save_t = -1.0
		DB.revert_object(cur_type, id)
		if not is_single(cur_type) and not DB.data[cur_type].has(id):
			cur_id = ""
		# остальные вкладки держат старые данные — перечитываем всё, иначе следующая правка вернёт старое
		ed.refresh_all()
		ed.content_changed())


func _rename() -> void:
	if is_single(cur_type) or cur_id == "":
		return
	var old := cur_id
	ed.ask_text("Новый id (латиница, без пробелов):", old, func(nid: String):
		nid = nid.strip_edges().to_snake_case()
		if nid == "" or nid == old or DB.data[cur_type].has(nid):
			ed.set_status("Такой id не подходит или уже занят")
			return
		_flush()
		var o: Dictionary = DB.data[cur_type][old]
		DB.save_object(cur_type, nid, o)
		DB.save_object(cur_type, old, null)
		var n := _replace_refs(old, nid)
		cur_id = nid
		_fill_objects()
		_show_form()
		ed.set_status("id изменён, исправлено ссылок: %d. Готовые карты (вкладка «Карта») не меняются — проверьте их." % n)
		ed.content_changed())


## Заменить ссылки old -> nid только там, где поле по схеме ссылается на этот вид данных
## (ref:/refs:/amounts: нужного вида), и сохранить изменённое. Чужие совпадения (модель с тем же id,
## вид здания и т. п.) не трогаются.
func _replace_refs(old: String, nid: String) -> int:
	var count := 0
	for t in DB.DICT_TYPES:
		for id in DB.data[t].keys():
			var o = DB.data[t][id]
			if not o is Dictionary:
				continue
			var c := _swap_schema(o, EdSchema.fields(t), cur_type, old, nid)
			if c > 0:
				count += c
				DB.save_object(t, id, o)
	for t in DB.SINGLE_TYPES:
		var c2 := _swap_schema(DB.data[t], EdSchema.fields(t), cur_type, old, nid)
		if c2 > 0:
			count += c2
			DB.save_object(t, "", DB.data[t])
	return count


static func _swap_schema(o: Dictionary, fields: Array, rt: String, old: String, nid: String) -> int:
	var n := 0
	for f in fields:
		var key: String = f[0]
		var kind: String = f[2]
		if not o.has(key):
			continue
		var v = o[key]
		if kind == "ref:" + rt and str(v) == old:
			o[key] = nid
			n += 1
		elif kind == "refs:" + rt and v is Array:
			for i in v.size():
				if str(v[i]) == old:
					v[i] = nid
					n += 1
		elif kind == "amounts:" + rt and v is Dictionary and v.has(old):
			v[nid] = v[old]
			v.erase(old)
			n += 1
		elif kind.begins_with("list:") and v is Array:
			for e in v:
				if e is Dictionary:
					n += _swap_schema(e, EdSchema.sub_for(kind.substr(5), e), rt, old, nid)
		elif kind.begins_with("group:") and v is Dictionary:
			var sub := kind.substr(6)
			var sf := EdSchema.params_for(str(o.get("behavior", "")), v) if sub == "bld_params" else EdSchema.sub(sub)
			n += _swap_schema(v, sf, rt, old, nid)
	return n


func _usages() -> void:
	if cur_id == "":
		return
	var found := []
	for t in DB.DICT_TYPES:
		for id in DB.data[t]:
			if _contains(DB.data[t][id], cur_id) and not (t == cur_type and id == cur_id):
				found.append("%s: %s" % [DB.TYPE_NAMES.get(t, t), DB.data[t][id].get("name", id) if DB.data[t][id] is Dictionary else id])
	for t in DB.SINGLE_TYPES:
		if _contains(DB.data[t], cur_id):
			found.append(DB.TYPE_NAMES.get(t, t))
	ed.info("Где используется «%s»" % _name(cur_id), "\n".join(found) if not found.is_empty() else "Нигде. Объект можно спокойно удалить.")


static func _contains(o, id: String) -> bool:
	if o is Dictionary:
		for k in o:
			if str(k) == id or _contains(o[k], id):
				return true
	elif o is Array:
		for v in o:
			if _contains(v, id):
				return true
	elif o is String:
		return o == id
	return false


func refresh() -> void:
	if is_single(cur_type):
		_show_form()
	else:
		_fill_objects()
		if not DB.data[cur_type].has(cur_id):
			cur_id = ids[0] if not ids.is_empty() else ""
		_show_form()


func open(t: String, id := "") -> void:
	select_type(t)
	if id != "":
		select_obj(id)
		_fill_objects()


## ---------------------------------------------------------------- каталог готового контента
const CAT_TYPES := [["items", "Предметы"], ["buildings", "Здания"], ["resources", "Растения и камни"], ["models", "Модели"]]
var cat_dialog: AcceptDialog
var _cat_type := "items"
var _cat_group := ""


## Окно каталога: слева разделы, справа картинки. Нажатие — «Добавить в игру» (с моделью, рецептами и материалами).
func open_catalog(t := "") -> void:
	if t == "":
		t = cur_type if cur_type in ["items", "buildings", "resources", "models"] else "items"
	_cat_type = t
	_cat_group = ""
	if cat_dialog and is_instance_valid(cat_dialog):
		cat_dialog.queue_free()
	var d := AcceptDialog.new()
	cat_dialog = d
	d.title = "Каталог готового контента"
	d.ok_button_text = "Закрыть"
	var root := VBoxContainer.new()
	d.add_child(root)
	var top := HBoxContainer.new()
	root.add_child(top)
	var tabs := HBoxContainer.new()
	top.add_child(tabs)
	var s := LineEdit.new()
	s.placeholder_text = "Поиск по названию"
	s.clear_button_enabled = true
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(s)
	root.add_child(UI.label("Нажмите на объект, чтобы добавить его в свою игру. Всё нужное (модель, рецепты, материалы, станции) добавится вместе с ним, и дальше это можно менять как своё.", 13, UI.DIM))
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	var groups := ItemList.new()
	groups.custom_minimum_size = Vector2(240, 540)
	body.add_child(groups)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(900, 540)
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(sc)
	var grid := GridContainer.new()
	grid.columns = 6
	sc.add_child(grid)
	var fill_grid := func():
		for c in grid.get_children():
			c.queue_free()
		var src: Dictionary = DB.catalog_data().get(_cat_type, {})
		var q := s.text.strip_edges().to_lower()
		var n := 0
		for id in src:
			var o: Dictionary = src[id]
			var g := _cat_group_of(_cat_type, o)
			if q == "" and g != _cat_group:
				continue
			var nm := str(o.get("name", id))
			if q != "" and not (q in nm.to_lower() or q in str(id).to_lower()):
				continue
			n += 1
			if n > 240:
				break
			grid.add_child(_cat_button(_cat_type, id, o))
	var fill_groups := func():
		groups.clear()
		var src: Dictionary = DB.catalog_data().get(_cat_type, {})
		var cnt := {}
		for id in src:
			var g := _cat_group_of(_cat_type, src[id])
			cnt[g] = int(cnt.get(g, 0)) + 1
		var keys := cnt.keys()
		keys.sort()
		for g in keys:
			groups.add_item("%s (%d)" % [g, cnt[g]])
			groups.set_item_metadata(groups.item_count - 1, g)
		if _cat_group == "" and not keys.is_empty():
			_cat_group = keys[0]
		for i in groups.item_count:
			if groups.get_item_metadata(i) == _cat_group:
				groups.select(i)
		fill_grid.call()
	groups.item_selected.connect(func(i):
		_cat_group = groups.get_item_metadata(i)
		s.text = ""
		fill_grid.call())
	s.text_changed.connect(func(_t): fill_grid.call())
	for ct in CAT_TYPES:
		var tt: String = ct[0]
		var b := UI.button("%s (%d)" % [ct[1], DB.catalog_data().get(tt, {}).size()], func():
			_cat_type = tt
			_cat_group = ""
			fill_groups.call())
		tabs.add_child(b)
	add_child(d)
	d.confirmed.connect(d.queue_free)
	d.canceled.connect(d.queue_free)
	fill_groups.call()
	d.popup_centered()


func _cat_group_of(t: String, o: Dictionary) -> String:
	if t == "models":
		return str(o.get("category", "Разное")).trim_prefix("Каталог: ")
	return str(o.get("catalog", o.get("category", "Разное")))


func _cat_button(t: String, id: String, o: Dictionary) -> Button:
	var have: bool = DB.data.get(t, {}).has(id)
	var b := Button.new()
	b.custom_minimum_size = Vector2(140, 128)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = "%s\n%s%s" % [o.get("name", id), str(o.get("desc", "")), "\n(уже в вашей игре)" if have else ""]
	var bv := VBoxContainer.new()
	bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bv.set_anchors_preset(Control.PRESET_FULL_RECT)
	var tr := TextureRect.new()
	tr.texture = Icons.get_icon("cat:%s:%s" % [t, id] if t != "models" else "model:" + id)
	tr.custom_minimum_size = Vector2(0, 88)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bv.add_child(tr)
	var l := UI.label(("✓ " if have else "") + str(o.get("name", id)), 12)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bv.add_child(l)
	b.add_child(bv)
	b.pressed.connect(func(): _cat_ask(t, id, o))
	return b


func _cat_ask(t: String, id: String, o: Dictionary) -> void:
	if DB.data.get(t, {}).has(id):
		ed.confirm("«%s» уже есть в вашей игре. Открыть?" % o.get("name", id), func():
			if cat_dialog and is_instance_valid(cat_dialog):
				cat_dialog.hide()
			_cat_open(t, id))
		return
	ed.confirm("Добавить «%s» в игру?\n%s\nВместе с ним добавится всё нужное: модель, рецепты, материалы и станции." % [o.get("name", id), o.get("desc", "")], func():
		var added := add_catalog(t, id)
		if cat_dialog and is_instance_valid(cat_dialog):
			cat_dialog.hide()
		_cat_open(t, id)
		ed.set_status("Добавлено из каталога: %d объектов (%s)" % [added.size(), ", ".join(added.slice(0, 6)) + (" …" if added.size() > 6 else "")]))


## Добавить из каталога и обновить редактор. Возвращает список добавленного.
func add_catalog(t: String, id: String) -> Array:
	_flush()
	var added := DB.add_from_catalog(t, id)
	ed.content_changed()
	return added


func _cat_open(t: String, id: String) -> void:
	if t == "models":
		ed.open_model(id)
	else:
		ed.open_data(t, id)


## Проверка каталога: добавление тянет за собой модель, рецепт и материалы; повторно ничего не добавляется.
func _test_catalog() -> void:
	var c := DB.catalog_data()
	var a1 := add_catalog("items", "bread")
	var bread_ok: bool = DB.data.items.has("bread") and DB.data.models.has(DB.data.items.bread.model) and DB.data.recipes.has("cook_bread") and DB.data.items.has("flour") and DB.data.items.has("wheat")
	var a2 := add_catalog("buildings", "crusher_mk3")
	var b_ok: bool = DB.data.buildings.has("crusher_mk3") and DB.data.models.has("cb_crusher_mk3")
	for i in DB.data.buildings.crusher_mk3.cost:
		b_ok = b_ok and DB.data.items.has(i)
	var a3 := add_catalog("resources", "tree_maple_red")
	var r_ok: bool = DB.data.resources.has("tree_maple_red") and DB.data.models.has("cn_tree_maple_red")
	var again := add_catalog("items", "bread")
	DB.load_all()
	var persist: bool = DB.data.items.has("bread") and DB.data.buildings.has("crusher_mk3") and not DB.data.items.bread.has("catalog")
	var icon_ok: bool = ModelLib.model("cb_turret_laser_mk5").get("parts", []).size() > 20
	print("CATTEST items=", c.items.size(), " buildings=", c.buildings.size(), " resources=", c.resources.size(), " bread=", a1.size(), " crusher=", a2.size(),
		" tree=", a3.size(), " again=", again.size(), " ", "OK" if bread_ok and b_ok and r_ok and again.is_empty() and persist and icon_ok else "FAIL")


## Проверка исправлений: переименование не портит чужие поля; дополнение хранит только изменения.
func _test_qa() -> void:
	cur_type = "buildings"
	var o: Dictionary = DB.data.buildings.generator.duplicate(true)
	DB.save_object("buildings", "my_generator", o)
	DB.save_object("buildings", "generator", null)
	var n := _replace_refs("generator", "my_generator")
	var g: Dictionary = DB.data.buildings.my_generator
	var rename_ok: bool = g.behavior == "generator" and g.model == "generator"
	DB.revert_object("buildings", "my_generator")
	DB.revert_object("buildings", "generator")
	# дополнение
	var p := DB.project_path().path_join("dlc").path_join("qa_dlc")
	DB.ensure_dir_info(DB.project_path(), {"name": "QA", "version": "1.0"}, "project.json")
	DB.ensure_dir_info(p, {"name": "QA DLC", "version": "1.0"})
	DB.load_all()
	DB.edit_target = p
	var ch: Dictionary = DB.data.buildings.chest.duplicate(true)
	ch["name"] = "Сундук DLC"
	DB.save_object("buildings", "chest", ch)
	var wd: Dictionary = DB.data.world.duplicate(true)
	wd["day_length"] = 999
	DB.save_object("world", "", wd)
	var bj = DB.read_file(p.path_join("buildings.json"))
	var wj = DB.read_file(p.path_join("world.json"))
	var patch_ok: bool = bj.chest.get("_patch", false) and bj.chest.size() == 2 and wj.size() == 1 and int(wj.day_length) == 999
	DB.load_all()
	var reload_ok: bool = DB.data.buildings.chest.name == "Сундук DLC" and DB.data.buildings.chest.has("cost")
	DB.edit_target = DB.project_path()
	print("QATEST rename refs=", n, " ok=", rename_ok, " dlc_patch=", patch_ok, " reload=", reload_ok, " ",
		"OK" if rename_ok and patch_ok and reload_ok else "FAIL")


## Проверка: каждый раздел данных и каждый объект открывается в форме без ошибок (новые: события, группы НПС, НПС, блоки).
func _test_types() -> void:
	var n := 0
	var bad := []
	for t in ORDER:
		if not DB.data.has(t):
			bad.append(t)
			continue
		select_type(t)
		if is_single(t):
			_show_form()
			n += 1
			continue
		var keys: Array = DB.data[t].keys()
		for id in keys.slice(0, 300) + (["trader", "bandit", "infiltrator"] if t == "enemies" else []) + (["research_lab", "drone_port", "rover"] if t == "buildings" else []):
			if DB.data[t].has(id):
				select_obj(id)
				n += 1
	var blank_ok := true
	for t in ["events", "factions"]:
		blank_ok = blank_ok and not EdSchema.blank(t).is_empty() and not EdSchema.fields(t).is_empty()
	var blk_ok: bool = EdSchema.sub_for("block", {"type": "carrier"}).size() > 5 and EdSchema.sub_for("block", {"type": "research"}).size() > 3
	print("TYPESTEST forms=", n, " missing=", bad, " blanks=", blank_ok, " blocks=", blk_ok, " ", "OK" if bad.is_empty() and blank_ok and blk_ok and n > 200 else "FAIL")
