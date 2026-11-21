extends RefCounted
## Заказы на орбитальной станции (этап 10).
## Игрок выставляет заказ: продать или купить предмет, сколько и за сколько.
## Раз в «order_check» секунд НПС-торговцы присылают предложения. Цена предложения считается от рынка
## (цена предмета × текущий спрос), с разбросом, а не от суммы игрока. Слишком жадный заказ не получает предложений,
## дешёвый — получает быстрее. Принятое предложение исполняется через склад штаба.

var game
var list: Array = []       # мои заказы: {id, side, item, n, price, age, offers: [{from, pay_item, pay_n, credits, t}]}
var history: Array = []    # сделки: {day, text}
var _acc := 0.0
var _next_id := 1


func _init(g) -> void:
	game = g


## Рыночная цена одной штуки (сколько станция платит сейчас).
func unit_price(item: String, side := "buy") -> float:
	if side == "sell" and Blocks.econ_on():
		return game.sell_value(item, "orders_k")   # 1.1.8: за проданное торговцы платят долю цены Чёрного рынка
	return float(DB.item(item).get("price", 1)) * float(game.price_mult.get(item, 1.0)) * game.econ_mult(item, side == "buy")


func place(side: String, item: String, n: int, price: int) -> Dictionary:
	if not DB.data.items.has(item) or n <= 0 or price <= 0:
		return {}
	var o := {"id": _next_id, "side": side, "item": item, "n": n, "price": price, "age": 0.0, "offers": []}
	_next_id += 1
	list.append(o)
	return o


func cancel(id: int) -> void:
	for o in list.duplicate():
		if int(o.id) == id:
			list.erase(o)


func update(delta: float) -> void:
	if not game.module("orders"):
		return
	_acc += delta
	var every := float(DB.setting("order_check", 20.0))
	if _acc < every:
		return
	_acc = 0.0
	var life := float(DB.setting("order_life", 600.0))
	for o in list.duplicate():
		o.age = float(o.age) + every
		for of in o.offers.duplicate():
			of.t = float(of.t) - every
			if of.t <= 0.0:
				o.offers.erase(of)
		if o.age > life and o.offers.is_empty():
			list.erase(o)
			_log("Заказ «%s × %d» снят: никто не откликнулся" % [DB.item_name(o.item), o.n])
			continue
		_maybe_offer(o)


## Сколько стоит заказ по рынку.
func market_total(o: Dictionary) -> float:
	return unit_price(str(o.item), str(o.side)) * int(o.n)


## Насколько игрок «жадничает»: >1 — просит больше рынка (продажа) или платит меньше (покупка).
func greed(o: Dictionary) -> float:
	var m := maxf(1.0 if not Blocks.econ_on() else 0.01, market_total(o))
	if o.side == "sell":
		return float(o.price) / m
	return m / maxf(1.0, float(o.price))


func _maybe_offer(o: Dictionary) -> void:
	var g := greed(o)
	if g > float(DB.setting("order_max_ratio", 1.6)) or o.offers.size() >= 3:
		return
	# чем жаднее, тем реже приходят предложения
	var chance := clampf(1.3 - g, 0.05, 0.95)
	if randf() > chance:
		return
	o.offers.append(make_offer(o))


func make_offer(o: Dictionary) -> Dictionary:
	var spread := float(DB.setting("order_spread", 0.12))
	var value := market_total(o) * randf_range(1.0 - spread, 1.0 + spread)
	if o.side == "buy":
		value = market_total(o) * randf_range(1.0, 1.0 + spread * 2.0)   # продавцы просят не меньше рынка
	var from := _trader_name()
	var of := {"from": from, "credits": maxi(1, roundi(value)), "pay_item": "", "pay_n": 0, "t": float(DB.setting("order_life", 600.0)) * 0.5}
	# иногда за проданное платят другим товаром той же цены
	if o.side == "sell" and randf() < 0.35 and not Blocks.econ_on():
		var cands := []
		for id in DB.data.items:
			var p := float(DB.item(id).get("price", 0))
			if id != o.item and p > 0.0 and p <= value * 0.5:
				cands.append(id)
		if not cands.is_empty():
			var it: String = cands[randi() % cands.size()]
			of.pay_item = it
			of.pay_n = maxi(1, roundi(value / maxf(1.0, unit_price(it))))
			of.credits = 0
	return of


func _trader_name() -> String:
	var names := []
	for id in DB.data.enemies:
		var d: Dictionary = DB.data.enemies[id]
		if str(d.get("behavior", "")) == "trader":
			var f: Dictionary = DB.data.get("factions", {}).get(str(d.get("faction", "")), {})
			names.append("%s (%s)" % [d.get("name", id), f.get("name", "станция")])
	if names.is_empty():
		return "Станция «Орбита-7»"
	return names[randi() % names.size()]


func offer_text(o: Dictionary, of: Dictionary) -> String:
	var pay: String = ("%d кр" % int(of.credits)) if of.pay_item == "" else ("%s × %d" % [DB.item_name(str(of.pay_item)), int(of.pay_n)])
	if o.side == "sell":
		return "%s предлагает за %d × %s: %s" % [of.from, o.n, DB.item_name(str(o.item)), pay]
	return "%s продаст %d × %s за %s" % [of.from, o.n, DB.item_name(str(o.item)), pay]


## Принять предложение. Продажа: товар уходит со склада штаба (и из рюкзака). Покупка: платим, товар — в штаб.
func accept(o: Dictionary, of: Dictionary) -> bool:
	if Net.is_client():
		if Time.get_ticks_msec() - int(o.get("pending_ms", -99999)) < 5000:
			return false   # ждём ответа хозяина
		# 1.1.15: у гостя сделка идёт через хозяина (его склад и кошелёк); раньше товар пропадал, а кредиты откатывались
		var d := {"side": str(o.side), "item": str(o.item), "n": int(o.n), "pay_item": str(of.pay_item), "pay_n": int(of.get("pay_n", 0)), "credits": int(of.get("credits", 0)), "oid": int(o.id), "text": offer_text(o, of)}
		var qh: Inventory = game._quest_home()   # в «своих базах» — склад своего аванпоста
		if o.side == "sell" and (qh.count(d.item) if qh else 0) + game.player.inv.count(d.item) < d.n:
			game.notify("Для заказа нужно %d × %s" % [d.n, DB.item_name(d.item)], Color(1, 0.6, 0.4))
			return false
		game.cmd("order_deal", d)
		o["pending_ms"] = Time.get_ticks_msec()   # B-6 r3: заказ уходит из списка, только когда хозяин подтвердит сделку
		return true
	return deal(o, of)


## Сама сделка (у хозяина или в одиночной игре; у хозяина за гостя — командой order_deal).
func deal(o: Dictionary, of: Dictionary) -> bool:
	var f = game.factory
	var item := str(o.item)
	var n := int(o.n)
	var home: Inventory = game.home_inv()   # A-19: у гостя в «своих базах» — его аванпост
	if o.side == "sell":
		var have: int = (home.count(item) if home else 0) + game.player.inv.count(item)
		if have < n:
			game.notify("Для заказа нужно %d × %s, есть %d" % [n, DB.item_name(item), have], Color(1, 0.6, 0.4))
			return false
		var from_hq: int = mini(n, home.count(item)) if home else 0
		if from_hq > 0:
			home.remove(item, from_hq)
		if n > from_hq:
			game.player.inv.remove(item, n - from_hq)
		if of.pay_item != "":
			var left: int = home.add(str(of.pay_item), int(of.pay_n)) if home else int(of.pay_n)
			if left > 0:
				f.give_player(str(of.pay_item), left)
		else:
			game.add_credits(int(of.credits), false)
			if Net.is_host() and Net._self().actor != 0:
				Net._self().rpc_id(Net._self().actor, "trade_credit", int(of.credits), 0.0)
			else:
				game.trade_earned += int(of.credits)
		game.market_sold(item, n)
	else:
		if game.credits < int(of.credits):
			game.notify("Не хватает кредитов", Color(1, 0.6, 0.4))
			return false
		game.credits -= int(of.credits)
		var left2: int = home.add(item, n) if home else n
		if left2 > 0:
			f.give_player(item, left2)
	_log(offer_text(o, of) + " — сделка")
	list.erase(o)
	game.sfx.play_ui("coin")
	game._shuttle_run()
	return true


## Хозяин подтвердил сделку гостя.
func done_remote(oid: int, text: String) -> void:
	for o in list.duplicate():
		if int(o.id) == oid:
			list.erase(o)
	_log(text + " — сделка")
	game.sfx.play_ui("coin")


func decline(o: Dictionary, of: Dictionary) -> void:
	o.offers.erase(of)


func _log(t: String) -> void:
	history.push_front({"day": game.day_n, "text": t})
	if history.size() > 50:
		history.resize(50)


func to_dict() -> Dictionary:
	return {"list": list.duplicate(true), "history": history.duplicate(true), "next": _next_id}


func load_dict(d: Dictionary) -> void:
	list = d.get("list", []).duplicate(true)
	history = d.get("history", []).duplicate(true)
	_next_id = int(d.get("next", list.size() + 1))
	for o in list:
		o.id = int(o.id)
		o.n = int(o.n)
		o.price = int(o.price)
