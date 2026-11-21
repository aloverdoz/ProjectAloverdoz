class_name AutoRig
extends RefCounted
## Автоскелет для готовой сплошной модели (нейросеть, GLB из интернета или из Blender).
## Сетка делится на части по костям, а двигает их скелет игры:
##  • монстр — ноги (бедро и колено), корпус, голова, хвост; ходьба, дыхание, замах и удар, смерть;
##  • герой — ноги, руки, корпус, голова; ходьбу, бег, удар и добычу играет сам герой;
##  • здание — корпус и светящиеся места, которые мигают, когда здание работает.
## Ноги находятся сами: всё, что ниже бёдер и касается земли отдельными кусками, — ноги.
## Монстр смотрит вдоль +X (у GLB «вперёд» — +Z, поэтому по умолчанию модель поворачивается на 90°).

const C_CELL := 2.0
const HERO_PARENT := {"leg_l": "hips", "leg_r": "hips", "shin_l": "leg_l", "shin_r": "leg_r", "torso": "hips", "head": "torso",
	"arm_l": "torso", "arm_r": "torso", "fore_l": "arm_l", "fore_r": "arm_r", "hand_r": "fore_r", "gun": "hand_r"}


## Прочитать модель из файла в одну сетку: {v, n, c, i} (цвет в вершинах, sRGB) или {err}.
static func load_mesh(path: String) -> Dictionary:
	var ext := path.get_extension().to_lower()
	var parts := []
	if ext in ["res", "tres", "mesh"]:
		var m := ResourceLoader.load(ModelLib.resolve_path(path), "", ResourceLoader.CACHE_MODE_IGNORE) as Mesh
		if m:
			parts.append([m, null, Transform3D.IDENTITY])
	else:
		parts = ModelLib._glb_parts(path)
	if parts.is_empty():
		var why := ModelLib.glb_problem(path) if ext in ["glb", "gltf"] else "файл не найден или это не модель"
		return {"err": why if why != "" else "в файле нет сетки"}
	var V := PackedVector3Array()
	var N := PackedVector3Array()
	var Cc := PackedColorArray()
	var I := PackedInt32Array()
	for gp in parts:
		var mesh: Mesh = gp[0]
		var xf: Transform3D = gp[2]
		var nb := xf.basis.inverse().transposed()
		var flip := xf.basis.determinant() < 0.0
		for si in mesh.get_surface_count():
			if mesh.surface_get_primitive_type(si) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			var arr := mesh.surface_get_arrays(si)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ns = arr[Mesh.ARRAY_NORMAL]
			var cs = arr[Mesh.ARRAY_COLOR]
			var uvs = arr[Mesh.ARRAY_TEX_UV]
			var ids = arr[Mesh.ARRAY_INDEX]
			var mat: Material = gp[1] if gp[1] != null else mesh.surface_get_material(si)
			var base_col := Color.WHITE
			var img: Image = null
			var emis := false
			if mat is BaseMaterial3D:
				var bm := mat as BaseMaterial3D
				base_col = bm.albedo_color
				emis = bm.emission_enabled
				if bm.albedo_texture:
					img = bm.albedo_texture.get_image()
					if img and img.is_compressed():
						img = img.duplicate()
						img.decompress()
			var b := V.size()
			for vi in vs.size():
				V.append(xf * vs[vi])
				N.append((nb * (ns[vi] if ns != null and vi < ns.size() else Vector3.UP)).normalized())
				var c := base_col
				if cs != null and vi < cs.size():
					c = c * (cs[vi] as Color)
				if img != null and uvs != null and vi < uvs.size():
					var uv: Vector2 = uvs[vi]
					var w := img.get_width()
					var h := img.get_height()
					c = c * img.get_pixel(posmod(int(uv.x * w), w), posmod(int(uv.y * h), h))
				# светящийся материал помечаем альфой 0.9 — потом из него получится «огонёк»
				c.a = 0.9 if emis else 1.0
				Cc.append(c)
			if ids != null and (ids as PackedInt32Array).size() > 0:
				for ti in range(0, ids.size(), 3):
					if flip:
						I.append(b + ids[ti]); I.append(b + ids[ti + 2]); I.append(b + ids[ti + 1])
					else:
						I.append(b + ids[ti]); I.append(b + ids[ti + 1]); I.append(b + ids[ti + 2])
			else:
				for vi in range(0, vs.size() - 2, 3):
					I.append(b + vi); I.append(b + vi + 1); I.append(b + vi + 2)
	if I.size() < 12:
		return {"err": "в модели слишком мало треугольников"}
	return {"v": V, "n": N, "c": Cc, "i": I}


## Главное: сетка → модель игры. opts: kind (monster|hero|building), turn (градусы вокруг вертикали),
## height (м, монстр), footprint (клеток, здание), tris (бюджет треугольников), id, dir.
## Возвращает {model, meshes {путь: ArrayMesh}, info} или {err}.
static func rig(src: Dictionary, opts: Dictionary) -> Dictionary:
	if src.has("err"):
		return src
	var kind := str(opts.get("kind", "monster"))
	var t0 := Time.get_ticks_msec()
	var m := _prepare(src, kind, opts)
	var seg: Dictionary
	match kind:
		"hero":
			seg = _seg_hero(m)
		"building":
			seg = _seg_building(m)
		_:
			seg = _seg_monster(m)
	var mid := str(opts.get("id", "ai_model"))
	var dir := str(opts.get("dir", "gen"))
	var meshes := {}
	var parts := []
	var labels: PackedInt32Array = seg.labels
	var names: Array = seg.names
	var shift: Dictionary = seg.get("shift", {})
	for li in names.size():
		var nm0: String = names[li]
		# лапы, руки и хвост чуть заходят в тело (при шаге нет щели); голова и корпус — без захода
		var rings := 2 if (nm0.begins_with("leg") or nm0.begins_with("shin") or nm0.begins_with("tail") or nm0.begins_with("arm") or nm0.begins_with("fore")) else 0
		var am := _part_mesh(m, labels, li, shift.get(names[li], Vector3.ZERO), rings)
		if am == null:
			continue
		var nm: String = names[li]
		var rel := "%s/%s/%s.res" % [dir, mid, nm.replace(":", "_")]
		meshes[rel] = am
		var glow: bool = nm.begins_with("glow")
		var p := {"shape": "mesh", "mesh": rel, "pos": [0, 0, 0], "size": [1, 1, 1], "color": "#ffffff",
			"mat": "glow" if glow else str(opts.get("mat", "paint")), "tint": not glow}
		if glow:
			p["emission"] = 2.0
			p["anim"] = "pulse"
		else:
			p["metallic"] = float(opts.get("metallic", 0.25))
			p["roughness"] = float(opts.get("roughness", 0.6))
		var role := str(seg.roles.get(nm, ""))
		if role != "":
			p["role"] = role
		parts.append(p)
	var model := {"name": str(opts.get("name", "Модель нейросети")), "category": str(opts.get("category", "Нейросеть")), "parts": parts,
		"ai": {"src": str(opts.get("src", "")), "kind": kind, "turn": float(opts.get("turn", 90.0)), "prompt": str(opts.get("prompt", ""))}}
	if seg.has("rig"):
		model["rig"] = seg.rig
		# вблизи монстр рисуется одной гладкой сеткой на костях (без щелей на суставах), вдали — частями
		var sk := _skin_mesh(m, labels, names, seg.roles, seg.rig)
		if sk != null:
			var srel := "%s/%s/skin.res" % [dir, mid]
			meshes[srel] = sk
			model["skin"] = {"mesh": srel, "bones": seg.rig.bones.map(func(b): return b.name)}
	if seg.has("bones"):
		model["bones"] = seg.bones
		model["scale"] = 1.25
		# герой тоже гладкой сеткой на костях (кости героя: hips, ноги, торс, голова, руки)
		var hb := []
		for bn in ["hips", "leg_l", "leg_r", "shin_l", "shin_r", "torso", "head", "arm_l", "arm_r", "fore_l", "fore_r", "hand_r"]:
			hb.append({"name": bn, "parent": HERO_PARENT.get(bn, ""), "pivot": _a(seg.world[bn])})
		var hsk := _skin_mesh(m, labels, names, seg.roles, {"bones": hb})
		if hsk != null:
			var hrel := "%s/%s/skin.res" % [dir, mid]
			meshes[hrel] = hsk
			model["skin"] = {"mesh": hrel, "bones": hb.map(func(b): return b.name)}
	var info := {"tris": 0, "parts": names.size(), "legs": seg.get("legs", 0), "ms": 0, "note": str(seg.get("note", ""))}
	for k in meshes:
		if str(k).ends_with("/skin.res"):
			continue
		var am2: ArrayMesh = meshes[k]
		info.tris += (am2.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	info.ms = Time.get_ticks_msec() - t0
	return {"model": model, "meshes": meshes, "info": info}


# ================================================================ подготовка

## Поворот, «на землю», размер, упрощение, сварка вершин (для связности).
static func _prepare(src: Dictionary, kind: String, opts: Dictionary) -> Dictionary:
	var V: PackedVector3Array = src.v.duplicate()
	var Nn: PackedVector3Array = src.n.duplicate()
	var Cc: PackedColorArray = src.c
	var I: PackedInt32Array = src.i
	var rot := Basis(Vector3.UP, deg_to_rad(float(opts.get("turn", 90.0))))
	if opts.has("up_fix"):
		rot = rot * Basis.from_euler(ModelLib.v3(opts.up_fix) * (PI / 180.0))
	for k in V.size():
		V[k] = rot * V[k]
		Nn[k] = rot * Nn[k]
	# вывернутая сетка (объём отрицательный) — меняем обход треугольников
	var vol := 0.0
	for t in range(0, I.size(), 3):
		vol += V[I[t]].dot(V[I[t + 1]].cross(V[I[t + 2]]))
	if vol < 0.0:
		I = I.duplicate()
		for t in range(0, I.size(), 3):
			var x := I[t + 1]
			I[t + 1] = I[t + 2]
			I[t + 2] = x
	var bb := AABB(V[0], Vector3.ZERO)
	for v in V:
		bb = bb.expand(v)
	var sc := 1.0
	match kind:
		"hero":
			sc = float(opts.get("height", 2.0)) / maxf(0.001, bb.size.y)
		"building":
			var fp := float(opts.get("footprint", 2)) * C_CELL * 0.94
			sc = fp / maxf(0.001, maxf(bb.size.x, bb.size.z))
		_:
			sc = float(opts.get("height", 1.6)) / maxf(0.001, bb.size.y)
	var c := bb.get_center()
	for k in V.size():
		V[k] = Vector3((V[k].x - c.x) * sc, (V[k].y - bb.position.y) * sc, (V[k].z - c.z) * sc)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = V
	arr[Mesh.ARRAY_NORMAL] = Nn
	arr[Mesh.ARRAY_COLOR] = Cc
	arr[Mesh.ARRAY_INDEX] = I
	var budget := int(opts.get("tris", 9000))
	if I.size() / 3 > budget * 1.3:
		arr = SdfMesh.simplify(arr, budget)
	arr = _compact(arr)
	V = arr[Mesh.ARRAY_VERTEX]
	I = arr[Mesh.ARRAY_INDEX]
	# сварка: вершины в одной точке (швы развёртки) считаем одной — для поиска связных кусков
	var weld := PackedInt32Array()
	weld.resize(V.size())
	var hm := {}
	var eps := 0.0005
	for k in V.size():
		var key := Vector3i(roundi(V[k].x / eps), roundi(V[k].y / eps), roundi(V[k].z / eps))
		if hm.has(key):
			weld[k] = hm[key]
		else:
			hm[key] = k
			weld[k] = k
	var bb2 := AABB(V[0], Vector3.ZERO)
	for v in V:
		bb2 = bb2.expand(v)
	return {"arr": arr, "v": V, "i": I, "weld": weld, "bb": bb2}


## Убрать неиспользуемые вершины (после упрощения их много).
static func _compact(arr: Array) -> Array:
	var I: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var V: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var remap := PackedInt32Array()
	remap.resize(V.size())
	remap.fill(-1)
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	var NV := PackedVector3Array()
	var NN := PackedVector3Array()
	var NC := PackedColorArray()
	var NI := PackedInt32Array()
	var Nsrc: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var Csrc: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	NI.resize(I.size())
	for k in I.size():
		var o := I[k]
		if remap[o] < 0:
			remap[o] = NV.size()
			NV.append(V[o])
			NN.append(Nsrc[o])
			NC.append(Csrc[o])
		NI[k] = remap[o]
	out[Mesh.ARRAY_VERTEX] = NV
	out[Mesh.ARRAY_NORMAL] = NN
	out[Mesh.ARRAY_COLOR] = NC
	out[Mesh.ARRAY_INDEX] = NI
	return out


## Связные куски сетки среди вершин, где mask[v] = true. Возвращает метку куска для каждой вершины (-1 — не в маске).
static func _components(m: Dictionary, mask: PackedByteArray) -> PackedInt32Array:
	var weld: PackedInt32Array = m.weld
	var I: PackedInt32Array = m.i
	var n := weld.size()
	var par := PackedInt32Array()
	par.resize(n)
	for k in n:
		par[k] = k
	for t in range(0, I.size(), 3):
		var a := weld[I[t]]
		var b := weld[I[t + 1]]
		var c := weld[I[t + 2]]
		if mask[a] and mask[b]:
			_union(par, a, b)
		if mask[b] and mask[c]:
			_union(par, b, c)
		if mask[a] and mask[c]:
			_union(par, a, c)
	var lab := PackedInt32Array()
	lab.resize(n)
	for k in n:
		var w := weld[k]
		lab[k] = _find(par, w) if mask[w] else -1
	return lab


static func _find(par: PackedInt32Array, a: int) -> int:
	var r := a
	while par[r] != r:
		r = par[r]
	while par[a] != r:
		var nx := par[a]
		par[a] = r
		a = nx
	return r


static func _union(par: PackedInt32Array, a: int, b: int) -> void:
	var ra := _find(par, a)
	var rb := _find(par, b)
	if ra != rb:
		par[ra] = rb


## Куски ниже высоты y, которые касаются земли: [{verts: PackedInt32Array, minp, maxp, sum}].
static func _ground_pieces(m: Dictionary, y: float, min_share := 0.004) -> Array:
	var V: PackedVector3Array = m.v
	var bb: AABB = m.bb
	var mask := PackedByteArray()
	mask.resize(V.size())
	for k in V.size():
		mask[k] = 1 if V[k].y < y else 0
	var lab := _components(m, mask)
	var groups := {}
	for k in V.size():
		var l := lab[k]
		if l < 0:
			continue
		if not groups.has(l):
			groups[l] = {"verts": [], "lo": INF, "sum": Vector3.ZERO}
		var g: Dictionary = groups[l]
		(g.verts as Array).append(k)
		g.lo = minf(g.lo, V[k].y)
		g.sum += V[k]
	var out := []
	var ground := bb.position.y + bb.size.y * 0.06
	for l in groups:
		var g: Dictionary = groups[l]
		if g.lo <= ground and (g.verts as Array).size() >= maxi(8, int(V.size() * min_share)):
			g["c"] = g.sum / float((g.verts as Array).size())
			g["verts"] = PackedInt32Array(g.verts)
			out.append(g)
	return out


## Средняя точка вершин куска в слое высот [y0, y1] (точка сустава).
static func _joint(m: Dictionary, verts: PackedInt32Array, y0: float, y1: float) -> Vector3:
	var V: PackedVector3Array = m.v
	var s := Vector3.ZERO
	var n := 0
	for k in verts:
		if V[k].y >= y0 and V[k].y <= y1:
			s += V[k]
			n += 1
	if n == 0:
		for k in verts:
			s += V[k]
		n = maxi(1, verts.size())
	return s / float(n)


# ================================================================ монстр

static func _seg_monster(m: Dictionary) -> Dictionary:
	var V: PackedVector3Array = m.v
	var bb: AABB = m.bb
	var H := bb.size.y
	var L := bb.size.x
	var labels := PackedInt32Array()
	labels.resize(V.size())
	labels.fill(0)
	var names := ["body"]
	var roles := {"body": "b:body"}
	var bones := []
	var legs_rig := []
	# высота бёдер: самая высокая, на которой ноги ещё раздельны
	var best_y := -1.0
	var best: Array = []
	var top_n := 0
	var y := 0.12
	while y <= 0.72:
		var pcs := _ground_pieces(m, bb.position.y + H * y)
		if pcs.size() >= 2 and pcs.size() <= 10 and pcs.size() >= top_n:
			top_n = pcs.size()
			best_y = bb.position.y + H * y
			best = pcs
		elif top_n >= 2 and pcs.size() < top_n:
			break
		y += 0.03
	var body_c := Vector3.ZERO
	var nb := 0
	for v in V:
		if v.y > (best_y if best_y > 0.0 else H * 0.3):
			body_c += v
			nb += 1
	body_c = body_c / float(maxi(1, nb)) if nb > 0 else bb.get_center()
	bones.append({"name": "b:body", "parent": "", "pivot": _a(body_c)})
	var note := ""
	if best.size() >= 2:
		# ноги: бедро — верх куска, колено — середина, снизу голень
		var order := best.duplicate()
		order.sort_custom(func(a, b): return a.c.x > b.c.x)
		var li := 0
		for g in order:
			var verts: PackedInt32Array = g.verts
			var lo: float = g.lo
			var hip := _joint(m, verts, best_y - H * 0.06, best_y)
			var kneey := lo + (best_y - lo) * 0.5
			var knee := _joint(m, verts, kneey - H * 0.04, kneey + H * 0.04)
			var foot := _joint(m, verts, lo, lo + H * 0.05)
			var hn := "b:hip%d" % li
			var kn := "b:knee%d" % li
			bones.append({"name": hn, "parent": "b:body", "pivot": _a(hip)})
			bones.append({"name": kn, "parent": hn, "pivot": _a(knee)})
			names.append("leg%d" % li)
			roles["leg%d" % li] = hn
			names.append("shin%d" % li)
			roles["shin%d" % li] = kn
			var a_up := names.size() - 2
			for k in verts:
				labels[k] = a_up if V[k].y > kneey else a_up + 1
			var side := 1.0 if hip.z >= 0.0 else -1.0
			var out_v := Vector2(foot.x - hip.x, foot.z - hip.z)
			# лапы в стороны (паук, краб) машут вбок-вперёд, прямые — вперёд-назад
			var style := "y" if absf(out_v.y) > absf(out_v.x) * 1.2 and absf(out_v.y) > H * 0.15 else "z"
			legs_rig.append({"hip": hn, "knee": kn, "side": side, "style": style, "x": hip.x})
			li += 1
		# фазы: по диагонали, как у животных и насекомых
		var lefts := legs_rig.filter(func(l): return l.side > 0.0)
		var rights := legs_rig.filter(func(l): return l.side <= 0.0)
		for arr in [lefts, rights]:
			arr.sort_custom(func(a, b): return a.x > b.x)
			for i in arr.size():
				var base := 0.0 if arr == lefts else 0.5
				arr[i]["phase"] = fposmod(base + i * 0.5, 1.0)
		for l in legs_rig:
			l.erase("x")
		note = "ноги: %d" % legs_rig.size()
	else:
		note = "ног не найдено — двигается всем телом"
	# голова: передняя часть впереди передних ног и выше бёдер
	var front := bb.position.x + L * 0.72
	var hip_top := bb.position.y + H * 0.2
	for b in bones:
		if str(b.name).begins_with("b:hip"):
			front = maxf(front, float(b.pivot[0]) + L * 0.06)
			hip_top = maxf(hip_top, float(b.pivot[1]) - H * 0.05)
	var head_n := 0
	var hs := Vector3.ZERO
	for k in V.size():
		if labels[k] == 0 and V[k].x > front and V[k].y > hip_top:
			head_n += 1
			hs += V[k]
	var rig := {"bones": bones, "legs": legs_rig, "arms": [], "jaws": [], "chains": [], "breath": ["b:body"], "head": "", "body": "b:body",
		"gait": {"stride": clampf(H * 0.9, 0.4, 3.0), "swing": 24.0, "lift": 22.0, "knee": 32.0, "bob": H * 0.03, "lean": 5.0}}
	if head_n > V.size() * 0.03:
		var hc := hs / float(head_n)
		var hp := Vector3(front, hc.y, hc.z)
		bones.append({"name": "b:head", "parent": "b:body", "pivot": _a(hp)})
		names.append("head")
		roles["head"] = "b:head"
		var hi := names.size() - 1
		for k in V.size():
			if labels[k] == 0 and V[k].x > front and V[k].y > hip_top:
				labels[k] = hi
		rig.head = "b:head"
	# хвост: задняя часть, если она заметно тоньше корпуса
	var back := bb.position.x + L * 0.2
	var tail_n := 0
	var tz := Vector2(INF, -INF)
	var tc := Vector3.ZERO
	for k in V.size():
		if labels[k] == 0 and V[k].x < back:
			tail_n += 1
			tz = Vector2(minf(tz.x, V[k].y), maxf(tz.y, V[k].y))
			tc += V[k]
	if tail_n > V.size() * 0.02 and tail_n < V.size() * 0.2 and (tz.y - tz.x) < H * 0.35:
		var tp := tc / float(tail_n)
		bones.append({"name": "b:tail", "parent": "b:body", "pivot": _a(Vector3(back, tp.y, tp.z))})
		names.append("tail")
		roles["tail"] = "b:tail"
		var ti := names.size() - 1
		for k in V.size():
			if labels[k] == 0 and V[k].x < back:
				labels[k] = ti
		rig.chains.append({"bones": ["b:tail"], "axis": "y", "amp": 14.0, "speed": 2.4, "follow": true})
		note += ", хвост"
	if legs_rig.is_empty():
		# без ног — ползёт: корпус волной, парит над землёй, если низ узкий
		rig["hover"] = {"amp": H * 0.03, "speed": 2.0}
	return {"labels": labels, "names": names, "roles": roles, "rig": rig, "legs": legs_rig.size(), "note": note}


# ================================================================ герой

static func _seg_hero(m: Dictionary) -> Dictionary:
	var V: PackedVector3Array = m.v
	var bb: AABB = m.bb
	var H := bb.size.y
	var labels := PackedInt32Array()
	labels.resize(V.size())
	labels.fill(-1)
	# промежность: самая высокая высота, где ниже неё два отдельных куска (ноги)
	var crotch := H * 0.45
	var legs: Array = []
	var y := 0.2
	while y <= 0.62:
		var pcs := _ground_pieces(m, H * y, 0.01)
		if pcs.size() == 2:
			crotch = H * y
			legs = pcs
		elif not legs.is_empty():
			break
		y += 0.02
	var note := ""
	if legs.size() != 2:
		# ноги слиплись (юбка, плащ) — делим по боку
		legs = []
		note = "ноги не разделены — делю по боку"
	# руки: куски выше промежности, которые не касаются земли (висят отдельно от тела)
	var arms := {}
	var armpit := H * 0.7
	var y2 := crotch / H + 0.05
	while y2 <= 0.86:
		var mask := PackedByteArray()
		mask.resize(V.size())
		for k in V.size():
			mask[k] = 1 if V[k].y < H * y2 else 0
		var lab := _components(m, mask)
		var cnt := {}
		for k in V.size():
			if lab[k] >= 0:
				cnt[lab[k]] = cnt.get(lab[k], 0) + 1
		var big := []
		for l in cnt:
			if cnt[l] > V.size() * 0.01:
				big.append(l)
		if big.size() == 3:
			armpit = H * y2
			arms = {"lab": lab, "big": big}
		elif not arms.is_empty():
			break
		y2 += 0.02
	var Lw := {}   # вершина -> "arm_l"/"arm_r"
	var torso_half := 0.0
	if not arms.is_empty():
		# торс — кусок с самой низкой точкой (через ноги стоит на земле)
		var lab2: PackedInt32Array = arms.lab
		var lo := {}
		var zs := {}
		for k in V.size():
			var l := lab2[k]
			if l in arms.big:
				lo[l] = minf(lo.get(l, INF), V[k].y)
				zs[l] = zs.get(l, 0.0) + V[k].z
		var torso_l: int = arms.big[0]
		for l in arms.big:
			if lo[l] < lo[torso_l]:
				torso_l = l
		for k in V.size():
			var l := lab2[k]
			if l in arms.big and l != torso_l:
				Lw[k] = "l" if zs[l] > 0.0 else "r"
	else:
		# руки прижаты или разведены в стороны (Т-поза): всё, что дальше плеч по боку
		var wmax := 0.0
		for k in V.size():
			if V[k].y > crotch and V[k].y < H * 0.5 + crotch * 0.5:
				wmax = maxf(wmax, absf(V[k].z))
		torso_half = maxf(H * 0.11, wmax * 0.62)
		for k in V.size():
			if V[k].y > crotch + H * 0.08 and V[k].y < H * 0.86 and absf(V[k].z) > torso_half:
				Lw[k] = "l" if V[k].z > 0.0 else "r"
		note += ("; " if note != "" else "") + "руки найдены по ширине плеч"
	# шея: самое узкое место между подмышками и макушкой (по тем вершинам, что не руки)
	var neck := H * 0.83
	var best_w := INF
	var yy := maxf(armpit / H, 0.7)
	while yy <= 0.92:
		var w := 0.0
		for k in V.size():
			if not Lw.has(k) and absf(V[k].y - H * yy) < H * 0.015:
				w = maxf(w, absf(V[k].z))
		if w > 0.0 and w < best_w:
			best_w = w
			neck = H * yy
		yy += 0.02
	# метки
	var names := ["hips", "torso", "head", "leg_l", "leg_r", "shin_l", "shin_r", "arm_l", "arm_r", "fore_l", "fore_r", "hand_r"]
	var NI := {}
	for i in names.size():
		NI[names[i]] = i
	var knee_y := crotch * 0.5
	# руки: плечо (верх), локоть (середина), кисть (низ правой)
	var arm_rng := {"l": Vector2(INF, -INF), "r": Vector2(INF, -INF)}
	for k in Lw:
		var s: String = Lw[k]
		arm_rng[s] = Vector2(minf(arm_rng[s].x, V[k].y), maxf(arm_rng[s].y, V[k].y))
	for k in V.size():
		var v := V[k]
		if Lw.has(k):
			var s: String = Lw[k]
			var r: Vector2 = arm_rng[s]
			var elbow := (r.x + r.y) * 0.5
			if v.y > elbow:
				labels[k] = NI["arm_" + s]
			elif s == "r" and v.y < r.x + (r.y - r.x) * 0.18:
				labels[k] = NI.hand_r
			else:
				labels[k] = NI["fore_" + s]
		elif v.y < crotch:
			var s2 := "l" if v.z > 0.0 else "r"
			labels[k] = NI[("leg_" if v.y > knee_y else "shin_") + s2]
		elif v.y > neck:
			labels[k] = NI.head
		elif v.y < crotch + (neck - crotch) * 0.18:
			labels[k] = NI.hips
		else:
			labels[k] = NI.torso
	# точки суставов (в координатах модели)
	var W := {}
	var hips_p := Vector3(0, crotch + (neck - crotch) * 0.1, 0)
	W["hips"] = hips_p
	W["torso"] = Vector3(0, crotch + (neck - crotch) * 0.18, 0)
	W["head"] = Vector3(0, neck, 0)
	for s in ["l", "r"]:
		var sg := 1.0 if s == "l" else -1.0
		var lv := PackedInt32Array()
		for k in V.size():
			if labels[k] == NI["leg_" + s] or labels[k] == NI["shin_" + s]:
				lv.append(k)
		var hip := _joint(m, lv, crotch - H * 0.05, crotch)
		hip.y = crotch
		W["leg_" + s] = hip if lv.size() > 0 else Vector3(0, crotch, sg * H * 0.09)
		var kn := _joint(m, lv, knee_y - H * 0.03, knee_y + H * 0.03)
		W["shin_" + s] = Vector3(kn.x, knee_y, kn.z) if lv.size() > 0 else Vector3(0, knee_y, sg * H * 0.09)
		var av := PackedInt32Array()
		for k in Lw:
			if Lw[k] == s:
				av.append(k)
		var r: Vector2 = arm_rng[s]
		if av.size() > 0:
			var sh := _joint(m, av, r.y - H * 0.06, r.y)
			W["arm_" + s] = sh
			var el := (r.x + r.y) * 0.5
			W["fore_" + s] = _joint(m, av, el - H * 0.03, el + H * 0.03)
			if s == "r":
				var wr := r.x + (r.y - r.x) * 0.18
				W["hand_r"] = _joint(m, av, wr - H * 0.03, wr + H * 0.03)
		else:
			W["arm_" + s] = Vector3(0, neck - H * 0.05, sg * H * 0.2)
			W["fore_" + s] = Vector3(0, neck - H * 0.25, sg * H * 0.22)
			if s == "r":
				W["hand_r"] = Vector3(0, neck - H * 0.45, sg * H * 0.22)
	W["gun"] = W.hand_r
	# кости героя — смещения от родителя
	var par := {"leg_l": "hips", "leg_r": "hips", "shin_l": "leg_l", "shin_r": "leg_r", "torso": "hips", "head": "torso",
		"arm_l": "torso", "arm_r": "torso", "fore_l": "arm_l", "fore_r": "arm_r", "hand_r": "fore_r", "gun": "hand_r"}
	var bones := {}
	for bn in ["hips", "leg_l", "leg_r", "shin_l", "shin_r", "torso", "head", "arm_l", "arm_r", "fore_l", "fore_r", "hand_r", "gun"]:
		var o: Vector3 = W[bn] - (W[par[bn]] if par.has(bn) else Vector3.ZERO)
		bones[bn] = _a(o)
	bones["muzzle"] = [snappedf(H * 0.28, 0.001), 0.0, 0.0]
	# части героя хранятся в координатах своей кости
	var shift := {}
	for bn in names:
		shift[bn] = -W[bn]
	var roles := {}
	for bn in names:
		roles[bn] = bn
	return {"labels": labels, "names": names, "roles": roles, "bones": bones, "shift": shift, "world": W, "legs": 2, "note": note}


# ================================================================ здание

static func _seg_building(m: Dictionary) -> Dictionary:
	var arr: Array = m.arr
	var Cc: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	var labels := PackedInt32Array()
	labels.resize(Cc.size())
	var ng := 0
	for k in Cc.size():
		var c := Cc[k]
		# огоньки: светящийся материал или очень яркий насыщенный цвет (окна печи, лампы, экраны)
		var g := c.a < 0.95 or (c.v > 0.92 and c.s > 0.55)
		labels[k] = 1 if g else 0
		ng += 1 if g else 0
	var names := ["body"]
	var note := ""
	if ng > 12 and ng < Cc.size() * 0.25:
		names.append("glow")
		note = "огоньки: мигают в работе"
	else:
		labels.fill(0)
	return {"labels": labels, "names": names, "roles": {}, "note": note}


# ================================================================ сборка частей

## Меш одной части: треугольники, у которых хотя бы одна вершина этой части (на стыках части чуть заходят
## друг в друга — при движении нет щелей).
static func _part_mesh(m: Dictionary, labels: PackedInt32Array, li: int, shift: Vector3, rings := 0) -> ArrayMesh:
	var arr: Array = m.arr
	var I: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var NI := PackedInt32Array()
	# дочерняя часть (лапа, рука, голова) чуть заходит внутрь родителя: при повороте край уходит в тело, а не открывает щель
	var W: PackedInt32Array = m.weld
	var grow := PackedByteArray()
	grow.resize(labels.size())
	for k in labels.size():
		if labels[k] == li:
			grow[W[k]] = 1
	if li > 0:
		for ring in rings:
			var add := PackedInt32Array()
			for t in range(0, I.size(), 3):
				var g := grow[W[I[t]]] + grow[W[I[t + 1]]] + grow[W[I[t + 2]]]
				if g > 0 and g < 3:
					add.append(W[I[t]]); add.append(W[I[t + 1]]); add.append(W[I[t + 2]])
			for k in add:
				grow[k] = 1
	for t in range(0, I.size(), 3):
		var a := labels[I[t]]
		var b := labels[I[t + 1]]
		var c := labels[I[t + 2]]
		var mine := int(a == li) + int(b == li) + int(c == li)
		if mine >= 2 or (mine == 1 and a != b and b != c and a != c) or (mine == 1 and li <= _owner(a, b, c)) \
				or (rings > 0 and grow[W[I[t]]] + grow[W[I[t + 1]]] + grow[W[I[t + 2]]] == 3):
			NI.append(I[t]); NI.append(I[t + 1]); NI.append(I[t + 2])
	if NI.size() < 3:
		return null
	var sub := arr.duplicate()
	sub[Mesh.ARRAY_INDEX] = NI
	sub = _compact(sub)
	var V: PackedVector3Array = sub[Mesh.ARRAY_VERTEX]
	var Cc: PackedColorArray = sub[Mesh.ARRAY_COLOR]
	for k in V.size():
		V[k] += shift
		Cc[k].a = 1.0
	sub[Mesh.ARRAY_VERTEX] = V
	sub[Mesh.ARRAY_COLOR] = Cc
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, sub)
	return am


## Треугольник на стыке двух частей достаётся обеим (меньший номер — «владелец», второй тоже берёт).
static func _owner(a: int, b: int, c: int) -> int:
	return maxi(a, maxi(b, c))


## Гладкая сетка на костях: у каждой вершины до 4 костей с весами; у суставов вес плавно переходит
## от родителя к ребёнку (на расстоянии r вокруг точки сустава).
static func _skin_mesh(m: Dictionary, labels: PackedInt32Array, names: Array, roles: Dictionary, rig_d: Dictionary) -> ArrayMesh:
	var arr: Array = (m.arr as Array).duplicate()
	var V: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var bb: AABB = m.bb
	var bl: Array = rig_d.get("bones", [])
	if bl.is_empty():
		return null
	var bi := {}
	var piv := []
	var par := PackedInt32Array()
	for i in bl.size():
		bi[bl[i].name] = i
	for i in bl.size():
		piv.append(ModelLib.v3(bl[i].pivot))
		par.append(int(bi.get(str(bl[i].get("parent", "")), -1)))
	var kids := []
	for i in bl.size():
		kids.append([])
	for i in bl.size():
		if par[i] >= 0:
			kids[par[i]].append(i)
	var part_bone := PackedInt32Array()
	for li in names.size():
		part_bone.append(int(bi.get(str(roles.get(names[li], "")), 0)))
	var r := maxf(0.02, bb.size.y * 0.09)
	var B := PackedInt32Array()
	var Wt := PackedFloat32Array()
	B.resize(V.size() * 4)
	Wt.resize(V.size() * 4)
	for k in V.size():
		var b := part_bone[labels[k]] if labels[k] >= 0 and labels[k] < part_bone.size() else 0
		var inf := {b: 1.0}
		if par[b] >= 0:
			# у своего сустава: половина веса у родителя, дальше — вся своя
			var t := smoothstep(0.0, r, V[k].distance_to(piv[b]))
			inf[b] = 0.5 + 0.5 * t
			inf[par[b]] = 0.5 - 0.5 * t
		for c in kids[b]:
			var d: float = V[k].distance_to(piv[c])
			if d < r:
				inf[c] = maxf(inf.get(c, 0.0), 0.5 * (1.0 - smoothstep(0.0, r, d)))
		var ks := inf.keys()
		ks.sort_custom(func(x, y): return inf[x] > inf[y])
		var tot := 0.0
		for j in mini(4, ks.size()):
			tot += inf[ks[j]]
		for j in 4:
			if j < ks.size():
				B[k * 4 + j] = ks[j]
				Wt[k * 4 + j] = inf[ks[j]] / tot
			else:
				B[k * 4 + j] = 0
				Wt[k * 4 + j] = 0.0
	var Cc: PackedColorArray = (arr[Mesh.ARRAY_COLOR] as PackedColorArray).duplicate()
	for k in Cc.size():
		Cc[k].a = 1.0
	arr[Mesh.ARRAY_COLOR] = Cc
	arr[Mesh.ARRAY_BONES] = B
	arr[Mesh.ARRAY_WEIGHTS] = Wt
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return am


static func _a(v: Vector3) -> Array:
	return [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]
