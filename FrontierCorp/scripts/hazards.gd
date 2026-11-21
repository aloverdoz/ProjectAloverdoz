class_name Hazards
extends RefCounted
## 14.22: опасности — радиация и серная кислота. Модуль «Опасности» (новая игра → модули).
## Радиация: урановые залежи, радиоактивные предметы в рюкзаке и в зданиях, работающая АЭС, заражённая земля.
##   Герой копит дозу; урон = мощность облучения. Защитный костюм снимает долю («Защита от радиации»).
##   Заражённая земля — клетки с уровнем заражения: на ней нельзя строить, пока не очистить
##   (станция дезактивации, баллон). Сама заражённость спадает очень медленно.
## Кислота: разъедает трубы и баки без «Кислотостойкий»; лопнувшая труба — лужа, которая жжёт героя;
##   кислота в рюкзаке без костюма понемногу обжигает.
## Правится: «Настройки → Радиация», «Настройки → Кислота», предметы (rad, carry_dps, rad_protect, acid_protect, decon),
## здания (acid_proof, rad_shield, decon_radius, decon_rate, decon_per_item).

var game
var zone := {}        # клетка сетки заражения (Vector2i) → уровень
var puddles: Array = []   # кислотные лужи: {p, t, node}
var rate := 0.0       # мощность облучения у героя сейчас (после защиты)
var raw := 0.0        # без защиты
var dose := 0.0       # накопленная доза 0..100
var acid_hit := 0.0   # урон кислотой в секунду сейчас
var _t := 0.0
var _acid_t := 0.0
var _decon_t := 0.0
var _click_t := 0.0
var _mm: MultiMeshInstance3D = null
var _dirty := true
var _vis_t := 0.0


func _init(g) -> void:
	game = g


static func rcfg() -> Dictionary:
	return DB.setting("radiation", {})


static func acfg() -> Dictionary:
	return DB.setting("acid", {})


func enabled() -> bool:
	return game.module("hazards")


static func grid() -> int:
	return maxi(1, int(rcfg().get("zone_grid", 2)))


static func key_of(p: Vector3) -> Vector2i:
	var c := World.world_to_cell(p)
	var g := grid()
	return Vector2i(floori(float(c.x) / g), floori(float(c.y) / g))


static func key_center(k: Vector2i) -> Vector3:
	var g := grid()
	return Vector3((k.x + 0.5) * g * World.C, 0.0, (k.y + 0.5) * g * World.C)


## Уровень заражения земли в точке.
func level_at(p: Vector3) -> float:
	return float(zone.get(key_of(p), 0.0))


func level_cell(c: Vector2i) -> float:
	var g := grid()
	return float(zone.get(Vector2i(floori(float(c.x) / g), floori(float(c.y) / g)), 0.0))


## Заразить круг (радиус в клетках): к центру сильнее.
func contaminate(p: Vector3, r_cells: float, strength: float) -> void:
	var g := grid()
	var rk := ceili(r_cells / g)
	var k0 := key_of(p)
	for dx in range(-rk, rk + 1):
		for dz in range(-rk, rk + 1):
			var k := k0 + Vector2i(dx, dz)
			var d := World.dist(key_center(k), p) / World.C
			if d > r_cells:
				continue
			var v := strength * (1.0 - 0.7 * d / maxf(1.0, r_cells))
			zone[k] = maxf(float(zone.get(k, 0.0)), v)
	_dirty = true


## Очистить: снять до amount с каждой клетки в радиусе (в клетках). Возвращает, сколько всего снято.
func decon_at(p: Vector3, r_cells: float, amount: float) -> float:
	var g := grid()
	var rk := ceili(r_cells / g)
	var k0 := key_of(p)
	var took := 0.0
	for dx in range(-rk, rk + 1):
		for dz in range(-rk, rk + 1):
			var k := k0 + Vector2i(dx, dz)
			if not zone.has(k):
				continue
			if World.dist(key_center(k), p) / World.C > r_cells:
				continue
			var v := float(zone[k])
			var t := minf(v, amount)
			took += t
			if v - t < 0.05:
				zone.erase(k)
			else:
				zone[k] = v - t
	if took > 0.0:
		_dirty = true
	return took


## Почему здесь нельзя строить (пусто — можно).
func build_why(c: Vector2i) -> String:
	if not enabled() or zone.is_empty():
		return ""
	var lim := float(rcfg().get("build_block", 3.0))
	if lim > 0.0 and level_cell(c) >= lim:
		return "Земля заражена радиацией (%d) — очистите станцией дезактивации или баллоном" % int(level_cell(c))
	return ""


static func rad_of(id: String) -> float:
	return float(DB.item(id).get("rad", 0.0)) if id != "" else 0.0


## Мощность облучения в точке p (без защиты героя).
func rad_at(p: Vector3, with_inv := true) -> float:
	var c := rcfg()
	var sum := level_at(p) * float(c.get("zone_k", 0.05))
	# урановые залежи рядом
	var dr := float(c.get("deposit_radius", 7.0))
	var ds := float(c.get("deposit_strength", 1.5))
	if ds > 0.0:
		var pc := World.world_to_cell(p)
		var best := INF
		var ri := ceili(dr)
		for dx in range(-ri, ri + 1, 1):
			for dz in range(-ri, ri + 1, 1):
				var it: String = game.world.deposit_item(pc + Vector2i(dx, dz))
				if it == "" or rad_of(it) <= 0.0:
					continue
				best = minf(best, sqrt(float(dx * dx + dz * dz)))
		if best < INF:
			sum += ds * maxf(0.0, 1.0 - best / maxf(1.0, dr))
	# здания: радиоактивное содержимое без защиты и работающие реакторы
	var br := float(c.get("building_radius", 8.0)) * World.C
	var f = game.factory
	for b in f.all:
		if b.dead:
			continue
		var d: float = World.dist(b.center(), p)
		if d > br:
			continue
		var fall := 1.0 - d / br
		if Nuclear.is_reactor(b):
			var s := Nuclear.st(b)
			sum += float(c.get("reactor_leak", 0.5)) * Nuclear.active_rods(b) * (1.0 - float(s.rods)) * fall
			sum += float(c.get("reactor_hot", 2.0)) * clampf((float(s.T) - float(Nuclear.c("warn_t", 500.0))) / 300.0, 0.0, 1.0) * fall
		if b.p("rad_shield", false):
			continue
		var r := 0.0
		for inv in [b.inv, b.out, b.fuel]:
			if inv == null:
				continue
			for s in inv.slots:
				if s != null:
					r += rad_of(s.id) * s.n
		if r > 0.0:
			sum += minf(float(c.get("item_cap", 6.0)), r * float(c.get("building_k", 0.3))) * fall
	if with_inv:
		sum += inv_rad()
	return sum


func inv_rad() -> float:
	var c := rcfg()
	var r := 0.0
	for s in game.player.inv.slots:
		if s != null:
			r += rad_of(s.id) * s.n
	return minf(float(c.get("item_cap", 6.0)), r * float(c.get("item_k", 1.0)))


func protect(kind: String) -> float:
	var cl: String = game.player.clothes
	if cl == "":
		return 0.0
	return clampf(float(DB.item(cl).get(kind, 0.0)), 0.0, 1.0)


func update(dt: float) -> void:
	if not enabled():
		rate = 0.0
		raw = 0.0
		acid_hit = 0.0
		if _mm:
			_mm.visible = false
		return
	_t += dt
	_acid_t += dt
	_decon_t += dt
	_vis_t += dt
	if _t >= 0.5:
		_step(_t)
		_t = 0.0
	if _acid_t >= 1.0:
		_acid(_acid_t)
		_acid_t = 0.0
	if _decon_t >= 1.0:
		_stations(_decon_t)
		_decay(_decon_t)
		_decon_t = 0.0
	_geiger(dt)
	if _dirty and _vis_t >= 0.5:
		_vis_t = 0.0
		_dirty = false
		_draw_zone()



## A-7 r5: в сплитскрине у каждого героя свои показатели — считаем по очереди за каждое место.
func _per_hero(fn: Callable, vars: Array) -> bool:
	var sp = game.get("split")
	if sp == null or not sp.running():
		return false
	for i in 2:
		sp.with_seat(i, func():
			var pl = game.player
			if pl != null:
				for k in vars:
					if pl.has_meta("hzr_" + k):
						set(k, pl.get_meta("hzr_" + k))
				fn.call()
				for k in vars:
					pl.set_meta("hzr_" + k, get(k)))
	var me = game.player
	if me != null:
		for k in vars:
			if me.has_meta("hzr_" + k):
				set(k, me.get_meta("hzr_" + k))
	return true

func _step(dt: float) -> void:
	if game.strategy:
		raw = 0.0
		rate = 0.0
		acid_hit = 0.0
		return
	if _per_hero(_step_one.bind(dt), ["raw", "rate", "dose", "acid_hit"]):
		return
	_step_one(dt)


func _step_one(dt: float) -> void:
	var c := rcfg()
	var pl = game.player
	if pl == null:
		return
	raw = rad_at(pl.position) if bool(c.get("enabled", true)) else 0.0
	rate = raw * (1.0 - protect("rad_protect"))
	if rate > 0.02:
		dose = minf(100.0, dose + rate * float(c.get("dose_k", 1.0)) * dt)
	else:
		dose = maxf(0.0, dose - float(c.get("recover", 0.5)) * dt)
	# кислота в рюкзаке
	var a := acfg()
	acid_hit = 0.0
	if bool(a.get("enabled", true)):
		var n := 0.0
		for s in pl.inv.slots:
			if s != null and float(DB.item(s.id).get("carry_dps", 0.0)) > 0.0:
				n += float(DB.item(s.id).carry_dps) * s.n
		acid_hit += minf(float(a.get("carry_cap", 5.0)), n * float(a.get("carry_k", 1.0)))
		for pd in puddles:
			if World.dist(pd.p, pl.position) <= float(a.get("spill_radius", 4.0)) * World.C * 0.5:
				acid_hit += float(a.get("spill_dps", 10.0))
				break
		acid_hit *= 1.0 - protect("acid_protect")
	if game.flags.get("god", false) or not pl.alive:
		return
	var dmg := rate * float(c.get("dmg_k", 1.0))
	if dose >= 100.0:
		dmg += float(c.get("sick_dps", 1.0))
	if dmg > 0.0:
		pl.damage(dmg * dt)
	if acid_hit > 0.0:
		pl.damage(acid_hit * dt)
		game.notify_once("acid_burn", "Кислота обжигает героя! Наденьте защитный костюм, не носите кислоту в рюкзаке, обходите лужи.", Color(0.85, 1.0, 0.3))
	if rate >= float(c.get("warn_at", 0.5)):
		game.notify_once("rad_warn", "Радиация! Герой облучается (%.1f/с). Уйдите подальше или наденьте защитный костюм." % rate, Color(0.5, 1.0, 0.4))
	if dose >= 100.0:
		game.notify_once("rad_sick", "Лучевая болезнь: здоровье тает, пока доза не спадёт. Уйдите из заражённого места.", Color(1, 0.5, 0.3))


## Треск дозиметра.
func _geiger(dt: float) -> void:
	if rate < 0.1 or game.sfx == null or not bool(rcfg().get("geiger", true)):
		return
	_click_t -= dt
	if _click_t <= 0.0:
		_click_t = randf_range(0.05, 0.5) / clampf(rate, 0.2, 6.0)
		game.sfx.play("click", game.player.position)


## Кислота в трубах и баках: разъедает всё без «Кислотостойкий». Лопнувшая — лужа.
func _acid(dt: float) -> void:
	var a := acfg()
	if not bool(a.get("enabled", true)):
		return
	var f = game.factory
	var dps := float(a.get("pipe_dps", 1.5))
	for n in f.fnets:
		if n.fluid == "" or str(DB.item(n.fluid).get("hazard", "")) != "acid":
			continue
		for m in n.members.duplicate():
			if m.dead or m.p("acid_proof", false):
				continue
			var at: Vector3 = m.center()
			f.damage(m, dps * dt)
			game.notify_once("acid_pipe", "Кислота разъедает обычные трубы! Нужны кислотостойкие трубы и баки (или Mk4).", Color(0.85, 1.0, 0.3))
			if m.dead:
				spill(at)
	var now: float = game.factory.sim_time
	for pd in puddles.duplicate():
		if now - float(pd.t) >= float(a.get("spill_time", 45.0)):
			if is_instance_valid(pd.node):
				pd.node.queue_free()
			puddles.erase(pd)


func spill(p: Vector3, quiet := false) -> void:
	var a := acfg()
	var pd := {"p": p, "t": game.factory.sim_time, "node": null}
	if game.is_inside_tree():
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		var r := float(a.get("spill_radius", 4.0)) * World.C * 0.5
		cm.top_radius = r
		cm.bottom_radius = r
		cm.height = 0.04
		mi.mesh = cm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = DB.color(str(a.get("color", "#c8e04a")))
		mat.albedo_color.a = 0.65
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = mat.albedo_color * 0.4
		mi.material_override = mat
		mi.position = Vector3(p.x, game.world.height_at(p) + 0.06, p.z)
		game.add_child(mi)
		pd.node = mi
	puddles.append(pd)
	if not quiet:
		game.notify("Труба лопнула: разлилась кислота!", Color(0.85, 1.0, 0.3))


## Станции дезактивации: чистят округу, расходуя раствор; энергия — из сети.
func _stations(dt: float) -> void:
	if zone.is_empty():
		return
	var f = game.factory
	for b in f.all:
		if b.dead or float(b.p("decon_rate", 0.0)) <= 0.0 or b.inv == null:
			continue
		if float(b.p("power", 0.0)) > 0.0 and f.sat_c(b) <= 0.05:
			continue
		var item := str(b.p("decon_item", "decon_solution"))
		var budget := float(b.bstate.get("decon_left", 0.0))
		if budget <= 0.0:
			if b.inv.count(item) <= 0:
				b.active = false
				continue
			b.inv.remove(item, 1)
			budget += float(b.p("decon_per_item", 200.0))
		var took := decon_at(b.center(), float(b.p("decon_radius", 16.0)), float(b.p("decon_rate", 1.5)) * dt)
		b.bstate["decon_left"] = budget - took
		b.active = took > 0.0


func _decay(dt: float) -> void:
	var k := float(rcfg().get("zone_decay", 0.003)) * dt
	if k <= 0.0 or zone.is_empty():
		return
	for key in zone.keys():
		var v := float(zone[key]) - k
		if v < 0.05:
			zone.erase(key)
		else:
			zone[key] = v
	_dirty = true


## Зелёное свечение над заражённой землёй.
func _draw_zone() -> void:
	if not game.is_inside_tree():
		return
	if _mm == null:
		_mm = MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		var q := PlaneMesh.new()
		q.size = Vector2(grid() * World.C, grid() * World.C)
		mm.mesh = q
		_mm.multimesh = mm
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mm.material_override = mat
		_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		game.add_child(_mm)
	_mm.visible = not zone.is_empty()
	var mmv: MultiMesh = _mm.multimesh
	mmv.instance_count = zone.size()
	var col := DB.color(str(rcfg().get("zone_color", "#7dff5a")))
	var i := 0
	for k in zone:
		var p := key_center(k)
		p.y = game.world.height_at(p) + 0.12
		mmv.set_instance_transform(i, Transform3D(Basis(), p))
		var cc := col
		cc.a = clampf(float(zone[k]) / 60.0, 0.08, 0.45)
		mmv.set_instance_color(i, cc)
		i += 1


func text() -> String:
	var t := "☢ %.1f/с" % rate
	if raw > rate + 0.05:
		t += " (без костюма %.1f)" % raw
	t += " · доза %d%%" % int(dose)
	if acid_hit > 0.0:
		t += " · кислота −%.1f/с" % acid_hit
	return t


func to_dict() -> Dictionary:
	var z := []
	for k in zone:
		z.append([k.x, k.y, snappedf(float(zone[k]), 0.01)])
	var pd := []
	for p in puddles:
		pd.append([p.p.x, p.p.z, game.factory.sim_time - float(p.t)])
	return {"zone": z, "dose": dose, "puddles": pd}


func from_dict(d: Dictionary) -> void:
	zone.clear()
	for e in d.get("zone", []):
		zone[Vector2i(int(e[0]), int(e[1]))] = float(e[2])
	dose = float(d.get("dose", 0.0))
	for p in puddles:
		if is_instance_valid(p.node):
			p.node.queue_free()
	puddles.clear()
	for e in d.get("puddles", []):
		spill(Vector3(float(e[0]), 0, float(e[1])), true)
		puddles[-1].t = game.factory.sim_time - float(e[2])
	_dirty = true
