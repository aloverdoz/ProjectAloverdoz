class_name Stripes
extends Control
## Косые полоски на заголовке окна (как предупреждающая разметка на заводе).


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


func _draw() -> void:
	var w := minf(160.0, size.x * 0.25)
	var x0 := size.x - w - 56.0
	if x0 < size.x * 0.45:
		return
	var h := size.y
	var col := Color(0, 0, 0, 0.16)
	var step := 14.0
	var x := x0
	while x < x0 + w:
		var pts := PackedVector2Array([Vector2(x, h), Vector2(x + 7, h), Vector2(x + 7 + h * 0.6, 0), Vector2(x + h * 0.6, 0)])
		draw_colored_polygon(pts, col)
		x += step
