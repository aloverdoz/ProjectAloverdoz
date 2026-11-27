class_name ModelLib
extends RefCounted
## Строит 3D-модели из описаний в models.json.
## Модель = список деталей (фигура, размер, положение, поворот, цвет, материал, анимация, текстура)
## или готовый файл GLB/GLTF (поле "glb").

const PART_SHADER := preload("res://shaders/part.gdshader")
const BELT_SHADER := preload("res://shaders/belt.gdshader")
const ITEM_SHADER := preload("res://shaders/belt_item.gdshader")

const SHAPES := ["box", "cylinder", "cone", "sphere", "prism", "torus", "capsule", "wedge", "gear", "screw"]
const SHAPE_NAMES := ["Куб", "Цилиндр", "Конус", "Шар", "Призма (клин)", "Кольцо", "Капсула", "Скат (рампа)", "Шестерня", "Шнек (винт бура)"]
const OUTLINE_SHADER := preload("res://shaders/outline.gdshader")
const PART_TOON_SHADER := preload("res://shaders/part_toon.gdshader")
const PART_2S_SHADER := preload("res://shaders/part_2s.gdshader")   # двусторонние детали (листва из Blender)
const MATS := {
	"paint": {"metallic": 0.15, "roughness": 0.45, "surface": "paint"},
	"metal": {"metallic": 0.85, "roughness": 0.3, "surface": "metal"},
	"dark": {"metallic": 0.5, "roughness": 0.55, "surface": "metal"},
	"concrete": {"metallic": 0.0, "roughness": 0.9, "surface": "concrete"},
	"stone": {"metallic": 0.05, "roughness": 0.85, "surface": "stone"},
	"wood": {"metallic": 0.0, "roughness": 0.8, "surface": "wood"},
	"leaf": {"metallic": 0.0, "roughness": 0.75, "surface": "leaf"},
	"glass": {"metallic": 0.6, "roughness": 0.08},
	"glow": {"metallic": 0.0, "roughness": 0.4, "emission": 3.0},
	"flesh": {"metallic": 0.1, "roughness": 0.25},
	"leg": {"metallic": 0.1, "roughness": 0.4},
	"cloth": {"metallic": 0.0, "roughness": 0.9, "surface": "cloth"},
}
## Рисунок поверхности (без картинок). У каждого материала свой; деталь может выбрать другой.
const SURFACES := ["none", "wood", "stone", "metal", "concrete", "leaf", "paint", "cloth"]
const SURFACE_NAMES := ["гладкая", "дерево", "камень", "металл", "бетон", "листва", "краска", "ткань"]
const MERGE_ANIMS := ["none", "pulse", "flicker", "sway", "bob", "jitter"]
const ANIM_TYPES := ["none", "spin", "pulse", "flicker", "sway", "wave", "bob", "legs", "breathe", "swing", "jitter", "step", "knee"]
const ANIM_TYPE_NAMES := ["нет", "вращение", "пульсация свечения", "огонь", "ветер", "флаг", "покачивание", "ноги", "дыхание", "маятник", "тряска", "шаг (нога от бедра)", "колено (сгиб назад)"]

static var _meshes := {}
static var _mats := {}
static var _tex := {}
static var _glb := {}
static var _rev := -1
static var _merged := {}


static func _check_rev() -> void:
	if _rev != DB.revision:
		_mats.clear()
		_file_meshes.clear()
		_glb.clear()
		_glb_anim_names.clear()
		_glb_states.clear()
		_merged.clear()
		_rev = DB.revision


static func unit_mesh(shape: String, top := 1.0, seg := 0, bevel := 0.0) -> Mesh:
	var k := "%s_%s_%s_%s" % [shape, top, seg, bevel]
	if _meshes.has(k):
		return _meshes[k]
	var m: Mesh
	if shape == "box" and bevel > 0.001:
		m = bevel_box(clampf(bevel, 0.01, 0.3))
		_meshes[k] = m
		return m
	if shape == "gear":
		m = gear_mesh(seg if seg > 3 else 12, top if top < 0.99 else 0.78)
		_meshes[k] = m
		return m
	if shape == "screw":
		m = screw_mesh(float(seg) if seg > 0 else 3.0, top if top < 0.99 else 0.24)
		_meshes[k] = m
		return m
	match shape:
		"cylinder", "cone":
			var c := CylinderMesh.new()
			c.top_radius = 0.0 if shape == "cone" else 0.5 * top
			c.bottom_radius = 0.5
			c.height = 1.0
			c.radial_segments = seg if seg > 2 else 12
			c.rings = 1
			m = c
		"sphere":
			var s := SphereMesh.new()
			s.radius = 0.5
			s.height = 1.0
			s.radial_segments = seg if seg > 2 else 12
			s.rings = max(3, (seg if seg > 2 else 12) / 2)
			m = s
		"prism":
			var p := PrismMesh.new()
			p.size = Vector3.ONE
			m = p
		"wedge":
			# скат: низ — квадрат, верх поднимается к +x
			var w := PrismMesh.new()
			w.size = Vector3.ONE
			w.left_to_right = 1.0
			m = w
		"torus":
			var t := TorusMesh.new()
			t.inner_radius = 0.3
			t.outer_radius = 0.5
			t.rings = seg if seg > 2 else 16
			t.ring_segments = 8
			m = t
		"capsule":
			var cp := CapsuleMesh.new()
			cp.radius = 0.5
			cp.height = 1.0
			cp.radial_segments = seg if seg > 2 else 12
			cp.rings = 4
			m = cp
		_:
			var b := BoxMesh.new()
			b.size = Vector3.ONE
			m = b
	_meshes[k] = m
	return m


## Шестерня: зубцов teeth (поле «Сегменты»), впадины на доле inner от радиуса (поле «Верх»), ось — Y.
## Меш детали: обычная фигура или готовый меш из файла (shape «mesh», поле mesh — путь к .res/.obj).
## Готовые меши делают генератор моделей и нейросеть; цвет у них в вершинах.
static var _file_meshes := {}

static func part_mesh(p: Dictionary) -> Mesh:
	if str(p.get("shape", "box")) != "mesh":
		return unit_mesh(p.get("shape", "box"), float(p.get("top", 1.0)), int(p.get("seg", 0)), float(p.get("bevel", 0.0)))
	var path := str(p.get("mesh", ""))
	if _put_meshes.has(path):
		return _put_meshes[path]
	if _file_meshes.has(path):
		return _file_meshes[path]
	var full := resolve_path(path)
	var m: Mesh = null
	if full != "" and (ResourceLoader.exists(full) or FileAccess.file_exists(full)):
		m = ResourceLoader.load(full, "", ResourceLoader.CACHE_MODE_IGNORE) as Mesh
	if m == null:
		m = unit_mesh("box")
	_file_meshes[path] = m
	return m


## Положить готовый меш в кэш (окно генератора показывает модель до сохранения на диск).
static var _put_meshes := {}

static func put_mesh(path: String, m: Mesh) -> void:
	if m == null:
		_put_meshes.erase(path)
	else:
		_put_meshes[path] = m
	_merged.clear()


static func gear_mesh(teeth: int, inner: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array[Vector2] = []
	for i in teeth:
		var a0 := TAU * i / teeth
		var w := TAU / teeth
		# впадина, подъём, вершина зубца, спуск
		for f in [[0.0, inner], [0.22, inner], [0.34, 1.0], [0.66, 1.0], [0.78, inner]]:
			var a: float = a0 + w * float(f[0])
			pts.append(Vector2(cos(a), sin(a)) * 0.5 * float(f[1]))
	var hub := 0.5 * inner * 0.35
	var n := pts.size()
	for y in [0.5, -0.5]:
		var up: float = signf(y)
		for i in n:
			var p0: Vector2 = pts[i]
			var p1: Vector2 = pts[(i + 1) % n]
			var c := Vector3(0, y, 0)
			var v0 := Vector3(p0.x, y, p0.y)
			var v1 := Vector3(p1.x, y, p1.y)
			st.set_normal(Vector3(0, up, 0))
			if up > 0:
				st.add_vertex(c); st.add_vertex(v1); st.add_vertex(v0)
			else:
				st.add_vertex(c); st.add_vertex(v0); st.add_vertex(v1)
	for i in n:
		var p0: Vector2 = pts[i]
		var p1: Vector2 = pts[(i + 1) % n]
		var a := Vector3(p0.x, 0.5, p0.y)
		var b := Vector3(p1.x, 0.5, p1.y)
		var c2 := Vector3(p1.x, -0.5, p1.y)
		var d := Vector3(p0.x, -0.5, p0.y)
		var nrm := Vector3(p1.y - p0.y, 0, -(p1.x - p0.x)).normalized()
		if nrm.dot(Vector3(p0.x + p1.x, 0, p0.y + p1.y)) < 0:
			nrm = -nrm
		st.set_normal(nrm)
		for v in [a, c2, b, a, d, c2]:
			st.add_vertex(v)
	# ступица-втулка поверх
	var hs := 16
	for i in hs:
		var a0 := TAU * i / hs
		var a1 := TAU * (i + 1) / hs
		for y in [0.58, -0.58]:
			st.set_normal(Vector3(0, signf(y), 0))
			var c3 := Vector3(0, y, 0)
			var v0 := Vector3(cos(a0) * hub, y, sin(a0) * hub)
			var v1 := Vector3(cos(a1) * hub, y, sin(a1) * hub)
			if y > 0:
				st.add_vertex(c3); st.add_vertex(v1); st.add_vertex(v0)
			else:
				st.add_vertex(c3); st.add_vertex(v0); st.add_vertex(v1)
		var q0 := Vector3(cos(a0) * hub, 0, sin(a0) * hub)
		var q1 := Vector3(cos(a1) * hub, 0, sin(a1) * hub)
		st.set_normal(((q0 + q1) * 0.5).normalized())
		for v in [q0 + Vector3(0, 0.58, 0), q1 - Vector3(0, 0.58, 0), q1 + Vector3(0, 0.58, 0), q0 + Vector3(0, 0.58, 0), q0 - Vector3(0, 0.58, 0), q1 - Vector3(0, 0.58, 0)]:
			st.add_vertex(v)
	return st.commit()


## Шнек: вал и винтовая лопасть вокруг него. turns витков (поле «Сегменты»), толщина вала — поле «Верх».
static func screw_mesh(turns: float, shaft: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rs := 0.5 * clampf(shaft, 0.05, 0.9)
	var steps := int(turns * 28.0)
	var th := 0.035
	for i in steps:
		var t0 := float(i) / steps
		var t1 := float(i + 1) / steps
		var a0 := t0 * turns * TAU
		var a1 := t1 * turns * TAU
		var y0 := -0.5 + t0
		var y1 := -0.5 + t1
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		# лопасть: верх и низ ленты
		for side in [1.0, -1.0]:
			var o := Vector3(0, th * side, 0)
			var i0 := d0 * rs + Vector3(0, y0, 0) + o
			var e0 := d0 * 0.5 + Vector3(0, y0, 0) + o
			var i1 := d1 * rs + Vector3(0, y1, 0) + o
			var e1 := d1 * 0.5 + Vector3(0, y1, 0) + o
			var nrm: Vector3 = (e0 - i0).cross(i1 - i0).normalized() * (-side)
			if nrm.y * side < 0:
				nrm = -nrm
			st.set_normal(nrm)
			if side > 0:
				for v in [i0, e1, e0, i0, i1, e1]:
					st.add_vertex(v)
			else:
				for v in [i0, e0, e1, i0, e1, i1]:
					st.add_vertex(v)
		# кромка лопасти
		st.set_normal((d0 + d1).normalized())
		var ea := d0 * 0.5 + Vector3(0, y0 + th, 0)
		var eb := d1 * 0.5 + Vector3(0, y1 + th, 0)
		var ec := d1 * 0.5 + Vector3(0, y1 - th, 0)
		var ed := d0 * 0.5 + Vector3(0, y0 - th, 0)
		for v in [ea, ec, eb, ea, ed, ec]:
			st.add_vertex(v)
	# вал
	var seg := 14
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var q0 := Vector3(cos(a0), 0, sin(a0)) * rs
		var q1 := Vector3(cos(a1), 0, sin(a1)) * rs
		st.set_normal(((q0 + q1) * 0.5).normalized())
		for v in [q0 + Vector3(0, 0.5, 0), q1 - Vector3(0, 0.5, 0), q1 + Vector3(0, 0.5, 0), q0 + Vector3(0, 0.5, 0), q0 - Vector3(0, 0.5, 0), q1 - Vector3(0, 0.5, 0)]:
			st.add_vertex(v)
		st.set_normal(Vector3.UP)
		for v in [Vector3(0, 0.5, 0), q1 + Vector3(0, 0.5, 0), q0 + Vector3(0, 0.5, 0)]:
			st.add_vertex(v)
	return st.commit()


## Куб со скошенными рёбрами: выглядит аккуратнее и «дороже» простого куба.
static func bevel_box(c: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := 0.5
	var i := h - c
	var polys := []
	# грани
	for ax in 3:
		for sg in [-1.0, 1.0]:
			var pts := []
			for a in [-1.0, 1.0]:
				for b in [-1.0, 1.0]:
					var v := Vector3.ZERO
					v[ax] = sg * h
					v[(ax + 1) % 3] = a * i
					v[(ax + 2) % 3] = b * i
					pts.append(v)
			polys.append(pts)
	# скосы рёбер
	for ax in 3:
		var a1 := (ax + 1) % 3
		var a2 := (ax + 2) % 3
		for s1 in [-1.0, 1.0]:
			for s2 in [-1.0, 1.0]:
				var pts := []
				for e in [-1.0, 1.0]:
					var p1 := Vector3.ZERO
					p1[ax] = e * i
					p1[a1] = s1 * h
					p1[a2] = s2 * i
					var p2 := Vector3.ZERO
					p2[ax] = e * i
					p2[a1] = s1 * i
					p2[a2] = s2 * h
					pts.append(p1)
					pts.append(p2)
				polys.append([pts[0], pts[1], pts[3], pts[2]])
	# уголки
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				polys.append([Vector3(sx * h, sy * i, sz * i), Vector3(sx * i, sy * h, sz * i), Vector3(sx * i, sy * i, sz * h)])
	for pts in polys:
		_poly(st, pts)
	return st.commit()


## Выпуклый многоугольник: сортируем вершины по кругу и режем веером (передняя сторона — наружу).
static func _poly(st: SurfaceTool, pts: Array) -> void:
	var cen := Vector3.ZERO
	for p in pts:
		cen += p
	cen /= pts.size()
	var n := cen.normalized()
	var u: Vector3 = (pts[0] - cen).normalized()
	var w := n.cross(u)
	var sorted := pts.duplicate()
	sorted.sort_custom(func(a, b): return atan2((a - cen).dot(w), (a - cen).dot(u)) < atan2((b - cen).dot(w), (b - cen).dot(u)))
	var fn: Vector3 = (sorted[1] - sorted[0]).cross(sorted[2] - sorted[0]).normalized()
	if fn.dot(n) < 0.0:
		fn = -fn
	for k in range(1, sorted.size() - 1):
		var tri := [sorted[0], sorted[k + 1], sorted[k]]
		for v in tri:
			st.set_normal(fn)
			var ax := 0
			if absf(fn.y) >= absf(fn.x) and absf(fn.y) >= absf(fn.z):
				ax = 1
			elif absf(fn.z) >= absf(fn.x):
				ax = 2
			var uv := Vector2(v.z, v.y) if ax == 0 else (Vector2(v.x, v.z) if ax == 1 else Vector2(v.x, v.y))
			st.set_uv(uv + Vector2(0.5, 0.5))
			st.add_vertex(v)


static func v3(a, def := Vector3.ZERO) -> Vector3:
	if a is Array and a.size() >= 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return def


static func part_xform(p: Dictionary) -> Transform3D:
	var rot := v3(p.get("rot", [0, 0, 0])) * (PI / 180.0)
	var size := v3(p.get("size", [1, 1, 1]), Vector3.ONE)
	var basis := Basis.from_euler(rot) * Basis.from_scale(size)
	return Transform3D(basis, v3(p.get("pos", [0, 0, 0])))


static func resolve_path(p: String) -> String:
	if p == "" or p.begins_with("res://") or p.begins_with("user://") or p.is_absolute_path():
		return p
	# относительный путь ищем в слоях контента: игра, дополнения, моды
	return DB.find_file(p)


static func texture(path: String) -> Texture2D:
	if _tex.has(path):
		return _tex[path]
	var full := resolve_path(path)
	var tex: Texture2D = null
	if full.begins_with("res://") and ResourceLoader.exists(full):
		tex = load(full)
	else:
		var img := Image.load_from_file(full)
		if img:
			img.generate_mipmaps()
			tex = ImageTexture.create_from_image(img)
	_tex[path] = tex
	return tex


## Стиль героя и монстров («Настройки» → «Стиль персонажей»): мультяшный свет и обводка.
static func char_style() -> Dictionary:
	var st = DB.data.get("settings", {}).get("char_style", {})
	return st if st is Dictionary else {}


static var _chars := {}
static var _chars_rev := -1

## Модель героя или монстра/НПС — рисуется в стиле персонажей.
static func is_char(id: String) -> bool:
	if _chars_rev != DB.revision:
		_chars.clear()
		_chars_rev = DB.revision
		_chars[str(DB.setting("hero_model", "hero"))] = true
		_chars["hero"] = true
		for e in DB.data.get("enemies", {}).values():
			if e is Dictionary:
				_chars[str(e.get("model", ""))] = true
	return _chars.has(id) or bool(model(id).get("toon", false))


static func _toon_for(id: String) -> bool:
	return bool(char_style().get("toon", true)) and is_char(id)


static func _outline_for(id: String, m: Dictionary) -> bool:
	if bool(m.get("outline", false)):
		return true
	return is_char(id) and bool(char_style().get("outline", true)) and bool(Prefs.get_value("char_outline", true))


static func material(p: Dictionary, fov := true, outline := false, toon := false) -> Material:
	_check_rev()
	var two_sided: bool = bool(p.get("two_sided", false))
	var key := "%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s" % [p.get("mat", "paint"), p.get("anim", ""), p.get("texture", ""), p.get("metallic", ""), p.get("roughness", ""), p.get("emission", ""), fov, outline, p.get("surface", ""), p.get("surface_amount", ""), toon, two_sided]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	var mk: String = p.get("mat", "paint")
	if mk == "belt":
		m.shader = BELT_SHADER
	else:
		m.shader = PART_TOON_SHADER if toon else (PART_2S_SHADER if two_sided else PART_SHADER)
		var preset: Dictionary = MATS.get(mk, MATS.paint)
		if toon:
			var cs := char_style()
			m.set_shader_parameter("toon_steps", int(cs.get("steps", 3)))
			m.set_shader_parameter("toon_shade", float(cs.get("shade", 0.38)))
			m.set_shader_parameter("toon_rim", float(cs.get("rim", 0.35)))
			m.set_shader_parameter("toon_spec", float(cs.get("spec", 0.45)))
		m.set_shader_parameter("metallic", float(p.get("metallic", preset.get("metallic", 0.2))))
		m.set_shader_parameter("roughness", float(p.get("roughness", preset.get("roughness", 0.5))))
		m.set_shader_parameter("emission", float(p.get("emission", preset.get("emission", 0.0))))
		m.set_shader_parameter("fov_cull", fov)
		var sf := str(p.get("surface", ""))
		if sf == "":
			sf = str(preset.get("surface", "none"))
		m.set_shader_parameter("surf", max(0, SURFACES.find(sf)))
		m.set_shader_parameter("surf_amount", float(p.get("surface_amount", DB.data.get("settings", {}).get("surface_detail", 1.0))))
		var an: String = p.get("anim", "")
		if an != "" and DB.data.animations.has(an):
			var a: Dictionary = DB.data.animations[an]
			m.set_shader_parameter("anim", max(0, ANIM_TYPES.find(a.get("type", "none"))))
			m.set_shader_parameter("speed", float(a.get("speed", 1.0)))
			m.set_shader_parameter("amount", float(a.get("amount", 1.0)))
			m.set_shader_parameter("always", bool(a.get("always", false)))
			m.set_shader_parameter("offset", float(a.get("phase", 0.0)))
		var tp: String = p.get("texture", "")
		if tp != "":
			var t := texture(tp)
			if t:
				m.set_shader_parameter("tex", t)
				m.set_shader_parameter("use_tex", true)
				m.set_shader_parameter("tex_scale", float(p.get("tex_scale", 1.0)))
		if outline:
			# тонкий тёмный контур вокруг детали (кнопка «Сделать красиво»)
			var o := ShaderMaterial.new()
			o.shader = OUTLINE_SHADER
			o.set_shader_parameter("fov_cull", fov)
			if toon:
				var cs2 := char_style()
				o.set_shader_parameter("width", float(cs2.get("outline_width", 2.0)))
				o.set_shader_parameter("color", DB.color(cs2.get("outline_color", "#14161c")))
			m.next_pass = o
	_mats[key] = m
	return m


static func model(id: String) -> Dictionary:
	var m: Dictionary = DB.model_def(id)
	return m if not m.is_empty() else {"parts": [{"shape": "box", "size": [1, 1, 1], "pos": [0, 0.5, 0], "color": "#ff00ff"}]}


## Список деталей модели в виде [меш, материал, локальная матрица, цвет, затемнять_при_уроне, роль]
static func parts_of(id: String, fov := true) -> Array:
	var m := model(id)
	var out := []
	var gscale := float(m.get("scale", 1.0))
	var g := Transform3D(Basis.from_scale(Vector3.ONE * gscale), Vector3.ZERO)
	var toon_on := _toon_for(id)
	var ol_on := _outline_for(id, m)
	var glb: String = m.get("glb", "")
	if glb != "":
		var gx := g * glb_offset(m)
		for gp in _glb_parts(glb, bool(m.get("glb_raw", false))):
			out.append([gp[0], gp[1], gx * gp[2], Color.WHITE, true, gp[3] if gp.size() > 3 else "glb"])
	for p in m.get("parts", []):
		var mesh := part_mesh(p)
		var mat := material(p, fov, ol_on and str(p.get("anim", "")) == "" and str(p.get("mat", "")) != "glow", toon_on)
		out.append([mesh, mat, g * part_xform(p), DB.color(p.get("color", "#ffffff")), p.get("tint", true), p.get("role", "")])
	return out


## Сдвиг готовой GLB-модели (поле «Сдвиг GLB», в метрах до масштаба).
static func glb_offset(m: Dictionary) -> Transform3D:
	var o = m.get("glb_pos", [0, 0, 0])
	return Transform3D(Basis(), v3(o) if o is Array and o.size() == 3 else Vector3.ZERO)


## Габариты GLB-модели как она лежит в файле (без масштаба и сдвига).
static func glb_aabb(path: String, raw := false) -> AABB:
	var box := AABB()
	var first := true
	for gp in _glb_parts(path, raw):
		var b: AABB = gp[2] * (gp[0] as Mesh).get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


## Подогнать готовую модель: поза (по костям или «как в программе», если кости свёрнуты), высота 2 м
## для огромных и крошечных моделей, на землю по центру. Возвращает m с полями scale, glb_pos, glb_raw и note.
static func glb_fit(m: Dictionary, path: String) -> Dictionary:
	var bx := glb_aabb(path)
	m.erase("glb_raw")
	var note := ""
	var bxr := glb_aabb(path, true)
	if glb_anims(path).is_empty() and bxr.size.y > bx.size.y * 1.6:
		m["glb_raw"] = true
		bx = bxr
		note += "; кости в файле стояли в свёрнутой позе — показываю позу без костей (поле «Поза без костей»)"
	var h := maxf(bx.size.y, maxf(bx.size.x, bx.size.z) * 0.5)
	if is_nan(h) or h < 0.00001:
		m["note"] = "bad"
		return m
	m["scale"] = 1.0
	if h > 6.0 or h < 0.25:
		m["scale"] = clampf(snappedf(2.0 / h, 0.0001), 0.0005, 2000.0)
		note = ": была %s м в высоту — масштаб подогнан до 2 м (поле «Общий масштаб»)" % snappedf(bx.size.y, 0.01) + note
	var c := bx.get_center()
	m["glb_pos"] = [snappedf(-c.x, 0.0001), snappedf(-bx.position.y, 0.0001), snappedf(-c.z, 0.0001)]
	m["note"] = note
	return m


## Почему GLB-файл не открывается (пусто — всё хорошо). Понятным языком для автора.
static func glb_problem(path: String) -> String:
	var full := resolve_path(path)
	if not FileAccess.file_exists(full):
		return "файл не найден: " + full
	var js := ""
	if full.get_extension().to_lower() == "glb":
		var f := FileAccess.open(full, FileAccess.READ)
		if f and f.get_length() > 20 and f.get_32() == 0x46546C67:
			f.get_32(); f.get_32()
			var clen := f.get_32()
			f.get_32()
			js = f.get_buffer(clen).get_string_from_utf8()
		elif f:
			return "это не GLB (возможно, другой формат с расширением .glb) — пересохраните как glTF Binary (.glb)"
	else:
		js = FileAccess.get_file_as_string(full)
	var j = JSON.parse_string(js)
	if j is Dictionary:
		var need: Array = j.get("extensionsRequired", [])
		for e in need:
			if str(e) in ["KHR_draco_mesh_compression", "EXT_meshopt_compression", "KHR_mesh_quantization", "KHR_texture_basisu"]:
				return "модель сжата (%s) — такое движок не читает. Скачайте вариант без сжатия или откройте в Blender и сохраните заново как .glb без галочки «Compression»" % e
	if _glb_parts(path).is_empty():
		return "в файле нет ни одной сетки (меша) — возможно, только скелет или анимация"
	return ""


## Готовая модель целиком (со скелетом и анимациями), для героя и окна просмотра.
static func glb_instance(path: String) -> Node3D:
	return _glb_scene(path) as Node3D


## Файл читается с диска один раз (большие модели — сотни МБ), дальше сцена собирается из прочитанного.
static var _glb_states := {}

static func _glb_scene(path: String) -> Node:
	_check_rev()
	var full := resolve_path(path)
	if full.begins_with("res://") and ResourceLoader.exists(full, "PackedScene"):
		var scene := load(full) as PackedScene
		return scene.instantiate() if scene else null
	if not _glb_states.has(full):
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		if document.append_from_file(full, state) != OK:
			return null
		var scene := document.generate_scene(state)
		if scene == null:
			return null
		_apply_mesh_lods(scene, full)
		var packed := PackedScene.new()
		if packed.pack(scene) != OK:
			return scene
		_glb_states[full] = packed
		return scene
	return (_glb_states[full] as PackedScene).instantiate()


static func _apply_mesh_lods(scene: Node, path: String) -> void:
	var lod_path := path.get_basename() + ".lod"
	if not FileAccess.file_exists(lod_path):
		return
	var file := FileAccess.open_compressed(lod_path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if file == null:
		return
	var levels = file.get_var()
	var instances := scene.find_children("*", "MeshInstance3D", true, false)
	if not levels is Array or levels.size() != instances.size():
		return
	for i in instances.size():
		var instance: MeshInstance3D = instances[i]
		var original := instance.mesh as ArrayMesh
		if original == null or original.get_blend_shape_count() > 0 or levels[i].size() != original.get_surface_count():
			continue
		var mesh := ArrayMesh.new()
		for surface in original.get_surface_count():
			var arrays := original.surface_get_arrays(surface)
			mesh.add_surface_from_arrays(original.surface_get_primitive_type(surface), arrays, [], levels[i][surface], original.surface_get_format(surface))
			mesh.surface_set_material(surface, original.surface_get_material(surface))
		mesh.set_meta("colony_lods", levels[i])
		instance.mesh = mesh


static func glb_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := glb_player(c)
		if r:
			return r
	return null


## Имена анимаций в файле (кэш по пути).
static var _glb_anim_names := {}

static func glb_anims(path: String) -> PackedStringArray:
	_check_rev()
	if _glb_anim_names.has(path):
		return _glb_anim_names[path]
	var out := PackedStringArray()
	var n := glb_instance(path)
	if n:
		var ap := glb_player(n)
		if ap:
			out = ap.get_animation_list()
		n.free()
	_glb_anim_names[path] = out
	return out


const GLB_STATES := ["idle", "walk", "run", "attack", "shoot", "jump", "die", "hurt"]
const GLB_WORDS := {"idle": ["idle", "stand", "breath", "rest", "wait"], "walk": ["walk"], "run": ["run", "sprint", "jog", "gallop"],
	"attack": ["attack", "punch", "slash", "swing", "hit", "strike", "melee", "kick"], "shoot": ["shoot", "fire", "aim", "gun"],
	"jump": ["jump", "leap"], "die": ["death", "die", "dead", "dying"], "hurt": ["hurt", "damage", "react", "impact"]}

## Какая анимация файла играет в состоянии state: из поля модели «Анимации GLB» или по словам в названии.
static func glb_anim_for(m: Dictionary, state: String, names: PackedStringArray) -> String:
	var set_name := str(m.get("glb_anims", {}).get(state, "")) if m.get("glb_anims") is Dictionary else ""
	if set_name != "" and set_name in names:
		return set_name
	for w in GLB_WORDS.get(state, []):
		for nm in names:
			if w in nm.to_lower():
				return nm
	return ""


## raw — сетки «как в программе» (без пересчёта по костям): для файлов, где кости стоят в странной позе.
static func _glb_parts(path: String, raw := false) -> Array:
	var ck := path + ("|raw" if raw else "")
	if _glb.has(ck):
		return _glb[ck]
	_raw_mode = raw
	var res := []
	var scene := _glb_scene(path)
	if scene:
		_collect_glb(scene, Transform3D.IDENTITY, res)
		_frontier_minerals(path.get_file().get_basename(),res)
		scene.free()
	_glb[ck] = res
	return res

static func _frontier_minerals(asset: String, surfaces: Array) -> void:
	var hues := {"cobalt_iron":["#373739","#a45f41"],"native_copper":["#783b29","#d98e60"],"quartz_vein":["#a6a29a","#fff4e5"],"ferrous_shale":["#484051","#bd9476"]}
	if not hues.has(asset) and asset != "amethyst_garden":
		return
	for part in surfaces:
		var source: Material = part[1]
		if source == null:
			continue
		var key := source.resource_name
		if asset == "amethyst_garden":
			if key == "Amethyst cuticle":
				var cap := ShaderMaterial.new()
				cap.shader = preload("res://shaders/spore_cap.gdshader")
				part[1] = cap
			continue
		if not key.begins_with(asset):
			continue
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://shaders/gemstone.gdshader")
		mat.set_shader_parameter("body", Color(hues[asset][0]))
		mat.set_shader_parameter("light_tip",Color(hues[asset][1]))
		mat.set_shader_parameter("facet",1.0 if "core" in key else (.56 if "faces" in key else .15))
		part[1] = mat


static var _raw_mode := false


static func _collect_glb(n: Node, xf: Transform3D, out: Array) -> void:
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh and (n as MeshInstance3D).skin != null and not _raw_mode:
		# сетка на скелете: в файле она лежит «как в программе» (часто в сантиметрах или повёрнута),
		# а настоящий вид даёт скелет — пересчитываем вершины по костям в позе покоя
		var baked := _bake_skinned(n as MeshInstance3D)
		if not baked.is_empty():
			for b in baked:
				out.append(b)
			for c in n.get_children():
				_collect_glb(c, t, out)
			return
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var mi := n as MeshInstance3D
		var part_role := "glb"
		if str(mi.name).begins_with("FC_"):
			var prefix := str(mi.name).get_slice("_", 1)
			if prefix in ["base", "head", "pitch", "slide", "spindle", "press", "arm", "scanner", "dockcraft"] or prefix.begins_with("rotor"):
				part_role = prefix
		var sc := mi.mesh.get_surface_count()
		if sc <= 1:
			out.append([mi.mesh, mi.get_active_material(0), t, part_role])
		else:
			# у модели несколько материалов — каждая поверхность своей деталью со своим материалом
			for si in sc:
				var am := ArrayMesh.new()
				var sa := mi.mesh.surface_get_arrays(si)
				_drop_custom(sa)
				var levels: Array = mi.mesh.get_meta("colony_lods",[])
				var lods: Dictionary = levels[si] if si < levels.size() else {}
				am.add_surface_from_arrays(mi.mesh.surface_get_primitive_type(si),sa,[],lods)
				if not lods.is_empty():
					am.set_meta("colony_lods",[lods])
				out.append([am, mi.get_active_material(si), t, part_role])
	for c in n.get_children():
		_collect_glb(c, t, out)


## Доп. каналы (TEXCOORD_2 и дальше) без описания формата не принимаются — для показа они не нужны.
static func _drop_custom(arr: Array) -> void:
	for ci in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
		arr[ci] = null


## Положение узла относительно корня сцены файла.
static func _acc_xf(n: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var c := n
	while c != null:
		if c is Node3D:
			xf = (c as Node3D).transform * xf
		c = c.get_parent()
	return xf


## Сетка со скелетом в позе покоя: [[меш, материал, матрица], ...] в координатах корня файла.
static func _bake_skinned(mi: MeshInstance3D) -> Array:
	var sk := mi.get_node_or_null(mi.skeleton) as Skeleton3D
	if sk == null:
		return []
	var skin := mi.skin
	var nb := sk.get_bone_count()
	var grest: Array[Transform3D] = []
	grest.resize(nb)
	for i in nb:
		var par := sk.get_bone_parent(i)
		grest[i] = (grest[par] if par >= 0 and par < i else Transform3D.IDENTITY) * sk.get_bone_rest(i)
	# у костей родитель может идти позже по номеру — досчитываем
	for i in nb:
		var par2 := sk.get_bone_parent(i)
		if par2 >= i:
			var chain: Array[int] = []
			var j := i
			while j >= 0:
				chain.push_front(j)
				j = sk.get_bone_parent(j)
			var acc := Transform3D.IDENTITY
			for k in chain:
				acc = acc * sk.get_bone_rest(k)
			grest[i] = acc
	var skx := _acc_xf(sk)
	var mats: Array[Transform3D] = []
	for bi in skin.get_bind_count():
		var bone := skin.get_bind_bone(bi)
		if bone < 0:
			bone = sk.find_bone(skin.get_bind_name(bi))
		mats.append(skx * (grest[bone] if bone >= 0 and bone < nb else Transform3D.IDENTITY) * skin.get_bind_pose(bi))
	var out := []
	for si in mi.mesh.get_surface_count():
		var arr := mi.mesh.surface_get_arrays(si)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ns = arr[Mesh.ARRAY_NORMAL]
		var bones = arr[Mesh.ARRAY_BONES]
		var ws = arr[Mesh.ARRAY_WEIGHTS]
		if not (bones is PackedInt32Array) or not (ws is PackedFloat32Array) or vs.is_empty():
			return []
		var per: int = bones.size() / vs.size()
		var nv := PackedVector3Array()
		nv.resize(vs.size())
		var nn := PackedVector3Array()
		var has_n: bool = ns is PackedVector3Array and ns.size() == vs.size()
		if has_n:
			nn.resize(vs.size())
		for vi in vs.size():
			var p := Vector3.ZERO
			var q := Vector3.ZERO
			var wsum := 0.0
			for k in per:
				var w: float = ws[vi * per + k]
				if w <= 0.0:
					continue
				var bidx: int = bones[vi * per + k]
				var m: Transform3D = mats[bidx] if bidx < mats.size() else skx
				p += (m * vs[vi]) * w
				if has_n:
					q += (m.basis * ns[vi]) * w
				wsum += w
			if wsum <= 0.0:
				p = skx * vs[vi]
				if has_n:
					q = skx.basis * ns[vi]
			else:
				p /= wsum
			nv[vi] = p
			if has_n:
				nn[vi] = q.normalized()
		arr[Mesh.ARRAY_VERTEX] = nv
		if has_n:
			arr[Mesh.ARRAY_NORMAL] = nn
		arr[Mesh.ARRAY_TANGENT] = null
		arr[Mesh.ARRAY_BONES] = null
		arr[Mesh.ARRAY_WEIGHTS] = null
		_drop_custom(arr)
		var am := ArrayMesh.new()
		var levels: Array = mi.mesh.get_meta("colony_lods", [])
		var lods: Dictionary = levels[si] if si < levels.size() else {}
		am.add_surface_from_arrays(mi.mesh.surface_get_primitive_type(si), arr, [], lods)
		if not lods.is_empty():
			am.set_meta("colony_lods",[lods])
		out.append([am, mi.get_active_material(si), Transform3D.IDENTITY])
	return out


## Детали модели, где все неподвижные детали с одинаковым материалом склеены в один меш.
## Так модель из 300+ деталей рисуется за несколько вызовов, а не за сотни.
## Не склеиваются: анимированные, с ролью (башня турели, растяжка), белые (их красят в цвет предмета).
static func merged_parts(id: String, fov := true, by_role := false) -> Array:
	_check_rev()
	var key := "%s|%s|%s" % [id, fov, by_role]
	if _merged.has(key):
		return _merged[key]
	var m := model(id)
	var out := []
	var gscale := float(m.get("scale", 1.0))
	var g := Transform3D(Basis.from_scale(Vector3.ONE * gscale), Vector3.ZERO)
	var toon_on := _toon_for(id)
	var ol_on := _outline_for(id, m)
	var glb: String = m.get("glb", "")
	if glb != "":
		var gx := g * glb_offset(m)
		for gp in _glb_parts(glb, bool(m.get("glb_raw", false))):
			out.append([gp[0], gp[1], gx * gp[2], Color.WHITE, true, gp[3] if gp.size() > 3 else "glb"])
	var groups := {}    # ключ -> {mat, tint, verts, norms, uvs, cols, idx}
	var order := []
	for p in m.get("parts", []):
		var mesh := part_mesh(p)
		var mat := material(p, fov, ol_on and str(p.get("anim", "")) == "" and str(p.get("mat", "")) != "glow", toon_on)
		var col := DB.color(p.get("color", "#ffffff"))
		var tint: bool = p.get("tint", true)
		var xf := g * part_xform(p)
		# анимации, которые считаются по вершинам одинаково для любой детали (свечение, качание по высоте, сдвиг),
		# склеиваются тоже; вращение, шаги и маятник — только отдельной деталью
		var an := str(p.get("anim", ""))
		var an_ok: bool = an == "" or (DB.data.animations.has(an) and str(DB.data.animations[an].get("type", "none")) in MERGE_ANIMS)
		# башня турели («head») поворачивается целиком, поэтому её детали тоже склеиваются — отдельной группой
		var role_s := str(p.get("role", ""))
		var keep_role: bool = by_role or role_s in ["head", "pitch", "slide"]
		var solo: bool = not an_ok or (role_s != "" and not role_s.begins_with("b:") and not keep_role) or str(p.get("mat", "")) == "belt" \
			or col.is_equal_approx(Color.WHITE) or str(p.get("texture", "")) != ""
		if solo:
			if str(p.get("shape", "")) == "mesh":
				out.append([mesh, mat, xf, col, tint, p.get("role", ""), true])   # цвет уже в вершинах
			else:
				out.append([mesh, mat, xf, col, tint, p.get("role", "")])
			continue
		var gk := "%d|%s|%s" % [mat.get_instance_id(), tint, role_s if keep_role else ""]
		if not groups.has(gk):
			groups[gk] = {"mat": mat, "tint": tint, "role": role_s if keep_role else "", "v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array(), "c": PackedColorArray(), "i": PackedInt32Array(), "sz": PackedFloat32Array()}
			order.append(gk)
		var G: Dictionary = groups[gk]
		var arr := mesh.surface_get_arrays(0)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ns = arr[Mesh.ARRAY_NORMAL]
		var uvs = arr[Mesh.ARRAY_TEX_UV]
		var ids = arr[Mesh.ARRAY_INDEX]
		var base: int = G.v.size()
		# мелкая деталь (болт, решётка, табличка) — помечаем, чтобы вдали она не рисовалась
		var sz := xf.basis.get_scale()
		var vcol := col
		var psz := maxf(sz.x, maxf(sz.y, sz.z))
		var i0: int = G.i.size()
		if psz < float(DB.setting("detail_size", 0.2)):
			vcol.a = 0.5
		var nb := xf.basis.inverse().transposed()
		for vi in vs.size():
			G.v.append(xf * vs[vi])
			G.n.append((nb * (ns[vi] if ns != null and vi < ns.size() else Vector3.UP)).normalized())
			G.uv.append(uvs[vi] if uvs != null and vi < uvs.size() else Vector2.ZERO)
			G.c.append(vcol)
		if ids != null and ids.size() > 0:
			# у отражённых (отрицательный масштаб) деталей меняем обход треугольников
			var flip := xf.basis.determinant() < 0.0
			for ti in range(0, ids.size(), 3):
				if flip:
					G.i.append(base + ids[ti]); G.i.append(base + ids[ti + 2]); G.i.append(base + ids[ti + 1])
				else:
					G.i.append(base + ids[ti]); G.i.append(base + ids[ti + 1]); G.i.append(base + ids[ti + 2])
		else:
			for vi in vs.size():
				G.i.append(base + vi)
		for ti in (G.i.size() - i0) / 3:
			G.sz.append(psz)
	for gk in order:
		var G: Dictionary = groups[gk]
		var arrs := []
		arrs.resize(Mesh.ARRAY_MAX)
		arrs[Mesh.ARRAY_VERTEX] = G.v
		arrs[Mesh.ARRAY_NORMAL] = G.n
		arrs[Mesh.ARRAY_TEX_UV] = G.uv
		arrs[Mesh.ARRAY_COLOR] = G.c
		arrs[Mesh.ARRAY_INDEX] = G.i
		out.append([with_lods(arrs, G.i.size() / 3, G.sz), G.mat, Transform3D.IDENTITY, Color.WHITE, G.tint, G.role, true])   # true — склеенная группа: цвета уже в вершинах, красить цветом профессии нельзя
	_merged[key] = out
	return out


## Склеенный меш с упрощёнными копиями (LOD): вдали движок сам рисует копию с меньшим числом треугольников.
## Мелкие меши (меньше lod_min_tris треугольников, «Настройки») не упрощаются.
## Сначала вдали убираются мелкие детали (иголки, болты, щепки) — целиком, без дыр;
## если мелочи нет — меш упрощается сам (меньше граней у крупных деталей).
static func with_lods(arrs: Array, tris: int, sizes := PackedFloat32Array()) -> ArrayMesh:
	if tris >= int(DB.setting("lod_min_tris", 300)) and bool(DB.setting("mesh_lod", true)):
		if sizes.size() == tris:
			var idx: PackedInt32Array = arrs[Mesh.ARRAY_INDEX]
			var lods := {}
			var prev := tris
			for t in [float(DB.setting("detail_size", 0.2)), 0.6, 1.5]:
				var li := PackedInt32Array()
				for ti in tris:
					if sizes[ti] >= t:
						li.append(idx[ti * 3]); li.append(idx[ti * 3 + 1]); li.append(idx[ti * 3 + 2])
				var n := li.size() / 3
				if n > 0 and n < prev * 0.8:
					# ошибка уровня — размер выброшенной детали (половина: мелочь не мелькает)
					lods[t * 0.5] = li
					prev = n
			if not lods.is_empty():
				var am0 := ArrayMesh.new()
				am0.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrs, [], lods)
				return am0
		var im := ImporterMesh.new()
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrs)
		im.generate_lods(60.0, 25.0, [])
		return im.get_mesh()
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrs)
	return am


static func make_renderer(id: String, shadows := true, fov := true, merge := false) -> PartRenderer:
	var r := PartRenderer.new()
	r.model_id = id
	for p in (merged_parts(id, fov) if merge else parts_of(id, fov)):
		r.add_part(p[0], p[1], p[2], p[3], shadows, p[4], p[5])
	return r


## Отдельный узел модели (для превью, героя, особых объектов).
static func make_node(id: String, fov := false, merge := false) -> Node3D:
	var root := Node3D.new()
	for p in (merged_parts(id, fov, true) if merge else parts_of(id, fov)):
		var m: Material = p[1]
		if m is ShaderMaterial:
			# цвет детали и фаза анимации передаются как у MultiMesh из одного экземпляра
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.use_custom_data = true
			mm.mesh = p[0]
			mm.instance_count = 1
			mm.set_instance_transform(0, Transform3D.IDENTITY)
			mm.set_instance_color(0, p[3])
			mm.set_instance_custom_data(0, Color(1, randf(), 0, 0))
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.material_override = m
			mmi.transform = p[2]
			mmi.set_meta("role", p[5])
			root.add_child(mmi)
		else:
			var mi := MeshInstance3D.new()
			mi.mesh = p[0]
			mi.transform = p[2]
			mi.set_meta("role", p[5])
			if m:
				mi.material_override = m
			root.add_child(mi)
	return root


static func make_ghost(id: String) -> Node3D:
	var root := Node3D.new()
	var gm := StandardMaterial3D.new()
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.albedo_color = Color(0.3, 1.0, 0.5, 0.45)
	root.set_meta("mat", gm)
	for p in parts_of(id, false):
		var mi := MeshInstance3D.new()
		mi.mesh = p[0]
		mi.transform = p[2]
		mi.material_override = gm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	var arrow := MeshInstance3D.new()
	arrow.mesh = unit_mesh("prism")
	arrow.transform = Transform3D(Basis.from_euler(Vector3(-PI / 2, 0, -PI / 2)) * Basis.from_scale(Vector3(0.8, 0.9, 0.08)), Vector3(1.2, 0.1, 0))
	arrow.material_override = gm
	root.add_child(arrow)
	return root


## Иконка предмета: картинка из поля "icon" или цветной квадрат.
static func item_icon(id: String) -> Texture2D:
	var it := DB.item(id)
	var ip: String = it.get("icon", "")
	if ip != "":
		var t := texture(ip)
		if t:
			return t
	return null
