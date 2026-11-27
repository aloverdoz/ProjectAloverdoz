class_name PartRenderer
extends Node3D
## Рисует тысячи одинаковых объектов одним вызовом (MultiMesh).
## Каждый «объект» состоит из нескольких деталей; у каждой детали свой MultiMesh.
## Это главный приём против лагов на больших заводах.

const STRIDE := 20  # 12 (Transform3D) + 4 (цвет) + 4 (custom)

var parts: Array = []          # [{mm, local, color, tint, role}]
var model_id := ""
var roles := {}
var detailed: Array = []
var lod_wait := 0.0
var distance_level := 0
var owners: Array = []         # объект по индексу
var index_of: Dictionary = {}  # объект -> индекс
var capacity := 0
var base_xf: Array = []        # базовая матрица объекта
var tint: Array = []           # 0..1 (урон)
## 21: разбивка по участкам карты (метры; 0 — одним куском). Каждый участок — свой MultiMesh: камера
## и тени рисуют только участки в кадре, а не весь завод целиком (на больших картах — главный выигрыш).
var chunk := 0.0
var _defs: Array = []          # детали для новых участков
var _subs := {}                # Vector2i -> PartRenderer
var _owner_sub := {}           # объект -> PartRenderer участка
var _shadows_on := true


func _ready() -> void:
	set_process(not detailed.is_empty() and not owners.is_empty())


func _process(delta: float) -> void:
	lod_wait -= delta
	if lod_wait > 0:
		return
	lod_wait = .42 + float(get_instance_id() % 11) * .019
	var camera := get_viewport().get_camera_3d()
	if camera == null or detailed.is_empty():
		return
	var reference: Dictionary = detailed.front()
	var bounds: AABB = reference.mm.get_aabb()
	var eye := to_local(camera.global_position)
	var distance := eye.distance_to(eye.clamp(bounds.position,bounds.end))
	var px: float = get_viewport().mesh_lod_threshold
	if px <= 0:
		distance = 0.0
	var multiplier := clampf(2.0 / maxf(px, .25), .65, 2.5)
	var middle := 22.0 * multiplier
	var far_distance := 62.0 * multiplier
	var hysteresis := 1.10 if distance_level == 0 else .90
	var tier := 0 if distance < middle*hysteresis else (2 if distance > far_distance*(.9 if distance_level == 2 else 1.1) else 1)
	if tier == distance_level:
		return
	distance_level = tier
	for info in detailed:
		info.mm.mesh = info.original if tier == 0 else preload("res://scripts/distance_mesh.gd").variant(info.original, tier == 2)


func add_part(mesh: Mesh, mat: Material, local: Transform3D, color: Color, shadows := true, tintable := true, role := "") -> int:
	_defs.append([mesh, mat, local, color, shadows, tintable, role])
	for k in _subs:
		_subs[k].add_part(mesh, mat, local, color, shadows, tintable, role)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh
	if mesh is ArrayMesh and mesh.has_meta("colony_lods") and mesh.get_surface_count() == 1 and mesh.surface_get_array_index_len(0) > 18000:
		detailed.append({"original":mesh, "mm":mm})
	mm.instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	if not roles.has(role):
		roles[role] = []
	roles[role].append(parts.size())
	parts.append({"mm": mm, "local": local, "color": color, "mmi": mmi, "tint": tintable, "role": role})
	return parts.size() - 1


func _grow() -> void:
	var newcap: int = max(16, capacity * 2)
	for p in parts:
		var mm: MultiMesh = p.mm
		var vis := mm.visible_instance_count
		var old := mm.buffer if capacity > 0 else PackedFloat32Array()
		mm.instance_count = newcap
		var buf := old.duplicate()
		buf.resize(newcap * STRIDE)
		mm.buffer = buf
		mm.visible_instance_count = vis if capacity > 0 else 0
	capacity = newcap


func _sub_at(p: Vector3) -> PartRenderer:
	var k := Vector2i(floori(p.x / chunk), floori(p.z / chunk))
	var r: PartRenderer = _subs.get(k)
	if r == null:
		r = PartRenderer.new()
		r.model_id = model_id
		r.name = "c%d_%d" % [k.x, k.y]
		for i in _defs.size():
			var d: Array = _defs[i]
			r.add_part(d[0], d[1], d[2], d[3], d[4], d[5], d[6])
			r.parts[i].mmi.visibility_range_end = parts[i].mmi.visibility_range_end
			r.parts[i].mmi.visibility_range_end_margin = parts[i].mmi.visibility_range_end_margin
		if not _shadows_on:
			r.set_shadows(false)
		add_child(r)
		_subs[k] = r
	return r


func add(owner, xf: Transform3D, active := 0.0, phase := -1.0) -> void:
	if chunk > 0.0:
		if _owner_sub.has(owner):
			remove(owner)
		var sr := _sub_at(xf.origin)
		_owner_sub[owner] = sr
		sr.add(owner, xf, active, phase)
		return
	if owners.size() >= capacity:
		_grow()
	var i := owners.size()
	owners.append(owner)
	if owners.size() == 1 and not detailed.is_empty():
		set_process(true)
	base_xf.append(xf)
	tint.append(0.0)
	index_of[owner] = i
	if phase < 0.0:
		phase = randf()
	for p in parts:
		var mm: MultiMesh = p.mm
		mm.set_instance_transform(i, xf * p.local)
		mm.set_instance_color(i, p.color)
		mm.set_instance_custom_data(i, Color(active, phase, 0, 0))
		mm.visible_instance_count = owners.size()


func has(owner) -> bool:
	if chunk > 0.0:
		return _owner_sub.has(owner)
	return index_of.has(owner)


func remove(owner) -> void:
	if chunk > 0.0:
		var sr = _owner_sub.get(owner)
		if sr != null:
			sr.remove(owner)
			_owner_sub.erase(owner)
		return
	if not index_of.has(owner):
		return
	var i: int = index_of[owner]
	var last := owners.size() - 1
	if i != last:
		var other = owners[last]
		owners[i] = other
		base_xf[i] = base_xf[last]
		tint[i] = tint[last]
		index_of[other] = i
		for p in parts:
			var mm: MultiMesh = p.mm
			mm.set_instance_transform(i, mm.get_instance_transform(last))
			mm.set_instance_color(i, mm.get_instance_color(last))
			mm.set_instance_custom_data(i, mm.get_instance_custom_data(last))
	owners.pop_back()
	if owners.is_empty():
		set_process(false)
	base_xf.pop_back()
	tint.pop_back()
	index_of.erase(owner)
	for p in parts:
		p.mm.visible_instance_count = owners.size()


func set_xform(owner, xf: Transform3D) -> void:
	if chunk > 0.0:
		var sr = _owner_sub.get(owner)
		if sr == null:
			return
		if sr != _sub_at(xf.origin):
			# переехал на другой участок (вагонетка, лифт): переносим с цветом и анимацией
			var i0: int = sr.index_of[owner]
			var cd: Color = sr.parts[0].mm.get_instance_custom_data(i0) if not sr.parts.is_empty() else Color()
			var t0: float = sr.tint[i0]
			remove(owner)
			add(owner, xf, cd.r, cd.g)
			if t0 > 0.0:
				set_tint(owner, t0)
			return
		sr.set_xform(owner, xf)
		return
	var i: int = index_of.get(owner, -1)
	if i < 0:
		return
	base_xf[i] = xf
	for p in parts:
		p.mm.set_instance_transform(i, xf * p.local)


## Поворот отдельной детали (например, башни турели) относительно объекта.
func set_part_xform(owner, part: int, local: Transform3D) -> void:
	if chunk > 0.0:
		var sr = _owner_sub.get(owner)
		if sr != null:
			sr.set_part_xform(owner, part, local)
		return
	var i: int = index_of.get(owner, -1)
	if i < 0:
		return
	parts[part].mm.set_instance_transform(i, base_xf[i] * local)


func set_active(owner, active: float) -> void:
	if chunk > 0.0:
		var sr = _owner_sub.get(owner)
		if sr != null:
			sr.set_active(owner, active)
		return
	var i: int = index_of.get(owner, -1)
	if i < 0:
		return
	for p in parts:
		var c: Color = p.mm.get_instance_custom_data(i)
		c.r = active
		p.mm.set_instance_custom_data(i, c)


## Подкрашивает объект: 0 = норма, 1 = почти разрушен. flash > 0 = вспышка при попадании.
func set_tint(owner, dmg: float, flash := 0.0) -> void:
	if chunk > 0.0:
		var sr = _owner_sub.get(owner)
		if sr != null:
			sr.set_tint(owner, dmg, flash)
		return
	var i: int = index_of.get(owner, -1)
	if i < 0:
		return
	tint[i] = dmg
	for p in parts:
		if not p.tint:
			continue
		var c: Color = p.color
		c = c.lerp(Color(0.25, 0.05, 0.03), clamp(dmg, 0.0, 1.0) * 0.6)
		if flash > 0.0:
			c = c.lerp(Color(1.25, 1.1, 1.05), flash * 0.6)
		p.mm.set_instance_color(i, c)


func set_part_color(owner, part: int, c: Color) -> void:
	if chunk > 0.0:
		var sr = _owner_sub.get(owner)
		if sr != null:
			sr.set_part_color(owner, part, c)
		return
	var i: int = index_of.get(owner, -1)
	if i >= 0:
		parts[part].mm.set_instance_color(i, c)


func set_part_custom(owner, part: int, c: Color) -> void:
	if chunk > 0.0:
		var sr = _owner_sub.get(owner)
		if sr != null:
			sr.set_part_custom(owner, part, c)
		return
	var i: int = index_of.get(owner, -1)
	if i >= 0:
		parts[part].mm.set_instance_custom_data(i, c)


func parts_with_role(role: String) -> Array:
	return roles.get(role, [])


func set_shadows(on: bool) -> void:
	_shadows_on = on
	for k in _subs:
		_subs[k].set_shadows(on)
	for p in parts:
		p.mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func count() -> int:
	if chunk > 0.0:
		return _owner_sub.size()
	return owners.size()
