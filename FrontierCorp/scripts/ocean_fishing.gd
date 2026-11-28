extends RefCounted

const TYPES := ["crate", "barrel"]
const MODELS := ["floating_crate", "floating_drum"]
const GOODS := ["log","branch","fiber","leaves","coal","stone","iron_ore","copper_ore","tree_seed"]
const REACH := 21.
const LIMIT := 5
const INTERVAL := 300.0
var last_tick := -1
var game
var drift: Array = []
var next_id := 1
var lines := {}
var spawn_timer := 0.
var clock := 0.
var cord_material := StandardMaterial3D.new()
var float_material := StandardMaterial3D.new()

func _init(g) -> void:
	game = g
	cord_material.albedo_color = Color("#f1dd9e")
	cord_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	float_material.albedo_color = Color("#ff7138")
	float_material.emission_enabled = true
	float_material.emission = Color("#c53a17")

func setup(rows: Array, delay: float) -> void:
	spawn_timer = clampf(delay, 0., INTERVAL)
	last_tick = Time.get_ticks_msec()
	for row in rows:
		if row.size() < 4 or row[0] not in TYPES or drift.size() >= LIMIT: continue
		var d := add(str(row[0]),Vector3(float(row[1]),.18,float(row[2])),float(row[3]),int(row[4]) if row.size()>4 else 0)
		restore_motion(d,row)

func restore_motion(d: Dictionary,row: Array) -> void:
	if row.size() >= 9:
		d.velocity = Vector3(float(row[5]),0,float(row[6]))
		d.stopped = bool(row[7])
		d.travel = float(row[8])

func records() -> Array:
	var out := []
	for d in drift:
		out.append([d.kind,d.node.position.x,d.node.position.z,d.phase,d.id,d.velocity.x,d.velocity.z,d.stopped,d.travel])
	return out

func add(kind: String,p: Vector3,phase: float, id := 0) -> Dictionary:
	if kind not in TYPES: return {}
	var node := ModelLib.make_node(MODELS[TYPES.find(kind)], false, true)
	node.position = p
	node.rotation.y = phase
	game.add_child(node)
	id = next_id if id == 0 else id
	next_id = maxi(next_id,id+1)
	var d := {"id":id,"kind":kind, "node":node, "phase":phase, "held":false,"velocity":Vector3(.92,0,.17),"stopped":false,"travel":0.}
	drift.append(d)
	return d

func apply_snapshot(rows: Array) -> void:
	var seen := {}
	for row in rows:
		var id := int(row[4])
		seen[id] = true
		var pos := Vector3(float(row[1]),.19,float(row[2]))
		var d := by_id(id)
		if d.is_empty():
			d = add(row[0],pos,float(row[3]),id)
		elif not d.held:
			d.node.position = pos
		restore_motion(d,row)
	for d in drift.duplicate():
		if not seen.has(d.id):
			discard(d)

func by_id(id: int) -> Dictionary:
	for d in drift:
		if d.id == id: return d
	return {}

func discard(d: Dictionary) -> void:
	for pl in lines.keys():
		if lines[pl].target == d: _clear(pl)
	drift.erase(d)
	d.node.queue_free()

func collect(id: int, pl) -> bool:
	var d := by_id(id)
	if d.is_empty() or pl.inv.count("salvage_rod") == 0 or World.dist(pl.position,d.node.position)>REACH+3.:
		return false
	var goods := loot(d.kind)
	discard(d)
	_give(pl,goods)
	return true

func spawn(kind: String) -> void:
	if drift.size() >= LIMIT or game.island.shore.is_empty(): return
	var anchor: Vector3 = game.player.position
	var closest: Vector2i = World.world_to_cell(anchor)
	if not game.island.shore_indices.has(closest):
		var best := INF
		for c in game.island.shore:
			var distance := World.cell_to_world(c).distance_squared_to(anchor)
			if distance < best:
				closest = c
				best = distance
	var edge := World.cell_to_world(closest)
	for attempt in 20:
		var angle := randf()*TAU
		var direction := Vector3(cos(angle),0,sin(angle))
		var side := Vector3(-direction.z,0,direction.x)
		var target := edge + side * randf_range(-9.,9.)
		var distance := 20.
		var pos := target-direction*distance
		pos.y=.2
		while game.camera.is_position_in_frustum(pos) or not game.world.water_at(World.world_to_cell(pos)):
			distance *= 1.5
			pos = target-direction*distance
			pos.y=.2
			if distance > 1200.: break
		if distance > 1200.: continue
		pos -= direction*3.
		var d := add(kind,pos,angle)
		d.velocity = direction*maxf(.95,distance/28.)
		return

func arrivals(elapsed: float) -> void:
	if Net.is_client(): return
	spawn_timer -= elapsed
	if spawn_timer > 0.: return
	spawn_timer = INTERVAL
	for d in drift.duplicate():
		if not d.held: discard(d)
	for i in mini(LIMIT-drift.size(),randi_range(2,LIMIT)):
		spawn(TYPES.pick_random())

func _mesh(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	game.add_child(mi)
	return mi

func click(pl, at: Vector3) -> void:
	if lines.has(pl):
		var line: Dictionary = lines[pl]
		if line.phase == "wait":
			line.fish = line.target.is_empty() and line.time >= line.bite and line.time <= line.bite + 3.2
			line.phase = "reel"
		return
	if not game.world.water_at(World.world_to_cell(at)):
		game.notify("Забросьте удочку в воду", UI.ACCENT)
		return
	var point: Vector3 = pl.position + (at-pl.position).limit_length(REACH)
	point.y = .23
	if not game.world.water_at(World.world_to_cell(point)):
		game.notify("Подойдите ближе к берегу", UI.ACCENT)
		return
	var target := {}
	var best := 2.
	for d in drift:
		var dist := Vector2(point.x-d.node.position.x,point.z-d.node.position.z).length()
		if not d.held and dist < best:
			target = d
			best = dist
	if not target.is_empty():
		target.held = true
		point = target.node.position
	var sphere := SphereMesh.new()
	sphere.radius = .115
	sphere.height = .23
	sphere.radial_segments = 8
	sphere.rings = 4
	var bob := _mesh(sphere,float_material)
	var rodline := BoxMesh.new()
	rodline.size = Vector3(.023,.023,1.)
	var cord := _mesh(rodline,cord_material)
	bob.position = pl.position+Vector3.UP
	lines[pl] = {"phase":"cast","bob":bob,"cord":cord,"end":point,"target":target,"time":0.,"bite":randf_range(2.,5.5),"fish":false,"signalled":false}
	game.sfx.play_ui("click")

func _clear(pl) -> void:
	var line: Dictionary = lines[pl]
	if not line.target.is_empty(): line.target.held = false
	line.bob.queue_free()
	line.cord.queue_free()
	lines.erase(pl)

func loot(kind: String) -> Dictionary:
	if kind not in TYPES: return {}
	var result := {}
	var pool := GOODS.duplicate()
	pool.shuffle()
	for i in randi_range(1,3):
		result[pool[i]] = randi_range(1,3)
	return result

func _land(pl,line: Dictionary) -> void:
	var goods := {}
	if not line.target.is_empty():
		var id: int = line.target.id
		_clear(pl)
		if game.split != null and game.split.active:
			game.split.with_seat(game.split.seat_of(pl),func(): game.cmd("shore_salvage",{"id":id}))
		else:
			game.cmd("shore_salvage",{"id":id})
		return
	if line.fish:
		goods = {"reef_fish":1}
	_give(pl,goods)
	_clear(pl)

func _give(pl, goods: Dictionary) -> void:
	var summary := PackedStringArray()
	for k in goods:
		var left: int = pl.inv.add(k,goods[k])
		if left > 0: game.overflow(k,left,pl.position)
		summary.append("%s ×%d" % [DB.item_name(k),goods[k]])
	game.notify("Улов · "+"   ".join(summary) if not goods.is_empty() else "Поплавок вернулся пустым", UI.ACCENT)

func float_cargo(d: Dictionary,p: Vector3) -> void:
	var wave: Vector3 = game.world.ocean_surface(p,clock)
	var up := Vector3(-wave.y,1.,-wave.z).normalized()
	var yaw: float = d.phase
	var across := Vector3(cos(yaw),0.,sin(yaw)).slide(up).normalized()
	d.node.basis = Basis(across,up,across.cross(up))
	p.y = wave.x+.09
	d.node.position = p

func tick(dt: float) -> void:
	clock += dt
	game.world.water_mat.set_shader_parameter("wave_time",clock)
	var now := Time.get_ticks_msec()
	arrivals(maxf(0.,float(now-last_tick)*.001) if last_tick >= 0 else 0.)
	last_tick = now
	for d in drift.duplicate():
		if d.held: continue
		var pos: Vector3 = d.node.position
		if not d.stopped:
			var step: Vector3 = d.velocity * dt
			var pieces := maxi(1,ceili(step.length()/.6))
			for i in pieces:
				var dest := pos + step / pieces
				if not game.world.water_at(World.world_to_cell(dest)):
					d.stopped = true
					break
				pos = dest
			d.travel += dt
		float_cargo(d,pos)
		if not Net.is_client() and not d.stopped and d.travel > 80. and not game.camera.is_position_in_frustum(pos):
			discard(d)
	for pl in lines.keys():
		var line: Dictionary = lines[pl]
		if not is_instance_valid(pl) or not pl.alive or pl.selected_item() != "salvage_rod" or game.strategy:
			_clear(pl)
			continue
		var hand: Vector3 = pl.position + Vector3.UP * 1.22
		var bob: MeshInstance3D = line.bob
		match line.phase:
			"cast":
				bob.position = bob.position.move_toward(line.end,dt*25.)
				if bob.position.is_equal_approx(line.end):
					line.phase = "wait"
					if not line.target.is_empty(): game.notify("Груз зацеплен · ЛКМ подтянуть",UI.ACCENT)
			"wait":
				line.time += dt
				if line.target.is_empty():
					if line.time >= line.bite and not line.signalled:
						line.signalled = true
						game.notify("Поклёвка! Щёлкните сейчас", Color.GOLD)
						game.sfx.play_ui("tick")
					bob.position.y = game.world.ocean_surface(bob.position,clock).x+.08+(sin(clock*15.)*.09 if line.signalled else 0.)
					if line.time > line.bite+3.2:
						line.time = 0.
						line.signalled = false
						line.bite = randf_range(2.,5.5)
				else: bob.position = line.target.node.position
			"reel":
				bob.position = bob.position.move_toward(hand,dt*8.)
				if not line.target.is_empty(): line.target.node.position = bob.position
				if bob.position.distance_to(hand) < .45:
					_land(pl,line)
					continue
		var length := hand.distance_to(bob.position)
		line.cord.position = (hand+bob.position)*.5
		if length > .04:
			line.cord.look_at(bob.position, Vector3.RIGHT if absf((bob.position-hand).normalized().y)>.98 else Vector3.UP)
			line.cord.scale = Vector3(1.,1.,length)
