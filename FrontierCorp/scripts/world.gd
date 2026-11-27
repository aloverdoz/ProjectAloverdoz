class_name World
extends Node3D
## Открытый мир: слои земли (трава, грунт, песок, камень, снег), вода (озёра и реки),
## ресурсы (деревья, кусты, камни, руда), месторождения для буров, гнёзда монстров.
## Всё это можно рисовать в редакторе карты и сохранять в мод.

const C := 2.0
const CHUNK := 48   # чанк отрисовки ресурсов (клеток)

var game
var ocean := false
var island_cells := {}
const ISLAND_CHUNK := 32
var islands_by_chunk := {}
var ground_chunks := {}
var changed_chunks := {}
var chart_tiles := {}
var island_mesh: BoxMesh
var chart_origin := Vector2i.ZERO
var W := 384
static var wrap_w := 0   # >0: мир зациклен (края склеены), размер в клетках
var wrap := false
var used_seed := 0
var rng := RandomNumberGenerator.new()
var center := Vector2i(192, 192)

# слои
var splat: Image        # R грунт, G песок, B камень, A снег (трава — где всё по нулям)
var water: Image        # R > 0.5 = вода
var height: Image       # высота земли в метрах в центре клетки (рельеф)
var height_tex: ImageTexture
var ore_img: Image      # цвет пятна руды
var occ_img: Image      # занятые клетки (для травы)
var splat_tex: ImageTexture
var water_tex: ImageTexture
var ore_tex: ImageTexture
var yard_img: Image
var yard_tex: ImageTexture
var occ_tex: ImageTexture
var dirty := {}

# объекты
class Node_:
	var res := ""
	var cell := Vector2i.ZERO
	var hp := 1.0
	var maxhp := 1.0
	var xf := Transform3D()
	var chunk := Vector2i.ZERO

var nodes := {}          # Vector2i -> Node_
var deposit := {}        # Vector2i -> индекс в deposits
## 1.3: месторождение под бур — размером с сам бур (бур 2×2 встаёт ровно на залежь 2×2, а не одной ножкой).
## Сохранения до 1.3 — по-старому (false), чтобы залежи под уже стоящими бурами не сдвинулись.
static var dep_fit := true
var pending_strikes := {}
var ordered_fields := {}  # Origin cell -> footprint and quality
var order_price := 1000
var orders_placed := 0
var deposits: Array = [] # [{item, color, resource}]
var dep_override := {}   # 21: клетка -> что добывается (квантовая жила после наблюдения)
var dep_marks := {}      # Vector2i -> Node3D: знак месторождения (кристаллы руды вокруг клетки под бур)
var dep_mined := {}      # Vector2i -> сколько «наковыряно» руками до следующей штуки
var renderers := {}      # "res|chunk" -> PartRenderer
var respawns: Array = [] # [{res, cell, t}]
var nests: Array = []
var nest_cells := {}

var ground_mat: ShaderMaterial
var ground_node: MeshInstance3D
var water_node: MeshInstance3D
var water_mat: ShaderMaterial
var grass: MultiMeshInstance3D
var grass_mat: ShaderMaterial


func setup_size(size: int, wrap_override = null) -> void:
	W = size
	wrap = bool(DB.data.world.get("wrap", true)) if wrap_override == null else bool(wrap_override)
	wrap_w = W if wrap else 0
	center = Vector2i(W / 2, W / 2)
	splat = Image.create(W, W, false, Image.FORMAT_RGBA8)
	water = Image.create(W, W, false, Image.FORMAT_R8)
	ore_img = Image.create(W, W, false, Image.FORMAT_RGBA8)
	yard_img = Image.create(W, W, false, Image.FORMAT_R8)
	occ_img = Image.create(W, W, false, Image.FORMAT_R8)
	height = Image.create(W, W, false, Image.FORMAT_RH)


# ---------------------------------------------------------------- генерация

const BIG := 768          # больше этого: шум, холмы и слои земли считаются на сетке BIG и растягиваются
const LAZY_FROM := 512   # больше этого: флора и украшения появляются кусками по мере приближения
var lazy := false
var flora_cfg := {}      # всё, что нужно, чтобы вырастить флору в новом куске (сохраняется в карту)
var chunks_done := {}    # кусок -> флора выращена
var decor_done := {}     # кусок -> украшения расставлены
var _stream_settled := false
var _grow_queue: Array = []
var _flora_noise: FastNoiseLite
var _gen_f := 1.0        # клеток полной карты на клетку сетки генерации
var _water_small: Image  # вода на сетке генерации (для рельефа)


var gen_args := {}       # с какими настройками построена карта (большие карты сохраняются без картинок)
var edited := false      # карту правили кистями — сохранять целиком

func generate_island(seed_value: int, size: int) -> void:
	used_seed = seed_value
	rng.seed = seed_value
	setup_size(128, false)
	water.fill(Color.WHITE)
	height.fill(Color(.76, 0, 0))
	deposits = DB.data.world.get("deposits", []).duplicate(true)
	for x in range(-2, 3):
		for z in range(-2, 3):
			set_land(center + Vector2i(x, z), true)
	var oak := center + Vector2i(-2,-1)
	add_node("tree_oak",oak,Transform3D(Basis(Vector3.UP,.45).scaled(Vector3.ONE*.74),cell_to_world(oak)))
	add_node("tree_pine", center + Vector2i(1, -1))
	_build_visuals()

func island_chunk(c: Vector2i) -> Vector2i:
	return Vector2i(c.x >> 5, c.y >> 5)

func set_land(c: Vector2i, on: bool) -> void:
	var key := island_chunk(c)
	if on:
		if not islands_by_chunk.has(key): islands_by_chunk[key] = {}
		islands_by_chunk[key][c] = true
		island_cells[c] = true
	else:
		if islands_by_chunk.has(key):
			islands_by_chunk[key].erase(c)
			if islands_by_chunk[key].is_empty(): islands_by_chunk.erase(key)
		island_cells.erase(c)
	changed_chunks[key] = true
	var pixel := c - chart_origin
	if Rect2i(0,0,W,W).has_point(pixel):
		water.set_pixelv(pixel,Color.BLACK if on else Color.WHITE)
		dirty["water"] = true

# Meshes and chart stamps are allocated only for occupied 32×32 chunks.
func rebuild_shore() -> void:
	for key in changed_chunks:
		var cells: Dictionary = islands_by_chunk.get(key,{})
		var node: MultiMeshInstance3D = ground_chunks.get(key)
		if cells.is_empty():
			if node: node.queue_free()
			ground_chunks.erase(key)
			chart_tiles.erase(key)
			continue
		var origin: Vector2i = key * ISLAND_CHUNK
		if node == null:
			node = MultiMeshInstance3D.new()
			node.multimesh = MultiMesh.new()
			node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
			node.multimesh.mesh = island_mesh
			node.position = Vector3(origin.x*C,0,origin.y*C)
			add_child(node)
			ground_chunks[key] = node
		node.multimesh.instance_count = cells.size()
		var stamp := Image.create(ISLAND_CHUNK,ISLAND_CHUNK,false,Image.FORMAT_RGBA8)
		var i := 0
		for c in cells:
			var local: Vector2i = c-origin
			node.multimesh.set_instance_transform(i,Transform3D(Basis(),cell_to_world(local)+Vector3.UP*.26))
			stamp.set_pixelv(local,Color("#748b60"))
			i += 1
		chart_tiles[key] = ImageTexture.create_from_image(stamp)
	changed_chunks.clear()

# The small chart follows the player. It is a rendering cache, never a world boundary.
func center_chart(focus: Vector3) -> void:
	var c := world_to_cell(focus)
	if Rect2i(chart_origin+Vector2i(W/4,W/4),Vector2i(W/2,W/2)).has_point(c): return
	chart_origin = island_chunk(c)*ISLAND_CHUNK - Vector2i(W/2,W/2)
	water.fill(Color.WHITE)
	ore_img.fill(Color.TRANSPARENT)
	occ_img.fill(Color.BLACK)
	var area := Rect2i(chart_origin,Vector2i(W,W))
	var start := island_chunk(area.position)
	var end := island_chunk(area.end)
	for x in range(start.x,end.x+1):
		for z in range(start.y,end.y+1):
			for land in islands_by_chunk.get(Vector2i(x,z),{}):
				if area.has_point(land):
					water.set_pixelv(land-chart_origin,Color.BLACK)
					_occ(land)
					if deposit.has(land) and not deposit_hidden(deposit[land]):
						ore_img.set_pixelv(land-chart_origin,DB.color(deposits[deposit[land]].color))
	dirty.merge({"water":true,"ore":true,"occ":true},true)
	water_mat.set_shader_parameter("chart_origin",Vector2(chart_origin)*C)

func paint_ore_pixel(c: Vector2i, color: Color) -> void:
	var at := c-chart_origin if ocean else wc(c)
	if not ocean or Rect2i(0,0,W,W).has_point(at): ore_img.set_pixelv(at,color)

# (wave vector X/Z, angular speed, amplitude) drives both the mesh and buoyancy.
const SWELLS := [Vector4(.48,.24,-1.15,.18),Vector4(-.38,.73,-1.53,.095),Vector4(.98,-.65,1.98,.042)]
func ocean_surface(p: Vector3,t: float) -> Vector3:
	var sample := Vector3(.12,0.,0.)
	for wave in SWELLS:
		var phase: float = p.x*wave.x+p.z*wave.y+t*wave.z
		var gradient: float = cos(phase)*wave.w
		sample += Vector3(sin(phase)*wave.w,gradient*wave.x,gradient*wave.y)
	return sample

func _island_visuals() -> void:
	splat_tex = ImageTexture.create_from_image(splat)
	ore_tex = ImageTexture.create_from_image(ore_img)
	occ_tex = ImageTexture.create_from_image(occ_img)
	height_tex = ImageTexture.create_from_image(height)
	water_tex = ImageTexture.create_from_image(water)
	_make_water()
	water_mat.shader = preload("res://shaders/island_ocean.gdshader")
	water_mat.set_shader_parameter("water", water_tex)
	water_mat.set_shader_parameter("world_size", W * C)
	var surface := PlaneMesh.new()
	surface.size = Vector2(2,2)
	surface.subdivide_width = 111
	surface.subdivide_depth = 111
	water_node.mesh = surface
	water_node.custom_aabb = AABB(Vector3(-1940,-2,-1940),Vector3(3880,4,3880))
	for i in SWELLS.size():
		water_mat.set_shader_parameter(["swell_a","swell_b","swell_c"][i],SWELLS[i])
	var rock := ShaderMaterial.new()
	rock.shader = preload("res://shaders/island_rock.gdshader")
	rock.set_shader_parameter("stone", preload("res://textures/frontier/slate.jpg"))
	rock.set_shader_parameter("soil", preload("res://textures/frontier/moss.jpg"))
	island_mesh = BoxMesh.new()
	island_mesh.size = Vector3(C,1.,C)
	island_mesh.material = rock
	rebuild_shore()

func generate(seed_value: int, override := {}, regen := false) -> void:
	var wd: Dictionary = DB.data.world
	if not override.is_empty():
		wd = wd.duplicate()
		wd.merge(override, true)
	if int(wd.get("seed", 0)) != 0:
		seed_value = int(wd.seed)
	# Old seed-only saves keep their original landing terrain.
	if regen and not override.has("landing_canyon"):
		wd = wd.duplicate()
		wd["landing_canyon"] = 0
	gen_args = {"seed": seed_value, "wd": wd.duplicate(true)}
	edited = false
	rng.seed = seed_value
	used_seed = seed_value
	setup_size(int(wd.get("size", 384)), wd.get("wrap", true))
	lazy = W > LAZY_FROM
	# большая карта: шум, холмы и слои земли считаются на сетке не больше BIG и растягиваются
	var area := maxf(1.0, float(W) * W / (BIG * BIG))
	var G := mini(W, BIG)
	_gen_f = float(W) / G
	_water_small = Image.create(G, G, false, Image.FORMAT_R8) if G < W else water
	var bs := float(wd.get("biome_scale", 1.0))
	var n2 := _noise(0.03 / bs)
	var n3 := _noise(0.08 / bs)
	var n4 := _noise(0.012 / bs)
	forest_t = 0.5 - 0.64 * float(wd.get("forest", 0.5))
	var dry_t := 0.7 - 0.7 * float(wd.get("dry", 0.5))
	var rock_t := 0.9 - 0.9 * float(wd.get("rocky", 0.5))
	var snow_t := 0.9 - 0.9 * float(wd.get("snow", 0.0))
	# вода: озёра и реки (на большой карте их больше)
	var clear := int(wd.get("start_clear_radius", 7)) + 10
	var ls: Array = wd.get("lake_size", [4, 11])
	for i in int(int(wd.get("lakes", 8)) * area):
		var c := Vector2i(rng.randi_range(20, W - 20), rng.randi_range(20, W - 20))
		if c.distance_to(center) < clear + 12:
			continue
		_blob_water(c, rng.randf_range(float(ls[0]), float(ls[1])))
	var rw: Array = wd.get("river_width", [1.2, 2.2])
	for i in int(int(wd.get("rivers", 3)) * sqrt(area)):
		_river(rng.randf_range(float(rw[0]), float(rw[1])))
	# слои земли по шуму
	var sm := Image.create(G, G, false, Image.FORMAT_RGBA8) if G < W else splat
	for gx in G:
		for gz in G:
			var x := gx * _gen_f
			var z := gz * _gen_f
			var dry := _nz(n2, x, z)
			var rocky := _nz(n3, x, z, 0.5)
			var cold := _nz(n4, x, z)
			var col := Color(0, 0, 0, 0)
			if dry > dry_t:
				col.r = clampf((dry - dry_t) * 2.5, 0, 0.9)
			if rocky > rock_t:
				col.b = clampf((rocky - rock_t) * 3.0, 0, 1)
			if cold > snow_t:
				col.a = clampf((cold - snow_t) * 3.0, 0, 1)
			sm.set_pixel(gx, gz, col)
	_make_relief(wd, sm, G)
	if G < W:
		sm.resize(W, W, Image.INTERPOLATE_BILINEAR)
		splat = sm
	if wd.get("sand_beaches", true) and not lazy:
		_beaches()
	if int(wd.get("landing_canyon", 0)) > 0 and W >= 64:
		_cut_landing_canyon()
	# месторождения
	deposits = []
	dep_override.clear()
	for d in wd.get("deposits", []):
		var idx := deposits.size()
		deposits.append(d)
		if wd.get("orbital_fields", false):
			continue
		var near := int(d.get("near_start", 0))
		var fp := dep_fp(d)   # 13.10: месторождение ровно под один бур (1 — клетка, 2 — 2×2); 0 — старое пятно
		# стартовые залежи — внутри открытой зоны (без зоны — в 11–20 клетках от центра)
		var zr := _start_zone_cells()
		var rk := clampf(float(wd.get("res_k", 1.0)), 0.1, 10.0)
		var ring0 := int(d.get("near_ring", 0))
		# стартовые и «за бурей» залежи — всегда (без них не начать), остальное — по «Ресурсы: мало / обычно / много»
		for k in maxi(near + ring0, int(int(d.get("patches", 10)) * area * rk)):
			var c: Vector2i
			var ring := int(d.get("near_ring", 0))   # 15.5: столько залежей сразу за стартовой зоной — в паре открытий тумана
			if k < near:
				var a := rng.randf() * TAU
				var r := rng.randf_range(7, maxf(8.0, zr - 3.0 - fp)) if zr > 0.0 else rng.randf_range(11, 20)
				c = center + Vector2i(roundi(cos(a) * r), roundi(sin(a) * r))
				if fp > 0 and (water_at(c) or deposit.has(c)):
					c += Vector2i(rng.randi_range(-3, 3), rng.randi_range(-3, 3))
			elif k < near + ring:
				var a2 := rng.randf() * TAU
				var base := maxf(zr, 20.0)
				var r2 := rng.randf_range(base + 2.0, base + float(d.get("ring_width", 12.0)))
				c = center + Vector2i(roundi(cos(a2) * r2), roundi(sin(a2) * r2))
				if fp > 0 and (water_at(c) or deposit.has(c)):
					c += Vector2i(rng.randi_range(-3, 3), rng.randi_range(-3, 3))
			else:
				c = Vector2i(rng.randi_range(8, W - 8), rng.randi_range(8, W - 8))
				if c.distance_to(center) < maxf(26.0, zr + 4.0):
					continue
			if fp > 0:
				_footprint(idx, c, fp, k < near)
				if k < near:
					# 1.5: стартовая залежь гарантирована — у воды или впритык к другой не встала, ищем другое место в зоне
					var tries0 := 0
					while not deposit.has(wc(c)) and tries0 < 60:
						tries0 += 1
						var a4 := rng.randf() * TAU
						var r4 := rng.randf_range(6.0, maxf(8.0, zr - 2.0 - fp)) if zr > 0.0 else rng.randf_range(10, 22)
						c = center + Vector2i(roundi(cos(a4) * r4), roundi(sin(a4) * r4))
						_footprint(idx, c, fp, true)
				if k >= near and k < near + ring:
					# у воды или впритык к другой залежи не встало — пробуем ещё (кольцо должно быть гарантировано)
					var tries := 0
					while not deposit.has(wc(c)) and tries < 12:
						tries += 1
						var a3 := rng.randf() * TAU
						var r3 := rng.randf_range(maxf(zr, 20.0) + 2.0, maxf(zr, 20.0) + float(d.get("ring_width", 12.0)))
						c = center + Vector2i(roundi(cos(a3) * r3), roundi(sin(a3) * r3))
						_footprint(idx, c, fp, false)
			else:
				_patch(idx, c, rng.randf_range(float(d.get("size_min", 2.5)), float(d.get("size_max", 5))))
	_start_set(wd)
	var nd: Dictionary = wd.get("nests", {}).duplicate()
	if area > 1.0:
		nd["count"] = int(int(nd.get("count", 7)) * sqrt(area))
		nd["max_dist"] = float(nd.get("max_dist", 150)) * sqrt(area)
	_make_nests(nd)
	# флора: по кускам (на маленькой карте — сразу вся)
	flora_cfg = {"seed": used_seed, "forest_t": forest_t, "bs": bs, "clear": clear, "flora": wd.get("flora", []),
		"chance": float(wd.get("deposit_rock_chance", 0.25))}
	_setup_flora()
	if regen:
		return
	_start_gatherables(wd.get("start_gatherables", {}), clear)
	_landing_groves()
	if not lazy:
		for cx in ceili(float(W) / CHUNK):
			for cz in ceili(float(W) / CHUNK):
				grow_chunk(Vector2i(cx, cz))
	else:
		_grow_around(cell_to_world(center), true)
	_last_focus = cell_to_world(center)
	_build_visuals()


## 1.7: у штаба есть залежи каждого вида: открытые с начала — по 2 в стартовой зоне,
## открываемые позже (Химия: сера и селитра…) — по 1–2 сразу за ней; видны, когда узел изучен.
## Свой генератор случайных чисел: остальные залежи и гнёзда старых миров не сдвигаются.
func _start_set(wd: Dictionary) -> void:
	if not bool(wd.get("start_set", true)):
		return
	var r := RandomNumberGenerator.new()
	r.seed = hash([used_seed, "start17"])
	var zr := _start_zone_cells()
	var inner: float = zr if zr > 0.0 else 20.0
	var band := float(wd.get("start_set_band", 16.0))
	var later_items := {}
	for tid in DB.data.get("tech", {}):
		for it in DB.data.tech[tid].get("unlocks", {}).get("deposits", []):
			later_items[str(it)] = true
	# сколько залежей каждого вида уже есть рядом (клетки → штуки)
	var cnt_in := {}
	var cnt_out := {}
	for c in deposit:
		var dv := World.delta(cell_to_world(center), cell_to_world(c))
		var dist: float = Vector2(dv.x, dv.z).length() / C
		if dist < inner:
			cnt_in[deposit[c]] = int(cnt_in.get(deposit[c], 0)) + 1
		elif dist < inner + band + 4.0:
			cnt_out[deposit[c]] = int(cnt_out.get(deposit[c], 0)) + 1
	for idx in deposits.size():
		var d: Dictionary = deposits[idx]
		var fp := dep_fp(d)
		if fp <= 0 or int(d.get("patches", 0)) <= 0:
			continue
		var later: bool = later_items.has(str(d.get("item", "")))
		var want := 2 if not later else 1 + r.randi() % 2
		if wd.has("start_one"):
			want = int(wd.start_one)   # 1.1.18: у штаба по одной залежи; закрытые — по одной сразу за зоной
		if wd.has("start_base"):
			# 1.1.19: у штаба — только базовые (железо, медь, камень), каждой остальной — по start_ring сразу за зоной,
			# чтобы развитие не упёрлось в «нужной руды нигде нет»
			later = not str(d.get("item", "")) in wd.start_base
			if later:
				want = int(wd.get("start_ring", 2))
		if wd.get("orbital_fields", false):
			want = 1 if str(d.get("item", "")) in wd.get("start_base", ["iron_ore", "copper_ore", "stone"]) else 0
			later = false
		var have := int(ceil(float((cnt_in if not later else cnt_out).get(idx, 0)) / float(fp * fp)))
		var tries := 0
		while have < want and tries < 120:
			tries += 1
			var a := r.randf() * TAU
			var rr: float = r.randf_range(7.0, maxf(8.0, inner - 2.0 - fp)) if not later else r.randf_range(inner + 2.0, inner + band)
			var c := wc(center + Vector2i(roundi(cos(a) * rr), roundi(sin(a) * rr)))
			if have == 0 and tries == 1 and wd.get("orbital_fields",false) and int(wd.get("landing_canyon",0)) > 0:
				var sites := {"iron_ore":Vector2i(-6,4),"copper_ore":Vector2i(3,-7),"stone":Vector2i(7,4)}
				if sites.has(str(d.get("item",""))):
					c = wc(center + sites[str(d.item)])
			if deposit.has(c):
				continue
			_footprint(idx, c, fp, true)
			if deposit.get(c, -1) == idx:
				have += 1


func _setup_flora() -> void:
	_flora_noise = FastNoiseLite.new()
	_flora_noise.seed = int(flora_cfg.get("seed", used_seed)) + 101
	_flora_noise.frequency = 0.018 / float(flora_cfg.get("bs", 1.0))
	forest_t = float(flora_cfg.get("forest_t", forest_t))


## Вырастить флору (деревья, кусты, камни на рудах) в куске карты. Каждый кусок — один раз и всегда одинаково.
const BIOME_NAMES := {"sand": "Бирюзовое побережье", "snow": "Северные уступы", "dry": "Янтарный каньон", "crystal_field": "Стеклянное плато", "spore": "Леса спор", "forest": "Рощи колоссов", "meadow": "Пойменные луга"}

func biome_at(c: Vector2i) -> String:
	c = wc(c)
	if not in_bounds(c) or splat == null or _flora_noise == null:
		return "meadow"
	var s := splat.get_pixelv(c)
	if s.g > 0.37 or water_at(c):
		return "sand"
	if s.a > 0.43:
		return "snow"
	var humidity := _nz(_flora_noise, c.x, c.y)
	if s.r > 0.32 and humidity < 0.12:
		return "dry"
	if s.b > 0.32 or (h_cell(c) > 7.0 and humidity < 0.055):
		return "crystal_field"
	if humidity > forest_t + 0.22 and s.r < 0.26:
		return "spore"
	if humidity > forest_t - 0.05:
		return "forest"
	return "meadow"


func grow_chunk(cc: Vector2i) -> void:
	var nch := ceili(float(W) / CHUNK)
	if wrap_w > 0:
		cc = Vector2i(posmod(cc.x, nch), posmod(cc.y, nch))
	elif cc.x < 0 or cc.y < 0 or cc.x >= nch or cc.y >= nch:
		return
	if chunks_done.has(cc):
		return
	chunks_done[cc] = true
	if _flora_noise == null:
		_setup_flora()
	var r := RandomNumberGenerator.new()
	r.seed = hash([int(flora_cfg.get("seed", used_seed)), cc.x, cc.y])
	var flora: Array = flora_cfg.get("flora", [])
	var clear := float(flora_cfg.get("clear", 17))
	var chance := float(flora_cfg.get("chance", 0.25))
	for x in range(cc.x * CHUNK, mini(W, cc.x * CHUNK + CHUNK)):
		for z in range(cc.y * CHUNK, mini(W, cc.y * CHUNK + CHUNK)):
			var c := Vector2i(x, z)
			if deposit.has(c):
				var dd: Dictionary = deposits[deposit[c]]
				var dres := str(dd.get("resource", ""))
				if int(dd.get("cells", 0)) > 0:
					# залежь под бур остаётся свободной; рудные камни лежат вокруг неё
					if dres != "" and not deposit_hidden(deposit[c]) and dep_marks.has(c):
						for k in int(dd.get("rocks_around", 2)):
							var a := r.randf() * TAU
							var rr := r.randf_range(2.0, 4.5)
							var rc := wc(c + Vector2i(roundi(cos(a) * rr), roundi(sin(a) * rr)))
							if not deposit.has(rc) and not nodes.has(rc) and not water_at(rc) and not nest_cells.has(rc) \
									and not (game != null and game.factory != null and game.factory.grid.has(rc)) and rc.distance_to(center) > 5.0 \
									and _rock_ok(rc, int(DB.setting("ore_rock_gap", 4))):
								add_node(dres, rc)
					continue
				if dres != "" and not deposit_hidden(deposit[c]) and r.randf() < chance and not water_at(c) and not nodes.has(c):
					add_node(dres, c)
				continue
			if water_at(c) or nest_cells.has(c) or nodes.has(c):
				continue
			if game != null and game.factory != null and (game.factory.grid.has(c) or game.factory.found.has(c)):
				continue
			var dc := c.distance_to(center)
			if dc < clear:
				continue
			var zone := biome_at(c)
			for fl in flora:
				var z2: String = fl.get("zone", "any")
				var ok := z2 == "any" or z2 == zone or (z2 == "far" and dc > minf(W * 0.33, 260.0))
				if ok and r.randf() < float(fl.get("density", 0.01)):
					var fres := str(fl.get("resource", ""))
					# 1.3: камни не кучами — рядом не больше одного-двух, и не впритык к месторождениям
					if _is_rock(fres) and not _rock_ok(c, int(DB.setting("rock_gap", 2))):
						break
					add_node(fres, c)
					break


## 1.3: камень или рудный камень (не растение): после добычи не вырастает снова.
static func _is_rock(res: String) -> bool:
	return str(DB.data.resources.get(res, {}).get("category", "")) in ["Камни", "Руда"]


## 1.3: можно ли положить камень в клетку c: рядом (в квадрате ±1) нет месторождений,
## а в квадрате ±gap не больше одного другого камня — так камни лежат по 1–2, а не россыпью.
func _rock_ok(c: Vector2i, gap: int) -> bool:
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			if deposit.has(wc(c + Vector2i(dx, dz))):
				return false
	var near := 0
	for dx in range(-gap, gap + 1):
		for dz in range(-gap, gap + 1):
			var n: Node_ = nodes.get(wc(c + Vector2i(dx, dz)))
			if n != null and _is_rock(n.res):
				near += 1
				if near >= 2:
					return false
	return true


## Большая карта: флора и украшения появляются кусками вокруг героя (или камеры редактора).
func _grow_around(focus: Vector3, now := false) -> void:
	var fc := Vector2i(floori(focus.x / C / CHUNK), floori(focus.z / C / CHUNK))
	_stream_settled = false
	var R := 3
	for dx in range(-R, R + 1):
		for dz in range(-R, R + 1):
			var cc := fc + Vector2i(dx, dz)
			if now:
				grow_chunk(cc)
			elif not chunks_done.has(_norm_chunk(cc)) and not _grow_queue.has(cc):
				_grow_queue.append(cc)
	# украшения — только когда вокруг куска уже выросла флора
	if _visuals_built:
		for dx in range(-R + 1, R):
			for dz in range(-R + 1, R):
				var cc := _norm_chunk(fc + Vector2i(dx, dz))
				if decor_done.has(cc):
					continue
				var ready := true
				for ox in range(-1, 2):
					for oz in range(-1, 2):
						if not chunks_done.has(_norm_chunk(cc + Vector2i(ox, oz))) and _chunk_ok(cc + Vector2i(ox, oz)):
							ready = false
				if ready:
					_decor_chunk(cc)
					if not now:
						return
	_stream_settled = _grow_queue.is_empty()


func _chunk_ok(cc: Vector2i) -> bool:
	if wrap_w > 0:
		return true
	var nch := ceili(float(W) / CHUNK)
	return cc.x >= 0 and cc.y >= 0 and cc.x < nch and cc.y < nch


func _norm_chunk(cc: Vector2i) -> Vector2i:
	if wrap_w > 0:
		var nch := ceili(float(W) / CHUNK)
		return Vector2i(posmod(cc.x, nch), posmod(cc.y, nch))
	return cc


var forest_t := 0.18


# ---------------------------------------------------------------- рельеф

## Холмы и низины. У воды, у штаба и у края карты земля плавно уходит в ровное место.
func _make_relief(wd: Dictionary, sm: Image, G: int) -> void:
	height.fill(Color(0, 0, 0))
	var amp := float(wd.get("relief", 5.0))
	if amp <= 0.0:
		return
	var f := _gen_f
	var bs := maxf(0.1, float(wd.get("relief_scale", 1.0)))
	var hills := clampf(float(wd.get("hills", 0.4)), 0.0, 1.0)
	var flat_r := float(wd.get("start_flat_radius", 22)) / f
	var shore := maxf(1.5, float(wd.get("shore_flat", 6)) / f)
	var n1 := _noise(0.026 / bs)
	var n2 := _noise(0.08 / bs)
	var t0 := 0.3 - 0.6 * hills
	var hs := Image.create(G, G, false, Image.FORMAT_RH) if G < W else height
	var gc := Vector2(center) / f
	# расстояние до воды (в клетках сетки, до shore + 1)
	var lim := int(shore) + 1
	var dist := PackedByteArray()
	dist.resize(G * G)
	dist.fill(lim)
	var q: Array[Vector2i] = []
	for x in G:
		for z in G:
			if _water_small.get_pixel(x, z).r > 0.5:
				dist[z * G + x] = 0
				q.append(Vector2i(x, z))
	var qi := 0
	while qi < q.size():
		var c: Vector2i = q[qi]
		qi += 1
		var d0: int = dist[c.y * G + c.x]
		if d0 + 1 >= lim:
			continue
		for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + dd
			if wrap_w > 0:
				n = Vector2i(posmod(n.x, G), posmod(n.y, G))
			elif n.x < 0 or n.y < 0 or n.x >= G or n.y >= G:
				continue
			if dist[n.y * G + n.x] > d0 + 1:
				dist[n.y * G + n.x] = d0 + 1
				q.append(n)
	var canyon_relief := int(wd.get("landing_canyon", 0)) > 0
	var rocky := bool(wd.get("rocky_slopes", true))
	var edge := 10.0 / f
	for x in G:
		for z in G:
			var v := _nz(n1, x * f, z * f) + 0.3 * _nz(n2, x * f, z * f)
			var h := amp * smoothstep(t0, t0 + 0.5, v)
			var palette := sm.get_pixel(x,z)
			if palette.r > .25:
				h += amp * palette.r * smoothstep(.04,.26,absf(v+.05)) * 0.95
			if palette.b > .30 or palette.a > .4:
				h += amp * maxf(palette.b,palette.a) * smoothstep(-.18,.24,v) * 1.2
			if canyon_relief and palette.b > .29:
				var spine := smoothstep(-.20,.36,v) * smoothstep(.29,.81,palette.b)
				var strata := (h + amp*(1.6+1.2*absf(v))*spine)
				h = lerpf(strata,snappedf(strata,1.28),spine*.72)
			if h <= 0.0:
				continue
			h *= smoothstep(1.0, shore, float(dist[z * G + x]))
			h *= smoothstep(flat_r, flat_r + 14.0 / f, Vector2(x, z).distance_to(gc))
			if wrap_w <= 0:
				h *= smoothstep(edge * 0.2, edge, float(mini(mini(x, z), mini(G - 1 - x, G - 1 - z))))
			hs.set_pixel(x, z, Color(snappedf(h, 0.01), 0, 0))
	if int(wd.get("landing_canyon",0)) >= 3:
		_weather_ridges(hs,G,f,amp)
	if rocky:
		for x in range(1, G - 1):
			for z in range(1, G - 1):
				var h0 := hs.get_pixel(x, z).r
				var sl := maxf(absf(hs.get_pixel(x + 1, z).r - h0), absf(hs.get_pixel(x, z + 1).r - h0)) / f
				if sl > 0.8:
					var col := sm.get_pixel(x, z)
					col.b = maxf(col.b, clampf((sl - 0.8) * 1.5, 0.0, 0.9))
					sm.set_pixel(x, z, col)
	if G < W:
		hs.resize(W, W, Image.INTERPOLATE_BILINEAR)
		height = hs


# Keep rolling ridgelines wide. Two directional sweeps constrain unsupported
# escarpments around rivers and narrow islands before the landing canyon is cut.
func _weather_ridges(hs: Image, side: int, spacing: float, relief: float) -> void:
	var broad := hs.duplicate() as Image
	var radius := maxi(3,roundi(14.0/spacing))
	broad.resize(maxi(2,side/radius),maxi(2,side/radius),Image.INTERPOLATE_TRILINEAR)
	broad.resize(side,side,Image.INTERPOLATE_BILINEAR)
	var surface := PackedFloat32Array()
	surface.resize(side*side)
	var span := maxf(1.0,relief*1.25)
	var step_h := C*spacing*.94
	var diag := step_h*sqrt(2.0)
	for z in side:
		for x in side:
			var i := z*side+x
			var smooth_h := broad.get_pixel(x,z).r
			var raw := hs.get_pixel(x,z).r
			var h := minf(raw, smooth_h + 1.4)
			h = minf(raw,span*tanh(h/span))
			if x > 0:
				h = minf(h,surface[i-1]+step_h)
			if z > 0:
				h = minf(h,surface[i-side]+step_h)
				if x > 0:
					h = minf(h,surface[i-side-1]+diag)
				if x+1 < side:
					h = minf(h,surface[i-side+1]+diag)
			surface[i]=h
	for z in range(side-1,-1,-1):
		for x in range(side-1,-1,-1):
			var i := z*side+x
			var h := surface[i]
			if x+1 < side:
				h = minf(h,surface[i+1]+step_h)
			if z+1 < side:
				h = minf(h,surface[i+side]+step_h)
				if x > 0:
					h = minf(h,surface[i+side-1]+diag)
				if x+1 < side:
					h = minf(h,surface[i+side+1]+diag)
			surface[i]=h
			hs.set_pixel(x,z,Color(h,0,0))

## Высота земли в клетке (её центре).
func h_cell(c: Vector2i) -> float:
	if ocean: return .76
	if not in_bounds(c) or height == null:
		return 0.0
	return height.get_pixelv(wc(c)).r


## Высота земли в любой точке (плавно между центрами клеток — так же, как рисует видеокарта).
func height_at(p: Vector3) -> float:
	if ocean: return .76
	if height == null:
		return 0.0
	var fx := p.x / C - 0.5
	var fz := p.z / C - 0.5
	var x0 := floori(fx)
	var z0 := floori(fz)
	var tx := fx - x0
	var tz := fz - z0
	var a := h_cell(Vector2i(x0, z0))
	var b := h_cell(Vector2i(x0 + 1, z0))
	var c := h_cell(Vector2i(x0, z0 + 1))
	var d := h_cell(Vector2i(x0 + 1, z0 + 1))
	if tx + tz <= 1.0:
		return a + (b-a)*tx + (c-a)*tz
	return d + (c-d)*(1.0-tx) + (b-d)*(1.0-tz)


## Самая низкая и самая высокая точка земли под клетками (углы и центры).
func ground_range(cells: Array) -> Vector2:
	var lo := INF
	var hi := -INF
	for c in cells:
		var o := Vector3(c.x * C, 0, c.y * C)
		for off in [Vector3(0, 0, 0), Vector3(C, 0, 0), Vector3(0, 0, C), Vector3(C, 0, C), Vector3(C * 0.5, 0, C * 0.5)]:
			var h := height_at(o + off)
			lo = minf(lo, h)
			hi = maxf(hi, h)
	return Vector2(lo, hi)


## Кисть рельефа в редакторе карты: поднять, опустить, выровнять (до высоты level), сгладить.
func paint_height(c: Vector2i, radius: float, mode: String, strength: float, level := 0.0) -> void:
	edited = true
	var ri := ceili(radius)
	var src := height.duplicate() if mode == "smooth" else null
	for dx in range(-ri, ri + 1):
		for dz in range(-ri, ri + 1):
			var p := c + Vector2i(dx, dz)
			if not in_bounds(p):
				continue
			var d := Vector2(dx, dz).length()
			if d > radius:
				continue
			var k := clampf(strength * (1.0 - d / (radius + 0.001)) * 1.6, 0.0, 1.0)
			var h := h_cell(p)
			match mode:
				"raise":
					h += k * 0.6
				"lower":
					h -= k * 0.6
				"flatten":
					h = lerpf(h, level, clampf(k * 1.5, 0.0, 1.0))
				"smooth":
					var sum := 0.0
					for ox in range(-1, 2):
						for oz in range(-1, 2):
							var q := p + Vector2i(ox, oz)
							sum += src.get_pixelv(wc(q)).r if in_bounds(q) else h
					h = lerpf(h, sum / 9.0, clampf(k * 1.5, 0.0, 1.0))
			height.set_pixelv(wc(p), Color(clampf(snappedf(h, 0.01), 0.0, 80.0), 0, 0))
	dirty["height"] = true
	reheight(c, ri + 1)


## После правки рельефа: деревья, камни, украшения и гнёзда встают на новую землю.
func reheight(c: Vector2i, ri: int) -> void:
	for dx in range(-ri, ri + 1):
		for dz in range(-ri, ri + 1):
			var p := wc(c + Vector2i(dx, dz))
			var n: Node_ = nodes.get(p)
			if n != null:
				if not seat_resource(n):
					remove_node(p)
					continue
				var r: PartRenderer = renderers.get("%s|%s" % [n.res, n.chunk])
				if r:
					r.set_xform(n, n.xf)
			for e in decor_cells.get(p, []):
				var mmi: MultiMeshInstance3D = decor_mm.get(e[0])
				if mmi:
					var xf := mmi.multimesh.get_instance_transform(e[1])
					xf.origin.y = height_at(xf.origin + mmi.position) - mmi.position.y
					mmi.multimesh.set_instance_transform(e[1], xf)
	for nst in nests:
		if is_instance_valid(nst.node):
			nst.node.position.y = height_at(nst.node.position)
			nst.pos = nst.node.position

## Шум с зацикленными краями, если мир зациклен.
func _noise(freq: float) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = rng.randi()
	n.frequency = freq
	return n


## Значение шума; в зацикленном мире — без шва на краях.
func _nz(n: FastNoiseLite, x: float, z: float, k := 1.0) -> float:
	if not wrap:
		return n.get_noise_2d(x * k, z * k)
	var fx := float(x) / W
	var fz := float(z) / W
	var a := n.get_noise_2d(x * k, z * k)
	var b := n.get_noise_2d((x - W) * k, z * k)
	var c := n.get_noise_2d(x * k, (z - W) * k)
	var d := n.get_noise_2d((x - W) * k, (z - W) * k)
	var v := lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fz)
	# смешивание приглушает контраст — немного возвращаем его
	return v * 1.6


func _set_water(p: Vector2i) -> void:
	p = wc(p)
	water.set_pixelv(p, Color(1, 0, 0))
	if _water_small != null and _water_small != water:
		var q := Vector2i(clampi(int(p.x / _gen_f), 0, _water_small.get_width() - 1), clampi(int(p.y / _gen_f), 0, _water_small.get_height() - 1))
		_water_small.set_pixelv(q, Color(1, 0, 0))


func _blob_water(c: Vector2i, r: float) -> void:
	var ri := ceili(r) + 2
	var ph := rng.randf() * TAU
	for dx in range(-ri, ri + 1):
		for dz in range(-ri, ri + 1):
			var p := c + Vector2i(dx, dz)
			if not in_bounds(p):
				continue
			var a := atan2(dz, dx)
			var rr := r * (0.8 + 0.2 * sin(a * 3.0 + ph) + 0.1 * sin(a * 5.0 + ph * 2.0))
			if Vector2(dx, dz).length() <= rr:
				_set_water(p)


func _river(width: float) -> void:
	var p := Vector2(rng.randf_range(0, W), 0 if rng.randf() < 0.5 else W - 1)
	if rng.randf() < 0.5:
		p = Vector2(p.y, p.x)
	var aim := Vector2(center) if not lazy else Vector2(rng.randf_range(0, W), rng.randf_range(0, W))
	var dir := (aim - p).normalized().rotated(rng.randf_range(-0.6, 0.6))
	for i in (int(W * 0.9) if wrap else W * 2):
		dir = dir.rotated(rng.randf_range(-0.15, 0.15))
		p += dir
		if Vector2(center).distance_to(p) < 30:
			dir = dir.rotated(0.4)
		var ci := Vector2i(p)
		if not in_bounds(ci):
			break
		var ri := ceili(width)
		for dx in range(-ri, ri + 1):
			for dz in range(-ri, ri + 1):
				if Vector2(dx, dz).length() <= width:
					var q := ci + Vector2i(dx, dz)
					if in_bounds(q):
						_set_water(q)


func _beaches() -> void:
	var src := water.duplicate()
	for x in W:
		for z in W:
			if src.get_pixel(x, z).r > 0.5:
				continue
			var near := false
			for dx in range(-2, 3):
				for dz in range(-2, 3):
					var q := Vector2i(x + dx, z + dz)
					if in_bounds(q) and src.get_pixelv(wc(q)).r > 0.5:
						near = true
			if near:
				var c := splat.get_pixel(x, z)
				c.g = 1.0
				splat.set_pixel(x, z, c)


## Половина стартовой зоны в клетках (0 — зона выключена).
func _start_zone_cells() -> float:
	var z = DB.data.settings.get("zone", {})
	if not (z is Dictionary) or not bool(z.get("enabled", true)) or (game != null and not game.module("zone")):
		return 0.0
	return float(z.get("start_blocks", 10)) * float(z.get("block_m", 8.0)) * 0.5 / C


## Месторождение под один бур: квадрат fp×fp клеток.
## Сколько клеток по стороне занимает залежь «под один бур» (0 — старое пятно).
## 1.3: под размер бура: обычная (1) — как бур, «двойная» для нефти, газа и магмы (2) — как насос.
func dep_fp(d: Dictionary) -> int:
	var fp := int(d.get("cells", 0))
	if fp <= 0 or not dep_fit:
		return fp
	var by := "oil_pump" if DB.is_fluid(str(d.get("item", ""))) else "miner"
	return maxi(fp, int(DB.building(by).get("size", fp)))


## Левый верхний угол залежи под бур, в которую входит клетка c (или c, если залежи нет).
func dep_corner(c: Vector2i) -> Vector2i:
	if not deposit.has(c):
		return c
	var idx: int = deposit[c]
	for i in 8:
		if deposit.get(wc(c - Vector2i(1, 0)), -1) == idx:
			c = wc(c - Vector2i(1, 0))
		elif deposit.get(wc(c - Vector2i(0, 1)), -1) == idx:
			c = wc(c - Vector2i(0, 1))
		else:
			break
	return c


func _footprint(idx: int, c: Vector2i, fp: int, near := false) -> void:
	if int(gen_args.get("wd",{}).get("landing_canyon",0)) > 0:
		var bounds := ground_range(field_cells(c,fp))
		if bounds.y-bounds.x > .40:
			return
	for dx in fp:
		for dz in fp:
			var p := c + Vector2i(dx, dz)
			if (wrap_w <= 0 and (p.x < 1 or p.y < 1 or p.x >= W - 1 or p.y >= W - 1)) or water_at(p):
				return
	# хотя бы клетка зазора до соседней залежи — чтобы два месторождения не сливались в одно большое
	# (1.3: две клетки — между двумя бурами остаётся проход под ленту, знаки руды не налезают друг на друга)
	var gap := 2 if dep_fit else 1
	for dx in range(-gap, fp + gap):
		for dz in range(-gap, fp + gap):
			if deposit.has(wc(c + Vector2i(dx, dz))):
				return
	var pu := _pick_purity(c, deposits[idx], near)
	for dx in fp:
		for dz in fp:
			set_deposit(c + Vector2i(dx, dz), idx)
			if not DB.is_fluid(str(deposits[idx].get("item", ""))):
				set_purity(c + Vector2i(dx, dz), pu)


func _patch(idx: int, c: Vector2i, r: float) -> void:
	var col := DB.color(deposits[idx].get("color", "#808080"))
	var ri := ceili(r) + 2
	var ph := rng.randf() * TAU
	for dx in range(-ri, ri + 1):
		for dz in range(-ri, ri + 1):
			var p := c + Vector2i(dx, dz)
			if (wrap_w <= 0 and (p.x < 1 or p.y < 1 or p.x >= W - 1 or p.y >= W - 1)) or water_at(p):
				continue
			var a := atan2(dz, dx)
			var rr := r * (0.8 + 0.25 * sin(a * 3.0 + ph))
			if Vector2(dx, dz).length() <= rr:
				set_deposit(p, idx, col)


# ---------------------------------------------------------------- 13.10: качество залежи
## «Настройки» → «Качество залежей»: бедная/нормальная/богатая/легендарная — сколько в минуту даёт бур Mk1.
var dep_purity := {}   # клетка -> id качества


func purity_levels() -> Array:
	var l = DB.data.settings.get("purity", [])
	return l if l is Array else []


func purity_def(id: String) -> Dictionary:
	for l in purity_levels():
		if l is Dictionary and str(l.get("id", "")) == id:
			return l
	return {}


## Качество залежи на клетке (пусто — у залежи нет качества: жидкость или качества выключены).
func purity_of(c: Vector2i) -> Dictionary:
	c = wc(c)
	if not deposit.has(c) or purity_levels().is_empty():
		return {}
	var d := purity_def(str(dep_purity.get(c, "")))
	if d.is_empty():
		d = purity_def(str(DB.data.settings.get("purity_start", "normal")).split(",")[0].strip_edges())
	return d


func set_purity(c: Vector2i, id: String) -> void:
	c = wc(c)
	if id == "":
		dep_purity.erase(c)
	else:
		dep_purity[c] = id


## Случайное качество по весам «Шанс» (одно и то же для этого места и зерна карты).
func _pick_purity(c: Vector2i, d: Dictionary, near: bool) -> String:
	if str(d.get("purity", "")) != "":
		return str(d.purity)
	# в стартовой зоне — только качества из «Качество стартовых залежей» (через запятую, по тем же шансам)
	var allow := []
	if near:
		for x in str(DB.data.settings.get("purity_start", "normal")).split(","):
			if x.strip_edges() != "":
				allow.append(x.strip_edges())
	var tot := 0.0
	for l in purity_levels():
		if allow.is_empty() or str(l.get("id", "")) in allow:
			tot += maxf(0.0, float(l.get("chance", 1.0)))
	if tot <= 0.0:
		return str(allow[0]) if not allow.is_empty() else ""
	var h := float(abs(hash(Vector3i(c.x, c.y, used_seed))) % 100000) / 100000.0 * tot
	for l in purity_levels():
		if allow.is_empty() or str(l.get("id", "")) in allow:
			h -= maxf(0.0, float(l.get("chance", 1.0)))
			if h <= 0.0:
				return str(l.get("id", ""))
	return ""


static func next_order_price(current: int) -> int:
	return mini(500000, 50 * ((current * 3 + 99) / 100))


func field_cells(origin: Vector2i, span: int) -> Array:
	var cells := []
	for x in span:
		for z in span:
			cells.append(wc(origin + Vector2i(x, z)))
	return cells


func order_issue(idx: int, origin: Vector2i) -> String:
	if idx < 0 or idx >= deposits.size() or deposit_hidden(idx):
		return "Тип месторождения ещё не открыт"
	if game == null or game.credits < order_price:
		return "Недостаточно кредитов"
	var span := maxi(1, dep_fp(deposits[idx]))
	var cells := field_cells(origin, span)
	for c in cells:
		if not in_bounds(c) or water_at(c) or nodes.has(c) or nest_cells.has(c):
			return "Нужна свободная сухая площадка"
		if game.factory.grid.has(c) or game.factory.found_top(c) != null:
			return "Площадка занята постройкой"
		if game.zone != null and game.zone.on() and not game.zone.inside_cell(c):
			return "Участок ещё не открыт"
	for x in range(-1, span + 1):
		for z in range(-1, span + 1):
			if deposit.has(wc(origin + Vector2i(x, z))):
				return "Рядом уже есть месторождение"
	var bounds := ground_range(cells)
	return "Слишком большой перепад высот" if bounds.y - bounds.x > 0.4 else ""


func order_field(idx: int, origin: Vector2i) -> bool:
	origin = wc(origin)
	var issue := order_issue(idx, origin)
	if issue != "":
		game.notify(issue, Color.ORANGE)
		return false
	var span := maxi(1, dep_fp(deposits[idx]))
	var quality := _pick_purity(Vector2i(randi(), randi()), deposits[idx], false)
	for c in field_cells(origin, span):
		set_deposit(c, idx)
		set_purity(c, quality)
	ordered_fields[origin] = [idx, span, quality]
	game.credits -= order_price
	order_price = next_order_price(order_price)
	orders_placed += 1
	var point := cell_to_world(origin) + Vector3(span - 1, 0, span - 1)
	point.y = height_at(point)
	if ocean and Net.is_host():
		Net._self().rpc("shore_field",origin,idx,span,quality,order_price,orders_placed)
	var token := orders_placed
	pending_strikes[origin] = token
	for c in field_cells(origin, span):
		paint_ore_pixel(c, Color.TRANSPARENT)
	if dep_marks.has(origin):
		dep_marks[origin].hide()
	game.fx.orbital_strike(point, span * C * 0.65, func(): reveal_strike(origin, token))
	return true


func reveal_strike(origin: Vector2i, token: int) -> void:
	if pending_strikes.get(origin, -1) != token or not ordered_fields.has(origin):
		return
	pending_strikes.erase(origin)
	var record: Array = ordered_fields[origin]
	var idx := int(record[0])
	var col := DB.color(deposits[idx].get("color", "#808080"))
	for c in field_cells(origin, int(record[1])):
		paint_ore_pixel(c, Color(col.r, col.g, col.b, 0.85))
	dirty["ore"] = true
	if dep_marks.has(origin):
		dep_marks[origin].show()
		dep_cover(origin, false)


func remove_field(cell: Vector2i) -> bool:
	var origin := dep_corner(wc(cell))
	if not ordered_fields.has(origin):
		return false
	var cells := field_cells(origin, int(ordered_fields[origin][1]))
	for c in cells:
		if game.factory.grid.has(c) or game.factory.found_top(c) != null:
			game.notify("Сначала разберите постройку над месторождением", Color.ORANGE)
			return false
	for c in cells:
		set_deposit(c, -1)
		dep_override.erase(c)
	ordered_fields.erase(origin)
	pending_strikes.erase(origin)
	return true


func _field_records() -> Array:
	var records := []
	for c in ordered_fields:
		records.append([c.x, c.y] + ordered_fields[c])
	return records


func set_deposit(p: Vector2i, idx: int, col := Color.BLACK) -> void:
	p = wc(p)
	if idx < 0:
		deposit.erase(p)
		dep_purity.erase(p)
		paint_ore_pixel(p, Color(0, 0, 0, 0))
	else:
		deposit[p] = idx
		if col == Color.BLACK:
			col = DB.color(deposits[idx].get("color", "#808080"))
		paint_ore_pixel(p, Color(col.r, col.g, col.b, 0.0 if deposit_hidden(idx) else 0.85))
	dirty["ore"] = true
	_occ(p)
	_dep_mark(p)


## Знак месторождения: модель из поля «Знак на земле» (кристаллы руды по краям клетки). Ставится в угол залежи,
## у залежи 2×2 — посередине. Бур встаёт прямо на неё.
func _dep_mark(p: Vector2i) -> void:
	if dep_marks.has(p):
		dep_marks[p].queue_free()
		dep_marks.erase(p)
	if not deposit.has(p):
		return
	var idx: int = deposit[p]
	var d: Dictionary = deposits[idx]
	var fp := dep_fp(d)
	var mid := str(d.get("marker", ""))
	if fp <= 0 or mid == "" or deposit_hidden(idx) or not DB.data.models.has(mid):
		return
	if deposit.get(wc(p - Vector2i(1, 0)), -1) == idx or deposit.get(wc(p - Vector2i(0, 1)), -1) == idx:
		return   # не угол залежи
	var n := ModelLib.make_node(mid)
	var cpos := cell_to_world(p) + Vector3((fp - 1) * C * 0.5, 0, (fp - 1) * C * 0.5)
	# 1.3: плоское «пятно» знака лежало ровно в земле и мерцало с ней (то земля, то руда) — ставим чуть выше
	# самой высокой точки земли под знаком
	var gy := height_at(cpos)
	var hr := fp * C * 0.45
	for o in [Vector3(hr, 0, hr), Vector3(-hr, 0, hr), Vector3(hr, 0, -hr), Vector3(-hr, 0, -hr)]:
		gy = minf(gy, height_at(cpos + o))
	n.position = cpos + Vector3(0, gy + float(DB.setting("dep_mark_lift", 0.05)), 0)
	# 1.3: знак твёрдый, как камень, — не выше, чем герой может запрыгнуть
	var h := _mark_height(mid)
	var mineral_lights := {"dep_quartz":Color("#ffeedd"),"dep_copper_ore":Color("#ff9439"),"dep_uranium_ore":Color("#4cff96")}
	if mineral_lights.has(mid):
		var glow := OmniLight3D.new()
		glow.light_color = mineral_lights[mid]
		glow.omni_range = 3.4
		glow.light_energy = 1.65
		glow.omni_attenuation = 1.25
		glow.distance_fade_enabled = true
		glow.distance_fade_begin = 32.0
		glow.distance_fade_length = 14.0
		glow.position.y = .72
		n.add_child(glow)
	var ky := minf(float(fp), float(DB.setting("dep_mark_max_h", 1.6)) / maxf(0.05, h))
	n.scale = Vector3(fp, ky, fp)
	n.set_meta("top", h * ky)
	n.set_meta("ky", ky)
	add_child(n)
	dep_marks[p] = n
	dep_cover(p, false)


var _mark_h := {}


## Высота модели знака месторождения при масштабе 1.
func _mark_height(mid: String) -> float:
	if _mark_h.has(mid):
		return _mark_h[mid]
	var n := ModelLib.make_node(mid)
	var top := 0.0
	for ch in n.get_children():
		var bb := AABB()
		if ch is MultiMeshInstance3D and ch.multimesh and ch.multimesh.mesh:
			bb = ch.transform * ch.multimesh.mesh.get_aabb()
		elif ch is MeshInstance3D and ch.mesh:
			bb = ch.transform * ch.mesh.get_aabb()
		top = maxf(top, bb.end.y)
	n.free()
	_mark_h[mid] = top if top > 0.0 else 0.8
	return _mark_h[mid]


## 1.3: знак залежи на клетке c, если он сейчас стоит (не ушёл под здание).
func dep_mark_at(c: Vector2i) -> Node3D:
	c = wc(c)
	if not deposit.has(c):
		return null
	var m = dep_marks.get(dep_corner(c))
	if m == null or not is_instance_valid(m) or m.get_meta("covered", false):
		return null
	return m


## Верх знака залежи над клеткой c (на него встаёт герой) или −1.
func dep_top(c: Vector2i) -> float:
	var m := dep_mark_at(c)
	if m == null:
		return -1.0
	return m.position.y + float(m.get_meta("top", 0.0))


## Пока на залежи стоит здание (бур, лента, часть составного здания), знак уходит в землю,
## чтобы не пересекаться с ним; убрали здание — знак поднимается обратно.
func dep_cover(c: Vector2i, animate := true) -> void:
	c = wc(c)
	if not deposit.has(c):
		return
	var corner := dep_corner(c)
	var m = dep_marks.get(corner)
	if m == null or not is_instance_valid(m):
		return
	var fp := dep_fp(deposits[deposit[corner]])
	var covered := false
	var ftop := -INF
	if game != null and game.factory != null:
		for dx in fp:
			for dz in fp:
				if game.factory.grid.has(wc(corner + Vector2i(dx, dz))):
					covered = true
				var fo = game.factory.found_top(wc(corner + Vector2i(dx, dz)))
				if fo != null:
					ftop = maxf(ftop, float(fo.top))
	# 1.1.8: на фундаменте залежь стоит на его верху (раньше пряталась внутри — не понять, где была)
	if not m.has_meta("y0"):
		m.set_meta("y0", m.position.y)
	var y0 := float(m.get_meta("y0"))
	m.position.y = maxf(y0, ftop + float(DB.setting("dep_mark_lift", 0.05))) if ftop > -INF else y0
	if covered == bool(m.get_meta("covered", false)) and animate:
		return
	m.set_meta("covered", covered)
	var full := Vector3(fp, float(m.get_meta("ky", fp)), fp)
	var flat := Vector3(fp * 0.9, 0.02, fp * 0.9)
	if not animate:
		m.scale = flat if covered else full
		m.visible = not covered
		return
	m.visible = true
	var t: Tween = m.create_tween()
	t.tween_property(m, "scale", flat if covered else full, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN if covered else Tween.EASE_OUT)
	if covered:
		t.tween_callback(func(): m.visible = false)


func _make_nests(nd: Dictionary) -> void:
	var count := int(nd.get("count", 7))
	for i in count:
		var a: float = float(i) / maxi(1, count) * TAU + rng.randf_range(-0.3, 0.3)
		var d := rng.randf_range(float(nd.get("min_dist", 45)), float(nd.get("max_dist", 150)))
		var c := center + Vector2i(roundi(cos(a) * d), roundi(sin(a) * d))
		if wrap_w > 0:
			c = wc(c)
		else:
			c.x = clampi(c.x, 12, W - 12)
			c.y = clampi(c.y, 12, W - 12)
		add_nest(c)


func add_nest(c: Vector2i) -> void:
	var nd: Dictionary = DB.data.world.get("nests", {})
	for dx in range(-3, 4):
		for dz in range(-3, 4):
			var q := wc(c + Vector2i(dx, dz))
			nest_cells[q] = nests.size()
			if in_bounds(q):
				water.set_pixelv(wc(q), Color(0, 0, 0))
	var node := _nest_node()
	node.position = cell_to_world(c)
	node.position.y = height_at(node.position)
	add_child(node)
	var hp := float(nd.get("hp", 1500))
	nests.append({"cell": c, "pos": node.position, "hp": hp, "max": hp, "node": node,
		"core": node.get_meta("core"), "light": node.get_meta("light"), "alive": true, "guards": false})


## Редактор карты: убрать гнездо.
func remove_nest(i: int) -> void:
	if i < 0 or i >= nests.size():
		return
	var n: Dictionary = nests[i]
	if is_instance_valid(n.node):
		n.node.queue_free()
	nests.remove_at(i)
	nest_cells.clear()
	for k in nests.size():
		for dx in range(-3, 4):
			for dz in range(-3, 4):
				nest_cells[wc(nests[k].cell + Vector2i(dx, dz))] = k


## Пустая карта: только трава.
func make_empty(size: int, wrap_on: bool) -> void:
	setup_size(size, wrap_on)
	lazy = W > LAZY_FROM
	flora_cfg = {"seed": used_seed, "flora": []}
	chunks_done.clear()
	_last_focus = cell_to_world(center)
	deposits = DB.data.world.get("deposits", []).duplicate(true)
	_build_visuals()


func _nest_node() -> Node3D:
	var root := Node3D.new()
	var flesh := StandardMaterial3D.new()
	flesh.albedo_color = Color(0.2, 0.07, 0.24)
	flesh.roughness = 0.3
	var mound := MeshInstance3D.new()
	mound.mesh = ModelLib.unit_mesh("sphere", 1.0, 16)
	mound.scale = Vector3(9.0, 4.0, 9.0)
	mound.material_override = flesh
	root.add_child(mound)
	var spike_mat := StandardMaterial3D.new()
	spike_mat.albedo_color = Color(0.35, 0.1, 0.4)
	spike_mat.emission_enabled = true
	spike_mat.emission = Color(0.7, 0.1, 1.0)
	spike_mat.emission_energy_multiplier = 0.6
	for k in 7:
		var s := MeshInstance3D.new()
		var h := rng.randf_range(3.0, 7.0)
		s.mesh = ModelLib.unit_mesh("cone", 1.0, 6)
		var a := float(k) / 7.0 * TAU
		var rr := rng.randf_range(1.5, 3.2)
		s.position = Vector3(cos(a) * rr, h * 0.45, sin(a) * rr)
		s.rotation = Vector3(sin(a) * 0.35, 0, -cos(a) * 0.35)
		s.scale = Vector3(1.4, h, 1.4)
		s.material_override = spike_mat
		root.add_child(s)
	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = Color(1.0, 0.2, 0.9)
	core_mat.emission_enabled = true
	core_mat.emission = Color(1.0, 0.15, 0.85)
	core_mat.emission_energy_multiplier = 4.0
	var core := MeshInstance3D.new()
	core.mesh = ModelLib.unit_mesh("sphere", 1.0, 16)
	core.scale = Vector3.ONE * 2.6
	core.position = Vector3(0, 2.2, 0)
	core.material_override = core_mat
	root.add_child(core)
	var light := OmniLight3D.new()
	light.light_color = Color(0.9, 0.2, 1.0)
	light.omni_range = 16.0
	light.light_energy = 3.0
	light.position = Vector3(0, 3.5, 0)
	root.add_child(light)
	root.set_meta("core", core)
	root.set_meta("light", light)
	return root


# ---------------------------------------------------------------- ресурсы на карте

func ground_normal(pos: Vector3, radius: float) -> Vector3:
	var dx := height_at(pos + Vector3.RIGHT * radius) - height_at(pos - Vector3.RIGHT * radius)
	var dz := height_at(pos + Vector3.BACK * radius) - height_at(pos - Vector3.BACK * radius)
	return Vector3(-dx, 2.0 * radius, -dz).normalized()

func seat_resource(n: Node_) -> bool:
	var radius := clampf(n.xf.basis.get_scale().x * .72, .28, 1.8)
	var pos := n.xf.origin
	var normal := ground_normal(pos, radius)
	var low := height_at(pos)
	var high := low
	for direction in [Vector3.RIGHT,Vector3.BACK,Vector3.LEFT,Vector3.FORWARD]:
		var sample := height_at(pos + direction * radius)
		low = minf(low,sample)
		high = maxf(high,sample)
	if normal.y < .77 or high-low > radius*1.3:
		return false
	var axis := n.xf.basis.y.normalized()
	n.xf.basis = Basis(Quaternion(axis,normal)) * n.xf.basis
	n.xf.origin.y = lerpf(height_at(pos), low, .25)
	return true

func add_node(res: String, c: Vector2i, xf_override = null) -> Node_:
	c = wc(c)
	if (ocean and not island_cells.has(c)) or res == "" or not DB.data.resources.has(res) or nodes.has(c):
		return null
	var rd: Dictionary = DB.data.resources[res]
	var n := Node_.new()
	n.res = res
	n.cell = c
	n.maxhp = float(rd.get("hp", 10))
	n.hp = n.maxhp
	if xf_override is Transform3D:
		n.xf = xf_override
	else:
		var sc: Array = rd.get("scale", [0.8, 1.2])
		var s := rng.randf_range(float(sc[0]), float(sc[1]))
		n.xf = Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.15), s)),
			cell_to_world(c) + Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4)))
	if not seat_resource(n):
		return null
	n.chunk = Vector2i(c.x / CHUNK, c.y / CHUNK)
	nodes[c] = n
	if rd.get("blocks", true):
		_occ(c)
	if _visuals_built:
		clear_decor_at(c)
	if is_inside_tree() and _visuals_built:
		_renderer_for(n).add(n, n.xf, 1.0)
	return n


func remove_node(c: Vector2i) -> void:
	c = wc(c)
	var n: Node_ = nodes.get(c)
	if n == null:
		return
	nodes.erase(c)
	var key := "%s|%s" % [n.res, n.chunk]
	if renderers.has(key):
		renderers[key].remove(n)
	_occ(c)


var _visuals_built := false

func _renderer_for(n: Node_) -> PartRenderer:
	var key := "%s|%s" % [n.res, n.chunk]
	if renderers.has(key):
		return renderers[key]
	var model: String = DB.data.resources[n.res].get("model", n.res)
	var r := ModelLib.make_renderer(model, true, false, true)
	r.set_meta("chunk", n.chunk)
	if not r.detailed.is_empty():
		r.chunk = 24.0
	for p in r.parts:
		p.mmi.visibility_range_end = 230.0
		p.mmi.visibility_range_end_margin = 20.0
	add_child(r)
	renderers[key] = r
	return r


func _build_visuals() -> void:
	_visuals_built = true
	for c in nodes:
		var n: Node_ = nodes[c]
		_renderer_for(n).add(n, n.xf, 1.0)
	if ocean:
		_island_visuals()
		return
	_make_ground()
	_make_water()
	if W >= 64:
		_landing_spring()
	_make_grass()
	_make_decor()
	apply_look()


func rebuild_resource_visuals() -> void:
	for k in renderers:
		renderers[k].queue_free()
	renderers.clear()
	for c in nodes:
		_renderer_for(nodes[c]).add(nodes[c], nodes[c].xf, 1.0)


func blocks(c: Vector2i) -> bool:
	c = wc(c)
	var n: Node_ = nodes.get(c)
	return n != null and DB.data.resources.get(n.res, {}).get("blocks", true)


## 1.3: верх ресурса на клетке (камень, рудный камень, куст), если его можно перепрыгнуть, иначе −1 (деревья).
func node_top(c: Vector2i) -> float:
	var n: Node_ = nodes.get(c)
	if n == null:
		return -1.0
	var rd: Dictionary = DB.data.resources.get(n.res, {})
	if str(rd.get("category", "")) == "Деревья":
		return -1.0
	var h := _mark_height(str(rd.get("model", n.res))) * n.xf.basis.get_scale().y
	if h > float(DB.setting("hop_max", 2.0)):
		return -1.0
	return n.xf.origin.y + h


## Удар по ресурсу. Возвращает true, если ресурс разрушен.
func hit_node(c: Vector2i, power: float, tool: String, silent := false) -> bool:
	c = wc(c)
	var n: Node_ = nodes.get(c)
	if n == null:
		return false
	var rd: Dictionary = DB.data.resources[n.res]
	var need: String = rd.get("tool", "")
	var dmg := power
	if need != "" and need != tool:
		dmg *= 0.35
	n.hp -= dmg
	var key := "%s|%s" % [n.res, n.chunk]
	var r: PartRenderer = renderers.get(key)
	if r:
		r.set_tint(n, 0.0, 0.7)
		_shake(n, r)
	var top := n.xf.origin + Vector3(0, 1.2, 0)
	# silent — удар другого игрока по сети: урон и щепки, но добыча и опыт — у него
	for d in ([] if silent else rd.get("drops", [])):
		if d.get("on", "break") == "hit" and rng.randf() < float(d.get("chance", 1.0)):
			game.drops.spawn(d.item, rng.randi_range(int(d.get("min", 1)), int(d.get("max", 1))), top)
	game.fx.chips(top, DB.color(DB.data.models.get(rd.get("model", ""), {}).get("parts", [{}])[0].get("color", "#8a5a2e")))
	if not silent:
		game.add_xp(float(DB.data.levels.get("xp", {}).get("gather_hit", 1)) * float(rd.get("xp", 1)))
	if n.hp > 0.0:
		return false
	for d in ([] if silent else rd.get("drops", [])):
		if d.get("on", "break") == "break" and rng.randf() < float(d.get("chance", 1.0)):
			var cnt := rng.randi_range(int(d.get("min", 1)), int(d.get("max", 1)))
			for i in cnt:
				game.drops.spawn(d.item, 1, top + Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.5, 0.5)))
	var xf := n.xf
	var model: String = rd.get("model", "")
	remove_node(c)
	if not silent:
		# 1.3: раскол — крупные осколки, пыль, звук, короткая заморозка кадра
		game.fx.chips(top, DB.color(DB.data.models.get(model, {}).get("parts", [{}])[0].get("color", "#8a5a2e")))
		game.fx.dirt(xf.origin + Vector3(0, 0.3, 0), 0.7)
		game.add_trauma(0.18)
		game.hitstop(0.04)
		if rd.get("category", "") != "Деревья":
			game.sfx.play("crack", xf.origin)
	if rd.get("category", "") == "Деревья" and model != "":
		_fall_anim(model, xf)
		game.sfx.play("fall", xf.origin)
	var stump: String = rd.get("stump", "")
	if stump != "" and DB.data.resources.has(stump):
		add_node(stump, c, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), xf.origin))
		# 1.4: пень со временем снова становится этим деревом
		var regrow := float(DB.setting("tree_regrow", 0.0))
		if regrow > 0.0:
			respawns.append({"res": n.res, "cell": c, "t": regrow, "over": stump})
	if float(rd.get("respawn", 0)) > 0.0 and not _is_rock(n.res):   # 1.3: камни не появляются снова, растения — да
		respawns.append({"res": n.res, "cell": c, "t": float(rd.respawn)})
	return true


## 13.10: добыча руками или киркой прямо с месторождения. Каждый удар копит «выработку»;
## набралось «Добыча руками: прочность» — выпадает одна штука руды. Без нужного инструмента — втрое медленнее.
func can_mine(c: Vector2i) -> bool:
	c = wc(c)
	if not deposit.has(c) or deposit_item(c) == "" or DB.is_fluid(deposit_item(c)):
		return false
	if not bool(deposits[deposit[c]].get("hand", true)):
		return false
	return game == null or game.factory == null or not game.factory.grid.has(c)


func mine_deposit(c: Vector2i, power: float, tool: String) -> bool:
	c = wc(c)
	if not can_mine(c):
		return false
	var d: Dictionary = deposits[deposit[c]]
	var need := str(d.get("hand_tool", "pickaxe"))
	var dmg := power
	# 17.10: твёрдая порода глубоких слоёв — нужна кирка не слабее «Кирка: мощность» залежи
	var minp := float(d.get("hand_power", 0.0))
	if minp > 0.0 and (tool != need or power + 0.01 < minp):
		if Time.get_ticks_msec() - _hard_msg_ms > 2500:
			_hard_msg_ms = Time.get_ticks_msec()
			game.notify("%s: слишком твёрдо — нужна кирка мощностью %s (или бур)" % [DB.item_name(str(d.get("item", ""))), str(minp)], Color(1, 0.7, 0.4))
		return false
	if need != "" and need != tool:
		dmg *= 0.35
	var acc := float(dep_mined.get(c, 0.0)) + dmg
	var hp := maxf(1.0, float(d.get("hand_hp", 25.0)))
	var top := cell_to_world(c) + Vector3(0, height_at(cell_to_world(c)) + 0.6, 0)
	game.fx.chips(top, DB.color(d.get("color", "#808080")))
	var got := false
	while acc >= hp:
		acc -= hp
		game.drops.spawn(str(d.get("item", "")), 1, top)
		for dr in d.get("drops", []):
			if rng.randf() < float(dr.get("chance", 0.0)):
				game.drops.spawn(str(dr.get("item", "")), 1, top)
		got = true
	dep_mined[c] = acc
	game.add_xp(float(DB.data.levels.get("xp", {}).get("gather_hit", 1)))
	if dep_marks.has(c):
		var m: Node3D = dep_marks[c]
		var t: Tween = m.create_tween()
		t.tween_property(m, "scale", m.scale * 1.08, 0.05)
		t.tween_property(m, "scale", m.scale, 0.1)
	return got


func _shake(n: Node_, r: PartRenderer) -> void:
	var base := n.xf
	var tw := create_tween()
	for k in 4:
		var off := Vector3(rng.randf_range(-0.08, 0.08), 0, rng.randf_range(-0.08, 0.08))
		tw.tween_callback(func(): if r.has(n): r.set_xform(n, Transform3D(base.basis, base.origin + off)))
		tw.tween_interval(0.03)
	tw.tween_callback(func(): if r.has(n): r.set_xform(n, base))


func _fall_anim(model: String, xf: Transform3D) -> void:
	var node := ModelLib.make_node(model)
	node.transform = xf
	add_child(node)
	var axis := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()
	var tw := create_tween()
	tw.tween_method(func(a: float): node.transform = Transform3D(xf.basis.rotated(axis, a), xf.origin), 0.0, PI * 0.48, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_interval(0.4)
	tw.tween_property(node, "scale", Vector3.ONE * 0.01, 0.5)
	tw.tween_callback(node.queue_free)


## 1.4: посадить саженец в свободную клетку земли рядом с точкой (сначала сама клетка, потом соседние).
## Возвращает клетку или (-1, -1), если места нет.
func plant_sapling(young: String, tree: String, at: Vector3):
	var c0 := world_to_cell(at)
	for r in 3:
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				var c := wc(c0 + Vector2i(dx, dz))
				if not in_bounds(c) or water_at(c) or nodes.has(c) or deposit.has(c) or (not ocean and occ_img.get_pixel(c.x, c.y).r > 0.5) or (ocean and game.factory.found.has(c)):
					continue
				if game.factory.building_at(c) != null:
					continue
				if not plant_at(c, young, tree):
					continue
				Net._self().node_plant(c, young, tree)
				return c
	return null


## Саженец в эту клетку (у посадившего и, по сети, у остальных игроков).
func plant_at(c: Vector2i, young: String, tree: String) -> bool:
	c = wc(c)
	if add_node(young, c) == null:
		return false
	respawns.append({"res": tree, "cell": c, "t": float(DB.setting("sapling_grow", 300.0)), "over": young})
	return true


func update_respawns(delta: float) -> void:
	if respawns.is_empty():
		return
	var keep := []
	for r in respawns:
		r.t -= delta
		if r.t > 0.0:
			keep.append(r)
		elif r.has("over"):
			# 1.4: пень или саженец вырастает в дерево (если его не срубили и клетку не заняли)
			var on: Node_ = nodes.get(r.cell)
			if on != null and on.res == str(r.over) and game.factory.building_at(r.cell) == null:
				var pos := on.xf.origin
				remove_node(r.cell)
				var sc: Array = DB.data.resources.get(r.res, {}).get("scale", [0.8, 1.2])
				var k := rng.randf_range(float(sc[0]), float(sc[1]))
				var gn := add_node(r.res, r.cell, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * k), pos))
				if gn != null and _visuals_built and is_inside_tree():
					game.fx.dirt(pos + Vector3(0, 0.3, 0), 0.6)
		elif not nodes.has(r.cell) and game.factory.building_at(r.cell) == null and not _is_rock(r.res):
			add_node(r.res, r.cell)
	respawns = keep


# ---------------------------------------------------------------- визуал земли

const GROUND_N := 256   # клеток сетки земли по стороне (ближняя сетка — шаг 1 клетка)
var ground_far: MeshInstance3D
var far_step := 8.0

func _ground_mesh(step: float) -> PlaneMesh:
	var plane := PlaneMesh.new()
	plane.size = Vector2(GROUND_N * step, GROUND_N * step)
	plane.subdivide_width = GROUND_N - 1
	plane.subdivide_depth = GROUND_N - 1
	return plane


## Земля — две сетки, которые следуют за камерой: подробная рядом и крупная вдали.
## Высоту холмов берёт видеокарта из карты высот, поэтому сетки можно двигать.
func _height_levels() -> Image:
	var levels := height.duplicate() as Image
	levels.generate_mipmaps()
	return levels

func _make_ground() -> void:
	splat_tex = ImageTexture.create_from_image(splat)
	water_tex = ImageTexture.create_from_image(water)
	ore_tex = ImageTexture.create_from_image(ore_img)
	height_tex = ImageTexture.create_from_image(_height_levels())
	ground_mat = ShaderMaterial.new()
	ground_mat.shader = preload("res://shaders/ground.gdshader")
	yard_tex = ImageTexture.create_from_image(yard_img)
	ground_mat.set_shader_parameter("yard", yard_tex)
	for material_name in ["slate", "regolith", "basalt", "moss"]:
		ground_mat.set_shader_parameter(material_name, load("res://textures/frontier/%s.jpg" % material_name))
	ground_mat.set_shader_parameter("splat", splat_tex)
	ground_mat.set_shader_parameter("water", water_tex)
	ground_mat.set_shader_parameter("ore_map", ore_tex)
	ground_mat.set_shader_parameter("height_map", height_tex)
	ground_mat.set_shader_parameter("world_size", W * C)
	ground_mat.set_shader_parameter("cell", C)
	ground_mat.set_shader_parameter("wrap", wrap)
	# 1.4: рисованные текстуры земли (look.ground_tex), файлы в textures/ground/
	if bool(DB.data.world.get("look", {}).get("ground_tex", false)):
		ground_mat.set_shader_parameter("use_tex", true)
		for k in ["grass", "meadow", "dirt", "rock", "sand", "gravel"]:
			var path := "res://textures/ground/%s.png" % k
			if ResourceLoader.exists(path):
				ground_mat.set_shader_parameter("t_" + k, load(path))
	far_step = C * maxf(4.0, ceilf(W * 3.0 / GROUND_N))
	var big := AABB(Vector3(-GROUND_N * far_step, -10, -GROUND_N * far_step), Vector3(GROUND_N * far_step * 2, 120, GROUND_N * far_step * 2))
	for i in 2:
		var mi := MeshInstance3D.new()
		mi.mesh = _ground_mesh(C if i == 0 else far_step)
		mi.set_instance_shader_parameter("height_lod",0.0 if i == 0 else log(far_step/C)/log(2.0))
		mi.set_meta("no_mirror", true)
		mi.material_override = ground_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if i == 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.custom_aabb = big
		add_child(mi)
		if i == 0:
			ground_node = mi
		else:
			ground_far = mi
	_place_ground(Vector3(W * C * 0.5, 0, W * C * 0.5))


# ---------------------------------------------------------------- 1.3: сплитскрин
## Земля рядом с героем и трава строятся вокруг одной точки. Во время сплитскрина у второй половины экрана свои
## копии (на своём слое отрисовки — их видит только её камера), чтобы у второго героя тоже была трава и подробная земля.
var split_nodes: Array = []      # [земля, дальняя земля, трава] второй половины
var ground_mat2: ShaderMaterial
var grass_mat2: ShaderMaterial
var grass_far: MultiMeshInstance3D


func split_views(on: bool, layers: Array) -> void:
	for n in split_nodes:
		if is_instance_valid(n):
			n.queue_free()
	split_nodes = []
	var own := [ground_node, ground_far, grass]
	for n in own:
		if n != null:
			n.layers = (1 << (int(layers[0]) - 1)) if on else 1
	if not on or ground_node == null:
		return
	ground_mat2 = ground_mat.duplicate()
	for n in own:
		if n == null:
			continue
		var c: GeometryInstance3D = n.duplicate()
		if n == grass:
			grass_mat2 = grass_mat.duplicate()
			c.material_override = grass_mat2
		else:
			c.material_override = ground_mat2
		c.layers = 1 << (int(layers[1]) - 1)
		add_child(c)
		split_nodes.append(c)


func update_split_view(focus: Vector3) -> void:
	if split_nodes.size() < 2:
		return
	var g: Node3D = split_nodes[0]
	var gf: GeometryInstance3D = split_nodes[1]
	g.position = Vector3(snappedf(focus.x - C * 0.5, C) + C * 0.5, 0, snappedf(focus.z - C * 0.5, C) + C * 0.5)
	gf.position = Vector3(snappedf(focus.x - C * 0.5, far_step) + C * 0.5, -0.05, snappedf(focus.z - C * 0.5, far_step) + C * 0.5)
	gf.set_instance_shader_parameter("hole", Vector4(g.position.x, g.position.z, GROUND_N * C * 0.5 - C * 2.0, 1))
	if split_nodes.size() > 2 and grass_mat2 != null:
		var gr: Node3D = split_nodes[2]
		var sp: float = grass.get_meta("spacing") if grass else 0.3
		gr.position = Vector3(snappedf(focus.x, sp), 0, snappedf(focus.z, sp))
		grass_mat2.set_shader_parameter("center", focus)


## Материал земли половины экрана (курсор и сетка стройки у каждой свои).
func ground_mat_of(seat: int) -> ShaderMaterial:
	return ground_mat2 if seat == 1 and ground_mat2 != null and not split_nodes.is_empty() else ground_mat


func _place_ground(focus: Vector3) -> void:
	if ground_node == null:
		return
	# вершины сетки стоят точно в центрах клеток
	ground_node.position = Vector3(snappedf(focus.x - C * 0.5, C) + C * 0.5, 0, snappedf(focus.z - C * 0.5, C) + C * 0.5)
	ground_far.position = Vector3(snappedf(focus.x - C * 0.5, far_step) + C * 0.5, -0.05, snappedf(focus.z - C * 0.5, far_step) + C * 0.5)
	ground_node.set_instance_shader_parameter("hole", Vector4(0, 0, 0, 0))
	ground_far.set_instance_shader_parameter("hole", Vector4(ground_node.position.x, ground_node.position.z, GROUND_N * C * 0.5 - C * 2.0, 1))


func _make_water() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(W * C, W * C) * (3.0 if wrap else 1.0)
	plane.subdivide_width = 0
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.position = Vector3(W * C * 0.5, 0.12, W * C * 0.5)
	water_mat = ShaderMaterial.new()
	water_mat.shader = preload("res://shaders/water.gdshader")
	water_mat.set_shader_parameter("water", water_tex)
	water_mat.set_shader_parameter("world_size", W * C)
	water_mat.set_shader_parameter("wrap", wrap)
	mi.set_meta("no_mirror", true)
	water_node = mi
	mi.material_override = water_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## 17.10: пересоздать траву (настройка «Густая трава»).
func remake_grass() -> void:
	if ocean:
		return
	if grass:
		grass.queue_free()
		grass = null
	_make_grass()
	if grass:
		grass.visible = bool(Prefs.get_value("grass", true))
		apply_look()


func _make_grass() -> void:
	# «Меньше растительности» возвращает и прежнюю, редкую траву
	var dense := bool(Prefs.get_value("grass_dense", true)) and not bool(Prefs.get_value("flora_less", false))
	var spacing := 0.3 if dense else 0.34
	# 1.4: рисованная трава — пучки шире и реже (меньше травинок — легче видеокарте)
	var lk: Dictionary = DB.data.world.get("look", {})
	spacing *= float(lk.get("grass_spacing_k", 1.0))
	var radius := 40.0 if dense else 30.0
	radius = minf(radius, float(lk.get("grass_radius", radius)))
	var n := int(radius * 2.0 / spacing)
	var lush := str(lk.get("grass_style", "")) == "lush"
	if lush:
		spacing = float(lk.get("lush_spacing", 0.26))
		radius = float(lk.get("lush_radius", 26.0))
		n = int(radius * 2.0 / spacing)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _blade_mesh(dense)
	# 1.4: look.grass_off — без травинок вовсе (земля нарисована текстурой)
	if bool(lk.get("grass_off", false)):
		n = 0
	mm.instance_count = n * n
	var i := 0
	for x in n:
		for z in n:
			mm.set_instance_transform(i, Transform3D(Basis(), Vector3(x * spacing - radius, 0, z * spacing - radius)))
			i += 1
	grass = MultiMeshInstance3D.new()
	grass.multimesh = mm
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	grass.set_meta("spacing", spacing)
	grass_mat = ShaderMaterial.new()
	grass_mat.shader = preload("res://shaders/grass_lush.gdshader") if lush else preload("res://shaders/grass.gdshader")
	occ_tex = ImageTexture.create_from_image(occ_img)
	grass_mat.set_shader_parameter("occ", occ_tex)
	grass_mat.set_shader_parameter("splat", splat_tex)
	grass_mat.set_shader_parameter("water", water_tex)
	grass_mat.set_shader_parameter("height_map", height_tex)
	grass_mat.set_shader_parameter("ore_map", ore_tex)
	grass_mat.set_shader_parameter("world_size", W * C)
	grass_mat.set_shader_parameter("radius", radius)
	grass_mat.set_shader_parameter("spacing", spacing)
	grass_mat.set_shader_parameter("clumpy", 1.0 if str(lk.get("grass_style", "")) == "clump" else 0.0)
	grass_mat.set_shader_parameter("wrap", wrap)
	if not lush:
		grass_mat.set_shader_parameter("lush_mask", ground_lush())
	grass.set_meta("no_mirror", true)
	grass.material_override = grass_mat
	grass.custom_aabb = AABB(Vector3(-radius - 2, -1, -radius - 2), Vector3(radius * 2 + 4, 90, radius * 2 + 4))
	add_child(grass)
	# 1.4: трава до горизонта — дальнее кольцо из крупных редких пучков (3 листа); вблизи — густая ближняя
	grass_far = null
	var far_r := float(lk.get("lush_far_radius", 75.0))
	if lush and n > 0 and far_r > radius:
		var fsp := float(lk.get("lush_far_spacing", 0.7))
		var fn := int(far_r * 2.0 / fsp)
		var fmm := MultiMesh.new()
		fmm.transform_format = MultiMesh.TRANSFORM_3D
		fmm.mesh = _blade_mesh(dense, 3)
		# квадрат без середины: ближе inner пучки всё равно схлопнутся в шейдере, их и не создаём
		var pts := []
		var hole := radius * 0.65
		for x in fn:
			for z in fn:
				var p := Vector3(x * fsp - far_r, 0, z * fsp - far_r)
				if absf(p.x) < hole and absf(p.z) < hole:
					continue
				if Vector2(p.x, p.z).length() > far_r + fsp:
					continue
				pts.append(p)
		fmm.instance_count = pts.size()
		for j in pts.size():
			fmm.set_instance_transform(j, Transform3D(Basis(), pts[j]))
		grass_far = MultiMeshInstance3D.new()
		grass_far.multimesh = fmm
		grass_far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		grass_far.set_meta("spacing", fsp)
		grass_far.set_meta("no_mirror", true)
		var fm: ShaderMaterial = grass_mat.duplicate()
		fm.set_shader_parameter("radius", far_r)
		fm.set_shader_parameter("spacing", fsp)
		fm.set_shader_parameter("inner", radius)
		fm.set_shader_parameter("tuft_scale", float(lk.get("lush_far_scale", 1.5)))
		grass_far.material_override = fm
		grass_far.custom_aabb = AABB(Vector3(-far_r - 2, -1, -far_r - 2), Vector3(far_r * 2 + 4, 90, far_r * 2 + 4))
		grass.add_child(grass_far)


func _blade_mesh(dense := false, n_leaves := 7) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if str(DB.data.world.get("look", {}).get("grass_style", "")) == "lush":
		# 1.4: пучок широких листьев — объёмная трава по колено, герой в ней утопает
		var rl := RandomNumberGenerator.new()
		rl.seed = 1405
		for li in n_leaves:
			var a := float(li) / float(n_leaves) * TAU + rl.randf_range(-0.35, 0.35)
			var tilt := rl.randf_range(0.15, 0.55)
			var lh := rl.randf_range(0.42, 0.62)
			var lw := rl.randf_range(0.055, 0.08)
			var dir := Vector3(cos(a), 0, sin(a))
			var side := Vector3(-dir.z, 0, dir.x)
			var p0 := dir * 0.03
			var p1 := dir * (0.03 + sin(tilt) * lh * 0.35) + Vector3(0, cos(tilt) * lh * 0.5, 0)
			var p2 := dir * (0.03 + sin(tilt) * lh * 0.85) + Vector3(0, cos(tilt) * lh * 0.85, 0)
			var p3 := dir * (0.03 + sin(tilt * 1.4) * lh * 1.15) + Vector3(0, lh, 0)
			var v := [p0 - side * lw, p0 + side * lw, p1 - side * lw * 0.95, p1 + side * lw * 0.95, p2 - side * lw * 0.6, p2 + side * lw * 0.6, p3]
			var nrm := (dir * 0.8 + Vector3.UP * 0.3).normalized()
			for idx in [0, 1, 2, 2, 1, 3, 2, 3, 4, 4, 3, 5, 4, 5, 6]:
				st.set_normal(nrm)
				st.add_vertex(v[idx])
		return st.commit()
	if str(DB.data.world.get("look", {}).get("grass_style", "")) == "clump":
		# 1.4: куст травы — широкие листья веером от центра. Крупный и редкий: вдали не рябит, как тонкие травинки
		var rng2 := RandomNumberGenerator.new()
		rng2.seed = 1404
		var leaves := 9
		for li in n_leaves:
			var a := float(li) / leaves * TAU + rng2.randf_range(-0.25, 0.25)
			var tilt := rng2.randf_range(0.35, 0.8) if li > 1 else 0.15
			var lh := rng2.randf_range(0.32, 0.5) * (1.15 if li <= 1 else 1.0)
			var lw := rng2.randf_range(0.09, 0.13)
			var dir := Vector3(cos(a), 0, sin(a))
			var side := Vector3(-dir.z, 0, dir.x)
			var mid := dir * sin(tilt) * lh * 0.5 + Vector3(0, cos(tilt) * lh * 0.55, 0)
			var tip := dir * sin(tilt) * lh * 1.25 + Vector3(0, cos(tilt) * lh * 0.85, 0)
			var base := dir * 0.04
			var v := [base - side * lw * 0.6, base + side * lw * 0.6, mid - side * lw, mid + side * lw, tip]
			var n := (Vector3.UP + dir * 0.6).normalized()
			for idx in [0, 1, 2, 2, 1, 3, 2, 3, 4]:
				st.set_normal(n)
				st.add_vertex(v[idx])
		return st.commit()
	# 17.10: «густая» трава — пучок из трёх изогнутых травинок разной высоты вместо одной
	var blades := [[0.0, 0.0, 0.0, 1.0]] if not dense else [[0.0, 0.0, 0.0, 1.0], [2.1, 0.07, 0.04, 0.8], [4.2, -0.06, 0.05, 1.15]]
	for bl in blades:
		var w := 0.045 * float(DB.data.world.get("look", {}).get("blade_width_k", 1.0))
		var h := 0.42 * float(bl[3]) * float(DB.data.world.get("look", {}).get("blade_height_k", 1.0))
		var v := [Vector3(-w, 0, 0), Vector3(w, 0, 0), Vector3(-w * 0.75 + 0.03, h * 0.5, 0), Vector3(w * 0.75 + 0.03, h * 0.5, 0), Vector3(0.1, h, 0)]
		var rot := Basis(Vector3.UP, float(bl[0]))
		for idx in [0, 1, 2, 2, 1, 3, 2, 3, 4]:
			st.set_normal(Vector3.UP)
			st.add_vertex(rot * v[idx] + Vector3(float(bl[1]), 0, float(bl[2])))
	return st.commit()


## 1.4: кто раздвигает объёмную траву — герои рядом и ближайшие монстры (до 4).
func _update_pushers(focus: Vector3) -> void:
	if grass_mat == null or game == null:
		return
	var arr: Array[Vector4] = [Vector4.ZERO, Vector4.ZERO, Vector4.ZERO, Vector4.ZERO]
	var i := 0
	var pl: Array = game.split.local_players() if game.get("split") != null else [game.player]
	for p in pl:
		if p != null and i < 4:
			arr[i] = Vector4(p.position.x, 0, p.position.z, 1.1)
			i += 1
	if game.get("enemies") != null and i < 4:
		for e in game.enemies.list:
			if i >= 4:
				break
			if World.dist(e.pos, focus) < 14.0:
				arr[i] = Vector4(e.pos.x, 0, e.pos.z, 1.2)
				i += 1
	grass_mat.set_shader_parameter("pushers", arr)


var _shadow_tick := 0

## Деревья и камни далеко от героя не отбрасывают тени («Настройки» → «Деревья и камни: тени ближе»).
## Тени дальних кусков леса считались для каждой ступени теней солнца — это главная нагрузка на видеокарту.
func _flora_shadows(focus: Vector3) -> void:
	_shadow_tick += 1
	if _shadow_tick % 20 != 0:
		return
	var lim := float(DB.setting("flora_shadow_dist", 70.0))
	var size := CHUNK * C
	var full := W * C
	for k in renderers:
		var r: PartRenderer = renderers[k]
		var on := true
		if lim > 0.0 and r.has_meta("chunk"):
			var ch: Vector2i = r.get_meta("chunk")
			var mid := Vector3((ch.x+.5)*size,0,(ch.y+.5)*size)
			var offset := World.delta(mid,focus).abs()
			var dx := maxf(0,offset.x-size*.5)
			var dz := maxf(0,offset.z-size*.5)
			on = dx*dx+dz*dz < lim*lim
		if r.get_meta("shadow_on", true) != on:
			r.set_meta("shadow_on", on)
			r.set_shadows(on)


func update_visuals(focus: Vector3) -> void:
	if ocean:
		center_chart(focus)
		water_node.position = Vector3(snappedf(focus.x,2.),.12,snappedf(focus.z,2.))
		if dirty.has("water"): water_tex.update(water)
		if dirty.has("ore"): ore_tex.update(ore_img)
		if dirty.has("occ"): occ_tex.update(occ_img)
		dirty.clear()
		return
	_place_ground(focus)
	_last_focus = focus
	if lazy:
		# по одному куску за кадр — без рывков
		if not _grow_queue.is_empty():
			grow_chunk(_grow_queue.pop_front())
		var fc := Vector2i(floori(focus.x / C / CHUNK), floori(focus.z / C / CHUNK))
		if fc != _last_chunk or (not _stream_settled and _grow_queue.is_empty()):
			_last_chunk = fc
			_grow_around(focus)
	_flora_shadows(focus)
	var s: float = grass.get_meta("spacing")
	grass.position = Vector3(snappedf(focus.x, s), 0, snappedf(focus.z, s))
	grass_mat.set_shader_parameter("center", focus)
	if grass_far:
		var fs: float = grass_far.get_meta("spacing")
		grass_far.global_position = Vector3(snappedf(focus.x, fs), 0, snappedf(focus.z, fs))
		grass_far.material_override.set_shader_parameter("center", focus)
	if grass.visible:
		_update_pushers(focus)
	if dirty.has("yard"):
		yard_tex.update(yard_img)
	if dirty.has("occ"):
		occ_tex.update(occ_img)
	if dirty.has("splat"):
		splat_tex.update(splat)
	if dirty.has("water"):
		water_tex.update(water)
	if dirty.has("ore"):
		ore_tex.update(ore_img)
	if dirty.has("height"):
		height_tex.update(_height_levels())
	dirty.clear()


func _occ(c: Vector2i) -> void:
	if not in_bounds(c):
		return
	var on: bool = blocks(c) or deposit.has(c) or (game != null and game.factory != null and (game.factory.grid.has(c) or c in game.factory.canopy_cells))
	var at := c-chart_origin if ocean else wc(c)
	if not ocean or Rect2i(0,0,W,W).has_point(at):
		occ_img.set_pixelv(at,Color.WHITE if on else Color.BLACK)
	dirty["occ"] = true


func set_occupied(c: Vector2i, on: bool) -> void:
	c = wc(c)
	if not in_bounds(c):
		return
	var built: bool = game.factory.grid.has(c) or game.factory.found.has(c) or c in game.factory.canopy_cells
	if not ocean: yard_img.set_pixelv(c, Color.WHITE if built else Color.BLACK)
	dirty["yard"] = true
	_occ(c)
	if on:
		clear_decor_at(c)


# ---------------------------------------------------------------- кисти редактора карты

func paint_splat(c: Vector2i, radius: float, channel: int, strength: float) -> void:
	edited = true
	var ri := ceili(radius)
	for dx in range(-ri, ri + 1):
		for dz in range(-ri, ri + 1):
			var p := c + Vector2i(dx, dz)
			if not in_bounds(p):
				continue
			var d := Vector2(dx, dz).length()
			if d > radius:
				continue
			var k := strength * (1.0 - d / (radius + 0.001))
			var col := splat.get_pixelv(wc(p))
			var v := [col.r, col.g, col.b, col.a]
			for i in 4:
				if channel < 0:
					v[i] = max(0.0, v[i] - k)
				elif i == channel:
					v[i] = min(1.0, v[i] + k)
				else:
					v[i] = max(0.0, v[i] - k * 0.5)
			splat.set_pixelv(wc(p), Color(v[0], v[1], v[2], v[3]))
	dirty["splat"] = true


func paint_water(c: Vector2i, radius: float, on: bool) -> void:
	edited = true
	var ri := ceili(radius)
	for dx in range(-ri, ri + 1):
		for dz in range(-ri, ri + 1):
			var p := c + Vector2i(dx, dz)
			if in_bounds(p) and Vector2(dx, dz).length() <= radius:
				water.set_pixelv(wc(p), Color(1, 0, 0) if on else Color(0, 0, 0))
				if on:
					remove_node(p)
	dirty["water"] = true


# ---------------------------------------------------------------- сохранение карты

func to_map() -> Dictionary:
	if lazy and not edited and not gen_args.is_empty():
		# большая случайная карта: вместо картинок — зерно и настройки, она построится заново точно такой же
		var objs2 := []
		for c in nodes:
			var n2: Node_ = nodes[c]
			objs2.append([n2.res, c.x, c.y, snappedf(n2.xf.basis.get_scale().x, 0.01), snappedf(n2.xf.basis.get_euler().y, 0.01)])
		return {"order_price": order_price, "orders_placed": orders_placed, "ordered_fields": _field_records(), "size": W, "wrap": wrap, "start": [center.x, center.y], "regen": gen_args, "objects": objs2, "seed": used_seed, "lazy": true,
			"flora_cfg": flora_cfg, "chunks": chunks_done.keys().map(func(k): return [k.x, k.y])}
	var objs := []
	for c in nodes:
		var n: Node_ = nodes[c]
		var b := n.xf.basis
		objs.append([n.res, c.x, c.y, snappedf(b.get_scale().x, 0.01), snappedf(b.get_euler().y, 0.01)])
	var dep := []
	for c in deposit:
		if dep_purity.has(c):
			dep.append([c.x, c.y, deposit[c], dep_purity[c]])
		else:
			dep.append([c.x, c.y, deposit[c]])
	var ns := []
	for n in nests:
		ns.append([n.cell.x, n.cell.y])
	if ocean:
		var chunks := []
		for key in islands_by_chunk:
			var mask := PackedByteArray()
			mask.resize(ISLAND_CHUNK*ISLAND_CHUNK/8)
			for c in islands_by_chunk[key]:
				var local: Vector2i = c-key*ISLAND_CHUNK
				var bit := local.y*ISLAND_CHUNK+local.x
				mask[bit>>3] |= 1<<(bit%8)
			chunks.append([key.x,key.y,Marshalls.raw_to_base64(mask)])
		return {"size":W,"wrap":false,"start":[center.x,center.y],"island_chunks":chunks,"seed":used_seed,"deposits":deposits,"deposit_cells":dep,"ordered_fields":_field_records(),"order_price":order_price,"orders_placed":orders_placed,"objects":objs}
	return {"order_price": order_price, "orders_placed": orders_placed, "ordered_fields": _field_records(), "size": W, "wrap": wrap, "start": [center.x, center.y], "splat": _img64(splat), "water": _img64(water), "height": _img64(height), "deposits": deposits,
		"deposit_cells": dep, "objects": objs, "nests": ns, "seed": used_seed, "lazy": lazy, "flora_cfg": flora_cfg,
		"chunks": chunks_done.keys().map(func(k): return [k.x, k.y])}


func _img64(img: Image) -> String:
	var raw := img.get_data()
	return "%d:%s" % [raw.size(), Marshalls.raw_to_base64(raw.compress(FileAccess.COMPRESSION_DEFLATE))]


func _img_from64(s: String, fmt: int) -> Image:
	var parts := s.split(":", true, 1)
	var raw := Marshalls.base64_to_raw(parts[1]).decompress(int(parts[0]), FileAccess.COMPRESSION_DEFLATE)
	return Image.create_from_data(W, W, false, fmt, raw)


func load_map(m: Dictionary) -> void:
	rng.randomize()
	if m.has("regen"):
		generate(int(m.regen.get("seed", 1)), m.regen.get("wd", {}), true)
	else:
		setup_size(128 if ocean else int(m.get("size",384)),m.get("wrap",null))
	if not ocean and m.has("splat"):
		splat = _img_from64(m.splat, Image.FORMAT_RGBA8)
	if not ocean and m.has("water"):
		water = _img_from64(m.water, Image.FORMAT_R8)
	if not ocean and m.has("height"):
		height = _img_from64(m.height, Image.FORMAT_RH)
	if m.has("start"):
		center = Vector2i(int(m.start[0]), int(m.start[1]))
	if ocean:
		water.fill(Color.WHITE)
		height.fill(Color(.76,0,0))
		for pair in m.get("island_tiles", []):
			set_land(Vector2i(int(pair[0]),int(pair[1])),true)
		for row in m.get("island_chunks",[]):
			var anchor := Vector2i(int(row[0]),int(row[1]))*ISLAND_CHUNK
			var mask := Marshalls.base64_to_raw(row[2])
			if mask.size()!=ISLAND_CHUNK*ISLAND_CHUNK/8: continue
			for j in mask.size():
				if mask[j]==0: continue
				for bit in 8:
					if mask[j] & (1<<bit):
						var index := j*8+bit
						set_land(anchor+Vector2i(index%ISLAND_CHUNK,index/ISLAND_CHUNK),true)
	if m.has("deposits"):
		deposits = m.get("deposits", [])
	used_seed = int(m.get("seed", used_seed))
	lazy = bool(m.get("lazy", false))
	flora_cfg = m.get("flora_cfg", {})
	chunks_done.clear()
	for k in m.get("chunks", []):
		chunks_done[Vector2i(int(k[0]), int(k[1]))] = true
	if lazy:
		_setup_flora()
	for d in m.get("deposit_cells", []):
		set_deposit(Vector2i(int(d[0]), int(d[1])), int(d[2]))
		if d.size() > 3:
			set_purity(Vector2i(int(d[0]), int(d[1])), str(d[3]))
	order_price = int(m.get("order_price", 1000))
	orders_placed = int(m.get("orders_placed", 0))
	ordered_fields.clear()
	for record in m.get("ordered_fields", []):
		var origin := Vector2i(int(record[0]), int(record[1]))
		ordered_fields[origin] = [int(record[2]), int(record[3]), str(record[4])]
		if m.has("regen"):
			for c in field_cells(origin, int(record[3])):
				set_deposit(c, int(record[2]))
				set_purity(c, str(record[4]))
	for o in m.get("objects", []):
		var c := Vector2i(int(o[1]), int(o[2]))
		var s := float(o[3]) if o.size() > 3 else 1.0
		var rot := float(o[4]) if o.size() > 4 else 0.0
		add_node(str(o[0]), c, Transform3D(Basis(Vector3.UP, rot).scaled(Vector3.ONE * s), cell_to_world(c)))
	for n in m.get("nests", []):
		add_nest(Vector2i(int(n[0]), int(n[1])))
	_last_focus = cell_to_world(center)
	_build_visuals()


# ---------------------------------------------------------------- запросы

func in_bounds(c: Vector2i) -> bool:
	if ocean: return true
	if wrap_w > 0:
		return true
	return c.x >= 0 and c.y >= 0 and c.x < W and c.y < W


func water_at(c: Vector2i) -> bool:
	if ocean: return not island_cells.has(c)
	return in_bounds(c) and water.get_pixelv(wc(c)).r > 0.5


func deposit_item(c: Vector2i) -> String:
	c = wc(c)
	if not deposit.has(c):
		return ""
	var it := str(dep_override[c]) if dep_override.has(c) else str(deposits[deposit[c]].get("item", ""))
	return "" if DB.locked.has("d:" + it) else it


var _hard_msg_ms := -100000


## 17.10: какой бур нужен для залежи (поле «Нужен бур Mk…»); 1 — любой.
func deposit_miner_tier(c: Vector2i) -> int:
	c = wc(c)
	if not deposit.has(c):
		return 1
	return int(deposits[deposit[c]].get("miner_tier", 1))


## Залежи, которые ещё не открыты в дереве открытий, не видны и не добываются.
func deposit_hidden(idx: int) -> bool:
	return idx >= 0 and idx < deposits.size() and DB.locked.has("d:" + str(deposits[idx].get("item", "")))


## Перерисовать пятна месторождений (после открытия узла с новыми залежами).
func reveal_deposits() -> void:
	for c in deposit:
		set_deposit(c, deposit[c])


func blocked_for_build(c: Vector2i) -> bool:
	return not in_bounds(c) or blocks(c) or nest_cells.has(c) or water_at(c)


func blocked_for_walk(c: Vector2i) -> bool:
	return not in_bounds(c) or blocks(c) or water_at(c)


static func cell_to_world(c: Vector2i) -> Vector3:
	return Vector3((c.x + 0.5) * C, 0.0, (c.y + 0.5) * C)


static func world_to_cell(p: Vector3) -> Vector2i:
	return wc(Vector2i(floori(p.x / C), floori(p.z / C)))


## Клетка с учётом зацикленного мира.
static func wc(c: Vector2i) -> Vector2i:
	if wrap_w <= 0:
		return c
	return Vector2i(posmod(c.x, wrap_w), posmod(c.y, wrap_w))


## Кратчайший вектор от a к b (в зацикленном мире — через край, если так ближе).
static func delta(a: Vector3, b: Vector3) -> Vector3:
	var d := b - a
	if wrap_w > 0:
		var s := wrap_w * C
		d.x -= roundf(d.x / s) * s
		d.z -= roundf(d.z / s) * s
	return d


static func dist(a: Vector3, b: Vector3) -> float:
	var d := delta(a, b)
	d.y = 0.0
	return d.length()


## Положение внутри мира (после перехода через край).
static func wrap_pos(p: Vector3) -> Vector3:
	if wrap_w <= 0:
		return p
	var s := wrap_w * C
	return Vector3(fposmod(p.x, s), p.y, fposmod(p.z, s))


func update_nests(t: float) -> void:
	for n in nests:
		if not n.alive:
			continue
		var p := 1.0 + 0.12 * sin(t * 2.5 + n.pos.x)
		n.core.scale = Vector3.ONE * 2.6 * p
		n.light.light_energy = 2.0 + 1.5 * sin(t * 2.5 + n.pos.x)


func nest_alive_count() -> int:
	var k := 0
	for n in nests:
		if n.alive:
			k += 1
	return k


# ---------------------------------------------------------------- собираемое у старта

## Немного веток, кустов и лопухов вокруг штаба, чтобы было что собрать в первую минуту.
func _landing_scale() -> int:
	return 3 if int(gen_args.get("wd", {}).get("landing_canyon", 0)) >= 2 else 1

func _landing_spring() -> void:
	var stretch := _landing_scale()
	for z in [-4,-5,-6,-3]:
		for x in range(-17 * stretch,-6 * stretch):
			var shore: Vector2i = center + Vector2i(x,z*stretch)
			if not water_at(shore) or water_at(shore+Vector2i.LEFT):
				continue
			var foot := cell_to_world(shore)
			foot.y = .18
			for step_back in [2,3,4]:
				var lip := cell_to_world(shore+Vector2i.LEFT*step_back*stretch)
				lip.y = height_at(lip)+.13
				if lip.y < 2.0:
					continue
				preload("res://scripts/geology_water.gd").falls(self,lip,foot,2.15)
				return


func _cut_landing_canyon() -> void:
	# Walkable eastern plateau, spring-fed western gully and a stepped northern ridge.
	var stretch := _landing_scale()
	for iz in range(-26 * stretch, 18 * stretch):
		for ix in range(-26 * stretch, 20 * stretch):
			var x := float(ix)/stretch
			var z := float(iz)/stretch
			var cell := wc(center + Vector2i(ix,iz))
			if not in_bounds(cell):
				continue
			var phase := float(used_seed % 13)*.08
			var bank := -9.5 + 1.4*sin(z*.22 + phase) - .16*z
			var length_fade := 1.0 - smoothstep(11.,19.,absf(z+3.))
			var width := 2.5*length_fade
			var channel := absf(x-bank)
			if width > .35 and channel < width:
				_set_water(cell)
				height.set_pixelv(cell,Color(-.60,0,0))
				splat.set_pixelv(cell,Color(.55,0,.40,0))
				continue
			var ledge := smoothstep(.05,1.7,bank-x-width)*length_fade
			var ridge := exp(-pow((z+14.+2.*sin(x*.31)) / 3.5,2.))*smoothstep(4.,9.,Vector2(x,z).length())
			var fade := 1.0 - smoothstep(17.,25.,Vector2(x,z+3).length())
			var h := maxf(ledge * (6.0+2.9*sin(z*.48)+1.2*cos(x*.88)),ridge*(5.+2.*cos(x*.53))) * fade
			if h > .24:
				h = lerpf(h, snappedf(h,.84),.63) * stretch
				height.set_pixelv(cell,Color(maxf(h_cell(cell),h),0,0))
				var tint := splat.get_pixelv(cell)
				tint.b = maxf(tint.b,smoothstep(.24,1.5,h)*.94)
				splat.set_pixelv(cell,tint)


func _landing_groves() -> void:
	# An open approach on the south-east side leads from the airlock to the first build area.
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = used_seed ^ 0x62c8a
	var pockets := [Vector2i(-6,-3), Vector2i(-3,7), Vector2i(7,-4), Vector2i(-6,-9),Vector2i(3,-9),Vector2i(-9,6)]
	for off in [Vector2i(-12,-8),Vector2i(-13,-5),Vector2i(-14,-2),Vector2i(-6,-12),Vector2i(-3,-13),Vector2i(6,-11),Vector2i(10,-10)]:
		var c: Vector2i = center + off * _landing_scale()
		if in_bounds(c) and not water_at(c) and not deposit.has(c) and not nest_cells.has(c):
			var b := Basis(Vector3.UP,local_rng.randf()*TAU).scaled(Vector3.ONE*local_rng.randf_range(1.7,2.35))
			add_node("basalt_buttress",c,Transform3D(b,cell_to_world(c)))
	var undergrowth := [Vector2i(-1,1),Vector2i(1,2),Vector2i(2,0),Vector2i(-2,-1)]
	for i in pockets.size():
		var anchor: Vector2i = center + pockets[i]
		for j in 5:
			var cell := anchor
			var res := "tree_oak" if i != 1 else "colony_monolith"
			if j > 0:
				cell += undergrowth[(i+j-1)%undergrowth.size()]
				res = "amethyst_garden" if j in [1,3] else ("glow_shroom" if j == 2 else "coral_fern")
			if not in_bounds(cell) or water_at(cell) or nodes.has(cell) or nest_cells.has(cell) or deposit.has(cell):
				continue
			if cell.distance_to(center) < 4.6 or not DB.data.resources.has(res):
				continue
			if j == 1 or j == 4:
				for delta in [Vector2i(1,-1),Vector2i(0,1),Vector2i(-2,1)]:
					var fringe: Vector2i = cell+delta
					if in_bounds(fringe) and fringe.distance_to(center) > 4.6 and not water_at(fringe) and not deposit.has(fringe) and not nest_cells.has(fringe):
						add_node("coral_fern",fringe,Transform3D(Basis(Vector3.UP,local_rng.randf()*TAU).scaled(Vector3.ONE*local_rng.randf_range(.78,1.4)),cell_to_world(fringe)))
			var pos := cell_to_world(cell)
			var scale_k := local_rng.randf_range(.82,1.15) if j==0 else local_rng.randf_range(1.25,1.65)
			var basis := Basis(Vector3.UP,local_rng.randf()*TAU).scaled(Vector3.ONE*scale_k)
			add_node(res,cell,Transform3D(basis,pos))


func _start_gatherables(list: Dictionary, clear_r: int) -> void:
	for res in list:
		if not DB.data.resources.has(res):
			continue
		var placed := 0
		var tries := 0
		while placed < int(list[res]) and tries < 200:
			tries += 1
			var a := rng.randf() * TAU
			var r := rng.randf_range(clear_r - 3.0, clear_r + 9.0)
			var c := center + Vector2i(roundi(cos(a) * r), roundi(sin(a) * r))
			if c.distance_to(center) < 5.0 or water_at(c) or nodes.has(c) or deposit.has(c):
				continue
			if add_node(res, c) != null:
				placed += 1


# ---------------------------------------------------------------- украшения земли

var decor_mm := {}        # "модель|чанк" -> MultiMeshInstance3D
var decor_cells := {}     # клетка -> [[ключ, индекс], ...]
var _tree_near := PackedByteArray()
static var _decor_meshes := {}

## Где лежит клетка: луг, лес, опушка, сухая земля, песок, снег или берег.
## Считается по уже готовой карте, поэтому работает и для нарисованных в редакторе карт.
func zone_at(c: Vector2i) -> String:
	if ocean: return "shore"
	var sp := splat.get_pixelv(wc(c))
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(2, 0), Vector2i(0, 2), Vector2i(-2, 0), Vector2i(0, -2)]:
		if water_at(c + d):
			return "shore"
	if sp.g > 0.4:
		return "sand"
	if sp.a > 0.4:
		return "snow"
	var tn := 0
	if _tree_near.size() == W * W:
		tn = _tree_near[wc(c).y * W + wc(c).x]
	else:
		for dx in range(-3, 4):
			for dz in range(-3, 4):
				var n: Node_ = nodes.get(wc(c + Vector2i(dx, dz)))
				if n != null and str(DB.data.resources.get(n.res, {}).get("category", "")) == "Деревья":
					tn += 1
	if tn >= 3:
		return "forest"
	if tn >= 1:
		return "forest_edge"
	if sp.r > 0.3 or sp.b > 0.4:
		return "dry"
	return "meadow"


func _count_trees() -> void:
	_tree_near = PackedByteArray()
	_tree_near.resize(W * W)
	for c in nodes:
		var n: Node_ = nodes[c]
		if str(DB.data.resources.get(n.res, {}).get("category", "")) != "Деревья":
			continue
		for dx in range(-3, 4):
			for dz in range(-3, 4):
				var p := wc(c + Vector2i(dx, dz))
				if p.x >= 0 and p.y >= 0 and p.x < W and p.y < W:
					var i := p.y * W + p.x
					_tree_near[i] = mini(255, _tree_near[i] + 1)


## Модель украшения одним мешем: все детали слиты, цвет — в вершинах (так тысячи кустиков рисуются быстро).
static func decor_mesh(model: String) -> Array:
	if _decor_meshes.has(model) and _decor_meshes[model][2] == DB.revision:
		return _decor_meshes[model]
	var parts := ModelLib.parts_of(model, true)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mat: Material = null
	for pt in parts:
		var mesh: Mesh = pt[0]
		var xf: Transform3D = pt[2]
		if mat == null or str(ModelLib.model(model).get("parts", [{}])[0].get("anim", "")) == "":
			mat = pt[1]
		var col: Color = pt[3]
		for si in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(si)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var norms = arr[Mesh.ARRAY_NORMAL]
			var idx = arr[Mesh.ARRAY_INDEX]
			var vcs = arr[Mesh.ARRAY_COLOR]
			var uvs = arr[Mesh.ARRAY_TEX_UV]
			var has_vc: bool = vcs is PackedColorArray and vcs.size() == verts.size()
			var has_uv: bool = uvs is PackedVector2Array and uvs.size() == verts.size()
			var order: Array = Array(idx) if idx is PackedInt32Array and idx.size() > 0 else range(verts.size())
			for vi in order:
				# у готовых мешей (Blender) цвет уже в вершинах
				st.set_color(col * vcs[vi] if has_vc else col)
				if has_uv:
					st.set_uv(uvs[vi])
				if norms is PackedVector3Array and norms.size() > vi:
					st.set_normal((xf.basis * norms[vi]).normalized())
				st.add_vertex(xf * verts[vi])
	var out := [st.commit(), mat, DB.revision]
	_decor_meshes[model] = out
	return out


func clear_decor() -> void:
	for k in decor_mm:
		decor_mm[k].queue_free()
	decor_mm.clear()
	decor_cells.clear()


## Украшения земли: при галочке «Меньше растительности» — прежний редкий набор (decor_lite), иначе полный.
static func decor_list() -> Array:
	# 1.4: look.decor_keep — оставить только эти модели (камешки), остальное не растёт
	var keep: Array = DB.data.world.get("look", {}).get("decor_keep", [])
	if not keep.is_empty():
		var out := []
		for d in DB.data.world.get("decor", []):
			if str(d.get("model", "")) in keep:
				out.append(d)
		return out
	# 1.4: look.no_decor — без цветов, кустиков и травы-моделей (они сильно нагружают видеокарту)
	if bool(DB.data.world.get("look", {}).get("no_decor", false)):
		return []
	if bool(Prefs.get_value("flora_less", false)):
		var lite: Array = DB.data.world.get("decor_lite", [])
		if not lite.is_empty():
			return lite
	return DB.data.world.get("decor", [])


## Расставить украшения по карте (список «Украшения земли» в данных мира). Большая карта — кусками.
func _make_decor() -> void:
	if ocean: return
	clear_decor()
	decor_done.clear()
	var list: Array = decor_list()
	if list.is_empty() or not bool(Prefs.get_value("decor", true)):
		return
	if lazy:
		_tree_near = PackedByteArray()
		_grow_around(_last_focus, true)
		return
	_count_trees()
	for cx in ceili(float(W) / CHUNK):
		for cz in ceili(float(W) / CHUNK):
			_decor_chunk(Vector2i(cx, cz))


var _last_focus := Vector3.ZERO
var _last_chunk := Vector2i(-99999, -99999)

## Украшения одного куска карты.
func _decor_chunk(cc: Vector2i) -> void:
	if decor_done.has(cc):
		return
	decor_done[cc] = true
	var list: Array = decor_list()
	if list.is_empty() or not bool(Prefs.get_value("decor", true)):
		return
	var dens := float(DB.data.world.get("look", {}).get("grass_density", 1.0))
	var r := RandomNumberGenerator.new()
	r.seed = hash([used_seed + 991, cc.x, cc.y])
	var per := {}   # ключ -> [модель, [матрицы], [клетки]]
	var lite := bool(Prefs.get_value("flora_less", false))
	var max_cell := 2 if lite else int(DB.data.world.get("look", {}).get("decor_per_cell", 2))
	# «пятна»: у записи с полем cluster свой шум — цветы ложатся полянами, папоротник зарослями
	var noises := []
	for i in list.size():
		var cl := float(list[i].get("cluster", 0.0))
		if cl <= 0.0 or lite:
			noises.append(null)
			continue
		var fn := FastNoiseLite.new()
		fn.seed = used_seed + 7717 + i * 131
		fn.frequency = 1.0 / cl
		noises.append(fn)
	for x in range(cc.x * CHUNK, mini(W, cc.x * CHUNK + CHUNK)):
		for z in range(cc.y * CHUNK, mini(W, cc.y * CHUNK + CHUNK)):
			var c := Vector2i(x, z)
			if water_at(c) or nodes.has(c) or deposit.has(c) or nest_cells.has(c) or occ_img.get_pixel(x, z).r > 0.5:
				continue
			if c.distance_to(center) < 4.0:
				continue
			var zone := zone_at(c)
			var placed := 0
			var start := r.randi() % list.size()
			for k in list.size():
				if placed >= max_cell:
					break
				var di := (start + k) % list.size()
				var d: Dictionary = list[di]
				var z2: String = str(d.get("zone", "any"))
				if z2 != "any" and z2 != zone:
					continue
				var dd := float(d.get("density", 0.05)) * dens
				if noises[di] != null:
					var nv: float = noises[di].get_noise_2d(float(x), float(z))
					var thr := float(d.get("cluster_thr", 0.15))
					if nv < thr:
						continue
					dd *= clampf((nv - thr) / 0.12, 0.25, 1.0)
				if r.randf() >= dd:
					continue
				var model: String = str(d.get("model", ""))
				if model == "" or not DB.data.models.has(model):
					continue
				var sc: Array = d.get("scale", [0.8, 1.2])
				var s := r.randf_range(float(sc[0]), float(sc[1]))
				var pos := cell_to_world(c) + Vector3(r.randf_range(-0.8, 0.8), 0, r.randf_range(-0.8, 0.8))
				var normal := ground_normal(pos, .4)
				if normal.y < .75:
					continue
				pos.y = height_at(pos) - .025
				var xf := Transform3D(Basis(Quaternion(Vector3.UP, normal)) * Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3.ONE * s), pos)
				# куски по 16 клеток: дальность видимости считается от середины куска, мелочь у края не пропадает раньше времени
				var key := "%s|%d|%d" % [model, floori(x / 16.0), floori(z / 16.0)]
				if not per.has(key):
					per[key] = [model, [], [], float(d.get("far", 0.0))]
				per[key][1].append(xf)
				per[key][2].append(c)
				placed += 1
	var far := float(DB.data.world.get("look", {}).get("decor_distance", 85.0))
	for key in per:
		var e: Array = per[key]
		var dm := decor_mesh(e[0])
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = dm[0]
		mm.instance_count = e[1].size()
		# дальность видимости считается от точки узла — ставим узел в центр чанка
		var mid := Vector3.ZERO
		for xf0 in e[1]:
			mid += xf0.origin
		mid /= float(e[1].size())
		mid.y = 0.0
		for i in e[1].size():
			var xf1: Transform3D = e[1][i]
			xf1.origin -= mid
			mm.set_instance_transform(i, xf1)
			mm.set_instance_color(i, Color.WHITE)
			mm.set_instance_custom_data(i, Color(1, randf(), 0, 0))
			var c: Vector2i = e[2][i]
			if not decor_cells.has(c):
				decor_cells[c] = []
			decor_cells[c].append([key, i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = dm[1]
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.position = mid
		mmi.visibility_range_end = float(e[3]) if float(e[3]) > 0.0 else far
		mmi.visibility_range_end_margin = 8.0
		add_child(mmi)
		decor_mm[key] = mmi


## Убрать украшения с клетки (там поставили здание или выросло дерево).
func clear_decor_at(c: Vector2i) -> void:
	c = wc(c)
	if not decor_cells.has(c):
		return
	for e in decor_cells[c]:
		var mmi: MultiMeshInstance3D = decor_mm.get(e[0])
		if mmi:
			var xf := mmi.multimesh.get_instance_transform(e[1])
			mmi.multimesh.set_instance_transform(e[1], Transform3D(Basis().scaled(Vector3.ZERO), xf.origin))
	decor_cells.erase(c)


# ---------------------------------------------------------------- внешний вид (палитра)

## Цвета земли, травы, воды и гор из «Мир и генератор карты» → «Внешний вид».
# 1.4: осенняя палитра (look.autumn поверх look): жёлто-оливковая трава, оранжевые и красные кроны
static func autumn_on() -> bool:
	if "--autumn" in OS.get_cmdline_user_args() or "--autumn" in OS.get_cmdline_args():
		return true
	if "--summer" in OS.get_cmdline_user_args() or "--summer" in OS.get_cmdline_args():
		return false
	# выбирается при создании мира («Вид природы»), хранится в правилах мира сохранения
	return str(DB.data.get("settings", {}).get("season_look", "summer")) == "autumn"


## 1.4: земля «сочного» вида (трава-текстура, голая земля у залежей, лужи) — и с объёмной травой, и с простой
static func ground_lush() -> bool:
	var lk: Dictionary = DB.data.world.get("look", {})
	return str(lk.get("grass_style", "")) == "lush" or bool(lk.get("ground_lush", false))


static func look() -> Dictionary:
	var lk: Dictionary = DB.data.world.get("look", {})
	if autumn_on() and lk.get("autumn", {}) is Dictionary and not lk.get("autumn", {}).is_empty():
		lk = lk.duplicate()
		lk.merge(lk["autumn"], true)
	return lk


func apply_look() -> void:
	var lk: Dictionary = look()
	var au := autumn_on() and lk.has("autumn")
	RenderingServer.global_shader_parameter_set("autumn", 1.0 if au else 0.0)
	var col := func(k: String, def: String) -> Color: return DB.color(lk.get(k, def))
	if ground_mat:
		for pair in [["c_grass_a", "grass_a", "#3f7a26"], ["c_grass_b", "grass_b", "#6f9e2e"], ["c_grass_dry", "grass_dry", "#a4a046"],
				["c_clover", "clover", "#2f6e2a"], ["c_dirt", "dirt", "#7a5434"], ["c_mud", "mud", "#4a3524"], ["c_sand", "sand", "#d9c48a"],
				["c_rock", "rock", "#8a857c"], ["c_snow", "snow", "#eef3f8"]]:
			ground_mat.set_shader_parameter(pair[0], col.call(pair[1], pair[2]))
		ground_mat.set_shader_parameter("detail", float(lk.get("detail", 1.0)))
		ground_mat.set_shader_parameter("tuft_k", float(lk.get("tuft", 0.0)))
		var tt: Array = lk.get("tex_tile", [3.5, 4.0, 5.0, 6.0, 6.0, 3.0])
		if tt.size() >= 6:
			ground_mat.set_shader_parameter("tex_tile", Vector4(tt[0], tt[1], tt[2], tt[3]))
			ground_mat.set_shader_parameter("tex_tile2", Vector2(tt[4], tt[5]))
		ground_mat.set_shader_parameter("tex_tint", col.call("tex_tint", "#ffffff"))
		ground_mat.set_shader_parameter("lush", ground_lush())
		ground_mat.set_shader_parameter("recolor", float(lk.get("ground_recolor", 0.4)))
	for m in [ground_mat, grass_mat, grass_far.material_override if grass_far and is_instance_valid(grass_far) else null]:
		if m != null:
			m.set_shader_parameter("c_lush_a", col.call("lush_a", "#33781c"))
			m.set_shader_parameter("c_lush_b", col.call("lush_b", "#559a26"))
			m.set_shader_parameter("c_lush_tip", col.call("lush_tip", "#a6d849"))
			m.set_shader_parameter("c_path", col.call("path", "#8c5b38"))
			m.set_shader_parameter("dirt_r", float(lk.get("dirt_r", 3.5)))
			m.set_shader_parameter("puddle_k", float(lk.get("puddles", 0.0)))
	if grass_mat:
		grass_mat.set_shader_parameter("c_base", col.call("blade_base", "#2f5e1c"))
		grass_mat.set_shader_parameter("c_tip", col.call("blade_tip", "#9cc94a"))
		grass_mat.set_shader_parameter("c_dry", col.call("grass_dry", "#a4a046"))
		grass_mat.set_shader_parameter("c_grass_a", col.call("grass_a", "#3f7a26"))
		grass_mat.set_shader_parameter("c_grass_b", col.call("grass_b", "#6f9e2e"))
		grass_mat.set_shader_parameter("c_clover", col.call("clover", "#2f6e2a"))
		grass_mat.set_shader_parameter("paint", float(lk.get("grass_paint", 0.0)))
	if water_mat:
		water_mat.set_shader_parameter("c_deep", col.call("water_deep", "#0f4a6e"))
		water_mat.set_shader_parameter("c_shallow", col.call("water_shallow", "#2f9cb0"))
		water_mat.set_shader_parameter("c_foam", col.call("foam", "#e8f6ff"))
