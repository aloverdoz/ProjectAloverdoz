class_name EdForm
extends VBoxContainer
## Форма для правки одного объекта (словаря) по описанию полей из EdSchema.
## Любая правка сразу меняет словарь и посылает сигнал changed.

signal changed

var obj: Dictionary
var fields: Array
var label_w := 230.0
var show_extra := true
var sub_name := ""          # запись списка: поля зависят от самой записи (EdSchema.sub_for)


static func make(o: Dictionary, f: Array, extra := true, lw := 230.0) -> EdForm:
	var e := EdForm.new()
	e.obj = o
	e.fields = f
	e.show_extra = extra
	e.label_w = lw
	e.add_theme_constant_override("separation", 5)
	e._build()
	return e


## Поля, от которых зависит состав формы (например, вид здания).
const REBUILD_ON := ["behavior"]
## Поля записи списка, от которых зависит её состав.
const SUB_REBUILD_ON := {"block": ["type", "event"], "cmd_action": ["do"], "mob_rule": ["if", "then"]}


func rebuild() -> void:
	for c in get_children():
		c.queue_free()
	if sub_name != "":
		fields = EdSchema.sub_for(sub_name, obj)
	_build()


func _emit() -> void:
	changed.emit()


func _build() -> void:
	var known := {}
	for f in fields:
		known[f[0]] = true
		add_child(_row(f))
	if show_extra:
		var extra := {}
		for k in obj:
			if not known.has(k) and k != "parts" and k != "emitters" and not str(k).begins_with("_"):
				extra[k] = obj[k]
		if not extra.is_empty():
			add_child(_section_label("Другие поля (JSON)", "Поля, для которых нет отдельного редактора. Правьте осторожно."))
			var te := TextEdit.new()
			te.text = JSON.stringify(extra, "  ")
			te.custom_minimum_size = Vector2(0, 110)
			te.text_changed.connect(func():
				var j = JSON.parse_string(te.text)
				if j is Dictionary:
					te.modulate = Color.WHITE
					for k in extra:
						if not j.has(k):
							obj.erase(k)
					for k in j:
						obj[k] = j[k]
					_emit()
				else:
					te.modulate = Color(1, 0.6, 0.6))
			add_child(te)


func _section_label(t: String, tip := "") -> Label:
	var l := UI.label(t, 15, UI.ACCENT)
	l.tooltip_text = tip
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	return l


func _row(f: Array) -> Control:
	var key: String = f[0]
	var kind: String = f[2]
	var tip: String = f[3] if f.size() > 3 else ""
	var big := kind.begins_with("list:") or kind.begins_with("group:") or kind.begins_with("amounts:") or kind == "bonus" or kind.begins_with("refs:") or kind.begins_with("files:") or kind == "text" or kind == "json"
	if big:
		var box := VBoxContainer.new()
		box.add_child(_section_label(f[1], tip))
		var inner := _editor(key, kind)
		var m := MarginContainer.new()
		m.add_theme_constant_override("margin_left", 16)
		m.add_child(inner)
		box.add_child(m)
		return box
	var h := HBoxContainer.new()
	var l := UI.label(f[1], 14)
	l.custom_minimum_size = Vector2(label_w, 0)
	l.tooltip_text = tip
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.add_child(l)
	var ed := _editor(key, kind)
	ed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ed.tooltip_text = tip
	h.add_child(ed)
	return h


func _setv(key: String, v) -> void:
	obj[key] = v
	_emit()


func _spin(v: float, is_int: bool, cb: Callable) -> SpinBox:
	var s := SpinBox.new()
	s.allow_greater = true
	s.allow_lesser = true
	s.min_value = -1000000
	s.max_value = 1000000
	s.step = 1.0 if is_int else 0.001
	s.custom_arrow_step = 1.0 if is_int else 0.05
	s.value = v
	s.select_all_on_focus = true
	s.custom_minimum_size = Vector2(72, 0)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(func(x): cb.call(int(x) if is_int else snappedf(x, 0.0001)))
	return s


## Флажки, которые в игре включены, пока их не выключили явно.
const DEFAULT_TRUE := ["buildable", "on_water", "blocks"]

func _editor(key: String, kind: String) -> Control:
	var cur = obj.get(key)
	var p := kind.split(":", true, 1)
	var base: String = p[0]
	var arg: String = p[1] if p.size() > 1 else ""
	match base:
		"str":
			var le := LineEdit.new()
			le.text = str(cur) if cur != null else ""
			le.text_changed.connect(func(t): _setv(key, t))
			return le
		"text":
			var te := TextEdit.new()
			te.text = str(cur) if cur != null else ""
			te.custom_minimum_size = Vector2(0, 64)
			te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
			te.text_changed.connect(func(): _setv(key, te.text))
			return te
		"strs":
			# список имён через запятую (кости хвоста и т.п.)
			var ls := LineEdit.new()
			ls.text = ", ".join(PackedStringArray(cur.map(func(x): return str(x)))) if cur is Array else ""
			ls.placeholder_text = "имя, имя, имя"
			ls.text_changed.connect(func(t):
				var arr: Array = []
				for x in t.split(","):
					if x.strip_edges() != "":
						arr.append(x.strip_edges())
				_setv(key, arr))
			return ls
		"int", "float":
			return _spin(float(cur) if cur != null else 0.0, base == "int", func(x): _setv(key, x))
		"bool":
			var c := CheckBox.new()
			if cur != null and not (cur is bool or cur is int or cur is float):
				push_warning("FORMBOOL %s = %s" % [key, str(cur)])
			c.button_pressed = bool(cur) if (cur is bool or cur is int or cur is float) else key in DEFAULT_TRUE
			c.focus_mode = Control.FOCUS_NONE
			c.toggled.connect(func(on): _setv(key, on))
			return c
		"color":
			var cp := ColorPickerButton.new()
			cp.color = DB.color(cur if cur != null else "#ffffff")
			cp.custom_minimum_size = Vector2(80, 28)
			cp.color_changed.connect(func(c): _setv(key, "#" + c.to_html(false)))
			return cp
		"vec3", "range2":
			var n := 3 if base == "vec3" else 2
			var arr: Array = cur.duplicate() if cur is Array else ([0, 0, 0] if n == 3 else [1, 1])
			while arr.size() < n:
				arr.append(0)
			var h := HBoxContainer.new()
			for i in n:
				var idx := i
				h.add_child(_spin(float(arr[i]), false, func(x):
					arr[idx] = x
					_setv(key, arr.duplicate())))
			return h
		"enum":
			var ob := OptionButton.new()
			ob.focus_mode = Control.FOCUS_NONE
			var table := EdSchema.enum_table(arg.substr(1)) if arg.begins_with("@") else {}
			var vals: PackedStringArray = PackedStringArray(table.keys()) if arg.begins_with("@") else arg.split("|")
			var sel := -1
			for i in vals.size():
				ob.add_item(str(table[vals[i]]) if table.has(vals[i]) else EdSchema.enum_label(vals[i]))
				if str(cur) == vals[i]:
					sel = i
			if sel < 0 and cur != null and str(cur) != "":
				ob.add_item(str(cur) + " (своё)")
				sel = vals.size()
			ob.select(max(sel, 0) if sel >= 0 or cur == null else 0)
			if sel < 0 and (cur == null or str(cur) == ""):
				ob.select(vals.find(""))
			ob.item_selected.connect(func(i):
				if i < vals.size():
					_setv(key, vals[i])
					if sub_name == "block" and key == "type":
						for dk in Blocks.DEFAULTS.get(vals[i], {}):
							if not obj.has(dk):
								obj[dk] = Blocks.DEFAULTS[vals[i]][dk]
					if key in REBUILD_ON or key in SUB_REBUILD_ON.get(sub_name, []):
						rebuild.call_deferred())
			return ob
		"ref":
			return _ref_button(arg, str(cur) if cur != null else "", func(id): _setv(key, id))
		"refs":
			return _refs_list(key, arg)
		"amounts":
			return _amounts(key, arg)
		"bonus":
			return _bonus(key)
		"list":
			return _list(key, arg)
		"group":
			if not obj.get(key) is Dictionary:
				obj[key] = {}
			var sf := EdSchema.sub(arg)
			if arg == "bld_params":
				sf = EdSchema.params_for(str(obj.get("behavior", "")), obj[key])
			var g := EdForm.make(obj[key], sf, true, label_w - 16)
			g.changed.connect(_emit)
			return g
		"file":
			return _file(key, arg)
		"files":
			return _files(key, arg)
	# json
	var tj := TextEdit.new()
	tj.text = JSON.stringify(cur, "  ") if cur != null else ""
	tj.custom_minimum_size = Vector2(0, 90)
	tj.text_changed.connect(func():
		var j = JSON.parse_string(tj.text)
		tj.modulate = Color.WHITE if j != null else Color(1, 0.6, 0.6)
		if j != null:
			_setv(key, j))
	return tj


func _ref_button(kind: String, id: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = EdPicker.label_of(kind, id)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(200, 0)
	b.clip_text = true
	b.pressed.connect(func():
		EdPicker.open_for(b, kind, func(nid):
			b.text = EdPicker.label_of(kind, nid)
			cb.call(nid)))
	return b


func _x_button(cb: Callable) -> Button:
	var x := UI.button("✕", cb, "Убрать")
	x.custom_minimum_size = Vector2(32, 0)
	return x


func _refs_list(key: String, kind: String) -> Control:
	var v := VBoxContainer.new()
	var arr: Array = obj.get(key, []) if obj.get(key) is Array else []
	obj[key] = arr
	for i in arr.size():
		var idx := i
		var h := HBoxContainer.new()
		h.add_child(_ref_button(kind, str(arr[i]), func(id):
			arr[idx] = id
			_emit()))
		h.add_child(_x_button(func():
			arr.remove_at(idx)
			_emit()
			_rebuild_row(v, key, "refs:" + kind)))
		v.add_child(h)
	v.add_child(UI.button("+ Добавить", func():
		EdPicker.open_for(v, kind, func(id):
			if id != "":
				arr.append(id)
				_emit()
				_rebuild_row(v, key, "refs:" + kind), false)))
	return v


func _amounts(key: String, kind: String) -> Control:
	var v := VBoxContainer.new()
	if not obj.get(key) is Dictionary:
		obj[key] = {}
	var d: Dictionary = obj[key]
	for id in d.keys():
		var k: String = id
		var h := HBoxContainer.new()
		var ic := UI.item_icon(k, 26) if kind == "items" else Control.new()
		h.add_child(ic)
		h.add_child(_ref_button(kind, k, func(nid):
			if nid != "" and nid != k:
				d[nid] = d[k]
				d.erase(k)
				_emit()
				_rebuild_row(v, key, "amounts:" + kind)))
		h.add_child(_spin(float(d[k]), true, func(x):
			d[k] = x
			_emit()))
		h.add_child(_x_button(func():
			d.erase(k)
			_emit()
			_rebuild_row(v, key, "amounts:" + kind)))
		v.add_child(h)
	v.add_child(UI.button("+ Добавить", func():
		EdPicker.open_for(v, kind, func(id):
			if id != "":
				d[id] = int(d.get(id, 0)) + 1
				_emit()
				_rebuild_row(v, key, "amounts:" + kind), false)))
	return v


func _bonus(key: String) -> Control:
	var v := VBoxContainer.new()
	if not obj.get(key) is Dictionary:
		obj[key] = {}
	var d: Dictionary = obj[key]
	var stats: Array = EdSchema.STATS.keys()
	for st in d.keys():
		var k: String = st
		var h := HBoxContainer.new()
		var ob := OptionButton.new()
		ob.focus_mode = Control.FOCUS_NONE
		for s in stats:
			ob.add_item(EdSchema.STATS[s])
		if not k in stats:
			ob.add_item(k)
		ob.select(stats.find(k) if k in stats else stats.size())
		ob.custom_minimum_size = Vector2(220, 0)
		ob.item_selected.connect(func(i):
			if i < stats.size() and stats[i] != k:
				d[stats[i]] = d[k]
				d.erase(k)
				_emit()
				_rebuild_row(v, key, "bonus"))
		h.add_child(ob)
		h.add_child(_spin(float(d[k]), false, func(x):
			d[k] = x
			_emit()))
		var hint := UI.small("")
		var upd := func():
			var x := float(d.get(k, 0))
			hint.text = ("%+d%%" % int(round(x * 100))) if absf(x) < 5 else ("%+d" % int(x))
		upd.call()
		h.add_child(hint)
		h.add_child(_x_button(func():
			d.erase(k)
			_emit()
			_rebuild_row(v, key, "bonus")))
		v.add_child(h)
	v.add_child(UI.button("+ Бонус или штраф", func():
		for s in stats:
			if not d.has(s):
				d[s] = 0.1
				break
		_emit()
		_rebuild_row(v, key, "bonus")))
	return v


## Значения новой записи списка, чтобы она сразу работала (а не «шанс 0»).
const LIST_DEFAULTS := {
	"drop": {"chance": 1.0, "min": 1, "max": 1, "on": "break"},
	"bonus_drop": {"chance": 0.05, "min": 1, "max": 1},
	"flora": {"zone": "any", "density": 0.3},
	"deposit": {"patches": 3, "size_min": 3.0, "size_max": 6.0, "near_start": 1, "color": "#c08050"},
	"wave_group": {"weight": 1.0, "from_wave": 1},
	"roam_group": {"weight": 1.0, "from_day": 1},
	"siege_boss": {"weight": 1.0, "from_day": 5},
	"dungeon_guard": {"n": 2, "from_day": 0},
	"npc_character": {"id": "new_char", "name": "Новый характер", "price": 1.0, "gift_k": 1.0, "touchy": 1.0, "refuse_below": -50, "flee": false},
	"emitter": {"kind": "puff", "when": "active", "rate": 1.0, "size": 1.0, "pos": [0, 2, 0]},
	"ui_elem": {"type": "label", "size": 16},
	"model_part": {"shape": "box", "size": [0.5, 0.5, 0.5], "pos": [0, 1, 0], "rot": [0, 0, 0], "color": "#ffa040", "mat": "paint"},
	"mob_rule": {"if": "sees_player", "n": 12.0, "then": "attack_player", "stop": true},
	"photo_filter": {"name": "Мой фильтр", "saturation": 1.0, "contrast": 1.0, "brightness": 1.0},
	"route_step": {"item": "", "n": 10, "from_tag": "A", "to_tag": "B", "keep": 0},
}


func _list(key: String, sub: String) -> Control:
	var v := VBoxContainer.new()
	if not obj.get(key) is Array:
		obj[key] = []
	var arr: Array = obj[key]
	var sf := EdSchema.sub(sub)
	for i in arr.size():
		var idx := i
		if not arr[i] is Dictionary:
			arr[i] = {}
		var sfi := EdSchema.sub_for(sub, arr[i])
		var pc := PanelContainer.new()
		var pv := VBoxContainer.new()
		pc.add_child(pv)
		var top := HBoxContainer.new()
		top.add_child(UI.small("№%d" % (i + 1)))
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(sp)
		top.add_child(UI.button("↑", func():
			if idx > 0:
				var t = arr[idx - 1]
				arr[idx - 1] = arr[idx]
				arr[idx] = t
				_emit()
				_rebuild_row(v, key, "list:" + sub), "Выше"))
		top.add_child(UI.button("⧉", func():
			arr.insert(idx + 1, arr[idx].duplicate(true))
			_emit()
			_rebuild_row(v, key, "list:" + sub), "Копия"))
		top.add_child(_x_button(func():
			arr.remove_at(idx)
			_emit()
			_rebuild_row(v, key, "list:" + sub)))
		pv.add_child(top)
		var f := EdForm.make(arr[i], sfi, false, label_w - 30)
		f.sub_name = sub
		f.changed.connect(_emit)
		pv.add_child(f)
		v.add_child(pc)
	v.add_child(UI.button("+ Добавить блок" if sub == "block" else ("+ Добавить действие" if sub == "cmd_action" else ("+ Добавить правило" if sub == "mob_rule" else ("+ Добавить шаг" if sub == "route_step" else ("+ Добавить деталь" if sub == "model_part" else "+ Добавить запись")))), func():
		var n := {}
		for fl in sf:
			if fl[2] == "float" or fl[2] == "int":
				n[fl[0]] = 1 if fl[0] in ["min", "max", "count", "weight", "from_wave", "from_day"] else 0
		n.merge(LIST_DEFAULTS.get(sub, {}).duplicate(true), true)
		if sub == "block":
			n = {"type": "produce"}
			n.merge(Blocks.DEFAULTS.produce.duplicate(true))
		elif sub == "cmd_action":
			n = {"do": "notify", "text": "Привет!"}
		elif sub == "mob_rule":
			n = LIST_DEFAULTS.mob_rule.duplicate(true)
		arr.append(n)
		_emit()
		_rebuild_row(v, key, "list:" + sub)))
	return v


const FILE_FILTERS := {
	"image": ["*.png, *.jpg, *.jpeg, *.webp ; Картинки"],
	"sound": ["*.wav, *.ogg, *.mp3 ; Звуки"],
	"glb": ["*.glb, *.gltf ; 3D-модели"],
	"map": ["*.json ; Карты"],
	"script": ["*.gd ; Скрипты GDScript"],
}
const FILE_DIRS := {"image": "textures", "sound": "sounds", "glb": "models", "map": "maps", "script": "mod_scripts"}


## Выбрать файл с диска: он копируется в папку игры, а в поле записывается путь внутри игры.
static func pick_file(parent: Node, kind: String, cb: Callable) -> void:
	var fd := FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.filters = PackedStringArray(FILE_FILTERS.get(kind, []))
	fd.title = "Выберите файл"
	if kind == "map":
		fd.current_dir = DB.edit_target.path_join("maps")
	parent.add_child(fd)
	fd.file_selected.connect(func(path: String):
		cb.call(import_file(path, kind))
		fd.queue_free())
	fd.canceled.connect(fd.queue_free)
	fd.popup_centered(Vector2i(900, 600))


static func import_file(path: String, kind: String) -> String:
	var sub: String = FILE_DIRS.get(kind, "files")
	var dst_dir := DB.edit_target.path_join(sub)
	if path.begins_with(DB.edit_target):
		return path.substr(DB.edit_target.length() + 1)
	DirAccess.make_dir_recursive_absolute(dst_dir)
	# файл с таким именем уже есть и он другой — не затираем, а даём новое имя
	var fname := path.get_file()
	var dst := dst_dir.path_join(fname)
	var k := 2
	while FileAccess.file_exists(dst) and FileAccess.get_md5(dst) != FileAccess.get_md5(path):
		fname = "%s_%d.%s" % [path.get_file().get_basename(), k, path.get_extension()]
		dst = dst_dir.path_join(fname)
		k += 1
	DirAccess.copy_absolute(path, dst)
	# .gltf ссылается на соседние файлы (.bin и текстуры) — копируем их тоже
	if path.get_extension().to_lower() == "gltf":
		var j = JSON.parse_string(FileAccess.get_file_as_string(path))
		if j is Dictionary:
			for key in ["buffers", "images"]:
				for e in j.get(key, []):
					var uri := str(e.get("uri", "")) if e is Dictionary else ""
					if uri != "" and not uri.begins_with("data:"):
						var srcf := path.get_base_dir().path_join(uri.uri_decode())
						var dstf := dst_dir.path_join(uri.uri_decode())
						DirAccess.make_dir_recursive_absolute(dstf.get_base_dir())
						DirAccess.copy_absolute(srcf, dstf)
	# старые картинки и модели из кэша больше не показываем
	ModelLib._tex.clear()
	ModelLib._glb.clear()
	ModelLib._glb_anim_names.clear()
	ModelLib._glb_states.clear()
	DB.revision += 1
	return sub.path_join(fname)


func _file(key: String, kind: String) -> Control:
	var h := HBoxContainer.new()
	var le := LineEdit.new()
	le.text = str(obj.get(key, ""))
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.text_changed.connect(func(t): _setv(key, t))
	h.add_child(le)
	h.add_child(UI.button("Выбрать…", func():
		pick_file(h, kind, func(rel):
			le.text = rel
			_setv(key, rel))))
	if kind == "sound":
		h.add_child(UI.button("▶", func(): EdAudio.play(le.text), "Прослушать"))
	return h


func _files(key: String, kind: String) -> Control:
	var v := VBoxContainer.new()
	if not obj.get(key) is Array:
		obj[key] = []
	var arr: Array = obj[key]
	for i in arr.size():
		var idx := i
		var h := HBoxContainer.new()
		var le := LineEdit.new()
		le.text = str(arr[i])
		le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		le.text_changed.connect(func(t):
			arr[idx] = t
			_emit())
		h.add_child(le)
		if kind == "sound":
			h.add_child(UI.button("▶", func(): EdAudio.play(str(arr[idx])), "Прослушать"))
		h.add_child(_x_button(func():
			arr.remove_at(idx)
			_emit()
			_rebuild_row(v, key, "files:" + kind)))
		v.add_child(h)
	v.add_child(UI.button("+ Добавить файл…", func():
		pick_file(v, kind, func(rel):
			arr.append(rel)
			_emit()
			_rebuild_row(v, key, "files:" + kind))))
	return v


## Перестроить один редактор поля после изменения его состава.
func _rebuild_row(old: Control, key: String, kind: String) -> void:
	var parent := old.get_parent()
	if parent == null:
		return
	var idx := old.get_index()
	var n := _editor(key, kind)
	parent.add_child(n)
	parent.move_child(n, idx)
	old.queue_free()
