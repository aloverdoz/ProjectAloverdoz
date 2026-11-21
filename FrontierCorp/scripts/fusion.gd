class_name Fusion
extends RefCounted
## 14.10: объединение зданий.
## 1) Уровни: две одинаковые постройки одного уровня рядом сливаются в одну «Объединение 2» (быстрее, сильнее,
##    больше места). Две «Объединение 2» рядом → «Объединение 3» и так до предела (5).
## 2) Составные здания (эксперимент, включается при создании игры): в здание встраиваются соседние —
##    генератор и аккумулятор (своя энергия), печи и сборщики (переработка по цепочке), сундук (всё собирается
##    в него), турели и щиты (оборона на крыше). Не больше 5 зданий в одном.
## Настройки: «Данные» → «Настройки» → «Объединение зданий»; модули «Объединение зданий» и «Составные здания».

const ROLE_ORDER := {"make": 0, "guard": 1, "store": 2, "power": 3, "other": 4, "drone": 5}

var f            # Factory
var game
var hosts: Array = []         # составные здания (у которых есть встроенные)
var declined := {}            # пары, от которых игрок отказался
var offers: Array = []        # [{a, b, kind}] — предложения объединить (показывает hud)


func _init(fac) -> void:
	f = fac
	game = fac.game


static func cfg() -> Dictionary:
	var c = DB.setting("fusion", {})
	return c if c is Dictionary else {}


func levels_on() -> bool:
	return bool(cfg().get("enabled", true)) and game.module("fusion")


func combo_on() -> bool:
	return bool(cfg().get("combo", true)) and game.module("combo")


static func max_level() -> int:
	return clampi(int(cfg().get("max_level", 5)), 1, 20)


static func max_parts() -> int:
	return clampi(int(cfg().get("max_parts", 5)), 2, 12)


## Во сколько раз сильнее здание уровня lvl (список «Сила по уровням»; по умолчанию ×уровень).
static func mult_for(lvl: int) -> float:
	var lm = cfg().get("level_mult", [])
	if lm is Array and lvl - 1 < lm.size() and lvl >= 1:
		return maxf(0.1, float(lm[lvl - 1]))
	return float(lvl)


## Роль здания в составном: make — производит, guard — оборона, store — склад, power — энергия, other — прочее.
static func role(b) -> String:
	match b.beh:
		"miner", "crafter":
			return "make"
		"turret":
			return "guard"
		"storage":
			return "store"
		"generator", "battery":
			return "power"
		"light":
			return "other"
	if str(b.p("defense", "")) != "":
		return "guard"
	if b.p("drone_station", false):
		return "drone"
	return ""


## Ставится на крышу составного (турели, фонари, щиты, станции дронов).
static func on_roof(s) -> bool:
	return s.beh in ["turret", "light"] or str(s.p("defense", "")) != "" or bool(s.p("drone_station", false))


## Встроенная печь: "fuel" — нужно топливо (руками, лентой, из цепочки или ящика), "power" — греется от энергии здания.
static func fuel_mode() -> String:
	return str(cfg().get("furnace_fuel", "fuel"))


## Печь греется от встроенной энергии вместо топлива (только в режиме "power").
static func heats_by_power(b) -> bool:
	if fuel_mode() != "power" or b.beh != "crafter" or not b.p("fuel", false):
		return false
	var h = b.host if b.host != null else b
	return not h.subs.is_empty() and h.has_gen


func can_level(b) -> bool:
	if b == null or b.dead or b.host != null or b == f.hq:
		return false
	var no: Array = cfg().get("no_merge", ["belt", "splitter", "merger", "pipe", "foundation", "wall", "floor", "hq", "pole", "tank", "decor"])
	# щиты, стазис и ремонт — тоже «decor», но объединяются
	return not (b.beh in no and not role(b) in ["guard", "drone"]) and not bool(b.p("no_fusion", false)) and not b.type in SPECIAL


## 1.1.20 B14-3: особые «склады» (база игрока, рынок, капсула, сундук подземелья, дезактивация, пары, врата) не сливаются.
const SPECIAL := ["outpost", "player_market", "supply_capsule", "dungeon_chest", "decon_station", "waste_storage", "ufo_pad", "star_gate"]


func can_combo(b) -> bool:
	return b != null and not b.dead and b.host == null and b != f.hq and role(b) != "" and not bool(b.p("no_fusion", false)) \
		and not b.type in SPECIAL and not bool(b.p("wild", false))


func parts(b) -> int:
	return 1 + b.subs.size()


## Соседние здания (касаются сторонами).
func neighbors(b) -> Array:
	var out := []
	for c in f.footprint(b.type, b.cell):
		for d in f.DIRS:
			var o = f.grid.get(World.wc(c + d))
			if o != null and o != b and not o in out:
				out.append(o)
	return out


## 15.2: какая технология нужна, чтобы получить уровень n (или составное из n зданий). "" — уже можно.
func tech_why(n: int) -> String:
	var ts = cfg().get("techs", [])
	if not ts is Array or n < 2 or game.tech == null or not game.tech.enabled() or game.flags.get("free_build", false):
		return ""
	var i := mini(n - 2, ts.size() - 1)
	if i < 0:
		return ""
	for j in i + 1:
		var tid := str(ts[j])
		if tid != "" and game.tech.nodes().has(tid) and not game.tech.done.has(tid):
			return "Нужна технология «%s» (дерево открытий, J)" % str(game.tech.nodes()[tid].get("name", tid))
	return ""


## Почему нельзя слить два одинаковых ("" — можно).
func level_why(a, b) -> String:
	if not levels_on():
		return "Объединение выключено"
	if a.type != b.type:
		return "Разные здания"
	if a.lvl != b.lvl:
		return "Разный уровень объединения (%d и %d)" % [a.lvl, b.lvl]
	if a.lvl >= max_level():
		return "Уже максимальный уровень (%d)" % max_level()
	if not can_level(a) or not can_level(b):
		return "Это здание не объединяется"
	if not a.subs.is_empty() or not b.subs.is_empty():
		return "Составное здание сначала не объединить по уровню"
	return tech_why(a.lvl + 1)


## Почему нельзя встроить одно в другое ("" — можно).
func combo_why(a, b) -> String:
	if not combo_on():
		return "Составные здания выключены (модуль при создании игры)"
	if not can_combo(a) or not can_combo(b):
		return "Это здание не встраивается"
	if parts(a) + parts(b) > max_parts():
		return "Не больше %d зданий в одном" % max_parts()
	var h = pick_host(a, b)
	var m = b if h == a else a
	if role(m) == "make" and m.beh == "miner":
		return "Бур не встраивается в другое здание (поставьте бур первым)"
	return tech_why(parts(a) + parts(b))


## Кто станет основой: сначала производство, потом оборона, склад, энергия.
func pick_host(a, b):
	var ra: int = ROLE_ORDER.get(role(a), 9)
	var rb: int = ROLE_ORDER.get(role(b), 9)
	if a.beh == "miner":
		return a
	if b.beh == "miner":
		return b
	return a if ra <= rb else b


# ---------------------------------------------------------------- предложения (окошко «Объединить?»)

## После постройки: есть ли рядом с кем объединиться. Окошко показывает hud.
func check_offers(b) -> void:
	if b == null or b.dead or not bool(cfg().get("ask", true)):
		return
	for n in neighbors(b):
		var w := level_why(n, b) if n.type == b.type else combo_why(n, b)
		if w.begins_with("Нужна технология"):
			game.notify_once("fuse_tech_" + w, "Объединить нельзя: " + w, Color(1, 0.8, 0.4))
			break
	for n in neighbors(b):
		var key := _pair(b, n)
		if declined.has(key):
			continue
		if level_why(n, b) == "":
			_offer(n, b, "level")
			return
	for n in neighbors(b):
		var key2 := _pair(b, n)
		if declined.has(key2) or n.type == b.type:
			continue
		if combo_why(n, b) == "":
			var hh = pick_host(n, b)
			var mm = b if hh == n else n
			_offer(n, b, "choice" if sub_twin(hh, mm) != null else "combo")
			return
		var hh2 = n if not n.subs.is_empty() else null
		if hh2 != null and sub_twin(hh2, b) != null:
			_offer(n, b, "sub")   # составное уже полное, но встроенную такую же можно поднять уровнем
			return


func _offer(a, b, kind: String) -> void:
	for o in offers:
		if (o.a == a and o.b == b) or (o.a == b and o.b == a):
			return
	offers.append({"a": a, "b": b, "kind": kind, "t": 0.0})


func decline(o: Dictionary) -> void:
	declined[_pair(o.a, o.b)] = true
	offers.erase(o)


static func _pair(a, b) -> String:
	var x := "%d,%d" % [a.cell.x, a.cell.y]
	var y := "%d,%d" % [b.cell.x, b.cell.y]
	return x + "|" + y if x < y else y + "|" + x


func offer_text(o: Dictionary) -> String:
	var a = o.a
	var b = o.b
	if o.kind == "level":
		return "Рядом две «%s». Объединить в «%s · Объединение %d»? Работает в %s раза сильнее, одно здание пропадёт." % [
			DB.building(a.type).get("name", a.type), DB.building(a.type).get("name", a.type), a.lvl + 1, _num(mult_for(a.lvl + 1))]
	if o.kind in ["choice", "sub"]:
		var hh = a if not a.subs.is_empty() else pick_host(a, b)
		var mm = b if hh == a else a
		var tw = sub_twin(hh, mm)
		var t := "В «%s» уже встроено «%s». " % [name_of(hh), name_of(tw)]
		if o.kind == "choice":
			t += "Встроить вторую отдельно (%d из %d зданий) или объединить с уже встроенной (Объединение %d, сила ×%s, место не занимает)?" % [parts(hh) + 1, max_parts(), tw.lvl + 1, _num(mult_for(tw.lvl + 1))]
		else:
			t += "Объединить с ней? Станет Объединение %d, сила ×%s." % [tw.lvl + 1, _num(mult_for(tw.lvl + 1))]
		return t
	var h = pick_host(a, b)
	var m = b if h == a else a
	return "Встроить «%s» в «%s»? Получится одно составное здание (%d из %d). %s" % [
		name_of(m), name_of(h), parts(h) + parts(m), max_parts(), module_hint(m)]


static func _num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, round(v)) else str(snappedf(v, 0.1))


## Что даст встроенное здание.
static func module_hint(m) -> String:
	match m.beh:
		"generator":
			return "Своя энергия — провода не нужны."
		"battery":
			return "Запас энергии на ночь."
		"crafter":
			return "Сразу перерабатывает то, что делает основа."
		"storage":
			return "Готовое собирается в него."
		"turret":
			return "Турель на крыше."
		"light":
			return "Фонарь на крыше."
	if m.p("drone_station", false):
		return "Станция дронов на крыше: дроны возят отсюда и сюда."
	if str(m.p("defense", "")) != "":
		return "Защита вокруг здания."
	return ""


# ---------------------------------------------------------------- слияние

## Слить два одинаковых соседних: b пропадает, a становится уровнем выше.
func fuse_level(a, b) -> bool:
	if level_why(a, b) != "":
		return false
	if a.beh == "storage" and a.inv != null:
		a.inv.resize(maxi(a.inv.size(), int(a.p("slots", 16)) * (a.lvl + 1)))   # 1.1.20 A14-1: сначала место, потом содержимое
	_transfer(b, a)
	a.paid = _sum_paid(a.paid, b.paid, a.type)
	f.remove(b)
	set_level(a, a.lvl + 1)
	game.fx.dirt(a.center(), 0.8)
	game.sfx.play("place", a.center())
	game.notify("%s · Объединение %d — сила ×%s" % [DB.building(a.type).get("name", a.type), a.lvl, _num(a.mult)], Color(1.0, 0.8, 0.35))
	f.power_dirty = true
	check_offers(a)
	return true


func set_level(b, lvl: int) -> void:
	b.lvl = clampi(lvl, 1, max_level())
	b.mult = mult_for(b.lvl)
	b.mine_period = 0.0
	if b.beh == "storage" and b.inv != null:
		b.inv.resize(maxi(b.inv.size(), int(b.p("slots", 16)) * b.lvl))
	if b.beh in ["miner", "crafter"] and b.out != null:
		b.out.resize(maxi(b.out.size(), (2 if b.beh == "miner" else int(b.p("out_slots", 2))) + b.lvl - 1))
	if b.beh == "crafter" and b.inv != null:
		b.inv.resize(maxi(b.inv.size(), int(b.p("in_slots", 4)) + b.lvl - 1))
	b.maxhp = float(DB.building(b.type).get("hp", 100)) * (1.0 + game.bonus("build_hp")) * (1.0 + 0.5 * (b.lvl - 1))
	b.hp = minf(b.maxhp, b.hp + b.maxhp * 0.5)
	refresh_visual(b)


## 15.4: у составного уже есть такое же встроенное (печь в буре, ставим ещё печь) — можно не вторую,
## а поднять встроенную на уровень. Возвращает встроенную-«близнеца» или null.
func sub_twin(h, m):
	if h == null or m == null or h.subs.is_empty() or not m.subs.is_empty() or not levels_on():
		return null
	for s in h.subs:
		if s.type == m.type and s.lvl == m.lvl and s.lvl < max_level() and tech_why(s.lvl + 1) == "" and can_level(m):
			return s
	return null


func fuse_into_sub(h, m) -> bool:
	var s = sub_twin(h, m)
	if s == null:
		return false
	if s.beh == "storage" and s.inv != null:
		s.inv.resize(maxi(s.inv.size(), int(s.p("slots", 16)) * (s.lvl + 1)))   # 1.1.20 A14-2: встроенный ящик тоже растёт
	_transfer(m, s)
	s.paid = _sum_paid(s.paid, m.paid, s.type)
	f.remove(m)
	s.lvl += 1
	s.mult = mult_for(s.lvl)
	if s.beh in ["miner", "crafter"] and s.out != null:
		s.out.resize(maxi(s.out.size(), (2 if s.beh == "miner" else int(s.p("out_slots", 2))) + s.lvl - 1))
	if s.beh == "crafter" and s.inv != null:
		s.inv.resize(maxi(s.inv.size(), int(s.p("in_slots", 4)) + s.lvl - 1))
	s.maxhp = float(DB.building(s.type).get("hp", 100)) * (1.0 + game.bonus("build_hp")) * (1.0 + 0.5 * (s.lvl - 1))   # 1.1.15: с бонусом прочности
	refresh_visual(h)
	f.power_dirty = true
	game.fx.dirt(h.center(), 0.8)
	game.sfx.play("place", h.center())
	game.notify("%s внутри «%s» · Объединение %d — сила ×%s" % [DB.building(s.type).get("name", s.type), name_of(h), s.lvl, _num(s.mult)], Color(1.0, 0.8, 0.35))
	return true


## 15.4: убрать одно встроенное здание: стоимость и содержимое возвращаются игроку, остальное работает дальше.
func detach(h, s) -> bool:
	if h == null or s == null or not s in h.subs:
		return false
	f.renderer(s.type).remove(s)
	f.turrets.erase(s)
	h.subs.erase(s)
	f.refund(s.paid if s.paid is Dictionary else game._scaled_cost(s.type))
	f._refund_crafting(s)   # A-6 r9: сырьё начатого изделия встроенной машины
	_give_back(s)
	s.dead = true
	s.host = null
	if h.subs.is_empty():
		hosts.erase(h)
		h.has_gen = false
		h.csat = 1.0
		h.surplus = 0.0
		h.gen_cap = 0.0
		_clear_deco(h)
	refresh_visual(h)
	f.power_dirty = true
	game.sfx.play("click", h.center())
	game.notify("«%s» убрано из «%s», стоимость возвращена" % [name_of(s), name_of(h)], Color(0.7, 0.9, 1.0))
	return true


## 15.5: что составное отдаёт на ленту: пусто — всё готовое (авто), иначе только выбранные предметы.
static func out_filter(h) -> Array:
	var l = h.cfg.get("out_items", [])
	return l if l is Array else []


static func out_ok(h, id: String) -> bool:
	var l := out_filter(h)
	return l.is_empty() or id in l


## Что вообще может выйти из составного (для выбора в окне): выход основы и машин цепочки.
func out_candidates(h) -> Array:
	var out := []
	var add := func(id: String):
		if id != "" and not id in out and not DB.is_fluid(id):
			out.append(id)
	if h.beh == "miner":
		add.call(str(h.recipe))
	var rids := []
	if h.beh == "crafter":
		rids += [h.recipe] if h.recipe != "" else DB.recipes_for(h.p("station", ""))
	for s in h.subs:
		if s.beh == "crafter":
			rids += [s.recipe] if s.recipe != "" else DB.recipes_for(s.p("station", ""))
	for rid in rids:
		for o in DB.data.recipes.get(rid, {}).get("out", {}):
			add.call(str(o))
	for inv in [h.out]:
		if inv != null:
			for sl in inv.slots:
				if sl != null:
					add.call(str(sl.id))
	return out


## Встроить: одно из двух становится основой, второе (и всё, что было встроено в него) — его частью.
func fuse_combo(a, b) -> bool:
	if combo_why(a, b) != "":
		return false
	var h = pick_host(a, b)
	var m = b if h == a else a
	var mods: Array = [m] + m.subs
	m.subs = []
	hosts.erase(m)
	f.remove(m)
	for s in mods:
		_attach(h, s)
	if not h in hosts:
		hosts.append(h)
	if h.out != null and h.out.size() < 4:
		h.out.resize(4)
	refresh_visual(h)
	f.power_dirty = true
	game.fx.dirt(h.center(), 0.8)
	game.sfx.play("place", h.center())
	game.notify("Составное здание: %s" % chain_text(h), Color(0.6, 0.9, 1.0))
	check_offers(h)
	return true


## Сделать здание s частью h (без своей клетки, считается через h).
func _attach(h, s) -> void:
	s.dead = false
	s.host = h
	s.cell = h.cell
	s.y = h.y
	s.net = -1
	s.next = null
	s.subs = []
	s.cfg.erase("clock")   # A-9 r3: у встроенного здания нет своего ползунка — работает на полную, как и хозяин
	s.cfg.erase("off")
	if s.beh == "crafter" and fuel_mode() == "power":
		s.fuel = null           # режим «греется от энергии»: топливо не нужно
	if s.beh == "turret" and not s in f.turrets:
		f.turrets.append(s)
	if s.beh == "light" and s.light == null:
		pass
	h.subs.append(s)


func _sum_paid(p1, p2, type: String) -> Dictionary:
	var out := {}
	for p in [p1, p2]:
		var d: Dictionary = p if p is Dictionary else game._scaled_cost(type)
		for k in d:
			out[k] = int(out.get(k, 0)) + int(d[k])
	return out


## Содержимое уходит в то, что остаётся (или к герою, если не влезло).
func _transfer(from, to) -> void:
	f._refund_crafting(from)   # 1.1.15: сырьё начатого изделия не пропадает при объединении
	for k in ["inv", "out", "fuel"]:
		var src: Inventory = from.get(k)
		if src == null:
			continue
		var dst: Inventory = to.get(k)
		if dst == src:
			continue   # A-10 r4: две половины одной запутанной пары — общий склад, переносить нечего
		for i in src.size():
			var sl = src.slots[i]
			if sl == null:
				continue
			if sl.has("dur") or sl.has("fresh"):
				# A-1 r9: износ и свежесть переезжают вместе с ячейкой
				if dst == null or dst.add_slot(sl) > 0:
					f.give_player_slot(sl)
				src.slots[i] = null
				continue
			var left: int = dst.add(sl.id, sl.n) if dst != null else int(sl.n)
			if left > 0:
				f.give_player(sl.id, left)
			src.slots[i] = null


## Здание разобрали или улучшили: встроенные — тоже.
func drop_subs(h) -> void:
	for s in h.subs:
		f.renderer(s.type).remove(s)
		f.turrets.erase(s)
		s.dead = true
	hosts.erase(h)
	_clear_deco(h)


func refund_subs(h) -> void:
	for s in h.subs:
		f.refund(s.paid if s.paid is Dictionary else game._scaled_cost(s.type))
		f._refund_crafting(s)   # A-6 r9
		_give_back(s)


## A-1 r9: содержимое — герою; инструменты и еда — ячейкой целиком (износ и свежесть).
func _give_back(s) -> void:
	for k in ["inv", "out", "fuel"]:
		var inv: Inventory = s.get(k)
		if inv == null:
			continue
		for sl in inv.slots:
			if sl == null:
				continue
			if sl.has("dur") or sl.has("fresh"):
				f.give_player_slot(sl)
			else:
				f.give_player(sl.id, int(sl.n))
		inv.slots.fill(null)


# ---------------------------------------------------------------- работа составного здания

## Энергия внутри составного: генераторы, аккумуляторы, недостающее — из сети проводов.
## Вызывается каждый такт после расчёта сетей.
func tick_power(dt: float) -> void:
	if hosts.is_empty():
		return
	var day: float = game.sun_power() if game.has_method("sun_power") else game.daylight()
	var wind: float = game.wind() if game.has_method("wind") else 0.6
	for h in hosts.duplicate():
		if h.dead:
			hosts.erase(h)
			continue
		if role(h) == "power":
			continue   # энергоблок (генераторы и аккумуляторы вместе) отдаёт всё в сеть — см. grid_pre
		var need := _need(h)
		var supply := 0.0
		var cap := 0.0
		var gcap := 0.0
		var has_gen := false
		# 15.3: есть кому отдать излишек — сеть по проводам, где не хватает
		var grid_wants: bool = h.net >= 0 and h.net < f.nets.size() and not f.nets[h.net].get("tripped", false) and f.nets[h.net].demand > f.nets[h.net].supply - h.surplus + 0.001
		for s in h.subs:
			if s.beh == "generator":
				has_gen = true
				var pw: float = float(s.p("power", 0)) * s.mult * Factory.clock(s) * Tuning.k(s, "supply")   # 1.3: тонкая настройка и во встроенном
				gcap += pw
				var on := false
				if s.p("solar", false):
					supply += pw * day
					on = day > 0.15
				elif s.p("wind", false):
					supply += pw * wind
					on = wind > 0.05
				else:
					# генератор на топливе: берёт топливо из своих ячеек или из готового в составном
					if s.fuel_t <= 0.0 and (need > 0.0 or grid_wants) and pw > 0.0:
						var fu := _find_fuel(h, s)
						if fu != "":
							s.fuel_t += f.burn_time(s, fu)
					on = s.fuel_t > 0.0 and pw > 0.0
					if on:
						supply += pw
						if need > 0.0 or grid_wants:
							s.fuel_t = maxf(0.0, s.fuel_t - dt * s.mult * maxf(0.05, Factory.clock(s)))   # 1.1.15: уровень объединения и мощность — и расход
				if on != s.active:
					s.active = on
					f.renderer(s.type).set_active(s, 1.0 if on else 0.0)
			elif s.beh == "battery":
				cap += float(s.p("capacity", 2000)) * s.mult
		h.ccap = cap
		h.gen_cap = gcap
		h.cgen = supply
		h.cneed = need
		var bal := supply - need
		h.surplus = 0.0
		if bal >= 0.0:
			var room := maxf(0.0, cap - h.cen) / maxf(dt, 0.0001)
			if grid_wants:
				h.surplus = bal   # сеть просит — отдаём всё свободное, батареи подождут
			else:
				h.surplus = maxf(0.0, bal - room)
			h.cen = minf(cap, h.cen + (bal - h.surplus) * dt)
			h.csat = 1.0
			h.grid_need = 0.0
		else:
			var take := minf(-bal * dt, h.cen)
			h.cen -= take
			var have := supply + take / maxf(dt, 0.0001)
			var short := maxf(0.0, need - have)
			h.grid_need = short
			var g := 0.0
			if short > 0.0 and h.net >= 0 and h.net < f.nets.size():
				g = f.nets[h.net].sat
			have += short * g
			h.csat = clampf(have / maxf(0.001, need), 0.0, 1.0) if need > 0.0 else 1.0
		h.has_gen = has_gen or cap > 0.0


## Энергоблок (основа — генератор или аккумулятор): встроенные генераторы добавляют выработку в сеть,
## аккумуляторы — запас. Вызывается из расчёта сетей.
func grid_pre(day: float, wind: float, dt: float) -> void:
	for h in hosts:
		# 15.3: составное с генератором (бур + ветряк…) отдаёт свободную энергию в сеть по проводам
		if not h.dead and role(h) != "power" and h.net >= 0 and h.net < f.nets.size():
			var nn: Dictionary = f.nets[h.net]
			nn.gen_max += h.gen_cap
			if not nn.tripped:
				nn.supply += h.surplus
	for h in hosts:
		if h.dead or role(h) != "power" or h.net < 0 or h.net >= f.nets.size():
			continue
		var n: Dictionary = f.nets[h.net]
		var cap := 0.0
		for s in h.subs:
			if s.beh == "generator":
				var pw: float = float(s.p("power", 0)) * s.mult * Factory.clock(s) * Tuning.k(s, "supply")   # 1.3: тонкая настройка и во встроенном
				n.gen_max += pw
				var on := false
				if n.tripped:
					on = false
				elif s.p("solar", false):
					n.supply += pw * day
					on = day > 0.15
				elif s.p("wind", false):
					n.supply += pw * wind
					on = wind > 0.05
				else:
					if s.fuel_t <= 0.0 and n.demand > 0.0 and pw > 0.0:   # A-1 r5: выключенный не берёт топливо
						var fu := _find_fuel(h, s)
						if fu != "":
							s.fuel_t += f.burn_time(s, fu)
					on = s.fuel_t > 0.0 and pw > 0.0
					if on:
						n.supply += pw
						if n.demand > 0.0:
							s.fuel_t = maxf(0.0, s.fuel_t - dt * s.mult * maxf(0.05, Factory.clock(s)))   # 1.1.15: уровень объединения и мощность — и расход
				if on != s.active:
					s.active = on
					f.renderer(s.type).set_active(s, 1.0 if on else 0.0)
			elif s.beh == "battery":
				cap += float(s.p("capacity", 2000)) * s.mult
		h.ccap = cap
		if cap > 0.0:
			n.cap += cap
			n.stored += h.cen


func grid_post() -> void:
	for h in hosts:
		if h.dead or role(h) != "power" or h.ccap <= 0.0 or h.net < 0 or h.net >= f.nets.size():
			continue
		var n: Dictionary = f.nets[h.net]
		h.cen = n.stored * h.ccap / maxf(1.0, n.cap)
		n.stored -= h.cen   # остальное раздаётся обычным аккумуляторам
		h.csat = 1.0


func _need(h) -> float:
	var n := 0.0
	var always := Factory.power_constant()
	# A-1 r4: основа-оборона, щит, обогреватель, декоративное/складское здание с энергией — тоже потребители
	if h.want or h.beh == "turret" or (always and h.beh in ["miner", "crafter"]) or str(h.p("defense", "")) != "" \
			or float(h.p("shield_radius", 0)) > 0.0 or float(h.p("heat", 0)) != 0.0 or (not h.blk and h.beh in ["decor", "storage"]):
		var hp := float(h.p("power", 0))
		if heats_by_power(h):
			hp = maxf(hp, float(cfg().get("furnace_power", 4.0)))   # печь-основа греется от своей энергии
		n += hp * power_k(h) * Factory.clock(h)
	for s in h.subs:
		match s.beh:
			"crafter":
				if s.want or always:
					n += maxf(float(s.p("power", 0)), float(cfg().get("furnace_power", 4.0)) if heats_by_power(s) else 0.0) * power_k(s) * Factory.clock(s)
			"turret":
				n += float(s.p("power", 0)) * power_k(s) * Factory.clock(s)
			"light":
				n += float(s.p("power", 0)) * Factory.clock(s)
			_:
				if str(s.p("defense", "")) != "" or (s.p("drone_station", false) and s.want) or (not s.blk and s.beh in ["decor", "storage"]):
					n += float(s.p("power", 0)) * power_k(s) * Factory.clock(s)
	return n


## Сколько энергии ест объединённое здание: ×уровень (если включено «Энергия растёт с уровнем»).
static func power_k(b) -> float:
	return b.mult if bool(cfg().get("power_scale", true)) else 1.0


func _find_fuel(h, s) -> String:
	if s.fuel != null:
		var fu: String = s.fuel.first_item()
		if fu != "":
			s.fuel.remove(fu, 1)
			return fu
	var invs := [h.out, h.inv]
	for sb in h.subs:   # A16-2: и из встроенных ящиков (как у печей)
		if sb.beh == "storage" and sb.inv != null:
			invs.append(sb.inv)
	for inv in invs:
		if inv == null:
			continue
		for sl in inv.slots:
			if sl != null and float(DB.item(sl.id).get("fuel", 0)) > 0.0 and f.fuel_ok(s, sl.id):
				inv.remove(sl.id, 1)
				return sl.id
	return ""


## Встроенные печи и сборщики работают (их скорость — свой уровень и общая энергия).
func tick_subs(dt: float) -> void:
	for h in hosts:
		if h.dead:
			continue
		var halted: bool = bool(h.get("ev_halt")) if "ev_halt" in h else false
		for s in h.subs:
			if s.beh != "crafter":
				continue
			if halted or Factory.clock(h) <= 0.0:
				if s.active:
					s.active = false
					f.renderer(s.type).set_active(s, 0.0)
				continue
			var was: bool = s.active
			_fuel_from_chest(h, s)
			f._crafter(s, dt * s.mult)
			if was != s.active:
				f.renderer(s.type).set_active(s, 1.0 if s.active else 0.0)


## Предметы идут по цепочке: основа → 1-я машина → 2-я… Топливо — в печи, которым оно нужно.
## Что дальше не нужно — в ящик (если встроен и фильтр ящика пускает), иначе на выход основы (на ленту).
## Чего некуда деть — ждёт (машина встаёт) или уничтожается, если у здания «Лишнее: уничтожать».
func flow(h) -> void:
	var stages: Array = h.subs.filter(func(s): return s.beh == "crafter")
	var chest = chest_of(h)
	# 1) то, что сделала основа
	if h.out != null:
		_route(h.out, stages, 0, chest, h, true)
	# 2) то, что сделали встроенные машины
	for i in stages.size():
		_route(stages[i].out, stages, i + 1, chest, h, false)
	if overflow_of(h) == "trash":
		if h.out != null and f._out_full(h):
			trash(h, h.out)
		for st in stages:
			if st.out != null and f._out_full(st):
				trash(h, st.out)


static func chest_of(h):
	for s in h.subs:
		if s.beh == "storage":
			return s
	return null


## 1.1.20 A14-3: положить во встроенные ящики по очереди (когда первый полон — во второй). Возвращает, сколько не влезло.
static func chest_add(h, id: String, n: int) -> int:
	var left := n
	for s in h.subs:
		if left <= 0:
			break
		if s.beh == "storage" and s.inv != null:
			left = s.inv.add(id, left)
	return left


## Что делать с лишним, когда выход полон: "wait" — ждать (здание встаёт), "trash" — уничтожать.
static func overflow_of(b) -> String:
	return str(b.cfg.get("overflow", cfg().get("overflow_default", "wait")))


## Режим ящика составного: "auto" — только готовое (что не нужно машинам дальше), "all" — всё, "list" — только выбранное.
static func chest_mode(h) -> String:
	return str(h.cfg.get("chest", cfg().get("chest_default", "auto")))


func chest_ok(h, id: String, stages: Array) -> bool:
	match chest_mode(h):
		"all":
			return true
		"list":
			var l = h.cfg.get("chest_items", [])
			return l is Array and id in l
	for st in stages:
		if f._is_input(st, id):
			return false
	return true


func _needed_later(stages: Array, from: int, id: String) -> bool:
	for j in range(from, stages.size()):
		if f._is_input(stages[j], id):
			return true
	return false


func _route(src: Inventory, stages: Array, from: int, chest, h, is_host: bool) -> void:
	for i in src.size():
		var sl = src.slots[i]
		if sl == null:
			continue
		var id: String = sl.id
		var moved := false
		for j in range(from, stages.size()):
			var st = stages[j]
			if f._is_input(st, id) and st.inv.count(id) < f.in_cap(st, id) and st.inv.can_add(id, 1):
				var n: int = mini(int(sl.n), 10)
				var left: int = st.inv.add(id, n)
				src.remove(id, n - left)
				moved = true
				break
		if not moved and bool(cfg().get("fuel_from_line", true)) and float(DB.item(id).get("fuel", 0)) > 0.0:
			# топливо из цепочки (например, бур на угле) — в печи, которым его не хватает
			for st in stages:
				if st.fuel != null and f.fuel_ok(st, id) and st.fuel.count(id) < 10 and st.fuel.can_add(id, 1):
					var n2: int = mini(int(sl.n), 10 - st.fuel.count(id))
					var left2: int = st.fuel.add(id, n2)
					src.remove(id, n2 - left2)
					moved = true
					break
		if moved or src.slots[i] == null:
			continue
		var c_ok: bool = chest != null and chest_ok(h, id, stages)
		if is_host:
			# своё основа отдаёт на ленту; если ленты нет (или это не выбрано для ленты) — в ящик (если фильтр пускает)
			if c_ok and (h.next == null or not out_ok(h, id)):
				var left3: int = chest_add(h, id, int(sl.n))
				src.remove(id, int(sl.n) - left3)
			continue
		if c_ok:
			var left4: int = chest_add(h, id, int(sl.n))
			src.remove(id, int(sl.n) - left4)
		elif not _needed_later(stages, from, id) and h.out != null and out_ok(h, id):
			# не для ящика и дальше не нужно — на выход основы (лента или дроны заберут)
			var left5: int = h.out.add(id, int(sl.n))
			src.remove(id, int(sl.n) - left5)


## Уничтожить содержимое переполненного выхода (настройка «Лишнее: уничтожать»).
func trash(b, inv: Inventory) -> void:
	var n := 0
	for i in inv.size():
		if inv.slots[i] != null:
			n += int(inv.slots[i].n)
			inv.slots[i] = null
	if n > 0:
		inv.changed.emit()
		b.trashed = int(b.trashed) + n


## Предмет пришёл в составное здание (лента, дрон, рука) и основе не подошёл: встроенным.
## Топливо — печам и генераторам, сырьё — машинам, патроны турелей — в штаб.
func accept_sub(h, item: String) -> bool:
	var is_fuel: bool = float(DB.item(item).get("fuel", 0)) > 0.0
	if is_fuel:
		# сначала топливо тем печам, у которых его мало (иначе уголь уйдёт в сырьё для стали)
		for s in h.subs:
			if s.fuel != null and s.beh in ["crafter", "generator"] and f.fuel_ok(s, item) and s.fuel.count(item) < 10 and s.fuel.can_add(item, 1):
				s.fuel.add(item, 1)
				return true
	for s in h.subs:
		if s.beh == "crafter" and f._is_input(s, item) and s.inv.count(item) < f.in_cap(s, item) and s.inv.can_add(item, 1):
			s.inv.add(item, 1)
			return true
	if is_fuel:
		for s in h.subs:
			if s.fuel != null and s.beh in ["crafter", "generator"] and f.fuel_ok(s, item) and s.fuel.can_add(item, 1):
				s.fuel.add(item, 1)
				return true
	for s in h.subs:
		if s.beh == "turret" and str(s.p("ammo", "")) == item:
			if s.inv != null:   # 1.1.15: в магазин встроенной турели (раньше уходило в штаб)
				if s.inv.can_add(item, 1):
					s.inv.add(item, 1)
					return true
				continue
			if f.hq != null:
				return f.hq.inv.add(item, 1) == 0
	return false


## Печи без топлива берут его из встроенного ящика (если там лежит уголь и т. п.).
func _fuel_from_chest(h, s) -> void:
	if s.fuel == null or s.fuel_t > 0.0 or s.fuel.first_item() != "" or not bool(cfg().get("fuel_from_chest", true)):
		return
	# 1.3: топливо, попавшее в саму основу (руками в окно, буром с угольной залежи, дроном), тоже идёт в печь
	for inv in [h.fuel, h.inv, h.out]:
		if inv == null or inv == s.fuel:
			continue
		for sl in inv.slots:
			if sl != null and float(DB.item(sl.id).get("fuel", 0)) > 0.0 and f.fuel_ok(s, sl.id):
				var n0: int = mini(int(sl.n), 5)
				var id0: String = sl.id
				var left0: int = s.fuel.add(id0, n0)
				inv.remove(id0, n0 - left0)
				return
	for chest in h.subs:
		if chest.beh != "storage" or chest.inv == null:
			continue
		for sl in chest.inv.slots:
			if sl != null and float(DB.item(sl.id).get("fuel", 0)) > 0.0 and f.fuel_ok(s, sl.id):
				var n: int = mini(int(sl.n), 5)
				var id: String = sl.id
				var left: int = s.fuel.add(id, n)
				chest.inv.remove(id, n - left)
				return


## Что выдаёт составное на ленту: готовое из сундука, если перед ним лента.
func push_chest(h) -> void:
	if h.next == null:
		return
	for s in h.subs:
		if s.beh == "storage":
			# 1.1.15: на ленту — только выбранное в «Идёт на ленту» (остальное остаётся в ящике, как и обещает окно)
			for sl in s.inv.slots:
				if sl == null or DB.is_fluid(str(sl.id)) or not out_ok(h, str(sl.id)):
					continue
				var id := str(sl.id)
				if f.accept(h.next, id, h):
					s.inv.remove(id, 1)
				return   # 1.1.20: пустой ящик — смотрим следующий встроенный


# ---------------------------------------------------------------- имена и описание

func name_of(b) -> String:
	var n := str(DB.building(b.type).get("name", b.type))
	if b.lvl > 1:
		n += " · Объединение %d" % b.lvl
	return n


## «Бур → Печь → Сборщик + Ветряк + Сундук».
func chain_text(h, lines := false) -> String:
	var parts := [name_of(h)]
	var extra := []
	for s in h.subs:
		if s.beh == "crafter":
			parts.append(name_of(s))
		else:
			extra.append(name_of(s))
	var t := " → ".join(parts)
	if not extra.is_empty():
		t += ("\n+ " if lines else " + ") + " + ".join(extra)
	return t


func title(b) -> String:
	if not b.subs.is_empty():
		return "Сборка: " + name_of(b)
	return name_of(b)


# ---------------------------------------------------------------- вид

## Размер основы: уровни делают здание крупнее, в составном основа чуть меньше (вокруг встроенные).
func scale_of(b) -> float:
	var k: float = 1.0 + float(cfg().get("scale_step", 0.1)) * (b.lvl - 1)
	if not b.subs.is_empty():
		k *= float(cfg().get("host_scale", 0.72))
	return k


## 21: во сколько раз модель увеличена вместе со зданием (tools/sizes21.py).
static func grown(b) -> float:
	var m: Dictionary = ModelLib.model(DB.building(b.type).get("model", b.type))
	return float(m.get("scale", 1.0)) / maxf(0.01, float(m.get("scale0", m.get("scale", 1.0))))


## Где стоит встроенное: машины и склад — по углам платформы, оборона и фонари — на крыше.
func sub_xform(h, i: int) -> Transform3D:
	var s = h.subs[i]
	var on_top: bool = on_roof(s)
	var base_rot := Basis(Vector3.UP, f._dir_angle(h.dir))
	if on_top:
		var k := 0
		for j in i:
			var o = h.subs[j]
			if on_roof(o):
				k += 1
		var off := Vector3((k % 2) * 0.7 - 0.35 if k > 0 else 0.0, float(cfg().get("roof_h", 2.0)) * scale_of(h) * grown(h), 0.0)
		var sc := float(cfg().get("roof_scale", 0.55))
		s.y = h.y + off.y
		return Transform3D(base_rot.scaled(Vector3(sc, sc, sc)), h.center() + base_rot * Vector3(off.x, 0, off.z) + Vector3(0, off.y, 0))
	var corners := [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(1, 0, 1), Vector3(-1, 0, 1)]
	var k2 := 0
	for j in i:
		var o2 = h.subs[j]
		if not on_roof(o2):
			k2 += 1
	var r: float = h.size * World.C * 0.5 * float(cfg().get("corner_k", 0.62))
	var pos: Vector3 = corners[k2 % 4] * r
	var sc2: float = float(cfg().get("module_scale", 0.42)) * (1.0 + 0.08 * (s.lvl - 1))
	if s.beh == "storage":
		sc2 = maxf(sc2, float(cfg().get("chest_scale", 0.85)))   # 1.1.20: ящик почти своего размера (раньше сжимался до 0.42)
	s.y = h.y
	return Transform3D(base_rot.scaled(Vector3(sc2, sc2, sc2)), h.center() + base_rot * pos)


## Обновить вид: размер основы, встроенные, платформа, знак уровня, надпись.
func refresh_visual(b) -> void:
	if b.dead:
		return
	f.renderer(b.type).set_xform(b, f._xform(b))
	for i in b.subs.size():
		var s = b.subs[i]
		var r: PartRenderer = f.renderer(s.type)
		r.remove(s)
		r.add(s, sub_xform(b, i))
		r.set_active(s, 1.0 if s.active else 0.0)
	_deco(b)


func _clear_deco(b) -> void:
	if b.deco != null and is_instance_valid(b.deco):
		b.deco.queue_free()
	b.deco = null


func _mat(col: Color, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = 0.6
	m.roughness = 0.45
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emit
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


## Знаки на земле и над зданием: кольцо с огоньками уровня, платформа сборной линии с трубами и надписью.
func _deco(b) -> void:
	_clear_deco(b)
	if b.lvl <= 1 and b.subs.is_empty():
		return
	var root := Node3D.new()
	root.set_meta("no_mirror", true)
	f.add_child(root)
	root.position = b.center()
	b.deco = root
	var acc := DB.color(str(cfg().get("color", "#ffb040")))
	var half: float = b.size * World.C * 0.5
	if not b.subs.is_empty():
		# платформа сборной линии: тёмная плита, жёлто-чёрные края, трубы от встроенных к основе
		var w: float = b.size * World.C * float(cfg().get("platform_k", 1.25))
		_box(root, Vector3(w, 0.14, w), Vector3(0, 0.07, 0), _mat(Color(0.16, 0.17, 0.2)))
		var stripe := _mat(acc, 0.4)
		var dark := _mat(Color(0.05, 0.05, 0.06))
		var n := 8
		for side in 4:
			for i in n:
				var t := (i + 0.5) / n - 0.5
				var along := Vector3(t * w, 0.16, w * 0.5) if side % 2 == 0 else Vector3(w * 0.5, 0.16, t * w)
				if side >= 2:
					along = -along
					along.y = 0.16
				var sz := Vector3(w / n * 0.98, 0.05, 0.16) if side % 2 == 0 else Vector3(0.16, 0.05, w / n * 0.98)
				_box(root, sz, along, stripe if i % 2 == 0 else dark)
		var pipe := _mat(Color(0.55, 0.6, 0.68))
		for i in b.subs.size():
			var s = b.subs[i]
			if s.beh in ["turret", "light"] or str(s.p("defense", "")) != "":
				continue
			var p: Vector3 = sub_xform(b, i).origin - b.center()
			var mid := p * 0.5
			var ln := Vector2(p.x, p.z).length()
			var pm := _box(root, Vector3(0.18, 0.18, ln), Vector3(mid.x, 0.35, mid.z), pipe)
			pm.rotation.y = atan2(p.x, p.z)
		var lab := Label3D.new()
		lab.text = "СБОРНАЯ ЛИНИЯ\n" + chain_text(b, true)
		lab.font_size = 40
		lab.pixel_size = 0.00042 * float(cfg().get("label_size", 1.0))
		lab.fixed_size = true   # одинаковый размер на экране вблизи и издалека
		lab.outline_size = 12
		lab.modulate = Color(0.75, 0.92, 1.0)
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lab.no_depth_test = true
		lab.position = Vector3(0, float(cfg().get("roof_h", 2.0)) * scale_of(b) * grown(b) + 1.4, 0)
		lab.visibility_range_end = float(cfg().get("label_dist", 35.0))
		root.add_child(lab)
	if b.lvl > 1:
		# кольцо уровня: светящиеся огоньки по числу уровней
		var ring_r: float = half * 1.05
		var dim := _mat(Color(0.12, 0.12, 0.14))
		var lit := _mat(acc, 2.5)
		var pips := max_level()
		for i in pips:
			var a := TAU * i / pips
			var on: bool = i < b.lvl
			var pm := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.13
			cm.bottom_radius = 0.16
			cm.height = 0.12 if not on else 0.22
			pm.mesh = cm
			pm.material_override = lit if on else dim
			pm.position = Vector3(cos(a) * ring_r, 0.1, sin(a) * ring_r)
			root.add_child(pm)
		var badge := Label3D.new()
		badge.text = "×%s · ОБЪЕДИНЕНИЕ %d" % [_num(b.mult), b.lvl]
		badge.font_size = 44
		badge.pixel_size = 0.00045 * float(cfg().get("label_size", 1.0))
		badge.fixed_size = true
		badge.outline_size = 14
		badge.modulate = acc
		badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		badge.no_depth_test = true
		badge.position = Vector3(0, 2.6 * scale_of(b) + (0.5 if not b.subs.is_empty() else 0.0), 0)
		badge.visibility_range_end = float(cfg().get("label_dist", 35.0))
		root.add_child(badge)


# ---------------------------------------------------------------- сохранение

func save_subs(h) -> Array:
	var out := []
	for s in h.subs:
		var e := {"t": s.type, "lvl": s.lvl, "r": s.recipe}
		for k in ["inv", "out", "fuel"]:
			var inv: Inventory = s.get(k)
			if inv != null:
				e[k] = inv.to_array()
		if s.crafting != "":
			e["crafting"] = s.crafting
			e["prog"] = s.prog
		if s.fuel_t > 0.0:
			e["fuel_t"] = s.fuel_t
		if s.paid is Dictionary:
			e["paid"] = s.paid
		if not s.cfg.is_empty():
			e["cfg"] = s.cfg.duplicate(true)
		if not s.bstate.is_empty():
			e["bs"] = s.bstate.duplicate(true)   # 1.1.20 B14-6: владелец и состояние встроенного
		out.append(e)
	return out


## Восстановить встроенные из сохранения: создаём здание как обычно и сразу встраиваем.
func load_subs(h, arr: Array) -> void:
	for e in arr:
		var t := str(e.get("t", ""))
		if DB.building(t).is_empty():
			continue
		var s = f.make_virtual(t, h)
		s.recipe = str(e.get("r", s.recipe))
		for k in ["inv", "out", "fuel"]:
			var inv: Inventory = s.get(k)
			if inv != null and e.has(k):
				inv.from_array(e[k])
		s.crafting = str(e.get("crafting", ""))
		s.prog = float(e.get("prog", 0.0))
		s.fuel_t = float(e.get("fuel_t", 0.0))
		if e.get("paid") is Dictionary:
			s.paid = e.paid
		if e.get("cfg") is Dictionary:
			s.cfg = e.cfg.duplicate(true)
		if e.get("bs") is Dictionary:
			s.bstate = e.bs.duplicate(true)
		elif h.bstate.has("owner"):
			s.bstate["owner"] = h.bstate.owner
		_attach(h, s)
		var lv := int(e.get("lvl", 1))
		if lv > 1:
			s.lvl = lv
			s.mult = mult_for(lv)
			# A16-9: ячейки по уровню (развалины восстанавливаются без содержимого — иначе размер по умолчанию)
			if s.beh == "storage" and s.inv != null:
				s.inv.resize(maxi(s.inv.size(), int(s.p("slots", 16)) * lv))
			if s.beh in ["miner", "crafter"] and s.out != null:
				s.out.resize(maxi(s.out.size(), (2 if s.beh == "miner" else int(s.p("out_slots", 2))) + lv - 1))
			if s.beh == "crafter" and s.inv != null:
				s.inv.resize(maxi(s.inv.size(), int(s.p("in_slots", 4)) + lv - 1))
	if not h.subs.is_empty():
		if not h in hosts:
			hosts.append(h)
		if h.out != null and h.out.size() < 4:
			h.out.resize(4)
	refresh_visual(h)
