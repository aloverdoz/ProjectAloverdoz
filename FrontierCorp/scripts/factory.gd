class_name Factory
extends Node3D
## Завод: здания, конвейеры, машины, энергосеть.
## Что умеет здание, задаёт поле "behavior" в buildings.json, а числа — поле "params".
## Логика считается 20 раз в секунду, все здания одного типа рисуются одним MultiMesh,
## а груз на лентах двигает видеокарта.

const C := World.C
const TICK := 0.04   # 25 тиков в секунду: лента Mk5 (1360 в минуту) успевает
const DIRS := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
const WALKABLE := ["belt", "floor", "foundation", "pipe"]
const ELECTRIC_NODES := ["generator", "pole", "battery", "hq"]

class B:
	var type := ""
	var ev_halt := false   # событие мира (солнечный выброс) остановило машину
	var beh := ""
	var cell := Vector2i.ZERO
	var dir := 0
	var size := 1
	var hp := 100.0
	var maxhp := 100.0
	# лента / разделитель
	var item := ""
	var t_in := 0.0
	var t_free := -1.0     # 1.1.15: точное время, когда лента освободилась (предмет из здания въезжает без округления до такта)
	var next = null
	var waiters: Array = []
	var kind := 0          # 0 прямая, +1 / -1 поворот
	var rr := 0            # очередь выходов разделителя / входов соединителя
	var cfg := {}          # настройки умных разделителей и соединителей (фильтры, приоритеты)
	var bstate := {}       # таймеры блоков поведения (см. Blocks)
	var blk := false       # собрано из блоков поведения
	var paid = null        # что заплачено при постройке (столько и вернётся при разборе)
	# машины и склады
	var inv: Inventory = null    # склад, вход машины
	var out: Inventory = null    # выход машины
	var fuel: Inventory = null   # топливо
	var fuel_t := 0.0
	var recipe := ""             # выбранный рецепт ("" — сам выбирает)
	var crafting := ""
	var prog := 0.0
	var timer := 0.0
	var want := false
	var active := false
	var net := -1                # номер энергосети
	var energy := 0.0            # заряд аккумулятора
	var tripped := false         # выбило пробки (генератор, опора, штаб)
	var feeder = null            # 21: станция энергии, от которой питается здание
	var pw_state := 0            # 21: 0 — нет станции рядом, 1 — питается, 2 — станция рядом, но ей не хватило мощности
	var idle_key := -1           # 21: машина ждёт сырья — версия инвентарей при последней проверке
	var idle_until := 0
	var period := 0.5            # лента: секунд на одну клетку (из «Предметов в минуту»)
	var mine_period := 0.0       # бур: секунд на штуку (качество залежи × множитель бура), 0 — пересчитать
	var mine_rev := -1
	var made: Array = []         # машина: когда сделаны последние предметы (для «в минуту»)
	var last_rid := ""           # машина: последний рецепт (для «в минуту» в режиме «Авто»)
	# бой
	var cd := 0.0
	var pitch := 0.0
	var recoil := 0.0
	var aim := 0.0
	var target = null
	var flash := 0.0
	var light: OmniLight3D = null
	var dead := false
	# высота: здание стоит на земле или на фундаменте
	var y := 0.0                 # низ здания
	var top := 0.0               # фундамент: верх (на нём строят)
	# жидкости
	var fluid := ""              # труба или бак: какая жидкость (раскладывается из сети при перестройке и сохранении)
	var famt := 0.0              # труба или бак: сколько её здесь
	var fnet := -1               # номер сети труб
	var lvl := 1                 # 14.10: уровень объединения (две одинаковые рядом → 2 … 5)
	var mult := 1.0              # во сколько раз сильнее (из «Сила по уровням»)
	var host = null              # составное здание, в которое встроено это
	var subs: Array = []         # встроенные здания (если это основа составного)
	var csat := 1.0              # составное: насколько хватает энергии (0..1)
	var trashed := 0             # сколько лишнего уничтожено (настройка «Лишнее: уничтожать»)
	var cen := 0.0               # составное: запас энергии во встроенных аккумуляторах
	var ccap := 0.0
	var grid_need := 0.0         # составное: сколько не хватает своей энергии (берётся из сети)
	var has_gen := false
	var surplus := 0.0           # 15.3: составное с генератором: свободная энергия, уходит в сеть по проводам
	var gen_cap := 0.0           # 15.3: сколько могут дать встроенные генераторы
	var cgen := 0.0              # 15.3: сколько дают сейчас
	var cneed := 0.0             # 15.3: сколько ест составное сейчас
	var deco: Node3D = null      # знак уровня, платформа сборной линии
	var nexts: Array = []        # 1.3: все выходы здания 2×2 и больше (по клетке передней стороны), next — первый из них
	var out_rr := 0              # 1.3: по очереди в каждый выход — поток делится поровну
	var lift := false            # 1.1.8: лифт для предметов (лента между ярусами)
	var pon := false             # 1.1.9: у здания свои порты (вход/выход только в определённых клетках)
	var pin: Array = []          # клетки снаружи, откуда лента может подавать (входы)
	var pin_side: Array = []     # сторона здания (0..3, мировая) для каждого входа
	var pout: Array = []         # клетка снаружи для выхода (одна)
	var pout_side: Array = []
	var pfuel := -1              # 1.1.11: номер входа для топлива (печь, коксовая печь…) или -1
	var pow_ov := -1.0           # 1.1.15: своя потребляемая мощность (канал штаба: клетки до штаба × 3), -1 — из паспорта
	var link_n := 0              # 1.1.15: канал штаба — счётчик предметов (каждый второй теряется)

	func center() -> Vector3:
		var o := (size - 1) * C * 0.5
		return World.cell_to_world(cell) + Vector3(o, y, o)

	func front() -> Vector2i:
		if size == 1:
			return World.wc(cell + DIRS[dir])
		# выход большого здания — середина передней стороны
		var mid := size / 2
		match dir:
			0: return World.wc(cell + Vector2i(size, mid))
			1: return World.wc(cell + Vector2i(mid, size))
			2: return World.wc(cell + Vector2i(-1, mid))
			_: return World.wc(cell + Vector2i(mid, -1))

	## 1.3: клетки перед передней стороной (выходы): у здания 2×2 — две, середина первой.
	func fronts() -> Array:
		if size == 1:
			return [front()]
		var out := [front()]
		for i in size:
			var c: Vector2i
			match dir:
				0: c = World.wc(cell + Vector2i(size, i))
				1: c = World.wc(cell + Vector2i(i, size))
				2: c = World.wc(cell + Vector2i(-1, i))
				_: c = World.wc(cell + Vector2i(i, -1))
			if not c in out:
				out.append(c)
		return out

	func p(key: String, def = null):
		if pow_ov >= 0.0 and key == "power":
			return pow_ov
		if type == "drone_port" and key == "power":
			var watts := float(DB.bparam(type, key, def))
			return watts + float(preload("res://scripts/carriers.gd").fleet_capacity(self)) * 0.006
		return DB.bparam(type, key, def)


var game
var grid := {}
var all: Array = []
var rev := 0                # 21: растёт при каждой постройке и сносе (кэши списков ниже)
var _having := {}           # параметр -> [rev, здания с этим параметром]
var belts: Array = []
var machines: Array = []   # всё, что считается каждый такт
var turrets: Array = []
var lights: Array = []
var power_nodes: Array = []
var consumers: Array = []     # здания, которым нужна энергия
var st_pairs: Array = []      # 21: [дальность, потребитель, станция] — кто в радиусе какой станции, ближние первыми
var st_acc := 0.0
var block_bldgs: Array = []   # здания с блоками поведения
var block_acc := 0.0
var loading := false           # идёт загрузка сохранения: события «построено» не срабатывают
var was_night := false
var hq: B
var found := {}                # клетка -> [фундаменты снизу вверх]
var renderers := {}
var item_renderers := {}       # "поворот|модель" -> PartRenderer груза на лентах
var belt_item_key := {}        # лента -> ключ рендерера, в котором сейчас её груз
var _belt_meshes := {}         # модель предмета -> меш для ленты (детали слиты в один)
var item_mats := {}
var belt_mats := {}
var port_rs := {}              # модель стыка -> PartRenderer
var port_keys := {}            # лента -> [[лента, сторона], ...]
var _face_cache := {}          # тип здания -> AABB нижней части модели
var acc := 0.0
var sim_time := 0.0
var tick_i := 0
var sched := {}
var hop_ticks := 10
var belt_speed := 2.0
var items_on_belts := 0
var stats := {"delivered": 0, "placed": 0}
var no_ammo_warned := 0.0
var flashing := {}
var damaged := {}
var nets: Array = []          # [{supply, demand, sat, stored, cap, tripped, over_t}]
var power_dirty := true
var links: Array = []         # провода: [[здание, здание], ...]
var net_hist := {}            # номер сети -> [[выработка, потребление, запас], ...] раз в секунду
var hist_t := 0.0
var trip_warned := 0.0
var wires: MeshInstance3D
var prof_tick := 0
var pipes: Array = []          # трубы и баки
var fnets: Array = []          # сети труб (см. _rebuild_fluids)
var fluid_dirty := true
var fluid_acc := 0.0
var arm_rs := {}               # модель отрезка трубы -> PartRenderer
var arm_keys := {}             # труба -> [[труба, сторона], ...]
var prof_ticks := 0
var fz: Fusion                 # 14.10: объединение зданий (fusion.gd)
var nuc: Nuclear               # 14.22: АЭС (nuclear.gd)
var tune_acc := 0.0            # 14.23: износ от перегрева настройки (tuning.gd)


func setup() -> void:
	fz = Fusion.new(self)
	nuc = Nuclear.new(self)
	Tuning._game = game
	belt_speed = float(DB.setting("belt_speed", 2.0)) * max(0.2, 1.0 + game.bonus("belt_speed"))
	hop_ticks = ceili(1.0 / belt_speed / TICK - 0.001)
	_make_belt_renderers()
	wires = MeshInstance3D.new()
	wires.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var wm := StandardMaterial3D.new()
	wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wm.albedo_color = Color(1, 1, 1)
	wm.vertex_color_use_as_albedo = true
	wm.cull_mode = BaseMaterial3D.CULL_DISABLED
	wires.material_override = wm
	add_child(wires)


func renderer(type: String) -> PartRenderer:
	if renderers.has(type):
		return renderers[type]
	var r := ModelLib.make_renderer(DB.building(type).get("model", type), true, false, true)
	r.chunk = render_chunk()
	add_child(r)
	renderers[type] = r
	return r


## Пересоздать всю графику (после правок моделей в редакторе).
func rebuild_visuals() -> void:
	for k in renderers:
		renderers[k].queue_free()
	for k in item_renderers:
		item_renderers[k].queue_free()
	for k in port_rs:
		port_rs[k].queue_free()
	for k in arm_rs:
		arm_rs[k].queue_free()
	arm_rs.clear()
	arm_keys.clear()
	renderers.clear()
	item_renderers.clear()
	belt_item_key.clear()
	_belt_meshes.clear()
	port_rs.clear()
	port_keys.clear()
	socket_keys.clear()
	canopy_key = null
	_face_cache.clear()
	_make_belt_renderers()
	for b in all:
		_add_visual(b)
		if b.beh == "turret":
			_aim_head(b)
		if b.size > 1:
			_update_sockets(b)
	_update_canopy()
	for b in belts:
		_update_ports(b)
		if b.bstate.get("rails", false):
			set_rails(b, true)
	for b in pipes:
		_update_arms(b)
	_show_fluid_colors(true)


# ---------------------------------------------------------------- графика лент

func _make_belt_renderers() -> void:
	for bt in belt_types():
		_make_belt_renderer(bt)


## Все виды лент (здания с поведением «Лента»): Mk1, Mk2, Mk3 и свои из редактора.
func belt_types() -> Array:
	var out := []
	for id in DB.data.buildings:
		if str(DB.data.buildings[id].get("behavior", "")) == "belt":
			out.append(id)
	if not "belt" in out:
		out.append("belt")
	return out


## Скорость ленты в предметах в секунду (поле «Предметов в минуту»; без него — правило «Скорость лент»).
func belt_rate(type: String) -> float:
	var pm := float(DB.bparam(type, "per_min", 0.0))
	var base := pm / 60.0 if pm > 0.0 else float(DB.setting("belt_speed", 2.0))
	return maxf(0.1, base * max(0.2, 1.0 + game.bonus("belt_speed")))


func _make_belt_renderer(bt: String) -> void:
	var belt_model: String = DB.building(bt).get("model", "belt")
	var edge := Color(0.42, 0.44, 0.47)
	var parts := ModelLib.parts_of(belt_model, false)
	if parts.size() > 0:
		edge = parts[0][3]
	var sp := belt_rate(bt)
	for k in [0, 1, -1]:
		var bm := ShaderMaterial.new()
		bm.shader = ModelLib.BELT_SHADER
		bm.set_shader_parameter("curve", float(k))
		bm.set_shader_parameter("speed", sp)
		belt_mats["%s@%d" % [bt, k]] = bm
		var r := PartRenderer.new()
		r.chunk = render_chunk()
		if k == 0:
			for pt in parts:
				var m: Material = pt[1]
				if m is ShaderMaterial and (m as ShaderMaterial).shader == ModelLib.BELT_SHADER:
					m = bm
				r.add_part(pt[0], m, pt[2], pt[3], false, pt[4], pt[5])
		else:
			r.add_part(_arc_mesh(k), bm, Transform3D.IDENTITY, edge, false)
			# 13.10: у поворота те же борта, планки, стойки, ролики и ножки, что у прямого куска — изогнутые по дуге
			for pt in parts:
				var m2: Material = pt[1]
				if m2 is ShaderMaterial and (m2 as ShaderMaterial).shader == ModelLib.BELT_SHADER:
					continue
				for xf2 in _bend_part(pt[2], k):
					r.add_part(pt[0], m2, xf2, pt[3], false, pt[4], pt[5])
		add_child(r)
		renderers["%s@%d" % [bt, k]] = r
		var mk := "%d|%s" % [k, sp]
		if not item_mats.has(mk):
			var im := ShaderMaterial.new()
			im.shader = ModelLib.ITEM_SHADER
			im.set_shader_parameter("curve", float(k))
			im.set_shader_parameter("speed", sp)
			item_mats[mk] = im


## Деталь прямой ленты (вдоль X от −1 до 1, поперёк Z) переносится на дугу поворота: радиус = 1 + z.
## Длинные детали (борта, планки) режутся на куски по дуге, короткие (стойки, ролики) просто поворачиваются.
func _bend_part(xf: Transform3D, k: int) -> Array:
	var o := xf.origin
	var r := 1.0 + o.z
	var cz := -1.0 * k
	var out := []
	var len_x := xf.basis.x.length()
	var n := 6 if len_x > 0.6 else 1
	for i in n:
		var x := o.x if n == 1 else -1.0 + (i + 0.5) * 2.0 / n
		var a := clampf((x + 1.0) * 0.5, 0.0, 1.0) * PI * 0.5
		var p := Vector3(1.0 - r * cos(a), o.y, cz + k * r * sin(a))
		var t := Vector3(r * sin(a), 0, k * r * cos(a)).normalized()
		var yaw := atan2(-t.z, t.x)
		var b: Basis
		if n == 1:
			b = Basis(Vector3.UP, yaw) * xf.basis
		else:
			var seg_len := PI * 0.5 * maxf(0.05, r) / n * 1.08
			b = Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(seg_len, xf.basis.y.length(), xf.basis.z.length()))
		out.append(Transform3D(b, p))
	return out


## Изогнутый кусок ленты: четверть кольца с центром в углу клетки.
func _arc_mesh(k: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 12
	var r0 := 0.35
	var r1 := 1.65
	var h := 0.26
	var cz := -1.0 * k
	var pts := func(a: float, r: float, y: float) -> Vector3:
		return Vector3(1.0 - r * cos(a), y, cz + k * r * sin(a))
	for i in seg:
		var a0 := float(i) / seg * PI * 0.5
		var a1 := float(i + 1) / seg * PI * 0.5
		var u0 := float(i) / seg
		var u1 := float(i + 1) / seg
		# верх
		_quad(st, pts.call(a0, r0, h), pts.call(a1, r0, h), pts.call(a1, r1, h), pts.call(a0, r1, h),
			Vector3.UP, Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 1), Vector2(u0, 1), k)
		# внутренняя и внешняя стенки
		var n_in: Vector3 = (Vector3(1, 0, cz) - pts.call((a0 + a1) * 0.5, 1.0, 0.0)).normalized()
		_quad(st, pts.call(a0, r0, 0), pts.call(a1, r0, 0), pts.call(a1, r0, h), pts.call(a0, r0, h),
			n_in, Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 0), Vector2(u0, 0), k)
		_quad(st, pts.call(a0, r1, h), pts.call(a1, r1, h), pts.call(a1, r1, 0), pts.call(a0, r1, 0),
			-n_in, Vector2(u0, 1), Vector2(u1, 1), Vector2(u1, 1), Vector2(u0, 1), k)
	return st.commit()


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2, k: int) -> void:
	# порядок вершин зависит от зеркала, чтобы лицевая сторона смотрела наружу
	var tris := [[a, ua, b, ub, c, uc], [a, ua, c, uc, d, ud]]
	for t in tris:
		var v0: Vector3 = t[0]
		var v1: Vector3 = t[2]
		var v2: Vector3 = t[4]
		var face := (v2 - v0).cross(v1 - v0)
		var order := [0, 2, 4] if face.dot(n) >= 0.0 else [0, 4, 2]
		for o in order:
			st.set_normal(n)
			st.set_uv(t[o + 1])
			st.add_vertex(t[o])


func _belt_r(b: B) -> PartRenderer:
	var key := "%s@%d" % [b.type, b.kind]
	if not renderers.has(key):
		_make_belt_renderer(b.type)
	return renderers[key]


# ---------------------------------------------------------------- стыки лент со зданиями
# Если лента везёт в здание или здание выдаёт на ленту, между ними рисуется мостик
# до стены здания и люк на стене. Вид — модель belt_port (или своя у здания).

func _port_r(model: String) -> PartRenderer:
	if port_rs.has(model):
		return port_rs[model]
	var r := PartRenderer.new()
	r.chunk = render_chunk()
	for pt in ModelLib.parts_of(model, true):
		r.add_part(pt[0], pt[1], pt[2], pt[3], true, pt[4], pt[5])
	add_child(r)
	port_rs[model] = r
	return r


## 1.3: направление стены, чтобы её длинная сторона шла вдоль шага линии step.
func wall_dir(type: String, step: Vector2i) -> int:
	var bb := _face_box(type)
	var long_x := bb.size.x >= bb.size.z
	var along_x := step.x != 0
	return 0 if long_x == along_x else 1


## Габарит нижней части модели здания (то, во что упирается лента), в осях здания.
func _face_box(type: String) -> AABB:
	if _face_cache.has(type):
		return _face_cache[type]
	var low := AABB()
	var any := AABB()
	var got_low := false
	var got_any := false
	for pt in ModelLib.parts_of(DB.building(type).get("model", type), false):
		var bb: AABB = (pt[2] as Transform3D) * (pt[0] as Mesh).get_aabb()
		any = bb if not got_any else any.merge(bb)
		got_any = true
		if bb.position.y < 0.5 and bb.size.y > 0.05:
			low = bb if not got_low else low.merge(bb)
			got_low = true
	var r := low if got_low else any
	if not got_any:
		r = AABB(Vector3(-0.8, 0, -0.8), Vector3(1.6, 1, 1.6))
	_face_cache[type] = r
	return r


func _clear_ports(b: B) -> void:
	for key in port_keys.get(b, []):
		for m in port_rs:
			port_rs[m].remove(key)
	port_keys.erase(b)


func _update_ports(b: B) -> void:
	_clear_ports(b)
	if b.dead or b.beh != "belt" or not bool(DB.setting("belt_ports", true)):
		return
	var keys := []
	var cb := b.center()
	for s in 4:
		var nb = grid.get(World.wc(b.cell + DIRS[s]))
		if nb == null or nb == b or nb.dead or nb.beh == "belt":
			continue
		var into: bool = b.next == nb and s == b.dir
		var from := false
		if nb.beh == "splitter":
			from = b.next != nb and b.cell in split_cells(nb) and _belt_starts_at(b, nb)
		elif nb.beh == "merger":
			from = nb.next == b
		else:
			from = (nb.front() == b.cell or b in nb.nexts) and s != b.dir
		if not into and not from:
			continue
		var bd := DB.building(nb.type)
		if bool(bd.get("no_ports", false)) or nb.pon:
			continue   # 1.1.9: у здания свои порты — мостик рисует оно само (_update_sockets)
		# где стена здания со стороны ленты
		var nc: Vector3 = cb + World.delta(cb, nb.center())
		var xf := Transform3D(_xform(nb).basis, nc)
		var box: AABB = xf * _face_box(nb.type)
		var dv := Vector3(DIRS[s].x, 0, DIRS[s].y)
		var fd := 0.0
		match s:
			0: fd = box.position.x - cb.x
			1: fd = box.position.z - cb.z
			2: fd = cb.x - box.end.x
			_: fd = cb.z - box.end.z
		var edge := C * 0.5
		fd = clampf(fd, edge - 0.05, C * 1.5)
		var length := fd - edge + 0.12
		var model: String = str(bd.get("port_model", ""))
		if model == "" or not DB.data.models.has(model):
			model = "belt_port"
		if not DB.data.models.has(model):
			return
		var r := _port_r(model)
		var key := [b, s]
		r.add(key, Transform3D(Basis(Vector3.UP, _dir_angle((s + 2) % 4)), cb + dv * fd))
		var col := DB.color(DB.setting("port_in_color" if into else "port_out_color", "#f2a81f" if into else "#5cff8c"))
		for i in r.parts.size():
			var pr: Dictionary = r.parts[i]
			if pr.role == "stretch":
				r.set_part_xform(key, i, Transform3D(Basis.from_scale(Vector3(length, 1, 1)), Vector3.ZERO) * pr.local)
			elif pr.role == "port_color":
				r.set_part_color(key, i, col)
		keys.append(key)
	if not keys.is_empty():
		port_keys[b] = keys


# 1.3: разъёмы выхода на самом здании — видно, куда подключать ленту, ещё до того, как она подведена.
# Зелёная заслонка с рамкой на каждой клетке передней стороны (у 2×2 — две); вход — с любой другой стороны.
var socket_keys := {}


func _has_output(b: B) -> bool:
	if b.dead or b.host != null or b.beh in ["belt", "splitter", "merger", "junction", "pipe", "pole", "wall", "foundation", "floor", "decor", "hq"]:
		return false
	if bool(DB.building(b.type).get("no_ports", false)) or not bool(DB.setting("output_sockets", true)):
		return false
	return b.out != null or b.beh in ["miner", "storage"]


func _clear_sockets(b: B) -> void:
	for key in socket_keys.get(b, []):
		for m in port_rs:
			port_rs[m].remove(key)
	socket_keys.erase(b)


## 1.3: навес у передней стены штаба — герой прячется под ним от кислотного дождя и выброса (events._collect_shelters).
## Клетки под навесом заняты для стройки (canopy_cells), пока навес стоит.
var canopy_key = null
var canopy_center := Vector3.ZERO
var canopy_cells: Array = []


func canopy_on() -> bool:
	return canopy_key != null and hq != null and not hq.dead


func _update_canopy() -> void:
	_clear_canopy()
	if hq == null or hq.dead or not bool(DB.setting("hq_canopy", true)) or not DB.data.models.has("hq_canopy"):
		return
	var b: B = hq
	var dv := Vector3(DIRS[b.dir].x, 0, DIRS[b.dir].y)
	var box: AABB = _xform(b) * _face_box(b.type)
	var ctr: Vector3 = b.center()
	var cp := Vector3(ctr.x, b.y, ctr.z)
	match b.dir:
		0: cp.x = box.end.x
		1: cp.z = box.end.z
		2: cp.x = box.position.x
		_: cp.z = box.position.z
	var cells := []
	for fc in b.fronts():
		var w: Vector3 = World.cell_to_world(fc)
		var lat := absf((w.z - ctr.z) if b.dir % 2 == 0 else (w.x - ctr.x))
		if lat < C:
			cells.append(fc)
			cells.append(World.wc(fc + DIRS[b.dir]))
	for c in cells:
		if grid.has(c):
			return   # место уже занято постройкой игрока — навес не ставим
	canopy_cells = cells
	cp -= dv * float(DB.setting("hq_canopy_inset", 0.55))   # балка навеса — к стене штаба, а не к цоколю
	canopy_center = cp + dv * 1.8
	canopy_key = [b, "canopy"]
	_port_r("hq_canopy").add(canopy_key, Transform3D(Basis(Vector3.UP, _dir_angle(b.dir)), cp))
	for c in cells:
		game.world.remove_node(c)
		game.world.set_occupied(c, true)   # трава и цветы не прорастают сквозь пол


func _clear_canopy() -> void:
	if canopy_key != null and port_rs.has("hq_canopy"):
		port_rs["hq_canopy"].remove(canopy_key)
	canopy_key = null
	var old := canopy_cells
	canopy_cells = []
	for c in old:
		game.world.set_occupied(c, false)


func _update_sockets(b: B) -> void:
	_clear_sockets(b)
	if b.pon:
		_port_sockets(b)
		return
	if not _has_output(b) or not DB.data.models.has("belt_port"):
		return
	var r := _port_r("belt_port")
	var keys := []
	var xb := _xform(b)
	var box: AABB = xb * _face_box(b.type)
	var dv := Vector3(DIRS[b.dir].x, 0, DIRS[b.dir].y)
	var col := DB.color(DB.setting("port_out_color", "#5cff8c"))
	var fs := b.fronts()
	for i in fs.size():
		var fc: Vector2i = fs[i]
		var t = grid.get(fc)
		if t != null and t.beh == "belt" and not t.dead:
			continue   # лента подведена — её мостик и так виден (_update_ports)
		# точка на стене здания напротив клетки выхода
		var cp: Vector3 = World.cell_to_world(fc) - dv * C
		cp = Vector3(cp.x, b.y, cp.z)
		match b.dir:
			0: cp.x = box.end.x
			1: cp.z = box.end.z
			2: cp.x = box.position.x
			_: cp.z = box.position.z
		var key := [b, "sock", i]
		r.add(key, Transform3D(Basis(Vector3.UP, _dir_angle(b.dir)), cp + dv * 0.02))
		for k in r.parts.size():
			var pr: Dictionary = r.parts[k]
			if pr.role == "stretch":
				r.set_part_xform(key, k, Transform3D(Basis.from_scale(Vector3(0.18, 1, 1)), Vector3.ZERO) * pr.local)
			elif pr.role == "port_color":
				r.set_part_color(key, k, col)
		keys.append(key)
	if not keys.is_empty():
		socket_keys[b] = keys


## 1.1.9: порты встроены в стену: рамка с тёмным проёмом, светящаяся полоса и стрелки на полу
## (вход — синий, стрелки внутрь; выход — зелёный, стрелки наружу). Подключена лента — пол порта тянется до неё.
func _port_sockets(b: B) -> void:
	if b.dead or b.host != null or bool(DB.building(b.type).get("no_ports", false)):
		return
	var keys := []
	var xb := _xform(b)
	var box: AABB = xb * _face_box(b.type)
	var cb := b.center()
	var all_p := []
	for i in b.pin.size():
		all_p.append([b.pin[i], b.pin_side[i], true, i == b.pfuel])
	for i in b.pout.size():
		all_p.append([b.pout[i], b.pout_side[i], false])
	for k in all_p.size():
		var pc: Vector2i = all_p[k][0]
		var side: int = all_p[k][1]
		var is_in: bool = all_p[k][2]
		var model := "port_in18" if is_in else "port_out18"
		if all_p[k].size() > 3 and all_p[k][3] and DB.data.models.has("port_fuel111"):
			model = "port_fuel111"   # 1.1.11: вход для топлива — оранжевый
		if not DB.data.models.has(model):
			continue
		var dv := Vector3(DIRS[side].x, 0, DIRS[side].y)
		var w: Vector3 = cb + World.delta(cb, World.cell_to_world(pc))   # клетка порта рядом со зданием (через край мира тоже)
		var cp := Vector3(w.x, b.y, w.z) - dv * C
		var face := 0.0
		match side:
			0: face = box.end.x
			1: face = box.end.z
			2: face = box.position.x
			_: face = box.position.z
		if side % 2 == 0:
			cp.x = face
		else:
			cp.z = face
		# до края клетки порта (там начинается лента)
		var edge: float = (w.x - dv.x * C * 0.5 - cp.x) * dv.x + (w.z - dv.z * C * 0.5 - cp.z) * dv.z
		var t = grid.get(pc)
		var linked: bool = t != null and not t.dead and t.beh in ["belt", "splitter", "merger", "junction"]
		var length := clampf(edge + 0.1, 0.25, C * 1.5) if linked else 0.3
		var r := _port_r(model)
		var key := [b, "port", k]
		r.add(key, Transform3D(Basis(Vector3.UP, _dir_angle(side)), cp + dv * 0.01))
		for j in r.parts.size():
			var pr: Dictionary = r.parts[j]
			if pr.role == "stretch":
				r.set_part_xform(key, j, Transform3D(Basis.from_scale(Vector3(length, 1, 1)), Vector3.ZERO) * pr.local)
		keys.append(key)
	if not keys.is_empty():
		socket_keys[b] = keys


# ---------------------------------------------------------------- размещение

func footprint(type: String, cell: Vector2i) -> Array:
	var s := int(DB.building(type).get("size", 1))
	var out := []
	for x in s:
		for z in s:
			out.append(World.wc(cell + Vector2i(x, z)))
	return out


var _collider_shapes := {}


func body_at(point: Vector3):
	var b = grid.get(World.world_to_cell(point))
	if b == null:
		return null
	var mid := str(DB.building(b.type).get("model", b.type))
	var model := ModelLib.model(mid)
	if not model.has("collision_outline"):
		return b
	if not _collider_shapes.has(mid):
		var outline := PackedVector2Array()
		for v in model.collision_outline:
			outline.append(Vector2(v[0],v[1]))
		_collider_shapes[mid] = outline
	var xf := _xform(b)
	var offset := World.delta(xf.origin, point)
	var scale_k := maxf(.001,float(model.get("scale",1.0)))
	var local := xf.basis.inverse() * offset / scale_k - ModelLib.glb_offset(model).origin
	return b if Geometry2D.is_point_in_polygon(Vector2(local.x,local.z),_collider_shapes[mid]) else null


func walkable(b: B) -> bool:
	return b.beh in WALKABLE or DB.building(b.type).get("walkable", false)


func can_place(type: String, cell: Vector2i) -> String:
	var d := DB.building(type)
	if d.is_empty():
		return "Нет такого здания"
	if Tech.building_locked(type) and not game.flags.get("free_build", false):
		return "Ещё не открыто: «%s» в дереве открытий (J)" % game.tech.opener("b", type)
	if game.strategy and type in DB.PERSONAL_BUILDINGS and not loading:
		return DB.tx("strat_no_b", "В «Стратегии» это здание не нужно")
	var player_cells: Array = game.player.occupied_cells() if game.player and not game.strategy else []   # в стратегии героя нет
	var is_f: bool = d.get("behavior", "") == "foundation"
	for c in footprint(type, cell):
		var why := _cell_why(c, bool(DB.bparam(type, "on_water", is_f)))
		if why != "":
			return why
		if grid.has(c):
			return "Клетка занята"
		if c in canopy_cells and canopy_on():
			return "Здесь навес штаба — укрытие от бурь"
		if c in player_cells and not (d.get("behavior", "") in WALKABLE):
			return "Здесь стоит герой — отойдите"
		if not loading and game.hazards:
			var hz: String = game.hazards.build_why(c)
			if hz != "":
				return hz
	if game.get("hearts") != null:
		var why_h: String = game.hearts.why(type, cell)   # 1.1.15: предел зданий (штаб и «Сердца»)
		if why_h != "":
			return why_h
	if d.get("behavior", "") == "miner":
		var why_m := _miner_why(type, cell)
		if why_m != "":
			return why_m
	# 17.10: «ставится только на залежь» (геотермальная станция — на выход магмы)
	var od := str(d.get("params", {}).get("on_deposit", ""))
	if od != "":
		var on_dep := false
		for c in footprint(type, cell):
			on_dep = on_dep or game.world.deposit_item(c) == od
		if not on_dep:
			return "%s ставится только на залежь: %s" % [str(d.get("name", type)), DB.item_name(od).to_lower()]
	return base_for(type, cell)[1]


## Почему на клетке нельзя строить (пусто — можно). Деревья и камни мешают: их надо срубить или разбить.
func _cell_why(c: Vector2i, water_ok := false) -> String:
	var w = game.world
	if not w.in_bounds(c):
		return "Здесь нельзя строить"
	if game.zone and not game.zone.inside_cell(c):
		return "За стеной бури: расширьте зону в штабе"
	if w.nest_cells.has(World.wc(c)):
		return "Здесь гнездо монстров"
	if w.water_at(c) and not water_ok and found_top(c) == null:
		return "На воде строят только на фундаменте"
	if w.blocks(c) and bool(DB.setting("nodes_block_build", true)):
		var n = w.nodes.get(World.wc(c))
		var rd: Dictionary = DB.data.resources.get(n.res, {})
		var nm := str(rd.get("name", n.res))
		var tool := str(rd.get("tool", ""))
		var how := "срубите" if tool == "axe" else ("разбейте" if tool == "pickaxe" else "уберите")
		return "Мешает: %s — %s" % [nm, how]
	return ""


# ---------------------------------------------------------------- рельеф и фундаменты

## Верхний фундамент на клетке (или null).
func found_top(c: Vector2i) -> B:
	var st = found.get(World.wc(c))
	return null if st == null or st.is_empty() else st.back()


## Высота, на которой встанет здание: [низ, текст ошибки, верх фундамента].
func base_for(type: String, cell: Vector2i) -> Array:
	var d := DB.building(type)
	var cells := footprint(type, cell)
	var is_f: bool = d.get("behavior", "") == "foundation"
	var tops := []
	var bare := 0
	for c in cells:
		var f := found_top(c)
		if f == null:
			bare += 1
			continue
		if f.p("ramp", false):
			return [0.0, "На рампу ничего не поставить", 0.0]
		tops.append(f.top)
	var hgt := float(DB.bparam(type, "height", 1.0))
	var step := maxf(0.1, float(DB.setting("found_step", 1.0)))
	if bare > 0 and bare < cells.size():
		return [0.0, "Часть клеток на фундаменте, часть на земле — поставьте фундамент под всё", 0.0]
	if bare == 0:
		var t0: float = tops[0]
		for t in tops:
			if absf(t - t0) > 0.01:
				return [0.0, "Фундаменты под ним разной высоты", 0.0]
		if is_f:
			var levels: int = found.get(cells[0], []).size()
			if levels >= int(DB.setting("found_levels", 8)):
				return [0.0, "Выше строить нельзя (ярусов: %d)" % levels, 0.0]
			return [t0, "", t0 + hgt]
		return [t0, "", t0]
	var gr: Vector2 = game.world.ground_range(cells)
	if is_f:
		var top := ceilf((gr.y + hgt * 0.5) / step) * step
		return [gr.x - 0.3, "", top]
	if bool(DB.setting("need_flat", true)) and gr.y - gr.x > float(DB.setting("flat_tolerance", 0.6)) and not DB.bparam(type, "any_ground", false):
		return [(gr.x + gr.y) * 0.5, "Земля неровная — поставьте фундамент", 0.0]
	return [(gr.x + gr.y) * 0.5, "", 0.0]


## Высота рампы в точке: от нижнего края (сзади) до верхнего (спереди по стрелке).
func ramp_h(f: B, p: Vector3) -> float:
	var lo := f.top - float(f.p("height", 1.0))
	var o: Vector3 = World.delta(f.center(), p)
	var dv: Vector2i = DIRS[f.dir]
	var t := (o.x * dv.x + o.z * dv.y) / (f.size * C) + 0.5
	return lerpf(lo, f.top, clampf(t, 0.0, 1.0))


## На какой высоте стоит то, что в точке p: земля, верх фундамента или рампа.
func support_at(p: Vector3) -> float:
	var g: float = game.world.height_at(p)
	var f := found_top(World.world_to_cell(p))
	if f == null:
		return g
	return maxf(g, ramp_h(f, p) if f.p("ramp", false) else f.top)


## Можно ли снести фундамент: сверху не должно быть ни зданий, ни других фундаментов.
func found_why(b: B) -> String:
	for c in footprint(b.type, b.cell):
		if found.get(c, []).back() != b:
			return "Сверху стоит фундамент — сначала снесите его"
		if grid.has(c):
			return "На фундаменте стоит здание — сначала снесите его"
	return ""


func cost_of(type: String) -> Dictionary:
	return DB.building(type).get("cost", {})


## 16: склад своей базы в сетевой игре со своими базами (аванпост) — стройка берёт отсюда, а не из штаба.
var personal: Inventory = null
var personal_b = null


func _store() -> Inventory:
	if personal != null:
		return personal
	return hq.inv if hq != null else null


## Сколько предметов доступно для стройки: инвентарь героя + склад штаба (или своей базы).
func available(id: String) -> int:
	var n: int = game.player.inv.count(id)
	var st := _store()
	if st != null:
		n += st.count(id)
	return n


func can_afford(type: String) -> bool:
	var cost := cost_of(type)
	for k in cost:
		if available(k) < int(cost[k]):
			return false
	return true


func pay(cost: Dictionary) -> void:
	for k in cost:
		var need := int(cost[k])
		need -= game.player.inv.take_up_to(k, need)
		if need > 0 and _store() != null:
			_store().take_up_to(k, need)


func refund(cost: Dictionary) -> void:
	for k in cost:
		give_player(k, int(cost[k]))


func give_player(id: String, n: int) -> void:
	# у подключившегося возврат за чужую команду не нужен: рюкзак и склад пришлёт хозяин
	if Net.is_client() and Net._self().applying:
		return
	if DB.is_fluid(id):
		return   # жидкость без канистры не унести — разливается
	var left: int = game.player.inv.add(id, n)
	# B15-5: у гостя склад штаба — копия хозяина и будет перезаписана: лишнее на землю
	if left > 0 and _store() != null and not Net.is_client():
		left = _store().add(id, left)
	if left > 0:
		game.overflow(id, left, game.player.position + Vector3(0, 1, 0))


func place(type: String, cell: Vector2i, dir: int) -> B:
	if not loading and game.get("builders") != null and game.builders != null and not DB.building(type).get("behavior", "") in ["foundation"]:
		game.builders.clear_at(type, cell)   # 1.1.12: обломки под новым зданием пропадают
	if not loading and game.get("physics") != null and game.physics != null:
		game.physics.clear_cells(cell, maxi(1, int(DB.building(type).get("size", 1))))   # 1.1.13: и разлетевшиеся куски тоже
	var d := DB.building(type)
	var b := B.new()
	b.type = type
	if not loading and game.tech != null and game.tech.done.has("calibration_" + type):
		b.cfg["tune"] = Tuning.center(Tuning.kind_of(b))
	b.beh = d.get("behavior", "decor")
	b.cell = cell
	b.dir = dir
	b.size = int(d.get("size", 1))
	b.maxhp = float(d.get("hp", 100)) * (1.0 + game.bonus("build_hp"))
	b.hp = b.maxhp
	var base := base_for(type, cell)
	b.y = base[0]
	b.top = base[2]
	for c in footprint(type, cell):
		if game.world.nodes.has(World.wc(c)):
			game.world.remove_node(c)   # цветы и мелочь под зданием убираются сами
		if b.beh == "foundation":
			if not found.has(c):
				found[c] = []
			found[c].append(b)
			game.world.set_occupied(c, true)
			game.world.dep_cover(c)   # 1.1.8: залежь поднимается на верх фундамента — её видно
		else:
			grid[c] = b
			game.world.set_occupied(c, true)
			game.world.dep_cover(c)
	all.append(b)
	rev += 1
	match b.beh:
		"belt":
			belts.append(b)
			b.period = 1.0 / belt_rate(type)
			b.lift = bool(b.p("lift", false))
		"splitter", "merger":
			# 13.10: свою скорость («Лента: предметов в минуту»), не медленнее лент Mk5 — иначе тормозит всю линию
			b.period = 1.0 / belt_rate(type)
		"miner":
			b.out = Inventory.new(2)   # 1.1.20 A15-3: вторая ячейка — для редкой добычи (богатая руда, антрацит)
			b.recipe = miner_item(type, cell)
			machines.append(b)
		"pipe", "tank":
			pipes.append(b)
		"crafter":
			b.inv = Inventory.new(int(b.p("in_slots", 4)))
			b.out = Inventory.new(int(b.p("out_slots", 2)))
			if b.p("fuel", false):
				b.fuel = Inventory.new(1)
				b.fuel.allow = fuel_filter(b)
			machines.append(b)
		"storage":
			b.inv = Inventory.new(int(b.p("slots", 16)))
			if b.p("ufo_pad", false):
				b.out = Inventory.new(int(b.p("slots", 16)))   # 14.23: «Получено» от НЛО
			machines.append(b)
		"hq":
			b.inv = Inventory.new(int(b.p("slots", 60)))
			hq = b
		"generator":
			if not b.p("solar", false) and not b.p("wind", false):
				b.fuel = Inventory.new(int(b.p("fuel_slots", 1)))
				b.fuel.allow = fuel_filter(b)
			if b.p("reactor", false):
				nuc.setup(b)
			machines.append(b)
		"battery":
			pass
		"turret":
			turrets.append(b)
			b.aim = _dir_angle(dir)
			_turret_mag(b)
		"hq_link":
			b.out = Inventory.new(2)
			machines.append(b)
			hq_link_power(b)
		"light":
			lights.append(b)
			var l := OmniLight3D.new()
			l.light_color = DB.color(b.p("light_color", "#ffe0a0"))
			l.omni_range = float(b.p("light_range", 12))
			l.light_energy = 0.0
			l.shadow_enabled = false
			l.position = b.center() + Vector3(0, 3.0, 0)
			add_child(l)
			b.light = l
	if b.beh in ELECTRIC_NODES or float(b.p("power", 0)) > 0.0:
		power_dirty = true
	if b.beh in ["generator", "pole", "battery", "hq"]:
		power_nodes.append(b)
	if Blocks.has_blocks(type):
		b.blk = true
		block_bldgs.append(b)
		if not Blocks.find(type, "power_gen").is_empty() and not b in power_nodes:
			power_nodes.append(b)
			power_dirty = true
	set_ports(b)
	_add_visual(b)
	_relink_around(b)
	if b.beh in ["pipe", "tank"] or b.p("pipes", false):
		fluid_dirty = true
		_arms_around(b)
	if b.beh == "turret":
		_aim_head(b)
	if Blocks.has_blocks(type):
		Blocks.setup(self, b)
	if not loading and wired() and bool(DB.setting("auto_wire", true)):
		auto_wire(b)
	if b.p("entangled", false) and game.get("quantum") != null:
		game.quantum.on_place(b)
	stats.placed += 1
	return b


## 14.10: здание без своей клетки — для встроенных в составное (загрузка сохранения).
func make_virtual(type: String, h: B) -> B:
	var d := DB.building(type)
	var b := B.new()
	b.type = type
	if not loading and game.tech != null and game.tech.done.has("calibration_" + type):
		b.cfg["tune"] = Tuning.center(Tuning.kind_of(b))
	b.beh = d.get("behavior", "decor")
	b.cell = h.cell
	b.dir = h.dir
	b.size = int(d.get("size", 1))
	b.maxhp = float(d.get("hp", 100)) * (1.0 + game.bonus("build_hp"))   # 1.1.15: с бонусом прочности, как у обычных
	b.hp = b.maxhp
	b.y = h.y
	match b.beh:
		"miner":
			b.out = Inventory.new(2)   # 1.1.20 A15-3: вторая ячейка — для редкой добычи (богатая руда, антрацит)
		"crafter":
			b.inv = Inventory.new(int(b.p("in_slots", 4)))
			b.out = Inventory.new(int(b.p("out_slots", 2)))
			if b.p("fuel", false):
				# 1.1.15: у встроенной печи после загрузки/восстановления пропадало место под топливо (и она плавила без него)
				b.fuel = Inventory.new(1)
				b.fuel.allow = fuel_filter(b)
		"storage":
			b.inv = Inventory.new(int(b.p("slots", 16)))
		"generator":
			if not b.p("solar", false) and not b.p("wind", false):
				b.fuel = Inventory.new(int(b.p("fuel_slots", 1)))
				b.fuel.allow = fuel_filter(b)
		"turret":
			b.aim = _dir_angle(h.dir)
			_turret_mag(b)
	return b


func _add_visual(b: B) -> void:
	if b.beh == "belt":
		_belt_r(b).add(b, _xform(b))
		if b.item != "":
			_show_item(b)
	else:
		renderer(b.type).add(b, _xform(b))


## 1.3: новое здание «вырастает» из земли с лёгким перехлёстом (ленты — сразу: их тянут десятками).
func pop_in(b: B) -> void:
	if b.beh == "belt" or b.beh == "foundation":
		return
	var r := renderer(b.type)
	if not r.has(b):
		return
	var xf := _xform(b)
	var tw: Tween = game.create_tween()
	var grow := func(k: float) -> void:
		if not b.dead and r.has(b):
			var w := lerpf(1.2, 1.0, minf(k, 1.0)) * k
			r.set_xform(b, Transform3D(xf.basis.scaled(Vector3(w, k, w)), xf.origin))
	tw.tween_method(grow, 0.05, 1.12, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_method(grow, 1.12, 1.0, 0.12).set_ease(Tween.EASE_IN_OUT)


## 1.3: снос — копия модели оседает и уходит в землю (само здание убирается сразу).
func sink_out(b: B) -> void:
	var mid := str(DB.building(b.type).get("model", b.type))
	if not DB.data.models.has(mid) or b.beh == "belt":
		return
	var n := ModelLib.make_node(mid)
	var xf := _xform(b)
	n.transform = xf
	game.add_child(n)
	var sink := func(k: float) -> void:
		var w := 1.0 + 0.1 * (1.0 - k)
		n.transform = Transform3D(xf.basis.scaled(Vector3(w, k, w)).rotated(Vector3(1, 0, 0.6).normalized(), (1.0 - k) * 0.12), xf.origin - Vector3(0, (1.0 - k) * 0.6, 0))
	var tw: Tween = n.create_tween()
	tw.tween_method(sink, 1.0, 0.02, 0.38).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(n.queue_free)


static func _dir_angle(d: int) -> float:
	return -d * PI * 0.5


func _xform(b: B) -> Transform3D:
	if b.lift:
		return _lift_xform(b)
	var basis := Basis(Vector3.UP, _dir_angle(b.dir)) if b.beh != "turret" else Basis()
	if b.beh == "foundation":
		# фундамент тянется от земли до своего верха (модель — высотой «Высота яруса»)
		basis = basis.scaled(Vector3(1, (b.top - b.y) / maxf(0.05, float(b.p("height", 1.0))), 1))
	if b.lvl > 1 or not b.subs.is_empty():
		var k: float = fz.scale_of(b)
		basis = basis.scaled(Vector3(k, k, k))
		if not b.subs.is_empty():
			return Transform3D(basis, b.center() + Vector3(0, 0.14, 0))   # стоит на платформе
	return Transform3D(basis, b.center())


## 1.1.8: лифт — наклонная лента от высоты того, что сзади, до высоты того, что спереди (земля, фундамент, здание).
func _lift_xform(b: B) -> Transform3D:
	var fwd: Vector2i = DIRS[b.dir]
	var eb := _lift_end(b, World.wc(b.cell - fwd))
	var ef := _lift_end(b, World.wc(b.cell + fwd))
	var lo := minf(eb, ef)
	var k := maxf(0.25, absf(ef - eb))
	var ang := _dir_angle(b.dir) + (PI if eb > ef + 0.01 else 0.0)
	var c := b.center()
	return Transform3D(Basis(Vector3.UP, ang).scaled(Vector3(1, k, 1)), Vector3(c.x, lo, c.z))


func _lift_end(b: B, c: Vector2i) -> float:
	var t = grid.get(c)
	if t != null and t != b and not t.dead:
		return t.y
	return support_at(World.cell_to_world(c))


## Лифты рядом с клеткой пересчитывают свою высоту (сосед поставлен или снесён).
func _refresh_lifts(around: Array) -> void:
	for t in around:
		if t != null and not t.dead and t.lift:
			var r := _belt_r(t)
			if r.has(t):
				r.set_xform(t, _xform(t))


func set_dir(b: B, d: int) -> void:
	b.dir = d
	set_ports(b)
	if b.beh == "belt":
		_belt_r(b).set_xform(b, _xform(b))
		if belt_item_key.has(b):
			item_renderers[belt_item_key[b]].set_xform(b, _xform(b))
	else:
		renderer(b.type).set_xform(b, _xform(b))
		if not b.subs.is_empty() or b.lvl > 1:
			fz.refresh_visual(b)   # 1.1.15: встроенные машины поворачиваются вместе с составным зданием
	_relink_around(b)


# ---------------------------------------------------------------- 1.1.9: порты зданий (как в Satisfactory)
# Один выход — середина передней стороны. Входов — сколько разных твёрдых ресурсов в самом сложном рецепте
# (печь с одним сырьём — один вход, литейная «железо + уголь» — два). Входы — на задней стороне, лишние — по бокам.
# Ленты подключаются только к портам. Штаб, терминал, турели и прочее без портов принимают с любой стороны.

static func ports_on() -> bool:
	return bool(DB.setting("ports18", {}).get("on", false)) if DB.setting("ports18", {}) is Dictionary else false


static var _pc_cache := {}
static var _pc_rev := -1


## [входов, выходов] для вида здания; [-1, -1] — портов нет (принимает отовсюду).
static func port_counts(type: String) -> Array:
	if _pc_rev != DB.revision:
		_pc_rev = DB.revision
		_pc_cache.clear()
	if _pc_cache.has(type):
		return _pc_cache[type]
	var d := DB.building(type)
	var pr: Dictionary = d.get("params", {})
	var beh := str(d.get("behavior", ""))
	var res := [-1, -1]
	if pr.has("inputs") and not (beh == "crafter" and pr.get("fuel", false)):
		res = [int(pr.inputs), int(pr.get("outputs", 1))]
	elif beh == "crafter":
		var n := 0
		# 1.1.15: по всем рецептам станции, а не только открытым — иначе число входов менялось после изучения и при загрузке
		var st_id := str(pr.get("station", type))
		for rid in DB.data.recipes:
			if not st_id in DB.data.recipes[rid].get("stations", []):
				continue
			var k := 0
			for it in DB.data.recipes.get(rid, {}).get("in", {}):
				if not DB.is_fluid(str(it)):
					k += 1
			n = maxi(n, k)
		if pr.has("inputs"):
			n = int(pr.inputs)
		# 1.1.11: машина на топливе — отдельный вход для топлива (последний);
		# только жидкое сырьё (нефтезавод) — ленточных входов нет, всё по трубам
		if pr.get("fuel", false):
			n = maxi(1, n) + 1
		res = [n, 1]
	elif beh == "miner":
		res = [0, 1]
	elif beh == "hq_link":
		res = [1, 1]
	elif beh == "turret" and str(pr.get("ammo", "")) != "" and local_ammo():
		res = [1, 0]   # 1.1.15: вход для патронов
	elif beh == "generator":
		res = [0 if (pr.get("solar", false) or pr.get("wind", false)) else 1, 0]
	elif beh == "storage":
		res = [-1, -1] if (pr.get("megaproject", false) or pr.get("ufo_pad", false)) else [1, 1]
	elif not d.get("blocks", []).is_empty():
		var ni := 0
		var no := 0
		for bl in d.get("blocks", []):
			match str(bl.get("type", "")):
				"convert", "research":
					# 1.1.11: входов — сколько разных видов сырья в блоке (переработчик: хитин + слизь)
					var k2 := 0
					for it in bl.get("in", {}):
						if not DB.is_fluid(str(it)):
							k2 += 1
					ni = maxi(ni, maxi(1, k2))
				"sell", "sink", "bmarket", "zone_push":
					ni = maxi(ni, 1)
				"store":
					ni = maxi(ni, 1)
					no = 1
				"power_gen":
					if bl.get("fuel", false):
						ni = maxi(ni, 1)
				"carrier":
					if str(bl.get("mode", "send")) == "send":
						ni = maxi(ni, 1)
					else:
						no = 1
				"produce":
					no = 1
			if str(bl.get("type", "")) in ["convert", "sink"]:
				no = 1
		res = [ni, no] if ni + no > 0 else [-1, -1]
	if type in ["black_market", "player_market"]:
		res = [-1, -1]   # 1.1.20 A15-4: рынки принимают ленты с любой стороны, как и написано в описании
	_pc_cache[type] = res
	return res


## 1.1.11: у здания на топливе на один вход больше (с 1.1.12 все входы принимают и сырьё, и топливо).
static func fuel_port(type: String) -> bool:
	var d := DB.building(type)
	return str(d.get("behavior", "")) == "crafter" and bool(d.get("params", {}).get("fuel", false)) and port_counts(type)[0] > 1


## Клетки вдоль стороны side (мировое направление) снаружи здания: от середины к краям.
static func side_cells(cell: Vector2i, size: int, side: int) -> Array:
	var idx := []
	var mid := size / 2
	idx.append(mid)
	for k in range(1, size):
		for j in [mid - k, mid + k]:
			if j >= 0 and j < size and not j in idx:
				idx.append(j)
	var out := []
	for i in idx:
		match side:
			0: out.append(cell + Vector2i(size, i))
			1: out.append(cell + Vector2i(i, size))
			2: out.append(cell + Vector2i(-1, i))
			_: out.append(cell + Vector2i(i, -1))
	return out


## Раскладка портов: {"in": [клетки], "in_side": [стороны], "out": [...], "out_side": [...]} (клетки без перевода через край мира).
static func port_layout(type: String, cell: Vector2i, dir: int) -> Dictionary:
	var pc := port_counts(type)
	var res := {"in": [], "in_side": [], "out": [], "out_side": []}
	if pc[0] < 0:
		return res
	var size := int(DB.building(type).get("size", 1))
	for output in side_cells(cell, size, dir).slice(0, int(pc[1])):
		res.out.append(output)
		res.out_side.append(dir)
	var back := (dir + 2) % 4
	var order := []   # [сторона, клетка]
	for c in side_cells(cell, size, back):
		order.append([back, c])
	# лишние входы — по бокам, с середины, по очереди слева и справа
	var left := side_cells(cell, size, (dir + 3) % 4)
	var right := side_cells(cell, size, (dir + 1) % 4)
	for i in maxi(left.size(), right.size()):
		order.append([(dir + 3) % 4, left[i]])
		order.append([(dir + 1) % 4, right[i]])
	for i in mini(pc[0], order.size()):
		res["in"].append(order[i][1])
		res.in_side.append(order[i][0])
	return res


func set_ports(b: B) -> void:
	b.pon = false
	b.pin = []
	b.pin_side = []
	b.pout = []
	b.pout_side = []
	b.pfuel = -1
	if not ports_on() or b.beh in ["belt", "splitter", "merger", "junction", "pipe", "foundation"]:
		return
	if port_counts(b.type)[0] < 0:
		return
	var lay := port_layout(b.type, b.cell, b.dir)
	b.pon = true
	for c in lay["in"]:
		b.pin.append(World.wc(c))
	b.pin_side = lay.in_side
	for c in lay.out:
		b.pout.append(World.wc(c))
	b.pout_side = lay.out_side
	# 1.1.12: все входы равноправны — в любой можно подавать и сырьё, и топливо (pfuel не задаётся)


## Сосед from стоит у входа здания t.
func _at_input(t: B, from: B) -> bool:
	return _input_index(t, from) >= 0


## Номер входа, у которого стоит from (-1 — не у входа).
func _input_index(t: B, from: B) -> int:
	for i in t.pin.size():
		if grid.get(t.pin[i]) == from:
			return i
	return -1


## 1.1.11: топливо — в топку, а не в сырьё: если рецепт не выбран или выбранному рецепту этот предмет не нужен.
## (Раньше брёвна, положенные в печь как топливо, печь принимала за сырьё для древесного угля —
## и дальше ждала только брёвна, руду с ленты не брала.)
func _fuel_first(t: B, item: String) -> bool:
	if t.fuel == null or not fuel_ok(t, item):
		return false
	if t.recipe == "":
		return true
	return not DB.data.recipes.get(t.recipe, {}).get("in", {}).has(item)


## 1.1.17: к таким зданиям лента не подводится вовсе (станции энергии, стены, фонари, сердца…) —
## раньше у столба появлялся люк-стык, будто в него что-то едет.
const NO_BELT_BEH := ["pole", "wall", "pipe", "foundation", "floor", "light", "heart", "vehicle", "rails", "tank", "battery", "station"]   # station — верстак, мастерская: крафт руками

func takes_belt(t) -> bool:
	if t == null or t.dead:
		return false
	if not t.subs.is_empty():
		return true
	if t.beh in NO_BELT_BEH:
		return false
	var pc: Array = port_counts(t.type)
	if int(pc[0]) == 0:
		return false   # нет входов: бур, солнечная панель, нефтезавод (только трубы)
	if t.beh == "decor" and int(pc[0]) < 0 and not t.type in ["black_market", "player_market"]:
		return false   # украшение без блоков, которые что-то принимают
	if t.beh == "turret" and str(t.p("ammo", "")) == "" and t.fuel == null:
		return false   # 1.1.20 A14-9: лазер, тесла, плазма — без патронов, лента к ним не цепляется
	return true


func _link(b: B) -> void:
	b.next = grid.get(b.front()) if b.beh != "junction" else null
	b.nexts = []
	if b.pon:
		# 1.1.9: один выход — своя клетка
		for cell in b.pout:
			var other = grid.get(cell)
			if other != null and other != b and not other.dead and not other in b.nexts:
				b.nexts.append(other)
		b.next = b.nexts[0] if not b.nexts.is_empty() else null
		if b.next == b:
			b.next = null
	elif b.size > 1 and b.beh != "junction" and b.subs.size() >= 0:
		# 1.3: у большого здания выход — любая клетка передней стороны; лента, смотрящая внутрь, не выход
		for fc in b.fronts():
			var t = grid.get(fc)
			if t != null and t != b and not t.dead and not t in b.nexts and not (t.beh in ["belt", "merger"] and t.next == b):
				b.nexts.append(t)
		if not b.nexts.is_empty() and (b.next == null or not b.next in b.nexts):
			b.next = b.nexts[0]
	if b.next != null and b.next != b and not takes_belt(b.next):
		b.next = null
	b.nexts = b.nexts.filter(func(t): return takes_belt(t))
	if b.next == null and not b.nexts.is_empty():
		b.next = b.nexts[0]
	_update_sockets(b)
	if b == hq and canopy_key == null:
		_update_canopy()
	if b.item != "":
		_schedule(b, tick_i + 1)


func _schedule(b: B, k: int) -> void:
	var l = sched.get(k)
	if l == null:
		l = []
		sched[k] = l
	l.append(b)


func _relink_around(b: B) -> void:
	_link(b)
	var touched := [b]
	for c in footprint(b.type, b.cell):
		for d in DIRS:
			var nb = grid.get(World.wc(c + d))
			if nb != null and nb != b and not nb in touched:
				_link(nb)
				touched.append(nb)
	# повороты: пересчитать саму ленту, соседей и тех, в кого они смотрят
	for t in touched.duplicate():
		if t.next != null and not t.next in touched:
			touched.append(t.next)
	for t in touched:
		if t.beh == "belt":
			_update_kind(t)
	for t in touched:
		if t.beh == "belt":
			_update_ports(t)
	_refresh_lifts(touched)


## Лента становится поворотом, если её единственный «кормилец» стоит сбоку.
func _update_kind(b: B) -> void:
	if b.dead or b.lift:
		return   # 1.1.8: лифт не поворачивает
	var back: Vector2i = World.wc(b.cell - DIRS[b.dir])
	var left: Vector2i = World.wc(b.cell + DIRS[(b.dir + 3) % 4])
	var right: Vector2i = World.wc(b.cell + DIRS[(b.dir + 1) % 4])
	var k := 0
	var fb = grid.get(back)
	var has_back: bool = fb != null and _feeds(fb, b)
	if not has_back:
		var fl = grid.get(left)
		var fr = grid.get(right)
		var l_ok: bool = fl != null and _feeds(fl, b)
		var r_ok: bool = fr != null and _feeds(fr, b)
		if l_ok and not r_ok:
			k = 1
		elif r_ok and not l_ok:
			k = -1
	if k == b.kind:
		return
	_belt_r(b).remove(b)
	_drop_item_visual(b)
	b.kind = k
	_belt_r(b).add(b, _xform(b))
	if b.item != "":
		_show_item(b)
	if b.bstate.get("rails", false):
		set_rails(b, true)


var _jn_depth := 0


func _feeds(f: B, b: B) -> bool:
	if f.dead or f.beh == "foundation":
		return false
	if f.beh == "splitter":
		return b.next != f and b.cell in split_cells(f)
	if f.beh == "junction":
		return b.next != f   # 21: кротовина отдаёт насквозь в любую сторону
	# лента, соединитель, машина, бур или склад, чей выход смотрит на эту ленту
	return f.next == b or b in f.nexts


## Клетки, куда разделитель отдаёт груз: вперёд, влево, вправо.
func split_cells(f: B) -> Array:
	var out := []
	for rel in OUT_RELS:
		out.append(World.wc(f.cell + DIRS[(f.dir + rel) % 4]))
	return out


# ---------------------------------------------------------------- груз на лентах
# Каждый предмет едет на ленте своей моделью (та же, что на земле, поле «model» у предмета).
# Все детали модели сливаются в один меш, чтобы одинаковые предметы рисовались одним вызовом.
# Белые детали красятся в цвет предмета, детали со свечением светятся.

func _show_item(b: B) -> void:
	if b.lift:
		return   # 1.1.8: груз в лифте не виден (он внутри короба)
	var model := str(DB.item(b.item).get("model", "drop_box"))
	if not DB.data.models.has(model):
		model = "drop_box"
	var ms := snappedf(clampf(float(DB.item(b.item).get("model_scale", 1.0)), 0.2, 3.0), 0.05)
	var mk := "%d|%s" % [b.kind, 1.0 / b.period]
	var key := "%s|%s|%s" % [mk, model, ms]
	if belt_item_key.get(b, "") != key:
		_drop_item_visual(b)
		_item_r(mk, model, ms, key).add(b, _xform(b))
		belt_item_key[b] = key
	var r: PartRenderer = item_renderers[key]
	var c := DB.item_color(b.item)
	r.set_part_color(b, 0, Color(1, 1, 1, 1))
	r.set_part_custom(b, 0, Color(c.r, c.g, c.b, b.t_in))


func _drop_item_visual(b: B) -> void:
	var key = belt_item_key.get(b)
	if key != null:
		item_renderers[key].remove(b)
		belt_item_key.erase(b)


func _item_r(mk: String, model: String, ms: float, key: String) -> PartRenderer:
	if item_renderers.has(key):
		return item_renderers[key]
	if not item_mats.has(mk):
		var p := mk.split("|")
		var im := ShaderMaterial.new()
		im.shader = ModelLib.ITEM_SHADER
		im.set_shader_parameter("curve", float(p[0]))
		im.set_shader_parameter("speed", float(p[1]))
		item_mats[mk] = im
	var r := PartRenderer.new()
	r.chunk = render_chunk()
	r.add_part(belt_item_mesh(model, ms), item_mats[mk], Transform3D.IDENTITY, Color(1, 1, 1, 0), false, false)
	add_child(r)
	item_renderers[key] = r
	return r


## Меш модели предмета для ленты: детали слиты, модель уменьшена до размера груза
## и стоит на полотне ленты. В альфе цвета вершины — признак детали:
## 1.0 — красится в цвет предмета, 0.9 — то же и светится, 0.8 — свой цвет, 0.7 — свой цвет и светится.
func belt_item_mesh(model: String, ms := 1.0) -> ArrayMesh:
	var mk := "%s|%s" % [model, ms]
	if _belt_meshes.has(mk):
		return _belt_meshes[mk]
	var parts := ModelLib.parts_of(model, false)
	var box := AABB()
	var first := true
	for pt in parts:
		var bb: AABB = (pt[2] as Transform3D) * (pt[0] as Mesh).get_aabb()
		box = bb if first else box.merge(bb)
		first = false
	var sc := 1.0
	var span := maxf(maxf(box.size.x, box.size.z), box.size.y * 1.3)
	if span > 0.001:
		sc = 0.78 / span
	sc *= ms
	var lift := Transform3D(Basis.from_scale(Vector3.ONE * sc), Vector3(-box.get_center().x * sc, 0.27 - box.position.y * sc, -box.get_center().z * sc))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mdl: Dictionary = ModelLib.model(model)
	var pdata: Array = mdl.get("parts", [])
	var glb_n := parts.size() - pdata.size()
	for i in parts.size():
		var pt: Array = parts[i]
		var mesh: Mesh = pt[0]
		var xf: Transform3D = lift * (pt[2] as Transform3D)
		var col: Color = pt[3]
		var glow := false
		var tint := col.is_equal_approx(Color.WHITE)
		if i >= glb_n:
			var pd: Dictionary = pdata[i - glb_n]
			glow = str(pd.get("mat", "")) == "glow"
			# готовый меш из Blender (этап 20): цвета в вершинах, перекраска цветом предмета — по полю tint
			if str(pd.get("shape", "")) == "mesh":
				tint = bool(pd.get("tint", true))
		col.a = (1.0 if tint else 0.8) - (0.1 if glow else 0.0)
		for si in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(si)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var norms = arr[Mesh.ARRAY_NORMAL]
			var vcols = arr[Mesh.ARRAY_COLOR]
			var has_vc: bool = vcols is PackedColorArray and (vcols as PackedColorArray).size() == verts.size()
			var idx = arr[Mesh.ARRAY_INDEX]
			var order: Array = []
			if idx is PackedInt32Array and idx.size() > 0:
				order = Array(idx)
			else:
				order = range(verts.size())
			for vi in order:
				if has_vc:
					var vc: Color = vcols[vi]
					st.set_color(Color(col.r * vc.r, col.g * vc.g, col.b * vc.b, col.a))
				else:
					st.set_color(col)
				if norms is PackedVector3Array and norms.size() > vi:
					st.set_normal((xf.basis * norms[vi]).normalized())
				st.add_vertex(xf * verts[vi])
	var m := st.commit()
	_belt_meshes[mk] = m
	return m


func set_item(b: B, item: String, t_in := -1.0) -> void:
	if b.item == "":
		items_on_belts += 1
	b.item = item
	# время въезда считаем точно (а не по такту), чтобы скорость ленты не округлялась
	if t_in < 0.0 and b.beh == "belt" and b.t_free >= 0.0:
		t_in = maxf(b.t_free, sim_time - TICK)   # 1.1.15: из здания — с момента, когда лента освободилась (раньше Mk4 давала 375/мин вместо 480)
	b.t_in = t_in if t_in >= 0.0 and t_in > sim_time - TICK * 2.0 else sim_time
	if b.beh == "belt":
		_schedule(b, tick_i + maxi(1, ceili((b.t_in + b.period - sim_time) / TICK - 0.001)))
	else:
		_schedule(b, tick_i + 2)
	if b.beh == "belt":
		_show_item(b)


func clear_item(b: B) -> void:
	if b.item != "":
		items_on_belts -= 1
		if b.beh == "belt":
			b.t_free = minf(sim_time, b.t_in + b.period)
	b.item = ""
	if b.beh == "belt" and belt_item_key.has(b):
		item_renderers[belt_item_key[b]].set_part_color(b, 0, Color(1, 1, 1, 0))
	_wake(b)


func _wake(b: B) -> void:
	if b.waiters.is_empty():
		return
	for w in b.waiters:
		if w.item != "" and not w.dead:
			_schedule(w, tick_i + 1)
	b.waiters.clear()


func _exit_tree() -> void:
	for b in all:
		b.next = null
		b.nexts.clear()
		b.waiters.clear()
		b.feeder = null
		b.target = null
		if b.fuel:
			b.fuel.allow = Callable()


func remove(b: B) -> void:
	if b.p("entangled", false) and game.get("quantum") != null:
		game.quantum.detach(b)
	if not b.subs.is_empty():
		fz.drop_subs(b)
	if b.bstate.get("rails", false):
		set_rails(b, false)
	fz._clear_deco(b)
	for c in footprint(b.type, b.cell):
		if b.beh == "foundation":
			found.get(c, []).erase(b)
			if found.get(c, [1]).is_empty():
				found.erase(c)
			game.world.set_occupied(c, false)
			game.world.dep_cover(c)
			continue
		grid.erase(c)
		game.world.set_occupied(c, false)
		game.world.dep_cover(c)
	all.erase(b)
	rev += 1
	belts.erase(b)
	machines.erase(b)
	if b in pipes or b.p("pipes", false):
		fluid_dirty = true
	pipes.erase(b)
	_clear_arms(b)
	turrets.erase(b)
	lights.erase(b)
	if b in power_nodes:
		power_dirty = true
	power_nodes.erase(b)
	if unwire(b) > 0:
		power_dirty = true
	block_bldgs.erase(b)
	if b.light:
		b.light.queue_free()
	if b.beh in ELECTRIC_NODES or float(b.p("power", 0)) > 0.0:
		power_dirty = true
	if b.item != "":
		items_on_belts -= 1
		b.item = ""
	b.dead = true
	if b.beh == "belt":
		_belt_r(b).remove(b)
		_drop_item_visual(b)
		_clear_ports(b)
	else:
		renderer(b.type).remove(b)
		_clear_sockets(b)
		if b == hq:
			_clear_canopy()
	damaged.erase(b)
	flashing.erase(b)
	_wake(b)
	var around := []
	for c in footprint(b.type, b.cell):
		for d in DIRS:
			var nb = grid.get(World.wc(c + d))
			if nb != null and not nb in around:
				around.append(nb)
	for nb in around:
		_link(nb)
	for nb in around:
		if nb.beh == "belt":
			_update_kind(nb)
			_update_ports(nb)
		elif nb.beh == "pipe":
			_update_arms(nb)
	_refresh_lifts(around)


## Разобрать здание: стоимость и содержимое возвращаются герою.
## Можно ли поставить здание поверх другого как улучшение (лента Mk1 → Mk2, плавильня → плавильня Mk2).
func upgrade_target(t: String, cell: Vector2i):
	var old = building_at(cell)
	if old == null or old.beh == "foundation" or old == hq or old.type == t or old.cell != World.wc(cell):
		return null
	if Tech.building_locked(t) and not game.flags.get("free_build", false):
		return null
	var d := DB.building(t)
	if str(d.get("behavior", "")) != old.beh or int(d.get("size", 1)) != old.size:
		return null
	# 21: только то же семейство (бур → бур Mk2, станция → станция Mk3) и только выше уровнем
	# 1.1.8: лифт ставится прямо поверх куска ленты (любой марки)
	var lift_over_belt: bool = bool(d.get("params", {}).get("lift", false)) and not old.lift and old.beh == "belt"
	if not lift_over_belt and (family_of(t) != family_of(old.type) or tier_of(t) <= tier_of(old.type)):
		return null
	return old


## Семейство здания: имя без «_mkN» (miner_mk3 → miner). Поле «upgrade_of» в параметрах задаёт семейство явно.
static func family_of(t: String) -> String:
	var fam := str(DB.building(t).get("params", {}).get("upgrade_of", ""))
	if fam != "":
		return fam
	var i := t.rfind("_mk")
	if i > 0 and t.substr(i + 3).is_valid_int():
		return t.substr(0, i)
	return t


## Уровень здания: параметр «tier», иначе цифра из «_mkN», иначе 1.
static func tier_of(t: String) -> int:
	var pr: Dictionary = DB.building(t).get("params", {})
	if pr.has("tier"):
		return int(pr.tier)
	var i := t.rfind("_mk")
	if i > 0 and t.substr(i + 3).is_valid_int():
		return int(t.substr(i + 3))
	return 1


## Заменить здание улучшенным: направление, груз, содержимое и провода сохраняются, старое возвращается в цену.
func upgrade(old: B, t: String):
	var item: String = old.item
	var keep := {}
	for k in ["inv", "out", "fuel"]:
		var inv: Inventory = old.get(k)
		if inv != null:
			keep[k] = inv.to_array()
			inv.slots.fill(null)
	var peers := []
	for l in links:
		if l[0] == old:
			peers.append(l[1])
		elif l[1] == old:
			peers.append(l[0])
	var recipe: String = old.recipe
	var dir: int = old.dir
	var cell: Vector2i = old.cell
	var keep_lvl: int = old.lvl
	var keep_subs: Array = old.subs.duplicate()
	var keep_paid = old.paid
	var keep_state: Dictionary = old.bstate.duplicate(true)
	var keep_cfg: Dictionary = old.cfg.duplicate(true)
	old.subs = []
	fz.hosts.erase(old)
	for s2 in keep_subs:
		renderer(s2.type).remove(s2)
	if item != "":
		clear_item(old)
	refund(old.paid if old.paid is Dictionary else game._scaled_cost(old.type))
	_refund_crafting(old)
	var was_loading := loading
	loading = true
	remove(old)
	var b := place(t, cell, dir)
	loading = was_loading
	# 1.1.15: сначала уровень и встроенные (у них больше ячеек), потом содержимое; что не влезло — игроку (раньше пропадало)
	if keep_lvl > 1:
		fz.set_level(b, keep_lvl)
	for s2 in keep_subs:
		fz._attach(b, s2)
	b.cfg = keep_cfg   # 1.1.15: настройки (выкл., ползунок, тонкая настройка, фильтры составного) сохраняются
	for k in keep:
		var inv: Inventory = b.get(k)
		for e in keep[k]:
			if e == null:
				continue
			var left := int(e.get("n", 0))
			if inv != null:
				left = inv.add(str(e.get("id", "")), left)
			if left > 0:
				give_player(str(e.get("id", "")), left)
	if b.beh == "crafter":
		b.recipe = recipe
	if item != "" and b.beh == "belt":
		set_item(b, item)
	for p2 in peers:
		if not p2.dead and not wired_to(b, p2):
			links.append([b, p2])
	for k in keep_state:
		if not b.bstate.has(k):
			b.bstate[k] = keep_state[k]
	if b.bstate.get("rails", false):
		set_rails(b, true)
	if not keep_subs.is_empty():
		fz.hosts.append(b)
		fz.refresh_visual(b)
	power_dirty = true
	return b


func deconstruct(b: B) -> void:
	if b == hq or b.p("landmark", false):
		return
	if b.p("entangled", false) and game.get("quantum") != null:
		game.quantum.detach(b)   # 21: содержимое пары остаётся у второго
	if not b.subs.is_empty():
		fz.refund_subs(b)
	refund(b.paid if b.paid is Dictionary else game._scaled_cost(b.type))
	_refund_crafting(b)
	# A-6 r8: инструменты и еда возвращаются слотами — с износом и свежестью
	for inv in [b.inv, b.out, b.fuel]:
		if inv == null:
			continue
		for s0 in inv.slots:
			if s0 != null and (s0.has("dur") or s0.has("fresh")):
				give_player_slot(s0)
		for i in inv.slots.size():
			if inv.slots[i] != null and (inv.slots[i].has("dur") or inv.slots[i].has("fresh")):
				inv.slots[i] = null
	for k in contents(b):
		give_player(k, contents(b)[k])
	remove(b)


func give_player_slot(s0: Dictionary) -> void:
	if Net.is_client() and Net._self().applying:
		return
	var left: int = game.player.inv.add_slot(s0)
	if left > 0 and _store() != null:
		left = _store().add_slot(s0)
	if left > 0:
		var s1 := s0.duplicate()
		s1["n"] = left
		game.overflow(str(s0.get("id", "")), left, game.player.position + Vector3(0, 1, 0), s1)


## Начатый крафт отменяется — сырьё, уже взятое машиной, возвращается герою.
func _refund_crafting(b: B) -> void:
	if b.crafting == "":
		return
	var r: Dictionary = DB.data.recipes.get(b.crafting, {})
	for k in r.get("in", {}):
		give_player(k, int(r["in"][k]))
	b.crafting = ""
	b.prog = 0.0


## Всё, что лежит внутри здания: {предмет: количество}.
func contents(b: B) -> Dictionary:
	var out := {}
	for inv in [b.inv, b.out, b.fuel]:
		if inv == null:
			continue
		var t: Dictionary = inv.totals()
		for k in t:
			out[k] = out.get(k, 0) + t[k]
	if b.item != "":
		out[b.item] = out.get(b.item, 0) + 1
	return out


## Кнопка «Забрать всё»: выход машины, склад или ящик → в инвентарь героя.
func take_all(b: B, to: Inventory) -> int:
	var moved := 0
	var invs := [b.out, b.inv]
	for sb in b.subs:   # 1.1.20: составное — и встроенный ящик, и готовое встроенных машин
		invs += [sb.out, sb.inv] if sb.beh == "storage" or sb.beh == "crafter" else []
	for inv in invs:
		if inv == null:
			continue
		for i in inv.slots.size():
			var s = inv.slots[i]
			if s == null:
				continue
			var left := to.add_slot(s)
			moved += s.n - left
			if left == 0:
				inv.slots[i] = null
			else:
				s.n = left
		inv.changed.emit()
	return moved


## Кнопка «Забрать готовое»: только то, что здание уже сделало (выход), сырьё и топливо остаются.
func take_ready(b: B, to: Inventory) -> int:
	var invs := [b.out]
	for sb in b.subs:   # 1.1.20: составное — готовое из встроенного ящика и встроенных машин
		invs.append(sb.inv if sb.beh == "storage" else (sb.out if sb.beh == "crafter" else null))
	var moved := 0
	for inv in invs:
		if inv == null:
			continue
		for i in inv.slots.size():
			var s = inv.slots[i]
			if s == null:
				continue
			var left := to.add_slot(s)
			moved += s.n - left
			if left == 0:
				inv.slots[i] = null
			else:
				s.n = left
		inv.changed.emit()
	return moved


## Кнопка «Положить»: из инвентаря героя всё, что подходит зданию.
## Можно ли жечь этот предмет в здании: у предмета есть «Топливо, сек», и он в списке топлива здания (если список задан).
static func fuel_filter(building: B) -> Callable:
	var owner := weakref(building)
	return func(id):
		var current = owner.get_ref()
		return current != null and fuel_ok(current, id)


static func fuel_ok(b, item: String) -> bool:
	if float(DB.item(item).get("fuel", 0)) <= 0.0:
		return false
	if bool(DB.item(item).get("reactor_fuel", false)) != bool(b.p("reactor", false)):
		return false   # 14.22: ТВЭЛы — только в реактор, реактору — только ТВЭЛы
	var list0 = b.p("fuels", [])
	if bool(DB.item(item).get("special_fuel", false)) and not (list0 is Array and item in list0):
		return false   # 14.23: особое топливо (термоядерные ячейки) — только где оно в списке
	var list = b.p("fuels", [])
	return not (list is Array) or list.is_empty() or item in list


## Сколько секунд здание проработает на одной штуке топлива.
func burn_time(b: B, item: String) -> float:
	return float(DB.item(item).get("fuel", 0)) * float(b.p("burn_mult", 2.0)) * Tuning.k(b, "fuel")


func put_from(b: B, from: Inventory) -> int:
	var moved := 0
	# 1.1.20 A14-7: в ящик/склад — без панели быстрого доступа (кирка, топор, еда остаются в руках, как у «Сложить в штаб»)
	var keep_hot: bool = b.beh in ["storage", "hq"] and game != null and game.player != null and from == game.player.inv
	for si in from.slots.size():
		var s = from.slots[si]
		if s == null:
			continue
		if keep_hot and si < Player.hot_n():
			# в руках остаются инструменты, оружие, еда и вещи с износом; материалы с панели кладутся
			var hit := DB.item(str(s.id))
			if s.has("dur") or s.has("fresh") or hit.has("tool") or hit.has("weapon") or hit.has("food") or float(hit.get("heal", 0)) > 0.0:
				continue
		# инструменты и еда со своим состоянием — целой ячейкой (в склад или штаб)
		if (s.has("dur") or s.has("fresh")) and b.inv != null and b.beh in ["storage", "hq"]:
			var placed: bool = b.inv.add_slot(s) == 0
			if not placed and b.beh == "storage":
				for sb in b.subs:
					if sb.beh == "storage" and sb.inv != null and sb.inv.add_slot(s) == 0:
						placed = true
						break
			if placed:
				from.slots[si] = null
				moved += int(s.n)
			continue
		var id: String = s.id
		if b.fuel != null and float(DB.item(id).get("food", 0)) > 0.0 and not DB.data.recipes.get(b.recipe, {}).get("in", {}).has(id):
			continue   # B-17: «Положить» не сжигает еду из рюкзака (лентой — можно)
		var n: int = int(s.n) if keep_hot else from.count(id)
		var k := 0
		while k < n and accept(b, id, null):
			k += 1
		if k > 0:
			if keep_hot:
				s.n = int(s.n) - k
				if int(s.n) <= 0:
					from.slots[si] = null
			else:
				from.remove(id, k)
			moved += k
	from.changed.emit()
	return moved


# ---------------------------------------------------------------- урон и ремонт

func damage(b: B, amount: float) -> void:
	if b.p("landmark", false):
		return
	if b.hp <= 0.0 or b.dead:
		return
	if game.defense:
		amount = game.defense.absorb(b.center(), amount)   # энергощит принимает урон на себя
		if amount <= 0.0:
			return
	b.hp -= amount
	b.flash = 0.8
	flashing[b] = true
	damaged[b] = true
	if b.hp <= 0.0:
		game.fx.explosion(b.center() + Vector3(0, 1, 0), 1.6 if b.size == 1 else 4.0, Color(1.0, 0.5, 0.15))
		game.sfx.play("boom", b.center())
		if b == hq:
			b.hp = 0.0   # A-15: штаб не уходит в минус (раньше −999 996 000 и «вечная» поломка)
			if not game.game_over:
				game.on_hq_destroyed()
			return
		if b.blk:
			Blocks.event(game, b, "destroyed")
		if Net.is_host():
			Net._self().building_destroyed(b)
		if game.builders:
			game.builders.add_ruin(b)   # 18: робот-строитель отстроит
		if game.get("physics") != null:
			game.physics.debris(b)   # 21: разлетается обломками
		remove(b)
		game.notify("Разрушено: " + DB.building(b.type).get("name", b.type), Color(1, 0.4, 0.3))
		if b.beh == "heart" and game.get("hearts") != null:
			game.hearts.on_destroyed(b)   # 1.1.15: цепная реакция сердец
	else:
		_tint(b)


func _tint(b: B) -> void:
	var r: PartRenderer = _belt_r(b) if b.beh == "belt" else renderer(b.type)
	r.set_tint(b, 1.0 - b.hp / b.maxhp, b.flash)


func repair(b: B, amount: float) -> void:
	b.hp = min(b.maxhp, b.hp + amount)
	_tint(b)
	if b.hp >= b.maxhp:
		damaged.erase(b)


func building_at(c: Vector2i) -> B:
	var b = grid.get(World.wc(c), null)
	return b if b != null else found_top(c)


func nearest_building(pos: Vector3, r: int) -> B:
	var c := World.world_to_cell(pos)
	var best: B = null
	var bd := INF
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			var b: B = grid.get(World.wc(c + Vector2i(dx, dz)))
			if b == null or b.p("wild", false):
				continue
			var d := float(dx * dx + dz * dz)
			if b.beh in ["belt", "floor"]:
				d += 30.0
			if d < bd:
				bd = d
				best = b
	return best


# ---------------------------------------------------------------- симуляция

func _process(delta: float) -> void:
	if game == null or game.is_frozen():
		return
	acc += delta
	var steps := 0
	while acc >= TICK and steps < 4:
		acc -= TICK
		var t0 := Time.get_ticks_usec()
		_tick(TICK)
		prof_tick += Time.get_ticks_usec() - t0
		prof_ticks += 1
		steps += 1
	var _pt := Time.get_ticks_usec()
	for k in item_mats:
		item_mats[k].set_shader_parameter("now", sim_time + acc)
	_update_turret_heads(delta)
	_update_flash(delta)
	_update_lights()
	_update_emitters(delta)
	if game.prof_on: game._prof("factory.visual", _pt)


func _tick(dt: float) -> void:
	sim_time += dt
	tick_i += 1
	var pf: bool = game.prof_on
	var _q := Time.get_ticks_usec() if pf else 0
	if power_dirty:
		_rebuild_power()
	var due = sched.get(tick_i)
	if due != null:
		sched.erase(tick_i)
		for b in due:
			if b.dead or b.item == "":
				continue
			if b.beh == "splitter":
				_split(b)
				continue
			if b.beh == "merger":
				if b.next != null and accept(b.next, b.item, b):
					clear_item(b)
				else:
					_schedule(b, tick_i + 2)
				continue
			if sim_time + 0.001 < b.t_in + b.period:
				continue
			var t = b.next
			if t == null:
				continue
			if t.beh == "belt":
				if t.item == "":
					if t.next != b:
						if t.kind != 0 and _spill(t, b.item):
							clear_item(b)
						else:
							set_item(t, b.item, b.t_in + b.period)
							clear_item(b)
				else:
					t.waiters.append(b)
			elif accept(t, b.item, b):
				clear_item(b)
			else:
				_schedule(b, tick_i + 4)
	if pf: game._prof("ft.belts", _q); _q = Time.get_ticks_usec()
	_power(dt)
	if pf: game._prof("ft.power", _q); _q = Time.get_ticks_usec()
	fz.tick_power(dt)
	fluid_acc += dt
	if fluid_acc >= float(DB.setting("fluid_tick", 0.25)) - 0.001 or fluid_dirty:
		_fluids(fluid_acc)
		fluid_acc = 0.0
	if pf: game._prof("ft.fluids", _q); _q = Time.get_ticks_usec()
	var mult: float = 1.0 + game.bonus("machine_speed")
	var _m := 0
	for b in machines:
		if pf: _m = Time.get_ticks_usec()
		var was: bool = b.active
		if b.ev_halt:
			b.active = false
			if was:
				renderer(b.type).set_active(b, 0.0)
			continue
		match b.beh:
			"miner":
				_miner(b, dt * mult * b.mult * Progress17.k(b))
			"crafter":
				_crafter(b, dt * mult * b.mult * Progress17.k(b))
			"generator":
				if b.p("reactor", false) and (b.net < 0 or nets.is_empty()):
					nuc.power(b, dt, true)   # без сети реактор всё равно греется
			"storage":
				pass
			"hq_link":
				_hq_link_take(b, dt)
		if b.active and b.beh in ["miner", "crafter"]:
			_update_tool(b)
		if pf: game._prof("fm." + b.beh, _m); _m = Time.get_ticks_usec()
		if not b.subs.is_empty():
			fz.flow(b)
		_push_out(b)
		if pf: game._prof("fm.push", _m); _m = Time.get_ticks_usec()
		if b.subs.is_empty() and b.out != null and _out_full(b) and Fusion.overflow_of(b) == "trash":
			fz.trash(b, b.out)
		if not b.subs.is_empty():
			fz.push_chest(b)
		if was != b.active:
			renderer(b.type).set_active(b, 1.0 if b.active else 0.0)
	if pf: game._prof("ft.machines", _q); _q = Time.get_ticks_usec()
	fz.tick_subs(dt * mult)
	tune_acc += dt
	if tune_acc >= 1.0:
		Tuning.wear(self, tune_acc)
		tune_acc = 0.0
	if pf: game._prof("ft.subs", _q); _q = Time.get_ticks_usec()
	_turrets(dt)
	if pf: game._prof("ft.turrets", _q); _q = Time.get_ticks_usec()
	_auto_repair(dt)
	block_acc += dt
	if block_acc >= 0.25:
		_update_blocks(block_acc)
		block_acc = 0.0


## Здания, собранные из блоков поведения (4 раза в секунду).
func _update_blocks(dt: float) -> void:
	var night: bool = game.is_night()
	var ev := ""
	if night != was_night:
		was_night = night
		ev = "night" if night else "day"
		if night and game.has_method("quip"):
			game.quip("night")
	for b in block_bldgs.duplicate():
		if b.dead:
			continue
		var was: bool = b.active
		Blocks.update(self, b, dt)
		if ev != "":
			Blocks.event(game, b, ev)
		if was != b.active and b.beh != "belt":
			renderer(b.type).set_active(b, 1.0 if b.active else 0.0)


## Событие для всех зданий с блоками (начало волны и т. п.).
func blocks_event(name: String) -> void:
	for b in block_bldgs.duplicate():
		if not b.dead:
			Blocks.event(game, b, name)


## Отдать готовый предмет вперёд (на ленту или в соседнее здание).
func _push_out(b: B) -> void:
	var src: Inventory = b.out if b.out != null else (b.inv if b.beh == "storage" and not b.p("megaproject", false) else null)
	if src == null or b.next == null:
		return
	var id := _first_solid(src, true)   # A-2 r9: инструменты и подпорченная еда на ленту не уходят (лента не хранит износ)
	if b.beh == "miner" and src.slots.size() > 1:
		# A18-4: бур отдаёт по очереди из всех ячеек — богатая руда не застревает за обычной
		var ids := []
		for s0 in src.slots:
			if s0 != null and not DB.is_fluid(s0.id) and not (s0.has("dur") or s0.has("fresh")) and not s0.id in ids:
				ids.append(s0.id)
		if ids.size() > 1 and b.nexts.size() <= 1 and not (b.next.beh == "storage" and b.beh == "storage"):
			# по кругу; что получатель не берёт — пропускаем (поток обычной руды не падает)
			for k in ids.size():
				var cid: String = ids[(b.out_rr + k) % ids.size()]
				if accept(b.next, cid, b):
					_take_plain(src, cid)
					b.out_rr = (b.out_rr + k + 1) % ids.size()
					return
			return
	if not b.subs.is_empty() and not Fusion.out_filter(b).is_empty():
		# 15.5: составное отдаёт на ленту только выбранное игроком
		id = ""
		for sl in src.slots:
			if sl != null and not DB.is_fluid(sl.id) and not (sl.has("dur") or sl.has("fresh")) and Fusion.out_ok(b, sl.id):
				id = sl.id
				break
	if id == "":
		return
	var t: B = b.next
	if b.nexts.size() > 1:
		# 1.3: несколько выходов — по очереди; занятый пропускаем
		for k in b.nexts.size():
			var t2: B = b.nexts[(b.out_rr + k) % b.nexts.size()]
			if t2.dead or (t2.beh == "storage" and b.beh == "storage"):
				continue
			if accept(t2, id, b):
				_take_plain(src, id)
				b.out_rr = (b.out_rr + k + 1) % b.nexts.size()
				return
		return
	if t.beh == "storage" and b.beh == "storage":
		return
	if accept(t, id, b):
		_take_plain(src, id)


## 15.6: рабочая мощность здания 0..1 (ползунок 0–100% в окне здания; «Выключено» — 0).
static func clock(b) -> float:
	if b != null and b.host != null:
		return clock(b.host)   # A-2 r4: встроенные машины работают так, как выставлено у основы
	if b == null or b.cfg.get("off", false):
		return 0.0
	if on_off_only(b):
		return 1.0
	return clampf(float(b.cfg.get("clock", 100.0)) / 100.0, 0.0, 1.0)


## 1.1.15 (A-6/A-8 r3): здания, у которых нет «половинной» работы (портал, радар, щит, обогреватель, АЭС…), —
## только «Включить/Выключить», без ползунка мощности.
static func on_off_only(b) -> bool:
	if b == null:
		return false
	if bool(b.p("reactor", false)):
		return true
	return not b.blk and b.beh in ["decor", "storage"] and str(b.p("defense", "")) == ""


## 15.6: подключённая машина ест энергию всё время, пока не выключена (правило «Постоянное потребление»).
static func power_constant() -> bool:
	return bool(DB.setting("power_constant", true))


# ---------------------------------------------------------------- 1.1.15: оборона и канал штаба

## Патроны турели — в её собственном магазине (а не в штабе). Выключается правилом defense115.local_ammo.
static func local_ammo() -> bool:
	return bool(DB.setting("defense115", {}).get("local_ammo", true))


func _turret_mag(b: B) -> void:
	var ammo := str(b.p("ammo", ""))
	if ammo == "" or not local_ammo():
		return
	b.inv = Inventory.new(int(b.p("ammo_slots", 2)))
	b.inv.allow = func(id): return id == ammo


static func link_cfg() -> Dictionary:
	return DB.setting("hq_link115", {})


## Мощность канала: клеток до штаба × 3 (настройка power_per_cell).
func hq_link_power(b: B) -> void:
	var anc = link_home(b)[1]
	if anc == null:
		b.pow_ov = float(link_cfg().get("power_min", 2.0))
		return
	var cells := World.dist(b.center(), anc.center()) / World.C
	b.pow_ov = maxf(float(link_cfg().get("power_min", 2.0)), ceilf(cells) * float(link_cfg().get("power_per_cell", 2.0)))


## 1.1.15: с чьим складом связан канал: в комнате «отдельные базы» канал гостя — со складом его базы, а не со штабом хозяина.
## Возвращает [склад, здание-якорь для расстояния] (или [null, null], если базы ещё нет).
func link_home(b: B) -> Array:
	var N = Net._self()
	if Net.active() and N.separate():
		var own := str(b.bstate.get("owner", ""))
		var host_nick: String = N.nick if Net.is_host() else str(N.peers.get(1, {}).get("nick", ""))
		if own != "" and own != host_nick:
			var ob = game.coop.outpost_of(own)
			return [ob.inv, ob] if ob != null and ob.inv != null else [null, null]
	return [hq.inv if hq != null and not hq.dead else null, hq]


## 1.1.15: канал ест энергию, только когда работает (раньше — всегда, даже пустой).
func link_busy(b: B) -> bool:
	if link_mode(b) == "send":
		return b.timer > 0.0
	var items = b.cfg.get("items", [])
	return items is Array and not items.is_empty() and link_home(b)[0] != null and b.out.slots.has(null)


static func link_mode(b) -> String:
	return "take" if str(b.cfg.get("mode", "send")) == "take" else "send"


## Каждый второй предмет теряется (настройка loss_every).
func _link_keep(b: B) -> bool:
	b.link_n += 1
	var every := int(link_cfg().get("loss_every", 2))
	return every <= 1 or b.link_n % every != 0


## «В штаб»: всё, что пришло на вход, сразу в штабе (каждый второй — теряется).
func _hq_link_in(b: B, item: String) -> bool:
	var home: Inventory = link_home(b)[0]
	if link_mode(b) != "send" or home == null or DB.is_fluid(item):
		return false
	if sat_c(b) < 0.3:
		b.active = false
		return false
	b.active = true
	b.timer = 3.0   # занят ещё 3 с — пока занят, ест энергию
	if not _link_keep(b):
		return true
	if home.add(item, 1) != 0:
		b.link_n -= 1
		return false
	stats.delivered += 1   # 1.1.15: доставка через канал засчитывается заданиям и достижениям
	game.on_delivered(item)
	return true


## «Из штаба»: выбранные предметы забираются из штаба и выходят на ленту (каждый второй — теряется).
func _hq_link_take(b: B, dt: float) -> void:
	var lh: Array = link_home(b)
	var home: Inventory = lh[0]
	if b.pow_ov < 0.0 or (lh[1] != null and b.get_meta("hq_at", Vector2i(-1, -1)) != lh[1].cell):
		hq_link_power(b)
		if lh[1] != null:
			b.set_meta("hq_at", lh[1].cell)
	if link_mode(b) != "take":
		b.timer = maxf(0.0, b.timer - dt)
		b.active = b.timer > 0.0
		return
	var items: Array = b.cfg.get("items", []) if b.cfg.get("items") is Array else []
	var s := sat_c(b)
	if home == null or items.is_empty() or s < 0.3 or not b.out.slots.has(null):
		b.active = false
		return
	b.timer += dt * s
	var period := 60.0 / maxf(1.0, float(link_cfg().get("take_per_min", 60.0)))
	if b.timer < period:
		return
	b.timer = 0.0
	for k in items.size():
		var it := str(items[(b.out_rr + k) % items.size()])
		if home.count(it) > 0:
			b.out_rr = (b.out_rr + k + 1) % items.size()
			b.active = true
			if _link_keep(b):
				if home.move_to(b.out, it, 1) <= 0:   # A-4 r10: ячейкой — с износом и свежестью
					return
			else:
				home.remove(it, 1)
			return
	b.active = false


func _sat(b: B) -> float:
	if b.host != null:
		return b.host.csat
	if not b.subs.is_empty():
		return b.csat
	var need := float(b.p("power", 0))
	if need <= 0.0:
		return 1.0
	if b.net < 0:
		return 0.0
	return nets[b.net].sat


func _miner(b: B, dt: float) -> void:
	var stack := DB.stack_of(b.recipe)
	b.want = b.out.count(b.recipe) < min(stack, 20)
	var s := _sat(b) * clock(b)
	b.active = b.want and s > 0.01
	if not b.active:
		return
	b.timer += dt * s * Tuning.k(b, "speed")
	var per := miner_period(b)
	var n := 0
	while b.timer >= per and n < 8 and b.out.count(b.recipe) < min(stack, 20):
		b.timer -= per
		n += 1
		b.out.add(b.recipe, 1)
		_made(b, 1, b.recipe)
		# шанс на редкую добычу из таблицы месторождения (world.deposits[].drops)
		for d in _deposit_drops(b.recipe):
			if randf() < float(d.get("chance", 0.0)):
				b.out.add(d.get("item", ""), randi_range(int(d.get("min", 1)), int(d.get("max", 1))))
	if b.timer >= per:
		b.timer = per   # выход полон — не копим


## 13.10: скорость бура = «в минуту» качества залежи (для Mk1) × «Множитель добычи» бура (Mk2 — ×2, Mk3 — ×3...).
## Насосы, жидкости и залежи без качества — по старому полю «Бур: секунд на руду».
func miner_rate(b: B) -> float:
	var base := 60.0 / maxf(0.01, float(b.p("period", 2.0)))
	if str(b.p("water_item", "")) != "" or str(b.p("extracts", "solid")) == "fluid":
		return base
	var pu: Dictionary = game.world.purity_of(miner_cell(b.type, b.cell))
	if pu.is_empty():
		return base
	var mult := float(b.p("rate_mult", b.p("tier", 1)))
	return maxf(0.1, float(pu.get("per_min", 60.0)) * maxf(0.01, mult))


func miner_period(b: B) -> float:
	if b.mine_period <= 0.0 or b.mine_rev != DB.revision:
		b.mine_rev = DB.revision
		b.mine_period = 60.0 / miner_rate(b)
	return b.mine_period


var _dep_drops_rev := -1
var _dep_drops := {}
func _deposit_drops(item: String) -> Array:
	if _dep_drops_rev != DB.revision:
		_dep_drops_rev = DB.revision
		_dep_drops.clear()
		for dd in DB.data.world.get("deposits", []):
			_dep_drops[dd.get("item", "")] = dd.get("drops", [])
	return _dep_drops.get(item, [])


func _crafter(b: B, dt: float) -> void:
	if b.crafting == "":
		# 21: сырьё и выход не менялись с прошлой неудачной попытки — рецепты не перебираем
		# (раз в 0.4 с всё равно пробуем: вдруг ячейку поменяли напрямую)
		var key: int = b.inv.ver * 65536 + (b.out.ver if b.out != null else 0)
		if key == b.idle_key and tick_i < b.idle_until:
			b.want = false
			b.active = false
			return
		var rid := _pick_recipe(b)
		if rid == "":
			b.idle_key = key
			b.idle_until = tick_i + 10
			if b.fuel != null and b.recipe == "" and b.fuel.first_item() == "":
				# 1.1.11: топливо лежит в сырье, а топка пуста — переложить (старые сохранения)
				for k in b.inv.totals():
					if fuel_ok(b, k):
						var n: int = b.inv.count(k)
						var left: int = b.fuel.add(k, n)
						b.inv.remove(k, n - left)
		if rid != "":
			var r: Dictionary = DB.data.recipes[rid]
			for k in r.get("in", {}):
				b.inv.remove(k, int(r["in"][k]))
			b.crafting = rid
			b.last_rid = rid
			b.prog = 0.0
	b.want = b.crafting != ""
	if not b.want:
		b.active = false
		return
	var rate := float(b.p("speed", 1.0)) * _sat(b) * clock(b)
	if b.fuel != null and not Fusion.heats_by_power(b):
		if b.fuel_t <= 0.0:
			var f := b.fuel.first_item()
			if f != "":
				b.fuel.remove(f, 1)
				b.fuel_t += float(DB.item(f).get("fuel", 0)) * Tuning.k(b, "fuel")
			else:
				rate = 0.0
		b.fuel_t = max(0.0, b.fuel_t - dt * maxf(0.05, _sat(b) * clock(b))) if rate > 0.0 else b.fuel_t
	b.active = rate > 0.0
	if not b.active:
		return
	var r2: Dictionary = DB.data.recipes.get(b.crafting, {})
	b.prog += dt * rate * Tuning.k(b, "speed") / max(0.05, float(r2.get("time", 1.0)))
	if b.prog >= 1.0:
		for k in r2.get("out", {}):
			b.out.add(k, int(r2["out"][k]))
			_made(b, int(r2["out"][k]), k)
		# 14.23: точная настройка иногда даёт лишний предмет
		var xc := Tuning.extra_chance(b)
		if xc > 0.0 and randf() < xc:
			for k in r2.get("out", {}):
				if not DB.is_fluid(k):
					b.out.add(k, 1)
					_made(b, 1)
					break
		b.crafting = ""
		b.prog = 0.0


func _pick_recipe(b: B) -> String:
	var ids: Array = [b.recipe] if b.recipe != "" else DB.recipes_for(b.p("station", ""))
	var tot: Dictionary = b.inv.totals()
	for rid in ids:
		var r: Dictionary = DB.data.recipes.get(rid, {})
		if r.is_empty():
			continue
		var ok := true
		for k in r.get("in", {}):
			if int(tot.get(k, 0)) < int(r["in"][k]):
				ok = false
				break
		if not ok:
			continue
		for k in r.get("out", {}):
			if not b.out.can_add(k, int(r["out"][k])):
				ok = false
				break
		if ok:
			return rid
	return ""


## Подходит ли предмет как сырьё для машины.
## В режиме «авто» машина не смешивает сырьё разных рецептов: новый предмет берётся, только если
## есть рецепт, которому подходит и он, и всё, что уже лежит внутри (иначе машина забивается).
func _is_input(b: B, item: String) -> bool:
	var ids: Array = [b.recipe] if b.recipe != "" else DB.recipes_for(b.p("station", ""))
	var inside: Array = b.inv.totals().keys() if b.inv != null else []
	if b.fuel != null and b.recipe == "":
		# 1.1.11: топливо, случайно попавшее в сырьё (старые сохранения), не мешает другим рецептам
		inside = inside.filter(func(k): return not fuel_ok(b, k) or k == item)
	for rid in ids:
		var ins: Dictionary = DB.data.recipes.get(rid, {}).get("in", {})
		if not ins.has(item):
			continue
		var fits := true
		for k in inside:
			if not ins.has(k):
				fits = false
				break
		if fits:
			return true
	return false


## Сырьё хоть одного рецепта машины (без проверки смешивания).
## 1.1.16: руками в машину без выбранного рецепта можно добавить сырьё другого рецепта с тем же
## результатом (обычная и богатая руда в одну печь), но не смешать железо с медью.
func _any_input(b: B, item: String) -> bool:
	if b.recipe != "" or b.inv == null:
		return false
	var outs := {}   # что получается из того, что можно сделать из item
	var ids: Array = DB.recipes_for(b.p("station", ""))
	for rid in ids:
		var r: Dictionary = DB.data.recipes.get(rid, {})
		if r.get("in", {}).has(item):
			for o in r.get("out", {}):
				outs[o] = true
	if outs.is_empty():
		return false
	for k in b.inv.totals():
		if b.fuel != null and fuel_ok(b, k):
			continue
		var same := false
		for rid in ids:
			var r: Dictionary = DB.data.recipes.get(rid, {})
			if r.get("in", {}).has(k):
				for o in r.get("out", {}):
					if outs.has(o):
						same = true
		if not same:
			return false
	return true


## 18: сколько машина держит про запас этого сырья с ленты: 2 крафта, но не меньше 20.
## Раньше было ровно 20 — и рецепт на 50 штук (ТВЭЛ) с ленты не запускался никогда.
func in_cap(b: B, item: String) -> int:
	var ids: Array = [b.recipe] if b.recipe != "" else DB.recipes_for(b.p("station", ""))
	var need := 0
	for rid in ids:
		need = maxi(need, int(DB.data.recipes.get(rid, {}).get("in", {}).get(item, 0)))
	return maxi(20, need * 2)


## Разделитель: по очереди вперёд, влево, вправо.
## Разделитель: выходы вперёд, влево, вправо по очереди.
## Умный разделитель (параметр smart): у каждого выхода свой фильтр —
## any (любое), items (только выбранные), rest (всё, что не выбрано на других выходах),
## overflow (только когда остальные заняты), none (закрыт). Выбранные предметы идут в первую очередь.
const OUT_RELS := [0, 3, 1]   # вперёд, влево, вправо (относительно направления здания)

func _split(b: B) -> void:
	if not (b.p("smart", false) and b.cfg.has("outs")):
		if _try_outs(b, OUT_RELS):
			return
		_schedule(b, tick_i + 2)
		return
	_seen(b)
	var spec := []
	var common := []
	var over := []
	for rel in OUT_RELS:
		var m: Dictionary = out_mode(b, rel)
		match str(m.get("mode", "any")):
			"items":
				if b.item in m.get("items", []):
					spec.append(rel)
			"any", "rest":
				common.append(rel)
			"overflow":
				over.append(rel)
	# 21: назначенный предмет едет только в свой выход (ждёт, если там занято) — не утекает в другие
	if not spec.is_empty():
		if _try_outs(b, spec):
			return
		_schedule(b, tick_i + 2)
		return
	if _try_outs(b, common) or _try_outs(b, over):
		return
	_schedule(b, tick_i + 2)


## 21: на повороте ленты Mk1–Mk2 предмет может слететь и упасть рядом (бортики спасают).
## Шанс: «Потери на лентах» (% для Mk1, у Mk2 вдвое меньше, с Mk3 не слетает).
func _spill(t: B, item: String) -> bool:
	if t.kind == 0 or loading or bool(t.bstate.get("rails", false)):
		return false
	var tier := tier_of(t.type)
	if tier >= 3:
		return false
	var pct := float(DB.setting("belt_spill_pct", 2.0)) / (1.0 if tier <= 1 else 2.0)
	if pct <= 0.0 or randf() * 100.0 >= pct:
		return false
	# падает наружу поворота
	var out_dir: Vector2i = DIRS[(t.dir + (3 if t.kind < 0 else 1)) % 4]
	var at: Vector3 = t.center() + Vector3(out_dir.x, 0, out_dir.y) * C * 0.45 + Vector3(0, t.y + 0.6, 0)
	stats["spilled"] = int(stats.get("spilled", 0)) + 1
	if game.get("drops") != null:
		game.drops.spawn(item, 1, at)
	return true


## 21: «Бортики» на ленте: предметы с неё больше не слетают.
func rails_ok(t: String, cell: Vector2i) -> bool:
	if str(DB.building(t).get("behavior", "")) != "rails":
		return false
	var b = building_at(cell)
	return b != null and b.beh == "belt" and not bool(b.bstate.get("rails", false))


func set_rails(b: B, on: bool) -> void:
	for rt in ["belt_rails", "belt_rails_corner"]:
		if renderers.has(rt) and renderers[rt].has(b):
			renderers[rt].remove(b)
	if on:
		b.bstate["rails"] = true
		if b.kind == 0:
			renderer("belt_rails").add(b, _xform(b))
		else:
			# поворот: Г-образные бортики по внешней стороне (модель — вход слева; вход справа — та же, повёрнутая)
			var xf := _xform(b)
			if b.kind == -1:
				xf.basis = xf.basis * Basis(Vector3.UP, -PI * 0.5)
			renderer("belt_rails_corner").add(b, xf)
	else:
		b.bstate.erase("rails")


## 21: что ехало через умный разделитель (для окна настройки), последние 12 видов.
func _seen(b: B) -> void:
	var sn: Dictionary = b.bstate.get("seen", {})
	if not sn.has(b.item):
		if sn.size() >= 12:
			var oldest := ""
			for k in sn:
				if oldest == "" or float(sn[k]) < float(sn[oldest]):
					oldest = k
			sn.erase(oldest)
	sn[b.item] = sim_time
	b.bstate["seen"] = sn


func out_mode(b: B, rel: int) -> Dictionary:
	return b.cfg.get("outs", {}).get(str(rel), {"mode": "any"})


func _listed_elsewhere(b: B, rel: int, item: String) -> bool:
	for r in OUT_RELS:
		if r != rel:
			var m: Dictionary = out_mode(b, r)
			if str(m.get("mode", "")) == "items" and item in m.get("items", []):
				return true
	return false


## Попробовать отдать предмет в один из выходов по очереди. true — отдали.
func _try_outs(b: B, rels: Array) -> bool:
	var n := rels.size()
	for i in n:
		var rel: int = rels[(b.rr + i) % n]
		var t = grid.get(World.wc(b.cell + DIRS[(b.dir + rel) % 4]))
		if t == null or t.next == b:
			continue
		if t.beh == "belt" and not _belt_starts_at(t, b):
			continue   # 1.1.17: лента просто проходит мимо разделителя — он в неё не сыплет
		if accept(t, b.item, b):
			b.rr = (b.rr + i + 1) % maxi(1, n)
			clear_item(b)
			return true
	return false


## 1.1.17: лента t начинается у f — f стоит у неё сзади или сбоку на повороте (а не лента идёт мимо прямо).
func _belt_starts_at(t: B, f: B) -> bool:
	var c: Vector2i = f.cell
	if World.wc(t.cell - DIRS[t.dir]) == c:
		return true
	if t.kind == 1 and World.wc(t.cell + DIRS[(t.dir + 3) % 4]) == c:
		return true
	if t.kind == -1 and World.wc(t.cell + DIRS[(t.dir + 1) % 4]) == c:
		return true
	return false


## С какой стороны сосед from относительно здания t: 0 спереди, 1 справа, 2 сзади, 3 слева; -1 — не сосед.
func _side_of(t: B, from) -> int:
	if from == null or not (from is B):
		return -1
	for d in 4:
		if grid.get(World.wc(t.cell + DIRS[d])) == from:
			return (d - t.dir + 4) % 4
	return -1


## Соединитель: принимает с трёх сторон по очереди (никто не ждёт вечно).
## Умный соединитель: главный вход (cfg.prio) пропускается первым, остальные — когда он пуст.
func _merge_turn(t: B, from) -> bool:
	var side := _side_of(t, from)
	if side < 0:
		return true
	var prio := int(t.cfg.get("prio", -1)) if t.p("smart", false) else -1
	var waiting := []
	var has_item := []
	for rel in [2, 3, 1]:
		var n = grid.get(World.wc(t.cell + DIRS[(t.dir + rel) % 4]))
		if n != null and n != from and n.next == t and n.item != "" and n.beh in ["belt", "splitter", "merger"]:
			has_item.append(rel)
			# в очереди только вход, чей предмет уже доехал до соединителя: далёкий не держит остальных
			if sim_time + 0.001 >= n.t_in + n.period:
				waiting.append(rel)
	if prio >= 0:
		if side != prio and prio in has_item:
			return false
		t.rr = side
		return true
	# по очереди: тот же вход второй раз подряд — только если больше никто не ждёт
	if side == t.rr and not waiting.is_empty():
		return false
	t.rr = side
	return true


## Когда предмет от ленты/разветвителя «доехал» (точное время, без округления до такта): иначе быстрые ленты
## и разветвители теряют скорость на каждом переходе.
func _carry_t(from) -> float:
	if from is B and from.beh in ["belt", "splitter", "merger"]:
		return from.t_in + from.period
	return -1.0


## Может ли здание t принять предмет от соседа from (from = null — от героя).
func accept(t: B, item: String, from) -> bool:
	if t.dead:
		return false
	if from != null and t.next == from and t.beh in ["belt", "splitter", "merger", "miner", "crafter", "storage"]:
		return false
	if t.pon and from != null and from is B and t.subs.is_empty() and not _at_input(t, from):
		return false   # 1.1.9: лента подведена не к входу
	if t.blk and Blocks.accept(t, item, self):
		return true
	match t.beh:
		"belt", "splitter":
			if t.item == "":
				if t.beh == "belt" and from != null and _spill(t, item):
					return true
				set_item(t, item, _carry_t(from))
				return true
		"junction":
			# 21: «Кротовина» — предмет проходит под поперечной лентой насквозь, на другую сторону
			if from == null or not (from is B):
				return false
			for d in 4:
				if grid.get(World.wc(t.cell + DIRS[d])) == from:
					var out = grid.get(World.wc(t.cell + DIRS[(d + 2) % 4]))
					if out == null or out == from or out.next == t:
						return false
					if out.beh == "junction":
						# 1.7: кротовины подряд передают насквозь (раньше между ними нужна была лента)
						if _jn_depth > 32:
							return false
						_jn_depth += 1
						var ok: bool = accept(out, item, t)
						_jn_depth -= 1
						return ok
					return accept(out, item, t)
			return false
		"merger":
			if t.item == "" and _merge_turn(t, from):
				set_item(t, item, _carry_t(from))
				return true
		"hq":
			if t.inv.add(item, 1) == 0:
				if from != null and game.counts_delivery(t):
					stats.delivered += 1
					game.on_delivered(item)
				return true
		"storage":
			# A16-1: основа полна — во встроенные ящики/склады составного
			if t.inv.add(item, 1) == 0 or (not t.subs.is_empty() and Fusion.chest_add(t, item, 1) == 0):
				if from != null and t.type == "outpost" and game.counts_delivery(t):   # B-2 r5: доставки гостя — в его аванпост
					stats.delivered += 1
					game.on_delivered(item)
				return true
			return false
		"crafter":
			if _fuel_first(t, item) and t.fuel.can_add(item, 1):
				t.fuel.add(item, 1)
				return true
			# 18: с ленты — запас на 2 крафта (не меньше 20), руками — сколько влезет (вся стопка)
			# 1.1.16: руками в «авто» можно класть сырьё разных рецептов (обычную и богатую руду вместе) — машина
			# сама выберет рецепт, для которого хватает; с ленты по-прежнему не смешивает (чтобы не забивалась)
			if (_is_input(t, item) or (from == null and _any_input(t, item))) and (from == null or t.inv.count(item) < in_cap(t, item)) and t.inv.can_add(item, 1):
				t.inv.add(item, 1)
				return true
			if t.fuel != null and fuel_ok(t, item) and t.fuel.can_add(item, 1):
				t.fuel.add(item, 1)
				return true
		"generator":
			if t.fuel != null and fuel_ok(t, item) and t.fuel.can_add(item, 1):
				t.fuel.add(item, 1)
				return true
		"terminal":
			return game.tech.accept_item(item)
		"turret":
			var ammo: String = t.p("ammo", "")
			if ammo != "" and item == ammo:
				if t.inv != null:
					# 1.1.15: патроны — в магазин самой турели (лентой, руками, каналом штаба), а не в штаб
					if t.inv.can_add(item, 1):
						t.inv.add(item, 1)
						return true
					return false
				if hq != null:
					return hq.inv.add(item, 1) == 0
		"hq_link":
			return _hq_link_in(t, item)
	if not t.subs.is_empty():
		return fz.accept_sub(t, item)
	return false


## A-5 r8: примет ли здание предмет «в руки» (узел дронов, без ленты) — без побочных действий.
func would_accept(t: B, item: String) -> bool:
	if t.dead:
		return false
	match t.beh:
		"hq", "storage":
			return t.inv != null and t.inv.can_add(item, 1)
		"crafter":
			if t.fuel != null and fuel_ok(t, item) and t.fuel.can_add(item, 1):
				return true
			return t.inv != null and _is_input(t, item) and t.inv.can_add(item, 1)
		"generator":
			return t.fuel != null and fuel_ok(t, item) and t.fuel.can_add(item, 1)
		"turret":
			var ammo: String = t.p("ammo", "")
			return ammo != "" and item == ammo and (t.inv == null or t.inv.can_add(item, 1))
	if t.inv != null and t.inv.allow.is_valid() and not t.inv.allow.call(item):
		return false
	var di = t.inv if t.inv != null else t.out
	return di != null and di.can_add(item, 1)


func set_recipe(b: B, rid: String) -> void:
	if b.recipe == rid:
		return
	var back: Dictionary = b.inv.totals()
	for k in back:
		give_player(k, back[k])
	b.inv.slots.fill(null)
	b.inv.changed.emit()
	_refund_crafting(b)
	b.crafting = ""
	b.prog = 0.0
	b.recipe = rid
	b.idle_key = -1


# ---------------------------------------------------------------- энергия

func _node_radius(b: B) -> float:
	if not b.beh in ELECTRIC_NODES:
		return Blocks.gen_radius(b)
	return float(b.p("radius", 10 if b.beh == "hq" else 6))


func _rebuild_power() -> void:
	power_dirty = false
	var old_net := {}
	for b in power_nodes:
		old_net[b] = b.net
	nets.clear()
	_rebuild_nets()
	# история графика переезжает к новым номерам сетей
	var nh := {}
	for b in power_nodes:
		if b.net >= 0 and not nh.has(b.net) and net_hist.has(old_net.get(b, -1)):
			nh[b.net] = net_hist[old_net[b]]
	net_hist = nh


func _rebuild_nets() -> void:
	var parent := {}
	for b in power_nodes:
		parent[b] = b
	var find := func(x):
		while parent[x] != x:
			parent[x] = parent[parent[x]]
			x = parent[x]
		return x
	if wired():
		_rebuild_wired()
		return
	var lk := []
	if stations_mode():
		for node in power_nodes:
			parent[node] = power_nodes[0]
	else:
		for i in power_nodes.size():
			var a: B = power_nodes[i]
			for j in range(i + 1, power_nodes.size()):
				var c: B = power_nodes[j]
				var d := World.dist(a.center(), c.center()) / C
				if d <= max(_link_radius(a), _link_radius(c)) or (a.p("entangled", false) and Quantum.linked(a, c)):
					var ra = find.call(a)
					var rc = find.call(c)
					if ra != rc:
						parent[ra] = rc
						lk.append([a, c])
	var ids := {}
	for b in power_nodes:
		var root = find.call(b)
		if not ids.has(root):
			ids[root] = nets.size()
			nets.append({"supply": 0.0, "demand": 0.0, "sat": 0.0, "stored": 0.0, "cap": 0.0, "tripped": false, "over_t": 0.0, "gen_max": 0.0})
		b.net = ids[root]
		if b.tripped:
			nets[b.net].tripped = true
	consumers.clear()
	st_pairs.clear()
	var st := stations_mode()
	var feeders := []
	if st:
		for n in power_nodes:
			if station_cap(n) > 0.0:
				feeders.append(n)
	for b in all:
		if b.beh in ELECTRIC_NODES or b in power_nodes:
			continue
		b.net = -1
		b.feeder = null
		b.pw_state = 0
		if float(b.p("power", 0)) <= 0.0 and b.subs.is_empty():
			continue
		consumers.append(b)
		if st:
			# 21: здание питается от станций, в радиус которых попадает
			for n in feeders:
				var d2: float = World.dist(n.center(), b.center()) / C
				if d2 <= station_radius(n) + (b.size - 1) * 0.5 + (n.size - 1) * 0.5:
					st_pairs.append([d2, b, n])
			continue
		var best := INF
		for n in power_nodes:
			var d: float = World.dist(n.center(), b.center()) / C
			if d <= _node_radius(n) + (b.size - 1) * 0.5 and d < best:
				best = d
				b.net = n.net
	if st:
		st_pairs.sort_custom(func(x, y): return x[0] < y[0])
		_assign_stations()
		lk = []   # станции работают без проводов
	_draw_wires(lk)


# ---------------------------------------------------------------- 21: станции энергии
## «Станции»: энергию до машин доносят станции энергопередачи. Каждая отдаёт не больше своей мощности
## зданиям в своём радиусе; ближние к станции получают первыми, остальным не хватает.
func stations_mode() -> bool:
	return str(DB.setting("power_mode", "stations")) == "stations"


## Сколько энергии станция передаёт зданиям вокруг (0 — это не станция).
func station_cap(n: B) -> float:
	if n == null or n.dead or n.host != null:
		return 0.0
	if n.beh == "hq":
		return float(n.p("transfer", DB.setting("hq_transfer", 40)))
	if n.beh != "pole":
		return 0.0
	return float(n.p("transfer", 0)) * n.mult


## Радиус станции в клетках: здания в нём питаются от неё.
func station_radius(n: B) -> float:
	if n.beh == "hq":
		return float(n.p("station_radius", DB.setting("hq_station_radius", 5)))
	return float(n.p("radius", 3))


## Сколько энергии здание просит у станции (по паспорту, с учётом слияния и разгона).
func station_need(b: B) -> float:
	if not b.subs.is_empty():
		return maxf(float(b.p("power", 0)) * Fusion.power_k(b), b.grid_need)
	return float(b.p("power", 0)) * Fusion.power_k(b) * maxf(clock(b), 0.0)


## Раздать мощность станций: каждое здание берёт от ближайшей станции, где ещё хватает запаса.
func _assign_stations() -> void:
	var left := {}
	for n in power_nodes:
		var c := station_cap(n)
		if c > 0.0:
			left[n] = c
			n.bstate["st_load"] = 0.0
			n.bstate["st_cap"] = c
			n.bstate["st_short"] = 0
	for b in consumers:
		b.feeder = null
		b.pw_state = 0
	for pr in st_pairs:
		var b: B = pr[1]
		var n: B = pr[2]
		if b.feeder != null or b.dead or n.dead or n.net < 0:
			continue
		var need := station_need(b)
		if need <= float(left.get(n, 0.0)) + 0.0001:
			left[n] = float(left[n]) - need
			b.feeder = n
			b.pw_state = 1
			n.bstate["st_load"] = float(n.bstate.get("st_load", 0.0)) + need
		else:
			b.pw_state = 2
	# 1.1.20 A15-2: крупному зданию (нужно больше, чем даёт одна станция) мощность складывается из нескольких станций рядом
	var multi := {}
	for pr in st_pairs:
		var b2: B = pr[1]
		var n2: B = pr[2]
		if b2.feeder == null and b2.pw_state == 2 and not b2.dead and not n2.dead and n2.net >= 0 and float(left.get(n2, 0.0)) > 0.0:
			if not multi.has(b2):
				multi[b2] = []
			if not n2 in multi[b2]:
				multi[b2].append(n2)
	for b2 in multi:
		var need2 := station_need(b2)
		var have := 0.0
		for n2 in multi[b2]:
			have += float(left.get(n2, 0.0))
		if have + 0.0001 < need2 or multi[b2].size() < 2:
			continue
		var rest := need2
		var best: B = null
		var best_k := -1.0
		for n2 in multi[b2]:
			var k: float = minf(rest, float(left[n2]))
			if k <= 0.0:
				continue
			left[n2] = float(left[n2]) - k
			n2.bstate["st_load"] = float(n2.bstate.get("st_load", 0.0)) + k
			rest -= k
			if k > best_k:
				best_k = k
				best = n2
		b2.feeder = best
		b2.pw_state = 1
	for b in consumers:
		if b.feeder != null:
			b.net = b.feeder.net
		else:
			if b.pw_state == 2:
				for pr in st_pairs:
					if pr[1] == b:
						pr[2].bstate["st_short"] = int(pr[2].bstate.get("st_short", 0)) + 1
						break
			b.net = -1


## Связь между станциями, генераторами и аккумуляторами (в клетках).
func _link_radius(b: B) -> float:
	if stations_mode() and b.beh == "pole":
		return float(b.p("link", b.p("radius", 3)))
	return _node_radius(b)


func _draw_wires(lk: Array) -> void:
	if lk.is_empty():
		wires.mesh = null
		return
	# провод — две узкие ленты крестом, чтобы было видно с любой стороны
	var w := float(DB.setting("wire_width", 0.07))
	var col := DB.color(DB.setting("wire_color", "#1c1d22"))
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for l in lk:
		var a: Vector3 = l[0].center() + Vector3(0, _wire_h(l[0]), 0)
		var c: Vector3 = a + World.delta(a, l[1].center() + Vector3(0, _wire_h(l[1]), 0))
		var side := (c - a).cross(Vector3.UP).normalized() * w * 0.5
		var up := Vector3(0, w * 0.5, 0)
		var prev := a
		for i in range(1, 11):
			var t := i / 10.0
			var p := a.lerp(c, t)
			p.y -= sin(t * PI) * a.distance_to(c) * 0.05
			for o in [side, up]:
				im.surface_set_color(col)
				im.surface_add_vertex(prev - o)
				im.surface_add_vertex(prev + o)
				im.surface_add_vertex(p + o)
				im.surface_add_vertex(prev - o)
				im.surface_add_vertex(p + o)
				im.surface_add_vertex(p - o)
			prev = p
	im.surface_end()
	wires.mesh = im


func _wire_h(b: B) -> float:
	var def := 2.0
	match b.beh:
		"pole": def = 3.6
		"hq": def = 5.5
	return float(b.p("wire_height", def))


func _power(dt: float) -> void:
	if nets.is_empty():
		return
	if stations_mode() and not st_pairs.is_empty():
		st_acc += dt
		if st_acc >= 0.5:
			st_acc = 0.0
			_assign_stations()   # разгон, слияние и составные здания меняют нужду
	for n in nets:
		n.supply = 0.0
		n.demand = 0.0
		n.cap = 0.0
		n.gen_max = 0.0
	# спрос: машины, которым есть что делать (список потребителей строится при перестройке сети)
	for b in consumers:
		if b.net < 0 or b.dead:
			continue
		var need := float(b.p("power", 0)) * Fusion.power_k(b) * clock(b)
		if not b.subs.is_empty():
			nets[b.net].demand += b.grid_need
			continue
		if need > 0.0 and (b.want or (power_constant() and b.beh in ["miner", "crafter"]) or b.beh == "turret" or (b.beh == "hq_link" and link_busy(b)) or (not b.blk and b.beh in ["decor", "storage"]) or float(b.p("shield_radius", 0)) > 0.0 or float(b.p("heat", 0)) != 0.0 or b.p("defense", "") != ""):
			nets[b.net].demand += need
	var day: float = game.sun_power() if game.has_method("sun_power") else game.daylight()
	var wind: float = game.wind() if game.has_method("wind") else 0.6
	for b in power_nodes:
		if b.net < 0:
			continue
		var n: Dictionary = nets[b.net]
		var off: bool = n.tripped
		match b.beh:
			"hq":
				n.gen_max += float(b.p("power", 0))
				if not off:
					n.supply += float(b.p("power", 0))
			"generator":
				var pw: float = float(b.p("power", 0)) * b.mult
				pw *= Tuning.k(b, "supply") * clock(b)
				n.gen_max += pw
				if clock(b) <= 0.0:
					if b.active:
						b.active = false
						renderer(b.type).set_active(b, 0.0)
					continue
				if b.p("solar", false):
					if not off:
						n.supply += pw * day
					b.active = day > 0.15 and not off
				elif b.p("reactor", false):
					n.supply += nuc.power(b, dt, off)
				elif b.p("wind", false):
					if not off:
						n.supply += pw * wind
					var won: bool = wind > 0.05 and not off
					if won != b.active:
						b.active = won
						renderer(b.type).set_active(b, 1.0 if won else 0.0)
				else:
					# 17.10: паровой генератор пьёт воду: без воды стоит
					var wpm := float(b.p("water_per_min", 0.0))
					var dry := false
					if wpm > 0.0:
						var need := wpm / 60.0 * dt
						dry = float(b.bstate.get("water", 0.0)) < need
					if not off and not dry and b.fuel_t <= 0.0 and n.demand > 0.0:
						var f: String = b.fuel.first_item()
						if f != "":
							b.fuel.remove(f, 1)
							b.fuel_t += burn_time(b, f)
					var on: bool = b.fuel_t > 0.0 and not off and not dry
					if on and wpm > 0.0 and n.demand > 0.0:
						b.bstate["water"] = maxf(0.0, float(b.bstate.get("water", 0.0)) - wpm / 60.0 * dt)
					if on:
						n.supply += pw
						if n.demand > 0.0:
							# 1.1.15: объединение N жжёт топливо за N, ползунок мощности снижает и расход
							b.fuel_t = max(0.0, b.fuel_t - dt * b.mult * maxf(0.05, clock(b)))
					if on != b.active:
						b.active = on
						renderer(b.type).set_active(b, 1.0 if on else 0.0)
			"battery":
				n.cap += float(b.p("capacity", 2000)) * b.mult
				n.stored += b.energy
			_:
				var bs := Blocks.power_supply(self, b, dt, n.demand) if not off else 0.0
				n.supply += bs
				b.bstate["pw_on"] = bs > 0.0
	fz.grid_pre(day, wind, dt)
	if game.coop:
		game.coop.grid(self, dt)   # 16: продажа энергии между игроками
	for b in power_nodes:
		if b.beh == "battery":
			b.energy = 0.0
	var fuses := bool(DB.setting("fuses", true))
	var delay := float(DB.setting("fuse_delay", 1.5))
	for ni in nets.size():
		var n: Dictionary = nets[ni]
		var bal: float = n.supply - n.demand
		var stored: float = n.stored
		if n.tripped:
			n.sat = 0.0
		elif bal >= 0.0:
			stored = min(n.cap, stored + bal * dt)
			n.sat = 1.0
			n.over_t = 0.0
		else:
			var need: float = -bal * dt
			var take: float = min(need, stored)
			stored -= take
			n.sat = clampf((n.supply + take / dt) / max(0.001, n.demand), 0.0, 1.0)
			# перегрузка: спрос больше выработки и аккумуляторы пусты — выбивает пробки
			if fuses and n.sat < 0.999:
				n.over_t += dt
				if n.over_t >= delay:
					_trip(ni)
			else:
				n.over_t = 0.0
		n.stored = stored
	fz.grid_post()
	# заряд раздаём обратно аккумуляторам поровну
	var per := {}
	for b in power_nodes:
		if b.beh == "battery":
			per[b.net] = per.get(b.net, 0) + 1
	for b in power_nodes:
		if b.beh == "battery":
			b.energy = nets[b.net].stored / per[b.net]
	# график: раз в секунду
	hist_t += dt
	trip_warned -= dt
	if hist_t >= 1.0:
		hist_t = 0.0
		for ni in nets.size():
			var h: Array = net_hist.get(ni, [])
			h.append([nets[ni].supply, nets[ni].demand, nets[ni].stored])
			if h.size() > 120:
				h.pop_front()
			net_hist[ni] = h
	for n in nets:
		n.stored = 0.0


func _trip(ni: int) -> void:
	nets[ni].tripped = true
	nets[ni].over_t = 0.0
	for b in power_nodes:
		if b.net == ni:
			b.tripped = true
	if trip_warned <= 0.0:
		trip_warned = 5.0
		game.notify(DB.tx("tripped", "Выбило пробки: машинам не хватило энергии! Поставьте ещё генераторы или аккумуляторы и включите сеть рубильником (E по генератору или опоре)."), Color(1, 0.55, 0.3))
		game.sfx.play_ui("alarm")


## Сводка сети, в которой стоит здание (для окна здания и интерфейса).
## Щит-купол работает: есть энергия (или энергия ему не нужна).
func shield_on(b: B) -> bool:
	if b.dead or b.cfg.get("off", false):
		return false
	if float(b.p("power", 0)) <= 0.0:
		return true
	return b.net >= 0 and sat_c(b) >= 0.5


## Обеспеченность энергией с учётом «Выключить» и ползунка мощности (спрос сети = power × clock).
func sat_c(b: B) -> float:
	return _sat(b) * clock(b)


func net_info(b: B) -> Dictionary:
	if b == null or b.net < 0 or b.net >= nets.size():
		return {}
	var n: Dictionary = nets[b.net]
	var stored := 0.0
	for x in power_nodes:
		if x.net == b.net and x.beh == "battery":
			stored += x.energy
	return {"supply": n.supply, "demand": n.demand, "sat": n.sat, "stored": stored, "cap": n.cap, "tripped": n.get("tripped", false), "gen_max": n.get("gen_max", 0.0), "hist": net_hist.get(b.net, [])}


# ---------------------------------------------------------------- бой

func _turrets(dt: float) -> void:
	var dmg_mult: float = 1.0 + game.bonus("damage")
	no_ammo_warned -= dt
	for b in turrets:
		if b.dead:
			continue
		b.cd -= dt
		var rng: float = float(b.p("range", 30)) * (1.0 + 0.1 * (b.lvl - 1))
		var pos: Vector3 = b.center() + Vector3(0, 1.45, 0)
		dmg_mult = (1.0 + game.bonus("damage")) * b.mult * Tuning.k(b, "damage")
		if b.target == null or not game.enemies.is_alive(b.target) or World.dist(game.enemies.pos_of(b.target), pos) > rng:
			b.target = game.enemies.nearest(pos, rng)
		if b.target == null or b.cd > 0.0:
			continue
		var ammo: String = b.p("ammo", "")
		var s := sat_c(b)
		if s < 0.3:
			b.active = false
			continue
		if ammo != "":
			var mag: Inventory = b.inv if b.inv != null else (hq.inv if hq != null else null)
			if mag == null or mag.count(ammo) <= 0:
				b.active = false
				if no_ammo_warned <= 0.0:
					game.notify("Турелям нужны патроны: подвезите лентой, через канал штаба или положите в турель." if b.inv != null else "Турелям нужны патроны! Положите их в штаб.", Color(1, 0.8, 0.2))
					no_ammo_warned = 20.0
				continue
			# A-7 r9: «Объединение N» бьёт ×N — и тратит N патронов за выстрел (не хватает — бьёт слабее)
			var need: int = maxi(1, int(ceil(b.mult - 0.01)))
			var got: int = mini(need, mag.count(ammo))
			mag.remove(ammo, got)
			if got < need:
				dmg_mult *= float(got) / float(need)
		b.active = true
		b.cd = float(b.p("rate", 0.22)) / max(0.3, s)
		var tp: Vector3 = pos + World.delta(pos, game.enemies.pos_of(b.target)) + Vector3(0, 0.5 - 1.45, 0)
		var fwd := Vector3(cos(b.aim), 0, -sin(b.aim))
		var muzzle: Vector3 = pos + fwd * 1.5 + fwd.cross(Vector3.UP) * (0.2 if randf() < 0.5 else -0.2)
		if not renderer(b.type).parts_with_role("slide").is_empty():
			b.recoil = 1.0
			var xf := _xform(b)
			var scale_k := float(ModelLib.model(renderer(b.type).model_id).get("scale", 1.0))
			var local := Vector3(1.628, 0.04, 0.36 * randi_range(-1, 1)) * scale_k
			var yaw := Basis(Vector3.UP, b.aim)
			muzzle = xf * (yaw * (Vector3.UP * 1.68 * scale_k + Basis(Vector3.BACK, b.pitch) * local))
			_aim_head(b)
		var laser := ammo == ""
		var bcol := str(b.p("beam_color", ""))
		game.fx.tracer(muzzle, tp, DB.color(bcol) if bcol != "" else (Color(0.4, 1.0, 1.0) if laser else Color(1.0, 0.8, 0.3)), 0.09 if laser else 0.06)
		game.sfx.play(str(b.p("shot_sound", "turret")), pos)
		var tpos: Vector3 = game.enemies.pos_of(b.target)
		game.enemies.hit(b.target, float(b.p("damage", 14)) * dmg_mult, false, b)
		# 13.10: взрыв по площади (пушка, ракеты, огнемёт): соседи получают часть урона
		var splash := float(b.p("splash", 0.0))
		if splash > 0.0:
			var sd := float(b.p("damage", 14)) * dmg_mult * float(b.p("splash_k", 0.6))
			for e2 in game.enemies.list.duplicate():
				if e2 != b.target and game.enemies.targetable(e2) and World.dist(e2.pos, tpos) < splash:
					game.enemies.hit(e2, sd, false, b)
			if splash >= 2.0:
				game.fx.explosion(tpos + Vector3(0, 0.6, 0), minf(splash * 0.5, 3.0), DB.color(bcol) if bcol != "" else Color(1.0, 0.55, 0.2))
		var chain := int(b.p("chain", 0))
		if chain > 0:
			# цепь молний: удар перескакивает на соседних монстров, каждый раз слабее
			var from_e = b.target
			var hit_list := [b.target]
			var dmg := float(b.p("damage", 14)) * dmg_mult
			for k in chain:
				dmg *= 0.7
				var nx = null
				var nd := float(b.p("chain_range", 7.0))
				for e in game.enemies.list:
					if e in hit_list or not game.enemies.targetable(e):
						continue
					var dd := World.dist(e.pos, from_e.pos)
					if dd < nd:
						nd = dd
						nx = e
				if nx == null:
					break
				game.fx.tracer(from_e.pos + Vector3(0, 0.8, 0), nx.pos + Vector3(0, 0.8, 0), Color(0.6, 0.8, 1.0), 0.12)
				game.enemies.hit(nx, dmg, false, b)
				hit_list.append(nx)
				from_e = nx
	dmg_mult = 1.0 + game.bonus("damage")
	if hq != null and hq.hp > 0:
		hq.cd -= dt
		if hq.cd <= 0.0:
			var hp := hq.center() + Vector3(0, 5.0, 0)
			var e = game.enemies.nearest(hp, float(hq.p("gun_range", 26)))
			if e != null:
				hq.cd = float(hq.p("gun_rate", 0.45))
				game.fx.tracer(hp, hp + World.delta(hp, game.enemies.pos_of(e)) + Vector3(0, 0.5 - 5.0, 0), Color(0.4, 0.85, 1.0))
				game.enemies.hit(e, float(hq.p("gun_damage", 12)) * dmg_mult, false, hq)


func _update_tool(b: B) -> void:
	var r := renderer(b.type)
	var phase := sim_time * 7.0 + float(b.cell.x + b.cell.y)
	for i in r.parts_with_role("spindle"):
		var xf: Transform3D = r.parts[i].local
		r.set_part_xform(b, i, xf.translated_local(Vector3.DOWN * (0.008 + 0.008 * sin(phase))).rotated_local(Vector3.UP, phase * 1.8))
	for i in r.parts_with_role("arm"):
		var xf: Transform3D = r.parts[i].local
		r.set_part_xform(b, i, xf.rotated_local(Vector3.UP, .34*sin(phase*.6)))
	for i in r.parts_with_role("press"):
		var xf: Transform3D = r.parts[i].local
		r.set_part_xform(b, i, xf.translated_local(Vector3.DOWN * (0.020 + 0.020 * cos(phase))))


func _update_turret_heads(delta: float) -> void:
	for b in turrets:
		var previous_recoil: float = b.recoil
		b.recoil = move_toward(b.recoil, 0.0, delta * 7.5)
		var moved: bool = previous_recoil != b.recoil
		if b.target != null and game.enemies.is_alive(b.target):
			var v: Vector3 = World.delta(b.center(), game.enemies.pos_of(b.target))
			var horizontal := Vector2(v.x, v.z).length()
			var yaw := lerp_angle(b.aim, atan2(-v.z, v.x), minf(1.0, delta * 10.0))
			var scale_k := float(ModelLib.model(renderer(b.type).model_id).get("scale", 1.0))
			var height := 1.68 * scale_k * _xform(b).basis.y.length()
			var pitch := lerp_angle(b.pitch, clampf(atan2(v.y + 0.5 - height, horizontal), -0.55, 1.1), minf(1.0, delta * 10.0))
			moved = moved or absf(yaw - b.aim) > 0.0001 or absf(pitch - b.pitch) > 0.0001
			b.aim = yaw
			b.pitch = pitch
		if moved:
			_aim_head(b)


func _aim_head(b: B) -> void:
	var r := renderer(b.type)
	var yaw := Transform3D(Basis(Vector3.UP, b.aim), Vector3.ZERO)
	for i in r.parts_with_role("head"):
		r.set_part_xform(b, i, yaw * r.parts[i].local)
	var scale_k := float(ModelLib.model(r.model_id).get("scale", 1.0))
	var pivot := Vector3.UP * 1.68 * scale_k
	var tilt := Basis(Vector3.BACK, b.pitch)
	var pitched := yaw * Transform3D(tilt, pivot - tilt * pivot)
	for i in r.parts_with_role("pitch"):
		r.set_part_xform(b, i, pitched * r.parts[i].local)
	var slide := pitched.translated_local(Vector3.LEFT * 0.15 * scale_k * b.recoil)
	for i in r.parts_with_role("slide"):
		r.set_part_xform(b, i, slide * r.parts[i].local)


func _update_flash(delta: float) -> void:
	var done := []
	for b in flashing:
		b.flash -= delta * 4.0
		if b.flash <= 0.0:
			b.flash = 0.0
			done.append(b)
		if not b.dead:
			_tint(b)
	for b in done:
		flashing.erase(b)


func _update_lights() -> void:
	var night: float = 1.0 - game.daylight()
	for b in lights:
		b.light.light_energy = night * 2.2
		b.light.visible = night > 0.05


# ---------------------------------------------------------------- дым, пар, искры

var _emit_acc := 0.0
var _near_active := 0.0
var _emit_t := 0.0
## Звуки работы рядом с героем: id звука -> {d: до ближайшего, pos: где он, n: сколько таких машин}
var work_near := {}

## Источники частиц задаются в модели: "emitters": [{kind, pos, when, rate, size}].
func _update_emitters(delta: float) -> void:
	_emit_acc += delta
	_emit_t += delta
	if _emit_acc < 0.1:
		return
	var dt := _emit_acc
	_emit_acc = 0.0
	var pp: Vector3 = game.player.position
	var near := 0
	var wn := {}
	for b in all:
		if b.beh == "belt":
			continue
		var d := World.dist(pp, b.center())
		if d > 55.0:
			continue
		if b.active and d < 18.0:
			near += 1
		if b.active and d < 40.0:
			var ws: String = str(DB.building(b.type).get("sounds", {}).get("work", ""))
			if ws != "":
				var w: Dictionary = wn.get(ws, {})
				if w.is_empty() or d < float(w.d):
					wn[ws] = {"d": d, "pos": b.center(), "n": int(w.get("n", 0)) + 1}
				else:
					w.n = int(w.n) + 1
		if b.type in ["tech_terminal","research_lab"] and float(b.bstate.get("scan_time", 0)) > 0:
			b.bstate["scan_time"] = maxf(0, float(b.bstate.scan_time) - dt)
			var station := renderer(b.type)
			for i in station.parts_with_role("scanner"):
				var xf: Transform3D = station.parts[i].local
				station.set_part_xform(b, i, xf.rotated_local(Vector3.UP, sin(float(b.bstate.scan_time)*1.6)*0.8))
		var em: Array = ModelLib.model(DB.building(b.type).get("model", b.type)).get("emitters", [])
		var damaged_b: bool = b.hp < b.maxhp * 0.5
		if em.is_empty() and not damaged_b:
			continue
		var basis := Basis(Vector3.UP, _dir_angle(b.dir))
		for e in em:
			var when: String = e.get("when", "active")
			if (when == "active" and not b.active) or (when == "damaged" and not damaged_b):
				continue
			if randf() > dt / max(0.05, float(e.get("rate", 0.4))):
				continue
			var lp := ModelLib.v3(e.get("pos", [0, 2, 0]))
			game.fx.puff(game.player.position + World.delta(pp, b.center() + basis * lp), e.get("kind", "puff"), float(e.get("size", 1.0)))
		if damaged_b and randf() < dt / 0.5:
			game.fx.puff(game.player.position + World.delta(pp, b.center() + Vector3(randf_range(-0.6, 0.6), 1.2, randf_range(-0.6, 0.6))), "puff" if randf() < 0.6 else "sparks", 0.8)
	_near_active = near
	work_near = wn


func active_near(_p: Vector3, _r: float) -> float:
	return _near_active


var _repair_acc := 0.0
func _auto_repair(dt: float) -> void:
	_repair_acc += dt
	if _repair_acc < 1.0:
		return
	_repair_acc = 0.0
	# 1.1.14: авторемонт от навыка бесплатный и считается у хозяина по лучшему навыку среди всех игроков
	# (раньше выделенный сервер брал навык своего невидимого героя — 0, и авторемонт не шёл никогда).
	# Развалины (здание уже разрушено) сам не восстанавливает — только игрок ремонтом или новым зданием.
	if Net.is_client():
		return
	var pct := auto_repair_pct(game.team_bonus("repair"))
	if pct <= 0.0:
		return
	for b in damaged.keys():
		if b == null or b.dead or b.hp <= 0.0:
			continue
		repair(b, b.maxhp * pct / 100.0 / 60.0)   # раз в секунду: pct % прочности в минуту


## 1.1.14: сколько % прочности в минуту чинит авторемонт на этом уровне «Инженерии» (1 → 2%, 2 → 3% … 5 → 6%).
static func auto_repair_pct(lvl: float) -> float:
	var n := int(floor(lvl + 0.001))
	if n <= 0:
		return 0.0
	var t = DB.setting("auto_repair114", {}).get("pct_per_min", [10, 20, 30, 40, 50])
	if not t is Array or t.is_empty():
		return 0.0
	if n <= t.size():
		return float(t[n - 1])
	return float(t[t.size() - 1]) + 10.0 * float(n - t.size())



# ---------------------------------------------------------------- провода
## «Провода» — здания соединяются проводами от разъёма к разъёму; «радиус» — старый способ:
## всё рядом с опорой подключено само. Выбирается в редакторе: Правила игры → «Энергосеть».
func wired() -> bool:
	return str(DB.setting("power_mode", "stations")) == "wires"


## Нужна ли зданию энергосеть: даёт, хранит, передаёт или потребляет энергию.
func is_electric(b: B) -> bool:
	return b != null and not b.dead and b.host == null and (b in power_nodes or float(b.p("power", 0)) > 0.0 or not b.subs.is_empty())


## Сколько проводов можно подключить к зданию (поле «Разъёмов для проводов»).
func connectors(b: B) -> int:
	var def := 1
	match b.beh:
		"pole": def = 4
		"hq": def = 8
		"generator", "battery": def = 2
	if (b in power_nodes or bool(DB.setting("wire_machines", true))) and def == 1:
		def = 2   # 14.10: машины можно соединять цепочкой: вход и выход
	return int(b.p("connectors", def))


func wire_count(b: B) -> int:
	var n := 0
	for l in links:
		if l[0] == b or l[1] == b:
			n += 1
	return n


func wired_to(a: B, b: B) -> bool:
	for l in links:
		if (l[0] == a and l[1] == b) or (l[0] == b and l[1] == a):
			return true
	return false


## Самая длинная длина провода в метрах (поле «Длина провода, клеток» в правилах игры).
func wire_len() -> float:
	return float(DB.setting("wire_length", 12)) * C


func wire_dist(a: B, b: B) -> float:
	# от края до края: большим зданиям не нужно тянуть провод до середины
	return maxf(0.0, World.dist(a.center(), b.center()) - (a.size - 1) * C * 0.5 - (b.size - 1) * C * 0.5)


## Почему нельзя протянуть провод ("" — можно).
func wire_why(a: B, b: B) -> String:
	if a == null or b == null or a == b:
		return DB.tx("w_pick", "Выберите второе здание")
	if not is_electric(a) or not is_electric(b):
		return DB.tx("w_noel", "Этому зданию энергия не нужна")
	if wired_to(a, b):
		return DB.tx("w_already", "Уже соединены")
	if wire_dist(a, b) > wire_len():
		return DB.t(DB.tx("w_far", "Слишком далеко (провод до {n} м)"), {"n": int(wire_len())})
	if wire_count(a) >= connectors(a):
		return DB.t(DB.tx("w_full", "У «{b}» заняты все разъёмы ({n})"), {"b": DB.building(a.type).get("name", a.type), "n": connectors(a)})
	if wire_count(b) >= connectors(b):
		return DB.t(DB.tx("w_full", "У «{b}» заняты все разъёмы ({n})"), {"b": DB.building(b.type).get("name", b.type), "n": connectors(b)})
	if not (a in power_nodes) and not (b in power_nodes) and not bool(DB.setting("wire_machines", true)):
		return DB.tx("w_twocons", "Две машины напрямую не соединить — нужна опора, генератор или штаб")
	return ""


## Цена провода: «Провод» за каждые N метров (правила игры). Пустой предмет — бесплатно.
func wire_cost(a: B, b: B) -> Dictionary:
	var it := str(DB.setting("wire_item", ""))
	if it == "" or not DB.data.items.has(it):
		return {}
	var per := maxf(1.0, float(DB.setting("wire_per_m", 10.0)))
	return {it: maxi(1, ceili(wire_dist(a, b) / per))}


func add_wire(a: B, b: B) -> bool:
	if wire_why(a, b) != "":
		return false
	links.append([a, b])
	power_dirty = true
	return true


## Снять все провода здания. Возвращает, сколько снято.
func unwire(b: B) -> int:
	var n := links.size()
	links = links.filter(func(l): return l[0] != b and l[1] != b)
	if n != links.size():
		power_dirty = true
	return n - links.size()


## Сам подключить здание к ближайшей сети (когда его только поставили).
## Опора, генератор и штаб тянут провод к ближайшему узлу сети и подхватывают
## неподключённые машины рядом; машина — к ближайшей опоре с свободным разъёмом.
func auto_wire(b: B) -> void:
	if not is_electric(b):
		return
	var nodes := power_nodes.filter(func(n): return n != b and not n.dead)
	nodes.sort_custom(func(x, y): return wire_dist(b, x) < wire_dist(b, y))
	var is_node: bool = b in power_nodes
	for n in nodes:
		if wire_count(b) >= connectors(b) or (is_node and wire_count(b) >= 1):
			break
		if wire_why(b, n) == "":
			add_wire(b, n)
	if is_node:
		var free := all.filter(func(x): return x != b and not x.dead and not (x in power_nodes) and is_electric(x) and wire_count(x) == 0)
		free.sort_custom(func(x, y): return wire_dist(b, x) < wire_dist(b, y))
		for x in free:
			if wire_count(b) >= connectors(b):
				break
			if wire_dist(b, x) <= float(DB.setting("auto_wire_radius", 8)) * C and wire_why(b, x) == "":
				add_wire(b, x)


## Подключить всё заново (старое сохранение без проводов или смена способа).
func auto_wire_all() -> void:
	links.clear()
	var order := power_nodes.duplicate()
	order.sort_custom(func(x, y): return x == hq or (y != hq and World.dist(x.center(), hq.center() if hq else Vector3.ZERO) < World.dist(y.center(), hq.center() if hq else Vector3.ZERO)))
	for b in order:
		auto_wire(b)
	for b in all:
		if not (b in power_nodes) and is_electric(b) and wire_count(b) == 0:
			auto_wire(b)
	power_dirty = true


func _rebuild_wired() -> void:
	var elec := all.filter(func(x): return is_electric(x))
	var parent := {}
	for b in elec:
		parent[b] = b
	var find := func(x):
		while parent[x] != x:
			parent[x] = parent[parent[x]]
			x = parent[x]
		return x
	links = links.filter(func(l): return parent.has(l[0]) and parent.has(l[1]))
	for l in links:
		var ra = find.call(l[0])
		var rb = find.call(l[1])
		if ra != rb:
			parent[ra] = rb
	var ids := {}
	for b in power_nodes:
		var root = find.call(b)
		if not ids.has(root):
			ids[root] = nets.size()
			nets.append({"supply": 0.0, "demand": 0.0, "sat": 0.0, "stored": 0.0, "cap": 0.0, "tripped": false, "over_t": 0.0, "gen_max": 0.0})
		b.net = ids[root]
		if b.tripped:
			nets[b.net].tripped = true
	consumers.clear()
	for b in elec:
		if b in power_nodes:
			continue
		consumers.append(b)
		b.net = ids.get(find.call(b), -1)
	_draw_wires(links)


## Рубильник: снова включить сеть, в которой стоит здание.
func reset_net(b: B) -> void:
	if b == null or b.net < 0:
		return
	for x in power_nodes:
		if x.net == b.net:
			x.tripped = false
	if b.net < nets.size():
		nets[b.net].tripped = false
		nets[b.net].over_t = 0.0



# ---------------------------------------------------------------- пропускная способность
func _made(b: B, n: int, item := "") -> void:
	if game.progress17 != null:
		game.progress17.on_made(b, item, n)
	for i in n:
		b.made.append(sim_time)
	while not b.made.is_empty() and b.made[0] < sim_time - 60.0:
		b.made.pop_front()


## Сколько предметов в минуту здание делает сейчас (по последней минуте).
func rate_now(b: B) -> float:
	while not b.made.is_empty() and b.made[0] < sim_time - 60.0:
		b.made.pop_front()
	if b.made.is_empty():
		return 0.0
	var span := clampf(sim_time - b.made[0], 10.0, 60.0)
	return b.made.size() * 60.0 / span


## Сколько в минуту здание может делать при полной энергии: машина — по рецепту, бур — по периоду, лента — по скорости.
func rate_max(b: B, rid := "") -> float:
	var mult: float = (1.0 + game.bonus("machine_speed")) * b.mult
	match b.beh:
		"miner":
			return miner_rate(b) * mult
		"belt":
			return 60.0 / b.period
		"crafter":
			if rid == "":
				rid = b.crafting if b.crafting != "" else (b.recipe if b.recipe != "" else b.last_rid)
			var r: Dictionary = DB.data.recipes.get(rid, {})
			if r.is_empty():
				return 0.0
			var outn := 0
			for k in r.get("out", {}):
				outn += int(r.out[k])
			return 60.0 / maxf(0.05, float(r.get("time", 1.0))) * float(b.p("speed", 1.0)) * mult * outn
	return 0.0


## Почему машина не работает в полную силу ("" — всё хорошо).
func bottleneck(b: B) -> String:
	if b.beh == "crafter" or b.beh == "miner":
		# A16-8: составное со своим генератором питается само (недостаток — ниже, по csat)
		if float(b.p("power", 0)) > 0.0 and not (not b.subs.is_empty() and b.has_gen):
			if b.net < 0:
				return DB.tx("bn_nopower", "нет энергии")
			if _sat(b) < 0.999:
				return DB.t(DB.tx("bn_lowpower", "мало энергии ({p}%)"), {"p": int(_sat(b) * 100)})
		if b.out != null and _out_full(b):
			return DB.tx("bn_out", "выход полный — заберите готовое или подведите ленту")
	if b.beh == "generator" and float(b.p("water_per_min", 0.0)) > 0.0 and float(b.bstate.get("water", 0.0)) < 1.0:
		return DB.tx("bn_water", "нет воды — подведите трубу от водяного насоса")
	if not b.subs.is_empty() and b.has_gen and b.csat < 0.999:
		return DB.t(DB.tx("bn_lowpower", "мало энергии ({p}%)"), {"p": int(b.csat * 100)})
	if b.beh == "crafter":
		if b.fuel != null and b.fuel_t <= 0.0 and b.fuel.first_item() == "" and not Fusion.heats_by_power(b):
			return DB.tx("bn_fuel", "нет топлива")
		if b.crafting == "":
			var rid: String = b.recipe
			if rid == "":
				return DB.tx("bn_input", "ждёт сырьё")
			var r: Dictionary = DB.data.recipes.get(rid, {})
			var miss := []
			for k in r.get("in", {}):
				if b.inv.count(k) < int(r["in"][k]):
					miss.append("%s ×%d" % [DB.item_name(k), int(r["in"][k]) - b.inv.count(k)])
			if not miss.is_empty():
				return DB.tx("bn_need", "не хватает: ") + ", ".join(miss)
	return ""


func _out_full(b: B) -> bool:
	if b.beh == "miner":
		return not b.out.can_add(b.recipe, 1) or b.out.count(b.recipe) >= mini(DB.stack_of(b.recipe), 20)
	for sl in b.out.slots:
		if sl == null or int(sl.n) < DB.stack_of(sl.id):
			return false
	return true


# ---------------------------------------------------------------- жидкости и трубы
# Жидкость — предмет с галочкой «Жидкость». Трубы и баки, стоящие рядом, образуют сеть;
# в сети одна жидкость, её запас (сумма ёмкостей труб и баков) и пропускная способность
# (самая медленная труба сети, «единиц в минуту»). Насосы и машины отдают жидкость из выхода
# в сеть, машины и генераторы берут из сети жидкое сырьё и топливо.
# Машина отдаёт жидкость только в трубу у своей передней стороны (там же, куда выходит лента),
# а берёт — с остальных сторон. Насос отдаёт на все стороны.

## Что добывает бур или насос на этой клетке.
func miner_item(type: String, cell: Vector2i) -> String:
	cell = miner_cell(type, cell)
	var wi := str(DB.bparam(type, "water_item", ""))
	if wi != "" and game.world.water_at(cell):
		return wi
	return game.world.deposit_item(cell)


## 21: бур крупнее клетки — добывает с той клетки под собой, где есть залежь (или вода у насоса).
func miner_cell(type: String, cell: Vector2i) -> Vector2i:
	if int(DB.building(type).get("size", 1)) <= 1:
		return cell
	var wi := str(DB.bparam(type, "water_item", ""))
	for c in footprint(type, cell):
		if (wi != "" and game.world.water_at(c)) or (wi == "" and game.world.deposit_item(c) != ""):
			return c
	return cell


## Почему бур или насос сюда не ставится (пусто — можно).
func _miner_why(type: String, cell: Vector2i) -> String:
	cell = miner_cell(type, cell)
	var wi := str(DB.bparam(type, "water_item", ""))
	if wi != "":
		return "" if game.world.water_at(cell) else "Насос ставится на воду — озеро или реку"
	var dep: String = game.world.deposit_item(cell)
	var ext := str(DB.bparam(type, "extracts", "solid"))
	if dep == "":
		return "Насос ставится на пятно жидкости (нефть — чёрные пятна)" if ext == "fluid" else "Бур ставится только на месторождение"
	if dep == "q_superposition":
		return "Жила в суперпозиции: подойдите и посмотрите на неё — она выберет, чем стать"
	if DB.is_fluid(dep) and ext != "fluid":
		return "Здесь %s — нужен насос" % DB.item_name(dep).to_lower()
	if not DB.is_fluid(dep) and ext == "fluid":
		return "Насос ставится на пятно жидкости (например, нефти)"
	var mt: int = game.world.deposit_miner_tier(cell)
	if mt > 1 and int(DB.bparam(type, "tier", 1)) < mt:
		return "%s — нужен бур Mk%d или выше" % [DB.item_name(dep), mt]
	return ""


func _first_solid(inv: Inventory, plain := false) -> String:
	for s in inv.slots:
		if s != null and not DB.is_fluid(s.id) and not (plain and (s.has("dur") or s.has("fresh"))):
			return s.id
	return ""


## A-2 r9: забрать одну штуку из обычной ячейки (не из ячейки с износом/свежестью).
func _take_plain(inv: Inventory, id: String) -> void:
	for i in range(inv.slots.size() - 1, -1, -1):
		var s = inv.slots[i]
		if s != null and s.id == id and not (s.has("dur") or s.has("fresh")):
			s.n -= 1
			if s.n <= 0:
				inv.slots[i] = null
			inv._bump()
			return
	inv.remove(id, 1)


func is_pipe(b: B) -> bool:
	return b.beh == "pipe" or b.beh == "tank"


func pipe_end(b: B) -> bool:
	return not is_pipe(b) and bool(b.p("pipes", false))


func pipe_cap(b: B) -> float:
	return float(b.p("pipe_capacity", 400.0 if b.beh == "tank" else 5.0))


## Соседи здания, которые участвуют в сети труб: [[сосед, сторона от здания к соседу], ...].
func _pipe_neighbors(b: B) -> Array:
	var out := []
	var mine := footprint(b.type, b.cell)
	for c in mine:
		for s in 4:
			var nc := World.wc(c + DIRS[s])
			if nc in mine:
				continue
			var nb = grid.get(nc)
			if nb == null or nb == b or nb.dead or not (is_pipe(nb) or pipe_end(nb)):
				continue
			out.append([nb, s])
	return out


## Машина b касается сети стороной s (от машины наружу): передняя сторона — выход.
func _end_role(e: B, s_from_end: int) -> String:
	if e.beh == "miner":
		return "out"
	if e.beh in ["generator"]:
		return "in"
	return "out" if s_from_end == e.dir else "in"


func _rebuild_fluids() -> void:
	fluid_dirty = false
	for n in fnets:
		_spread(n)
	fnets.clear()
	for b in pipes:
		b.fnet = -1
	for b in pipes:
		if b.dead or b.fnet >= 0:
			continue
		var idx := fnets.size()
		var n := {"fluid": "", "amt": 0.0, "cap": 0.0, "rate": 0.0, "members": [], "ends": {}, "flow": 0.0,
			"moved": 0.0, "t": 0.0, "in_bud": 0.0, "out_bud": 0.0, "rr": 0, "shown": "-", "lost": ""}
		var stack := [b]
		b.fnet = idx
		var slow := INF
		while not stack.is_empty():
			var m: B = stack.pop_back()
			n.members.append(m)
			n.cap += pipe_cap(m)
			if m.beh == "pipe":
				slow = minf(slow, float(m.p("pipe_per_min", 300)) / 60.0)
			for pr in _pipe_neighbors(m):
				var nb: B = pr[0]
				if is_pipe(nb):
					if nb.fnet < 0:
						nb.fnet = idx
						stack.append(nb)
				else:
					var role := _end_role(nb, (pr[1] + 2) % 4)
					var e: Dictionary = n.ends.get(nb, {"b": nb, "in": false, "out": false})
					e[role] = true
					n.ends[nb] = e
		n.rate = slow if slow < INF else 10.0
		# какая жидкость в сети: та, которой больше (при слиянии двух сетей с разными жидкостями меньшая сливается)
		var by := {}
		for m in n.members:
			if m.fluid != "" and m.famt > 0.0:
				by[m.fluid] = by.get(m.fluid, 0.0) + m.famt
		for f in by:
			if n.fluid == "" or by[f] > by[n.fluid]:
				n.fluid = f
		if n.fluid != "":
			n.amt = minf(by[n.fluid], n.cap)
		fnets.append(n)
	_show_fluid_colors(true)


## Разложить запас сети по трубам и бакам (перед перестройкой и сохранением).
func _spread(n: Dictionary) -> void:
	for m in n.members:
		m.fluid = n.fluid if n.amt > 0.0 else ""
		m.famt = n.amt * pipe_cap(m) / maxf(0.001, n.cap) if n.amt > 0.0 else 0.0


func sync_fluids() -> void:
	if fluid_dirty:
		_rebuild_fluids()
	for n in fnets:
		_spread(n)


## Сколько единиц жидкости машина готова взять сейчас.
func wants_fluid(e: B, id: String) -> int:
	if e.dead:
		return 0
	if e.beh == "generator" and e.p("reactor", false):
		return Nuclear.wants_water(e, id)
	if e.beh == "generator" and float(e.p("water_per_min", 0.0)) > 0.0 and id == "water":
		return maxi(0, int(float(e.p("water_per_min", 0.0)) * 0.5 - float(e.bstate.get("water", 0.0))))
	if e.fuel != null and fuel_ok(e, id):
		return maxi(0, DB.stack_of(id) * e.fuel.size() - e.fuel.count(id)) if e.fuel.can_add(id, 1) else 0
	if e.beh == "crafter" and e.inv != null and _is_input(e, id):
		var need := 1
		var ids: Array = [e.recipe] if e.recipe != "" else DB.recipes_for(e.p("station", ""))
		for rid in ids:
			need = maxi(need, int(DB.data.recipes.get(rid, {}).get("in", {}).get(id, 0)))
		var target := mini(DB.stack_of(id), ceili(need * float(DB.setting("pipe_fill_buffer", 2.0))) + need)
		if not e.inv.can_add(id, 1):
			return 0
		return maxi(0, target - e.inv.count(id))
	if e.blk and Blocks.accept(e, id, self):
		return 1
	return 0


func _fluids(dt: float) -> void:
	if fluid_dirty:
		_rebuild_fluids()
	for n in fnets:
		var bin: float = n.rate * dt + n.in_bud
		var bout: float = n.rate * dt + n.out_bud
		# 1) насосы и машины отдают жидкость
		for eb in n.ends:
			var e: Dictionary = n.ends[eb]
			var b: B = e.b
			if b.dead or not e.out or b.out == null:
				continue
			for s in b.out.slots:
				if s == null or not DB.is_fluid(s.id):
					continue
				if n.fluid != "" and n.fluid != s.id and n.amt > 0.0:
					continue
				var k := mini(int(s.n), int(floorf(minf(bin, n.cap - n.amt))))
				if k <= 0:
					continue
				var id: String = s.id
				b.out.remove(id, k)
				n.fluid = id
				n.amt += k
				bin -= k
		# 2) машины, генераторы и т. п. берут
		if n.fluid != "" and n.amt >= 1.0:
			var cons := []
			for eb in n.ends:
				var e: Dictionary = n.ends[eb]
				if e["in"] and wants_fluid(e.b, n.fluid) > 0:
					cons.append(e.b)
			var gave := true
			while gave and bout >= 1.0 and n.amt >= 1.0 and not cons.is_empty():
				gave = false
				for i in cons.size():
					var b: B = cons[(n.rr + i) % cons.size()]
					if bout < 1.0 or n.amt < 1.0:
						break
					if wants_fluid(b, n.fluid) <= 0:
						continue
					if b.beh == "generator" and b.p("reactor", false):
						Nuclear.add_water(b, 1.0)
					elif b.beh == "generator" and float(b.p("water_per_min", 0.0)) > 0.0 and n.fluid == "water":
						b.bstate["water"] = float(b.bstate.get("water", 0.0)) + 1.0
					elif b.fuel != null and fuel_ok(b, n.fluid):
						b.fuel.add(n.fluid, 1)
					elif b.blk and b.beh != "crafter":
						Blocks.accept(b, n.fluid, self)
					else:
						b.inv.add(n.fluid, 1)
					n.amt -= 1.0
					bout -= 1.0
					n.moved += 1.0
					gave = true
				n.rr += 1
		n.in_bud = clampf(bin, 0.0, 1.0)
		n.out_bud = clampf(bout, 0.0, 1.0)
		n.t += dt
		if n.t >= 2.0:
			n.flow = n.moved / n.t * 60.0
			n.moved = 0.0
			n.t = 0.0
		if n.amt < 0.001:
			n.amt = 0.0
			n.fluid = ""
	_show_fluid_colors(false)


## Цветная полоска на узлах труб и баках — цвет жидкости в сети.
func _show_fluid_colors(force: bool) -> void:
	for n in fnets:
		if not force and n.shown == n.fluid:
			continue
		n.shown = n.fluid
		var col := DB.item_color(n.fluid) if n.fluid != "" else Color(0.16, 0.17, 0.19)
		for m in n.members:
			if m.dead:
				continue
			var r := renderer(m.type)
			for i in r.parts.size():
				if r.parts[i].role == "fluid_color":
					r.set_part_color(m, i, col)


## Сведения о сети для окна и подсказки.
func fluid_info(b: B) -> Dictionary:
	if fluid_dirty:
		_rebuild_fluids()
	var ns := []
	for n in fnets:
		if b in n.members or n.ends.has(b):
			ns.append(n)
	if ns.is_empty():
		return {}
	var n: Dictionary = ns[0]
	return {"fluid": n.fluid, "amt": n.amt, "cap": n.cap, "rate": n.rate * 60.0, "flow": n.flow, "pipes": n.members.size(),
		"ends": n.ends.size(), "nets": ns.size(), "here": n.amt * pipe_cap(b) / maxf(0.001, n.cap) if is_pipe(b) else 0.0}


## Слить жидкость из сети (кнопка в окне трубы): сеть пустеет и готова к другой жидкости.
func drain(b: B) -> void:
	if fluid_dirty:
		_rebuild_fluids()
	for n in fnets:
		if b in n.members:
			n.amt = 0.0
			n.fluid = ""
	_show_fluid_colors(false)


# --- отрезки труб: от узла до соседней трубы или до стены машины

func _arm_r(model: String) -> PartRenderer:
	if arm_rs.has(model):
		return arm_rs[model]
	var r := PartRenderer.new()
	r.chunk = render_chunk()
	for pt in ModelLib.parts_of(model, true):
		r.add_part(pt[0], pt[1], pt[2], pt[3], true, pt[4], pt[5])
	add_child(r)
	arm_rs[model] = r
	return r


func _clear_arms(b: B) -> void:
	for key in arm_keys.get(b, []):
		for m in arm_rs:
			arm_rs[m].remove(key)
	arm_keys.erase(b)


func _arms_around(b: B) -> void:
	if b.beh == "pipe":
		_update_arms(b)
	for pr in _pipe_neighbors(b):
		if pr[0].beh == "pipe":
			_update_arms(pr[0])


func _update_arms(b: B) -> void:
	_clear_arms(b)
	if b.dead or b.beh != "pipe":
		return
	var model := str(b.p("arm_model", "pipe_arm"))
	if not DB.data.models.has(model):
		return
	var r := _arm_r(model)
	var keys := []
	var cb := b.center()
	for pr in _pipe_neighbors(b):
		var nb: B = pr[0]
		var s: int = pr[1]
		var length := C * 0.5
		if nb.beh != "pipe":
			# до стены машины или бака
			var nc: Vector3 = cb + World.delta(cb, nb.center())
			var box: AABB = Transform3D(_xform(nb).basis, nc) * _face_box(nb.type)
			var fd := 0.0
			match s:
				0: fd = box.position.x - cb.x
				1: fd = box.position.z - cb.z
				2: fd = cb.x - box.end.x
				_: fd = cb.z - box.end.z
			length = clampf(fd + 0.05, C * 0.5, C * 1.5)
		var key := [b, s]
		r.add(key, Transform3D(Basis(Vector3.UP, _dir_angle(s)), cb))
		for i in r.parts.size():
			if r.parts[i].role == "stretch":
				r.set_part_xform(key, i, Transform3D(Basis.from_scale(Vector3(length, 1, 1)), Vector3.ZERO) * r.parts[i].local)
		keys.append(key)
	if not keys.is_empty():
		arm_keys[b] = keys


const Quantum = preload("res://scripts/quantum21.gd")


## 21: крыши. Герой залезает прыжком на невысокие здания и ходит по ним — так ряд печей не надо обходить.
var _roof_cache: Dictionary = {}
const CLIMB := ["crafter", "storage", "generator", "miner", "splitter", "merger", "junction", "tank", "battery", "terminal", "station"]


func roof_h(type: String) -> float:
	if _roof_cache.has(type):
		return _roof_cache[type]
	var h := float(DB.bparam(type, "roof", -1.0))
	if h < 0.0:
		h = 0.0
		var r := renderer(type)
		for pt in r.parts:
			var mm: MultiMesh = pt.mm
			if mm.mesh == null:
				continue
			var bx: AABB = (pt.local as Transform3D) * mm.mesh.get_aabb()
			h = maxf(h, bx.end.y)
		if h <= 0.0:
			h = 2.0
	_roof_cache[type] = h
	return h


## Верх крыши здания (мировая высота) или -1, если на него не залезть.
func roof_top(b: B) -> float:
	if b == null or b.dead or walkable(b) or not b.beh in CLIMB or b.p("no_climb", false):
		return -1.0
	if not bool(DB.setting("climb_roofs", true)):
		return -1.0
	var k: float = fz.scale_of(b) if (b.lvl > 1 or not b.subs.is_empty()) else 1.0
	var h: float = roof_h(b.type) * k + (0.14 if not b.subs.is_empty() else 0.0)
	if h > float(DB.setting("climb_roof_max", 4.0)):
		return -1.0
	return b.y + h



## 1.3: верх невысокого здания, через которое можно перепрыгнуть (костёр, фонарь, турель, декор, трубы) или −1.
## Стены, заборы-стены, штаб, машины и всё выше «Высоты перепрыгивания» — нет.
func hop_top(b: B) -> float:
	if b == null or b.beh in ["wall", "hq", "vehicle"] or b.p("no_climb", false):
		return -1.0
	var k: float = fz.scale_of(b) if (b.lvl > 1 or not b.subs.is_empty()) else 1.0
	var h: float = roof_h(b.type) * k
	if h > float(DB.setting("hop_max", 2.0)):
		return -1.0
	return b.y + h


## 21: здания, у которых есть параметр key (например ufo_pad) — без перебора всех лент карты каждый кадр.
func having(key: String) -> Array:
	var h = _having.get(key)
	if h != null and h[0] == rev:
		return h[1]
	var out := []
	for b in all:
		if b.p(key, null):
			out.append(b)
	_having[key] = [rev, out]
	return out



## 21: размер участка отрисовки завода, м («Настройки → Участок отрисовки»; 0 — весь завод одним куском).
static func render_chunk() -> float:
	return float(DB.setting("render_chunk", 64.0))
