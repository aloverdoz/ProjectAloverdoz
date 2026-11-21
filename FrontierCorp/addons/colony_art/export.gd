@tool
extends EditorExportPlugin

func _get_name() -> String:
	return "ColonyArtExport"

func _export_begin(_features: PackedStringArray, _debug: bool, _path: String, _flags: int) -> void:
	for directory in ["res://art/colony", "res://art/designed"]:
		var dir := DirAccess.open(directory)
		if dir == null:
			push_error("Missing folder " + directory)
			continue
		for file in dir.get_files():
			if file.get_extension() not in ["glb", "lod"]:
				continue
			var source: String = directory.path_join(file)
			var bytes := FileAccess.get_file_as_bytes(source)
			if bytes.is_empty():
				push_error("Empty file " + source)
			else:
				add_file(source, bytes, false)
