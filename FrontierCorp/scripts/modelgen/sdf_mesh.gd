class_name SdfMesh
extends RefCounted
## 15.7: «лепка» модели из гладких форм. Фигуры (шар, эллипсоид, скруглённый ящик, капсула-конус, цилиндр, тор)
## сливаются плавно (как глина), вычитаются (пазы, вырезы, отверстия) и пересекаются. Из поля расстояний
## строится гладкая сетка (surface nets), в цвета вершин запекаются затенение в складках (AO), потёртости на
## рёбрах и пятна. Потом сетка упрощается до нужного числа треугольников.
## Работает и в редакторе, и в игре; на 8 ядрах модель из 15 частей — несколько секунд.

const T_SPHERE := 0
const T_ELLIPSOID := 1
const T_BOX := 2          # скруглённый ящик: a = половины сторон, b.x = скругление
const T_CAPSULE := 3      # конус-капсула от p до a, радиусы b.x → b.y
const T_CYLINDER := 4     # ось Y, a.x = радиус, a.y = половина высоты, b.x = скругление
const T_TORUS := 5        # a.x = большой радиус, a.y = толщина
const T_HEX := 6          # шестигранник: a.x = радиус, a.y = половина высоты

const OP_ADD := 0
const OP_SUB := 1
const OP_INTER := 2

var types := PackedInt32Array()
var ops := PackedInt32Array()
var pos := PackedVector3Array()
var pa := PackedVector3Array()
var pb := PackedVector3Array()
var inv: Array[Basis] = []
var blend := PackedFloat32Array()
var cols := PackedColorArray()
var rough := PackedFloat32Array()      # неровность поверхности (камень, кожа), метры
var noise: FastNoiseLite
var wear := 0.35                        # светлые потёртости на выступающих рёбрах
var dirt := 0.25                        # тёмная грязь в складках
var ao_k := 0.85


func _init() -> void:
	noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 3.0
	noise.fractal_octaves = 3


func _add(t: int, p: Vector3, a: Vector3, b: Vector3, rot: Vector3, col: Color, k: float, op: int, rg: float) -> int:
	types.append(t)
	ops.append(op)
	pos.append(p)
	pa.append(a)
	pb.append(b)
	inv.append(Basis.from_euler(rot * (PI / 180.0)).inverse())
	blend.append(maxf(0.0, k))
	cols.append(col)
	rough.append(rg)
	return types.size() - 1


func sphere(p: Vector3, r: float, col: Color, k := 0.05, op := OP_ADD, rg := 0.0) -> int:
	return _add(T_SPHERE, p, Vector3(r, r, r), Vector3.ZERO, Vector3.ZERO, col, k, op, rg)


func ellipsoid(p: Vector3, r: Vector3, col: Color, rot := Vector3.ZERO, k := 0.05, op := OP_ADD, rg := 0.0) -> int:
	return _add(T_ELLIPSOID, p, r, Vector3.ZERO, rot, col, k, op, rg)


func box(p: Vector3, half: Vector3, round_r: float, col: Color, rot := Vector3.ZERO, k := 0.03, op := OP_ADD, rg := 0.0) -> int:
	return _add(T_BOX, p, half, Vector3(round_r, 0, 0), rot, col, k, op, rg)


## Конус-капсула между точками a и b с радиусами ra и rb (ноги, руки, хвосты, рога, трубы).
func capsule(a: Vector3, b: Vector3, ra: float, rb: float, col: Color, k := 0.04, op := OP_ADD, rg := 0.0) -> int:
	return _add(T_CAPSULE, a, b, Vector3(ra, rb, 0), Vector3.ZERO, col, k, op, rg)


func cylinder(p: Vector3, r: float, half_h: float, round_r: float, col: Color, rot := Vector3.ZERO, k := 0.03, op := OP_ADD) -> int:
	return _add(T_CYLINDER, p, Vector3(r, half_h, 0), Vector3(round_r, 0, 0), rot, col, k, op, 0.0)


func torus(p: Vector3, big: float, small: float, col: Color, rot := Vector3.ZERO, k := 0.02, op := OP_ADD) -> int:
	return _add(T_TORUS, p, Vector3(big, small, 0), Vector3.ZERO, rot, col, k, op, 0.0)


func hexprism(p: Vector3, r: float, half_h: float, col: Color, rot := Vector3.ZERO, k := 0.02, op := OP_ADD) -> int:
	return _add(T_HEX, p, Vector3(r, half_h, 0), Vector3.ZERO, rot, col, k, op, 0.0)


func count() -> int:
	return types.size()


# ---------------------------------------------------------------- поле расстояний

static func _len2(x: float, y: float) -> float:
	return sqrt(x * x + y * y)


func _prim(i: int, p: Vector3) -> float:
	var t := types[i]
	if t == T_CAPSULE:
		# конус со скруглёнными концами (формула Иниго Килеса)
		var a := pos[i]
		var b := pa[i]
		var r1 := pb[i].x
		var r2 := pb[i].y
		var ba := b - a
		var l2 := ba.dot(ba)
		if l2 < 1e-8:
			return (p - a).length() - r1
		var rr := r1 - r2
		var a2 := l2 - rr * rr
		var il2 := 1.0 / l2
		var pa2 := p - a
		var y := pa2.dot(ba)
		var z := y - l2
		var xv := pa2 * l2 - ba * y
		var x2 := xv.dot(xv)
		var y2 := y * y * l2
		var z2 := z * z * l2
		var kk := signf(rr) * rr * rr * x2
		if signf(z) * a2 * z2 > kk:
			return sqrt(x2 + z2) * il2 - r2
		if signf(y) * a2 * y2 < kk:
			return sqrt(x2 + y2) * il2 - r1
		return (sqrt(x2 * a2 * il2) + y * rr) * il2 - r1
	var q := inv[i] * (p - pos[i])
	match t:
		T_SPHERE:
			return q.length() - pa[i].x
		T_ELLIPSOID:
			var r := pa[i]
			var k0 := Vector3(q.x / r.x, q.y / r.y, q.z / r.z).length()
			var k1 := Vector3(q.x / (r.x * r.x), q.y / (r.y * r.y), q.z / (r.z * r.z)).length()
			return k0 * (k0 - 1.0) / maxf(k1, 1e-6)
		T_BOX:
			var rb := pb[i].x
			var d := Vector3(absf(q.x), absf(q.y), absf(q.z)) - pa[i] + Vector3(rb, rb, rb)
			return Vector3(maxf(d.x, 0.0), maxf(d.y, 0.0), maxf(d.z, 0.0)).length() + minf(maxf(d.x, maxf(d.y, d.z)), 0.0) - rb
		T_CYLINDER:
			var rc := pb[i].x
			var dx := _len2(q.x, q.z) - pa[i].x + rc
			var dy := absf(q.y) - pa[i].y + rc
			return minf(maxf(dx, dy), 0.0) + _len2(maxf(dx, 0.0), maxf(dy, 0.0)) - rc
		T_TORUS:
			return _len2(_len2(q.x, q.z) - pa[i].x, q.y) - pa[i].y
		T_HEX:
			var kx := -0.8660254
			var ky := 0.5
			var kz := 0.57735
			var px := absf(q.x)
			var pz := absf(q.z)
			var dd := minf(kx * px + ky * pz, 0.0)
			px -= 2.0 * dd * kx
			pz -= 2.0 * dd * ky
			var cx := clampf(px, -kz * pa[i].x, kz * pa[i].x)
			var d1 := _len2(px - cx, pz - pa[i].x) * signf(pz - pa[i].x)
			var d2 := absf(q.y) - pa[i].y
			return minf(maxf(d1, d2), 0.0) + _len2(maxf(d1, 0.0), maxf(d2, 0.0))
	return 1e9


## Расстояние до поверхности в точке p (отрицательное — внутри).
func dist(p: Vector3) -> float:
	var d := 1e9
	var n := types.size()
	for i in n:
		var di := _prim(i, p)
		if rough[i] > 0.0 and di < rough[i] * 4.0:
			di += noise.get_noise_3dv(p) * rough[i]
		var k := blend[i]
		match ops[i]:
			OP_ADD:
				if k > 0.0:
					var h := clampf(0.5 + 0.5 * (d - di) / k, 0.0, 1.0)
					d = lerpf(d, di, h) - k * h * (1.0 - h)
				else:
					d = minf(d, di)
			OP_SUB:
				if k > 0.0:
					var h2 := clampf(0.5 - 0.5 * (d + di) / k, 0.0, 1.0)
					d = lerpf(d, -di, h2) + k * h2 * (1.0 - h2)
				else:
					d = maxf(d, -di)
			OP_INTER:
				d = maxf(d, di)
	return d


## Цвет в точке поверхности: смесь цветов ближайших фигур (плавно на стыках).
func color_at(p: Vector3) -> Color:
	var best := 1e9
	var c := Color(0.6, 0.6, 0.6)
	var wsum := 0.0
	var acc := Color(0, 0, 0, 0)
	for i in types.size():
		if ops[i] == OP_INTER:
			continue
		var di := _prim(i, p)
		if ops[i] == OP_SUB:
			di = -di
			if absf(di) > 0.02:
				continue
		var k := maxf(blend[i], 0.008)
		var w := exp(-maxf(di, 0.0) / k * 2.5) if di > -0.5 else 0.0
		if ops[i] == OP_ADD and di < best:
			best = di
			c = cols[i]
		if w > 0.0001:
			acc += cols[i] * w
			wsum += w
	if wsum > 0.0:
		return (acc / wsum).lerp(c, 0.35)
	return c


func normal_at(p: Vector3, e: float) -> Vector3:
	var n := Vector3(
		dist(p + Vector3(e, 0, 0)) - dist(p - Vector3(e, 0, 0)),
		dist(p + Vector3(0, e, 0)) - dist(p - Vector3(0, e, 0)),
		dist(p + Vector3(0, 0, e)) - dist(p - Vector3(0, 0, e)))
	return n.normalized() if n.length_squared() > 1e-12 else Vector3.UP


## Рамка, в которой лежат все добавляемые фигуры.
func bounds(margin: float) -> AABB:
	var box_ := AABB()
	var first := true
	for i in types.size():
		if ops[i] != OP_ADD:
			continue
		var ext := pa[i] if types[i] != T_CAPSULE else Vector3.ZERO
		var c := pos[i]
		var r := 0.0
		match types[i]:
			T_CAPSULE:
				r = maxf(pb[i].x, pb[i].y)
				var bb := AABB(pos[i], Vector3.ZERO).expand(pa[i]).grow(r)
				box_ = bb if first else box_.merge(bb)
				first = false
				continue
			T_TORUS:
				r = pa[i].x + pa[i].y
			T_CYLINDER:
				r = maxf(pa[i].x, pa[i].y)
			_:
				r = ext.length()
		var bb2 := AABB(c - Vector3(r, r, r), Vector3(r, r, r) * 2.0)
		box_ = bb2 if first else box_.merge(bb2)
		first = false
	return box_.grow(margin + rough_max() * 2.0)


func rough_max() -> float:
	var m := 0.0
	for r in rough:
		m = maxf(m, r)
	return m


# ---------------------------------------------------------------- сетка (surface nets)

## Построить сетку. res — клеток по самой длинной стороне (40 — быстро, 64 — хорошо, 96 — очень подробно).
## tris — до скольких треугольников упростить (0 — не упрощать).
func build(res := 64, tris := 0) -> ArrayMesh:
	if types.is_empty():
		return null
	var bb := bounds(0.02)
	var longest := maxf(bb.size.x, maxf(bb.size.y, bb.size.z))
	var h := longest / float(maxi(8, res))
	var nx := int(ceil(bb.size.x / h)) + 2
	var ny := int(ceil(bb.size.y / h)) + 2
	var nz := int(ceil(bb.size.z / h)) + 2
	var o := bb.position - Vector3(h, h, h) * 0.5
	var vals := PackedFloat32Array()
	vals.resize(nx * ny * nz)
	# грубый проход: блоки 4×4×4 далеко от поверхности не считаем по точкам
	var B := 4
	for bz in range(0, nz, B):
		for by in range(0, ny, B):
			for bx in range(0, nx, B):
				var cx := o + Vector3(bx + B * 0.5, by + B * 0.5, bz + B * 0.5) * h
				var dc := dist(cx)
				var far := absf(dc) > h * B * 0.9 + rough_max() * 1.5
				for z in range(bz, mini(bz + B, nz)):
					for y in range(by, mini(by + B, ny)):
						for x in range(bx, mini(bx + B, nx)):
							var idx := x + nx * (y + ny * z)
							vals[idx] = dc if far else dist(o + Vector3(x, y, z) * h)
	# вершина в каждой клетке, через которую идёт поверхность
	var vid := PackedInt32Array()
	vid.resize(nx * ny * nz)
	vid.fill(-1)
	var verts := PackedVector3Array()
	var corners := [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(1, 1, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 1), Vector3i(0, 1, 1), Vector3i(1, 1, 1)]
	var edges := [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]
	for z in nz - 1:
		for y in ny - 1:
			for x in nx - 1:
				var cv := PackedFloat32Array()
				cv.resize(8)
				var inside := 0
				for ci in 8:
					var c: Vector3i = corners[ci]
					var v := vals[(x + c.x) + nx * ((y + c.y) + ny * (z + c.z))]
					cv[ci] = v
					if v < 0.0:
						inside += 1
				if inside == 0 or inside == 8:
					continue
				var acc := Vector3.ZERO
				var cnt := 0
				for e in edges:
					var a: float = cv[e[0]]
					var b: float = cv[e[1]]
					if (a < 0.0) != (b < 0.0):
						var tt := a / (a - b)
						var ca: Vector3i = corners[e[0]]
						var cb: Vector3i = corners[e[1]]
						acc += Vector3(ca).lerp(Vector3(cb), tt)
						cnt += 1
				var pp := o + (Vector3(x, y, z) + acc / float(cnt)) * h
				vid[x + nx * (y + ny * z)] = verts.size()
				verts.append(pp)
	# квадраты на рёбрах решётки, которые пересекает поверхность
	var idxs := PackedInt32Array()
	for z in range(1, nz - 1):
		for y in range(1, ny - 1):
			for x in range(1, nx - 1):
				var v0 := vals[x + nx * (y + ny * z)]
				var in0 := v0 < 0.0
				# ребро по X: клетки (x, y-1..y, z-1..z)
				if x < nx - 1:
					var v1 := vals[(x + 1) + nx * (y + ny * z)]
					if in0 != (v1 < 0.0):
						_quad(idxs, vid, nx, ny, Vector3i(x, y - 1, z - 1), Vector3i(x, y, z - 1), Vector3i(x, y, z), Vector3i(x, y - 1, z), in0)
				if y < ny - 1:
					var v2 := vals[x + nx * ((y + 1) + ny * z)]
					if in0 != (v2 < 0.0):
						_quad(idxs, vid, nx, ny, Vector3i(x - 1, y, z - 1), Vector3i(x - 1, y, z), Vector3i(x, y, z), Vector3i(x, y, z - 1), in0)
				if z < nz - 1:
					var v3 := vals[x + nx * (y + ny * (z + 1))]
					if in0 != (v3 < 0.0):
						_quad(idxs, vid, nx, ny, Vector3i(x - 1, y - 1, z), Vector3i(x, y - 1, z), Vector3i(x, y, z), Vector3i(x - 1, y, z), in0)
	if idxs.is_empty():
		return null
	# нормали, цвет, затенение складок, потёртости рёбер
	var norms := PackedVector3Array()
	var colors := PackedColorArray()
	norms.resize(verts.size())
	colors.resize(verts.size())
	var e := h * 0.5
	for i in verts.size():
		var p := verts[i]
		var n := normal_at(p, e)
		norms[i] = n
		var col := color_at(p)
		# AO: насколько тесно вокруг (пробы вдоль нормали)
		var occ := 0.0
		var w := 1.0
		for s in range(1, 5):
			var sd := h * 1.6 * s
			occ += w * maxf(0.0, sd - dist(p + n * sd)) / sd
			w *= 0.55
		var ao := clampf(1.0 - occ * ao_k, 0.25, 1.0)
		# кривизна: выпуклое ребро светлее (потёртость), впадина темнее (грязь)
		var cur := dist(p + n * h * 2.5) - h * 2.5
		var edge := clampf(cur / h * 0.9, -1.0, 1.0)
		var nn := noise.get_noise_3dv(p * 2.3) * 0.5 + 0.5
		col = col.lightened(maxf(0.0, edge) * wear * (0.6 + 0.6 * nn))
		col = col.darkened(maxf(0.0, -edge) * dirt + (1.0 - nn) * 0.06)
		colors[i] = Color(col.r * ao, col.g * ao, col.b * ao, col.a)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = colors
	arr[Mesh.ARRAY_INDEX] = idxs
	if tris > 0 and idxs.size() / 3 > tris:
		arr = simplify(arr, tris)
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


static func _quad(idxs: PackedInt32Array, vid: PackedInt32Array, nx: int, ny: int, a: Vector3i, b: Vector3i, c: Vector3i, d: Vector3i, flip: bool) -> void:
	var ia := vid[a.x + nx * (a.y + ny * a.z)]
	var ib := vid[b.x + nx * (b.y + ny * b.z)]
	var ic := vid[c.x + nx * (c.y + ny * c.z)]
	var id := vid[d.x + nx * (d.y + ny * d.z)]
	if ia < 0 or ib < 0 or ic < 0 or id < 0:
		return
	if flip:
		idxs.append_array([ia, ic, ib, ia, id, ic])
	else:
		idxs.append_array([ia, ib, ic, ia, ic, id])


## Упростить сетку до ~tris треугольников (встроенное в Godot упрощение с сохранением формы).
static func simplify(arr: Array, tris: int) -> Array:
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arr)
	im.generate_lods(25.0, 60.0, [])
	var best: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	for li in im.get_surface_lod_count(0):
		var ix: PackedInt32Array = im.get_surface_lod_indices(0, li)
		if ix.size() / 3 >= tris * 0.6:
			best = ix
		else:
			break
	var out := arr.duplicate()
	out[Mesh.ARRAY_INDEX] = best
	return out
