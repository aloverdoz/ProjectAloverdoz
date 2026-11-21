class_name WrapMirror
extends Node
## Зацикленный мир: когда герой подходит к краю карты, объекты с другой стороны
## показываются копиями (тот же MultiMesh, сдвинутый на размер мира).
## Копии создаются напрямую в RenderingServer — это дёшево, и только рядом с краем.

var roots: Array = []
var size := 768.0
var range_m := 170.0
var nodes: Array = []
var ghosts := {}       # "id|ox|oz" -> {rid, node, off}
var acc := 0.0
var scan_acc := 0.0
var view_clock := 0.0
var view_radius := 170.0


func setup(world_size: float, root_nodes: Array) -> void:
	size = world_size
	roots = root_nodes


func _scan() -> void:
	nodes.clear()
	for r in roots:
		if is_instance_valid(r):
			_collect(r)


func _collect(n: Node) -> void:
	if n.has_meta("no_mirror"):
		return
	if n is MultiMeshInstance3D or n is MeshInstance3D:
		nodes.append(n)
	for c in n.get_children():
		_collect(c)


## 21: обход дерева сцены по кусочку за кадр — на больших картах полный обход давал рывок до 150 мс.
var _stack: Array = []
var _found: Array = []
var _scanning := false


func _scan_step(budget: int) -> void:
	if not _scanning:
		_scanning = true
		_stack.clear()
		_found.clear()
		for r in roots:
			if is_instance_valid(r):
				_stack.append(r)
	while budget > 0 and not _stack.is_empty():
		var n = _stack.pop_back()
		budget -= 1
		if not is_instance_valid(n) or n.has_meta("no_mirror"):
			continue
		if n is MultiMeshInstance3D or n is MeshInstance3D:
			_found.append(n)
		_stack.append_array(n.get_children())
	if _stack.is_empty():
		_scanning = false
		nodes = _found.duplicate()
		scan_acc = 0.0


func _exit_tree() -> void:
	clear()


func clear() -> void:
	for k in ghosts:
		RenderingServer.free_rid(ghosts[k].rid)
	ghosts.clear()


func visible_radius(focus: Vector3) -> float:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return range_m
	var size_px := get_viewport().get_visible_rect().size
	var radius := 24.0
	for corner in [Vector2.ZERO, Vector2(size_px.x,0), size_px, Vector2(0,size_px.y)]:
		var ray := cam.project_ray_normal(corner)
		if ray.y > -.08:
			return range_m
		var origin := cam.project_ray_origin(corner)
		var end := origin + ray * maxf(0.0,(focus.y-18.0-origin.y)/ray.y)
		radius = maxf(radius, maxf(absf(end.x-focus.x),absf(end.z-focus.z))+20.0)
	return minf(radius,range_m)


func update(delta: float, focus: Vector3, scenario: RID) -> void:
	view_clock -= delta
	if view_clock <= 0:
		view_clock = .24
		view_radius = visible_radius(focus)
	acc += delta
	scan_acc += delta
	# подвижные одиночные объекты (падающее дерево, гнездо) — каждый кадр
	for k in ghosts:
		var g: Dictionary = ghosts[k]
		if g.dyn and is_instance_valid(g.node):
			RenderingServer.instance_set_transform(g.rid, Transform3D(Basis(), g.off) * g.node.global_transform)
	var near_edge: bool = focus.x < view_radius or focus.x > size - view_radius or focus.z < view_radius or focus.z > size - view_radius
	if not near_edge:
		if not ghosts.is_empty():
			clear()
		return   # далеко от края — копии не нужны, дерево сцены не обходим
	if _scanning or scan_acc > 2.0 or nodes.is_empty():
		_scan_step(4000)
	if nodes.is_empty() and _scanning:
		return
	if acc < 0.4:
		return
	acc = 0.0
	var offs := []
	var ox := []
	var oz := []
	if focus.x < view_radius:
		ox.append(-size)
	if focus.x > size - view_radius:
		ox.append(size)
	if focus.z < view_radius:
		oz.append(-size)
	if focus.z > size - view_radius:
		oz.append(size)
	for x in ox:
		offs.append(Vector3(x, 0, 0))
		for z in oz:
			offs.append(Vector3(x, 0, z))
	for z in oz:
		offs.append(Vector3(0, 0, z))
	var view := AABB(focus - Vector3(view_radius, 50, view_radius), Vector3(view_radius * 2, 200, view_radius * 2))
	var want := {}
	if not offs.is_empty():
		for n in nodes:
			if not is_instance_valid(n) or not n.is_visible_in_tree():
				continue
			var base := _base(n)
			if not base.is_valid():
				continue
			var gx: Transform3D = n.global_transform
			var box: AABB = gx * n.get_aabb()
			for o in offs:
				var b2 := AABB(box.position + o, box.size)
				if not b2.intersects(view):
					continue
				var key := "%d|%d|%d" % [n.get_instance_id(), int(o.x), int(o.z)]
				want[key] = true
				if not ghosts.has(key):
					ghosts[key] = _make(n, base, o, scenario)
				var g: Dictionary = ghosts[key]
				if not g.dyn:
					RenderingServer.instance_set_transform(g.rid, Transform3D(Basis(), o) * gx)
	for k in ghosts.keys():
		if not want.has(k):
			RenderingServer.free_rid(ghosts[k].rid)
			ghosts.erase(k)


func _base(n: GeometryInstance3D) -> RID:
	if n is MultiMeshInstance3D:
		var mm: MultiMesh = (n as MultiMeshInstance3D).multimesh
		if mm == null or mm.visible_instance_count == 0:
			return RID()
		return mm.get_rid()
	var m: Mesh = (n as MeshInstance3D).mesh
	return m.get_rid() if m else RID()


func _make(n: GeometryInstance3D, base: RID, off: Vector3, scenario: RID) -> Dictionary:
	var rid := RenderingServer.instance_create2(base, scenario)
	if n.material_override:
		RenderingServer.instance_geometry_set_material_override(rid, n.material_override.get_rid())
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for i in mi.get_surface_override_material_count():
			var m := mi.get_surface_override_material(i)
			if m:
				RenderingServer.instance_set_surface_override_material(rid, i, m.get_rid())
	RenderingServer.instance_geometry_set_cast_shadows_setting(rid, RenderingServer.SHADOW_CASTING_SETTING_OFF)
	if n.visibility_range_end > 0.0:
		RenderingServer.instance_geometry_set_visibility_range(rid, 0.0, n.visibility_range_end, 0.0, n.visibility_range_end_margin, RenderingServer.VISIBILITY_RANGE_FADE_DISABLED)
	RenderingServer.instance_set_transform(rid, Transform3D(Basis(), off) * n.global_transform)
	return {"rid": rid, "node": n, "off": off, "dyn": n is MeshInstance3D}
