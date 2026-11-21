extends RefCounted
## НПС: торговцы, путники, налётчики и «тени» (днём торгуют, ночью вредят).
## Виды НПС лежат в «Монстры и НПС» (поведение trader, traveler, bandit, infiltrator), группы — в «Группы НПС».
## Приходят по событиям мира вида «visit». Вдали от героя и базы НПС и монстры «спят».

const KINDS := ["trader", "traveler", "bandit", "infiltrator"]

var game
var rep := {}             # группа -> отношение −100..100
var _warned := {}
## 14.7 Память и характер: у каждого НПС имя, характер и память о герое (встречи, покупки, подарки, обиды).
var people := {}          # id -> {name, type, char, visits, bought, sold, gifts, hits, rel, last_day, alive, caught}
var fmem := {}            # группа -> {kills, robbed, trades, gifts} — что группа помнит о герое
var _pid_n := 0


func _init(g) -> void:
	game = g


static func factions() -> Dictionary:
	return DB.data.get("factions", {})


func rep_of(f: String) -> int:
	if rep.has(f):
		return int(rep[f])
	return int(factions().get(f, {}).get("start_rep", 0))


func change_rep(f: String, d: int) -> void:
	if f == "" or d == 0:
		return
	rep[f] = clampi(rep_of(f) + d, -100, 100)


## Множитель цен у торговцев группы: друзья продают дешевле.
func price_k(f: String) -> float:
	return clampf(1.0 - rep_of(f) / 250.0, 0.6, 1.4)


## Характеры из «Настройки → Характеры НПС»: id -> запись.
static func characters() -> Dictionary:
	var out := {}
	for c in DB.setting("npc_characters", []):
		if c is Dictionary and str(c.get("id", "")) != "":
			out[str(c.id)] = c
	return out


func person(e) -> Dictionary:
	return people.get(e.person, {}) if e != null else {}


func char_of(e) -> Dictionary:
	var p := person(e)
	return characters().get(str(p.get("char", e.pchar if e != null else "")), {})


## Цена у этого НПС: группа × характер × личное отношение.
func price_for(e) -> float:
	var d: Dictionary = DB.data.enemies.get(e.type, {})
	var k := price_k(str(d.get("faction", "")))
	k *= float(char_of(e).get("price", 1.0))
	k *= clampf(1.0 - float(person(e).get("rel", 0)) / 400.0, 0.75, 1.25)
	return k


func fm(f: String) -> Dictionary:
	if not fmem.has(f):
		fmem[f] = {"kills": 0, "robbed": 0, "trades": 0, "gifts": 0}
	return fmem[f]


func _pick_char(d: Dictionary) -> String:
	var all := characters()
	var ok: Array = []
	for c in d.get("characters", []):
		if all.has(str(c)):
			ok.append(str(c))
	if ok.is_empty():
		for c in all:
			if all[c].get("arrive", "") == "" or str(d.get("behavior", "")) == "bandit":
				ok.append(str(c))
	return "" if ok.is_empty() else str(ok[randi() % ok.size()])


func _pick_name(d: Dictionary) -> String:
	var names: PackedStringArray = str(d.get("names", "")).split("\n", false)
	if names.is_empty():
		names = str(DB.setting("npc_names", "")).split("\n", false)
	return "" if names.is_empty() else names[randi() % names.size()].strip_edges()


## Кто пришёл: знакомый (помнит героя) или новый человек.
func _assign(e, d: Dictionary) -> void:
	if e.npc == "bandit":
		e.pchar = _pick_char(d)
		return
	var present := {}
	for o in game.enemies.list:
		if o.person != "":
			present[o.person] = true
	var known: Array = []
	for pid in people:
		var p: Dictionary = people[pid]
		if p.type == e.type and p.alive and not p.get("caught", false) and not present.has(pid):
			known.append(pid)
	var pid := ""
	if not known.is_empty() and randf() < float(DB.setting("npc_return_chance", 0.6)):
		pid = known[randi() % known.size()]
	else:
		_pid_n += 1
		pid = "p%d" % _pid_n
		people[pid] = {"name": _pick_name(d), "type": e.type, "char": _pick_char(d), "visits": 0, "bought": 0, "sold": 0,
			"gifts": 0, "hits": 0, "rel": 0, "last_day": game.day_n, "alive": true}
		_trim()
	var p: Dictionary = people[pid]
	p.days_away = game.day_n - int(p.get("last_day", game.day_n))
	p.visits = int(p.get("visits", 0)) + 1
	p.last_day = game.day_n
	e.person = pid
	e.pchar = str(p.char)


## Не больше 80 человек в памяти: сначала забываем погибших и давних.
func _trim() -> void:
	if people.size() <= 80:
		return
	var ids := people.keys()
	ids.sort_custom(func(a, b): return (0 if people[a].alive else -100000) + int(people[a].last_day) < (0 if people[b].alive else -100000) + int(people[b].last_day))
	for i in people.size() - 80:
		people.erase(ids[i])


## Реплика по характеру и ситуации: {name}, {visits}, {days}, {bought}, {faction}, {kills}, {robbed}.
func say(e, situation: String) -> String:
	var c := char_of(e)
	var lines: PackedStringArray = str(c.get(situation, "")).split("\n", false)
	if lines.is_empty():
		return ""
	var p := person(e)
	var d: Dictionary = DB.data.enemies.get(e.type, {}) if e != null else {}
	var f := str(d.get("faction", ""))
	var t: String = lines[randi() % lines.size()]
	return t.format({"name": str(p.get("name", d.get("name", ""))), "visits": int(p.get("visits", 1)), "days": int(p.get("days_away", 0)),
		"bought": int(p.get("bought", 0)), "faction": str(factions().get(f, {}).get("name", f)), "kills": int(fm(f).kills), "robbed": int(fm(f).robbed)})


## Приветствие по памяти: первая встреча, снова, друзья, обида.
func greeting(e) -> String:
	var p := person(e)
	if p.is_empty():
		return str(DB.data.enemies.get(e.type, {}).get("greeting", ""))
	var sit := "again"
	if int(p.get("visits", 1)) <= 1 and int(p.get("hits", 0)) == 0:
		sit = "first"
	if int(p.get("rel", 0)) >= 30:
		sit = "friend"
	if int(p.get("hits", 0)) > 0 and int(p.get("rel", 0)) < 10:
		sit = "hurt"
	var t := say(e, sit)
	return t if t != "" else str(DB.data.enemies.get(e.type, {}).get("greeting", ""))


## Отказывается торговать (сильно обижен).
func refuses(e) -> bool:
	var p := person(e)
	return not p.is_empty() and int(p.get("rel", 0)) <= int(char_of(e).get("refuse_below", -100))


func display_name(e) -> String:
	var d: Dictionary = DB.data.enemies.get(e.type, {})
	var p := person(e)
	if p.is_empty() or str(p.get("name", "")) == "":
		return str(d.get("name", e.type))
	return "%s %s" % [str(d.get("name", e.type)), str(p.name)]


## Что НПС помнит о герое (для окна торговли).
func memory_text(e) -> String:
	var p := person(e)
	if p.is_empty():
		return ""
	var c := char_of(e)
	return "Характер: %s · встреч: %d · купили: %d · продали: %d · подарков: %d · обид: %d · личное отношение: %d" % [
		str(c.get("name", "?")), int(p.visits), int(p.bought), int(p.sold), int(p.gifts), int(p.hits), int(p.rel)]


## Герой ударил мирного НПС: обида запоминается, трус убегает.
func on_hurt(e) -> void:
	if e.npc == "" or not e.peaceful or e.npc == "bandit":
		return
	var now := Time.get_ticks_msec() * 0.001
	if now - e.hurt_at < 2.0:
		return
	e.hurt_at = now
	var d: Dictionary = DB.data.enemies.get(e.type, {})
	change_rep(str(d.get("faction", "")), -2)
	var p := person(e)
	if p.is_empty():
		return
	var c := char_of(e)
	p.hits = int(p.hits) + 1
	p.rel = clampi(int(p.rel) - roundi(float(DB.setting("npc_rel_hurt", 12)) * float(c.get("touchy", 1.0))), -100, 100)
	var line := say(e, "hurt")
	if line != "":
		game.notify("%s: «%s»" % [display_name(e), line], Color(1, 0.7, 0.5))
	if bool(c.get("flee", false)) and e.state in ["come", "stay"]:
		var hq = game.factory.hq
		var center: Vector3 = hq.center() if hq else game.player.position
		e.state = "leave"
		e.goal = e.pos + World.delta(center, e.pos).normalized() * 70.0


static func rep_word(r: int) -> String:
	if r >= 50: return "друзья"
	if r >= 15: return "доверяют"
	if r > -15: return "нейтрально"
	if r > -50: return "недовольны"
	return "враги"


func count() -> int:
	var n := 0
	for e in game.enemies.list:
		if e.npc != "":
			n += 1
	return n


## Привести n НПС вида id к базе (или к герою, если штаба нет).
func spawn_visit(id: String, n: int) -> Array:
	var d: Dictionary = DB.data.enemies.get(id, {})
	var out := []
	if d.is_empty() or not str(d.get("behavior", "")) in KINDS:
		return out
	var center: Vector3 = game.factory.hq.center() if game.factory.hq else game.player.position
	var a := randf() * TAU
	var dir := Vector3(cos(a), 0, sin(a))
	var origin := center + dir * 60.0
	var maxn := int(DB.setting("npc_max", 12))
	for i in n:
		if count() >= maxn:
			break
		var p := origin + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4))
		var e = game.enemies.spawn(id, p)
		if e == null:
			continue
		e.state = "come"
		_assign(e, d)
		e.stock = {}
		e.cash = -1
		prepare_stock(e, d)
		var side := dir.rotated(Vector3.UP, PI * 0.5) * randf_range(-10, 10)
		if e.npc == "traveler":
			e.goal = center - dir * 60.0 + side
			e.state = "pass"
		else:
			e.goal = center + dir * randf_range(9.0, 14.0) + side * 0.6
		out.append(e)
	if not out.is_empty() and out[0].npc == "bandit":
		var f := str(d.get("faction", ""))
		var sit := "arrive"
		if int(fm(f).kills) >= int(DB.setting("npc_bandit_revenge_from", 3)):
			sit = "revenge"
		elif int(fm(f).robbed) > 0 and randf() < 0.5:
			sit = "rich"
		var line := say(out[0], sit)
		if line == "":
			line = say(out[0], "arrive")
		if line != "":
			game.notify(line, Color(1, 0.5, 0.4))
		if sit == "revenge":
			for e in out:
				e.hp *= 1.3
				e.maxhp *= 1.3
	return out


## Своё поведение НПС. true — движение уже посчитано (обычная логика монстра не нужна).
func update_npc(e, delta: float) -> bool:
	var d: Dictionary = DB.data.enemies.get(e.type, {})
	var hq = game.factory.hq
	var center: Vector3 = hq.center() if hq else game.player.position
	var to_player: float = World.dist(e.pos, game.player.position)
	if e.peaceful and to_player < 7.0 and e.said == 0:
		e.said = 1
		var gr := greeting(e)
		if gr != "":
			game.notify("%s: «%s»" % [display_name(e), gr], Color(0.75, 0.9, 1.0))
	if e.talk_t > 0.0 and e.peaceful:
		# 1.7: во время разговора НПС стоит (раньше уходил, и окно торговли закрывалось)
		e.talk_t -= delta
		e.moving = false
		var tt := World.delta(e.pos, e.talk_to)
		e.yaw = lerp_angle(e.yaw, atan2(-tt.z, tt.x), minf(1.0, delta * 6.0))
		return true
	match e.npc:
		"traveler":
			if _walk(e, e.goal, e.speed * 0.6, delta):
				_despawn(e)
			return true
		"trader", "infiltrator":
			if e.npc == "infiltrator" and game.is_night() and e.state in ["stay", "come"]:
				e.state = "sneak"
				e.target = null
			match e.state:
				"come":
					if _walk(e, e.goal, e.speed * 0.7, delta):
						e.state = "stay"
						e.timer = float(d.get("stay", 120))
				"stay":
					e.moving = false
					var to := World.delta(e.pos, game.player.position)
					if to_player < 10.0:
						e.yaw = lerp_angle(e.yaw, atan2(-to.z, to.x), minf(1.0, delta * 5.0))
					e.timer -= delta
					if e.timer <= 0.0:
						e.state = "leave"
						e.goal = e.pos + World.delta(center, e.pos).normalized() * 70.0
				"leave":
					if _walk(e, e.goal, e.speed * 0.8, delta):
						_despawn(e)
				"sneak":
					if not game.is_night():
						e.state = "leave"
						e.goal = e.pos + World.delta(center, e.pos).normalized() * 70.0
						return true
					_sneak(e, delta)
			return true
		"bandit":
			var loot := 0
			for k in e.loot:
				loot += int(e.loot[k])
			if loot >= 12 or e.state == "flee":
				if e.state != "flee":
					e.state = "flee"
					e.goal = e.pos + World.delta(center, e.pos).normalized() * 80.0
					e.target = null
				if _walk(e, e.goal, e.speed, delta):
					if loot > 0:
						game.notify("Налётчики ушли с добычей", Color(1, 0.6, 0.4))
					_despawn(e)
				return true
			# ищем склад; на героя кидается обычная логика, если он рядом
			if e.retarget <= 0.0 and (e.target == null or e.target == game.player or (e.target.inv == null)) and to_player > 10.0:
				var s = _storage_near(e.pos)
				if s != null:
					e.target = s
					e.retarget = 2.0
			return false
	return false


## «Тень» ночью: подбирается к ящикам и лентам, ворует и ломает.
func _sneak(e, delta: float) -> void:
	e.timer -= delta
	if e.target == null or e.target.dead:
		var cands := []
		for b in game.factory.all:
			if b != game.factory.hq and (b.beh in ["belt", "storage", "pole"] or b.inv != null) and World.dist(b.center(), e.pos) < 60.0:
				cands.append(b)
		if cands.is_empty():
			e.state = "leave"
			e.goal = e.pos + Vector3(60, 0, 0)
			return
		e.target = cands[randi() % cands.size()]
	var tp: Vector3 = e.target.center()
	if _walk(e, tp, e.speed * 0.6, delta, 1.4 + e.target.size):
		if e.timer > 0.0:
			return
		e.timer = 3.0
		var b = e.target
		if not e.revealed:
			e.revealed = true
			e.peaceful = false   # теперь его видят турели
			if not person(e).is_empty():
				person(e).caught = true
			game.notify("%s вредит базе! Подозрительный гость оказался из «%s»" % [DB.data.enemies.get(e.type, {}).get("name", e.type),
				factions().get(str(DB.data.enemies.get(e.type, {}).get("faction", "")), {}).get("name", "?")], Color(1, 0.45, 0.8))
		if b.inv != null and b.inv.first_item() != "":
			var it: String = b.inv.first_item()
			var n := mini(3, b.inv.count(it))
			b.inv.remove(it, n)
			e.loot[it] = int(e.loot.get(it, 0)) + n
		else:
			game.factory.damage(b, 35.0)
			if game.factory.wire_count(b) > 0:
				game.factory.unwire(b)
		e.target = null


## Удар бандита по складу — грабёж вместо разрушения. true — удар обработан.
func on_attack(e) -> bool:
	if e.npc != "bandit" or e.target == null or e.target == game.player:
		return false
	var b = e.target
	if b.inv == null or b.inv.first_item() == "":
		return false
	var it: String = b.inv.first_item()
	var n := mini(3, b.inv.count(it))
	b.inv.remove(it, n)
	e.loot[it] = int(e.loot.get(it, 0)) + n
	var fr := str(DB.data.enemies.get(e.type, {}).get("faction", ""))
	fm(fr).robbed = int(fm(fr).robbed) + n
	if not _warned.has("rob"):
		_warned["rob"] = true
		game.notify("Налётчики грабят склад!", Color(1, 0.45, 0.35))
	return true


func on_killed(e) -> void:
	var d: Dictionary = DB.data.enemies.get(e.type, {})
	change_rep(str(d.get("faction", "")), int(d.get("rep_kill", 0)))
	fm(str(d.get("faction", ""))).kills = int(fm(str(d.get("faction", ""))).kills) + 1
	if not person(e).is_empty():
		person(e).alive = false
	for it in e.loot:
		game.drops.spawn(it, int(e.loot[it]), e.pos + Vector3(randf_range(-0.6, 0.6), 0.8, randf_range(-0.6, 0.6)))


func _storage_near(p: Vector3):
	var best = null
	var bd := 90.0
	for b in game.factory.all:
		if b.inv != null and b.inv.first_item() != "" and (b.beh in ["storage", "hq"]):
			var dd := World.dist(p, b.center())
			if dd < bd:
				bd = dd
				best = b
	return best


func _walk(e, goal: Vector3, sp: float, delta: float, reach := 1.0) -> bool:
	var to := World.delta(e.pos, goal)
	to.y = 0.0
	var dist := to.length()
	if dist <= reach:
		e.moving = false
		return true
	var dir := to / dist
	var step := dir
	if game.enemies._wet(World.world_to_cell(e.pos + dir * 1.2)):
		step = Vector3.ZERO
		for ang in [0.8, -0.8, 1.6, -1.6, 2.4, -2.4]:
			var d2 := dir.rotated(Vector3.UP, ang)
			if not game.enemies._wet(World.world_to_cell(e.pos + d2 * 1.2)):
				step = d2
				break
	var blk = game.factory.grid.get(World.world_to_cell(e.pos + step * 0.9))
	if blk != null and not game.factory.walkable(blk) and blk != e.target:
		step = step.rotated(Vector3.UP, 1.2)
	e.pos += step * sp * delta
	e.moving = step != Vector3.ZERO
	if e.moving:
		e.yaw = lerp_angle(e.yaw, atan2(-step.z, step.x), minf(1.0, delta * 8.0))
	return false


func _despawn(e) -> void:
	game.enemies.remove_silent(e)


# ---------------------------------------------------------------- торговля с НПС (окно «npc»)

## С кем говорить по E (1.3): с тем, на кого наведён курсор (рядом с героем), или с тем, кто стоит вплотную —
## но не когда курсор на здании: тогда E открывает здание.
func near_trader():
	var best = null
	var bd := INF
	var on_building: bool = game.factory.building_at(game.hover_cell) != null
	var close := float(DB.setting("npc_talk_close", 2.5))
	var reach := float(DB.setting("npc_talk_reach", 7.0))
	for e in game.enemies.list:
		if e.npc != "" and e.peaceful and not DB.data.enemies.get(e.type, {}).get("goods", []).is_empty():
			var d := World.dist(e.pos, game.player.position)
			var aimed: bool = World.dist(e.pos, game.hover_point) < 1.6 and d < reach
			if not aimed and (d > close or on_building):
				continue
			var score := d - (100.0 if aimed else 0.0)
			if score < bd:
				bd = score
				best = e
	return best


## 1.7: окно разговора открыто — НПС ждёт. У гостя просьба уходит хозяину (НПС двигает он).
var _talk_sent := 0.0
func talking(e) -> void:
	e.talk_t = 1.0
	e.talk_to = game.player.position
	if Net.is_client() and e.nid > 0:
		var now := Time.get_ticks_msec() / 1000.0
		if now - _talk_sent > 0.4:
			_talk_sent = now
			Net._self().npc_talk(e)


func good_price(e, i: int) -> int:
	var d: Dictionary = DB.data.enemies.get(e.type, {})
	var g: Dictionary = d.goods[i]
	return maxi(1, roundi(float(g.get("price", 1)) * price_for(e)))


func prepare_stock(e, d: Dictionary) -> void:
	var goods: Array = d.get("goods", [])
	if goods.is_empty():
		return
	var rotation := int(game.day_n) + int(person(e).get("visits", 0)) + absi(hash(e.type))
	var featured := posmod(rotation, goods.size())
	var offered := maxi(1, ceili(goods.size() * 0.7))
	for i in offered:
		var index := posmod(featured + i, goods.size())
		var quantity := maxi(1, int(goods[index].get("n", 1)))
		e.stock[index] = quantity + (ceili(quantity * .35) if i == 0 else 0)


func client_stock(e, d: Dictionary) -> void:
	prepare_stock(e, d)


func buy_from(e, i: int) -> bool:
	if Net.is_client() and e.nid > 0 and not Net._self().applying:
		# 1.1.15: у гостя сделка идёт через хозяина (товар и кредиты — у него; раньше покупка не работала)
		game.cmd("npc_trade", {"nid": e.nid, "kind": "buy", "i": i})
		if int(e.stock.get(i, 0)) > 0:
			e.stock[i] = int(e.stock[i]) - 1
		return true
	var d: Dictionary = DB.data.enemies.get(e.type, {})
	if i < 0 or i >= d.get("goods", []).size() or int(e.stock.get(i, 0)) <= 0 or refuses(e):
		return false
	var pr := good_price(e, i)
	if game.credits < pr:
		game.notify("Не хватает кредитов", Color(1, 0.6, 0.4))
		return false
	game.credits -= pr
	e.stock[i] = int(e.stock[i]) - 1
	game.factory.give_player(str(d.goods[i].item), 1)
	change_rep(str(d.get("faction", "")), int(DB.setting("rep_trade", 1)))
	_remember_trade(e, "bought")
	game.sfx.play_ui("coin")
	return true


func sell_price_to(e, item: String) -> int:
	var d: Dictionary = DB.data.enemies.get(e.type, {})
	return maxi(1, roundi(float(DB.item(item).get("price", 1)) * 0.7 / price_for(e)))


## Продать НПС n штук (1.1.8: «1», «50», «всё»; n < 0 — всё). При экономике 1.1.8 у торговца ограниченный кошелёк.
func sell_to(e, item: String, n := 1) -> bool:
	if Net.is_client() and e.nid > 0 and not Net._self().applying:
		# 1.1.15: у гостя — через хозяина (раньше предметы пропадали, а кредиты откатывались)
		game.cmd("npc_trade", {"nid": e.nid, "kind": "sell", "item": item, "n": n})
		return true
	var d: Dictionary = DB.data.enemies.get(e.type, {})
	if not item in d.get("buys", []) or game.player.inv.count(item) <= 0 or refuses(e):
		return false
	var have: int = game.player.inv.count(item)
	n = have if n < 0 else mini(n, have)
	var pr := sell_price_to(e, item)
	if Blocks.econ_on():
		var cash := cash_of(e)
		if cash < pr:
			game.notify("У торговца кончились кредиты", Color(1, 0.6, 0.4))
			return false
		n = mini(n, cash / maxi(1, pr))
		e.cash = cash - n * pr
	if n <= 0:
		return false
	game.player.inv.remove(item, n)
	game.credits += pr * n
	change_rep(str(d.get("faction", "")), int(DB.setting("rep_trade", 1)) * mini(n, 5))
	_remember_trade(e, "sold")
	game.sfx.play_ui("coin")
	return true


## 1.1.8: сколько кредитов у торговца с собой (на всё, что он скупает за визит).
func cash_of(e) -> int:
	if int(e.cash) < 0:
		e.cash = int(Blocks.econ().get("npc_cash", 300))
	return int(e.cash)


## Подарок: предмет из рук героя, отношение растёт от его цены.
func gift(e, item: String) -> int:
	if item == "" or game.player.inv.count(item) <= 0:
		return 0
	var d: Dictionary = DB.data.enemies.get(e.type, {})
	var faction := str(d.get("faction", ""))
	var memory := fm(faction)
	var gifts: Dictionary = memory.get("gift_history", {})
	var count := int(gifts.get(item, 0))
	var preference := 2 if item in d.get("buys", []) else 1
	var base := maxi(1, int(DB.item(item).get("price", 1)) / maxi(1, int(DB.setting("rep_gift_per", 10))))
	var up := int(preference * base / (1 + count * count))
	if up < 1:
		game.notify("Торговец уже получил достаточно таких подарков", Color.LIGHT_GRAY)
		return 0
	if Net.is_client() and e.nid > 0 and not Net._self().applying:
		game.cmd("npc_trade", {"nid": e.nid, "kind": "gift", "item": item})
		return up
	game.player.inv.remove(item, 1)
	gifts[item] = count + 1
	memory["gift_history"] = gifts
	change_rep(str(d.get("faction", "")), up)
	fm(str(d.get("faction", ""))).gifts = int(fm(str(d.get("faction", ""))).gifts) + 1
	var p := person(e)
	if not p.is_empty():
		p.gifts = int(p.gifts) + 1
		p.rel = clampi(int(p.rel) + maxi(1, roundi(up * 2.0 * float(char_of(e).get("gift_k", 1.0)))), -100, 100)
	return up


func _remember_trade(e, key: String) -> void:
	var f := str(DB.data.enemies.get(e.type, {}).get("faction", ""))
	fm(f).trades = int(fm(f).trades) + 1
	var p := person(e)
	if p.is_empty():
		return
	p[key] = int(p.get(key, 0)) + 1
	if (int(p.bought) + int(p.sold)) % 5 == 0:
		p.rel = clampi(int(p.rel) + 3, -100, 100)


func next_line(e) -> String:
	var d: Dictionary = DB.data.enemies.get(e.type, {})
	if refuses(e):
		var rf := say(e, "refuse")
		if rf != "":
			return rf
	e.said += 1
	if e.said <= 2:
		return greeting(e)
	var lines: PackedStringArray = str(d.get("lines", "")).split("\n", false)
	lines.append_array(str(char_of(e).get("talk", "")).split("\n", false))
	if lines.is_empty():
		return greeting(e)
	return lines[e.said % lines.size()]


func to_dict() -> Dictionary:
	return {"rep": rep.duplicate(), "people": people.duplicate(true), "fmem": fmem.duplicate(true), "pid_n": _pid_n}


func load_dict(d: Dictionary) -> void:
	rep = d.get("rep", {}).duplicate()
	people = d.get("people", {}).duplicate(true)
	fmem = d.get("fmem", {}).duplicate(true)
	_pid_n = int(d.get("pid_n", people.size()))
