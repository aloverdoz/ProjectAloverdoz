extends Node
## 1.3: геймпад (автозагрузка «Pad»). Левый стик — ходьба, правый — курсор (им же целиться и строить),
## курки — левая/правая кнопка мыши, A — прыжок (в окнах — щелчок), X — взаимодействие, B — назад/Esc,
## Y — стройка, Back — рюкзак, Start — пауза, LB/RB — быстрые слоты, крестовина — поворот камеры и приближение,
## правый стик нажатием — повернуть здание, левый — бег.
## Сплитскрин: Start на втором геймпаде во время игры — второй игрок (split.gd делит экран этой же копии игры).
## У второго игрока свой экземпляр этого скрипта (seat = 1): его стик и кнопки не трогают общие действия ввода,
## а идут в его героя (move, sprint_on, jump_just), его искусственная мышь помечена device = MARK + 1.

signal join_request(dev: int)

const DEAD := 0.22
const MARK := 77            # device у наших искусственных событий мыши

var device := 0             # чей геймпад слушает (-1 — никакой, только клавиатура и мышь)
var seat := 0               # 0 — первый игрок (автозагрузка), 1 — второй игрок сплитскрина
var move := Vector2.ZERO    # второй игрок: стик ходьбы
var sprint_on := false
var jump_just := false      # второй игрок: прыжок нажат (герой сбрасывает, когда прочитал)
var cam_l := false
var cam_r := false
var fake_pads: Array = []  # для автотеста: геймпады, которых нет в системе
var claim_next := false     # «Добавить игрока»: следующий Start с любого геймпада — второй игрок
var cursor := Vector2(800, 450)
var active := false         # геймпадом пользовались недавно: курсор виден, игра целится в него
var _idle := 0.0
var _prev := {}             # кнопка -> была нажата
var _lt := false
var _rt := false
var _sprint := false
var _a_click := false
var _moving := {}
var _layer: CanvasLayer
var _cur: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if seat == 0:
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--pad="):
				device = int(a.substr(6))
	_layer = CanvasLayer.new()
	_layer.layer = 128
	add_child(_layer)
	_cur = Cursor.new()
	_cur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cur.visible = false
	_layer.add_child(_cur)
	var vs := get_viewport().get_visible_rect().size
	cursor = vs * 0.5


class Cursor extends Control:
	func _draw() -> void:
		var pts := PackedVector2Array([Vector2(0, 0), Vector2(0, 22), Vector2(6, 17), Vector2(10, 26), Vector2(14, 24), Vector2(10, 16), Vector2(17, 16)])
		draw_colored_polygon(pts, Color(1.0, 0.72, 0.3))
		pts.append(pts[0])
		draw_polyline(pts, Color(0.1, 0.05, 0.0), 2.0, true)


## Настоящая мышь сдвинулась — снова играем мышью (курсор геймпада прячется).
func _input(ev: InputEvent) -> void:
	if seat == 0 and active and ev is InputEventMouseMotion and ev.device != MARK and ev.device != MARK + 1 and (ev as InputEventMouseMotion).relative.length() > 3.0:
		_set_active(false)
		_idle = 0.0


## Позиция «мыши» для игры: курсор геймпада, если им пользуются, иначе настоящая мышь.
func mouse_pos(vp: Viewport) -> Vector2:
	return cursor if active else vp.get_mouse_position()


func _game():
	var cs = get_tree().current_scene
	return cs if cs != null and cs.has_method("hot_select") and cs.get("player") != null else null


func _split(g):
	return g.split if g != null and g.get("split") != null and g.split.active else null


func _win_open(g) -> bool:
	if g == null:
		return true
	var sp = _split(g)
	var h = sp.hud_of(seat) if sp != null else g.hud
	return (h != null and h.any_window_open()) or g.get("paused") == true


## Действие в игре за своё место (в сплитскрине у второго игрока свои герой, окна и камера).
func _do(g, f: Callable) -> void:
	var sp = _split(g)
	if sp != null:
		sp.with_seat(seat, f)
	else:
		f.call()


var _now := {}

## Кнопка нажата в этом кадре (снимок кнопок делает _snap раз за кадр).
func _just(dev: int, b: int) -> bool:
	var k := dev * 100 + b
	return bool(_now.get(k, false)) and not bool(_prev.get(k, false))


func _up(dev: int, b: int) -> bool:
	var k := dev * 100 + b
	return bool(_prev.get(k, false)) and not bool(_now.get(k, false))


func _snap(pads: Array) -> void:
	_prev = _now
	_now = {}
	for d in pads:
		for b in 15:
			if Input.is_joy_button_pressed(d, b):
				_now[d * 100 + b] = true


func _process(delta: float) -> void:
	var pads := Input.get_connected_joypads()
	for d in fake_pads:
		if not d in pads:
			pads.append(d)
	_snap(pads)
	# Start на «чужом» геймпаде — второй игрок (только в игре и только у первого игрока)
	var g0 = _game()
	if seat == 0 and not (_split(g0) != null):
		for d in pads:
			if (d != device or claim_next) and _just(d, JOY_BUTTON_START):
				if _game() != null:
					if claim_next:
						claim_next = false
						if d == device:
							device = -1    # первый игрок остаётся на клавиатуре и мыши
					join_request.emit(d)
	if device < 0 or not device in pads:
		_idle += delta
		if active and _idle > 0.1:
			_set_active(false)
		return
	_pad(device, delta)


func _set_active(on: bool) -> void:
	active = on
	_cur.visible = on
	if not on:
		_release_moves()


func _release_moves() -> void:
	move = Vector2.ZERO
	sprint_on = false
	cam_l = false
	cam_r = false
	for a in _moving:
		Input.action_release(a)
	_moving.clear()
	if _sprint:
		Input.action_release("sprint")
		_sprint = false


func _stick(dev: int, ax: int, ay: int) -> Vector2:
	var v := Vector2(Input.get_joy_axis(dev, ax), Input.get_joy_axis(dev, ay))
	var l := v.length()
	if l < DEAD:
		return Vector2.ZERO
	return v / l * minf(1.0, (l - DEAD) / (1.0 - DEAD))


func _pad(dev: int, delta: float) -> void:
	var g = _game()
	var in_ui := _win_open(g)
	var ls := _stick(dev, JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)
	var rs := _stick(dev, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y)
	var lt := Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_LEFT) > 0.5
	var rt := Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_RIGHT) > 0.5
	var any := ls != Vector2.ZERO or rs != Vector2.ZERO or lt or rt
	for b in 15:
		if _now.has(dev * 100 + b):
			any = true
	if any:
		_idle = 0.0
		if not active:
			_set_active(true)
	else:
		_idle += delta
	if not active:
		return
	# курсор: правый стик (в меню и окнах — и левый)
	var vs := get_viewport().get_visible_rect().size
	var area := Rect2(Vector2.ZERO, vs)
	var sp = _split(g)
	if sp != null:
		area = sp.rect(seat)
	if not area.has_point(cursor):
		cursor = area.get_center()
	var mv := rs
	if in_ui:
		mv = rs if rs.length() > ls.length() else ls
	if mv != Vector2.ZERO:
		var spd := vs.y * 1.15 * pow(mv.length(), 1.6)
		var old := cursor
		cursor = (cursor + mv.normalized() * spd * delta).clamp(area.position, area.end - Vector2.ONE)
		_motion(cursor - old)
	_cur.position = cursor
	# ходьба (в игре и без открытых окон)
	var want := {}
	if g != null and not in_ui:
		if ls.x < 0.0: want["move_left"] = -ls.x
		if ls.x > 0.0: want["move_right"] = ls.x
		if ls.y < 0.0: want["move_up"] = -ls.y
		if ls.y > 0.0: want["move_down"] = ls.y
	if seat == 1:
		move = ls if g != null and not in_ui else Vector2.ZERO
		if sprint_on and ls == Vector2.ZERO:
			sprint_on = false
	else:
		for a in _moving.keys():
			if not want.has(a):
				Input.action_release(a)
				_moving.erase(a)
		for a in want:
			Input.action_press(a, want[a])
			_moving[a] = true
		if _sprint and ls == Vector2.ZERO:
			Input.action_release("sprint")
			_sprint = false
	# курки — кнопки мыши
	if rt != _rt:
		_rt = rt
		_click(MOUSE_BUTTON_LEFT, rt)
	if lt != _lt:
		_lt = lt
		_click(MOUSE_BUTTON_RIGHT, lt)
	# кнопки
	if _just(dev, JOY_BUTTON_A):
		_a_click = in_ui
		if in_ui:
			_click(MOUSE_BUTTON_LEFT, true)
		elif seat == 1:
			jump_just = true
		else:
			Input.action_press("jump")
	if _up(dev, JOY_BUTTON_A):
		if _a_click:
			_click(MOUSE_BUTTON_LEFT, false)
		_a_click = false
		if seat == 0:
			Input.action_release("jump")
	if _just(dev, JOY_BUTTON_X):
		if in_ui:
			_click(MOUSE_BUTTON_RIGHT, true)
			_click(MOUSE_BUTTON_RIGHT, false)
		elif g != null:
			_do(g, func(): g._action("interact"))
	if _just(dev, JOY_BUTTON_B) or _just(dev, JOY_BUTTON_START):
		_key(KEY_ESCAPE)
	if g != null:
		if _just(dev, JOY_BUTTON_Y):
			_do(g, func(): g._action("build_menu"))
		if _just(dev, JOY_BUTTON_BACK):
			_do(g, func(): g._action("inventory"))
		if _just(dev, JOY_BUTTON_LEFT_SHOULDER):
			_do(g, func(): g.hot_select(posmod(g.player.selected - 1, Player.hot_n()), true))
		if _just(dev, JOY_BUTTON_RIGHT_SHOULDER):
			_do(g, func(): g.hot_select(posmod(g.player.selected + 1, Player.hot_n()), true))
		if _just(dev, JOY_BUTTON_RIGHT_STICK):
			_do(g, func(): g._action("rotate"))
		if _just(dev, JOY_BUTTON_LEFT_STICK) and ls != Vector2.ZERO:
			if seat == 1:
				sprint_on = true
			else:
				_sprint = true
				Input.action_press("sprint")
		if Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_UP):
			_do(g, func(): g.cam_dist_target = maxf(12.0, g.cam_dist_target * (1.0 - 1.2 * delta)))
		if Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_DOWN):
			_do(g, func(): g.cam_dist_target = minf(g.cam_max, g.cam_dist_target * (1.0 + 1.2 * delta)))
		if seat == 1:
			cam_l = Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_LEFT)
			cam_r = Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_RIGHT)
		else:
			for e in [[JOY_BUTTON_DPAD_LEFT, "cam_left"], [JOY_BUTTON_DPAD_RIGHT, "cam_right"]]:
				if _just(dev, e[0]):
					Input.action_press(e[1])
				elif _up(dev, e[0]) and not _key_held(e[1]):
					Input.action_release(e[1])


## Клавиша действия зажата на настоящей клавиатуре (тогда крестовина не отпускает её).
func _key_held(act: String) -> bool:
	for e in InputMap.action_get_events(act):
		if e is InputEventKey and Input.is_physical_key_pressed((e as InputEventKey).physical_keycode):
			return true
	return false


func _mask() -> int:
	return (MOUSE_BUTTON_MASK_LEFT if _rt or _a_click else 0) | (MOUSE_BUTTON_MASK_RIGHT if _lt else 0)


func _motion(rel: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.device = MARK + seat
	e.position = cursor
	e.global_position = cursor
	e.relative = rel
	e.button_mask = _mask()
	Input.parse_input_event(e)


func _click(btn: int, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.device = MARK + seat
	e.button_index = btn
	e.pressed = pressed
	e.position = cursor
	e.global_position = cursor
	e.button_mask = _mask()
	Input.parse_input_event(e)


func _key(k: int) -> void:
	for p in [true, false]:
		var e := InputEventKey.new()
		e.device = MARK + seat
		e.keycode = k
		e.physical_keycode = k
		e.pressed = p
		Input.parse_input_event(e)
