extends Node3D
## Карта потоков (клавиша L): поверх базы цветом видно, где производство стоит и почему.
##  • лента: зелёная — едет, красная — предмет застрял (дальше некуда), серая — пустая;
##  • машина: зелёная — работает, жёлтая — ждёт сырьё, красная — выход забит, фиолетовая — нет энергии;
##  • труба: голубая — есть жидкость, серая — пустая.
## Вверху — сводка, сколько чего. Цвета и дальность — «Данные → Настройки».

var game
var on := false
var marks: Array = []      # [мир, размер в метрах, цвет, поломка?]
var canvas: Control
var label: Label
var layer: CanvasLayer
var _acc := 0.0
var counts := {}


func _init(g) -> void:
	game = g


func _ready() -> void:
	layer = CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	# метки рисуются поверх картинки: кружок или квадрат над зданием, размер — по расстоянию до камеры
	canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.visible = false
	canvas.draw.connect(_draw_marks)
	layer.add_child(canvas)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 150)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.1, 0.8)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	layer.add_child(panel)
	label = Label.new()
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	panel.visible = false
	panel.add_child(label)


func toggle() -> void:
	on = not on
	canvas.visible = on
	label.get_parent().visible = on
	_acc = 99.0
	if on:
		refresh()


func _col(key: String, def: String) -> Color:
	return DB.color(DB.setting(key, def))


## Что с этим зданием: ok | stuck | starve | blocked | nopower | empty | fluid. Пусто — не показываем.
func state_of(b) -> String:
	var f = game.factory
	match b.beh:
		"belt":
			if b.item == "":
				return "empty"
			return "stuck" if f.sim_time > b.t_in + b.period * 3.0 + 0.3 else "ok"
		"pipe":
			return "fluid" if b.famt > 0.01 else "empty"
		"miner", "crafter":
			if float(b.p("power", 0)) > 0.0 and (b.net < 0 or float(f.net_info(b).get("sat", 1.0)) < 0.3):
				return "nopower"
			if b.active:
				return "ok"
			if b.out != null and not b.out.is_empty():
				return "blocked"
			return "starve"
		"generator":
			return "ok" if b.active else "starve"
	return ""


func refresh() -> void:
	var f = game.factory
	var center: Vector3 = game.player.position
	var rng := float(DB.setting("flow_range", 120.0))
	var cols := {"ok": _col("flow_ok", "#3ddc6a"), "stuck": _col("flow_stuck", "#ff3b30"), "blocked": _col("flow_stuck", "#ff3b30"),
		"starve": _col("flow_starve", "#ffd23a"), "nopower": _col("flow_nopower", "#b06bff"), "fluid": _col("flow_fluid", "#46b8ff"), "empty": _col("flow_empty", "#80868f")}
	marks.clear()
	counts = {"stuck": 0, "starve": 0, "blocked": 0, "nopower": 0, "ok": 0}
	for b in f.all:
		if b.dead:
			continue
		var c: Vector3 = b.center()
		if World.delta(center, c).length() > rng:
			continue
		var st := state_of(b)
		if st == "" or (st == "empty" and not bool(DB.setting("flow_show_empty", false))):
			continue
		if counts.has(st):
			counts[st] += 1
		var col: Color = cols[st]
		var s := float(b.size) * World.C
		var small: bool = b.beh in ["belt", "pipe"]
		col.a = 0.45 if st == "empty" else 0.85
		marks.append([Vector3(c.x, b.y + (0.5 if small else 1.5), c.z), s * (0.45 if small else 0.7), col, st in ["stuck", "blocked", "starve", "nopower"]])
		if marks.size() >= 6000:
			break
	canvas.queue_redraw()
	label.text = "Карта потоков (L — скрыть)\n[красный] застряло на лентах: %d\n[жёлтый] ждут сырьё: %d\n[красный] выход забит: %d\n[фиолетовый] без энергии: %d\n[зелёный] работают: %d" % [
		counts.stuck, counts.starve, counts.blocked, counts.nopower, counts.ok]


func _draw_marks() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var vp := canvas.get_viewport_rect().size
	var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.008)
	for m in marks:
		var p: Vector3 = m[0]
		if cam.is_position_behind(p):
			continue
		var sp := cam.unproject_position(p)
		if sp.x < -40 or sp.y < -40 or sp.x > vp.x + 40 or sp.y > vp.y + 40:
			continue
		# радиус: размер здания в метрах → пиксели на этом расстоянии
		var edge := cam.unproject_position(p + cam.global_transform.basis.x * float(m[1]))
		var r := clampf(sp.distance_to(edge), 3.0, 60.0)
		var col: Color = m[2]
		if m[3]:
			r *= pulse + 0.25
		canvas.draw_circle(sp, r, Color(col.r, col.g, col.b, col.a * 0.55))
		canvas.draw_arc(sp, r, 0.0, TAU, 24, Color(col.r, col.g, col.b, 1.0), 2.0, true)


func _process(delta: float) -> void:
	if not on:
		return
	canvas.queue_redraw()
	_acc += delta
	if _acc >= 0.4:
		_acc = 0.0
		refresh()
