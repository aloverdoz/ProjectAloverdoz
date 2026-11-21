## Выбор профессии новым игроком, вошедшим на сервер (у хозяина профессия выбирается в «Новой игре»).
extends RefCounted

const Menu = preload("res://scripts/menu.gd")


static func open(g) -> void:
	if g == null or not is_instance_valid(g):
		return
	var layer := CanvasLayer.new()
	layer.layer = 20
	g.add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var pan := UI.panel()
	# 1.1.16: окно выбора профессии полностью непрозрачное (как бы ни была настроена прозрачность окон)
	var psb: StyleBoxFlat = UI.theme().get_stylebox("panel", "PanelContainer").duplicate()
	psb.bg_color.a = 1.0
	pan.add_theme_stylebox_override("panel", psb)
	pan.set_anchors_preset(Control.PRESET_CENTER)
	layer.add_child(pan)
	var v := UI.vbox(8)
	pan.add_child(v)
	v.add_child(UI.title(DB.tx("pick_prof", "Выберите профессию"), 20))
	v.add_child(UI.small(DB.tx("pick_prof_hint", "Профессия даёт свои бонусы. Её можно выбрать один раз — при первом входе на этот сервер.")))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	var ids: Array = DB.data.professions.keys()
	ids.sort_custom(func(a, b): return int(DB.data.professions[a].get("order", 0)) < int(DB.data.professions[b].get("order", 0)))
	for id in ids:
		var p: Dictionary = DB.data.professions[id]
		var b := Button.new()
		b.custom_minimum_size = Vector2(200, 132)
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = str(p.get("desc", ""))
		var bv := UI.vbox(2)
		bv.set_anchors_preset(Control.PRESET_FULL_RECT)
		bv.offset_left = 8
		bv.offset_top = 6
		bv.offset_right = -8
		bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(bv)
		var hrow := UI.hbox(6)
		hrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hrow.add_child(UI.profession_icon(id, 40))
		var nl := UI.label(str(p.get("name", id)), 16, DB.color(p.get("color", "#ffffff")))
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hrow.add_child(nl)
		bv.add_child(hrow)
		var r := UI.rich(Menu._bonus_text(p.get("bonus", {})), 12)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bv.add_child(r)
		b.pressed.connect(func(): choose(g, str(id), layer))
		grid.add_child(b)
	pan.reset_size()
	pan.position = (g.get_viewport().get_visible_rect().size - pan.size) * 0.5


static func choose(g, id: String, layer: Node) -> void:
	if is_instance_valid(layer):
		layer.queue_free()
	if g == null or not is_instance_valid(g) or not DB.data.professions.has(id):
		return
	g.profession = id
	if g.hud != null and g.hud.has_method("refresh_prof_icon"):
		g.hud.refresh_prof_icon()
	g.notify("%s: %s" % [DB.tx("profession", "Профессия"), str(DB.data.professions[id].get("name", id))], Color(0.6, 0.9, 1))
	Net._self().send_my_state()   # хозяин сразу запоминает выбор
