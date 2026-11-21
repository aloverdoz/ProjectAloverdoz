extends SceneTree
## Импорт моделей из Blender (этап 20): GLB → детали игры.
## godot --headless --path . -s tools/import20.gd -- --src=/путь/к/glb [--ids=a,b]
## Для каждого <id>.glb пишет res://models20/<id>/ : меши деталей (.res, с LOD), текстуру (.png)
## и model.json — список деталей в формате models.json (shape "mesh").
## Имя узла в Blender: «имя__anim-spin_fast__role-head» — анимация и роль детали.

var src := ""
var only := PackedStringArray()


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--src="):
			src = a.substr(6)
		elif a.begins_with("--ids="):
			only = a.substr(6).split(",", false)
	var d := DirAccess.open(src)
	if d == null:
		print("IMPORT20 ERROR нет папки ", src)
		quit(1)
		return
	var n := 0
	for f in d.get_files():
		if not f.ends_with(".glb"):
			continue
		var id := f.get_basename()
		if not only.is_empty() and not id in only:
			continue
		if _import(id, src.path_join(f)):
			n += 1
	print("IMPORT20 done ", n)
	quit()


func _hex(c: Color) -> String:
	return "#" + c.to_html(false)


func _import(id: String, path: String) -> bool:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_file(path, st) != OK:
		print("IMPORT20 ERROR ", path)
		return false
	var scene := doc.generate_scene(st)
	var out_dir := "res://models20/" + id
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	# старые файлы модели убираем, чтобы не копились
	var od := DirAccess.open(out_dir)
	for f in od.get_files():
		if f.ends_with(".res") or f.ends_with(".png") or f.ends_with(".import"):
			od.remove(f)
	var parts := []
	var texs := {}
	var info := {"n": 0}
	_walk(scene, Transform3D.IDENTITY, out_dir, parts, texs, info)
	scene.free()
	var res := {"parts": parts}
	# доп. поля модели (частицы и т.п.) — рядом с glb в <id>.json
	var side := path.get_basename() + ".json"
	if FileAccess.file_exists(side):
		res["extra"] = JSON.parse_string(FileAccess.get_file_as_string(side))
	var f := FileAccess.open(out_dir.path_join("model.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(res, " "))
	f.close()
	print("IMPORT20 ", id, " parts=", parts.size(), " tris=", info.get("tris", 0))
	return true


func _walk(n: Node, xf: Transform3D, out_dir: String, parts: Array, texs: Dictionary, info: Dictionary) -> void:
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var mi := n as MeshInstance3D
		var nm := str(mi.name)
		var meta := {}
		for seg in nm.split("__"):
			var kv := seg.split("-", true, 1)
			if kv.size() == 2 and kv[0] in ["anim", "role", "mat", "tint"]:
				meta[kv[0]] = kv[1]
		for si in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(si)
			for ci in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
				arr[ci] = null
			var has_col: bool = arr[Mesh.ARRAY_COLOR] != null and (arr[Mesh.ARRAY_COLOR] as PackedColorArray).size() > 0
			if has_col:
				# glTF хранит цвета вершин в линейном виде, а шейдер деталей ждёт sRGB (как у цветов деталей)
				var vc: PackedColorArray = arr[Mesh.ARRAY_COLOR]
				for ci in vc.size():
					vc[ci] = vc[ci].linear_to_srgb()
				arr[Mesh.ARRAY_COLOR] = vc
			# без UV касательные мусорные (а шейдер деталей их не использует) — убираем
			if arr[Mesh.ARRAY_TEX_UV] == null or (arr[Mesh.ARRAY_TEX_UV] as PackedVector2Array).is_empty():
				arr[Mesh.ARRAY_TANGENT] = null
			var tris: int = (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3 if arr[Mesh.ARRAY_INDEX] != null else 0
			info["tris"] = int(info.get("tris", 0)) + tris
			var im := ImporterMesh.new()
			im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arr)
			if tris > 400:
				im.generate_lods(25.0, 60.0, [])
			var mesh := im.get_mesh()
			var mp := out_dir.path_join("%d.res" % info.n)
			info.n += 1
			ResourceSaver.save(mesh, mp)
			var p := {"shape": "mesh", "mesh": mp, "surface": "none"}
			var mat := mi.get_active_material(si)
			if mat == null:
				mat = mi.mesh.surface_get_material(si)
			var sm := mat as BaseMaterial3D
			var col := Color.WHITE
			if sm:
				col = sm.albedo_color
				p["metallic"] = snappedf(sm.metallic, 0.01)
				p["roughness"] = snappedf(sm.roughness, 0.01)
				if sm.emission_enabled and sm.emission_energy_multiplier > 0.01 and sm.emission != Color.BLACK:
					p["mat"] = "glow"
					col = sm.emission
					p["emission"] = snappedf(clampf(sm.emission_energy_multiplier, 0.5, 6.0), 0.1)
				elif sm.albedo_texture:
					var tex := sm.albedo_texture
					var key := tex.get_rid().get_id()
					if not texs.has(key):
						var tp := out_dir.path_join("tex%d.png" % texs.size())
						var img := tex.get_image()
						if img.is_compressed():
							img.decompress()
						img.save_png(ProjectSettings.globalize_path(tp))
						# сжатие для видеокарты (S3TC/ETC) и mip-уровни: при сотнях моделей экономит память
						var imp := FileAccess.open(ProjectSettings.globalize_path(tp) + ".import", FileAccess.WRITE)
						imp.store_string("[remap]\n\nimporter=\"texture\"\ntype=\"CompressedTexture2D\"\n\n[deps]\n\nsource_file=\"%s\"\n\n[params]\n\ncompress/mode=2\nmipmaps/generate=true\n" % tp)
						imp.close()
						texs[key] = tp
					p["texture"] = texs[key]
					col = Color.WHITE
			if has_col:
				col = Color.WHITE
			p["color"] = _hex(col)
			if p.get("mat", "") == "":
				p["mat"] = "paint"
			for k in meta:
				if k == "tint":
					p["tint"] = meta[k] == "1"
				elif k == "mat" and p.get("mat") == "glow":
					pass
				else:
					p[k] = meta[k]
			var b := t.basis
			var sc := b.get_scale()
			var e := b.orthonormalized().get_euler() * (180.0 / PI)
			p["pos"] = [snappedf(t.origin.x, 0.0001), snappedf(t.origin.y, 0.0001), snappedf(t.origin.z, 0.0001)]
			p["rot"] = [snappedf(e.x, 0.01), snappedf(e.y, 0.01), snappedf(e.z, 0.01)]
			p["size"] = [snappedf(sc.x, 0.0001), snappedf(sc.y, 0.0001), snappedf(sc.z, 0.0001)]
			parts.append(p)
	for c in n.get_children():
		_walk(c, t, out_dir, parts, texs, info)
