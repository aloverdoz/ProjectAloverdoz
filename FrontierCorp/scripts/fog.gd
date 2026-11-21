extends RefCounted
## Исследование и туман войны (14.7): карта и миникарта открываются там, где побывал герой.
## Радары (здания с «Радар: радиус») открывают округу, дрон-разведчик летит вперёд и открывает полосу.
## Неоткрытое на карте тёмное, гнёзда и монстры там не видны. Включается модулем «Туман войны».

const TILE := 8.0            # метров на клетку тумана

var game
var res := 0
var bits := PackedByteArray()
var img: Image
var tex: ImageTexture
var dirty := false
var _up_t := 0.0
var _t := 0.0
var _radar_t := 0.0
var scouts: Array = []       # {node, pos, dir, left, r, speed}


func _init(g) -> void:
	game = g


func on() -> bool:
	return game.module("fog")


func setup() -> void:
	var wm: float = game.world.W * World.C
	res = maxi(1, ceili(wm / TILE))
	bits = PackedByteArray()
	bits.resize(res * res)
	bits.fill(0)
	img = Image.create_from_data(res, res, false, Image.FORMAT_L8, bits)
	tex = ImageTexture.create_from_image(img)
	if game.factory and game.factory.hq:
		reveal(game.factory.hq.center(), float(DB.setting("fog_start_radius", 70.0)))


func _idx(x: int, z: int) -> int:
	if game.world.wrap:
		x = posmod(x, res)
		z = posmod(z, res)
	elif x < 0 or z < 0 or x >= res or z >= res:
		return -1
	return z * res + x


func explored(p: Vector3) -> bool:
	if not on() or res == 0:
		return true
	var i := _idx(floori(p.x / TILE), floori(p.z / TILE))
	return i < 0 or bits[i] > 0


## Открыть круг радиусом r метров.
func reveal(p: Vector3, r: float) -> int:
	if res == 0:
		return 0
	var cx := floori(p.x / TILE)
	var cz := floori(p.z / TILE)
	var rt := ceili(r / TILE)
	var n := 0
	for dz in range(-rt, rt + 1):
		for dx in range(-rt, rt + 1):
			if dx * dx + dz * dz > rt * rt:
				continue
			var i := _idx(cx + dx, cz + dz)
			if i >= 0 and bits[i] == 0:
				bits[i] = 255
				n += 1
	if n > 0:
		dirty = true
	return n


## Доля открытой карты 0..1.
func explored_share() -> float:
	if res == 0:
		return 1.0
	var n := 0
	for b in bits:
		if b > 0:
			n += 1
	return float(n) / float(bits.size())


func update(dt: float) -> void:
	if not on() or res == 0:
		return
	_t += dt
	if _t >= 0.25:
		_t = 0.0
		var r := float(DB.setting("fog_reveal_radius", 45.0))
		reveal(game.player.position, r)
		for pl in game.hit_targets():   # A-7 r6: оба героя сплитскрина и гости
			if pl != null and is_instance_valid(pl) and pl != game.player:
				reveal(pl.position, r)
	_radar_t -= dt
	if _radar_t <= 0.0:
		_radar_t = 2.0
		for b in game.factory.all:
			var rr := float(b.p("radar_radius", 0.0))
			if rr > 0.0 and not b.dead and (not game.factory.is_electric(b) or game.factory.sat_c(b) > 0.0):
				reveal(b.center(), rr * World.C)
	for s in scouts.duplicate():
		var step: float = s.speed * dt
		s.pos += s.dir * step
		s.left -= step
		s.pos.y = game.world.height_at(s.pos) + 10.0
		if is_instance_valid(s.node):
			s.node.position = s.pos
			s.node.rotation.y = atan2(-s.dir.z, s.dir.x)
		reveal(s.pos, s.r)
		if s.left <= 0.0:
			if is_instance_valid(s.node):
				s.node.queue_free()
			scouts.erase(s)
	_up_t += dt
	if dirty and _up_t > 0.4:
		_up_t = 0.0
		dirty = false
		img.set_data(res, res, false, Image.FORMAT_L8, bits)
		tex.update(img)


## Дрон-разведчик: летит от героя туда, куда смотрит камера, и открывает полосу карты.
func launch_scout(from: Vector3, dir: Vector3, dist := 0.0, r := 0.0) -> void:
	dir.y = 0.0
	if dir.length() < 0.01:
		dir = Vector3.FORWARD
	var node: Node3D = ModelLib.make_node("drone_carrier")
	game.add_child(node)
	scouts.append({"node": node, "pos": from + Vector3(0, 8, 0), "dir": dir.normalized(),
		"left": dist if dist > 0.0 else float(DB.setting("scout_dist", 320.0)), "r": r if r > 0.0 else float(DB.setting("scout_radius", 40.0)),
		"speed": float(DB.setting("scout_speed", 30.0))})
	game.notify("Разведчик полетел вперёд", Color(0.6, 0.9, 1.0))


func to_dict() -> Dictionary:
	if res == 0:
		return {}
	var packed := bits.compress(FileAccess.COMPRESSION_DEFLATE)
	return {"res": res, "size": bits.size(), "data": Marshalls.raw_to_base64(packed)}


func from_dict(d: Dictionary) -> void:
	if res == 0 or int(d.get("res", 0)) != res:
		return
	var raw := Marshalls.base64_to_raw(str(d.get("data", "")))
	var b := raw.decompress(int(d.get("size", 0)), FileAccess.COMPRESSION_DEFLATE)
	if b.size() == bits.size():
		bits = b
		dirty = true
