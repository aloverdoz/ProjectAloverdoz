extends RefCounted
## Подземелья (14.7): опасные руины на карте. Стены, ловушки для героя, стража и босс,
## в центре — сундук с добычей и редким чертежом (открывает здание, которого нет в дереве открытий).
## Всё правится: «Настройки → Подземелья» (сколько, где, стража, добыча), «Предметы» (чертежи), «Здания» (редкие).

var game
var list: Array = []      # {cell: Vector2i, chest (B), guards: bool, done: bool, level: int}


func _init(g) -> void:
	game = g


func cfg() -> Dictionary:
	return DB.setting("dungeons", {})


## Новая игра: разложить подземелья по карте.
func generate() -> void:
	var c := cfg()
	if not bool(c.get("enabled", false)) or game.factory.hq == null:
		return
	var hq: Vector2i = game.factory.hq.cell
	var n := int(c.get("count", 4))
	var rng := RandomNumberGenerator.new()
	rng.seed = game.world.used_seed
	var tries := 0
	while list.size() < n and tries < 400:
		tries += 1
		var a := rng.randf() * TAU
		var r := rng.randf_range(float(c.get("min_dist", 70)), float(c.get("max_dist", 220)))
		var cell := World.wc(hq + Vector2i(roundi(cos(a) * r), roundi(sin(a) * r)))
		# на замкнутой карте далёкая точка может оказаться рядом со штабом с другой стороны
		if World.dist(World.cell_to_world(cell), World.cell_to_world(hq)) < float(c.get("min_dist", 70)) * World.C * 0.9:
			continue
		if not _free_spot(cell, 9):
			continue
		var far_ok := true
		for d in list:
			if World.dist(World.cell_to_world(d.cell), World.cell_to_world(cell)) < 120.0:
				far_ok = false
		if not far_ok:
			continue
		build(cell, list.size())


func _free_spot(c: Vector2i, r: int) -> bool:
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var cc := World.wc(c + Vector2i(dx, dz))
			if game.enemies._wet(cc) or game.factory.grid.has(cc):
				return false
			if not game.world.wrap and (cc.x < 2 or cc.y < 2 or cc.x >= game.world.W - 2 or cc.y >= game.world.W - 2):
				return false
	for nst in game.world.nests:
		if World.dist(nst.pos, World.cell_to_world(c)) < 40.0:
			return false
	return true


func _put(t: String, c: Vector2i, d := 0):
	c = World.wc(c)
	game.world.remove_node(c)
	if game.factory.grid.has(c):
		return null
	return game.factory.place(t, c, d)


## Руины: квадрат стен с входом, коридор ловушек, вход-арка, сундук в центре.
func build(c: Vector2i, level: int) -> Dictionary:
	var R := 5
	for dz in range(-R - 1, R + 2):
		for dx in range(-R - 1, R + 2):
			game.world.remove_node(World.wc(c + Vector2i(dx, dz)))
	var side := level % 4
	var door: Vector2i = [Vector2i(0, R), Vector2i(R, 0), Vector2i(0, -R), Vector2i(-R, 0)][side]
	var inward: Vector2i = -door / R
	for dz in range(-R, R + 1):
		for dx in range(-R, R + 1):
			if maxi(absi(dx), absi(dz)) != R:
				continue
			var o := Vector2i(dx, dz)
			if o == door:
				continue
			_put("ruin_wall", c + o)
	# внутренняя стена-лабиринт
	for k in range(-2, 3):
		var o := Vector2i(k, 2) if side % 2 == 0 else Vector2i(2, k)
		if side >= 2:
			o = -o
		_put("ruin_wall", c + o)
	_put("ruin_arch", c + door, side)
	# ловушки в проходе
	for k in range(1, 3):
		_put("dungeon_spikes", c + door + inward * k)
	for k in [-3, 3]:
		var o := Vector2i(k, 0) if side % 2 == 0 else Vector2i(0, k)
		_put("dungeon_spikes", c + o + inward)
	var chest = _put("dungeon_chest", c + inward * 2)
	if chest and chest.inv:
		_fill(chest, level)
	var d := {"cell": World.wc(c), "chest": chest, "guards": false, "done": false, "level": level}
	list.append(d)
	return d


func _fill(chest, level: int) -> void:
	var c := cfg()
	var loot: Array = c.get("loot", [])
	for l in loot:
		if randf() <= float(l.get("chance", 1.0)) and DB.data.items.has(str(l.get("item", ""))):
			chest.inv.add(str(l.item), randi_range(int(l.get("min", 1)), int(l.get("max", 1))))
	var bps: Array = c.get("blueprints", [])
	if not bps.is_empty():
		var bp := str(bps[level % bps.size()])
		if DB.data.items.has(bp):
			chest.inv.add(bp, 1)


func update(_dt: float) -> void:
	if list.is_empty() or Net.is_client():
		return
	var c := cfg()
	for d in list:
		var wp: Vector3 = World.cell_to_world(d.cell)
		if not d.guards and not d.done and game.near_any_hero(wp) < float(c.get("wake_dist", 70.0)):   # B-4 r5: любой герой
			d.guards = true
			_spawn_guards(d)
		if not d.done and d.chest != null and (d.chest.dead or (d.chest.inv != null and d.chest.inv.is_empty())):
			d.done = true
			game.notify("Подземелье пройдено! Добыча ваша.", Color(1.0, 0.85, 0.3))


func _spawn_guards(d: Dictionary) -> void:
	var c := cfg()
	var wp: Vector3 = World.cell_to_world(d.cell)
	d["mobs"] = []
	# A-6 r7: после загрузки — только те, кого ещё не перебили
	if d.get("left") is Array:
		for t in d.left:
			if DB.data.enemies.has(str(t)):
				var a := randf() * TAU
				var e0 = game.enemies.spawn(str(t), wp + Vector3(cos(a), 0, sin(a)) * randf_range(2.0, 7.0), true)
				if e0:
					e0.home = wp
					d.mobs.append(e0)
		d.erase("left")
		return
	var guards: Array = c.get("guards", [])
	var day: int = game.day_n
	for g in guards:
		if day < int(g.get("from_day", 0)) or not DB.data.enemies.has(str(g.get("enemy", ""))):
			continue
		for i in int(g.get("n", 1)):
			var a := randf() * TAU
			var e = game.enemies.spawn(str(g.enemy), wp + Vector3(cos(a), 0, sin(a)) * randf_range(2.0, 7.0), true)
			if e:
				e.home = wp
				d.mobs.append(e)
	var boss := str(c.get("boss", ""))
	if boss != "" and DB.data.enemies.has(boss):
		var b = game.enemies.spawn(boss, wp, true)
		if b:
			b.home = wp
			d.mobs.append(b)


## Есть ли рядом подземелье (для карты и подсказок).
func near(p: Vector3, r: float) -> Dictionary:
	for d in list:
		if World.dist(World.cell_to_world(d.cell), p) < r:
			return d
	return {}


func to_dict() -> Array:
	return list.map(func(d):
		var o := {"x": d.cell.x, "z": d.cell.y, "done": d.done, "level": d.level}
		var left = left_of(d)
		if left != null:
			o["left"] = left
		return o)


## A-6 r7: какие стражи ещё живы (null — стража ещё не просыпалась).
func left_of(d: Dictionary):
	if d.get("left") is Array:
		return d.left
	if not d.guards:
		return null
	return (d.get("mobs", []) as Array).filter(func(e): return e != null and e.alive).map(func(e): return e.type)


func from_dict(a: Array) -> void:
	list.clear()
	for v in a:
		var cell := Vector2i(int(v.get("x", 0)), int(v.get("z", 0)))
		var ch = null
		for dz in range(-5, 6):
			for dx in range(-5, 6):
				var b = game.factory.grid.get(World.wc(cell + Vector2i(dx, dz)))
				if b != null and b.type == "dungeon_chest":
					ch = b
		var dd := {"cell": cell, "chest": ch, "guards": false, "done": bool(v.get("done", false)), "level": int(v.get("level", 0))}
		if v.get("left") is Array:
			dd["left"] = v.left
		list.append(dd)

func place_caves() -> void:
	var w = game.world
	var rng := RandomNumberGenerator.new()
	rng.seed = int(w.used_seed) ^ 0x219af
	var center: Vector2i = w.center
	for kind in 4:
		var angle := kind*PI/2.0 + rng.randf_range(-0.25,0.25)
		for attempt in 80:
			var radius: float = minf(w.W * 0.32, 16.0 + kind*11.0) + rng.randf_range(-4, 5)
			var jitter := rng.randf_range(-.3,.3)
			var offset := Vector2i(roundi(cos(angle+jitter)*radius), roundi(sin(angle+jitter)*radius))
			var cell := World.wc(center + offset)
			if not w.in_bounds(cell) or w.water_at(cell) or w.deposit.has(cell) or game.factory.grid.has(cell):
				continue
			var b = game.factory.place("ruin_arch", cell, kind)
			b.bstate["cave_type"] = kind
			break
