extends Node3D
## Витрина моделей для снимков: ряды моделей с подписями, свет и камера.
## Запуск: tools/showcase.sh имя "id1,id2,..." [колонок]

var shot := ""
var frames := 40
var n := 0

func _ready() -> void:
	var ids: Array = []
	var cols := 5
	var cam_pitch := 28.0
	var zoom := 1.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ids="):
			ids = Array(a.substr(6).split(","))
		elif a.begins_with("--shot="):
			shot = a.substr(7)
		elif a.begins_with("--cols="):
			cols = int(a.substr(7))
		elif a.begins_with("--pitch="):
			cam_pitch = float(a.substr(8))
		elif a.begins_with("--zoom="):
			zoom = float(a.substr(7))
		elif a.begins_with("--frames="):
			frames = int(a.substr(9))
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.62, 0.74, 0.86)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.8, 0.9)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	e.ssao_enabled = true
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)
	# "i:<предмет>" — модель предмета, белые детали красятся в цвет предмета
	var tints := {}
	var names := {}
	for i in ids.size():
		var id: String = ids[i]
		if id.begins_with("i:"):
			var it: Dictionary = DB.data.items.get(id.substr(2), DB.catalog_data().items.get(id.substr(2), {}))
			ids[i] = str(it.get("model", "drop_box"))
			tints[i] = DB.color(it.get("color", "#ffffff"))
			names[i] = str(it.get("name", id))
	# размеры моделей
	var sizes := []
	var cell := 1.0
	for id in ids:
		var ext := Vector3.ZERO
		for p in ModelLib.model(id).get("parts", []):
			var pos := ModelLib.v3(p.get("pos", [0, 0, 0]))
			var sz := ModelLib.v3(p.get("size", [1, 1, 1]), Vector3.ONE)
			ext.x = maxf(ext.x, absf(pos.x) + sz.length() * 0.35)
			ext.z = maxf(ext.z, absf(pos.z) + sz.length() * 0.35)
			ext.y = maxf(ext.y, pos.y + sz.y * 0.5)
		sizes.append(ext)
		cell = maxf(cell, maxf(ext.x, ext.z) * 2.0 + 0.6)
	var rows := int(ceil(ids.size() / float(cols)))
	var w := mini(cols, ids.size()) * cell
	var d := rows * cell
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(w + cell * 4, d + cell * 4)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.36, 0.5, 0.3)
	ground.material_override = gm
	add_child(ground)
	var maxh := 1.0
	for i in ids.size():
		var c := i % cols
		var r := i / cols
		var x := (c - (mini(cols, ids.size()) - 1) * 0.5) * cell
		var z := (r - (rows - 1) * 0.5) * cell
		var node := ModelLib.make_node(ids[i], false)
		if tints.has(i):
			for ch in node.get_children():
				if ch is MultiMeshInstance3D and (ch as MultiMeshInstance3D).multimesh.get_instance_color(0) == Color.WHITE:
					(ch as MultiMeshInstance3D).multimesh.set_instance_color(0, tints[i])
		node.position = Vector3(x, 0, z)
		node.rotation_degrees.y = -30
		add_child(node)
		maxh = maxf(maxh, sizes[i].y)
		var lb := Label3D.new()
		lb.text = names.get(i, str(ModelLib.model(ids[i]).get("name", ids[i])))
		lb.font_size = 64
		lb.pixel_size = 0.0016 * cell
		lb.outline_size = 12
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.position = Vector3(x, 0.12, z + cell * 0.42)
		add_child(lb)
	var cam := Camera3D.new()
	cam.fov = 40
	var span := maxf(w, d * 1.3) + maxh
	var dist := span * 0.75 / zoom
	var pr := deg_to_rad(cam_pitch)
	cam.position = Vector3(0, maxh * 0.4 + sin(pr) * dist, cos(pr) * dist)
	add_child(cam)
	cam.look_at(Vector3(0, maxh * 0.35, 0))
	cam.current = true


func _process(_d: float) -> void:
	n += 1
	if n == frames and shot != "":
		var img := get_viewport().get_texture().get_image()
		img.save_png(shot)
		print("SHOWCASE saved ", shot)
		get_tree().quit()
