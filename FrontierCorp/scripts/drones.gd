class_name Drones
extends RefCounted
## 14.21: станции дронов. У станции «Объединение N» живёт столько дронов, сколько указано в настройке
## «Дронов по уровням» (1, 2, 4, 8, 15). Каждый дрон летает по маршрутам станции: «из здания А забрать
## (что-то или всё) → отвезти в здание Б». У дрона батарея на N метров полёта: перед вылетом он проверяет,
## хватит ли заряда туда и обратно, иначе ждёт на станции (заряд — от энергии станции). Монстры рядом
## (стрелки и летуны — в полёте, все — на посадке) сбивают дрона; груз падает на землю, станция собирает
## нового за ресурсы из штаба. Настройки: «Данные» → «Настройки» → «Дроны»; у здания — параметр «Станция дронов».

var game
var f                              # Factory
var st: Dictionary = {}            # станция (B) → {"d": [дроны], "rr": номер маршрута по кругу, "err": {}}
var _scan_t := 0.0
var _threat_t := 0.0
var _shot_note_t := 0.0
var pick_cb = null                 # выбор здания кликом на карте (Callable(b)), null — не выбираем
var pick_text := ""
var _lines: MeshInstance3D
var _line_for = null
var _labels: Array = []
var stats_picked := 0               # 21: сколько предметов дроны подобрали с земли


static func cfg() -> Dictionary:
	var c = DB.setting("drones", {})
	return c if c is Dictionary else {}


static func c(key: String, def):
	return cfg().get(key, def)


static func is_station(b) -> bool:
	return b != null and bool(b.p("drone_station", false))


func _init(g) -> void:
	game = g
	f = g.factory


## Сколько дронов у станции этого уровня.
static func count_for(b) -> int:
	var pl = c("per_level", [1, 2, 4, 8, 15])
	var n: int = b.lvl
	if pl is Array and not pl.is_empty():
		n = int(pl[clampi(b.lvl - 1, 0, pl.size() - 1)])
	return maxi(0, n * maxi(1, int(b.p("drones_k", 1))))


static func battery() -> float:
	return float(c("battery_m", 400.0))


# ---------------------------------------------------------------- станции

func stations() -> Array:
	return st.keys()


func _collect() -> Array:
	var out := []
	for b in f.all:
		if not b.dead and is_station(b):
			out.append(b)
	for h in f.fz.hosts:
		if h.dead:
			continue
		for s in h.subs:
			if is_station(s):
				out.append(s)
	return out


## Найти станции и привести число дронов к уровню.
func sync() -> void:
	f = game.factory
	var live := _collect()
	for b in st.keys():
		if not b in live or b.dead:
			_drop_station(b)
	for b in live:
		if not st.has(b):
			st[b] = {"d": [], "rr": 0, "err": {}, "gap": 0.0}
		var list: Array = st[b].d
		var want := count_for(b)
		while list.size() < want:
			list.append(_new_drone(b, list.size()))
		for i in range(list.size() - 1, -1, -1):
			if i >= want:
				var d: Dictionary = list[i]
				if d.state in ["dock", "dead"]:
					_free(d)
					list.remove_at(i)
				else:
					d.retire = true


func _drop_station(b) -> void:
	for d in st[b].d:
		if d.state != "dead" and d.n > 0:
			_drop_cargo(d, Vector3(d.pos.x, game.world.height_at(d.pos) + 0.5, d.pos.z))
		_unclaim(d)
		_free(d)
	st.erase(b)


func _new_drone(b, i: int) -> Dictionary:
	var d := {"st": b, "i": i, "pos": pad(b, i), "state": "dock", "bat": battery(), "hp": float(c("hp", 60.0)),
		"item": "", "n": 0, "src": null, "dst": null, "route": -1, "t": 0.0, "dead_t": 0.0, "retire": false,
		"node": null, "box": null, "yaw": 0.0, "hit_t": 0.0}
	_make_node(d)
	return d


func _make_node(d: Dictionary) -> void:
	var m := str(c("model", "drone_carrier"))
	var node: Node3D = ModelLib.make_node(m if not DB.model_def(m).is_empty() else "drone_carrier")
	node.scale = Vector3.ONE * float(c("scale", 0.8))
	game.add_child(node)
	node.position = d.pos
	d.node = node
	var box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.45, 0.35, 0.45)
	box.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.6, 0.3)
	box.material_override = mat
	box.position = Vector3(0, -0.45, 0)
	box.visible = false
	node.add_child(box)
	d.box = box


func _free(d: Dictionary) -> void:
	if d.node != null and is_instance_valid(d.node):
		d.node.queue_free()
	d.node = null


## Площадка дрона i: над станцией (по кругу, если дронов много).
func pad(b, i: int) -> Vector3:
	var base: Vector3
	if b.host != null:
		var idx: int = b.host.subs.find(b)
		base = f.fz.sub_xform(b.host, idx).origin if idx >= 0 else b.host.center()
		base.y += 0.9
	else:
		base = b.center() + Vector3(0, 1.1, 0)
	if i == 0:
		return base
	var ring := 1 + (i - 1) / 6
	var a := float((i - 1) % 6) / 6.0 * TAU + ring * 0.5
	return base + Vector3(cos(a) * 0.9 * ring, 0.25 * ring, sin(a) * 0.9 * ring)


func home(b) -> Vector3:
	return b.host.center() if b.host != null else b.center()


# ---------------------------------------------------------------- маршруты

## Маршруты станции: [{from: [x, z], to: [x, z], item: "" (любое), keep: оставлять в А, on: true}].
static func routes(b) -> Array:
	var r = b.cfg.get("routes", [])
	return r if r is Array else []


func set_routes(b, r: Array) -> void:
	var cf: Dictionary = b.cfg.duplicate(true)
	cf["routes"] = r
	b.cfg = cf
	if st.has(b):
		st[b].err = {}


func bld_at(cell) -> Factory.B:
	if not cell is Array or cell.size() < 2:
		return null
	return f.building_at(Vector2i(int(cell[0]), int(cell[1])))


## Откуда дрон берёт: у складов и штаба — содержимое; у машин — готовое; у составных — встроенный ящик, потом выход.
func src_invs(o) -> Array:
	var out := []
	if o.beh in ["storage", "hq"]:
		if o.inv != null:
			out.append(o.inv)
		return out
	for ch in o.subs:   # 1.1.20 A15-1: все встроенные ящики, а не только первый
		if ch.beh == "storage" and ch.inv != null:
			out.append(ch.inv)
	if o.out != null:
		out.append(o.out)
	for s in o.subs:
		if s.beh == "crafter" and s.out != null:
			out.append(s.out)
	return out


func _count(o, id: String) -> int:
	var n := 0
	for inv in src_invs(o):
		n += inv.count(id)
	return n


func _take(o, id: String, n: int, d = null) -> int:
	var got := 0
	if d is Dictionary:
		d["sl"] = []
	for inv in src_invs(o):
		# A-12 r5: инструмент с износом / еда со свежестью — слотом целиком, чтобы не «чинились»
		for i in inv.slots.size():
			var sl = inv.slots[i]
			if got >= n or sl == null or str(sl.get("id", "")) != id or not (sl.has("dur") or sl.has("fresh")):
				continue
			var k0: int = mini(n - got, int(sl.n))
			var part: Dictionary = (sl as Dictionary).duplicate()
			part["n"] = k0
			if d != null:
				if not d.has("sl"):
					d["sl"] = []
				d.sl.append(part)
			if k0 >= int(sl.n):
				inv.slots[i] = null
			else:
				sl["n"] = int(sl.n) - k0
			inv._bump()
			got += k0
		var k: int = mini(n - got, inv.count(id))
		if k > 0:
			inv.remove(id, k)
			got += k
		if got >= n:
			break
	return got


## Примет ли здание этот предмет (без изменений).
func can_take(o, id: String) -> bool:
	if o == null or o.dead:
		return false
	match o.beh:
		"storage", "hq":
			return o.inv != null and o.inv.can_add(id, 1)
		"crafter":
			if f._is_input(o, id) and o.inv.count(id) < f.in_cap(o, id) and o.inv.can_add(id, 1):
				return true
			if o.fuel != null and f.fuel_ok(o, id) and o.fuel.can_add(id, 1):
				return true
		"generator":
			if o.fuel != null and f.fuel_ok(o, id) and o.fuel.can_add(id, 1):
				return true
		"turret":
			if str(o.p("ammo", "")) == id:
				if o.inv != null:
					return o.inv.can_add(id, 1)   # 1.1.15: свой магазин турели
				return f.hq != null and f.hq.inv.can_add(id, 1)
	for s in o.subs:
		if s.beh == "turret" and s.inv != null and str(s.p("ammo", "")) == id and s.inv.can_add(id, 1):
			return true
		if s.beh == "crafter" and f._is_input(s, id) and s.inv.count(id) < f.in_cap(s, id) and s.inv.can_add(id, 1):
			return true
		if s.fuel != null and s.beh in ["crafter", "generator"] and f.fuel_ok(s, id) and s.fuel.can_add(id, 1):
			return true
		if s.beh == "storage" and s.inv.can_add(id, 1):
			return true
	return false


## Отдать груз: как лента (машине, печи, складу), остаток — во встроенный ящик. Возвращает, сколько осталось.
func deliver(o, id: String, n: int, d = null) -> int:
	var left := n
	var sls: Array = d.get("sl", []) if d is Dictionary else []
	if not sls.is_empty():
		var tinvs := [o.inv] if o.beh in ["storage", "hq"] and o.inv != null else []
		if tinvs.is_empty():
			for ch in o.subs:   # 1.1.20 A15-1: по очереди во все встроенные ящики
				if ch.beh == "storage" and ch.inv != null:
					tinvs.append(ch.inv)
		for tinv in tinvs:
			for sl in sls.duplicate():
				var l2: int = tinv.add_slot(sl)
				left -= int(sl.n) - l2
				if l2 <= 0:
					sls.erase(sl)
				else:
					sl["n"] = l2
		if not tinvs.is_empty():
			d["sl"] = sls
			if left <= 0:
				return 0
	while left > 0 and f.accept(o, id, null):
		left -= 1
	if left > 0 and not o.subs.is_empty():
		left = Fusion.chest_add(o, id, left)
	if d is Dictionary and d.has("sl"):
		# обычными предметами ушло больше, чем было без особых слотов — лишние особые слоты израсходованы
		var keep := left
		var out := []
		for sl in d.sl:
			if keep <= 0:
				break
			var k := mini(keep, int(sl.n))
			var c2: Dictionary = (sl as Dictionary).duplicate()
			c2["n"] = k
			out.append(c2)
			keep -= k
		d["sl"] = out
	return left


## Что везти по маршруту r: [здание А, здание Б, предмет, сколько] или пусто.
func _job(b, r: Dictionary) -> Array:
	if not bool(r.get("on", true)):
		return []
	var a = bld_at(r.get("from"))
	var z = bld_at(r.get("to"))
	if a == null or z == null or a == z or a.dead or z.dead:
		return ["err", "здание пропало"]
	var range_m: float = float(c("range", 150.0))
	var hp: Vector3 = home(b)
	if World.dist(hp, a.center()) > range_m or World.dist(hp, z.center()) > range_m:
		return ["err", "дальше %d м от станции" % int(range_m)]
	var want := str(r.get("item", ""))
	var keep := int(r.get("keep", 0))
	var cand := []
	if want != "":
		cand = [want]
	else:
		for inv in src_invs(a):
			for sl in inv.slots:
				if sl != null and not sl.id in cand:
					cand.append(sl.id)
	for id in cand:
		var have: int = _count(a, id) - keep
		if have > 0 and can_take(z, id):
			return [a, z, id, mini(have, capacity(b))]
	return []


func capacity(b) -> int:
	return maxi(1, int(float(c("capacity", 10)) * (1.0 + float(c("capacity_per_level", 0.0)) * (b.lvl - 1))))


# ---------------------------------------------------------------- такт

func update(dt: float) -> void:
	if dt <= 0.0:
		return
	if f == null:
		f = game.factory
	_scan_t -= dt
	if _scan_t <= 0.0:
		_scan_t = 0.5
		sync()
	_threat_t -= dt
	var threat := _threat_t <= 0.0
	if threat:
		_threat_t = 0.25
	_shot_note_t -= dt
	for b in st.keys():
		if b.dead:
			continue
		st[b].gap = maxf(0.0, float(st[b].get("gap", 0.0)) - dt)
		var sat: float = clampf(f.sat_c(b), 0.0, 1.0) if float(b.p("power", 0)) > 0.0 else 1.0
		var charging := false
		for d in st[b].d:
			_step(b, d, dt, sat)
			if d.state == "dock" and d.bat < battery() - 0.01:
				charging = true
			if threat and d.state != "dead":
				_threats(d, 0.25)
		b.want = charging
		b.active = charging or st[b].d.any(func(x): return not x.state in ["dock", "dead"])
	_update_lines()


func _step(b, d: Dictionary, dt: float, sat: float) -> void:
	var speed: float = float(c("speed", 12.0)) * (1.0 + float(c("speed_per_level", 0.0)) * (b.lvl - 1))
	match d.state:
		"dead":
			d.dead_t -= dt
			if d.dead_t <= 0.0 and not d.retire:
				if _pay_rebuild():
					d.state = "dock"
					d.hp = float(c("hp", 60.0))
					d.bat = battery() * 0.5
					d.pos = pad(b, d.i)
					if d.node == null:
						_make_node(d)
					d.node.visible = true
					game.fx.magic(d.pos, Color(0.5, 0.8, 1.0), 0.6)
				else:
					d.dead_t = 2.0
		"dock":
			d.pos = pad(b, d.i)
			d.bat = minf(battery(), d.bat + float(c("charge_rate", 25.0)) * sat * dt)
			d.hp = minf(float(c("hp", 60.0)), d.hp + float(c("repair", 2.0)) * dt)
			if d.retire:
				return
			d.t -= dt
			if d.t > 0.0:
				return
			d.t = 0.5
			if float(st[b].get("gap", 0.0)) <= 0.0:
				_dispatch(b, d)
		"go_src":
			if _fly(d, _above(d.src), speed, dt):
				_at_src(b, d)
		"go_pick":
			var dr = d.get("pick")
			if dr == null or not dr in game.drops.list:
				_claimed.erase(dr)
				d.state = "home"
			elif _fly(d, dr.pos + Vector3(0, 1.2, 0), speed, dt):
				d.item = dr.id
				d.n = dr.n
				game.drops.take(dr)
				_claimed.erase(dr)
				d.erase("pick")
				d.state = "go_dst" if d.dst != null and not d.dst.dead else "home"
				stats_picked += d.n
		"go_dst":
			if _fly(d, _above(d.dst), speed, dt):
				d.state = "drop"
				d.t = float(c("retry_s", 4.0))
		"drop":
			if d.dst == null or d.dst.dead:
				d.state = "home"
				return
			d.n = deliver(d.dst, d.item, d.n, d)
			if d.n <= 0:
				d.item = ""
				d.n = 0
				d.state = "home"
			else:
				d.t -= dt
				if d.t <= 0.0:
					d.state = "home"     # не влезло — домой с остатком, отвезёт в следующий раз
		"home":
			if _fly(d, pad(b, d.i), speed, dt):
				d.state = "dock"
				d.t = 0.3
				if d.retire:
					d.n = deliver(f.hq, d.item, d.n, d) if d.n > 0 and f.hq != null else 0
	_visual(d, dt)


## Выбрать работу: сначала довезти остаток, потом маршруты по кругу.
func _dispatch(b, d: Dictionary) -> void:
	var rs := routes(b)
	var info: Dictionary = st[b]
	var reserve: float = 1.0 + float(c("reserve", 0.15))
	var hp: Vector3 = pad(b, d.i)
	if rs.is_empty():
		if d.n <= 0:
			_try_pickup(b, d, hp, reserve)
		elif f.hq != null:
			d.n = deliver(f.hq, d.item, d.n, d)
		return
	if d.n > 0:
		var r0: Dictionary = rs[clampi(d.route, 0, rs.size() - 1)] if d.route >= 0 else {}
		var z0 = bld_at(r0.get("to")) if not r0.is_empty() else null
		if z0 != null and can_take(z0, d.item):
			var need0: float = World.dist(hp, z0.center()) * 2.0 * reserve
			if d.bat >= need0:
				d.dst = z0
				d.state = "go_dst"
		elif f.hq != null:
			d.n = deliver(f.hq, d.item, d.n, d)   # маршрут убрали — остаток в штаб
			if d.n <= 0:
				d.item = ""
		return
	for k in rs.size():
		var ri: int = (int(info.rr) + k) % rs.size()
		var j: Array = _job(b, rs[ri])
		if j.is_empty():
			info.err.erase(ri)
			continue
		if j[0] is String:
			info.err[ri] = j[1]
			continue
		var need: float = (World.dist(hp, j[0].center()) + World.dist(j[0].center(), j[1].center()) + World.dist(j[1].center(), hp)) * reserve
		if need > battery():
			info.err[ri] = "не хватит батареи (%d м из %d)" % [int(need), int(battery())]
			continue
		info.err.erase(ri)
		if d.bat < need:
			return   # ждёт зарядки
		# не посылать второго дрона за тем, что уже везут (если груза мало)
		var busy := 0
		for o in info.d:
			if o != d and o.state == "go_src" and o.src == j[0] and o.route == ri:
				busy += capacity(b)
		if busy > 0 and _count(j[0], j[2]) - int(rs[ri].get("keep", 0)) <= busy:
			continue
		d.src = j[0]
		d.dst = j[1]
		d.item = j[2]
		d.route = ri
		d.state = "go_src"
		info.gap = float(c("launch_gap", 1.0))   # взлетают по очереди, а не стаей
		info.rr = (ri + 1) % rs.size()
		return
	_try_pickup(b, d, hp, reserve)


## 21: свободный дрон подбирает предметы, слетевшие с лент рядом со станцией, и везёт на ближайший склад.
var _claimed := {}


func _try_pickup(b, d: Dictionary, hp: Vector3, reserve: float) -> void:
	if not bool(c("pickup", true)) or game.drops == null:
		return
	var rad := float(c("pickup_radius", 30.0))
	var best = null
	var bd := rad
	for dr in game.drops.list:
		if not dr.landed or dr.magnet or _claimed.has(dr):
			continue
		var dd: float = World.dist(hp, dr.pos)
		if dd < bd:
			bd = dd
			best = dr
	if best == null:
		return
	var dst = _store_near(best.pos, best.id)
	if dst == null:
		return
	var need: float = (bd + World.dist(best.pos, dst.center()) + World.dist(dst.center(), hp)) * reserve
	if d.bat < need:
		return
	_claimed[best] = d
	d["pick"] = best
	d.dst = dst
	d.state = "go_pick"


func _store_near(p: Vector3, id: String):
	var best = f.hq
	var bd: float = World.dist(p, f.hq.center()) if f.hq != null else INF
	for o in f.having("slots"):
		if o.dead or o.beh != "storage" or o.inv == null or not o.inv.can_add(id, 1):
			continue
		if (o.type in Fusion.SPECIAL and o.type != "outpost") or o.type == "black_market":
			continue   # A16-3: НЛО, рынки, дезактивация, отходы — не склад для подобранного
		var dd: float = World.dist(p, o.center())
		if dd < bd:
			bd = dd
			best = o
	return best


func _at_src(b, d: Dictionary) -> void:
	var rs := routes(b)
	if d.src == null or d.src.dead or d.route < 0 or d.route >= rs.size():
		d.item = ""
		d.state = "home"
		return
	var keep := int(rs[d.route].get("keep", 0))
	var n: int = mini(capacity(b), _count(d.src, d.item) - keep)
	if n <= 0 or d.dst == null or d.dst.dead:
		d.item = ""
		d.state = "home"
		return
	d.n = _take(d.src, d.item, n, d)
	d.state = "go_dst" if d.n > 0 else "home"


func _above(o) -> Vector3:
	if o == null or o.dead:
		return Vector3.ZERO
	return o.center() + Vector3(0, float(o.size) * 0.6 + 1.6, 0)


## Полёт к точке: взлёт на высоту, полёт, посадка. true — прилетел. Тратит батарею по пройденному пути.
func _fly(d: Dictionary, to: Vector3, speed: float, dt: float) -> bool:
	if to == Vector3.ZERO and d.state != "home":
		d.state = "home"
		return false
	var p: Vector3 = d.pos
	var dl: Vector3 = World.delta(p, to)
	var flat := Vector2(dl.x, dl.z)
	var dist := flat.length()
	var cruise: float = float(c("cruise_h", 7.0))
	var gy: float = game.world.height_at(p)
	var want_y: float = maxf(to.y, gy + cruise) if dist > 4.0 else to.y
	var k := speed
	if d.bat <= 0.0:
		k *= 0.3          # разрядился — тянет домой на последних силах
	var step: float = minf(dist, k * dt)
	if dist > 0.001:
		var dir := flat / dist
		p.x += dir.x * step
		p.z += dir.y * step
		d.yaw = atan2(-dir.y, dir.x)
	p.y = move_toward(p.y, want_y, maxf(3.0, k * 0.6) * dt)
	d.bat = maxf(0.0, d.bat - step)
	d.pos = World.wrap_pos(p)
	# батарея на исходе: бросить работу и домой
	if d.state in ["go_src", "go_dst"] and d.bat < World.dist(d.pos, pad(d.st, d.i)) * 1.02 + 2.0:
		d.state = "home"
		game.notify("Дрон: батарея садится — возвращается на станцию", Color(1, 0.8, 0.4))
		return false
	return dist < 0.3 and absf(p.y - to.y) < 0.4


## Монстры рядом бьют дрона: в полёте — только стрелки и летуны, у земли — все.
func _threats(d: Dictionary, dt: float) -> void:
	if game.enemies == null:
		return
	var r: float = float(c("threat_r", 7.0))
	var low: bool = d.pos.y - game.world.height_at(d.pos) < float(c("low_h", 3.0))
	var dmg := 0.0
	var shooter = null
	for e in game.enemies.list:
		if not e.alive or e.npc != "" or e.peaceful:
			continue
		var ep: Vector3 = game.enemies.pos_of(e)
		var dd: Vector3 = World.delta(d.pos, ep)
		if Vector2(dd.x, dd.z).length() > r:
			continue
		if not (low or e.ranged or e.fly):
			continue
		dmg += e.dmg / maxf(0.3, e.rate) * float(c("dmg_k", 1.0)) * dt
		shooter = e
	if dmg <= 0.0:
		return
	d.hp -= dmg
	d.hit_t = 0.3
	if shooter != null and randf() < 0.5:
		game.fx.tracer(game.enemies.pos_of(shooter) + Vector3(0, 1.0, 0), d.pos, Color(1.0, 0.35, 0.2))
	if d.hp <= 0.0:
		_kill(d)


func _unclaim(d: Dictionary) -> void:
	if d.has("pick"):
		if _claimed.get(d.pick) == d:
			_claimed.erase(d.pick)
		d.erase("pick")


## A-7 r10: груз падает с износом и свежестью (особые ячейки — целиком, остальное — обычными предметами).
func _drop_cargo(d: Dictionary, at: Vector3) -> void:
	var left := int(d.n)
	for sl in (d.get("sl", []) if d.get("sl") is Array else []):
		if left <= 0:
			break
		var c: Dictionary = (sl as Dictionary).duplicate()
		c["n"] = mini(int(c.n), left)
		left -= int(c.n)
		game.drops.spawn_slot(c, at)
	if left > 0:
		game.drops.spawn(d.item, left, at)
	d.erase("sl")


func _kill(d: Dictionary) -> void:
	_unclaim(d)
	game.fx.explosion(d.pos, 0.6, Color(1.0, 0.6, 0.2))
	game.sfx.play("boom", d.pos)
	if d.n > 0:
		var gp: Vector3 = Vector3(d.pos.x, game.world.height_at(d.pos) + 0.5, d.pos.z)
		_drop_cargo(d, gp)
	d.item = ""
	d.n = 0
	d.state = "dead"
	d.dead_t = float(c("rebuild_s", 30.0))
	d.src = null
	d.dst = null
	if d.node != null:
		d.node.visible = false
	if _shot_note_t <= 0.0:
		_shot_note_t = 5.0
		game.notify("Монстры сбили дрона! Груз упал на землю. Станция соберёт нового.", Color(1, 0.45, 0.35))


func _pay_rebuild() -> bool:
	var cost = c("rebuild_cost", {})
	if not cost is Dictionary or cost.is_empty() or game.flags.get("free_build", false):
		return true
	if f.hq == null:
		return false
	for k in cost:
		if f.hq.inv.count(k) < int(cost[k]):
			return false
	for k in cost:
		f.hq.inv.remove(k, int(cost[k]))
	return true


func _visual(d: Dictionary, dt: float) -> void:
	var node: Node3D = d.node
	if node == null or not is_instance_valid(node):
		return
	var t := Time.get_ticks_msec() * 0.001
	var bob := 0.0 if d.state == "dock" else sin(t * 3.0 + d.i) * 0.08
	node.position = d.pos + Vector3(0, bob, 0)
	node.rotation.y = d.yaw
	if d.box != null:
		d.box.visible = d.n > 0
	if d.hit_t > 0.0:
		d.hit_t -= dt
		node.rotation.z = sin(t * 40.0) * 0.15
	else:
		node.rotation.z = 0.0


# ---------------------------------------------------------------- текст для окна

static func state_text(d: Dictionary) -> String:
	match d.state:
		"dock":
			if d.retire:
				return "лишний (уровень станции меньше) — на стоянке"
			if d.bat < battery() - 0.5:
				return "заряжается %d%%" % int(d.bat / battery() * 100)
			return "ждёт работу" if d.n == 0 else "ждёт, пока примут груз"
		"go_src":
			return "летит за грузом: %s" % DB.item_name(d.item)
		"go_dst", "drop":
			return "везёт %d × %s" % [d.n, DB.item_name(d.item)]
		"home":
			return "возвращается на станцию"
		"dead":
			return "сбит — новый через %d с" % int(ceilf(d.dead_t)) if d.dead_t > 0.0 else "сбит — нужны ресурсы в штабе на нового"
	return d.state


func drones_of(b) -> Array:
	return st[b].d if st.has(b) else []


func route_err(b, i: int) -> String:
	return str(st[b].err.get(i, "")) if st.has(b) else ""


# ---------------------------------------------------------------- выбор здания кликом

func start_pick(text: String, cb: Callable) -> void:
	pick_cb = cb
	pick_text = text
	game.notify(text + " (ПКМ — отмена)", Color(0.6, 0.9, 1.0))


func picking() -> bool:
	return pick_cb != null


func cancel_pick() -> void:
	if pick_cb != null:
		pick_cb = null
		game.notify("Выбор отменён", UI.DIM)


## Клик по карте в режиме выбора: ближайшее здание у курсора (можно мимо на пару метров).
func pick_click() -> void:
	var b = _pick_target()
	if b == null:
		game.notify("Здесь нет здания — кликните по зданию", Color(1, 0.7, 0.5))
		return
	var cb: Callable = pick_cb
	pick_cb = null
	cb.call(b)


func _pick_target():
	var b = f.building_at(game.hover_cell)
	if b != null and not b.beh in ["belt", "splitter", "merger", "pipe", "wall", "floor", "foundation"]:
		return b
	var best = null
	var bd := 2.5
	for o in f.all:
		if o.dead or o.beh in ["belt", "splitter", "merger", "pipe", "wall", "floor", "foundation", "pole"]:
			continue
		var dd := World.delta(game.hover_point, o.center())
		var dist: float = Vector2(dd.x, dd.z).length() - o.size * World.C * 0.5
		if dist < bd:
			bd = dist
			best = o
	return best


# ---------------------------------------------------------------- линии маршрутов (пока открыто окно станции)

func _update_lines() -> void:
	var b = null
	if game.hud != null and game.hud.is_open("building") and is_station(game.hud.bld):
		b = game.hud.bld
	if b == _line_for and (b == null or Engine.get_process_frames() % 15 != 0):
		return
	_line_for = b
	if _lines == null:
		_lines = MeshInstance3D.new()
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		m.no_depth_test = true
		_lines.material_override = m
		game.add_child(_lines)
	for l in _labels:
		if is_instance_valid(l):
			l.queue_free()
	_labels.clear()
	var im := ImmediateMesh.new()
	_lines.mesh = im
	if b == null:
		return
	var hp: Vector3 = home(b) + Vector3(0, 2.0, 0)
	var any := false
	var rs := routes(b)
	for i in rs.size():
		var a = bld_at(rs[i].get("from"))
		var z = bld_at(rs[i].get("to"))
		if a == null or z == null:
			continue
		if not any:
			im.surface_begin(Mesh.PRIMITIVE_LINES)
			any = true
		var pa: Vector3 = a.center() + Vector3(0, 2.0, 0)
		var pz: Vector3 = z.center() + Vector3(0, 2.0, 0)
		pa = hp + World.delta(hp, pa)
		pz = hp + World.delta(hp, pz)
		for seg in [[hp, pa, Color(0.5, 0.8, 1.0, 0.6)], [pa, pz, Color(1.0, 0.8, 0.3)], [pz, hp, Color(0.5, 0.8, 1.0, 0.6)]]:
			im.surface_set_color(seg[2])
			im.surface_add_vertex(seg[0])
			im.surface_set_color(seg[2])
			im.surface_add_vertex(seg[1])
		_label(pa + Vector3(0, 1.2, 0), "А%d" % (i + 1), Color(1.0, 0.85, 0.4))
		_label(pz + Vector3(0, 1.2, 0), "Б%d" % (i + 1), Color(0.5, 1.0, 0.6))
	if any:
		im.surface_end()


func _label(p: Vector3, t: String, col: Color) -> void:
	var l := Label3D.new()
	l.text = t
	l.font_size = 48
	l.pixel_size = 0.0006
	l.fixed_size = true
	l.outline_size = 12
	l.modulate = col
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = p
	game.add_child(l)
	_labels.append(l)


# ---------------------------------------------------------------- сохранение

func to_list() -> Array:
	var out := []
	for b in st.keys():
		var h = b.host if b.host != null else b
		var e := {"c": [h.cell.x, h.cell.y], "t": b.type, "sub": b.host != null, "si": h.subs.find(b), "d": []}
		for d in st[b].d:
			var o := {"bat": d.bat, "hp": d.hp, "item": d.item, "n": d.n, "dead": d.state == "dead", "dt": d.dead_t, "r": d.route}
			if d.get("sl") is Array and not (d.sl as Array).is_empty():
				o["sl"] = d.sl   # A-9 r7: износ/свежесть груза
			e.d.append(o)
		out.append(e)
	return out


func load_list(arr) -> void:
	clear()
	sync()
	if not arr is Array:
		return
	for e in arr:
		if not e is Dictionary:
			continue
		var h = f.building_at(Vector2i(int(e.c[0]), int(e.c[1])))
		if h == null:
			continue
		var b = h
		if bool(e.get("sub", false)):
			b = null
			var si := int(e.get("si", -1))
			if si >= 0 and si < h.subs.size() and h.subs[si].type == str(e.t):
				b = h.subs[si]   # A16-10: две одинаковые станции в составном — по номеру
			else:
				for s in h.subs:
					if s.type == str(e.t):
						b = s
						break
		if b == null or not st.has(b):
			continue
		var list: Array = st[b].d
		for i in mini(list.size(), e.d.size()):
			var src: Dictionary = e.d[i]
			var d: Dictionary = list[i]
			d.bat = float(src.get("bat", battery()))
			d.hp = float(src.get("hp", c("hp", 60.0)))
			d.item = str(src.get("item", ""))
			d.n = int(src.get("n", 0))
			d.route = int(src.get("r", -1))
			if src.get("sl") is Array:
				d["sl"] = src.sl
			else:
				d.erase("sl")
			if bool(src.get("dead", false)):
				d.state = "dead"
				d.dead_t = float(src.get("dt", 0.0))
				if d.node != null:
					d.node.visible = false


## В полёте при сохранении: дроны мгновенно возвращаются на станцию (груз остаётся у них).
func clear() -> void:
	for b in st.keys():
		for d in st[b].d:
			_free(d)
	st.clear()
	pick_cb = null
