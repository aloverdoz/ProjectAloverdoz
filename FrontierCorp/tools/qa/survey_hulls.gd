extends Node

func _ready() -> void:
	var directory := OS.get_environment("FRONTIER_SURVEY_DIR")
	if directory.is_empty():
		get_tree().quit(1)
		return
	for id in DB.data.buildings:
		var model := str(DB.building(id).get("model",id))
		var file := FileAccess.open(directory.path_join(id+".bin"),FileAccess.WRITE)
		for part in ModelLib.parts_of(model,false):
			var mesh: Mesh = part[0]
			for surface in mesh.get_surface_count():
				var arrays := mesh.surface_get_arrays(surface)
				var points: PackedVector3Array = part[2] * arrays[Mesh.ARRAY_VERTEX]
				var ids = arrays[Mesh.ARRAY_INDEX]
				var indices := PackedInt32Array(ids) if ids != null else PackedInt32Array()
				file.store_32(points.size())
				file.store_32(indices.size())
				file.store_buffer(points.to_byte_array())
				file.store_buffer(indices.to_byte_array())
		file.close()
	print("SURVEY ",DB.data.buildings.size())
	get_tree().quit()
