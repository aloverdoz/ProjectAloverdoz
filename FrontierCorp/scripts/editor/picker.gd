class_name EdPicker
extends PopupPanel
## Окно выбора объекта из базы с поиском и иконками (предмет, модель, звук...).

signal picked(id: String)

var kind := ""
var search: LineEdit
var list: ItemList
var ids: Array = []


static func open_for(parent: Node, kind: String, cb: Callable, allow_empty := true) -> EdPicker:
	var p := EdPicker.new()
	p.kind = kind
	parent.add_child(p)
	p.picked.connect(cb)
	p._build(allow_empty)
	p.popup_centered(Vector2i(460, 520))
	p.search.grab_focus()
	p.popup_hide.connect(p.queue_free)
	return p


## Все варианты для вида ссылки: [id, подпись]
static func options(kind: String) -> Array:
	var out := []
	match kind:
		"stations":
			out.append(["hand", "В руках"])
			var seen := {}
			for id in DB.data.buildings:
				var b: Dictionary = DB.data.buildings[id]
				var st: String = str(b.get("params", {}).get("station", ""))
				if st != "" and not seen.has(st):
					seen[st] = true
					out.append([st, "Станция: " + str(b.get("name", st))])
				if b.get("behavior", "") == "crafter" and not seen.has(id):
					seen[id] = true
					out.append([id, "Машина: " + str(b.get("name", id))])
		_:
			var d: Dictionary = DB.data.get(kind, {})
			for id in d:
				var v = d[id]
				var nm: String = str(v.get("name", v.get("desc", id))) if v is Dictionary else str(id)
				out.append([id, nm])
	out.sort_custom(func(a, b): return a[1].naturalnocasecmp_to(b[1]) < 0)
	return out


static func label_of(kind: String, id: String) -> String:
	if id == "":
		return "— не выбрано —"
	for o in options(kind):
		if o[0] == id:
			return "%s  (%s)" % [o[1], id]
	return id + "  (нет в базе!)"


func _build(allow_empty: bool) -> void:
	theme = UI.theme()
	var v := VBoxContainer.new()
	add_child(v)
	search = LineEdit.new()
	search.placeholder_text = "Поиск..."
	search.text_changed.connect(func(_t): _fill(allow_empty))
	v.add_child(search)
	list = ItemList.new()
	list.custom_minimum_size = Vector2(440, 460)
	list.fixed_icon_size = Vector2i(28, 28)
	list.item_activated.connect(_choose)
	list.item_clicked.connect(func(i, _p, _b): _choose(i))
	v.add_child(list)
	search.text_submitted.connect(func(_t): if list.item_count > 0: _choose(0))
	_fill(allow_empty)


func _fill(allow_empty: bool) -> void:
	list.clear()
	ids.clear()
	var q := search.text.strip_edges().to_lower()
	if allow_empty and q == "":
		list.add_item("— не выбрано —")
		ids.append("")
	for o in options(kind):
		if q != "" and not (q in str(o[0]).to_lower() or q in str(o[1]).to_lower()):
			continue
		var icon: Texture2D = null
		if kind == "items":
			icon = Icons.get_icon("item:" + o[0])
		elif kind == "buildings":
			icon = Icons.get_icon("building:" + o[0])
		elif kind == "models":
			icon = Icons.get_icon("model:" + o[0])
		list.add_item("%s   ·  %s" % [o[1], o[0]], icon)
		ids.append(o[0])


func _choose(i: int) -> void:
	if i < 0 or i >= ids.size():
		return
	picked.emit(ids[i])
	hide()
