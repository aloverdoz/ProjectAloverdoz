extends Player
## Герой другого игрока в сетевой игре: модель как у своего героя, ник и цвет над головой.
## Положение, взгляд и действия приходят по сети (net.gd), анимация считается здесь же.
## У хозяина по такому герою бьют монстры — урон уходит его игроку.

var peer := 0
var seat := 0   # B-5 r8: 1 — второй игрок сплитскрина этого подключения
var nick := ""
var tint := Color(1, 0.6, 0.25)
var net_pos := Vector3.INF
var net_yaw := 0.0
var last_inv: Array = []
var label: Label3D
var _py := 0.0
# 1.5: плавное движение — положения копятся с метками времени отправителя, герой показывается
# чуть «в прошлом» (INTERP_MS) и идёт ровно между двумя полученными точками, а не рывками к последней
const INTERP_MS := 110.0
var _snaps: Array = []        # [время отправителя мс, положение, поворот]
var _offset := 0.0            # наше время минус время отправителя (наименьшее увиденное — без сетевой задержки)
var _offset_ok := false


func push_snap(pos: Vector3, yaw: float, ts: int) -> void:
	if ts <= 0:
		_snaps.clear()
		return
	var now := float(Time.get_ticks_msec())
	var off := now - float(ts)
	if not _offset_ok or off < _offset:
		_offset = off
		_offset_ok = true
	else:
		_offset += (off - _offset) * 0.01   # часы могут чуть «плыть» — подтягиваемся медленно
	if not _snaps.is_empty() and float(ts) <= float(_snaps[-1][0]):
		return
	_snaps.append([float(ts), pos, yaw])
	if _snaps.size() > 30:
		_snaps.pop_front()


func _follow_snaps() -> void:
	var rt := float(Time.get_ticks_msec()) - _offset - INTERP_MS   # время отправителя, которое показываем
	while _snaps.size() > 2 and float(_snaps[1][0]) <= rt:
		_snaps.pop_front()
	var a: Array = _snaps[0]
	var target: Vector3
	if _snaps.size() == 1 or rt <= float(a[0]):
		target = a[1]
	else:
		var b: Array = _snaps[1]
		var span := maxf(1.0, float(b[0]) - float(a[0]))
		var k := (rt - float(a[0])) / span
		var d: Vector3 = World.delta(a[1], b[1])
		if d.length() > 8.0:
			target = b[1] if k >= 0.5 else a[1]
		else:
			# за последней точкой — немного «вперёд» (до 0.25 с), пока не придёт следующая
			target = a[1] + d * clampf(k, 0.0, 1.0 + 250.0 / span)
	var dd: Vector3 = World.delta(position, target)
	position = target if dd.length() > 8.0 else position + dd


func setup_label() -> void:
	label = Label3D.new()
	label.text = nick
	label.modulate = tint
	label.outline_modulate = Color(0, 0, 0, 0.9)
	label.outline_size = 10
	label.font_size = 56
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = Vector3(0, 3.0, 0)
	add_child(label)
	# цвет игрока вместо цвета профессии (люди-герои не красятся — их узнают по нику)
	if float(ModelLib.model(model_id).get("prof_tint", 1.0)) <= 0.0:
		return
	for bp in body_parts:
		(bp[0] as MultiMesh).set_instance_color(0, tint)
		bp[1] = tint


func damage(x: float) -> void:
	if Net.is_host() and alive and not game.strategy:
		Net._self().rpc_id(peer, "hurt", x, seat)


func _process(delta: float) -> void:
	if game == null:
		return
	t += delta
	if not _snaps.is_empty():
		_follow_snaps()
	elif net_pos != Vector3.INF:
		var d: Vector3 = World.delta(position, net_pos)
		position = net_pos if d.length() > 8.0 else position + d * minf(1.0, delta * 12.0)
	if not alive or game.strategy:
		visible = false   # 1.1.15: в стратегии героев нет — только точки обзора камер
		return
	visible = true
	# прыжок другого игрока: высоту над опорой и скорость вверх-вниз видно по его положению
	var h: float = position.y - support(position)
	vel_y = lerpf(vel_y, (position.y - _py) / maxf(delta, 0.001), minf(1.0, delta * 10.0))
	_py = position.y
	var was := airborne
	airborne = h > 0.3
	jump_y = maxf(0.0, h)
	if was and not airborne:
		_land_k = clampf((-vel_y - 3.0) / 14.0, 0.15, 1.0)
		_land_t = 0.0
	_animate(delta, Vector2(move_dir.x, move_dir.z).length() > float(DB.setting("player_speed", 9.0)) + 1.0)
	# 1.7: свои модели (GLB со своими анимациями и авто-скелет) у других игроков тоже ходят и бегают, а не «плывут»
	_glb_update(delta)
	_sync_skin()
