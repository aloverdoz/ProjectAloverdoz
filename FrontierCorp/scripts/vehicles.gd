extends RefCounted
## Машины: здание с поведением «vehicle». Стоит на земле как обычное здание (можно разобрать),
## E рядом — сесть и ехать (скорость — параметр «speed»), E ещё раз — выйти и припарковать.

var game
var driving := ""          # тип машины, в которой сидит герой ("" — пешком)
var node: Node3D
var yaw := 0.0
var _parked_hp := 0.0
var _paid = null   # A-7 r3: сколько реально заплачено за машину (возвращается при разборке)
var driver = null  # A-1 r6: кто за рулём (в сплитскрине героев двое)


func _init(g) -> void:
	game = g


func is_driver(pl) -> bool:
	return driving != "" and pl != null and _drv() == pl   # A-3 r7: без водителя за рулём — только первый герой


func _drv():
	if driver != null and is_instance_valid(driver):
		return driver
	return game.split.p1() if game.split != null and game.split.active else game.player


func speed_mult(pl = null) -> float:
	if driving == "" or (pl != null and not is_driver(pl)):
		return 1.0
	return float(DB.bparam(driving, "speed", 2.5))


## Сесть в машину-здание b.
func enter(b) -> bool:
	if driving != "" or b == null or b.beh != "vehicle":
		return false
	driving = b.type
	driver = game.player
	_parked_hp = b.hp
	_paid = b.paid.duplicate() if b.paid is Dictionary else null
	yaw = -b.dir * PI * 0.5
	game.player.position = b.center()
	game.factory.remove(b)
	_make_node()
	game.player.hips.visible = false
	game.notify("%s: WASD — ехать, E — выйти" % DB.building(driving).get("name", driving), Color(0.6, 0.9, 1.0))
	game.sfx.play("place", game.player.position)
	return true


## Выйти: машина встаёт зданием на клетку под героем (или рядом).
func leave() -> bool:
	if driving == "":
		return false
	var cell: Vector2i = World.world_to_cell(_drv().position)
	var dir := posmod(roundi(-yaw / (PI * 0.5)), 4)
	var spot := Vector2i(-99999, 0)
	for r in 3:
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				var c := World.wc(cell + Vector2i(dx, dz))
				if spot.x == -99999 and game.factory.can_place(driving, c) == "":
					spot = c
	if spot.x == -99999:
		game.notify("Здесь не припарковаться — нужно свободное ровное место", Color(1, 0.7, 0.4))
		return false
	var b = game.factory.place(driving, spot, dir)
	b.hp = minf(b.hp, _parked_hp) if _parked_hp > 0.0 else b.hp
	b.paid = _paid.duplicate() if _paid is Dictionary else DB.building(driving).get("cost", {}).duplicate()
	_paid = null
	var dp = _drv()
	driving = ""
	driver = null
	if node:
		node.queue_free()
		node = null
	dp.hips.visible = true
	dp.position += Vector3(1.5, 0, 1.5) * World.C * 0.5
	return true


## Герой погиб за рулём: машина встаёт рядом, а если места нет — её стоимость возвращается в штаб.
func force_leave() -> void:
	if driving == "" or not is_driver(game.player):
		return
	if leave():
		return
	var cost: Dictionary = _paid if _paid is Dictionary else DB.building(driving).get("cost", {})
	_paid = null
	for k in cost:
		if game.factory.hq:
			game.factory.hq.inv.add(k, int(cost[k]))
	var dp = _drv()
	driving = ""
	driver = null
	if node:
		node.queue_free()
		node = null
	dp.hips.visible = true


func _make_node() -> void:
	if node:
		node.queue_free()
	node = ModelLib.make_node(str(DB.building(driving).get("model", driving)))
	game.add_child(node)


func update(delta: float) -> void:
	if driving == "" or node == null:
		return
	var mv: Vector3 = _drv().move_dir
	if mv.length() > 0.5:
		var want := atan2(-mv.z, mv.x)
		yaw = lerp_angle(yaw, want, minf(1.0, delta * 6.0))
	node.position = _drv().position
	node.rotation.y = yaw
	# покачивание на ходу
	node.rotation.z = sin(Time.get_ticks_msec() * 0.02) * 0.015 * minf(1.0, mv.length() / 10.0)


func to_dict() -> Dictionary:
	return {"driving": driving, "yaw": yaw, "hp": _parked_hp, "paid": _paid} if driving != "" else {}


func load_dict(d: Dictionary) -> void:
	if str(d.get("driving", "")) == "" or DB.building(str(d.driving)).is_empty():
		return
	driving = str(d.driving)
	yaw = float(d.get("yaw", 0.0))
	_parked_hp = float(d.get("hp", 0.0))
	_paid = d.get("paid") if d.get("paid") is Dictionary else null
	driver = game.split.p1() if game.split != null and game.split.active else game.player   # A-3 r7
	_make_node()
	_drv().hips.visible = false
