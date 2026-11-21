extends Node3D
## 21: физика. Разрушенное здание разлетается обломками, взрыв расталкивает монстров, предметы и обломки,
## убитый монстр отлетает и кувыркается (тело с подёргиванием лап — в creature_rig), предметы на земле
## катятся под горку и отскакивают от зданий. Всё настраивается в «Данные → Настройки → Физика».

var game
var pieces: Array = []     # [{pos, vel, axis, ang, spin, size, t, life, rest}]
var r: PartRenderer
var stats := {"debris": 0, "blasts": 0, "pushed": 0}
var _next_id := 0         # 1.1.13: ключ куска в рендерере — число (словарь как ключ меняет хэш при каждом шаге)


func _init(g) -> void:
	game = g
	r = PartRenderer.new()
	r.add_part(ModelLib.unit_mesh("box", 1.0, 0, 0.08), ModelLib.material({"mat": "metal", "roughness": 0.7}), Transform3D.IDENTITY, Color.WHITE, true, false)
	add_child(r)


static func cfg() -> Dictionary:
	var c = DB.setting("physics", {})
	return c if c is Dictionary else {}


static func on(key: String) -> bool:
	var c := cfg()
	return bool(c.get("enabled", true)) and bool(c.get(key, true))


static func num(key: String, def: float) -> float:
	return float(cfg().get(key, def))


# ---------------------------------------------------------------- обломки

## Здание разрушено: куски его цветов разлетаются от центра, падают, отскакивают и тают.
func debris(b) -> void:
	if not on("debris") or b == null:
		return
	var cols := []
	var br = game.factory.renderers.get(b.type)
	if br != null:
		for p in br.parts:
			var c: Color = p.color
			if c != Color.WHITE and c.a > 0.5:
				cols.append(c)
	if cols.is_empty():
		cols = [Color(0.55, 0.55, 0.58), Color(0.72, 0.52, 0.22), Color(0.3, 0.3, 0.32)]
	var n := mini(int(num("debris_per_cell", 9.0) * b.size * b.size), 40)
	var cap := int(num("debris_max", 500.0))
	var h: float = minf(game.factory.roof_h(b.type), 6.0)
	var c0: Vector3 = b.center()
	for i in n:
		if pieces.size() >= cap:
			_drop(pieces[0])
		var off: Vector3 = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * b.size * 0.8
		var at: Vector3 = c0 + off + Vector3(0, randf_range(0.3, h), 0)
		var out: Vector3 = off.normalized() if off.length() > 0.05 else Vector3.RIGHT
		var sp := randf_range(3.0, 8.0) * num("debris_force", 1.0)
		var pc := {"pos": at, "vel": out * sp + Vector3(0, randf_range(4.0, 10.0), 0),
			"axis": Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized(),
			"ang": randf() * TAU, "spin": randf_range(4.0, 14.0),
			"size": Vector3(randf_range(0.2, 0.7), randf_range(0.12, 0.45), randf_range(0.2, 0.6)) * (1.0 + 0.25 * (b.size - 1)),
			"t": 0.0, "life": num("debris_life", 7.0) * randf_range(0.8, 1.2), "rest": false, "id": _next_id}
		_next_id += 1
		pieces.append(pc)
		r.add(pc.id, _xf(pc), 0.0)
		r.set_part_color(pc.id, 0, (cols[randi() % cols.size()] as Color).darkened(randf_range(0.0, 0.35)))
	stats.debris += n


## 1.1.13: на месте разрушенного здания поставили новое или отстроили его — обломки на следе пропадают.
func clear_cells(cell: Vector2i, size: int) -> void:
	if pieces.is_empty():
		return
	var area := {}
	for x in range(-1, size + 1):
		for z in range(-1, size + 1):
			area[World.wc(cell + Vector2i(x, z))] = true
	for pc in pieces.duplicate():
		if area.has(World.wc(World.world_to_cell(pc.pos))):
			_drop(pc)


func _xf(pc: Dictionary) -> Transform3D:
	var k := 1.0 - smoothstep(pc.life - 1.0, pc.life, pc.t)
	var bs := Basis(pc.axis, pc.ang).scaled(pc.size * maxf(0.02, k))
	return Transform3D(bs, pc.pos)


func _drop(pc: Dictionary) -> void:
	r.remove(pc.id)
	pieces.erase(pc)


func _update_pieces(delta: float) -> void:
	var g := num("gravity", 18.0)
	var done := []
	for pc in pieces:
		pc.t += delta
		if pc.t > pc.life:
			done.append(pc)
			continue
		if not pc.rest:
			pc.vel.y -= g * delta
			var np: Vector3 = pc.pos + pc.vel * delta
			# в стену здания — отскок
			var bb = game.factory.grid.get(World.world_to_cell(np))
			if bb != null and not game.factory.walkable(bb) and np.y < game.factory.roof_top(bb):
				pc.vel.x *= -0.4
				pc.vel.z *= -0.4
				np = pc.pos + Vector3(0, pc.vel.y * delta, 0)
			pc.pos = World.wrap_pos(np)
			pc.ang += pc.spin * delta
			var fy: float = game.factory.support_at(pc.pos) + pc.size.y * 0.5
			if pc.pos.y <= fy:
				pc.pos.y = fy
				if absf(pc.vel.y) > 2.5:
					pc.vel = Vector3(pc.vel.x * 0.5, -pc.vel.y * 0.35, pc.vel.z * 0.5)
					pc.spin *= 0.6
				else:
					pc.vel.y = 0.0
					var hv := Vector3(pc.vel.x, 0, pc.vel.z) * maxf(0.0, 1.0 - delta * 4.0)
					pc.vel = hv
					pc.spin *= maxf(0.0, 1.0 - delta * 5.0)
					if hv.length() < 0.15:
						pc.rest = true
		r.set_xform(pc.id, _xf(pc))
	for pc in done:
		_drop(pc)


# ---------------------------------------------------------------- взрыв

## Взрыв: монстров, предметы на земле и обломки отбрасывает от центра; героя слегка толкает.
func blast(pos: Vector3, size: float) -> void:
	if not on("blast"):
		return
	var rad := clampf(size * num("blast_radius", 2.2), 2.0, 40.0)
	var force := num("blast_force", 14.0) * sqrt(maxf(0.3, size))
	stats.blasts += 1
	if game.enemies:
		for e in game.enemies.list:
			if not e.alive:
				continue
			var d: Vector3 = World.delta(pos, e.pos)
			d.y = 0
			var l := d.length()
			if l > rad:
				continue
			var dir := d / l if l > 0.05 else Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
			var f := force * (1.0 - l / rad) / maxf(0.6, e.radius)
			game.enemies.knock(e, dir * f, f * 0.55)
			stats.pushed += 1
	if game.drops:
		for dr in game.drops.list:
			var d2: Vector3 = World.delta(pos, dr.pos)
			var l2 := Vector3(d2.x, 0, d2.z).length()
			if l2 > rad or dr.magnet:
				continue
			var dir2 := Vector3(d2.x, 0, d2.z) / maxf(0.05, l2)
			var f2 := force * (1.0 - l2 / rad)
			dr.vel = dr.vel + dir2 * f2 + Vector3(0, f2 * 0.6, 0)
			dr.landed = false
			dr.rolling = false
	for pc in pieces:
		var d3: Vector3 = World.delta(pos, pc.pos)
		var l3 := d3.length()
		if l3 > rad:
			continue
		var f3 := force * 1.2 * (1.0 - l3 / rad)
		pc.vel = pc.vel + d3 / maxf(0.05, l3) * f3 + Vector3(0, f3 * 0.5, 0)
		pc.rest = false
		pc.spin = randf_range(6.0, 14.0)
	var pl = game.player
	if pl != null and pl.alive:
		var d4: Vector3 = World.delta(pos, pl.position)
		d4.y = 0
		var l4 := d4.length()
		if l4 > 0.6 and l4 < rad * 0.8:
			pl.move_dir += d4 / l4 * force * (1.0 - l4 / rad) * num("blast_hero", 0.6)


func update(delta: float) -> void:
	if not pieces.is_empty():
		_update_pieces(delta)
