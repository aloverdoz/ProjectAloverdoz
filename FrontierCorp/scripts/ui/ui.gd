class_name UI
extends RefCounted
## Общие детали интерфейса: тема, панели, окна, ячейки предметов, полоски.

static var ACCENT := Color(1.0, 0.62, 0.15)   # меняется в редакторе интерфейса (ui.json → accent)
const TEXT := Color(0.92, 0.94, 0.97)
const DIM := Color(0.62, 0.67, 0.75)
const BAD := Color(1.0, 0.42, 0.35)
const GOOD := Color(0.5, 1.0, 0.6)

static var _theme: Theme
static var _theme_key := ""
static var STYLE := {}          # ui.json → theme (вид окон, размер шрифта, углы)
static var SCALE := 1.0         # размер шрифта: в игре из настроек, в редакторе всегда 1
static var game_style := false  # true — интерфейс игры (шрифт крупнее); редактор — false
static var BOLD: FontVariation

const STYLE_DEFAULTS := {
	"font_scale": 1.15, "corners": "cut", "radius": 10, "panel_color": "#121822", "panel_opacity": 0.95,
	"header": "fill", "header_text": "#1a1206", "frame": 1, "frame_alpha": 0.45, "bold_titles": true,
	"stripes": true, "rich_tips": true, "window_scale": 1.1, "button_color": "#232b38",
}


## Цвет акцента из настроек интерфейса игры. Тема пересоберётся при следующем запросе.
static func set_accent(c: Color) -> void:
	if not c.is_equal_approx(ACCENT):
		ACCENT = c
		_theme = null


## Вид интерфейса из ui.json → theme (редактор: «Интерфейс» → «Общий вид»).
static func set_style(d) -> void:
	var st := STYLE_DEFAULTS.duplicate()
	if d is Dictionary:
		for k in d:
			st[k] = d[k]
	STYLE = st
	_theme = null
	_apply_scale()


## Включить крупный шрифт игры (true) или обычный шрифт редактора (false).
static func use_game_style(on: bool) -> void:
	game_style = on
	_apply_scale()


static func _apply_scale() -> void:
	var s := clampf(float(st("font_scale")), 0.7, 1.8) if game_style else 1.0
	if not is_equal_approx(s, SCALE):
		SCALE = s
		_theme = null


static func st(key: String):
	if STYLE.is_empty():
		STYLE = STYLE_DEFAULTS.duplicate()
	return STYLE.get(key, STYLE_DEFAULTS.get(key))


## Размер шрифта с учётом масштаба из настроек.
static func fs(n: float) -> int:
	return maxi(8, int(round(n * SCALE)))


## Ширина окна с учётом масштаба интерфейса.
static func ws(w: float) -> float:
	return w * (clampf(float(st("window_scale")), 0.7, 1.6) if game_style else 1.0)


## Жирный шрифт для заголовков.
static func bold() -> Font:
	if BOLD == null:
		BOLD = FontVariation.new()
		BOLD.base_font = ThemeDB.fallback_font
		BOLD.variation_embolden = 0.75
	return BOLD


## Основа рамок: скошенные (как у заводских панелей), скруглённые или прямые углы.
static func box(bg: Color, radius := -1) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	var r := int(st("radius")) if radius < 0 else radius
	match str(st("corners")):
		"square":
			r = 0
		"cut":
			b.corner_detail = 1    # одна грань вместо дуги — срезанный угол
	b.set_corner_radius_all(r)
	b.anti_aliasing = true
	return b


static func panel_color() -> Color:
	var c := Color.from_string(str(st("panel_color")), Color(0.07, 0.09, 0.13))
	c.a = clampf(float(st("panel_opacity")), 0.3, 1.0)
	return c


static func theme() -> Theme:
	var key := "%s|%s|%s" % [ACCENT.to_html(), SCALE, str(STYLE)]
	if _theme and key == _theme_key:
		return _theme
	_theme_key = key
	var t := Theme.new()
	t.default_font_size = fs(16)
	var fa := float(st("frame_alpha"))
	var panel := box(panel_color())
	panel.border_color = Color(ACCENT.lerp(Color(0.6, 0.65, 0.75), 0.55), fa)
	panel.set_border_width_all(int(st("frame")))
	panel.set_content_margin_all(14)
	panel.shadow_color = Color(0, 0, 0, 0.5)
	panel.shadow_size = 16
	panel.shadow_offset = Vector2(0, 6)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	var bc := Color.from_string(str(st("button_color")), Color(0.15, 0.18, 0.235))
	var bn := box(Color(bc, 0.97), maxi(0, int(st("radius")) - 3))
	bn.content_margin_top = 7
	bn.content_margin_bottom = 7
	bn.content_margin_left = 14
	bn.content_margin_right = 14
	bn.border_color = Color(1, 1, 1, 0.1)
	bn.set_border_width_all(1)
	bn.border_width_bottom = 1            # нижняя грань темнее — кнопка выглядит объёмной
	bn.shadow_color = Color(0, 0, 0, 0.3)
	bn.shadow_size = 0
	bn.shadow_offset = Vector2(0, 2)
	var bh := bn.duplicate()
	bh.bg_color = bc.lightened(0.14)
	bh.border_color = ACCENT
	bh.set_border_width_all(2)
	bh.border_width_bottom = 1
	var bp := bn.duplicate()
	bp.bg_color = ACCENT
	bp.border_color = ACCENT.darkened(0.35)
	bp.border_width_bottom = 1
	bp.border_width_top = 3
	var bd := bn.duplicate()
	bd.bg_color = Color(0.1, 0.11, 0.13, 0.8)
	bd.border_color = Color(1, 1, 1, 0.04)
	var dark_text := Color.from_string(str(st("header_text")), Color(0.1, 0.07, 0.03))
	for cls in ["Button", "OptionButton", "MenuButton", "CheckBox", "CheckButton"]:
		t.set_stylebox("normal", cls, bn)
		t.set_stylebox("hover", cls, bh)
		t.set_stylebox("pressed", cls, bp)
		t.set_stylebox("hover_pressed", cls, bp)
		t.set_stylebox("disabled", cls, bd)
		t.set_stylebox("focus", cls, StyleBoxEmpty.new())
		t.set_color("font_color", cls, TEXT)
		t.set_color("font_hover_color", cls, Color.WHITE)
		t.set_color("font_pressed_color", cls, dark_text)
		t.set_color("font_hover_pressed_color", cls, dark_text)
		t.set_color("font_disabled_color", cls, Color(0.5, 0.5, 0.55))
		t.set_font_size("font_size", cls, fs(15))
	for cls in ["CheckBox", "CheckButton"]:
		var cb := StyleBoxEmpty.new()
		cb.content_margin_left = 4
		cb.content_margin_right = 4
		t.set_stylebox("normal", cls, cb)
		t.set_stylebox("pressed", cls, cb)
		t.set_stylebox("hover_pressed", cls, cb)
		t.set_color("font_pressed_color", cls, TEXT)
		t.set_color("font_hover_pressed_color", cls, Color.WHITE)
		var hv := bh.duplicate()
		hv.bg_color = Color(1, 1, 1, 0.05)
		hv.border_color = Color(ACCENT, 0.4)
		hv.set_border_width_all(1)
		t.set_stylebox("hover", cls, hv)
	# заметные квадратики галочек: светлая рамка видна и когда галочка снята
	var isz := int(fs(22))
	for ic in [["checked", true, false], ["unchecked", false, false], ["radio_checked", true, true], ["radio_unchecked", false, true],
			["checked_disabled", true, false], ["unchecked_disabled", false, false]]:
		var dis := str(ic[0]).ends_with("disabled")
		t.set_icon(str(ic[0]), "CheckBox", check_icon(bool(ic[1]), bool(ic[2]), isz, dis))
	for ic2 in [["checked", true], ["unchecked", false], ["checked_disabled", true], ["unchecked_disabled", false]]:
		t.set_icon(str(ic2[0]), "CheckButton", switch_icon(bool(ic2[1]), isz, str(ic2[0]).ends_with("disabled")))
	var le := box(Color(0.03, 0.04, 0.06, 0.96), maxi(0, int(st("radius")) - 4))
	le.content_margin_left = 10
	le.content_margin_right = 10
	le.content_margin_top = 6
	le.content_margin_bottom = 6
	le.border_color = Color(1, 1, 1, 0.12)
	le.set_border_width_all(1)
	var lf := le.duplicate()
	lf.border_color = ACCENT
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", lf)
	t.set_stylebox("normal", "TextEdit", le)
	t.set_stylebox("focus", "TextEdit", lf)
	t.set_font_size("font_size", "LineEdit", fs(15))
	t.set_font_size("font_size", "TextEdit", fs(15))
	t.set_color("caret_color", "LineEdit", ACCENT)
	t.set_color("selection_color", "LineEdit", Color(ACCENT, 0.35))
	var tab_sel := bn.duplicate()
	tab_sel.bg_color = ACCENT
	tab_sel.border_color = ACCENT.darkened(0.3)
	t.set_stylebox("tab_selected", "TabBar", tab_sel)
	t.set_stylebox("tab_unselected", "TabBar", bn)
	t.set_stylebox("tab_hovered", "TabBar", bh)
	t.set_stylebox("tab_selected", "TabContainer", tab_sel)
	t.set_stylebox("tab_unselected", "TabContainer", bn)
	t.set_stylebox("tab_hovered", "TabContainer", bh)
	for cls in ["TabBar", "TabContainer"]:
		t.set_color("font_selected_color", cls, dark_text)
		t.set_color("font_unselected_color", cls, Color(0.8, 0.84, 0.9))
		t.set_color("font_hovered_color", cls, Color.WHITE)
		t.set_font_size("font_size", cls, fs(15))
	var pan := panel.duplicate()
	pan.bg_color = Color(0.05, 0.06, 0.09, 0.6)
	pan.shadow_size = 0
	t.set_stylebox("panel", "TabContainer", pan)
	# подсказки: тёмная плашка с цветной чертой сверху
	var tip := box(Color(0.03, 0.04, 0.06, 0.97))
	tip.border_color = Color(ACCENT, 0.8)
	tip.set_border_width_all(1)
	tip.border_width_top = 3
	tip.set_content_margin_all(12)
	tip.shadow_color = Color(0, 0, 0, 0.6)
	tip.shadow_size = 10
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", fs(15))
	t.set_font_size("font_size", "Label", fs(15))
	t.set_font_size("normal_font_size", "RichTextLabel", fs(15))
	t.set_font_size("bold_font_size", "RichTextLabel", fs(15))
	t.set_font_size("font_size", "PopupMenu", fs(15))
	t.set_font_size("font_size", "ItemList", fs(15))
	t.set_font_size("font_size", "Tree", fs(15))
	var pm := box(Color(0.05, 0.06, 0.09, 0.98))
	pm.border_color = Color(ACCENT, 0.5)
	pm.set_border_width_all(1)
	pm.set_content_margin_all(6)
	t.set_stylebox("panel", "PopupMenu", pm)
	var pmh := box(Color(ACCENT, 0.85), 4)
	t.set_stylebox("hover", "PopupMenu", pmh)
	t.set_color("font_hover_color", "PopupMenu", dark_text)
	var sc := StyleBoxFlat.new()
	sc.bg_color = Color(1, 1, 1, 0.06)
	sc.set_corner_radius_all(4)
	sc.content_margin_left = 3
	sc.content_margin_right = 3
	var grab := sc.duplicate()
	grab.bg_color = Color(ACCENT, 0.7)
	var grab_h := sc.duplicate()
	grab_h.bg_color = ACCENT
	for cls in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", cls, sc)
		t.set_stylebox("grabber", cls, grab)
		t.set_stylebox("grabber_highlight", cls, grab_h)
		t.set_stylebox("grabber_pressed", cls, grab_h)
	# ползунки
	var sl := StyleBoxFlat.new()
	sl.bg_color = Color(1, 1, 1, 0.12)
	sl.set_corner_radius_all(3)
	sl.content_margin_top = 3
	sl.content_margin_bottom = 3
	var slf := sl.duplicate()
	slf.bg_color = ACCENT
	t.set_stylebox("slider", "HSlider", sl)
	t.set_stylebox("grabber_area", "HSlider", slf)
	t.set_stylebox("grabber_area_highlight", "HSlider", slf)
	# полоски прогресса
	var pbg := box(Color(0, 0, 0, 0.4), 4)
	var pfg := box(ACCENT, 4)
	t.set_stylebox("background", "ProgressBar", pbg)
	t.set_stylebox("fill", "ProgressBar", pfg)
	# разделитель
	var sep := StyleBoxLine.new()
	sep.color = Color(1, 1, 1, 0.1)
	sep.thickness = 1
	t.set_stylebox("separator", "HSeparator", sep)
	t.set_constant("separation", "HSeparator", 10)
	_theme = t
	return t


## Заголовок окна. «fill» — сплошная цветная плашка с тёмным текстом,
## «line» — тёмная полоса с цветной чертой снизу.
static func header_box() -> PanelContainer:
	var p := PanelContainer.new()
	var fill := str(st("header")) == "fill"
	var hs := box(ACCENT if fill else Color(1, 1, 1, 0.035), maxi(0, int(st("radius")) - 2))
	if fill:
		hs.border_color = ACCENT.darkened(0.35)
		hs.border_width_bottom = 3
	else:
		hs.border_color = Color(ACCENT, 0.9)
		hs.border_width_bottom = 2
	hs.content_margin_left = 8
	hs.content_margin_right = 4
	hs.content_margin_top = 4
	hs.content_margin_bottom = 5
	p.add_theme_stylebox_override("panel", hs)
	p.set_meta("fill", fill)
	if fill and bool(st("stripes")):
		p.add_child(Stripes.new())
	return p


## Цвет текста на заголовке окна.
static func header_text() -> Color:
	return Color.from_string(str(st("header_text")), Color(0.1, 0.07, 0.03)) if str(st("header")) == "fill" else ACCENT


## Подзаголовок раздела внутри окна: «ВХОД», «ВЫХОД» и т. п.
static func section(text: String) -> Control:
	var h := hbox(8)
	var mark := ColorRect.new()
	mark.color = ACCENT
	mark.custom_minimum_size = Vector2(3, fs(13))
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(mark)
	var l := label(Lang.t(text).to_upper(), 13, Color(ACCENT, 0.95))   # 1.1.15: сначала перевод, потом заглавные (раньше заголовки оставались русскими)
	if bool(st("bold_titles")):
		l.add_theme_font_override("font", bold())
	h.add_child(l)
	var line := HSeparator.new()
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(line)
	return h


static func label(text: String, size := 15, col := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs(size))
	l.add_theme_color_override("font_color", col)
	return l


static func small(text: String) -> Label:
	return label(text, 13, DIM)


static func title(text: String, size := 18) -> Label:
	var l := label(text, size, ACCENT)
	if bool(st("bold_titles")):
		l.add_theme_font_override("font", bold())
	return l


static func rich(text := "", size := 14) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.text = text
	r.add_theme_font_size_override("normal_font_size", fs(size))
	r.add_theme_font_size_override("bold_font_size", fs(size))
	r.add_theme_font_override("bold_font", bold())
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Галочка «Меньше растительности» — на виду в главном меню и в паузе: сразу убирает лишние растения, если игра лагает.
## Значок галочки: квадрат (или кружок) со светлой рамкой; включено — залит цветом акцента с белой галкой.
static func check_icon(on: bool, radio: bool, sz: int, disabled := false) -> ImageTexture:
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(sz, sz) * 0.5
	var r := sz * 0.5 - 1.0
	var bw := maxf(2.0, sz * 0.11)
	var frame := Color(0.85, 0.88, 0.95) if not disabled else Color(0.45, 0.47, 0.52)
	var fill := Color(0.05, 0.06, 0.09, 0.95)
	if on:
		fill = ACCENT if not disabled else Color(0.4, 0.4, 0.42)
		frame = ACCENT.lightened(0.25) if not disabled else Color(0.5, 0.5, 0.52)
	var rad := sz * (0.5 if radio else 0.2)
	for y in sz:
		for x in sz:
			var p := Vector2(x + 0.5, y + 0.5)
			var q := (p - c).abs() - Vector2(r - rad, r - rad)
			var d := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - rad
			if d > 0.5:
				continue
			var a := clampf(0.5 - d, 0.0, 1.0)
			var col := frame if d > -bw else fill
			img.set_pixel(x, y, Color(col, col.a * a))
	if on:
		var w := Color(1, 1, 1) if not disabled else Color(0.8, 0.8, 0.8)
		if radio:
			for y in sz:
				for x in sz:
					var dd := Vector2(x + 0.5, y + 0.5).distance_to(c)
					if dd < sz * 0.2:
						img.set_pixel(x, y, w)
		else:
			# галка: две линии толщиной ~12% размера
			var pts := [Vector2(0.24, 0.52), Vector2(0.42, 0.7), Vector2(0.77, 0.3)]
			var th := sz * 0.075
			for y in sz:
				for x in sz:
					var p2 := Vector2(x + 0.5, y + 0.5) / sz
					for k in 2:
						var a0: Vector2 = pts[k]
						var b0: Vector2 = pts[k + 1]
						var h := clampf((p2 - a0).dot(b0 - a0) / (b0 - a0).length_squared(), 0.0, 1.0)
						if (p2 - (a0 + (b0 - a0) * h)).length() * sz < th:
							img.set_pixel(x, y, w)
	return ImageTexture.create_from_image(img)


## Переключатель (CheckButton): дорожка со светлой рамкой и кружок; включено — дорожка цвета акцента, кружок справа.
static func switch_icon(on: bool, sz: int, disabled := false) -> ImageTexture:
	var w := sz * 2
	var img := Image.create(w, sz, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var r := sz * 0.5 - 1.0
	var frame := Color(0.85, 0.88, 0.95) if not disabled else Color(0.45, 0.47, 0.52)
	var track := ACCENT if on and not disabled else Color(0.05, 0.06, 0.09, 0.95)
	var knob_x := (w - sz * 0.5) if on else sz * 0.5
	for y in sz:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			var cx := clampf(p.x, sz * 0.5, w - sz * 0.5)
			var d := p.distance_to(Vector2(cx, sz * 0.5)) - r
			if d > 0.5:
				continue
			var col := frame if d > -maxf(2.0, sz * 0.1) else track
			if p.distance_to(Vector2(knob_x, sz * 0.5)) < r * 0.62:
				col = Color.WHITE if on else frame
			img.set_pixel(x, y, Color(col, clampf(0.5 - d, 0.0, 1.0) * col.a))
	return ImageTexture.create_from_image(img)


static func flora_toggle(font := 17) -> CheckBox:
	var cb := CheckBox.new()
	cb.text = DB.tx("flora_less", "Меньше растительности (если лагает)")
	cb.tooltip_text = "Возвращает прежнее, редкое количество цветов и травы — заметно легче для видеокарты.\nТо же самое: «Настройки» → «Графика»."
	cb.button_pressed = bool(Prefs.get_value("flora_less", false))
	cb.add_theme_font_size_override("font_size", font)
	cb.add_theme_color_override("font_color", ACCENT)
	cb.add_theme_color_override("font_pressed_color", ACCENT)
	cb.add_theme_color_override("font_hover_color", ACCENT.lightened(0.25))
	cb.toggled.connect(func(on: bool): Prefs.set_value("flora_less", on))
	return cb


static func button(text: String, cb: Callable, tip := "") -> Button:
	var b := TipButton.new()
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


static func bar(parent: Control, col: Color, h := 12.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(0, h)
	b.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	bg.set_corner_radius_all(4)
	var fg := StyleBoxFlat.new()
	fg.bg_color = col
	fg.set_corner_radius_all(4)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent:
		parent.add_child(b)
	return b


static func panel(opacity := 0.86) -> PanelContainer:
	var p := PanelContainer.new()
	if opacity != 0.86 and opacity < 0.999 * panel_color().a:
		var sb: StyleBoxFlat = theme().get_stylebox("panel", "PanelContainer").duplicate()
		sb.bg_color.a = opacity
		p.add_theme_stylebox_override("panel", sb)
	return p


static func hbox(sep := 6) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func vbox(sep := 6) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


static func clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


## Цветная иконка предмета: картинка (если есть) или кружок цвета предмета.
static func item_icon(id: String, size := 36) -> Control:
	if not DB.is_known(id):
		# ещё не найденный ресурс — знак вопроса
		var q := Panel.new()
		var qs := StyleBoxFlat.new()
		qs.bg_color = Color(0.12, 0.13, 0.16)
		qs.set_corner_radius_all(size / 2)
		qs.border_color = Color(1, 1, 1, 0.25)
		qs.set_border_width_all(2)
		q.add_theme_stylebox_override("panel", qs)
		q.custom_minimum_size = Vector2(size, size) * 0.8
		q.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ql := label("?", int(size * 0.5), Color(0.7, 0.72, 0.78))
		ql.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ql.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ql.set_anchors_preset(Control.PRESET_FULL_RECT)
		q.add_child(ql)
		var qc := CenterContainer.new()
		qc.custom_minimum_size = Vector2(size, size)
		qc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		qc.add_child(q)
		return qc
	var tex: Texture2D = ModelLib.item_icon(id)
	if tex == null:
		tex = Icons.get_icon("item:" + id)
	if tex:
		var r := TextureRect.new()
		r.texture = tex
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.custom_minimum_size = Vector2(size, size)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return r
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = DB.item_color(id)
	sb.set_corner_radius_all(size / 2)
	sb.border_color = Color(1, 1, 1, 0.35)
	sb.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(size, size) * 0.7
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var c := CenterContainer.new()
	c.custom_minimum_size = Vector2(size, size)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(p)
	return c


## Значок профессии: своя картинка или иконка, нарисованная из модели значка.
static func profession_icon(id: String, size := 48) -> Control:
	var p: Dictionary = DB.data.get("professions", {}).get(id, {})
	var tex: Texture2D = null
	if str(p.get("icon", "")) != "":
		tex = ModelLib.texture(str(p.icon))
	if tex == null and str(p.get("icon_model", "")) != "" and DB.data.models.has(str(p.icon_model)):
		tex = Icons.get_icon("model:" + str(p.icon_model))
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(size, size)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func building_icon(id: String, size := 56) -> Control:
	var tex := Icons.get_icon("building:" + id)
	if tex:
		var r := TextureRect.new()
		r.texture = tex
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.custom_minimum_size = Vector2(size, size)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return r
	var cat: String = DB.building(id).get("category", "")
	var col := DB.color(DB.data.categories.get(cat, {}).get("color", "#888888"))
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = col.darkened(0.3)
	sb.set_corner_radius_all(8)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(size, size)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static var _links := {}
static var _links_rev := -1


## Название станции крафта: «Руками», «Верстак», «Печь»…
static func station_name(st: String) -> String:
	if st == "hand":
		return "руками"
	for bid in DB.data.buildings:
		var d: Dictionary = DB.data.buildings[bid]
		if str(d.get("params", {}).get("station", "")) == st or bid == st:
			return str(d.get("name", bid))
	return st


## Откуда берётся предмет и куда идёт (кэш до следующей правки данных).
static func item_links(id: String) -> Dictionary:
	if _links_rev != DB.revision:
		_links.clear()
		_links_rev = DB.revision
	if _links.has(id):
		return _links[id]
	var made := []
	var used := []
	var builds := []
	var from := []
	for rid in DB.data.recipes:
		var r: Dictionary = DB.data.recipes[rid]
		if r.get("out", {}).has(id) and made.size() < 3:
			var sts: Array = r.get("stations", [])
			var where := ", ".join(sts.map(func(x): return station_name(str(x)))) if not sts.is_empty() else ""
			var ins: Dictionary = r.get("in", {})
			var parts := []
			for k in ins:
				parts.append("%d %s" % [int(ins[k]), DB.item_name(k)])
			made.append("%s → %d шт. за %s с%s" % [", ".join(parts), int(r.out[id]), str(snappedf(float(r.get("time", 1.0)), 0.1)), (" (" + where + ")") if where != "" else ""])
		if r.get("in", {}).has(id):
			for o in r.get("out", {}):
				var nm := DB.item_name(o)
				if not nm in used and used.size() < 6:
					used.append(nm)
	for bid in DB.data.buildings:
		if DB.data.buildings[bid].get("cost", {}).has(id) and builds.size() < 6:
			builds.append(str(DB.data.buildings[bid].get("name", bid)))
	for res in DB.data.resources:
		for dr in DB.data.resources[res].get("drops", []):
			if str(dr.get("item", "")) == id and from.size() < 4:
				var rn := str(DB.data.resources[res].get("name", res))
				if not rn in from:
					from.append(rn)
	for dp in DB.data.world.get("deposits", []):
		if dp is Dictionary and str(dp.get("item", "")) == id and from.size() < 5:
			var dn := "залежь (бур)"
			if not dn in from:
				from.append(dn)
	var out := {"made": made, "used": used, "builds": builds, "from": from}
	_links[id] = out
	return out


## Подсказка к предмету: что это, свойства, откуда берётся, куда идёт.
static func item_tip(id: String, n := 0) -> String:
	if not DB.is_known(id):
		return "Неизвестный ресурс\nНайдите его, чтобы узнать, что это"
	var it := DB.item(id)
	var t := "%s" % DB.t(str(it.get("name", id)))
	if str(it.get("category", "")) != "":
		t += "  ·  " + str(it.category)
	if str(it.get("desc", "")) != "":
		t += "\n" + Tutorial.keys(Lang.t(DB.t(str(it.desc))))   # A-4 r5: {key:…} → клавиша (после перевода)
	var rar: String = {"rare": "Редкий предмет", "epic": "Очень редкий предмет", "legendary": "Легендарный предмет"}.get(it.get("rarity", ""), "")
	if rar != "":
		t += "\n★ " + rar
	t += "\n"
	if n > 0:
		t += "\nВ ячейке: %d из %d" % [n, DB.stack_of(id)]
	else:
		t += "\nСтопка: до %d шт." % DB.stack_of(id)
	if it.has("food"):
		t += "\nСытость: +%d" % int(it.food)
	if it.has("water"):
		t += "\nВода: +%d" % int(it.water)
	if it.has("heal"):
		t += "\nЗдоровье: +%d" % int(it.heal)
	if it.has("fuel"):
		t += "\nТопливо: горит %d с" % int(it.fuel)
	if it.has("damage"):
		t += "\nУрон: %d" % int(it.damage)
	if it.has("range"):
		t += "\nДальность: %.1f м" % float(it.range)
	if it.has("durability"):
		t += "\nПрочность: %d" % int(it.durability)
	if int(it.get("outdoor_guard", 0)) > 0:
		t += "\nЗащищает: от %s" % ", ".join(it.get("guard_events", []).map(func(e): return str(DB.data.get("events", {}).get(e, {}).get("name", e))))
	if int(it.get("price", 0)) > 0:
		t += "\nЦена на станции: ~%d кр" % int(it.price)
	var ln := item_links(id)
	if not (ln.from.is_empty() and ln.made.is_empty() and ln.used.is_empty() and ln.builds.is_empty()):
		t += "\n"
	if not ln.from.is_empty():
		t += "\nДобывается: " + ", ".join(ln.from)
	for m in ln.made:
		t += "\nРецепт: " + str(m)
	if not ln.used.is_empty():
		t += "\nНужен для: " + ", ".join(ln.used)
	if not ln.builds.is_empty():
		t += "\nИдёт на стройку: " + ", ".join(ln.builds)
	if it.has("food") or it.has("water") or it.has("heal") or it.has("boost") or it.has("on_use"):
		t += "\n\nПКМ — использовать"
	if not DB.is_researched(id):
		t += "\n\n[не изучен] Отсканируйте %d шт. (окно «Сканер», клавиша I) — тогда его можно использовать в рецептах" % DB.scan_need(id)
	return t


## Подсказка к зданию: что делает, цифры, цена, размер.
static func building_tip(id: String) -> String:
	var d := DB.building(id)
	var pr: Dictionary = d.get("params", {})
	var cat: String = str(DB.data.categories.get(str(d.get("category", "")), {}).get("name", d.get("category", "")))
	var t := DB.t(str(d.get("name", id))) + ("  ·  " + cat if cat != "" else "")
	if str(d.get("desc", "")) != "":
		t += "\n" + DB.t(str(d.desc))
	t += "\n"
	var beh := str(d.get("behavior", ""))
	if pr.has("tier"):
		t += "\nУровень: Mk%d" % int(pr.tier)
	if beh == "miner":
		t += "\nДобыча: %d в минуту на нормальной залежи (×%s)" % [int(round(60.0 * float(pr.get("rate_mult", 1.0)))), str(pr.get("rate_mult", 1.0))]
	if beh in ["belt", "splitter", "merger"] and pr.has("per_min"):
		t += "\nПропускает: %d предметов в минуту" % int(pr.per_min)
	if beh == "crafter" and pr.has("speed"):
		t += "\nСкорость работы: ×%s" % str(pr.speed)
	var pw := float(pr.get("power", 0))
	if beh == "generator" and pw > 0:
		t += "\nДаёт энергии: %d" % int(pw)
	elif pw > 0:
		t += "\nПотребляет энергии: %d" % int(pw)
	if pr.has("damage"):
		t += "\nУрон: %d, дальность %d м" % [int(pr.damage), int(pr.get("range", 0))]
	if pr.has("slots"):
		t += "\nЯчеек: %d" % int(pr.slots)
	t += "\nПрочность: %d" % int(d.get("hp", 100))
	t += "\nРазмер: %d×%d клеток" % [int(d.get("size", 1)), int(d.get("size", 1))]
	var cost: Dictionary = d.get("cost", {})
	if not cost.is_empty():
		var parts := []
		for k in cost:
			parts.append("%d %s" % [int(cost[k]), DB.item_name(k)])
		t += "\nЦена: " + ", ".join(parts)
	return t


## Красивая подсказка из обычного текста: 1-я строка — заголовок («Имя  ·  раздел»),
## строки «Ключ: значение» — в две колонки, пустая строка — отступ, ★ — золотом, [не изучен] — красным.
static func tip_panel(text: String, icon: Control = null) -> Control:
	var v := vbox(3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lines := text.split("\n")
	if lines.is_empty():
		return v
	var head := hbox(10)
	if icon:
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(icon)
	var hv := vbox(0)
	var parts := lines[0].split("  ·  ")
	var tl := title(parts[0], 18)
	hv.add_child(tl)
	if parts.size() > 1:
		hv.add_child(label(" · ".join(parts.slice(1)), 13, DIM))
	head.add_child(hv)
	v.add_child(head)
	if lines.size() > 1:
		var line := ColorRect.new()
		line.color = Color(ACCENT, 0.5)
		line.custom_minimum_size = Vector2(0, 2)
		v.add_child(line)
	var wrap := 380.0 * SCALE
	for i in range(1, lines.size()):
		var ln: String = lines[i]
		if ln.strip_edges() == "":
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(0, 4)
			v.add_child(gap)
			continue
		var ci := ln.find(": ")
		if ci > 0 and ci < 30 and not ln.begins_with("[") and not ln.begins_with("🔒"):
			var row := hbox(8)
			var k := label(ln.substr(0, ci), 14, DIM)
			k.custom_minimum_size = Vector2(118 * SCALE, 0)
			k.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			row.add_child(k)
			var val := label(ln.substr(ci + 2), 14, TEXT)
			val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			val.custom_minimum_size = Vector2(minf(wrap - 118 * SCALE, maxf(60.0, text_w(ln.substr(ci + 2), 14))), 0)
			val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(val)
			v.add_child(row)
			continue
		var col := TEXT
		if ln.begins_with("★"):
			col = Color(1, 0.82, 0.35)
		elif ln.begins_with("[") or ln.begins_with("🔒") or ln.begins_with("Не хватает"):
			col = BAD
		elif ln.ends_with("— использовать") or ln.begins_with("ПКМ") or ln.begins_with("Клик") or ln.begins_with("Shift"):
			col = Color(0.6, 0.85, 1.0)
		var l := label(ln, 14, col)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(minf(wrap, text_w(ln, 14) + 4), 0)
		v.add_child(l)
	return v


## Ширина строки текста в пикселях (шрифт интерфейса).
static func text_w(text: String, size := 15) -> float:
	return ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs(size)).x


## Цена или рецепт значками: «[значок] Бревно 14/4». Зелёное — хватает, красное — не хватает.
## have(id) -> сколько есть; null — показать только «нужно».
static func cost_box(cost: Dictionary, have = null, icon := 22, where := "") -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 10)
	f.add_theme_constant_override("v_separation", 2)
	f.mouse_filter = Control.MOUSE_FILTER_PASS
	fill_cost(f, cost, have, icon, where)
	return f


static func fill_cost(f: Control, cost: Dictionary, have = null, icon := 22, where := "") -> void:
	clear(f)
	if cost.is_empty():
		f.add_child(label("Бесплатно", 13, GOOD))
		return
	for k in cost:
		var need := int(cost[k])
		var chip := hbox(3)
		chip.mouse_filter = Control.MOUSE_FILTER_PASS
		chip.add_child(item_icon(k, icon))
		var l := Label.new()
		l.add_theme_font_size_override("font_size", fs(13))
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tip := item_tip(k)
		if have is Callable:
			var h := int(have.call(k))
			l.text = "%s %d/%d" % [DB.item_name(k), h, need]
			l.add_theme_color_override("font_color", GOOD if h >= need else BAD)
			tip += "\n\nЕсть: %d%s · нужно: %d%s" % [h, where, need, ("" if h >= need else "  (не хватает %d)" % (need - h))]
		else:
			l.text = "%s ×%d" % [DB.item_name(k), need]
			l.add_theme_color_override("font_color", TEXT)
		chip.add_child(l)
		chip.tooltip_text = tip
		f.add_child(chip)


static func cost_text(cost: Dictionary, have: Callable) -> String:
	var parts := []
	for k in cost:
		var ok: bool = have.call(k) >= int(cost[k])
		parts.append("[color=%s]%d %s[/color]" % ["#e8edf5" if ok else "#ff6b5a", int(cost[k]), DB.item_name(k)])
	return ", ".join(parts)


## Иконка окна игры из настроек проекта (поле «Иконка игры» в редакторе).
static func apply_game_icon() -> void:
	var rel := str(DB.project.get("icon", ""))
	if rel == "":
		return
	var full := DB.find_file(rel)
	var img := Image.load_from_file(full) if FileAccess.file_exists(full) else null
	if img != null and not img.is_empty():
		DisplayServer.set_icon(img)
