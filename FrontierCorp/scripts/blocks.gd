class_name Blocks
extends RefCounted
## Блоки поведения: из них в редакторе собираются здания с новыми функциями без программирования.
## У здания в данных: "blocks": [{"type": "produce", ...}, {"type": "trigger", ...}].
## Блоки работают вместе с обычным видом здания (можно сделать турель, которая ещё и лечит).
## Если блоков не хватает — "script": "scripts/моё.gd" (для модов): функции on_tick, on_event, on_use.

const TYPES := {
	"produce": "Производит предмет сам по себе",
	"convert": "Превращает предметы (свой рецепт)",
	"store": "Хранит предметы",
	"power_gen": "Даёт энергию (можно на топливе)",
	"shoot": "Стреляет по монстрам",
	"heal_area": "Лечит героя и чинит здания рядом",
	"buff_area": "Усиливает героя рядом",
	"spawn": "Призывает монстров или выбрасывает предметы",
	"sell": "Продаёт положенные предметы за кредиты",
	"trigger": "Событие → действия (как команды консоли)",
	"research": "Лаборатория: изучает образцы → очки исследований",
	"carrier": "Дрон или грузовик: возит предметы между зданиями одного канала",
	"route": "Дроны по маршруту: «отвезти груз со склада А на склад Б» (по меткам зданий)",
	"sink": "Утилизатор: сжигает любые предметы, копит очки по их цене, за очки выдаёт купоны",
	"zone_push": "Разгонитель облаков: подвезённое лентой оплачивает следующее расширение зоны",
	"bmarket": "Чёрный рынок: продаёт предметы с лент за кредиты (чем ценнее предмет, тем большая доля цены)",
}
## Поля каждого блока для редактора: [ключ, подпись, вид, подсказка].
const FIELDS := {
	"produce": [["item", "Что производит", "ref:items", ""], ["n", "Сколько за раз", "int", ""], ["every", "Каждые, сек", "float", ""],
		["needs_power", "Нужна энергия", "bool", "Сколько — в «Параметры → Энергия». Без энергии стоит, при нехватке — медленнее"]],
	"convert": [["in", "Берёт", "amounts:items", ""], ["out", "Даёт", "amounts:items", ""], ["time", "Время, сек", "float", ""],
		["needs_power", "Нужна энергия", "bool", ""]],
	"store": [["slots", "Ячеек", "int", ""]],
	"power_gen": [["power", "Мощность", "float", ""], ["radius", "Радиус сети, клеток", "float", ""],
		["fuel", "Нужно топливо", "bool", "Ветки, брёвна, уголь — всё, у чего есть «топливо»"], ["solar", "Только днём (от солнца)", "bool", ""]],
	"shoot": [["damage", "Урон", "float", ""], ["range", "Дальность", "float", ""], ["rate", "Выстрел каждые, сек", "float", ""],
		["color", "Цвет луча", "color", ""], ["needs_power", "Нужна энергия", "bool", ""]],
	"heal_area": [["radius", "Радиус", "float", ""], ["heal", "Лечит героя, в сек", "float", ""], ["repair", "Чинит здания, в сек", "float", ""],
		["needs_power", "Нужна энергия", "bool", ""]],
	"buff_area": [["radius", "Радиус", "float", ""], ["stat", "Что усиливает", "enum:@STATS", ""], ["value", "Насколько", "float", "0.2 = +20%"],
		["needs_power", "Нужна энергия", "bool", ""]],
	"spawn": [["enemy", "Монстр", "ref:enemies", "Пусто — не призывать"], ["item", "Предмет на землю", "ref:items", "Пусто — не выбрасывать"],
		["n", "Сколько", "int", ""], ["every", "Каждые, сек", "float", ""], ["only_night", "Только ночью", "bool", ""]],
	"sell": [["items", "Какие предметы (пусто — любые)", "refs:items", ""], ["k", "Доля цены", "float", "1 = полная цена"]],
	"trigger": [["event", "Когда", "enum:@EVENTS", ""],
		["every", "Раз в, сек (для «каждые»)", "float", ""], ["radius", "Радиус (для «рядом»)", "float", ""],
		["cooldown", "Не чаще, чем раз в, сек", "float", ""], ["actions", "Действия", "list:cmd_action", "Как в командах консоли; $x, $z — клетка здания"]],
	"research": [["in", "Образцы", "amounts:items", "Что нужно положить (лентой или руками) на один опыт"], ["points", "Очков исследований за опыт", "int", ""],
		["time", "Время опыта, сек", "float", ""], ["needs_power", "Нужна энергия", "bool", ""]],
	"carrier": [["mode", "Роль", "enum:send|receive", "send — отправляет то, что ему привезли лентой; receive — принимает и выдаёт на ленту"],
		["channel", "Канал", "str", "Отправитель везёт ближайшему получателю с тем же каналом (A, B, руда...)"],
		["n", "Груз за рейс", "int", ""], ["every", "Рейс каждые, сек", "float", ""], ["range", "Дальность, клеток", "float", ""],
		["speed", "Скорость", "float", "Метров в секунду"], ["model", "Модель перевозчика", "ref:models", "drone_carrier — дрон, truck_carrier — грузовик"],
		["ground", "Едет по земле", "bool", "Вкл — грузовик, выкл — летит"], ["needs_power", "Нужна энергия", "bool", ""]],
	"route": [["steps", "Шаги маршрута", "list:route_step", "Рейсы идут по очереди: шаг 1, шаг 2… Метку зданию ставят в его окне («Метка для дронов»)"],
		["every", "Рейс каждые, сек", "float", ""], ["range", "Дальность от станции, клеток", "float", "Склады «Откуда» и «Куда» ищутся в этом радиусе"],
		["speed", "Скорость", "float", "Метров в секунду"], ["model", "Модель перевозчика", "ref:models", "drone_carrier — дрон, truck_carrier — грузовик"],
		["ground", "Едет по земле", "bool", ""], ["needs_power", "Нужна энергия", "bool", ""]],
	"sink": [["items", "Какие предметы (пусто — любые)", "refs:items", ""], ["k", "Очков за единицу цены", "float", "1 = очки равны цене предмета"],
		["coupon", "Очков на один купон", "int", "Купон утилизации выходит на ленту или забирается руками"], ["per_tick", "Сжигает за 0,25 с", "int", "8 = 1920 в минуту"],
		["needs_power", "Нужна энергия", "bool", ""]],
	"zone_push": [["needs_power", "Нужна энергия", "bool", "Принимает с ленты только то, что нужно для следующего расширения зоны"]],
	"bmarket": [["items", "Какие предметы (пусто — любые)", "refs:items", ""], ["per_min", "Предметов в минуту", "int", "Пусто — из «Экономика 1.1.8»"],
		["k", "Множитель выплаты", "float", "1 = как в правилах экономики"], ["needs_power", "Нужна энергия", "bool", ""]],
}
## Значения нового блока, чтобы он сразу работал.
const DEFAULTS := {
	"produce": {"item": "stone", "n": 1, "every": 5.0, "needs_power": false},
	"convert": {"in": {"stone": 2}, "out": {"concrete": 1}, "time": 3.0, "needs_power": true},
	"store": {"slots": 8},
	"power_gen": {"power": 20.0, "radius": 6.0, "fuel": false, "solar": false},
	"shoot": {"damage": 12.0, "range": 22.0, "rate": 0.8, "color": "#ff6040", "needs_power": true},
	"heal_area": {"radius": 6.0, "heal": 4.0, "repair": 0.0, "needs_power": false},
	"buff_area": {"radius": 8.0, "stat": "move", "value": 0.2, "needs_power": false},
	"spawn": {"enemy": "", "item": "", "n": 1, "every": 30.0, "only_night": false},
	"sell": {"items": [], "k": 0.8},
	"trigger": {"event": "every", "every": 10.0, "radius": 4.0, "cooldown": 0.0, "actions": [{"do": "notify", "text": "Сработало!"}]},
	"research": {"in": {"alien_tissue": 1}, "points": 5, "time": 20.0, "needs_power": true},
	"carrier": {"mode": "send", "channel": "A", "n": 10, "every": 8.0, "range": 80.0, "speed": 14.0, "model": "drone_carrier", "ground": false, "needs_power": true},
	"route": {"steps": [{"item": "", "n": 10, "from_tag": "A", "to_tag": "B", "keep": 0}], "every": 6.0, "range": 120.0, "speed": 16.0, "model": "drone_carrier", "ground": false, "needs_power": true},
	"sink": {"items": [], "k": 1.0, "coupon": 100, "per_tick": 8, "needs_power": true},
	"zone_push": {"needs_power": true},
	"bmarket": {"items": [], "k": 1.0, "needs_power": false},
}
const EVENT_NAMES := {"every": "Каждые N секунд", "placed": "Здание построено", "destroyed": "Здание разрушено", "wave_start": "Началась волна",
	"night": "Наступила ночь", "day": "Наступил день", "player_near": "Герой подошёл", "enemy_near": "Монстр рядом", "working": "Пока работает"}

static var _scripts := {}


## 1.1.8: правила экономики (Настройки → economy18). В тестах старых версий выключены.
static func econ() -> Dictionary:
	var e = DB.setting("economy18", {})
	return e if e is Dictionary else {}


static func econ_on() -> bool:
	return bool(econ().get("on", false))


## Сколько кредитов Чёрный рынок платит за 1 штуку: доля цены растёт с ценой (руда — тысячные доли, детали — до четверти цены).
## Своё значение — поле предмета «bm».
static func bm_value(g, id: String) -> float:
	var it := DB.item(id)
	if it.has("bm"):
		return float(it.bm)
	var p := float(it.get("price", 0))
	if p <= 0.0:
		return 0.0
	var e := econ()
	var soft := float(e.get("bm_soft", 45.0))
	var v := float(e.get("bm_k", 0.25)) * p * p * p / (p * p + soft * soft)
	if g != null:
		v *= g.econ_mult(id) * (1.0 + maxf(-0.9, g.bonus("sell")))
	return minf(v, shop_sell_cap(id))   # A-2 r10


static func of(type: String) -> Array:
	return DB.building(type).get("blocks", [])


static func has_blocks(type: String) -> bool:
	var d := DB.building(type)
	return not d.get("blocks", []).is_empty() or str(d.get("script", "")) != ""


static func find(type: String, kind: String) -> Dictionary:
	for bl in of(type):
		if str(bl.get("type", "")) == kind:
			return bl
	return {}


## При постройке: завести нужные ячейки.
static func setup(f, b) -> void:
	var slots := 0
	var needs_out := false
	var needs_fuel := false
	for bl in of(b.type):
		match str(bl.get("type", "")):
			"store":
				slots += int(bl.get("slots", 8))
			"sink":
				slots = maxi(slots, 8)
				needs_out = true
			"zone_push":
				slots = maxi(slots, 12)
			"bmarket":
				slots = maxi(slots, 8)
			"convert", "sell", "research":
				slots = maxi(slots, 4)
				needs_out = needs_out or bl.get("type") == "convert"
			"produce":
				needs_out = true
			"carrier":
				if str(bl.get("mode", "send")) == "receive":
					needs_out = true
				else:
					slots = maxi(slots, 6)
			"power_gen":
				if bl.get("fuel", false):
					needs_fuel = true
	if slots > 0 and b.inv == null:
		b.inv = Inventory.new(slots)
	if needs_out and b.out == null:
		b.out = Inventory.new(4)
	if needs_fuel and b.fuel == null:
		b.fuel = Inventory.new(2)
	b.bstate = {}
	if not f.loading:
		event(f.game, b, "placed")


## Может ли здание с блоками принять предмет (с ленты или от героя).
static func accept(b, item: String, f = null) -> bool:
	for bl in of(b.type):
		match str(bl.get("type", "")):
			"convert", "research":
				if bl.get("in", {}).has(item) and b.inv != null and b.inv.count(item) < 20 and b.inv.can_add(item, 1):
					b.inv.add(item, 1)
					return true
			"sell":
				var its: Array = bl.get("items", [])
				if (its.is_empty() or item in its) and b.inv != null and b.inv.can_add(item, 1):
					b.inv.add(item, 1)
					return true
			"sink":
				var sits: Array = bl.get("items", [])
				if (sits.is_empty() or item in sits) and item != "sink_coupon" and not bool(DB.item(item).get("no_sink", false)) and b.inv != null and b.inv.can_add(item, 1):
					b.inv.add(item, 1)
					return true
			"bmarket":
				var bits: Array = bl.get("items", [])
				if (bits.is_empty() or item in bits) and item != "sink_coupon" and float(DB.item(item).get("price", 0)) > 0.0 and b.inv != null and b.inv.can_add(item, 1):
					b.inv.add(item, 1)
					return true
			"zone_push":
				var zg = f.game if f != null else null
				if zg != null and zg.zone != null and b.inv != null:
					var need: int = int(zg.zone.next_cost().get(item, 0))
					if need > 0 and b.inv.count(item) < need and b.inv.can_add(item, 1):
						b.inv.add(item, 1)
						return true
			"power_gen":
				if b.fuel != null and Factory.fuel_ok(b, item) and b.fuel.can_add(item, 1):
					b.fuel.add(item, 1)
					return true
			"store":
				if b.inv != null and b.inv.can_add(item, 1):
					b.inv.add(item, 1)
					return true
			"carrier":
				if str(bl.get("mode", "send")) == "send" and b.inv != null and b.inv.can_add(item, 1):
					b.inv.add(item, 1)
					return true
	return false


## Энергия от блоков (вызывается из расчёта сети).
static func power_supply(f, b, dt: float, demand: float) -> float:
	var bl := find(b.type, "power_gen")
	if bl.is_empty():
		return 0.0
	var pw := float(bl.get("power", 10))
	if bl.get("solar", false):
		return pw * f.game.sun_power()
	if bl.get("fuel", false):
		if b.fuel_t <= 0.0 and demand > 0.0 and b.fuel != null:
			var it: String = b.fuel.first_item()
			if it != "":
				b.fuel.remove(it, 1)
				b.fuel_t += float(DB.item(it).get("fuel", 0)) * 2.0
		if b.fuel_t <= 0.0:
			return 0.0
		if demand > 0.0:
			b.fuel_t = maxf(0.0, b.fuel_t - dt)
	return pw


static func gen_radius(b) -> float:
	return float(find(b.type, "power_gen").get("radius", 6))


## Работа блоков (4 раза в секунду).
static func update(f, b, dt: float) -> void:
	var g = f.game
	var st: Dictionary = b.bstate
	var sat: float = f.sat_c(b)
	var working := false
	var blocks := of(b.type)
	var w0: bool = b.want
	b.want = false   # B-8: несколько блоков — здание хочет энергию, если хочет хоть один
	var want_set := false
	for i in blocks.size():
		var bl: Dictionary = blocks[i]
		var k := "b%d" % i
		var pw_k: float = sat if bl.get("needs_power", false) else 1.0
		match str(bl.get("type", "")):
			"produce":
				want_set = true
				b.want = b.want or (true)
				if b.out != null and b.out.can_add(str(bl.get("item", "")), int(bl.get("n", 1))) and DB.data.items.has(str(bl.get("item", ""))):
					st[k] = float(st.get(k, 0.0)) + dt * pw_k * Tuning.k(b, "speed")
					working = working or pw_k > 0.0
					if st[k] >= float(bl.get("every", 5.0)):
						st[k] = 0.0
						b.out.add(str(bl.item), int(bl.get("n", 1)))
			"convert":
				var ins: Dictionary = bl.get("in", {})
				var ok := b.inv != null and b.out != null and not ins.is_empty()
				for it in ins:
					if ok and b.inv.count(it) < int(ins[it]):
						ok = false
				for it in bl.get("out", {}):
					if ok and not b.out.can_add(it, int(bl.out[it])):
						ok = false
				want_set = true
				b.want = b.want or (ok)
				if ok:
					st[k] = float(st.get(k, 0.0)) + dt * pw_k * Tuning.k(b, "speed")
					working = working or pw_k > 0.0
					b.prog = clampf(float(st[k]) / maxf(0.1, float(bl.get("time", 2.0))), 0.0, 1.0)
					if st[k] >= float(bl.get("time", 2.0)):
						st[k] = 0.0
						for it in ins:
							b.inv.remove(it, int(ins[it]))
						for it in bl.get("out", {}):
							b.out.add(it, int(bl.out[it]))
			"sink":
				if b.inv == null:
					continue
				want_set = true
				b.want = b.want or b.inv.first_item() != ""   # A-4 r3: утилизатор ест энергию, пока есть что жечь
				var burn := 0
				# A-8 r4: темп утилизации ∝ энергии (дробная часть копится)
				st["acc"] = minf(float(st.get("acc", 0.0)) + float(bl.get("per_tick", 8)) * pw_k, float(bl.get("per_tick", 8)) * 2.0)
				var cap := int(floor(float(st.acc)))
				while burn < cap and pw_k > 0.0:
					var sid: String = b.inv.first_item()
					if sid == "":
						break
					b.inv.remove(sid, 1)
					var spts: float = sink_points(sid, float(bl.get("coupon", 100))) * float(bl.get("k", 1.0))
					st["pts"] = float(st.get("pts", 0.0)) + spts
					st["total"] = float(st.get("total", 0.0)) + spts
					burn += 1
				st["acc"] = float(st.acc) - burn
				if b.inv.first_item() == "":
					st["acc"] = minf(float(st.acc), 1.0)
				working = working or burn > 0
				var per := maxf(1.0, float(bl.get("coupon", 100)))
				b.prog = clampf(float(st.get("pts", 0.0)) / per, 0.0, 1.0)
				while float(st.get("pts", 0.0)) >= per and b.out != null and b.out.can_add("sink_coupon", 1):
					st["pts"] = float(st.pts) - per
					b.out.add("sink_coupon", 1)
					g.sink_points_total = int(g.sink_points_total) + int(per)
			"bmarket":
				if b.inv == null:
					continue
				# 1.1.8: продаёт по одному с темпом per_min; доли кредита копятся, целые уходят владельцу
				var per := 60.0 / maxf(1.0, float(bl.get("per_min", econ().get("bm_per_min", 30))))
				st["t"] = float(st.get("t", 0.0)) + dt * pw_k
				while float(st.t) >= per:
					var mid: String = b.inv.first_item()
					if mid == "":
						st["t"] = minf(float(st.t), per)
						break
					st["t"] = float(st.t) - per
					b.inv.remove(mid, 1)
					var v := bm_value(g, mid) * float(bl.get("k", 1.0))
					st["cr"] = float(st.get("cr", 0.0)) + v
					st["sold"] = int(st.get("sold", 0)) + 1
					st["last"] = mid
					working = true
				var whole := int(floor(float(st.get("cr", 0.0))))
				if whole >= 1:
					st["cr"] = float(st.cr) - whole
					st["paid"] = int(st.get("paid", 0)) + whole
					g.trade_earned += whole
					if g.coop:
						g.coop.income(b, whole)
					else:
						g.add_credits(whole, false)
				b.prog = clampf(float(st.get("cr", 0.0)), 0.0, 1.0)
			"zone_push":
				if b.inv == null or g.zone == null or pw_k <= 0.0:
					continue
				var zc: Dictionary = g.zone.next_cost()
				var full: bool = not zc.is_empty() and int(g.zone.blocks) < int(g.zone.max_blocks())
				for it in zc:
					if full and b.inv.count(it) < int(zc[it]):
						full = false
				want_set = true
				b.want = b.want or (not full)
				b.prog = 0.0
				if not zc.is_empty():
					var have := 0.0
					var need := 0.0
					for it in zc:
						have += minf(b.inv.count(it), int(zc[it]))
						need += int(zc[it])
					b.prog = have / maxf(1.0, need)
				# A-8 r4: на слабой энергии — разгон копится (1 с при полной энергии)
				st["zp"] = minf(float(st.get("zp", 0.0)) + dt * pw_k, 1.0) if full else 0.0
				if full and float(st.zp) >= 1.0:
					st["zp"] = 0.0
					for it in zc:
						b.inv.remove(it, int(zc[it]))
					g.zone.expand(true)
					g.notify("Разгонитель облаков: буря отступила", Color(0.6, 0.85, 1.0))
					working = true
			"research":
				var rin: Dictionary = bl.get("in", {})
				var rok := b.inv != null and not rin.is_empty()
				for it in rin:
					if rok and b.inv.count(it) < int(rin[it]):
						rok = false
				want_set = true
				b.want = b.want or (rok)
				if rok:
					st[k] = float(st.get(k, 0.0)) + dt * pw_k
					working = working or pw_k > 0.0
					b.prog = clampf(float(st[k]) / maxf(0.1, float(bl.get("time", 20.0))), 0.0, 1.0)
					if st[k] >= float(bl.get("time", 20.0)):
						st[k] = 0.0
						for it in rin:
							b.inv.remove(it, int(rin[it]))
						g.tech.research += int(bl.get("points", 5))
						g.notify("Лаборатория: +%d очков исследований" % int(bl.get("points", 5)), Color(0.55, 0.9, 1.0))
			"carrier":
				if str(bl.get("mode", "send")) != "send" or b.inv == null:
					continue
				var filter_item := str(b.cfg.get("cargo_filter", ""))
				var cit: String = b.inv.first_item() if filter_item == "" else (filter_item if b.inv.count(filter_item) > 0 else "")
				want_set = true
				b.want = b.want or (cit != "")
				if cit == "" or g.carriers == null or (b.type == "drone_port" and g.carriers.airborne(b)):
					continue
				st[k] = float(st.get(k, 0.0)) + dt * pw_k
				if st[k] >= float(bl.get("every", 8.0)):
					var to = g.carriers.find_receiver(b, bl, cit)
					if to != null:
						st[k] = 0.0
						var capacity: int = g.carriers.fleet_capacity(b) if b.type == "drone_port" else int(bl.get("n", 10))
						var cn := mini(capacity, b.inv.count(cit))
						if cn <= 0:
							continue
						var manifest := Inventory.new(b.inv.size())
						cn = b.inv.move_to(manifest, cit, cn)
						if cn <= 0:
							continue
						g.carriers.launch(b, to, cit, cn, str(bl.get("model", "drone_carrier")), float(bl.get("speed", 14.0)), bool(bl.get("ground", false)))
						g.carriers.flights.back()["sl"] = manifest.slots.filter(func(slot): return slot != null)
						working = true
			"route":
				var steps: Array = bl.get("steps", [])
				if steps.is_empty() or g.carriers == null:
					continue
				want_set = true
				b.want = b.want or (true)
				st[k] = float(st.get(k, 0.0)) + dt * pw_k
				if st[k] >= float(bl.get("every", 6.0)):
					st[k] = 0.0
					var si := int(st.get(k + "s", 0))
					for j in steps.size():
						var sj := (si + j) % steps.size()
						if g.carriers.route_step(b, bl, steps[sj]):
							st[k + "s"] = (sj + 1) % steps.size()
							working = true
							break
			"shoot":
				want_set = true
				b.want = b.want or (true)
				st[k] = float(st.get(k, 0.0)) - dt * pw_k
				if st[k] <= 0.0 and pw_k > 0.0:
					var e = g.enemies.nearest(b.center(), float(bl.get("range", 20)))
					if e != null:
						st[k] = float(bl.get("rate", 1.0))
						g.enemies.hit(e, float(bl.get("damage", 10)), false, b)
						var from: Vector3 = b.center() + Vector3(0, 1.6, 0)
						g.fx.tracer(from, from + World.delta(from, e.pos + Vector3(0, 0.8, 0)), DB.color(bl.get("color", "#ff6040")), 0.08)
						working = true
			"heal_area":
				want_set = true
				b.want = b.want or (true)
				var r := float(bl.get("radius", 8)) * World.C
				if pw_k > 0.0:
					for hp_pl in (g.split.local_players() if g.get("split") != null else [g.player]):   # A-13 r5: оба героя
						if hp_pl != null and World.dist(hp_pl.position, b.center()) < r and hp_pl.alive:
							hp_pl.hp = minf(hp_pl.maxhp, hp_pl.hp + float(bl.get("heal", 5)) * dt * pw_k)
					var rep := float(bl.get("repair", 0))
					if rep > 0.0:
						for o in f.all:
							if o != b and o.hp < o.maxhp and World.dist(o.center(), b.center()) < r:
								f.repair(o, rep * dt * pw_k)
					working = true
			"buff_area":
				want_set = true
				b.want = b.want or (true)
				var near_any := false   # A-13 r5: усиление общее — если рядом любой из героев
				for bp in (g.split.local_players() if g.get("split") != null else [g.player]):
					if bp != null and World.dist(bp.position, b.center()) < float(bl.get("radius", 8)) * World.C:
						near_any = true
				if pw_k > 0.0 and near_any:
					g.add_effect(str(bl.get("stat", "move")), float(bl.get("value", 0.2)) * minf(pw_k, 1.0), 0.6, DB.building(b.type).get("name", b.type))
					working = true
			"spawn":
				if bl.get("only_night", false) and g.daylight() > 0.3:
					continue
				st[k] = float(st.get(k, 0.0)) + dt
				if st[k] >= float(bl.get("every", 30.0)):
					st[k] = 0.0
					var en := str(bl.get("enemy", ""))
					var it := str(bl.get("item", ""))
					for n in int(bl.get("n", 1)):
						var off := Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
						if en != "":
							g.enemies.spawn(en, b.center() + off)
						if it != "":
							g.drops.spawn(it, 1, b.center() + Vector3(0, 1, 0))
					working = true
			"sell":
				if b.inv != null:
					var id: String = b.inv.first_item()
					if id != "":
						b.inv.remove(id, 1)
						var amt := int(round(g.sell_price(id) * float(bl.get("k", 1.0))))
						if econ_on():
							# 1.1.8: старый «Торговый терминал» платит как торговая станция; доли копятся
							st["cr"] = float(st.get("cr", 0.0)) + g.sell_value(id) * float(bl.get("k", 1.0))
							amt = int(floor(float(st.cr)))
							st["cr"] = float(st.cr) - amt
						if amt > 0:
							g.coop.income(b, amt) if g.coop else g.add_credits(amt, false)
						working = true
			"trigger":
				var ev := str(bl.get("event", "every"))
				match ev:
					"every":
						st[k] = float(st.get(k, 0.0)) + dt
						if st[k] >= float(bl.get("every", 10.0)):
							st[k] = 0.0
							_fire(g, b, bl, i)
					"player_near":
						var near: bool = World.dist(g.player.position, b.center()) < float(bl.get("radius", 4)) * World.C
						if near and not st.get(k + "in", false):
							_fire(g, b, bl, i)
						st[k + "in"] = near
					"enemy_near":
						if g.enemies.nearest(b.center(), float(bl.get("radius", 8)) * World.C) != null:
							_fire(g, b, bl, i)
	if b.out != null:
		f._push_out(b)
	if st.get("pw_on", false):
		working = true
	if not want_set:
		b.want = w0
	b.active = working
	var path := str(DB.building(b.type).get("script", ""))
	if path != "":
		var s = script_for(path)
		if s != null and s.has_method("on_tick"):
			s.on_tick(g, b, dt)
	if working:
		for i in blocks.size():
			if str(blocks[i].get("event", "")) == "working" and blocks[i].get("type", "") == "trigger":
				_fire(g, b, blocks[i], i)


## Событие у здания (placed, destroyed) или у всех зданий с блоками (wave_start, night, day).
static func event(g, b, name: String) -> void:
	var blocks := of(b.type)
	for i in blocks.size():
		var bl: Dictionary = blocks[i]
		if str(bl.get("type", "")) == "trigger" and str(bl.get("event", "")) == name:
			_fire(g, b, bl, i)
	var path := str(DB.building(b.type).get("script", ""))
	if path != "":
		var s = script_for(path)
		if s != null and s.has_method("on_event"):
			s.on_event(g, b, name)


static func _fire(g, b, bl: Dictionary, i: int) -> void:
	var key := "cd%d" % i
	var now := Time.get_ticks_msec() / 1000.0
	if now < float(b.bstate.get(key, -1000.0)):
		return
	b.bstate[key] = now + float(bl.get("cooldown", 0.0))
	g.console.run_actions(bl.get("actions", []), {"x": b.cell.x, "z": b.cell.y})


## Скрипт мода: GDScript из файла проекта или мода. Ошибка в скрипте не роняет игру.
static func script_for(path: String):
	if _scripts.has(path):
		return _scripts[path]
	var inst = null
	# A-1 r12: код — только из .gd (установка чужого мода .gd отбрасывает; раньше readme.txt с кодом выполнялся)
	if path.get_extension().to_lower() != "gd":
		DB.errors.append("Скрипт %s: нужен файл .gd" % path)
		_scripts[path] = null
		return null
	var full := DB.find_file(path) if not path.begins_with("res://") else path
	if FileAccess.file_exists(full):
		var gs := GDScript.new()
		gs.source_code = FileAccess.get_file_as_string(full)
		if gs.reload() == OK:
			inst = gs.new()
		else:
			DB.errors.append("Скрипт %s: ошибка в коде" % path)
	_scripts[path] = inst
	return inst


## A-3 r9: очки Утилизатора за предмет. То, что продаёт магазин утилизации, сжигается не дороже половины
## своей цены в купонах (раньше 2 купона → 50 патронов → 9 купонов, бесконечный рост).
static var _shop_cap := {}
static var _shop_rev := -1

static func sink_points(id: String, coupon_pts: float) -> float:
	var it: Dictionary = DB.item(id)
	var v := float(it.get("sink", it.get("price", 1)))
	_shop_build()
	if _shop_cap.has(id):
		v = minf(v, float(_shop_cap[id]) * coupon_pts * 0.5)
	return v


## A-2 r10: товар магазина утилизации продаётся не дороже, чем стоят его купоны в кредитах (иначе брёвна → купоны → ТВЭЛ → станция).
static func shop_sell_cap(id: String) -> float:
	_shop_build()
	if not _shop_cap.has(id):
		return INF
	return float(_shop_cap[id]) * float(econ().get("coupon_cr", 15.0))


static func _shop_build() -> void:
	if _shop_rev != DB.revision:
		_shop_rev = DB.revision
		_shop_cap = {}
		for rid in DB.data.recipes:
			var r: Dictionary = DB.data.recipes[rid]
			var cin := int(r.get("in", {}).get("sink_coupon", 0))
			if cin <= 0:
				continue
			for o in r.get("out", {}):
				var per := float(cin) / maxf(1.0, float(r.out[o]))
				_shop_cap[o] = minf(float(_shop_cap.get(o, INF)), per)
		# A-4 r11: то, что крафтится из дешёвых товаров магазина (сухпаёк из консервов и ягод), тоже не дороже
		# своего сырья в купонах (раньше крафт снимал потолок: 30 купонов → 86)
		for _pass in 5:
			for rid in DB.data.recipes:
				var r: Dictionary = DB.data.recipes[rid]
				var ins: Dictionary = r.get("in", {})
				if ins.has("sink_coupon"):
					continue
				var cheap := false
				for i in ins:
					if _shop_cap.has(i) and float(_shop_cap[i]) * 100.0 < _own_value(i):
						cheap = true
				if not cheap:
					continue
				var v := 0.0
				for i in ins:
					v += float(ins[i]) * minf(float(_shop_cap.get(i, INF)), _own_value(i) / 100.0)
				for o in r.get("out", {}):
					var per := v / maxf(1.0, float(r.out[o]))
					if per * 100.0 < _own_value(o) and per < float(_shop_cap.get(o, INF)):
						_shop_cap[o] = per


static func _own_value(id: String) -> float:
	var it: Dictionary = DB.item(id)
	return float(it.get("sink", it.get("price", 1)))
