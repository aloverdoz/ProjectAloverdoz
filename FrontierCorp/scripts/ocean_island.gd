extends RefCounted

const DRIFT_GOODS = preload("res://scripts/ocean_fishing.gd").GOODS
const OFFERINGS := ["iron_ingot", "gear", "iron_plate", "copper_ingot", "wire", "concrete", "reinforced_plate", "steel", "steel_beam", "circuit"]
const PERIOD := 10
var game
var prices := {}
var due := 11
var request := {}
var paid := {}
var shore: Array = []
var shore_indices := {}
var fishing
var door: Node3D
var door_time := 0.
var weather_clock := 0.

func _init(g) -> void:
	game = g
	fishing = preload("res://scripts/ocean_fishing.gd").new(g)

func read_state(data: Dictionary) -> void:
	prices = data.get("prices", {}).duplicate(true)
	for n in prices:
		for item in prices[n]:
			prices[n][item] = int(prices[n][item])
	request = data.get("request", {}).duplicate(true)
	paid = data.get("paid", {}).duplicate(true)
	due = int(data.get("due", 11))

func state() -> Dictionary:
	return {"prices":prices, "request":request, "paid":paid, "due":due}

func setup(data: Dictionary) -> void:
	read_state(data)
	refresh_coast()
	if request.is_empty() and not Net.is_client():
		new_request()
	fishing.setup(data.get("drift", []))

func refresh_coast() -> void:
	shore.clear()
	shore_indices.clear()
	for c in game.world.island_cells: update_edge(c)

func update_edge(c: Vector2i) -> void:
	var land: Dictionary = game.world.island_cells
	var exposed: bool = land.has(c) and Factory.DIRS.any(func(d): return not land.has(c+d))
	if exposed and not shore_indices.has(c):
		shore_indices[c] = shore.size()
		shore.append(c)
	elif not exposed and shore_indices.has(c):
		var i: int = shore_indices[c]
		var last: Vector2i = shore.back()
		shore[i] = last
		shore_indices[last] = i
		shore.pop_back()
		shore_indices.erase(c)

func ring(c: Vector2i) -> int:
	var d: Vector2i = (c - game.world.center).abs()
	return maxi(1, maxi(d.x, d.y) - 2)

func cost(n: int) -> Dictionary:
	if prices.has(str(n)):
		return prices[str(n)]
	if n <= 8:
		var common := ["branch","leaves","fiber","stone","log"]
		var item: String = common[0]
		for k in common:
			if game.factory.available(k)>game.factory.available(item): item=k
		return {item:1}
	var tier := floori(log(float(n-7))/log(2.))
	var price := {"log":1+tier,"stone":1+tier}
	if n >= 17: price["iron_ingot"] = tier-2
	return price

func set_price(n: int, value) -> String:
	if not value is Dictionary or n < 1:
		return "Укажите номер ряда и набор ресурсов"
	var valid := {}
	for k in value:
		var amount = value[k]
		if not DB.data.items.has(k) or typeof(amount) not in [TYPE_INT,TYPE_FLOAT] or float(amount) != floorf(float(amount)) or float(amount) < 1 or float(amount) > 100000:
			return "Проверьте код предмета и количество (1–100000)"
		valid[k] = int(amount)
	prices[str(n)] = valid
	sync()
	return "Цена ряда %d сохранена" % n

func issue(c: Vector2i) -> String:
	if not game.world.in_bounds(c) or game.world.island_cells.has(c):
		return "Выберите клетку воды"
	if not Factory.DIRS.any(func(d): return game.world.island_cells.has(c+d)):
		return "Нужна общая сторона с островом"
	for k in cost(ring(c)):
		if game.factory.available(k) < int(cost(ring(c))[k]):
			return "Не хватает материалов"
	return ""

func expand(c: Vector2i) -> bool:
	var why := issue(c)
	if why != "":
		game.notify(why, Color.ORANGE)
		return false
	game.factory.pay(cost(ring(c)))
	change_land([c], [])
	sync([c], [])
	return true

func sync(added := [], removed := []) -> void:
	if Net.is_host():
		Net._self().rpc("shore_event", state(), added, removed)

func reachable() -> Dictionary:
	var known := {}
	for id in DRIFT_GOODS:
		known[id] = true
	var stations := {"hand":true}
	for b in game.factory.all:
		if not b.dead and b.beh in ["station", "crafter"]:
			stations[b.p("station", "")] = true
	for c in game.world.deposit:
		var id: String = game.world.deposit_item(c)
		var miner = game.factory.grid.get(c)
		var mined: bool = miner != null and miner.beh == "miner" and miner.recipe == id
		if id != "" and not DB.is_fluid(id) and (game.world.can_mine(c) or mined):
			known[id] = true
	var changed := true
	while changed:
		changed = false
		for rid in DB.data.recipes:
			var r: Dictionary = DB.data.recipes[rid]
			if Tech.recipe_locked(rid) or not DB.recipe_known(rid) or not r.get("stations", []).any(func(s): return stations.has(s)):
				continue
			var inputs: Dictionary = r.get("in", {})
			if inputs.is_empty() or not inputs.keys().all(func(k): return known.has(k)):
				continue
			for id in r.get("out", {}):
				if not known.has(id):
					known[id] = true
					changed = true
	return known

func new_request() -> void:
	request.clear()
	paid.clear()
	var known := reachable()
	var pool := OFFERINGS.filter(func(k): return known.has(k))
	var industrial := not pool.is_empty()
	if pool.is_empty():
		pool = DRIFT_GOODS.duplicate()
	pool.shuffle()
	var count := mini(pool.size(), 2 if due <= 11 else randi_range(1, 3))
	for i in count:
		request[pool[i]] = (mini(100,20 + 10*floori(float(due)/10)) if industrial else randi_range(5,12))
		paid[pool[i]] = 0

func complete() -> bool:
	return not request.is_empty() and request.keys().all(func(k): return int(paid.get(k,0)) >= int(request[k]))

func deliver() -> bool:
	if game.factory.hq == null or (not game.strategy and World.dist(game.player.position,game.factory.hq.center()) > 11.):
		return false
	var sent := {}
	for k in request:
		var n := mini(int(request[k])-int(paid.get(k,0)),game.factory.available(k))
		if n > 0:
			sent[k] = n
			paid[k] = int(paid.get(k,0))+n
	game.factory.pay(sent)
	game.notify("Дар принят. Берег защищён до смены задания." if complete() else ("Часть дара принята" if not sent.is_empty() else "Подходящих припасов пока нет"), UI.ACCENT)
	sync()
	return not sent.is_empty()

func description() -> String:
	var lines := PackedStringArray()
	for k in request:
		lines.append("%s  %d / %d" % [DB.item_name(k), paid.get(k,0),request[k]])
	return "Прилив в начале дня %d · осталось %d дн.\n%s\n%s" % [due,maxi(0,due-game.day_n),"  ·  ".join(lines),"Берег защищён." if complete() else "Невыполнение смоет берег вместе с постройками."]

func deadline() -> void:
	while game.day_n >= due and not game.game_over:
		var lost := []
		if not complete():
			lost = shore.duplicate()
			change_land([], lost)
			game.notify("Прилив смыл береговых клеток: %d" % lost.size(), Color.CORAL)
		due += PERIOD
		if not game.game_over:
			new_request()
			game.notify("Древняя плита открыла новый заказ", UI.ACCENT)
		sync([], lost)

func change_land(added: Array, removed: Array) -> void:
	var w = game.world
	var f = game.factory
	var cleared := {}
	for c in removed:
		cleared[c] = true
	# Decide the entire lost shoreline before touching any cells or footprints.
	var slab_lost: bool = f.hq != null and cleared.has(f.hq.cell)
	for c in removed:
		if f.grid.has(c):
			f.remove(f.grid[c])
		for b in f.found.get(c, []).duplicate():
			f.remove(b)
		w.remove_node(c)
	if not cleared.is_empty():
		for origin in w.ordered_fields.keys():
			var footprint: Array = w.field_cells(origin, int(w.ordered_fields[origin][1]))
			if footprint.any(func(c): return cleared.has(c)):
				for c in footprint:
					w.set_deposit(c,-1)
					w.dep_override.erase(c)
				w.ordered_fields.erase(origin)
				w.pending_strikes.erase(origin)
	for c in removed:
		if w.deposit.has(c):
			w.set_deposit(c,-1)
		w.set_land(c,false)
	if not cleared.is_empty():
		w.respawns = w.respawns.filter(func(r): return not cleared.has(r.cell))
	for c in added:
		w.set_land(c,true)
	w.rebuild_shore()
	for changed in [added,removed]:
		for c in changed:
			update_edge(c)
			for d in Factory.DIRS: update_edge(c+d)
	if slab_lost:
		f.hq = null
		if w.island_cells.is_empty():
			if not game.game_over: game.on_hq_destroyed()
			return
		var spots: Array = w.island_cells.keys()
		spots.sort_custom(func(a,b): return a.distance_squared_to(w.center)<b.distance_squared_to(w.center))
		var free := spots.filter(func(c): return not f.grid.has(c))
		if free.is_empty():
			# Surviving machines keep their tiles. The base has lost its slab.
			game.on_hq_destroyed()
			return
		f.place("tide_slab",free[0],0)
	if not removed.is_empty() and cleared.has(World.world_to_cell(game.player.position)):
		game.player.position = landing()

func landing() -> Vector3:
	var w = game.world
	var p: Vector2i = game.factory.hq.cell if game.factory.hq != null else w.center
	var best: Vector2i = p
	var dist := INF
	for c in w.island_cells:
		var d: float = p.distance_squared_to(c)
		if d < dist and not game.factory.grid.has(c) and not w.blocks(c):
			best = c
			dist = d
	var pos := World.cell_to_world(best)
	pos.y = w.h_cell(best)
	return pos

func sheltered(p: Vector3) -> bool:
	var c := World.world_to_cell(p)
	for d in [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP]:
		var b = game.factory.grid.get(c+d)
		if b != null and b.type == "shore_canopy":
			var local: Vector3 = game.factory._xform(b).affine_inverse() * p
			if local.x >= -.68 and local.x <= 2.44 and absf(local.z) <= 1. and local.y < 2.65:
				return true
	return false

func fire_weather(dt: float, rain: float) -> void:
	for b in game.factory.lights:
		if b.type != "campfire" or b.bstate.get("extinguished",false):
			continue
		if rain > .12 and not sheltered(b.center()):
			b.bstate["wet"] = float(b.bstate.get("wet",0.)) + dt*rain
			if b.bstate.wet >= 4.:
				set_fire(b,false)
		else:
			b.bstate.erase("wet")

func set_fire(b, lit: bool) -> void:
	b.bstate["extinguished"] = not lit
	b.bstate.erase("wet")
	fire_visual(b,lit)
	if Net.is_host():
		Net._self().rpc("shore_fire",b.cell,lit)

func fire_visual(b, lit: bool) -> void:
	var renderer: PartRenderer = game.factory.renderer(b.type)
	for i in renderer.parts_with_role("flame"):
		var local: Transform3D = renderer.parts[i].local
		if not lit:
			local.basis = local.basis.scaled(Vector3.ONE*.001)
			local.origin = Vector3.ZERO
		renderer.set_part_xform(b,i,local)
	if not lit and b.light: b.light.hide()

func relight(b) -> bool:
	if b == null or b.dead or b.type != "campfire" or not b.bstate.get("extinguished",false):
		return false
	if game.events.rain > .12 and not sheltered(b.center()):
		game.notify("Дождь заливает костёр. Поверните навес полотном к огню.", Color.ORANGE)
		return false
	if game.factory.available("branch") < 1:
		game.notify("Для розжига нужна ветка", Color.ORANGE)
		return false
	game.factory.pay({"branch":1})
	set_fire(b,true)
	return true

func wave_origin() -> Vector3:
	if shore.is_empty():
		return game.player.position
	var open := shore.filter(func(c): return not game.factory.grid.has(c) and not game.world.blocks(c))
	var cell: Vector2i = shore.pick_random() if open.is_empty() else open.pick_random()
	show_door(cell)
	if Net.is_host():
		Net._self().rpc("shore_door",cell)
	return World.cell_to_world(cell) + Vector3.UP * game.world.h_cell(cell)

func show_door(c: Vector2i) -> void:
	if not is_instance_valid(door):
		door = ModelLib.make_node("ruin_arch")
		game.add_child(door)
		door.scale = Vector3.ONE * .56
	door.position = World.cell_to_world(c)+Vector3.UP * game.world.h_cell(c)
	door.show()
	door_time = 10.

func tick(dt: float) -> void:
	fishing.tick(dt)
	if door_time > 0.:
		door_time -= dt
		if door_time <= 0.: door.hide()
	if not Net.is_client():
		deadline()
		weather_clock += dt
		if weather_clock >= 1.:
			fire_weather(weather_clock,game.events.rain)
			weather_clock = 0.
