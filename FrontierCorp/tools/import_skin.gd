extends SceneTree
## 1.3: персонаж одной сеткой на костях (готовая модель, например из нейросети Tripo) → models20/<id>/.
## Буферы готовит Blender-скрипт art20/anime/rig_anime.py: v n uv (float32), i (int32), b w (по 4 на вершину), rig.json.
## godot --headless --path . -s tools/import_skin.gd -- --src=DIR --id=hero_anime --tex=PNG --name=... --order=10 --gun_from=hero_lady

func _init() -> void:
	var a := {}
	for s in OS.get_cmdline_user_args():
		var kv := s.trim_prefix("--").split("=", true, 1)
		a[kv[0]] = kv[1] if kv.size() > 1 else ""
	var src: String = a.get("src", "")
	var id: String = a.get("id", "hero_skin")
	var rig: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(src + "/rig.json"))
	var f32 := func(n: String) -> PackedFloat32Array: return FileAccess.get_file_as_bytes(src + "/" + n + ".bin").to_float32_array()
	var i32 := func(n: String) -> PackedInt32Array: return FileAccess.get_file_as_bytes(src + "/" + n + ".bin").to_int32_array()
	var v: PackedFloat32Array = f32.call("v")
	var nn: PackedFloat32Array = f32.call("n")
	var uv: PackedFloat32Array = f32.call("uv")
	var V := PackedVector3Array()
	var N := PackedVector3Array()
	var U := PackedVector2Array()
	for k in v.size() / 3:
		V.append(Vector3(v[k * 3], v[k * 3 + 1], v[k * 3 + 2]))
		N.append(Vector3(nn[k * 3], nn[k * 3 + 1], nn[k * 3 + 2]).normalized())
		U.append(Vector2(uv[k * 2], uv[k * 2 + 1]))
	var I: PackedInt32Array = i32.call("i")
	for t in I.size() / 3:   # Blender — против часовой, Godot — по часовой
		var x := I[t * 3 + 1]
		I[t * 3 + 1] = I[t * 3 + 2]
		I[t * 3 + 2] = x
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = V
	arr[Mesh.ARRAY_NORMAL] = N
	arr[Mesh.ARRAY_TEX_UV] = U
	arr[Mesh.ARRAY_BONES] = i32.call("b")
	arr[Mesh.ARRAY_WEIGHTS] = f32.call("w")
	arr[Mesh.ARRAY_INDEX] = I
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var dir := "res://models20/" + id
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	ResourceSaver.save(am, dir + "/skin.res")
	var img := Image.load_from_file(a.get("tex", ""))
	img.save_png(ProjectSettings.globalize_path(dir + "/tex0.png"))
	var mat := {"shape": "mesh", "mesh": dir + "/skin.res", "color": "#ffffff", "mat": "paint", "metallic": 0, "roughness": 0.55,
		"surface": "none", "texture": dir + "/tex0.png", "pos": [0, 0, 0], "rot": [0, 0, 0], "size": [1, 1, 1]}
	var parts := []
	var gf: String = a.get("gun_from", "")
	if gf != "":
		var gm = JSON.parse_string(FileAccess.get_file_as_string("res://models20/%s/model.json" % gf))
		for p in gm.parts:
			if str(p.get("role", "")) == "gun":
				parts.append(p)
	var extra := {"name": a.get("name", id), "category": a.get("category", "Герои"), "scale": 1.25, "prof_tint": 0, "gun_pitch": 0,
		"look_order": int(a.get("order", "50")), "bones": rig.bones,
		"skin": {"mesh": dir + "/skin.res", "bones": rig.names, "mat": mat}}
	var fo := FileAccess.open(dir + "/model.json", FileAccess.WRITE)
	fo.store_string(JSON.stringify({"extra": extra, "parts": parts}, " "))
	fo.close()
	print("IMPORT_SKIN ", id, " verts=", V.size(), " tris=", I.size() / 3, " parts=", parts.size())
	quit()
