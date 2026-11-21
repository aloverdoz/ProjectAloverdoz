extends Node3D

func _ready() -> void:
	get_viewport().mesh_lod_threshold = 2.0
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	var r := ModelLib.make_renderer("miner", false, false)
	add_child(r)
	r.add("machine", Transform3D.IDENTITY)
	var good := not r.detailed.is_empty()
	var base: ArrayMesh = r.detailed[0].original
	var counts := []
	for z in [4, 32, 140, 3]:
		cam.position = Vector3(0,1,z)
		r._process(10.0)
		var current: ArrayMesh = r.detailed[0].mm.mesh
		counts.append(current.surface_get_array_index_len(0)/3)
		good = good and current.surface_get_material(0) == base.surface_get_material(0)
		var arrays := current.surface_get_arrays(0)
		good = good and arrays[Mesh.ARRAY_NORMAL].size() == arrays[Mesh.ARRAY_VERTEX].size() and arrays[Mesh.ARRAY_TEX_UV].size() == arrays[Mesh.ARRAY_VERTEX].size()
	good = good and counts[0] == counts[3] and counts[0] > counts[1] and counts[1] > counts[2]
	print("DISTANCE_QA ", counts, " ", "PASS" if good else "FAIL")
	get_tree().quit(0 if good else 1)
