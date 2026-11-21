extends Node3D
## Открытая зона (13.10): игрок начинает на участке N×N «блоков» вокруг штаба, всё остальное скрыто тучами,
## которые стелются по земле, с молниями. Зона расширяется на 1 блок за ресурсы (кнопка в окне штаба, команда консоли «zone»).
## Всё правится в «Данные» → «Настройки» → «Зона и буря»: размер блока, старт, предел, цены каждого шага.

var game
var blocks := 10
var center := Vector3.ZERO
var walls: Array = []          # MeshInstance3D слоёв туч
var _bolt_t := 2.0
var _flash := 0.0
var _rng := RandomNumberGenerator.new()
var rects: Array = []          # 15.5: открытые игроком участки P×P блоков: Vector2i — блок левого верхнего угла от центра
var rect_n := {}               # 1.3: сторона каждого открытого участка (старые сохранения — 5, новые — patch_n())
var _rect_img: Image = null
var _pick: Node3D = null        # рамка выбора участка
const MAX_RECTS := 64


func cfg() -> Dictionary:
	var z = DB.data.settings.get("zone", {})
	return z if z is Dictionary else {}


func on() -> bool:
	return game.module("zone") and bool(cfg().get("enabled", true))


func block_m() -> float:
	return maxf(2.0, float(cfg().get("block_m", 8.0)))


func max_blocks() -> int:
	var lim := int(cfg().get("max_blocks", 60))
	if game.world:
		lim = mini(lim, int(game.world.W * World.C / block_m()) - 2)
	return maxi(1, lim)


func half() -> float:
	return blocks * block_m() * 0.5


func setup(hq_pos: Vector3) -> void:
	center = Vector3(hq_pos.x, 0.0, hq_pos.z)
	blocks = clampi(int(cfg().get("start_blocks", 10)), 1, max_blocks())
	_rng.randomize()
	process_priority = 1000   # после камеры
	rebuild()


## Расстояние до края зоны по горизонтали: < 0 — внутри, > 0 — под тучами. Форма — скруглённый квадрат
## с волнистым краем (поля «Скругление углов» и «Волнистость края»); та же формула в shaders/zone.gdshaderinc.
func sd(p: Vector3) -> float:
	if not on():
		return -100000.0
	var dd := World.delta(center, p)
	var d := Vector2(dd.x, dd.z)
	var h := half()
	var r := clampf(float(cfg().get("corner", 0.35)), 0.0, 1.0) * h
	var q := Vector2(absf(d.x), absf(d.y)) - Vector2(h - r, h - r)
	var base := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - r
	var th := atan2(d.y, d.x)
	var s3 := seeds()
	var w := wobble() * (0.5 * sin(3.0 * th + s3.x) + 0.3 * sin(5.0 * th + s3.y) + 0.2 * sin(11.0 * th + s3.z))
	var out := base + w
	# 15.5: участки, открытые игроком (та же формула в shaders/zone.gdshaderinc)
	for rc in rects:
		var rr := _rect_box(rc)
		var q2 := Vector2(absf(d.x - rr.position.x), absf(d.y - rr.position.y)) - rr.size + Vector2(2.0, 2.0)
		var bd := Vector2(maxf(q2.x, 0.0), maxf(q2.y, 0.0)).length() + minf(maxf(q2.x, q2.y), 0.0) - 2.0
		out = minf(out, bd + w * 0.35)
	return out


## 15.5: сторона участка в блоках (поле «Участок, блоков»).
func patch_n() -> int:
	return clampi(int(cfg().get("patch_blocks", 3)), 1, 20)


## Прямоугольник участка: position — центр от центра зоны (м), size — половины сторон.
func _rect_box(rc: Vector2i) -> Rect2:
	var bm := block_m()
	var hs := int(rect_n.get(rc, patch_n())) * bm * 0.5
	return Rect2(Vector2(rc.x * bm + hs, rc.y * bm + hs), Vector2(hs, hs))


## Участок под точкой p (центр участка — в точке, по сетке блоков).
func patch_at(p: Vector3) -> Vector2i:
	var dd := World.delta(center, p)
	var bm := block_m()
	return Vector2i(roundi(dd.x / bm - patch_n() * 0.5), roundi(dd.z / bm - patch_n() * 0.5))


func patch_center(rc: Vector2i) -> Vector3:
	var r := _rect_box(rc)
	var p := center + Vector3(r.position.x, 0, r.position.y)
	return World.wrap_pos(p) if game.world and game.world.wrap else p


## Почему нельзя открыть участок ("" — можно): должен касаться открытой земли и не быть уже открытым.
func patch_why(rc: Vector2i) -> String:
	if not on():
		return "Зона выключена"
	if not bool(cfg().get("patches", true)):
		return "Участки выключены (Правила игры → «Зона и буря»)"
	if rects.size() >= MAX_RECTS:
		return "Открыто максимум участков"
	var bm := block_m()
	var n := patch_n()
	var touch := false
	var closed := false
	for i in n:
		for j in n:
			var bp := center + Vector3((rc.x + i + 0.5) * bm, 0, (rc.y + j + 0.5) * bm)
			var v := sd(bp)
			if v > -bm * 0.25:
				closed = true
			if v < bm * 1.05:
				touch = true
	if not closed:
		return "Этот участок уже открыт"
	if not touch:
		return "Участок должен примыкать к открытой земле"
	if game.world and not game.world.wrap:
		var c0 := World.world_to_cell(center + Vector3(rc.x * bm, 0, rc.y * bm))
		var c1 := World.world_to_cell(center + Vector3((rc.x + n) * bm, 0, (rc.y + n) * bm))
		if c0.x < 1 or c0.y < 1 or c1.x >= game.world.W - 1 or c1.y >= game.world.W - 1:
			return "За краем карты"
	return ""


func patch_cost() -> Dictionary:
	# 1.3: цена от площади — участок 3×3 стоит как 9/25 прежнего 5×5
	var k := maxf(0.0, float(cfg().get("patch_cost_k", 0.6))) * float(patch_n() * patch_n()) / 25.0
	# 1.5: каждые N открытых участков цена идёт на следующий шаг (раньше участки всегда стоили брёвна и камень —
	# всю карту можно было открыть за них), внутри шага — чуть дороже с каждым участком
	var per := maxi(1, int(cfg().get("patch_per_step", 3)))
	var opened := rects.size()
	k *= 1.0 + 0.2 * float(opened % per)
	var out := {}
	var nc := next_cost(opened / per)
	for it in nc:
		out[it] = maxi(1, int(round(float(nc[it]) * k)))
	return out


func patch_can(rc: Vector2i) -> String:
	var w := patch_why(rc)
	if w != "":
		return w
	var cost := patch_cost()
	for it in cost:
		if game.factory.available(it) < int(cost[it]):
			return "Не хватает: %s" % DB.item_name(it)
	return ""


func open_patch(rc: Vector2i, free := false) -> bool:
	if (patch_why(rc) if free else patch_can(rc)) != "":
		return false
	if not free:
		game.factory.pay(patch_cost())
	rects.append(rc)
	rect_n[rc] = patch_n()
	rebuild()
	game.notify("Открыт участок %d×%d блоков" % [patch_n(), patch_n()], Color(0.5, 0.9, 1.0))
	game.sfx.play("thunder", patch_center(rc))
	return true


## Рамка выбора участка над землёй: зелёная — можно, красная — нельзя.
func show_pick(p, ok := true) -> void:
	if p == null:
		if _pick:
			_pick.visible = false
		return
	if _pick == null:
		_pick = Node3D.new()
		add_child(_pick)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.no_depth_test = true
		mat.render_priority = 20
		for i in 5:
			var mi := MeshInstance3D.new()
			mi.mesh = BoxMesh.new()
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_pick.add_child(mi)
		_pick.set_meta("mat", mat)
		var fill := mat.duplicate() as StandardMaterial3D
		(_pick.get_child(4) as MeshInstance3D).material_override = fill
		_pick.set_meta("fill", fill)
	var rc: Vector2i = p
	var c := patch_center(rc)
	var side := patch_n() * block_m()
	var y: float = (game.world.height_at(c) if game.world else 0.0) + float(cfg().get("cloud_height", 2.4)) + 0.6
	_pick.visible = true
	_pick.global_position = Vector3(c.x, y, c.z)
	var mat2: StandardMaterial3D = _pick.get_meta("mat")
	mat2.albedo_color = Color(0.3, 1.0, 0.5, 0.9) if ok else Color(1.0, 0.35, 0.3, 0.9)
	var fm: StandardMaterial3D = _pick.get_meta("fill")
	fm.albedo_color = Color(0.3, 1.0, 0.5, 0.1) if ok else Color(1.0, 0.35, 0.3, 0.1)
	var bars := [[Vector3(0, 0, -side * 0.5), Vector3(side, 0.3, 0.6)], [Vector3(0, 0, side * 0.5), Vector3(side, 0.3, 0.6)],
		[Vector3(-side * 0.5, 0, 0), Vector3(0.6, 0.3, side)], [Vector3(side * 0.5, 0, 0), Vector3(0.6, 0.3, side)], [Vector3.ZERO, Vector3(side, 0.02, side)]]
	for i in 5:
		var mi: MeshInstance3D = _pick.get_child(i)
		mi.position = bars[i][0]
		(mi.mesh as BoxMesh).size = bars[i][1]


func wobble() -> float:
	return clampf(float(cfg().get("wobble", 4.0)), 0.0, half() * 0.3)


func seeds() -> Vector3:
	var k := float(cfg().get("shape_seed", 7))
	return Vector3(fmod(k * 1.7, TAU), fmod(k * 2.9 + 1.0, TAU), fmod(k * 4.3 + 2.0, TAU))


## Внутри зоны? (pad > 0 — с запасом от края)
func inside(p: Vector3, pad := 0.0) -> bool:
	return sd(p) <= -pad


func inside_cell(c: Vector2i) -> bool:
	return inside(World.cell_to_world(c))


## Точка на краю зоны в сторону dir (для волн роботов): out — на сколько метров под тучами.
func edge_point(dir: Vector3, out := 1.5) -> Vector3:
	dir.y = 0.0
	dir = dir.normalized()
	var lo := 0.0
	var hi := half() * 2.0 + wobble() + 10.0
	for i in 24:
		var m := (lo + hi) * 0.5
		if sd(center + dir * m) < out:
			lo = m
		else:
			hi = m
	var p := center + dir * hi
	if game.world and game.world.wrap:
		p = World.wrap_pos(p)
	return p


func next_cost(extra := 0) -> Dictionary:
	var steps: Array = cfg().get("steps", [])
	var i := blocks - int(cfg().get("start_blocks", 10)) + extra
	if steps.is_empty():
		return {}
	var k := 1.0
	if i >= steps.size():
		k = pow(maxf(1.0, float(cfg().get("growth", 1.25))), i - steps.size() + 1)
		i = steps.size() - 1
	var st = steps[maxi(0, i)]
	var cost = st.get("cost", st) if st is Dictionary else {}
	var out := {}
	for it in cost:
		out[it] = maxi(1, int(round(float(cost[it]) * k)))
	return out


## 1.1.15: между расширениями — пауза (настройка zone.expand_cooldown, 60 с): быстрыми кликами раньше
## можно было расширить несколько раз по старой цене, пока окно не обновило требования.
var next_ok_ms := 0


func cooldown_left() -> float:
	return maxf(0.0, float(next_ok_ms - Time.get_ticks_msec()) / 1000.0)


func can_expand() -> String:
	if not on():
		return "Зона выключена"
	if blocks >= max_blocks():
		return "Зона уже максимальная"
	if cooldown_left() > 0.0 and not Net.is_client():
		return "Следующее расширение — через %d с" % ceili(cooldown_left())
	var cost := next_cost()
	for it in cost:
		if game.factory.available(it) < int(cost[it]):
			return "Не хватает: %s" % DB.item_name(it)
	return ""


func expand(free := false) -> bool:
	if not free and can_expand() != "":
		return false
	if not free:
		game.factory.pay(next_cost())
	blocks += 1
	next_ok_ms = Time.get_ticks_msec() + int(float(cfg().get("expand_cooldown", 60.0)) * 1000.0)
	rebuild()
	game.notify("Зона расширена: %d×%d" % [blocks, blocks], Color(0.5, 0.9, 1.0))
	game.sfx.play("thunder", center)
	return true


func set_blocks(n: int) -> void:
	blocks = clampi(n, 1, max_blocks())
	rebuild()


# ---------------------------------------------------------------- вид: тучи, стелющиеся по земле
## Значения для шейдеров (земля, деревья, трава, вода, роботы прячутся под тучами).
func _globals() -> void:
	var c := cfg()
	var rs := RenderingServer
	rs.global_shader_parameter_set("zone_on", 1.0 if on() else 0.0)
	rs.global_shader_parameter_set("zone_center", Vector2(center.x, center.z))
	rs.global_shader_parameter_set("zone_half", half())
	rs.global_shader_parameter_set("zone_corner", clampf(float(c.get("corner", 0.35)), 0.0, 1.0))
	rs.global_shader_parameter_set("zone_wobble", wobble())
	rs.global_shader_parameter_set("zone_seed", seeds())
	rs.global_shader_parameter_set("zone_world", float(game.world.W * World.C) if game.world and game.world.wrap else 0.0)
	rs.global_shader_parameter_set("zone_soft", maxf(0.5, float(c.get("soft", 5.0))))
	rs.global_shader_parameter_set("zone_speed", float(c.get("cloud_speed", 1.0)))
	rs.global_shader_parameter_set("zone_flicker", float(c.get("flicker", 1.0)))
	rs.global_shader_parameter_set("zone_dark", DB.color(c.get("dark_color", "#0f0f17")))
	rs.global_shader_parameter_set("zone_cloud", DB.color(c.get("cloud_color", "#5a5478")))
	rs.global_shader_parameter_set("zone_flash_col", DB.color(c.get("flash_color", "#a8c0ff")))
	# 15.5: участки — в текстуру (на пиксель: центр x, z и половины сторон)
	if _rect_img == null:
		_rect_img = Image.create(MAX_RECTS, 1, false, Image.FORMAT_RGBAF)
	_rect_img.fill(Color(0, 0, 0, 0))
	for i in mini(rects.size(), MAX_RECTS):
		var rr := _rect_box(rects[i])
		_rect_img.set_pixel(i, 0, Color(rr.position.x, rr.position.y, rr.size.x, rr.size.y))
	rs.global_shader_parameter_set("zone_rects", ImageTexture.create_from_image(_rect_img))
	rs.global_shader_parameter_set("zone_nrect", float(mini(rects.size(), MAX_RECTS)))
	rs.global_shader_parameter_set("zone_lq", 1.0 if lq() else 0.0)


# 1.5: расстояние до края зоны — в текстуру (на открытие участка уходило ~0.2 с, а шейдеры земли и туч
# на каждом пикселе перебирали все участки — на встроенной видеокарте это и съедало FPS)
const SDF_STEP := 2.0           # метров на пиксель
const SDF_MAX := 1024
var _sdf: PackedFloat32Array
var _sdf_n := 0
var _sdf_ext := 0.0
var _sdf_far := 30.0
var _hs_key := ""
var _hs := PackedFloat32Array()


func _ext() -> float:
	var far := maxf(20.0, float(cfg().get("cloud_far", 120.0)))
	var ext := half() + wobble() + far
	for rc in rects:
		var rr := _rect_box(rc)
		ext = maxf(ext, maxf(absf(rr.position.x), absf(rr.position.y)) + rr.size.x + wobble() + far * 0.5)
	return ext


## Посчитать текстуру расстояний: квадрат 2·ext вокруг центра зоны. Дальше чем _sdf_far от края — просто «далеко»
## (тучи там сплошные), поэтому участки пересчитывают только клетки рядом с собой.
func _bake(ext: float) -> void:
	var n := clampi(int(ceil(ext * 2.0 / SDF_STEP)), 8, SDF_MAX)
	var st := ext * 2.0 / n
	var soft := maxf(0.5, float(cfg().get("soft", 5.0)))
	var far := soft * 3.0 + wobble() + 6.0
	_sdf_far = far
	_sdf_n = n
	_sdf_ext = ext
	_sdf.resize(n * n)
	var h := half()
	var r := clampf(float(cfg().get("corner", 0.35)), 0.0, 1.0) * h
	var wob := wobble()
	var s3 := seeds()
	var wv := PackedFloat32Array()
	wv.resize(n * n)
	for iz in n:
		var dz := -ext + (iz + 0.5) * st
		for ix in n:
			var dx := -ext + (ix + 0.5) * st
			var k := iz * n + ix
			var th := atan2(dz, dx)
			var w := wob * (0.5 * sin(3.0 * th + s3.x) + 0.3 * sin(5.0 * th + s3.y) + 0.2 * sin(11.0 * th + s3.z))
			wv[k] = w
			var qx := absf(dx) - (h - r)
			var qz := absf(dz) - (h - r)
			var base := Vector2(maxf(qx, 0.0), maxf(qz, 0.0)).length() + minf(maxf(qx, qz), 0.0) - r
			_sdf[k] = clampf(base + w, -far, far)
	for rc in rects:
		var rr := _rect_box(rc)
		var x0 := clampi(int(floor((rr.position.x - rr.size.x - far + ext) / st)), 0, n - 1)
		var x1 := clampi(int(ceil((rr.position.x + rr.size.x + far + ext) / st)), 0, n - 1)
		var z0 := clampi(int(floor((rr.position.y - rr.size.y - far + ext) / st)), 0, n - 1)
		var z1 := clampi(int(ceil((rr.position.y + rr.size.y + far + ext) / st)), 0, n - 1)
		for iz in range(z0, z1 + 1):
			var dz := -ext + (iz + 0.5) * st
			for ix in range(x0, x1 + 1):
				var dx := -ext + (ix + 0.5) * st
				var k := iz * n + ix
				var qx := absf(dx - rr.position.x) - rr.size.x + 2.0
				var qz := absf(dz - rr.position.y) - rr.size.y + 2.0
				var bd := Vector2(maxf(qx, 0.0), maxf(qz, 0.0)).length() + minf(maxf(qx, qz), 0.0) - 2.0 + wv[k] * 0.35
				if bd < _sdf[k]:
					_sdf[k] = maxf(bd, -far)
	var img := Image.create_from_data(n, n, false, Image.FORMAT_RF, _sdf.to_byte_array())
	img.convert(Image.FORMAT_RH)
	var rs := RenderingServer
	rs.global_shader_parameter_set("zone_sdf", ImageTexture.create_from_image(img))
	rs.global_shader_parameter_set("zone_sdf_box", Vector4(ext * 2.0, far, 0.0, 1.0))


## Расстояние до края из готовой текстуры (для сетки туч): точка — смещение от центра зоны.
func _sdf_at(dx: float, dz: float) -> float:
	if _sdf_n <= 0:
		return sd(center + Vector3(dx, 0, dz))
	var st := _sdf_ext * 2.0 / _sdf_n
	var ix := int(floor((dx + _sdf_ext) / st))
	var iz := int(floor((dz + _sdf_ext) / st))
	if ix < 0 or iz < 0 or ix >= _sdf_n or iz >= _sdf_n:
		return _sdf_far
	return _sdf[iz * _sdf_n + ix]


func rebuild() -> void:
	for w in walls:
		w.queue_free()
	walls.clear()
	_globals()
	if not on():
		RenderingServer.global_shader_parameter_set("zone_sdf_box", Vector4(0, 0, 0, 0))
		return
	var c := cfg()
	var layers := clampi(int(c.get("cloud_layers", 3)), 1, 6)
	if lq():
		layers = mini(layers, 2)
	var thick := maxf(0.3, float(c.get("cloud_height", 2.4)))
	var soft := maxf(0.5, float(c.get("soft", 5.0)))
	var step := 4.0
	var ext := _ext()
	_bake(ext)
	var n := int(ceil(ext * 2.0 / step))
	# высоты рельефа в узлах сетки — пока зона того же размера, не пересчитываются
	var key := "%d|%.1f|%.1f" % [n, center.x, center.z]
	if key != _hs_key:
		_hs_key = key
		_hs.resize((n + 1) * (n + 1))
		for iz in n + 1:
			for ix in n + 1:
				_hs[iz * (n + 1) + ix] = game.world.height_at(center + Vector3(-ext + ix * step, 0, -ext + iz * step)) if game.world else 0.0
	var sds := PackedFloat32Array()
	sds.resize((n + 1) * (n + 1))
	for iz in n + 1:
		for ix in n + 1:
			sds[iz * (n + 1) + ix] = _sdf_at(-ext + ix * step, -ext + iz * step)
	# одна сетка на все слои (слой — та же сетка выше)
	var verts := PackedVector3Array()
	verts.resize((n + 1) * (n + 1))
	for iz in n + 1:
		for ix in n + 1:
			var k := iz * (n + 1) + ix
			verts[k] = Vector3(-ext + ix * step, _hs[k], -ext + iz * step)
	var idx := PackedInt32Array()
	for iz in n:
		for ix in n:
			var k := iz * (n + 1) + ix
			if maxf(maxf(sds[k], sds[k + 1]), maxf(sds[k + n + 2], sds[k + n + 1])) < -soft * 1.2:
				continue   # целиком внутри зоны — туч нет
			idx.append_array([k, k + 1, k + n + 2, k, k + n + 2, k + n + 1])
	if idx.is_empty():
		return
	var norms := PackedVector3Array()
	norms.resize(verts.size())
	norms.fill(Vector3.UP)
	var arrs := []
	arrs.resize(Mesh.ARRAY_MAX)
	arrs[Mesh.ARRAY_VERTEX] = verts
	arrs[Mesh.ARRAY_NORMAL] = norms
	arrs[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrs)
	for li in layers:
		var y := thick * (0.25 + 0.75 * float(li) / maxf(1.0, layers - 1.0)) if layers > 1 else thick
		var m := MeshInstance3D.new()
		m.mesh = mesh
		var mat2 := ShaderMaterial.new()
		mat2.shader = preload("res://shaders/storm.gdshader")
		mat2.set_shader_parameter("layer", float(li))
		mat2.set_shader_parameter("density", clampf(float(c.get("cloud_density", 0.9)), 0.05, 1.0) * (1.0 - 0.18 * li))
		mat2.render_priority = li
		m.material_override = mat2
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.position = Vector3(center.x, y, center.z)
		m.extra_cull_margin = 8.0
		add_child(m)
		walls.append(m)


## 1.5: тучи попроще (2 слоя, один шум) — на «Низком» и «Среднем» качестве или после автонастройки.
func lq() -> bool:
	return str(Prefs.get_value("quality", "high")) in ["low", "medium"] or bool(Prefs.get_value("clouds_lq", false))


var _lq_was := false
var _lq_t := 0


func _process(_dt: float) -> void:
	_lq_t += 1
	if _lq_t >= 60:
		_lq_t = 0
		if lq() != _lq_was:
			_lq_was = lq()
			rebuild()
	# главная камера: только в ней прячется всё за границей (иконки и превью — свои камеры)
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam:
		RenderingServer.global_shader_parameter_set("zone_cam", cam.global_position)


func _exit_tree() -> void:
	RenderingServer.global_shader_parameter_set("zone_sdf", null)
	RenderingServer.global_shader_parameter_set("zone_on", 0.0)


func update(delta: float) -> void:
	if not on():
		return
	_flash = maxf(0.0, _flash - delta * 2.5)
	RenderingServer.global_shader_parameter_set("zone_flash", _flash)
	_bolt_t -= delta
	if _bolt_t > 0.0:
		return
	var every := maxf(0.3, float(cfg().get("lightning_every", 4.0)))
	_bolt_t = _rng.randf_range(every * 0.4, every * 1.6)
	_bolt()


## Удар молнии с неба в тучи за краем зоны, недалеко от героя — чтобы было видно.
func _bolt() -> void:
	var pp: Vector3 = game.player.position if game.player else center
	var dir := World.delta(center, pp)
	dir.y = 0.0
	if dir.length() < 1.0:
		dir = Vector3(1, 0, 0)
	var a := atan2(dir.z, dir.x) + _rng.randf_range(-0.6, 0.6)
	var p := edge_point(Vector3(cos(a), 0, sin(a)), _rng.randf_range(4.0, 22.0))
	var ground: float = game.world.height_at(p) if game.world else 0.0
	var top := ground + float(cfg().get("cloud_height", 2.4))
	var col := DB.color(cfg().get("flash_color", "#a8c0ff"))
	var y := top + 34.0
	var at := Vector3(p.x + _rng.randf_range(-6, 6), y, p.z + _rng.randf_range(-6, 6))
	while y > top:
		var ny := maxf(top, y - _rng.randf_range(2.5, 5.0))
		var b := Vector3(at.x + _rng.randf_range(-1.8, 1.8), ny, at.z + _rng.randf_range(-1.8, 1.8))
		if ny <= top:
			b = Vector3(p.x, top, p.z)
		game.fx.tracer(at, b, col * 3.0, 0.22)
		if _rng.randf() < 0.3:
			game.fx.tracer(b, b + Vector3(_rng.randf_range(-4, 4), -_rng.randf_range(1, 3), _rng.randf_range(-4, 4)), col * 2.0, 0.15)
		at = b
		y = ny
	game.fx._flash(p + Vector3(0, top - ground + 1.0, 0), col, 8.0, 30.0)
	_flash = 1.0
	RenderingServer.global_shader_parameter_set("zone_flash_pos", p)
	if game.player and World.dist(p, game.player.position) < 90.0:
		game.sfx.play("thunder", p)


func to_dict() -> Dictionary:
	return {"blocks": blocks, "x": center.x, "z": center.z, "rects": rects.map(func(r): return [r.x, r.y, int(rect_n.get(r, patch_n()))])}


func from_dict(d: Dictionary) -> void:
	blocks = clampi(int(d.get("blocks", blocks)), 1, max_blocks())
	center = Vector3(float(d.get("x", center.x)), 0.0, float(d.get("z", center.z)))
	rects.clear()
	rect_n.clear()
	for r in d.get("rects", []):
		if r is Array and r.size() >= 2:
			var rc := Vector2i(int(r[0]), int(r[1]))
			rects.append(rc)
			rect_n[rc] = int(r[2]) if r.size() >= 3 else 5   # до 1.3 участки были 5×5
	rebuild()
