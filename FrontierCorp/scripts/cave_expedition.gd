extends CanvasLayer

const STEP := 2.4
const NAMES := ["Сад спор", "Лазурная жила", "Зал картографов", "Горячий разлом"]
const GLOWS := [Color("#65d2aa"), Color("#71bfff"), Color("#b392e8"), Color("#ef945b")]
var game
var entrance
var cave := Node3D.new()
var camera := Camera3D.new()
var info: Label
var rng := RandomNumberGenerator.new()
var cells := {}
var visited := {}
var samples := {}
var kind := 0
var yaw := 0.0
var pitch := -0.12
var previous_mouse := Input.MOUSE_MODE_VISIBLE
var materials := {}
var shades := {}
var lamp := OmniLight3D.new()
var hud_line := ""
var message_time := 0.0
var origin := Vector2i.ZERO
var walker := Vector3.ZERO
var relic: MeshInstance3D
var guardian: Node3D
var guardian_home := Vector3.ZERO
var guardian_clips: AnimationPlayer
var repel_time := 0.0
var encounter_time := 0.0
var contact_time := 0.0
var old_pause := false
var landmarks := {}

func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	old_pause = get_tree().paused
	get_tree().paused = true
	previous_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	rng.seed = hash(Vector3i(entrance.cell.x, entrance.cell.y, game.world.used_seed)) & 0x7fffffff
	kind = int(entrance.bstate.get("cave_type", rng.randi_range(0, 3)))
	entrance.bstate["cave_type"] = kind
	visited = entrance.bstate.get("cave_samples", {}).duplicate()
	var host := SubViewportContainer.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.stretch = true
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(host)
	var viewport := SubViewport.new()
	viewport.world_3d = World3D.new()
	host.add_child(viewport)
	viewport.add_child(cave)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#141c23")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#829ac2")
	env.ambient_light_energy = .60
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = bool(Prefs.get_value("glow", true))
	env.glow_intensity = .64
	env.fog_enabled = true
	env.fog_density = 0.020
	env.fog_light_color = GLOWS[kind].darkened(0.68)
	viewport.world_3d.environment = env
	cave.add_child(camera)
	camera.current = true
	camera.fov = 68
	camera.near = 0.07
	lamp.omni_range = 14
	lamp.light_energy = 1.3
	lamp.light_color = Color("#f5dfc5")
	camera.add_child(lamp)
	_generate()
	var water_sound := AudioStreamPlayer.new()
	water_sound.stream = preload("res://sounds/cave_water.wav")
	water_sound.bus = "Ambient"
	water_sound.volume_db = -9.0
	add_child(water_sound)
	water_sound.finished.connect(water_sound.play)
	water_sound.play()
	walker = Vector3(0, 0, 0)
	var overlay := MarginContainer.new()
	overlay.offset_left = 24
	overlay.offset_top = 20
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	info = Label.new()
	info.add_theme_font_size_override("font_size", 18)
	info.add_theme_constant_override("outline_size", 4)
	overlay.add_child(info)
	update_view()


func excavate(c: Vector2i, width: int) -> void:
	for x in range(-width, width + 1):
		for z in range(-width, width + 1):
			if x*x + z*z <= width*width + 1:
				cells[c + Vector2i(x, z)] = true


func branch(a: Vector2i, b: Vector2i) -> void:
	var steps := maxi(absi(b.x-a.x), absi(b.y-a.y))
	for i in steps + 1:
		var pos := Vector2(a).lerp(Vector2(b), float(i) / maxi(1, steps))
		excavate(Vector2i(roundi(pos.x), roundi(pos.y)), 1)


func floor_height(x: float, z: float) -> float:
	return 0.65 * sin(x * 0.12 + kind) + 0.9 * sin(z * 0.083)


func material(id: String, color: Color, lit := false) -> StandardMaterial3D:
	if not materials.has(id):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.87
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		if lit:
			m.emission_enabled = true
			m.emission = color
			m.emission_energy_multiplier = 1.25
		materials[id] = m
	return materials[id]


func emit_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for v in [a, b, c, a, c, d]:
		st.add_vertex(v)


func at_corner(x: float, z: float, roof: bool) -> Vector3:
	var y := floor_height(x,z)
	if roof:
		y += 5.6 + sin(x*.74 + z*.38)*.62 + 1.95*cos(x*.18)*cos(z*.12)
	return Vector3(x, y, z)


func _generate() -> void:
	var centers := [Vector2i.ZERO]
	excavate(Vector2i.ZERO, 3)
	for attempt in 60:
		if centers.size() >= 10:
			break
		var parent: Vector2i = centers[rng.randi_range(0, centers.size()-1)]
		var angle := rng.randf()*TAU
		var c := parent + Vector2i(roundi(cos(angle)*8.0), roundi(sin(angle)*8.0))
		if centers.any(func(other): return c.distance_squared_to(other) < 12):
			continue
		branch(parent,c)
		excavate(c, rng.randi_range(2,4))
		centers.append(c)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stone := ShaderMaterial.new()
	stone.shader = preload("res://shaders/cavern.gdshader")
	stone.set_shader_parameter("basalt",preload("res://textures/frontier/basalt.jpg"))
	stone.set_shader_parameter("paving",preload("res://textures/frontier/slate.jpg"))
	stone.set_shader_parameter("earth",preload("res://textures/frontier/regolith.jpg"))
	stone.set_shader_parameter("ruins",kind==2)
	st.set_material(stone)
	for c: Vector2i in cells:
		var x := c.x*STEP
		var z := c.y*STEP
		var low := []
		var high := []
		for corner in [Vector2(-.5,-.5),Vector2(.5,-.5),Vector2(.5,.5),Vector2(-.5,.5)]:
			low.append(at_corner(x+corner.x*STEP,z+corner.y*STEP,false))
			high.append(at_corner(x+corner.x*STEP,z+corner.y*STEP,true))
		emit_quad(st,low[0],low[1],low[2],low[3])
		emit_quad(st,high[3],high[2],high[1],high[0])
		for j in 4:
			if not cells.has(c+[Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT][j]):
				var k := (j+1)%4
				var middle: Vector3 = (low[j]+low[k]+high[j]+high[k])/4.0
				middle += (Vector3(x,middle.y,z)-middle).normalized()*rng.randf_range(.2,.8)
				for pair in [[low[j], low[k]], [low[k],high[k]], [high[k],high[j]], [high[j],low[j]]]:
					for v in [pair[0], pair[1], middle]:
						st.add_vertex(v)
	st.generate_normals()
	var terrain := MeshInstance3D.new()
	terrain.mesh = st.commit()
	cave.add_child(terrain)
	var spring_cell := Vector2i(-2,-2)
	if kind in [0,1]:
		while cells.has(spring_cell+Vector2i.UP):
			spring_cell += Vector2i.UP
		var x := spring_cell.x*STEP
		var z := spring_cell.y*STEP
		var lip := at_corner(x,z-STEP*.40,true)-Vector3.UP*.45
		var foot := Vector3(x,floor_height(x,z)+.08,z+.7)
		preload("res://scripts/geology_water.gd").falls(cave,lip,foot,1.38)
		_spring_pool(foot)
	var seen := {}
	for c: Vector2i in centers:
		if seen.has(c):
			continue
		seen[c] = true
		var at := Vector3(c.x*STEP, floor_height(c.x*STEP,c.y*STEP), c.y*STEP)
		var beacon := OmniLight3D.new()
		beacon.position = at + Vector3.UP*2.0
		beacon.omni_range = 12.0
		beacon.light_energy = 2.0
		beacon.light_color = GLOWS[kind]
		cave.add_child(beacon)
		if kind in [0,1]:
			var violet := OmniLight3D.new()
			violet.light_color = Color("#b462ec")
			violet.light_energy = 1.65
			violet.omni_range = 5.4
			violet.position = at+Vector3(-2.35,1.15,-1.83)
			cave.add_child(violet)
			_cluster("coral_fern",c,at+Vector3(-.9,0,-1.8),1.02)
			_cluster("basalt_buttress",c,at+Vector3(-2.8,0,-2.0),1.4)
			_cluster("amethyst_garden",c,at+Vector3(-2.15,0,-1.25),1.27)
			_cluster("dep_quartz",c,at+Vector3(-1.85,0,-2.1),1.55)
			var model_id := "amethyst_garden" if kind == 0 else "dep_iron_ore"
			if not landmarks.has(model_id):
				var renderer := ModelLib.make_renderer(model_id, false, false)
				cave.add_child(renderer)
				landmarks[model_id] = renderer
			var position := at + Vector3(STEP * 1.2, 0, STEP * .5)
			position.y = floor_height(position.x,position.z)
			var size := rng.randf_range(.67,1.08)
			var xf := Transform3D(Basis(Vector3.UP, rng.randf()*TAU).scaled(Vector3.ONE*size), position)
			landmarks[model_id].add(c, xf, 1.0)
		for j in 5:
			var off := Vector3(rng.randf_range(-1.4,1.4),0,rng.randf_range(-1.4,1.4))
			var pos := at+off
			pos.y = floor_height(pos.x,pos.z)
			_decoration(pos, rng.randf_range(.4,1.4), j)
		if c != Vector2i.ZERO:
			var key := "%d,%d" % [c.x,c.y]
			if not visited.has(key):
				var gem := _shape("sample", at + Vector3.UP*.92, Vector3(.36,.62,.36), "sample", true)
				samples[key] = gem
	var exit_pos := Vector3(-1.2,floor_height(-1.2,1.4),1.4)
	_shape("pillar",exit_pos+Vector3.UP*.31,Vector3(.26,.62,.26),"exit_post")
	_shape("cap",exit_pos+Vector3.UP*.67,Vector3(.24,.17,.24),"exit",true)
	if kind >= 2 and not entrance.bstate.get("relic_found", false):
		var chamber: Vector2i = centers.back()
		var altar := Vector3(chamber.x*STEP,0,chamber.y*STEP)
		altar.y = floor_height(altar.x,altar.z)
		_shape("pillar",altar+Vector3.UP*.29,Vector3(1.1,.58,1.1),"altar")
		relic = _shape("shard",altar+Vector3.UP*.99,Vector3(.6,.87,.6),"sample",true)
		if kind == 3:
			guardian = ModelLib.glb_instance(str(ModelLib.model("alien_stone_golem").glb))
			if guardian != null:
				cave.add_child(guardian)
				guardian_home = altar + Vector3(1.9,0,0)
				guardian_home.y = floor_height(guardian_home.x,guardian_home.z)
				guardian.position = guardian_home
				guardian.scale = Vector3.ONE*2.15
				guardian_clips = ModelLib.glb_player(guardian)
				if guardian_clips != null:
					for clip in ["Idle","Walk"]:
						if guardian_clips.has_animation(clip):
							guardian_clips.get_animation(clip).loop_mode = Animation.LOOP_LINEAR


func _cluster(id: String, key: Vector2i, p: Vector3, size: float) -> void:
	if not landmarks.has(id):
		var batch := ModelLib.make_renderer(id,false,false)
		cave.add_child(batch)
		landmarks[id] = batch
	p.y = floor_height(p.x,p.z)-.04
	var b := Basis(Vector3.UP, sin(p.x+p.z)*PI).scaled(Vector3.ONE*size)
	landmarks[id].add([key,id,"shore"], Transform3D(b,p),1.0)


func _spring_pool(center: Vector3) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 60:
		for t in [-1,i,i+1]:
			var angle := float(t)*TAU/60.
			var edge := 1.+.09*cos(angle*5.)+.05*sin(angle*3.)
			var p := center if t<0 else center+Vector3(cos(angle)*2.2*edge,0,sin(angle)*1.4*edge)
			p.y = floor_height(p.x,p.z)+.065
			st.set_uv(Vector2(p.x,p.z)*.18)
			st.add_vertex(p)
	st.generate_normals()
	var water_node := MeshInstance3D.new()
	water_node.mesh = st.commit()
	var water_mat := StandardMaterial3D.new()
	water_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	water_mat.albedo_color = Color("#169ba4")
	water_mat.roughness = .21
	water_mat.emission_enabled = true
	water_mat.emission = Color("#087d91")
	water_mat.emission_energy_multiplier = .46
	water_node.material_override = water_mat
	cave.add_child(water_node)
	var bounce := OmniLight3D.new()
	bounce.position = center+Vector3.UP*.8
	bounce.light_color = Color("#53e6ed")
	bounce.light_energy = 2.35
	bounce.omni_range = 8.
	cave.add_child(bounce)


func _shape(form: String, pos: Vector3, scale_value: Vector3, color_id: String, glow := false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	if not shades.has(form):
		var mesh: Mesh
		if form in ["pillar","exit"]:
			mesh = BoxMesh.new()
		elif form == "cap":
			var cap := SphereMesh.new()
			cap.radial_segments = 12
			cap.rings = 5
			mesh = cap
		else:
			var cone := CylinderMesh.new()
			cone.radial_segments = 6
			cone.rings = 1
			cone.top_radius = .03
			cone.bottom_radius = .46
			mesh = cone
		shades[form] = mesh
	node.mesh = shades[form]
	node.position = pos
	node.scale = scale_value
	var color: Color = Color("#e8ca82") if color_id == "sample" else (Color("#70d9a2") if color_id=="exit" else GLOWS[kind] if glow else Color("#696170"))
	node.material_override = material(color_id,color,glow)
	cave.add_child(node)
	return node


func _decoration(p: Vector3, h: float, j: int) -> void:
	match kind:
		0:
			_shape("pillar",p+Vector3.UP*h*.4,Vector3(.13,h*.8,.13),"stalk")
			_shape("cap",p+Vector3.UP*h*.87,Vector3(h*.83,h*.20,h*.83),"spore",true)
		1:
			if j % 2 == 0:
				var batch_key := Vector2i(roundi(p.x*16.),roundi(p.z*16.))
				_cluster("dep_quartz" if j==2 else "dep_iron_ore",batch_key,p,h*.57)
		2:
			_shape("pillar",p+Vector3.UP*h,Vector3(.5,h*2,.54),"stone")
			_shape("pillar",p+Vector3.UP*h*1.4,Vector3(.52,.10,.56),"rune",true)
		3:
			if j % 2:
				var tooth := _shape("shard",p+Vector3.UP*3.8,Vector3(.64,h,.64),"stone")
				tooth.rotation.x = PI
			else:
				_shape("cap",p+Vector3.UP*.08,Vector3(h,.07,h*.5),"ember",true)


func _process(delta: float) -> void:
	if info == null:
		return
	var dir := Input.get_vector("move_left","move_right","move_up","move_down")
	var step := Vector3(dir.x,0,dir.y).rotated(Vector3.UP,yaw)*delta*4.7
	for axis in [Vector3(step.x,0,0),Vector3(0,0,step.z)]:
		var next: Vector3 = walker+axis
		var safe := true
		for offset in [Vector2(.22,.22),Vector2(-.22,.22),Vector2(.22,-.22),Vector2(-.22,-.22)]:
			safe = safe and cells.has(Vector2i(roundi((next.x+offset.x)/STEP),roundi((next.z+offset.y)/STEP)))
		if safe:
			walker = next
	message_time -= delta
	encounter_time += delta
	repel_time = maxf(0,repel_time-delta)
	contact_time = maxf(0,contact_time-delta)
	if is_instance_valid(relic):
		relic.rotation.y = encounter_time*.65
	if is_instance_valid(guardian):
		var goal := guardian_home
		var separation := Vector2(walker.x-guardian.position.x, walker.z-guardian.position.z)
		var closing := separation.length() < 7.0 and repel_time <= 0
		if closing:
			goal = walker
		var next := guardian.position.move_toward(Vector3(goal.x,guardian.position.y,goal.z),delta*(1.25 if closing else 1.9))
		if cells.has(Vector2i(roundi(next.x/STEP),roundi(next.z/STEP))):
			next.y = floor_height(next.x,next.z)
			guardian.position = next
		if separation.length() > .1:
			guardian.rotation.y = atan2(separation.x,separation.y)
		var clip := "Hurt" if repel_time > 2.3 else "Walk" if guardian.position.distance_to(goal)>1.0 else "Idle"
		if closing and separation.length() < 1.5 and contact_time <= 0:
			clip = "Attack"
			contact_time = 2.5
			walker = Vector3.ZERO
			hud_line = "Страж вытеснил экспедицию ко входу"
			message_time = 3.0
		if guardian_clips != null and guardian_clips.has_animation(clip) and guardian_clips.current_animation != clip:
			guardian_clips.play(clip,.12)
	update_view()


func update_view() -> void:
	camera.position = walker+Vector3.UP*(1.6+floor_height(walker.x,walker.z))
	camera.rotation = Vector3(pitch,yaw,0)
	var hint := "WASD — идти   ·   мышь — обзор   ·   Esc — вернуться"
	for k in samples:
		if samples[k].position.distance_to(camera.position)<3:
			hint = "E — извлечь геологический образец"
			break
	if is_instance_valid(relic) and camera.position.distance_to(relic.position) < 2.5:
		hint = "E — забрать древний образец"
	if is_instance_valid(guardian) and camera.position.distance_to(guardian.position) < 7.5 and repel_time <= 0.0:
		hint += "   ·   F — отпугнуть стража светом"
	info.text = "%s\n%s" % [NAMES[kind],hud_line if message_time>0 else hint]


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		yaw -= event.relative.x * .0027
		pitch = clampf(pitch - event.relative.y*.0027, -1.25,1.25)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			leave()
		elif event.keycode == KEY_F and is_instance_valid(guardian) and repel_time <= 0 and camera.position.distance_to(guardian.position) < 7.5:
			repel_time = 3.0
			lamp.light_energy = 4.5
			create_tween().tween_property(lamp, "light_energy", 1.3, .45)
			hud_line = "Страж отступает от вспышки фонаря"
			message_time = 2.0
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("interact"):
			get_viewport().set_input_as_handled()
			collect()


func collect() -> void:
	if is_instance_valid(relic) and not relic.is_queued_for_deletion() and camera.position.distance_to(relic.position) < 2.0 and not entrance.bstate.get("relic_found",false):
		entrance.bstate["relic_found"] = true
		game.factory.give_player("crystal" if kind == 2 else "monster_core", 1)
		game.tech.research += 5
		hud_line = "Древний образец · +5 ОИ"
		message_time = 3.0
		relic.queue_free()
		if is_instance_valid(guardian):
			guardian.queue_free()
		return
	for key in samples:
		var sample: Node3D = samples[key]
		if camera.position.distance_to(sample.position) >= 3:
			continue
		if kind == 1 and not game.tech.done.has("t_geo2"):
			hud_line = "Для отбора кристаллов нужна Геология II"
		else:
			var item := ["fiber","crystal","circuit","iron_ore"][kind] as String
			game.factory.give_player(item, 3+kind)
			game.tech.research += 2
			visited[key] = true
			entrance.bstate["cave_samples"] = visited.duplicate()
			sample.queue_free()
			samples.erase(key)
			hud_line = DB.item_name(item) + " · +2 ОИ"
		message_time = 3
		return


func leave() -> void:
	Input.mouse_mode = previous_mouse
	get_tree().paused = old_pause
	queue_free()
