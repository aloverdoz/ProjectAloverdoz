extends Node

func _ready() -> void:
	call_deferred("bake")


func bake() -> void:
	var selected := OS.get_cmdline_user_args()
	for directory in ["res://art/colony", "res://art/designed"]:
		for name in DirAccess.get_files_at(directory):
			if not name.ends_with(".glb") or (not selected.is_empty() and not name in selected):
				continue
			var path: String = directory.path_join(name)
			var doc := GLTFDocument.new()
			var state := GLTFState.new()
			if doc.append_from_file(path, state) != OK:
				get_tree().quit(1)
				return
			var scene := doc.generate_scene(state)
			var instances := scene.find_children("*", "MeshInstance3D", true, false)
			var levels := []
			for instance in instances:
				var mesh: ArrayMesh = instance.mesh
				var surfaces := []
				for surface in mesh.get_surface_count():
					var arrays := mesh.surface_get_arrays(surface)
					var im := ImporterMesh.new()
					im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
					im.generate_lods(60.0, 25.0, [])
					var lods := {}
					for lod in im.get_surface_lod_count(0):
						var indices := im.get_surface_lod_indices(0, lod)
						if not indices.is_empty():
							lods[im.get_surface_lod_size(0, lod)] = indices
					var resulting: Array = im.get_surface_arrays(0)
					if arrays[Mesh.ARRAY_VERTEX] != resulting[Mesh.ARRAY_VERTEX]:
						push_error("LOD vertices changed: " + name)
						get_tree().quit(1)
						return
					surfaces.append(lods)
					print(name, " levels=", lods.size())
				levels.append(surfaces)
			var file := FileAccess.open_compressed(path.get_basename() + ".lod", FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
			file.store_var(levels)
			file.close()
			scene.free()
	get_tree().quit()
