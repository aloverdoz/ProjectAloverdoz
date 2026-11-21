extends HSplitContainer
## Вкладка «Интерфейс»: где на экране стоят панели игры (перетаскиванием), их прозрачность,
## размер и видимость; цвет интерфейса; свои окна с текстом, полосками, кнопками и картинками.

var ed
var ui: Dictionary
var screen: Control
var side: VBoxContainer
var sel := ""
var sel_win := ""
var _drag := false
var _drag_off := Vector2.ZERO
var _save_t := 0.0
var win_preview: PanelContainer

const SCREEN := Vector2(1600, 900)
const PANELS := {
	"corp": ["Корпорация (кредиты, уровень)", Vector2(290, 95), "tl", [16, 16]],
	"vitals": ["Здоровье, еда, вода", Vector2(250, 125), "bl", [16, 16]],
	"wave": ["Таймер волны и время суток", Vector2(260, 60), "top", [0, 12]],
	"minimap": ["Миникарта", Vector2(200, 200), "tr", [16, 16]],
	"quests": ["Задачи", Vector2(330, 125), "tr", [16, 232]],
	"info": ["Подсказка о здании", Vector2(300, 150), "br", [16, 130]],
	"hotbar": ["Быстрые слоты", Vector2(770, 135), "bottom", [0, 10]],
}
const ANCHORS := ["tl", "top", "tr", "bl", "bottom", "br", "center"]


func _init(editor) -> void:
	ed = editor
	split_offset = 980
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(left)
	var tip := UI.small("Перетаскивайте панели мышкой — так они встанут в игре. Щелчок по панели — её настройки справа. Экран игры показан уменьшенным.")
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(tip)
	var ar := AspectRatioContainer.new()
	ar.ratio = SCREEN.x / SCREEN.y
	ar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(ar)
	screen = Control.new()
	screen.clip_contents = true
	screen.mouse_filter = Control.MOUSE_FILTER_STOP
	screen.draw.connect(_draw_screen)
	screen.gui_input.connect(_screen_input)
	ar.add_child(screen)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(420, 0)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(sc)
	side = VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 8)
	sc.add_child(side)


func _ready() -> void:
	refresh()


func refresh() -> void:
	ui = DB.data.get("ui", {}).duplicate(true)
	if not ui.has("panels"):
		ui["panels"] = {}
	if not ui.has("windows"):
		ui["windows"] = {}
	_build_side()
	screen.queue_redraw()


func _cfg(id: String) -> Dictionary:
	var d: Array = PANELS[id]
	var c := {"anchor": d[2], "pos": d[3], "opacity": 0.82, "visible": true, "scale": 1.0}
	c.merge(ui.panels.get(id, {}), true)
	return c


func _set_cfg(id: String, key: String, v) -> void:
	if not ui.panels.has(id):
		ui.panels[id] = _cfg(id)
	ui.panels[id][key] = v
	_changed()


var _dirty := false

func _changed() -> void:
	_dirty = true
	_save_t = 0.5
	screen.queue_redraw()
	_update_preview()


func _process(delta: float) -> void:
	if _save_t > 0.0:
		_save_t -= delta
		if _save_t <= 0.0:
			flush()


func flush() -> void:
	if _dirty:
		_dirty = false
		_save_t = 0.0
		DB.save_object("ui", "", ui.duplicate(true))
		ed.content_changed()
		ed.set_status("Интерфейс сохранён")


# ---------------------------------------------------------------- экран

func _k() -> float:
	return screen.size.x / SCREEN.x


## Прямоугольник панели в координатах экрана игры (как в hud._place_panels).
func _rect(id: String) -> Rect2:
	var c := _cfg(id)
	var sz: Vector2 = PANELS[id][1] * float(c.get("scale", 1.0))
	var o := Vector2(float(c.pos[0]), float(c.pos[1]))
	var pos := o
	match str(c.anchor):
		"tr": pos = Vector2(SCREEN.x - sz.x - o.x, o.y)
		"bl": pos = Vector2(o.x, SCREEN.y - sz.y - o.y)
		"br": pos = Vector2(SCREEN.x - sz.x - o.x, SCREEN.y - sz.y - o.y)
		"top": pos = Vector2((SCREEN.x - sz.x) * 0.5 + o.x, o.y)
		"bottom": pos = Vector2((SCREEN.x - sz.x) * 0.5 + o.x, SCREEN.y - sz.y - o.y)
		"center": pos = (SCREEN - sz) * 0.5 + o
	return Rect2(pos, sz)


## Обратно: из положения на экране — отступ от выбранного края.
func _offset_for(id: String, pos: Vector2) -> Array:
	var c := _cfg(id)
	var sz: Vector2 = PANELS[id][1] * float(c.get("scale", 1.0))
	var o := pos
	match str(c.anchor):
		"tr": o = Vector2(SCREEN.x - sz.x - pos.x, pos.y)
		"bl": o = Vector2(pos.x, SCREEN.y - sz.y - pos.y)
		"br": o = Vector2(SCREEN.x - sz.x - pos.x, SCREEN.y - sz.y - pos.y)
		"top": o = Vector2(pos.x - (SCREEN.x - sz.x) * 0.5, pos.y)
		"bottom": o = Vector2(pos.x - (SCREEN.x - sz.x) * 0.5, SCREEN.y - sz.y - pos.y)
		"center": o = pos - (SCREEN - sz) * 0.5
	return [roundi(o.x), roundi(o.y)]


## Ближайший к точке угол или край экрана — чтобы панель «прилипала» к нему при другом размере окна.
func _best_anchor(r: Rect2) -> String:
	var cx := r.get_center().x / SCREEN.x
	var cy := r.get_center().y / SCREEN.y
	var h := "l" if cx < 0.33 else ("r" if cx > 0.67 else "c")
	var v := "t" if cy < 0.5 else "b"
	if h == "c" and cy > 0.3 and cy < 0.7:
		return "center"
	if h == "c":
		return "top" if v == "t" else "bottom"
	return v + h


func _draw_screen() -> void:
	var k := _k()
	screen.draw_rect(Rect2(Vector2.ZERO, screen.size), Color(0.23, 0.36, 0.22))
	# условная картинка игры: земля, пара деревьев, штаб
	for i in 14:
		var p := Vector2(fmod(i * 397.0, SCREEN.x), fmod(i * 211.0 + 120.0, SCREEN.y)) * k
		screen.draw_circle(p, 22.0 * k, Color(0.16, 0.3, 0.17))
	screen.draw_rect(Rect2(Vector2(740, 380) * k, Vector2(120, 120) * k), Color(0.55, 0.55, 0.6))
	screen.draw_circle(Vector2(900, 470) * k, 12.0 * k, Color(1.0, 0.8, 0.4))
	var font := ThemeDB.fallback_font
	for id in PANELS:
		var c := _cfg(id)
		var r := _rect(id)
		var rr := Rect2(r.position * k, r.size * k)
		var on: bool = c.get("visible", true)
		var bg := Color(0.06, 0.08, 0.11, float(c.get("opacity", 0.82)) if on else 0.25)
		screen.draw_rect(rr, bg)
		var bc := UI.ACCENT if id == sel else Color(1, 1, 1, 0.25)
		screen.draw_rect(rr, bc, false, 2.0 if id == sel else 1.0)
		var t: String = PANELS[id][0] + ("" if on else " (скрыта)")
		screen.draw_string(font, rr.position + Vector2(6, 16), t, HORIZONTAL_ALIGNMENT_LEFT, rr.size.x - 10, 12,
			UI.ACCENT if on else Color(1, 1, 1, 0.4))
	# свои окна, открытые при старте
	for wid in ui.windows:
		var w: Dictionary = ui.windows[wid]
		if not w.get("visible", false) and wid != sel_win:
			continue
		var sz := Vector2(float(w.get("size", [340, 0])[0]), maxf(120.0, float(w.get("size", [340, 0])[1])))
		var rr := Rect2((SCREEN - sz) * 0.5 * k, sz * k)
		screen.draw_rect(rr, Color(0.06, 0.08, 0.11, float(w.get("opacity", 0.86))))
		screen.draw_rect(rr, UI.ACCENT if wid == sel_win else Color(1, 1, 1, 0.3), false, 1.0)
		screen.draw_string(font, rr.position + Vector2(6, 16), "Окно: " + str(w.get("title", wid)), HORIZONTAL_ALIGNMENT_LEFT, rr.size.x - 10, 12, UI.ACCENT)


func _screen_input(ev: InputEvent) -> void:
	var k := _k()
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			var p: Vector2 = ev.position / k
			var hit := ""
			for id in PANELS:
				if _rect(id).has_point(p):
					hit = id
			if hit != "":
				_drag = true
				_drag_off = p - _rect(hit).position
			if hit != sel:
				sel = hit
				_build_side()
			screen.queue_redraw()
		elif _drag:
			_drag = false
			# после перетаскивания привязать к ближайшему краю
			var r := _rect(sel)
			var a := _best_anchor(r)
			if a != str(_cfg(sel).anchor):
				_set_cfg(sel, "anchor", a)
				_set_cfg(sel, "pos", _offset_for(sel, r.position))
				_build_side()
	elif ev is InputEventMouseMotion and _drag and sel != "":
		var p: Vector2 = ev.position / k - _drag_off
		var sz := _rect(sel).size
		p.x = clampf(p.x, 0, SCREEN.x - sz.x)
		p.y = clampf(p.y, 0, SCREEN.y - sz.y)
		p = p.snapped(Vector2(4, 4))
		_set_cfg(sel, "pos", _offset_for(sel, p))


# ---------------------------------------------------------------- правая колонка

func _section(t: String, tip := "") -> VBoxContainer:
	var pc := PanelContainer.new()
	side.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	pc.add_child(v)
	v.add_child(UI.title(t, 17))
	if tip != "":
		var l := UI.small(tip)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	return v


func _build_side() -> void:
	for c in side.get_children():
		c.queue_free()
	win_preview = null
	# --- общее
	var g := _section("Общий вид")
	var ch := HBoxContainer.new()
	g.add_child(ch)
	ch.add_child(UI.small("Цвет интерфейса (заголовки, рамки)"))
	var cp := ColorPickerButton.new()
	cp.color = Color.from_string(str(ui.get("accent", "#ffa040")), UI.ACCENT)
	cp.custom_minimum_size = Vector2(90, 28)
	cp.edit_alpha = false
	cp.color_changed.connect(func(c):
		ui["accent"] = "#" + c.to_html(false)
		_changed())
	ch.add_child(cp)
	_build_style(g)
	g.add_child(UI.button("Вернуть расстановку как было", func():
		ed.confirm("Вернуть все панели на места по умолчанию?", func():
			ui.panels = {}
			sel = ""
			_changed()
			_build_side())))
	# --- выбранная панель
	if sel != "":
		var c := _cfg(sel)
		var p := _section("Панель: " + str(PANELS[sel][0]))
		var vis := CheckBox.new()
		vis.text = "Показывать в игре"
		vis.button_pressed = c.get("visible", true)
		vis.toggled.connect(func(on): _set_cfg(sel, "visible", on))
		p.add_child(vis)
		var ah := HBoxContainer.new()
		p.add_child(ah)
		ah.add_child(UI.small("Прилипает к"))
		var ob := OptionButton.new()
		ob.focus_mode = Control.FOCUS_NONE
		for i in ANCHORS.size():
			ob.add_item(EdSchema.enum_label(ANCHORS[i]), i)
		ob.select(maxi(0, ANCHORS.find(str(c.anchor))))
		ob.item_selected.connect(func(i):
			var r := _rect(sel)
			_set_cfg(sel, "anchor", ANCHORS[i])
			_set_cfg(sel, "pos", _offset_for(sel, r.position)))
		ah.add_child(ob)
		p.add_child(_slider("Непрозрачность фона", 0.0, 1.0, float(c.get("opacity", 0.82)), 0.05, func(v): _set_cfg(sel, "opacity", v)))
		p.add_child(_slider("Размер", 0.6, 1.6, float(c.get("scale", 1.0)), 0.05, func(v): _set_cfg(sel, "scale", v)))
		var off := UI.small("Отступ от края: %d, %d" % [int(c.pos[0]), int(c.pos[1])])
		p.add_child(off)
	else:
		var l := UI.small("Щёлкните по панели на экране слева, чтобы её настроить.")
		side.add_child(l)
	# --- свои окна
	var w := _section("Свои окна",
		"Окно открывается своей клавишей (например F6) или кнопкой. В тексте можно писать значения игры в фигурных скобках — они будут обновляться.")
	for wid in ui.windows:
		var row := HBoxContainer.new()
		var b := Button.new()
		b.text = "%s  [%s]" % [ui.windows[wid].get("title", wid), ui.windows[wid].get("key", "")]
		b.toggle_mode = true
		b.button_pressed = wid == sel_win
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		var id: String = wid
		b.pressed.connect(func():
			sel_win = "" if sel_win == id else id
			_build_side()
			screen.queue_redraw())
		row.add_child(b)
		row.add_child(UI.button("✕", func():
			ed.confirm("Удалить окно «%s»?" % ui.windows[id].get("title", id), func():
				ui.windows.erase(id)
				if sel_win == id:
					sel_win = ""
				_changed()
				_build_side()), "Удалить окно"))
		w.add_child(row)
	w.add_child(UI.button("+ Новое окно", _new_window))
	var vals := []
	for k in EdSchema.UI_VALUES:
		vals.append("{%s} — %s" % [k, EdSchema.UI_VALUES[k]])
	var vl := UI.small("Значения: " + ", ".join(vals))
	vl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	w.add_child(vl)
	if sel_win != "" and ui.windows.has(sel_win):
		var wd: Dictionary = ui.windows[sel_win]
		var e := _section("Окно «%s»" % wd.get("title", sel_win))
		var f := EdForm.make(wd, EdSchema.sub("ui_window"), false, 150)
		f.changed.connect(_changed)
		e.add_child(f)
		e.add_child(UI.title("Как будет выглядеть", 15))
		win_preview = PanelContainer.new()
		e.add_child(win_preview)
		_update_preview()


# ---------------------------------------------------------------- вид окон (13.10)
const CORNERS := ["cut", "round", "square"]
const CORNER_NAMES := ["Срезанные (как на заводе)", "Скруглённые", "Прямые"]
var style_preview: Control


func _th() -> Dictionary:
	if not ui.get("theme") is Dictionary:
		ui["theme"] = {}
	return ui.theme


func _thv(k: String):
	return _th().get(k, UI.STYLE_DEFAULTS.get(k))


func _set_th(k: String, v) -> void:
	_th()[k] = v
	UI.set_style(_th())
	_changed()
	_style_preview_refresh()


func _color_row(t: String, key: String) -> Control:
	var h := HBoxContainer.new()
	var l := UI.small(t)
	l.custom_minimum_size = Vector2(150, 0)
	h.add_child(l)
	var cp := ColorPickerButton.new()
	cp.color = Color.from_string(str(_thv(key)), Color.GRAY)
	cp.custom_minimum_size = Vector2(90, 28)
	cp.edit_alpha = false
	cp.color_changed.connect(func(c): _set_th(key, "#" + c.to_html(false)))
	h.add_child(cp)
	return h


func _check_row(t: String, key: String, tip := "") -> Control:
	var c := CheckBox.new()
	c.text = t
	c.tooltip_text = tip
	c.button_pressed = bool(_thv(key))
	c.toggled.connect(func(on): _set_th(key, on))
	return c


## Вид окон игры: шрифт, углы, цвета, подсказки — с живым образцом окна.
func _build_style(g: VBoxContainer) -> void:
	g.add_child(UI.section("Вид окон и шрифт"))
	g.add_child(_slider("Размер шрифта ×", 0.8, 1.6, float(_thv("font_scale")), 0.05, func(v): _set_th("font_scale", v)))
	g.add_child(_slider("Ширина окон ×", 0.8, 1.5, float(_thv("window_scale")), 0.05, func(v): _set_th("window_scale", v)))
	var ch := HBoxContainer.new()
	var cl := UI.small("Углы окон и кнопок")
	cl.custom_minimum_size = Vector2(150, 0)
	ch.add_child(cl)
	var ob := OptionButton.new()
	ob.focus_mode = Control.FOCUS_NONE
	for i in CORNERS.size():
		ob.add_item(CORNER_NAMES[i], i)
	ob.select(maxi(0, CORNERS.find(str(_thv("corners")))))
	ob.item_selected.connect(func(i): _set_th("corners", CORNERS[i]))
	ch.add_child(ob)
	g.add_child(ch)
	g.add_child(_slider("Размер угла, пикс.", 0, 20, float(_thv("radius")), 1, func(v): _set_th("radius", int(v))))
	g.add_child(_color_row("Цвет окон", "panel_color"))
	g.add_child(_slider("Непрозрачность окон", 0.4, 1.0, float(_thv("panel_opacity")), 0.05, func(v): _set_th("panel_opacity", v)))
	g.add_child(_color_row("Цвет кнопок", "button_color"))
	g.add_child(_slider("Рамка окна, пикс.", 0, 4, float(_thv("frame")), 1, func(v): _set_th("frame", int(v))))
	var hh := HBoxContainer.new()
	var hl := UI.small("Заголовок окна")
	hl.custom_minimum_size = Vector2(150, 0)
	hh.add_child(hl)
	var hb := OptionButton.new()
	hb.focus_mode = Control.FOCUS_NONE
	hb.add_item("Цветная плашка", 0)
	hb.add_item("Тёмный с чертой", 1)
	hb.select(0 if str(_thv("header")) == "fill" else 1)
	hb.item_selected.connect(func(i): _set_th("header", "fill" if i == 0 else "line"))
	hh.add_child(hb)
	g.add_child(hh)
	g.add_child(_color_row("Текст на плашке", "header_text"))
	g.add_child(_check_row("Косые полоски на заголовке", "stripes"))
	g.add_child(_check_row("Жирные заголовки", "bold_titles"))
	g.add_child(_check_row("Подробные подсказки (значок, строки «название: значение»)", "rich_tips",
		"Выключите — подсказки будут обычным текстом"))
	g.add_child(UI.small("Образец окна в игре:"))
	style_preview = CenterContainer.new()
	g.add_child(style_preview)
	_style_preview_refresh()


func _style_preview_refresh() -> void:
	if style_preview == null or not is_instance_valid(style_preview):
		return
	UI.clear(style_preview)
	UI.use_game_style(true)
	var th := UI.theme()
	var w := PanelContainer.new()
	w.theme = th
	w.custom_minimum_size = Vector2(300, 0)
	var v := UI.vbox(8)
	w.add_child(v)
	var hb := UI.header_box()
	var head := UI.hbox(8)
	hb.add_child(head)
	var t := UI.title("ИНВЕНТАРЬ", 20)
	t.add_theme_color_override("font_color", UI.header_text())
	head.add_child(t)
	v.add_child(hb)
	v.add_child(UI.section("Пример"))
	v.add_child(UI.label("Обычный текст окна"))
	v.add_child(UI.small("Мелкая подсказка"))
	var row := UI.hbox(8)
	row.add_child(UI.button("Кнопка", func(): pass))
	var pb := UI.button("Нажата", func(): pass)
	pb.toggle_mode = true
	pb.button_pressed = true
	row.add_child(pb)
	v.add_child(row)
	var bar := UI.bar(null, UI.ACCENT, 10)
	bar.value = 65
	v.add_child(bar)
	UI.use_game_style(false)
	style_preview.add_child(w)


func _slider(t: String, lo: float, hi: float, v: float, step: float, cb: Callable) -> Control:
	var h := HBoxContainer.new()
	var l := UI.small(t)
	l.custom_minimum_size = Vector2(150, 0)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = v
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.focus_mode = Control.FOCUS_NONE
	var vl := UI.small(str(v))
	vl.custom_minimum_size = Vector2(40, 0)
	s.value_changed.connect(func(x):
		vl.text = str(snappedf(x, 0.01))
		cb.call(x))
	h.add_child(s)
	h.add_child(vl)
	return h


func _new_window() -> void:
	var n := 1
	while ui.windows.has("window_%d" % n):
		n += 1
	var id := "window_%d" % n
	ui.windows[id] = {"title": "Новое окно", "key": "F%d" % mini(12, 6 + n), "size": [340, 0], "opacity": 0.9, "visible": false,
		"elements": [{"type": "label", "text": "Кредиты: {credits}"}, {"type": "bar", "bind": "hp_frac", "color": "#ff5a4a", "text": "Здоровье"},
			{"type": "button", "text": "Инвентарь", "action": "inventory"}]}
	sel_win = id
	_changed()
	_build_side()


## Окно в уменьшенном виде с примерными значениями.
func _update_preview() -> void:
	if win_preview == null or not is_instance_valid(win_preview) or not ui.windows.has(sel_win):
		return
	for c in win_preview.get_children():
		c.queue_free()
	var wd: Dictionary = ui.windows[sel_win]
	var sample := {"level": 7, "xp_frac": 0.6, "skill_points": 2, "attr_points": 4, "credits": 1250, "kills": 83, "wave": 5, "waves": 4,
		"nests": 3, "buildings": 41, "hp": 160, "hp_max": 200, "hp_frac": 0.8, "food": 70, "food_frac": 0.7, "water": 55,
		"water_frac": 0.55, "day": 3, "time": "14:20", "profession": "Инженер"}
	var v := UI.vbox(6)
	v.custom_minimum_size = Vector2(minf(380.0, float(wd.get("size", [340, 0])[0])), 0)
	win_preview.add_child(v)
	v.add_child(UI.title(str(wd.get("title", "")).to_upper(), 16))
	for e in wd.get("elements", []):
		match str(e.get("type", "label")):
			"label":
				var t := str(e.get("text", ""))
				for k in sample:
					t = t.replace("{%s}" % k, str(sample[k]))
				var l := UI.rich(t, int(e.get("size", 14)))
				v.add_child(l)
			"bar":
				var bv := UI.vbox(2)
				bv.add_child(UI.small(str(e.get("text", ""))))
				var pb := UI.bar(bv, DB.color(e.get("color", "#ffa040")), 10)
				pb.max_value = 1.0
				pb.value = float(sample.get(str(e.get("bind", "")), 0.5))
				v.add_child(bv)
			"separator":
				v.add_child(HSeparator.new())
			"button":
				v.add_child(UI.button(str(e.get("text", "Кнопка")), func(): pass))
			"image":
				var tr := TextureRect.new()
				tr.texture = ModelLib.texture(str(e.get("path", "")))
				tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				tr.custom_minimum_size = Vector2(float(e.get("w", 64)), float(e.get("h", 64)))
				v.add_child(tr)


## Проверка: перевод «место на экране ↔ отступ от края» туда и обратно для всех краёв.
func _test_layout() -> void:
	var bad := 0
	for id in PANELS:
		for a in ANCHORS:
			ui.panels[id] = {"anchor": a, "pos": [24, 40]}
			var back := _offset_for(id, _rect(id).position)
			if back != [24, 40]:
				bad += 1
				print("UITEST mismatch ", id, " ", a, " ", back)
	ui.panels = {}
	print("UITEST layout bad=", bad, " anchor_tl=", _best_anchor(Rect2(10, 10, 100, 50)), " anchor_br=", _best_anchor(Rect2(1400, 800, 100, 50)), " anchor_bottom=", _best_anchor(Rect2(700, 800, 100, 50)))
