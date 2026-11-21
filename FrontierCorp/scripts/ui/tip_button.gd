class_name TipButton
extends Button
## Кнопка с красивой подсказкой: заголовок, строки «Название: значение», цветные пометки.
## Плюс «живость»: чуть растёт под мышью, проседает при нажатии и тихо щёлкает.

const HOVER := 1.04
const PRESS := 0.95

var _tw: Tween
var _hover := false


func _ready() -> void:
	resized.connect(_centre_pivot)
	mouse_entered.connect(func(): _hover = true; _to(HOVER))
	mouse_exited.connect(func(): _hover = false; _to(1.0))
	button_down.connect(_on_down)
	button_up.connect(func(): _to(HOVER if _hover else 1.0))
	_centre_pivot()


func _make_custom_tooltip(for_text: String) -> Object:
	return UI.tip_panel(for_text) if bool(UI.st("rich_tips")) else null


func _centre_pivot() -> void:
	pivot_offset = size * 0.5


## Плавно к нужному масштабу. Выключенная кнопка не шевелится (но всегда возвращается к 1).
func _to(s: float) -> void:
	if disabled and s != 1.0:
		return
	if _tw and _tw.is_valid():
		_tw.kill()
	if not is_inside_tree() or scale.is_equal_approx(Vector2.ONE * s):
		scale = Vector2.ONE * s
		return
	_tw = create_tween()
	_tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tw.tween_property(self, "scale", Vector2.ONE * s, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_down() -> void:
	_to(PRESS)
	_click()


## Тихий щелчок через звуки игры. В меню (нет узла игры со звуками) — просто молчим.
func _click() -> void:
	var g = get_tree().current_scene if is_inside_tree() else null
	if g == null or not ("sfx" in g) or g.sfx == null:
		return
	var s = g.sfx
	s.play_ui("click")
	# этот же щелчок часто звучит и из обработчика кнопки — свой делаем потише, чтобы не было «двойного»
	if "pool2d" in s and "pool2_i" in s and not s.pool2d.is_empty():
		var p = s.pool2d[(int(s.pool2_i) - 1 + s.pool2d.size()) % s.pool2d.size()]
		if p is AudioStreamPlayer and p.playing:
			p.volume_db -= 8.0
