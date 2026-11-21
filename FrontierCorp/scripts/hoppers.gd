extends Node3D

var game
var herd: Array = []
var materials := {}
var body_mesh := SphereMesh.new()
var rng := RandomNumberGenerator.new()
var center := Vector2i(-10000, -10000)
var scan_time := 0.0

func _ready() -> void:
	game = get_parent()
	body_mesh.radial_segments = 32
	body_mesh.rings = 16

func joint(parent: Node3D, at: Vector3) -> Node3D:
	var n := Node3D.new()
	parent.add_child(n)
	n.position = at
	return n

func shape(parent: Node3D, at: Vector3, size: Vector3, color: String) -> MeshInstance3D:
	if not materials.has(color):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(color)
		m.roughness = .83
		if color == "#77e4c6":
			m.emission_enabled = true
			m.emission = Color(color)
			m.emission_energy_multiplier = .42
		materials[color] = m
	var n := MeshInstance3D.new()
	n.mesh = body_mesh
	n.material_override = materials[color]
	n.position = at
	n.scale = size
	parent.add_child(n)
	return n

func spawn_hopper(at: Vector3) -> void:
	var animal := joint(self, at)
	var trunk := joint(animal, Vector3(0,.245,0))
	var face := joint(trunk, Vector3(0,.08,-.19))
	var coat := "#829a78"
	shape(trunk, Vector3.ZERO, Vector3(.35,.39,.54),coat)
	shape(trunk, Vector3(0,-.055,-.08), Vector3(.31,.27,.39),"#dfcfaa")
	shape(trunk, Vector3(0,.065,.30), Vector3(.14,.14,.15),"#d5ddc0")
	shape(face, Vector3.ZERO, Vector3(.31,.29,.27),coat)
	shape(face, Vector3(0,-.045,-.11), Vector3(.21,.13,.125),"#efdfba")
	shape(face, Vector3(0,-.02,-.17), Vector3(.071,.044,.032),"#725956")
	var ears: Array = []
	var hind: Array = []
	for side in [-1.0,1.0]:
		shape(face,Vector3(side*.117,.022,-.089),Vector3(.061,.074,.05),"#272a2a")
		shape(face,Vector3(side*.129,.033,-.106),Vector3(.016,.018,.012),"#faf1ce")
		shape(face,Vector3(side*.126,-.029,-.087),Vector3(.045,.018,.023),"#77e4c6")
		var ear := joint(face,Vector3(side*.071,.094,0))
		ear.rotation.z = -side*.23
		shape(ear, Vector3(0,.155,0),Vector3(.105,.35,.069),coat)
		shape(ear, Vector3(0,.17,-.025),Vector3(.071,.28,.032),"#b3d1a4")
		ears.append(ear)
		var leg := joint(trunk, Vector3(side*.133,-.041,.123))
		shape(leg,Vector3.ZERO,Vector3(.17,.244,.234),coat)
		shape(leg,Vector3(side*.012,-.148,-.055),Vector3(.115,.086,.228),"#c8c5a2")
		shape(trunk,Vector3(side*.094,-.155,-.138),Vector3(.085,.16,.092),"#d7ceae")
		hind.append(leg)
	animal.rotation.y = rng.randf()*TAU
	animal.scale *= rng.randf_range(.86,1.18)
	herd.append({"node":animal,"body":trunk,"head":face,"ears":ears,"hind":hind,"phase":rng.randf()*TAU,"mode":"forage","wait":rng.randf_range(1,4),"speed":0.0})

func walkable(point: Vector3) -> bool:
	var c := World.world_to_cell(point)
	return game.world.in_bounds(c) and not game.world.water_at(c) and not game.factory.grid.has(c) and not game.world.nodes.has(c)

func resettle(c: Vector2i) -> void:
	for h in herd:
		h.node.queue_free()
	herd.clear()
	center = c
	rng.seed = hash(Vector3i(game.world.used_seed, c.x, c.y))
	var start: Vector3 = game.player.position
	for i in 48:
		var pos := World.wrap_pos(start + Vector3(rng.randf_range(-27,27),0,rng.randf_range(-27,27)))
		var cell := World.world_to_cell(pos)
		if not walkable(pos) or game.world.biome_at(cell) not in ["forest","meadow","spore"]:
			continue
		pos.y = game.world.height_at(pos)
		spawn_hopper(pos)
		if herd.size() >= 5:
			break

func _process(delta: float) -> void:
	scan_time -= delta
	if scan_time <= 0:
		scan_time = 1.0
		var c := World.world_to_cell(game.player.position)
		if center.distance_squared_to(c) > 32*32:
			resettle(c)
	for h in herd:
		var animal: Node3D = h.node
		var away := World.delta(game.player.position, animal.position)
		away.y = 0.0
		h.wait -= delta
		if not game.strategy and away.length_squared() < 17 and h.mode != "flee":
			h.mode = "flee"
			h.wait = 2.6
			animal.rotation.y = atan2(-away.x,-away.z)
		elif h.wait <= 0.0:
			h.mode = "sleep" if game.is_night() and rng.randf()<.75 else ["forage","hop","idle"][rng.randi_range(0,2)]
			h.wait = rng.randf_range(1.8,4.8)
			animal.rotation.y += rng.randf_range(-1.3,1.3)
		var moving: bool = h.mode in ["hop","flee"]
		var pace := 12.0 if h.mode == "flee" else 7.4
		h.phase += delta * (pace if moving else 2.2)
		var arc := maxf(0.0,sin(h.phase)) if moving else 0.0
		if moving:
			var next: Vector3 = World.wrap_pos(animal.position-animal.basis.z.normalized()*delta*arc*(4.2 if h.mode == "flee" else 1.6))
			var floor_y: float = game.world.height_at(next)
			if walkable(next) and absf(floor_y-animal.position.y)<.45:
				animal.position = Vector3(next.x,floor_y,next.z)
			else:
				animal.rotation.y += 1.2
		h.body.position.y = .245 + arc*.25 - (.085 if h.mode=="sleep" else 0.0)
		h.head.rotation.x = -.36+.22*sin(h.phase) if h.mode=="forage" else -.2 if h.mode=="sleep" else arc*.14
		for i in 2:
			h.ears[i].rotation.x = (.75 if h.mode=="sleep" else .12)+arc*.25+.09*sin(h.phase*2.0+float(i))
			h.hind[i].rotation.x = arc*.72
