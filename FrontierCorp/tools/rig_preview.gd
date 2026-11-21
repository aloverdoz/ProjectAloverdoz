extends Node
## Проверка автоскелета: модель → части по костям → монстр шагает / герой / здание. Сохраняет картинку.
## godot --path . tools/rig_preview.tscn -- --out=/tmp/x.png (--src=файл.glb | --proc="описание") --kind=monster --turn=90 [--debug]

var out := "/tmp/claude-0/shots2/rig.png"
var frames := 0
var rigs: Array = []
var kind := "monster"
var t := 0.0


func _ready() -> void:
	var src := ""
	var proc := ""
	var turn := 90.0
	var debug := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.substr(6)
		elif a.begins_with("--src="): src = a.substr(6)
		elif a.begins_with("--proc="): proc = a.substr(7)
		elif a.begins_with("--kind="): kind = a.substr(7)
		elif a.begins_with("--turn="): turn = float(a.substr(7))
		elif a == "--debug": debug = true
	if proc != "":
		# имитация ответа нейросети: одна сплошная сетка в GLB, «вперёд» — +Z, как у GLB
		var r := ModelGen.generate(proc, {"seed": 3, "quality": 1})
		var root := Node3D.new()
		var st := SurfaceTool.new()
		for rel in r.meshes:
			if str(rel).ends_with("_glow.res"):
				continue
			var mi := MeshInstance3D.new()
			mi.mesh = r.meshes[rel]
			mi.rotation_degrees = Vector3(0, -90, 0)
			var mat := StandardMaterial3D.new()
			mat.vertex_color_use_as_albedo = true
			mi.material_override = mat
			root.add_child(mi)
		var doc := GLTFDocument.new()
		var gs := GLTFState.new()
		doc.append_from_scene(root, gs)
		src = "/tmp/claude-0/proc_test.glb"
		print("EXPORT ", doc.write_to_filesystem(gs, src))
		root.free()
	RenderingServer.global_shader_parameter_set("view_on", 0.0)
	RenderingServer.global_shader_parameter_set("zone_on", 0.0)
	var t0 := Time.get_ticks_msec()
	var m := AutoRig.load_mesh(src)
	if debug:
		var pm0 := AutoRig._prepare(m, kind, {"turn": turn})
		var bb0: AABB = pm0.bb
		print("BB ", bb0)
		for yy in [0.08, 0.15, 0.25, 0.35, 0.5, 0.65]:
			var pcs := AutoRig._ground_pieces(pm0, bb0.position.y + bb0.size.y * yy)
			print("Y ", yy, " pieces=", pcs.size(), " sizes=", pcs.map(func(g): return g.verts.size()))
	print("LOAD ms=", Time.get_ticks_msec() - t0, " err=", m.get("err", ""), " verts=", (m.get("v", PackedVector3Array()) as PackedVector3Array).size())
	var res := AutoRig.rig(m, {"kind": kind, "turn": turn, "id": "ai_test", "footprint": 2})
	if res.has("err"):
		print("RIGERR ", res.err)
		get_tree().quit()
		return
	print("RIG ", res.info, " bones=", res.model.get("bones", {}), " legs=", JSON.stringify(res.model.get("rig", {}).get("legs", [])))
	var k := 0
	for rel in res.meshes:
		var mesh: ArrayMesh = res.meshes[rel]
		if debug:
			# каждая часть своим цветом
			var arr := mesh.surface_get_arrays(0)
			var cs: PackedColorArray = arr[Mesh.ARRAY_COLOR]
			var col := Color.from_hsv(fmod(k * 0.17, 1.0), 0.8, 0.95)
			for i in cs.size(): cs[i] = col
			arr[Mesh.ARRAY_COLOR] = cs
			mesh = ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		ModelLib.put_mesh(rel, mesh)
		if k == 0:
			var a0 := mesh.surface_get_arrays(0)
			print("COL0 ", (a0[Mesh.ARRAY_COLOR] as PackedColorArray).slice(0, 3), " fmt=", mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_COLOR)
		k += 1
	if "--notoon" in OS.get_cmdline_user_args(): res.model.erase("toon")
	DB.data.models["ai_test"] = res.model
	DB.revision += 1
	var root3 := Node3D.new()
	add_child(root3)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.16, 0.18, 0.22)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.6, 0.7)
	e.ambient_light_energy = 0.7
	env.environment = e
	root3.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.shadow_enabled = true
	root3.add_child(sun)
	var floor_ := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	floor_.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.32, 0.36, 0.3)
	floor_.material_override = fm
	root3.add_child(floor_)
	var H := 2.0
	if kind == "monster":
		for i in 3:
			var rg = preload("res://scripts/creature_rig.gd").new()
			root3.add_child(rg)
			print("BUILD ", rg.build("ai_test"))
			if rg.skin_mi:
				print("SKIN fmt=", rg.skin_mi.mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_BONES, " aabb=", rg.skin_mi.get_aabb(), " bones=", rg.skel.get_bone_count(), " vis=", rg.skin_mi.is_visible_in_tree())
				if "--stdmat" in OS.get_cmdline_user_args():
					var sm := StandardMaterial3D.new()
					sm.vertex_color_use_as_albedo = true
					rg.skin_mi.material_override = sm
			rigs.append(rg)
	else:
		var n := ModelLib.make_node("ai_test", false, false)
		root3.add_child(n)
		if kind == "hero":
			# в окне героя части в координатах костей: соберём по костям вручную
			n.queue_free()
			var bones: Dictionary = res.model.bones
			var par := {"leg_l": "hips", "leg_r": "hips", "shin_l": "leg_l", "shin_r": "leg_r", "torso": "hips", "head": "torso",
				"arm_l": "torso", "arm_r": "torso", "fore_l": "arm_l", "fore_r": "arm_r", "hand_r": "fore_r", "gun": "hand_r"}
			var W := {}
			for bn in ["hips", "leg_l", "leg_r", "shin_l", "shin_r", "torso", "head", "arm_l", "arm_r", "fore_l", "fore_r", "hand_r", "gun"]:
				W[bn] = ModelLib.v3(bones[bn]) + (W[par[bn]] if par.has(bn) else Vector3.ZERO)
			var pose := {"leg_l": 25.0, "leg_r": -25.0, "arm_l": -30.0, "arm_r": 40.0, "fore_r": 30.0, "shin_l": -20.0}
			for p in res.model.parts:
				var mi := MeshInstance3D.new()
				mi.mesh = ModelLib.part_mesh(p)
				var mat := StandardMaterial3D.new()
				mat.vertex_color_use_as_albedo = true
				mat.vertex_color_is_srgb = true
				mi.material_override = mat
				var role: String = p.role
				# поза: поворот вокруг сустава (вперёд-назад), с учётом родителя
				var xf := Transform3D(Basis(), W[role])
				var chain := [role]
				while par.has(chain[0]):
					chain.push_front(par[chain[0]])
				var acc := Transform3D.IDENTITY
				for bn in chain:
					var off: Vector3 = ModelLib.v3(bones[bn])
					acc = acc * Transform3D(Basis(Vector3.BACK, deg_to_rad(pose.get(bn, 0.0))), off)
					acc = Transform3D(acc.basis, acc.origin)
				mi.transform = acc
				root3.add_child(mi)
	var cam := Camera3D.new()
	root3.add_child(cam)
	cam.fov = 40
	var span := 9.0 if kind == "monster" else 5.0
	cam.look_at_from_position(Vector3(span * 0.5, span * 0.6, span * 1.1), Vector3(0, 0.8, 0), Vector3.UP)


func _process(d: float) -> void:
	frames += 1
	t += 1.0 / 30.0
	for i in rigs.size():
		var rg = rigs[i]
		var z := (i - 1) * 3.2
		if i == 0:
			rg.animate(1.0 / 30.0, Vector3(fmod(t * 3.0, 6.0) - 3.0, 0, z), 0.0, 1.0, {"speed": 3.0})
		elif i == 1:
			if frames == 14: rg.strike()
			rg.animate(1.0 / 30.0, Vector3(0, 0, z), 0.0, 1.0, {"speed": 3.0, "windup": 0.0})
		else:
			rg.animate(1.0 / 30.0, Vector3(t * 2.2, 0, z), 0.0, 1.0, {"speed": 3.0})
	if frames == 10 and "--two" in OS.get_cmdline_user_args():
		get_viewport().get_texture().get_image().save_png(out.replace(".png", "_a.png"))
	if frames == 18:
		get_viewport().get_texture().get_image().save_png(out)
		print("SHOT ", out)
		get_tree().quit()
