class_name Progress17
extends RefCounted
## 17.10: механики, которые затягивают.
##  • Мастерство машины: каждая машина и бур копят сделанное; на порогах (по умолчанию 200 / 1000 / 5000) получают
##    уровень мастерства I–III: +5% скорости за уровень. Над машиной загорается звёздочка, в окне — счётчик до следующего.
##  • Связка: машина работает на 10% быстрее за каждого соседа (до 2), который делает ей сырьё или берёт её продукт —
##    стройте цепочки плотно, «завод к заводу».
##  • Рекорды производства: за 100 / 1000 / 10000 сделанных штук каждого предмета — награда деньгами (купоны — только из утилизатора),
##    чем выше тир предмета, тем больше. Окно «Рекорды» (клавиша F) показывает прогресс.
##  • Заказ дня: каждый игровой день один из предметов, которые уже делают ваши машины, становится «заказом дня»:
##    машины, которые его делают, работают на 25% быстрее, а за N штук до конца дня — награда. Завтра — другой.
##  • Угольный генератор пьёт воду: без воды по трубе — ни энергии.
## Правится: «Настройки» → «Мастерство и связки», «Рекорды производства»; генератор — параметр «Воды в минуту».

var game
var xp_units := {}
var made := {}          # предмет -> сколько сделано машинами за игру
var got := {}           # "предмет|порог" -> true: награда уже выдана
var _syn_t := 0.0
var daily := {}         # {"item", "need", "have", "day", "done"}


func _init(g) -> void:
	game = g


static func mcfg() -> Dictionary:
	var c = DB.setting("mastery", {})
	return c if c is Dictionary else {}


static func dcfg() -> Dictionary:
	var c = DB.setting("daily", {})
	return c if c is Dictionary else {}


static func rcfg() -> Dictionary:
	var c = DB.setting("milestones", {})
	return c if c is Dictionary else {}


# ---------------------------------------------------------------- мастерство
static func level(b) -> int:
	var steps: Array = mcfg().get("steps", [200, 1000, 5000])
	var n := int(b.bstate.get("crafts", 0))
	var lv := 0
	for s in steps:
		if n >= int(s):
			lv += 1
	return lv


static func next_step(b) -> int:
	var steps: Array = mcfg().get("steps", [200, 1000, 5000])
	var n := int(b.bstate.get("crafts", 0))
	for s in steps:
		if n < int(s):
			return int(s)
	return 0


## Множитель скорости: мастерство × связка.
static func k(b) -> float:
	if not bool(mcfg().get("enabled", true)):
		return 1.0
	var m := 1.0 + float(mcfg().get("bonus", 0.05)) * level(b)
	m *= 1.0 + float(b.bstate.get("syn", 0.0))
	return m * (1.0 + float(b.bstate.get("focus", 0.0)))


func on_made(b, item: String, n: int) -> void:
	if b.beh != "crafter" and b.beh != "miner":
		return
	if item != "" and n > 0:
		var awards: Dictionary = xp_units
		var previous := int(awards.get(item, 0))
		var cfg: Dictionary = DB.setting("automation_xp", {})
		var limit := int(cfg.get("rated_units", 1200))
		var counted := mini(n, maxi(0, limit - previous))
		if counted > 0:
			awards[item] = previous + counted
			var unit := float(cfg.get("extraction" if b.beh == "miner" else "crafting", 0.18))
			game.add_xp(counted * unit * (1.0 - 0.5 * (float(previous) + counted * 0.5) / limit))
	if bool(mcfg().get("enabled", true)):
		var lv0 := level(b)
		b.bstate["crafts"] = int(b.bstate.get("crafts", 0)) + n
		var lv1 := level(b)
		if lv1 > lv0:
			game.notify("%s: мастерство %s — скорость +%d%%" % [DB.t(DB.building(b.type).get("name", b.type)), ["", "I", "II", "III", "IV", "V"][mini(lv1, 5)],
				int(float(mcfg().get("bonus", 0.05)) * lv1 * 100.0)], Color(1.0, 0.85, 0.35))
			if game.fx:
				game.fx.puff(b.center() + Vector3(0, 2.5, 0), "spark", 2.0)
	if item != "" and bool(rcfg().get("enabled", true)):
		made[item] = int(made.get(item, 0)) + n
		_cur_b = b
		_check(item)
		_cur_b = null
	if item != "" and item == str(daily.get("item", "")) and not bool(daily.get("done", false)):
		daily["have"] = int(daily.get("have", 0)) + n
		if int(daily.have) >= int(daily.need):
			daily["done"] = true
			var cr := int(daily.get("reward", 0))
			_pay(b, cr)   # B-3 r5
			game.notify("Заказ дня выполнен: %s ×%d — +%d денег" % [DB.item_name(item), int(daily.need), cr], Color(1.0, 0.8, 0.3))
			if game.sfx:
				game.sfx.play("levelup", game.player.position)


# ---------------------------------------------------------------- рекорды
static func steps_of() -> Array:
	return rcfg().get("steps", [100, 1000, 10000])


static func reward_of(item: String, step: int) -> Dictionary:
	var c := rcfg()
	var price := float(DB.item(item).get("price", 1))
	var cr := int(round(price * step * float(c.get("credit_k", 0.15))))
	return {"credits": maxi(5, cr), "coupons": 0}


## B-3 r5: деньги за рекорд/заказ — владельцу машины (свои кошельки), считает хозяин игры.
var _cur_b = null
func _pay(b, cr: int) -> void:
	if cr <= 0:
		return
	if game.get("coop") != null and b != null:
		game.coop.income(b, cr)
	elif not Net.is_client():
		game.credits += cr


func _check(item: String) -> void:
	var n := int(made.get(item, 0))
	for s in steps_of():
		var key := "%s|%d" % [item, int(s)]
		if n >= int(s) and not got.has(key):
			got[key] = true
			var rw := reward_of(item, int(s))
			_pay(_cur_b, int(rw.credits))   # B-3 r5
			var txt := "Рекорд: %s ×%d — +%d денег" % [DB.item_name(item), int(s), int(rw.credits)]
			# 1.3: купоны утилизации — только из утилизатора (раньше рекорд сам клал их в рюкзак)
			game.notify(txt, Color(0.5, 1.0, 0.7))
			if game.sfx:
				game.sfx.play("levelup", game.player.position)


## Для окна «Рекорды»: [[предмет, сделано, следующий порог (0 — все взяты)], ...] по убыванию сделанного.
func table() -> Array:
	var rows := []
	for it in made:
		var nxt := 0
		for s in steps_of():
			if int(made[it]) < int(s):
				nxt = int(s)
				break
		rows.append([it, int(made[it]), nxt])
	rows.sort_custom(func(a, b): return a[1] > b[1])
	return rows


# ---------------------------------------------------------------- связки
## Раз в 2 секунды: у каждой машины считаем соседей по цепочке (сосед — до 1 клетки между зданиями).
func update(dt: float) -> void:
	_syn_t += dt
	if _syn_t < 2.0:
		return
	_syn_t = 0.0
	_daily_tick()
	var f = game.factory
	var per := float(mcfg().get("chain_bonus", 0.1))
	var cap := int(mcfg().get("chain_max", 2))
	for b in f.machines:
		if not b.dead and b.beh == "miner":
			# 1.1.15: заказ дня — руда: бонус и бурам (раньше его не получал никто)
			b.bstate["focus"] = float(dcfg().get("speed_bonus", 0.25)) if (_daily_on() and _outs(b).has(str(daily.get("item", "")))) else 0.0
			continue
		if b.dead or b.beh != "crafter":
			continue
		var my_out := _outs(b)
		var my_in := _ins(b)
		var n := 0
		var seen := {}
		for c in f.footprint(b.type, b.cell):
			for dx in range(-2, 3):
				for dz in range(-2, 3):
					var o = f.building_at(c + Vector2i(dx, dz))
					if o == null or o == b or seen.has(o) or o.dead or (o.beh != "crafter" and o.beh != "miner"):
						continue
					seen[o] = true
					var linked := false
					for it in _outs(o):
						linked = linked or my_in.has(it)
					for it in _ins(o):
						linked = linked or my_out.has(it)
					if linked:
						n += 1
		b.bstate["syn"] = per * mini(n, cap)
		b.bstate["focus"] = float(dcfg().get("speed_bonus", 0.25)) if (_daily_on() and my_out.has(str(daily.get("item", "")))) else 0.0


# ---------------------------------------------------------------- заказ дня
func _daily_on() -> bool:
	return bool(dcfg().get("enabled", true)) and daily.has("item") and not bool(daily.get("done", false))


## Новый день — новый заказ: из предметов, которые машины уже делали (значит, игрок точно может), не тот же, что вчера.
func _daily_tick() -> void:
	if Net.is_client():
		return   # B-12 r5: заказ дня выбирает хозяин игры
	if not bool(dcfg().get("enabled", true)) or int(daily.get("day", -1)) == int(game.day_n):
		return
	var pool := []
	for it in made:
		if it != str(daily.get("item", "")) and DB.data.items.has(it):
			pool.append(it)
	if pool.is_empty():
		return
	var it: String = pool[randi() % pool.size()]
	var price := maxf(1.0, float(DB.item(it).get("price", 1)))
	var need := clampi(int(float(dcfg().get("value", 3000)) / price), 1, 300)   # A-9 r10: дорогое — от 1 штуки (награда ≈ value × credit_k)
	var reward := int(round(minf(price * need, float(dcfg().get("value", 3000))) * float(dcfg().get("credit_k", 0.5))))   # A-9 r10
	daily = {"item": it, "need": need, "have": 0, "day": int(game.day_n), "done": false, "reward": reward}
	game.notify("Заказ дня: %s ×%d — машины с ним +%d%% скорости, награда %d" % [DB.item_name(it), need,
		int(float(dcfg().get("speed_bonus", 0.25)) * 100.0), reward], Color(1.0, 0.8, 0.3))


func set_daily(d: Dictionary) -> void:
	var was := str(daily.get("item", "")) + "|" + str(daily.get("day", -1))
	daily = d.duplicate()
	if was != str(daily.get("item", "")) + "|" + str(daily.get("day", -1)) and str(daily.get("item", "")) != "":
		game.notify("Заказ дня: %s ×%d — награда %d" % [DB.item_name(str(daily.item)), int(daily.get("need", 0)), int(daily.get("reward", 0))], Color(1.0, 0.8, 0.3))


static func _outs(b) -> Dictionary:
	if b.beh == "miner":
		return {b.recipe: true} if b.recipe != "" else {}
	var rid: String = b.recipe if b.recipe != "" else b.last_rid
	return DB.data.recipes.get(rid, {}).get("out", {})


static func _ins(b) -> Dictionary:
	if b.beh != "crafter":
		return {}
	var rid: String = b.recipe if b.recipe != "" else b.last_rid
	return DB.data.recipes.get(rid, {}).get("in", {})


# ---------------------------------------------------------------- сохранение
func to_dict() -> Dictionary:
	return {"xp_units": xp_units, "made": made, "got": got.keys(), "daily": daily}


func from_dict(d: Dictionary) -> void:
	xp_units = d.get("xp_units", {}).duplicate()
	made = d.get("made", {}).duplicate()
	daily = d.get("daily", {}).duplicate()
	got.clear()
	for k in d.get("got", []):
		got[str(k)] = true
