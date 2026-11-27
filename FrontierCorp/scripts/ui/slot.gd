class_name Slot
extends Panel
## Ячейка инвентаря: показывает предмет, перетаскивается мышью.
## Перетащить — переложить; с зажатым Ctrl — половину стака.
## Shift+клик — быстро переложить в другое открытое окно; ПКМ — использовать (съесть, выпить).

var inv: Inventory
var index := 0
var hud
var hotkey := ""
var shortcut := false
var selected := false
var _shown := ""
var _icon: Control
var _count: Label
var _dur: ProgressBar
var _key: Label
var _style: StyleBoxFlat
var _style_sel: StyleBoxFlat
var _style_b: StyleBoxFlat


func setup(p_inv: Inventory, i: int, p_hud, size := 54.0) -> void:
	inv = p_inv
	index = i
	hud = p_hud
	custom_minimum_size = Vector2(size, size)
	_style = StyleBoxFlat.new()
	_style.bg_color = Color("#182f36")
	_style.border_color = Color(1, 1, 1, 0.09)
	_style.set_border_width_all(1)
	_style.border_width_top = 2          # тень сверху — ячейка выглядит «утопленной»
	_style.border_color = Color("#38535b")
	_style.set_corner_radius_all(3)
	_style.shadow_color = Color(1, 1, 1, 0.04)
	_style.shadow_size = 1
	_style.shadow_offset = Vector2(0, 1)
	_style_sel = _style.duplicate()
	_style_sel.border_color = UI.ACCENT
	_style_sel.set_border_width_all(2)
	_style_sel.bg_color = Color("#25524f")
	_style_b = _style.duplicate()
	_style_b.bg_color = Color(0.08, 0.14, 0.2, 0.92)
	_style_b.border_color = Color(0.35, 0.65, 0.95, 0.6)
	add_theme_stylebox_override("panel", _style)
	_count = UI.label("", 13)
	_count.add_theme_color_override("font_outline_color", Color.BLACK)
	_count.add_theme_constant_override("outline_size", 4)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_count.set_anchors_preset(Control.PRESET_FULL_RECT)
	_count.offset_right = -4
	_count.offset_bottom = -1
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_count)
	_key = UI.label("", 11, UI.DIM)
	_key.position = Vector2(4, 1)
	_key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_key)
	_dur = UI.bar(null, Color(0.4, 0.9, 0.4), 4)
	_dur.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_dur.offset_left = 5
	_dur.offset_right = -5
	_dur.offset_top = -7
	_dur.offset_bottom = -3
	_dur.visible = false
	add_child(_dur)
	mouse_filter = Control.MOUSE_FILTER_STOP


## Здание, закреплённое в этой ячейке панели быстрого доступа ("" — нет).
func hot_build() -> String:
	if not shortcut or hud == null or hud.game == null or inv != hud.game.player.inv:
		return ""
	return str(hud.game.player.hot_builds.get(index, ""))


func refresh() -> void:
	var slot_index: int = hud.game.player.hot_slot(index) if shortcut else index
	var s = inv.slots[slot_index] if slot_index >= 0 and slot_index < inv.size() else null
	var hb := hot_build() if s == null else ""
	var key := ("b:" + hb if hb != "" else "") if s == null else "%s|%d|%s|%s" % [s.id, s.n, s.get("dur", -1), DB.is_known(s.id)]
	add_theme_stylebox_override("panel", _style_sel if selected else (_style_b if hb != "" else _style))
	_key.text = hotkey
	if key == _shown:
		return
	_shown = key
	if _icon:
		_icon.queue_free()
		_icon = null
	if s == null:
		_count.text = ""
		_dur.visible = false
		tooltip_text = ""
		if hb != "":
			_icon = UI.building_icon(hb, int(custom_minimum_size.x) - 8)
			_icon.position = Vector2(4, 4)
			_icon.modulate = Color(1, 1, 1, 0.9)
			_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(_icon)
			move_child(_icon, 0)
			_count.text = ""
			tooltip_text = "Постройка: %s\nКлавиша или клик — строить. ПКМ — убрать из панели." % DB.building(hb).get("name", hb)
		return
	_icon = UI.item_icon(s.id, int(custom_minimum_size.x) - 8)
	_icon.position = Vector2(4, 4)
	add_child(_icon)
	move_child(_icon, 0)
	_count.text = str(s.n) if s.n != 1 else ""
	var maxd := float(DB.item(s.id).get("durability", 0))
	_dur.visible = s.has("dur") and maxd > 0
	if _dur.visible:
		_dur.max_value = maxd
		_dur.value = float(s.dur)
	tooltip_text = UI.item_tip(s.id, s.n)


func _get_drag_data(_pos: Vector2):
	if shortcut and hud.game.player.hot_slot(index) >= 0:
		var id: String = hud.game.player.hot_items[index]
		set_drag_preview(UI.item_icon(id, 44))
		return {"shortcut_item": id, "from": index}
	var s = null if shortcut else inv.slots[index]
	if s == null:
		var hb := hot_build()
		if hb != "":
			var bp := UI.building_icon(hb, 44)
			set_drag_preview(bp)
			return {"build": hb, "from": index}
		return null
	var half: bool = (Input.is_key_pressed(KEY_CTRL) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)) and s.n > 1 and bool(DB.setting("split_stacks", true))
	var prev := UI.item_icon(s.id, 44)
	prev.modulate.a = 0.85
	set_drag_preview(prev)
	return {"inv": inv, "index": index, "half": half}


func _can_drop_data(_pos: Vector2, d) -> bool:
	if not d is Dictionary:
		return false
	if d.has("build") or d.has("shortcut_item"):
		return shortcut
	return d.has("inv") and (not shortcut or d.inv == hud.game.player.inv)


func _drop_data(_pos: Vector2, d) -> void:
	if d.has("build"):
		hud.pin_build(d.build, index, int(d.get("from", -1)))
	elif shortcut:
		var p = hud.game.player
		if d.has("shortcut_item"):
			var other: String = p.hot_items.get(index, "")
			var building: String = p.hot_builds.get(index, "")
			p.pin_item(d.from, other)
			if building != "":
				hud.pin_build(building, d.from)
			p.pin_item(index, d.shortcut_item)
		elif d.inv.slots[d.index] != null:
			p.pin_item(index, d.inv.slots[d.index].id)
	else:
		hud.move_slot(d.inv, d.index, inv, index, d.half)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		if shortcut:
			if ev.button_index == MOUSE_BUTTON_RIGHT:
				hud.game.player.pin_item(index, "")
			elif ev.button_index == MOUSE_BUTTON_LEFT:
				hud.game.hot_select(index)
			accept_event()
			return
		if ev.button_index == MOUSE_BUTTON_LEFT and ev.alt_pressed:
			# 1.3: Alt+клик — стопку в мусорку, Shift+Alt+клик — все такие предметы
			if inv.slots[index] != null and bool(DB.setting("trash", true)):
				if ev.shift_pressed:
					hud.trash_all(inv, index)
				else:
					hud.trash(inv, index)
			accept_event()
		elif ev.button_index == MOUSE_BUTTON_LEFT and ev.shift_pressed:
			# 1.3: Shift+клик — весь такой предмет в открытый ящик/печь или обратно в рюкзак
			hud.quick_move(inv, index, true)
			accept_event()
		elif ev.button_index == MOUSE_BUTTON_RIGHT:
			if inv.slots[index] == null and hot_build() != "":
				hud.pin_build("", index)
			else:
				hud.use_slot(inv, index)
			accept_event()
		elif ev.button_index == MOUSE_BUTTON_LEFT and ev.double_click and bool(DB.setting("dblclick_move", true)):
			# двойной клик — вся стопка в открытое здание или обратно в рюкзак
			hud.quick_move(inv, index)
			accept_event()
		elif ev.button_index == MOUSE_BUTTON_LEFT and not ev.double_click:
			if inv.slots[index] != null and hud.has_method("show_item_info"):
				hud.show_item_info(inv, index)
			if hud.game.player.inv == inv and "inv_pick" in hud:
				hud.inv_pick = index   # 1.7: рамка переходит на ячейку, по которой щёлкнули
				hud._refresh_inventory()


func _make_custom_tooltip(for_text: String) -> Object:
	if not bool(UI.st("rich_tips")) or for_text == "":
		return null
	var slot_index: int = hud.game.player.hot_slot(index) if shortcut else index
	var s = inv.slots[slot_index] if slot_index >= 0 and slot_index < inv.size() else null
	var ic: Control = null
	if s != null:
		ic = UI.item_icon(s.id, 48)
	elif hot_build() != "":
		ic = UI.building_icon(hot_build(), 48)
	return UI.tip_panel(for_text, ic)
