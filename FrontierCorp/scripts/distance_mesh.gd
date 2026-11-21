class_name DistanceMesh
extends RefCounted
## Unindexed attributes and PBR materials stay identical when changing index density.

static func variant(mesh: ArrayMesh, distant: bool) -> Mesh:
	var key := "distant_proxy" if distant else "middle_proxy"
	if mesh.has_meta(key):
		return mesh.get_meta(key)
	var levels: Array = mesh.get_meta("colony_lods", [])
	if levels.size() != 1 or levels[0].is_empty():
		return mesh
	var count := mesh.surface_get_array_index_len(0)
	var budget := maxi(144, roundi(count * (.008 if distant else .065)))
	var indices := PackedInt32Array()
	for level in levels[0].values():
		if indices.is_empty() or abs(level.size() - budget) < abs(indices.size() - budget):
			indices = level
	if indices.is_empty() or indices.size() >= count:
		return mesh
	var src := mesh.surface_get_arrays(0)
	if src[Mesh.ARRAY_BONES] != null or mesh.get_blend_shape_count() > 0:
		return mesh
	var remap := {}
	var vertices := PackedInt32Array()
	var compact := PackedInt32Array()
	compact.resize(indices.size())
	for i in indices.size():
		var old := indices[i]
		if not remap.has(old):
			remap[old] = vertices.size()
			vertices.append(old)
		compact[i] = remap[old]
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_INDEX] = compact
	for channel in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2, Mesh.ARRAY_COLOR]:
		if src[channel] == null or src[channel].is_empty():
			continue
		var stride := 4 if channel == Mesh.ARRAY_TANGENT else 1
		var packed = src[channel].slice(0,0)
		packed.resize(vertices.size()*stride)
		for i in vertices.size():
			for offset in stride:
				packed[i*stride+offset] = src[channel][vertices[i]*stride+offset]
		arrays[channel] = packed
	var proxy := ArrayMesh.new()
	proxy.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	proxy.surface_set_material(0, mesh.surface_get_material(0))
	mesh.set_meta(key, proxy)
	return proxy
