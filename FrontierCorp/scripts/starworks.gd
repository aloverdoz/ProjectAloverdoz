class_name Starworks
extends RefCounted
## 14.23: «Звёздный патч» — орбитальная торговля с НЛО, инженерный стол (узоры 4×4 → улучшенные рецепты),
## мегапроект «Звёздные врата».
## НЛО: к каждой посадочной площадке прилетает по расписанию, забирает из «Отправки» сколько унесёт
## (стоимость = цена предмета × «Доля при продаже»), а взамен по сегодняшнему курсу покупает заказанную экзотику
## и привозит её в следующий прилёт. Курс каждой экзотики меняется каждый игровой день (случайное блуждание,
## одинаковое для всех игроков в мире с тем же зерном).
## Правится: «Настройки → НЛО-торговля», «Настройки → Узоры инженерного стола», «Настройки → Мегапроект».

var game
var ufos := {}          # площадка → Node3D летающей тарелки
var _price_cache := {}  # "id|day" → множитель
var _t := 0.0


func _init(g) -> void:
	game = g


static func ucfg() -> Dictionary:
	return DB.setting("ufo", {})


func enabled() -> bool:
	return bool(ucfg().get("enabled", true)) and game.module("ufo")


static func is_pad(b) -> bool:
	return b != null and bool(b.p("ufo_pad", false))


static func goods() -> Dictionary:
	return ucfg().get("goods", {})


func day() -> int:
	return int(game.day_n)


## Множитель цены экзотики на день: случайное блуждание от 1.0.
func swing(id: String, d: int) -> float:
	var key := "%s|%d" % [id, d]
	if _price_cache.has(key):
		return _price_cache[key]
	var c := ucfg()
	var lo := float(c.get("swing_min", 0.5))
	var hi := float(c.get("swing_max", 1.6))
	var v := 1.0 if d <= 1 else swing(id, d - 1)
	if d > 1:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%s|%d|%d" % [id, d, int(game.world.used_seed) if game.world else 0])
		v = clampf(v * (1.0 + rng.randf_range(-1.0, 1.0) * float(c.get("step", 0.35))), lo, hi)
	_price_cache[key] = v
	return v


## Сколько стоит 1 штука экзотики сегодня (в кредитах-ценности).
func price(id: String, d := -1) -> float:
	var g: Dictionary = goods().get(id, {})
	return float(g.get("value", DB.item(id).get("price", 1))) * swing(id, day() if d < 0 else d)


## Курс для показа: «Гелий-3 = 1000 микросхем».
func quote(id: String, d := -1) -> Array:
	var q := str(goods().get(id, {}).get("quote", "circuit"))
	var qv := maxf(1.0, float(DB.item(q).get("price", 1)))
	return [q, maxi(1, roundi(price(id, d) / qv))]


## Во сколько НЛО оценит наш товар.
func sell_value(id: String) -> float:
	if goods().has(id):
		return minf(price(id) * float(ucfg().get("sell_k", 0.6)), Blocks.shop_sell_cap(id))
	# A-3 r11: товар магазина утилизации — не дороже его купонов (ТВЭЛ за 15 купонов НЛО ценил в 5299)
	return minf(float(DB.item(id).get("price", 1)) * float(ucfg().get("sell_k", 0.6)), Blocks.shop_sell_cap(id))


static func st(b) -> Dictionary:
	var s: Dictionary = b.bstate
	if not s.has("ufo_t"):
		s["ufo_t"] = float(ucfg().get("first", 120.0))
		s["phase"] = "away"      # away, down, landed, up
		s["anim"] = 0.0
		s["balance"] = 0.0
		s["orders"] = []         # [{id, n}]
		s["carry"] = {}          # что везёт в следующий прилёт
		s["log"] = []
	return s


func setup(b) -> void:
	if b.out == null:
		b.out = Inventory.new(int(b.p("slots", 24)))   # «Получено»: доставленная экзотика (ленты забирают отсюда)
	st(b)


func update(dt: float) -> void:
	_t += dt
	if _t >= 1.0 and not Net.is_client():
		_t = 0.0
		_megaprojects()
	if not enabled():
		for b in ufos.keys():
			_drop_ufo(b)
		return
	var f = game.factory
	for b in f.having("ufo_pad"):
		if b.dead:
			continue
		if b.out == null:
			setup(b)
		_pad(b, dt)
	for b in ufos.keys():
		if not is_instance_valid(b) or b.dead:
			_drop_ufo(b)


func _pad(b, dt: float) -> void:
	var s := st(b)
	var c := ucfg()
	match str(s.phase):
		"away":
			s.ufo_t = float(s.ufo_t) - dt
			if float(s.ufo_t) <= 0.0:
				s.phase = "down"
				s.anim = 0.0
				if game.sfx:
					game.sfx.play(str(c.get("sound", "omen")), b.center())
				game.notify_once("ufo_come", "НЛО спускается к посадочной площадке!", Color(0.6, 1, 1))
		"down":
			s.anim = float(s.anim) + dt / 4.0
			if float(s.anim) >= 1.0:
				s.phase = "landed"
				s.anim = 0.0
				if not Net.is_client():
					trade(b)
		"landed":
			s.anim = float(s.anim) + dt
			if float(s.anim) >= float(c.get("stay", 20.0)):
				s.phase = "up"
				s.anim = 0.0
		"up":
			s.anim = float(s.anim) + dt / 4.0
			if float(s.anim) >= 1.0:
				s.phase = "away"
				s.anim = 0.0
				s.ufo_t = float(c.get("interval", 420.0))
	_visual(b, s)


## Посадка: выгрузить привезённое, забрать товары, купить заказ по сегодняшнему курсу (привезёт в следующий раз).
func trade(b) -> Dictionary:
	var s := st(b)
	var c := ucfg()
	var got := {}
	# 1) выгрузка
	var carry: Dictionary = s.carry
	for id in carry.keys():
		var n := int(carry[id])
		var left: int = b.out.add(id, n)
		if n - left > 0:
			got[id] = n - left
		if left > 0:
			carry[id] = left
		else:
			carry.erase(id)
	# 2) забирает товары
	var cap := int(c.get("capacity", 400))
	var took := {}
	var val := 0.0
	var tot: Dictionary = b.inv.totals()
	for id in tot:
		if cap <= 0:
			break
		var k := mini(int(tot[id]), cap)
		b.inv.remove(id, k)
		cap -= k
		took[id] = int(took.get(id, 0)) + k
		val += sell_value(id) * k
	s.balance = float(s.balance) + val
	# 3) покупает заказ
	var bought := {}
	for o in s.orders:
		var id := str(o.get("id", ""))
		var want := int(o.get("n", 0))
		if id == "" or want <= 0:
			continue
		var p := price(id)
		var n := mini(want, int(floorf(float(s.balance) / maxf(0.01, p))))
		if n <= 0:
			continue
		s.balance = float(s.balance) - n * p
		carry[id] = int(carry.get(id, 0)) + n
		bought[id] = n
		if bool(o.get("once", false)):
			o["n"] = want - n
	s.carry = carry
	var lg: Array = s.log
	lg.push_front({"day": day(), "got": got, "took": took, "bought": bought})
	while lg.size() > 6:
		lg.pop_back()
	if not got.is_empty() or not took.is_empty():
		game.notify("НЛО: выгрузил %s, забрал %s. Заказ привезёт в следующий раз." % [_list(got), _list(took)], Color(0.6, 1, 1))
	return {"got": got, "took": took, "bought": bought}


static func _list(d: Dictionary) -> String:
	if d.is_empty():
		return "ничего"
	var a := []
	for id in d:
		a.append("%s ×%d" % [DB.item_name(id), int(d[id])])
	return ", ".join(a)


func _visual(b, s: Dictionary) -> void:
	if not game.is_inside_tree():
		return
	var ph := str(s.phase)
	if ph == "away":
		_drop_ufo(b)
		return
	var n: Node3D = ufos.get(b)
	if n == null:
		n = ModelLib.make_node("ufo")
		game.add_child(n)
		var beam := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.8
		cm.bottom_radius = 2.4
		cm.height = 1.0
		beam.mesh = cm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = DB.color(str(ucfg().get("beam_color", "#8ff0ff")))
		mat.albedo_color.a = 0.25
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		beam.material_override = mat
		beam.name = "beam"
		n.add_child(beam)
		ufos[b] = n
	var hgt := float(ucfg().get("height", 40.0))
	var low := 6.0
	var y := low
	var a := float(s.anim)
	if ph == "down":
		y = lerpf(hgt, low, ease(a, 0.4))
	elif ph == "up":
		y = lerpf(low, hgt, ease(a, 2.2))
	var base: Vector3 = b.center()
	n.position = base + Vector3(0, y, 0)
	n.rotation.y += 0.02
	var beam_n: MeshInstance3D = n.get_node_or_null("beam")
	if beam_n:
		beam_n.visible = ph == "landed"
		beam_n.scale = Vector3(1, y - 0.5, 1)
		beam_n.position = Vector3(0, -(y - 0.5) * 0.5, 0)


func _drop_ufo(b) -> void:
	var n = ufos.get(b)
	if n != null and is_instance_valid(n):
		n.queue_free()
	ufos.erase(b)


func eta_text(b) -> String:
	var s := st(b)
	match str(s.phase):
		"away":
			return "НЛО прилетит через %d с" % ceili(float(s.ufo_t))
		"down":
			return "НЛО садится…"
		"landed":
			return "НЛО на площадке (улетит через %d с)" % ceili(float(ucfg().get("stay", 20.0)) - float(s.anim))
	return "НЛО улетает…"


# ---------------------------------------------------------------- инженерный стол

static func pcfg() -> Dictionary:
	return DB.setting("patterns", {})


static func patterns() -> Array:
	return pcfg().get("list", [])


static func pattern(id: String) -> Dictionary:
	for p in patterns():
		if str(p.get("id", "")) == id:
			return p
	return {}


## Сетка узора 4×4 → массив 16 id предметов ("" — пусто).
static func pattern_cells(p: Dictionary) -> Array:
	var out := []
	var g: Array = p.get("grid", [])
	var key: Dictionary = p.get("key", {})
	for r in 4:
		var row := str(g[r]) if r < g.size() else ""
		for c in 4:
			var ch := row.substr(c, 1) if c < row.length() else "."
			out.append(str(key.get(ch, "")) if ch != "." else "")
	return out


## Узор, повёрнутый на 0/90/180/270° и зеркальный: все 8 вариантов (узор можно класть как угодно).
static func variants(p: Dictionary) -> Array:
	var base := pattern_cells(p)
	var out := []
	var cur := base
	for m in 2:
		for r in 4:
			if not out.has(cur):
				out.append(cur)
			var rot := []
			rot.resize(16)
			for i in 4:
				for j in 4:
					rot[j * 4 + (3 - i)] = cur[i * 4 + j]
			cur = rot
		var mir := []
		mir.resize(16)
		for i in 4:
			for j in 4:
				mir[i * 4 + (3 - j)] = base[i * 4 + j]
		cur = mir
	return out


## Сколько клеток совпало с узором (подсказка «горячо-холодно»), по лучшему повороту.
static func match_count(p: Dictionary, cells: Array) -> int:
	var best := 0
	for want in variants(p):
		var n := 0
		for i in 16:
			if i < cells.size() and str(cells[i]) == str(want[i]) and str(want[i]) != "":
				n += 1
		best = maxi(best, n)
	return best


static func filled(p: Dictionary) -> int:
	var n := 0
	for x in pattern_cells(p):
		if x != "":
			n += 1
	return n


## Проверить раскладку: верный узор открывает рецепт навсегда и тратит по 1 предмету с каждой клетки.
func try_pattern(cells: Array, inv: Inventory) -> String:
	var tc = game.tech
	for p in patterns():
		var want: Array = []
		for v in variants(p):
			var ok := true
			for i in 16:
				if str(cells[i] if i < cells.size() else "") != str(v[i]):
					ok = false
					break
			if ok:
				want = v
				break
		if want.is_empty():
			continue
		var pid := str(p.id)
		if tc.patterns.has(pid):
			return "Этот узор уже открыт: «%s»." % str(p.get("name", pid))
		var need := {}
		for x in want:
			if x != "":
				need[x] = int(need.get(x, 0)) + 1
		for k in need:
			if inv.count(k) < int(need[k]):
				return "Не хватает: %s ×%d" % [DB.item_name(k), int(need[k]) - inv.count(k)]
		for k in need:
			inv.remove(k, int(need[k]))
		tc.patterns[pid] = true
		tc.refresh_locks()
		DB.revision += 1
		var rn := str(DB.data.recipes.get(str(p.get("recipe", "")), {}).get("name", p.get("recipe", "")))
		game.notify("Узор «%s» собран! Открыт улучшенный рецепт: %s" % [str(p.get("name", pid)), rn], Color(1, 0.85, 0.4))
		if game.sfx:
			game.sfx.play("coin", game.player.position)
		return ""
	return "Такого узора нет. Смотрите на подсказки: сколько клеток совпало."


# ---------------------------------------------------------------- мегапроект

static func mcfg() -> Dictionary:
	return DB.setting("megaproject", {})


static func is_mega(b) -> bool:
	return b != null and bool(b.p("megaproject", false))


static func stage(b) -> int:
	return int(b.bstate.get("stage", 0))


static func stages() -> Array:
	return mcfg().get("stages", [])


## Сдача: всё, что нужно этапу, переносится из склада врат; этап закрыт — следующий.
func _megaprojects() -> void:
	for b in game.factory.all:
		if b.dead or not is_mega(b) or b.inv == null:
			continue
		if b.type == "orbital_elevator":
			_service_elevator(b)
			continue
		var i := stage(b)
		if i >= stages().size():
			continue
		var need: Dictionary = stages()[i].get("need", {})
		var have: Dictionary = b.bstate.get("have", {})
		var all_done := true
		for k in need:
			var miss := int(need[k]) - int(have.get(k, 0))
			if miss > 0:
				var t := mini(miss, b.inv.count(k))
				if t > 0:
					b.inv.remove(k, t)
					have[k] = int(have.get(k, 0)) + t
					miss -= t
			if miss > 0:
				all_done = false
		b.bstate["have"] = have
		if all_done:
			b.bstate["stage"] = i + 1
			b.bstate["have"] = {}
			game.notify("Звёздные врата: этап «%s» завершён!" % str(stages()[i].get("name", "")), Color(1, 0.85, 0.4))
			if i + 1 >= stages().size():
				game.add_credits(int(mcfg().get("reward", 50000)), true)
				game.notify("ЗВЁЗДНЫЕ ВРАТА ОТКРЫТЫ! Ваш завод — легенда галактики.", Color(1, 0.9, 0.5))
				if bool(mcfg().get("victory", true)) and game.has_method("win"):
					game.win()


func mega_text(b) -> String:
	if b.type == "orbital_elevator":
		return orbital_status(b)
	var i := stage(b)
	if i >= stages().size():
		return "[color=#ffd36a]Врата открыты![/color]"
	var sg: Dictionary = stages()[i]
	var t := "Этап %d из %d: [b]%s[/b]\n" % [i + 1, stages().size(), str(sg.get("name", ""))]
	var have: Dictionary = b.bstate.get("have", {})
	for k in sg.get("need", {}):
		t += "%s: %d / %d\n" % [DB.item_name(k), int(have.get(k, 0)), int(sg.need[k])]
	return t.strip_edges()

func place_elevator() -> void:
	var w = game.world
	var rng := RandomNumberGenerator.new()
	rng.seed = int(w.used_seed) ^ 0x72a21
	var best := Vector2i(-1, -1)
	var score := INF
	for attempt in 400:
		var a := rng.randf() * TAU
		var distance := rng.randf_range(0.22, 0.39) * float(w.W)
		var cell := World.wc(w.center + Vector2i(roundi(cos(a) * distance), roundi(sin(a) * distance)))
		var cells: Array = game.factory.footprint("orbital_elevator", cell)
		if cells.any(func(c): return not w.in_bounds(c) or w.water_at(c) or w.deposit.has(c) or game.factory.grid.has(c) or w.nest_cells.has(c)):
			continue
		var heights: Vector2 = w.ground_range(cells)
		var variation := heights.y - heights.x
		if variation < score:
			score = variation
			best = cell
		if variation < 0.32:
			break
	if best.x >= 0:
		game.factory.place("orbital_elevator", best, rng.randi_range(0, 3))


func orbital_order(b) -> Dictionary:
	var config: Dictionary = DB.setting("orbital_terminal", {})
	var repairs: Array = config.get("repair", [])
	if stage(b) < repairs.size():
		return repairs[stage(b)]
	var missions: Array = config.get("missions", [])
	var selected := int(b.bstate.get("mission", -1))
	return missions[selected] if selected >= 0 and selected < missions.size() else {}


func _service_elevator(b) -> void:
	if b.net < 0 or game.factory.sat_c(b) < 0.99 or not b.bstate.get("surveyed", false):
		return
	var order := orbital_order(b)
	if order.is_empty():
		return
	var have: Dictionary = b.bstate.get("have", {})
	var ready := true
	for item in order.need:
		var missing := int(order.need[item]) - int(have.get(item, 0))
		if missing > 0:
			have[item] = int(have.get(item, 0)) + b.inv.take_up_to(item, missing)
		ready = ready and int(have.get(item, 0)) >= int(order.need[item])
	b.bstate["have"] = have
	if ready:
		b.bstate["have"] = {}
		if order.has("credits"):
			b.bstate["mission"] = -1
			b.bstate["shipments"] = int(b.bstate.get("shipments", 0)) + 1
			game.add_credits(int(order.credits), true)
			game.add_xp(int(order.xp))
		else:
			b.bstate["stage"] = stage(b) + 1
		game.notify("Орбитальный лифт · " + str(order.name) + " — завершено", Color.LIGHT_BLUE)
		if game.hud.bld == b:
			game.hud.open_building(b)


func orbital_status(b) -> String:
	if not b.bstate.get("surveyed", false):
		return "Обнаружен аварийный маяк. Обследуйте терминал, чтобы получить ведомость ремонта."
	var order := orbital_order(b)
	if order.is_empty():
		return "Терминал в строю. Завершено поставок: %d." % int(b.bstate.get("shipments", 0))
	var text := str(order.name) + (" · %d кр" % int(order.credits) if order.has("credits") else "")
	for item in order.need:
		text += "\n%s    %d / %d" % [DB.item_name(item), int(b.bstate.get("have", {}).get(item, 0)), int(order.need[item])]
	if b.net < 0 or game.factory.sat_c(b) < 0.99:
		text += "\nТерминалу требуется бесперебойное питание."
	return text
