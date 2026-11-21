class_name TipCard
extends PanelContainer
## Карточка-строка (рецепт, товар): тёмная плашка, при наведении светлеет; подсказка с картинкой.

var tip_item := ""        # предмет для значка в подсказке
var tip_building := ""    # или здание
var _st: StyleBoxFlat
var _st_h: StyleBoxFlat


func _init() -> void:
	_st = UI.box(Color(1, 1, 1, 0.035), maxi(0, int(UI.st("radius")) - 3))
	_st.set_content_margin_all(8)
	_st.border_color = Color(1, 1, 1, 0.06)
	_st.set_border_width_all(1)
	_st_h = _st.duplicate()
	_st_h.bg_color = Color(1, 1, 1, 0.07)
	_st_h.border_color = Color(UI.ACCENT, 0.6)
	add_theme_stylebox_override("panel", _st)
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_entered.connect(func(): add_theme_stylebox_override("panel", _st_h))
	mouse_exited.connect(func(): add_theme_stylebox_override("panel", _st))


func _make_custom_tooltip(for_text: String) -> Object:
	if not bool(UI.st("rich_tips")) or for_text == "":
		return null
	var ic: Control = null
	if tip_item != "":
		ic = UI.item_icon(tip_item, 48)
	elif tip_building != "":
		ic = UI.building_icon(tip_building, 56)
	return UI.tip_panel(for_text, ic)
