class_name DemoSetup
extends RefCounted
## Готовые сценарии для проверки и скриншотов (аргументы --demo, --stress=N, --test=имя).


static func nearest_deposit(game, item: String, around: Vector2i, avoid: Array = [], min_d := 0.0) -> Vector2i:
	var best := around
	var bd := INF
	for c in game.world.deposit:
		if game.world.deposit_item(c) != item:
			continue
		var d: float = Vector2(c - around).length()
		if avoid.any(func(a): return Vector2(World.wc(c - a + Vector2i(World.wrap_w, World.wrap_w) / 2) - Vector2i(World.wrap_w, World.wrap_w) / 2).length() < min_d):
			continue
		if d < bd and game.factory.can_place("miner", c) == "":
			bd = d
			best = c
	return best


static func _cnt_arr(arr, id: String) -> int:
	var n := 0
	if arr is Array:
		for e in arr:
			if e is Dictionary and str(e.get("id", "")) == id:
				n += int(e.get("n", 0))
			elif e is Array and e.size() >= 2 and str(e[0]) == id:
				n += int(e[1])
	return n

static func put(game, t: String, c: Vector2i, d: int):
	c = World.wc(c)
	for fc in game.factory.footprint(t, c):
		game.world.remove_node(World.wc(fc))
	if game.factory.can_place(t, c) != "":
		return null
	return game.factory.place(t, c, d)



## Удалить папку со всем содержимым (уборка после проверок).
static func _rm_tree(p: String) -> void:
	var d := DirAccess.open(p)
	if d == null:
		return
	for fn in d.get_files():
		DirAccess.remove_absolute(p.path_join(fn))
	for sub in d.get_directories():
		_rm_tree(p.path_join(sub))
	DirAccess.remove_absolute(p)


## Поставить здание рядом с клеткой: если место занято или вода — ищет поблизости.
static func put_near(game, t: String, c: Vector2i, d := 0):
	for r in range(0, 12):
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				var b = put(game, t, c + Vector2i(dx, dz) * 2, d)
				if b != null:
					return b
	return null


## Нефтяной промысел для проверки и скриншота: качалка → трубы (+бак) → нефтезавод → топливный генератор.
static func fluid_layout(game, base: Vector2i) -> Dictionary:
	var f = game.factory
	var w = game.world
	game.flags["free_build"] = true
	var lvl: float = w.h_cell(base)
	for dx in range(-2, 15):
		for dz in range(-3, 7):
			var c := World.wc(base + Vector2i(dx, dz))
			w.remove_node(c)
	for k in 3:
		w.paint_height(base + Vector2i(6, 1), 14.0, "flatten", 1.0, lvl)
	var oil_i := -1
	for i in w.deposits.size():
		if str(w.deposits[i].get("item", "")) == "oil":
			oil_i = i
	for dx in 2:
		for dz in 2:
			w.set_deposit(base + Vector2i(dx, dz), oil_i)
	var out := {}
	out["pump"] = put(game, "oil_pump", base, 0)
	out["pipes"] = []
	for x in range(2, 6):
		out.pipes.append(put(game, "pipe", base + Vector2i(x, 0), 0))
	out["tank"] = put(game, "tank", base + Vector2i(3, 1), 0)
	out["ref"] = put(game, "refinery", base + Vector2i(6, 0), 0)
	if out.ref:
		f.set_recipe(out.ref, "refine_fuel")
	out.pipes.append(put(game, "pipe_mk2", base + Vector2i(8, 0), 0))
	out.pipes.append(put(game, "pipe_mk2", base + Vector2i(9, 0), 0))
	out["gen"] = put(game, "fuel_generator", base + Vector2i(10, 0), 0)
	out["belt"] = put(game, "belt", base + Vector2i(2, 1), 0)
	out["pack"] = put(game, "packager", base + Vector2i(9, -2), 3)
	out.pipes.append(put(game, "pipe_mk2", base + Vector2i(9, -1), 0))
	return out

## Лента от start до target: сначала по X, потом по Z (повороты рисуются сами).
static func belt_path(game, start: Vector2i, target: Vector2i) -> void:
	var c := start
	var guard := 0
	while c != target and guard < 200:
		guard += 1
		var step: Vector2i
		if c.x != target.x:
			step = Vector2i(signi(target.x - c.x), 0)
		else:
			step = Vector2i(0, signi(target.y - c.y))
		put(game, "belt", c, Factory.DIRS.find(step))
		c += step


## Мини-база: бур → лента с поворотами → печь → лента → штаб; генератор, опоры, турели, ящик.
static func build(game) -> void:
	var hq: Vector2i = game.factory.hq.cell
	game.factory.hq.inv.add("coal", 40)
	game.factory.hq.inv.add("ammo", 200)
	for k in ["log", "stone", "plank", "iron_ingot", "gear", "wire", "glass", "iron_plate"]:
		game.player.inv.add(k, 40)
	game.player.inv.add("stone_axe", 1)
	game.player.inv.add("blaster", 1)
	game.player.inv.add("ammo", 100)
	game.player.inv.add("berry", 8)
	var gen = put(game, "generator", hq + Vector2i(-3, 4), 0)
	if gen:
		gen.fuel.add("coal", 30)
	put(game, "pole", hq + Vector2i(-3, 9), 0)
	var ore := nearest_deposit(game, "iron_ore", hq)
	var m = put(game, "miner", ore, 0)
	# лента: от бура вправо, потом вниз к печи — с поворотом
	var p := ore + Vector2i(1, 0)
	var f_cell := ore + Vector2i(4, 3)
	belt_path(game, p, Vector2i(f_cell.x, p.y))
	belt_path(game, Vector2i(f_cell.x, p.y), f_cell)
	var fur = put(game, "furnace", f_cell, 1)
	if fur:
		fur.fuel.add("coal", 20)
	belt_path(game, f_cell + Vector2i(0, 1), f_cell + Vector2i(0, 4))
	put(game, "chest", f_cell + Vector2i(0, 4), 1)
	# декоративная линия с поворотами у штаба
	var s := hq + Vector2i(5, -2)
	belt_path(game, s, s + Vector2i(4, 0))
	belt_path(game, s + Vector2i(4, 0), s + Vector2i(4, 4))
	belt_path(game, s + Vector2i(4, 4), s + Vector2i(0, 4))
	put(game, "turret", hq + Vector2i(-3, -3), 0)
	put(game, "turret", hq + Vector2i(5, 6), 0)
	put(game, "workbench", hq + Vector2i(-2, 7), 0)
	put(game, "workshop", hq + Vector2i(0, 7), 0)
	put(game, "lamp", hq + Vector2i(3, 4), 0)
	put(game, "solar", hq + Vector2i(-5, 4), 0)
	put(game, "assembler", hq + Vector2i(-6, 0), 0)
	game.player.position = World.cell_to_world(hq + Vector2i(3, 6))
	game.cam_focus = game.player.position
	game.day_t = 0.42


## Витрина для картинок магазина Steam: цеха с лентами, энергоблок, кольцо обороны, роботы снаружи.
static func steam_showcase(game) -> void:
	game.flags["god"] = true
	game.flags["free_build"] = true
	var f = game.factory
	var hq: Vector2i = f.hq.cell
	var o := hq + Vector2i(0, 4)
	for dx in range(-26, 27):
		for dz in range(-24, 20):
			game.world.remove_node(World.wc(o + Vector2i(dx, dz)))
	var items := ["iron_ore", "copper_ore", "coal", "stone"]
	var outs := ["iron_ingot", "copper_ingot", "iron_plate", "gear"]
	# четыре производственные линии: ящик → лента → плавильня → лента → сборщик → лента → контейнер
	for i in 4:
		var y := o.y + 3 + i * 3
		var x0 := o.x - 14
		put(game, "container", Vector2i(x0, y), 0)
		belt_path(game, Vector2i(x0 + 1, y), Vector2i(x0 + 6, y))
		put(game, "smelter_mk2", Vector2i(x0 + 6, y), 0)
		belt_path(game, Vector2i(x0 + 7, y), Vector2i(x0 + 11, y))
		put(game, "assembler_mk2", Vector2i(x0 + 11, y), 0)
		belt_path(game, Vector2i(x0 + 12, y), Vector2i(x0 + 15, y))
		put(game, "container", Vector2i(x0 + 15, y), 0)
		for k in range(1, 15):
			var b = f.building_at(World.wc(Vector2i(x0 + k, y)))
			if b and b.type == "belt" and k % 2 == 0:
				f.set_item(b, items[i] if k < 6 else outs[i])
	# энергоблок справа
	for i in 3:
		var g = put(game, "coal_generator", o + Vector2i(8 + i * 2, 3), 0)
		if g and g.fuel:
			g.fuel.add("coal", 50)
	for i in 6:
		put(game, "solar", o + Vector2i(8 + (i % 3) * 2, 6 + (i / 3) * 2), 0)
	for i in 3:
		put(game, "wind_turbine", o + Vector2i(15, 3 + i * 3), 0)
	put(game, "battery_block", o + Vector2i(8, 11), 0)
	put(game, "battery_block", o + Vector2i(10, 11), 0)
	put(game, "research_lab", o + Vector2i(-6, -3), 0)
	put(game, "radar_tower", o + Vector2i(-10, -4), 0)
	put(game, "drone_port", o + Vector2i(6, -3), 0)
	put(game, "tank", o + Vector2i(12, -3), 0)
	# кольцо обороны
	var tur := ["gatling_turret", "missile_turret", "cannon_turret", "laser_turret", "tesla_coil", "flame_turret", "plasma_turret", "sniper_tower"]
	for i in 14:
		var a := -PI + i * PI / 13.0
		put_near(game, tur[i % tur.size()], o + Vector2i(roundi(cos(a) * 19), roundi(sin(a) * 14) - 4))
	f.auto_wire_all()
	f.power_dirty = true
	for b in f.all:
		if b.type in ["smelter_mk2", "assembler_mk2", "coal_generator", "wind_turbine", "research_lab", "radar_tower"]:
			b.active = true
			f.renderer(b.type).set_active(b, 1.0)
	# роботы идут к базе с севера
	var kinds := ["crawler", "brute", "runner", "sniper", "bomber", "guard", "crawler", "brute", "runner", "crawler"]
	for i in kinds.size():
		var me = game.enemies.spawn(kinds[i], World.cell_to_world(o + Vector2i(-18 + i * 4, -23 + (i % 3) * 2)))
		if me:
			me.speed = 0.0
	game.player.position = World.cell_to_world(o + Vector2i(-2, -3))
	game.cam_focus = game.player.position
	game.day_t = 0.38


## Ленты для проверки вида: одиночный поворот, змейка, зигзаг, U-разворот, с грузом.
static func belts(game, focus := 0) -> void:
	var hq: Vector2i = game.factory.hq.cell
	var s := hq + Vector2i(6, -8)
	for x in range(-2, 16):
		for z in range(-2, 12):
			game.world.remove_node(World.wc(s + Vector2i(x, z)))
	# одиночный поворот
	belt_path(game, s, s + Vector2i(3, 0))
	belt_path(game, s + Vector2i(3, 0), s + Vector2i(3, 4))
	# змейка
	var z0 := s + Vector2i(6, 0)
	var pts := [z0, z0 + Vector2i(2, 0), z0 + Vector2i(2, 2), z0 + Vector2i(0, 2), z0 + Vector2i(0, 4), z0 + Vector2i(3, 4), z0 + Vector2i(3, 7)]
	for i in pts.size() - 1:
		belt_path(game, pts[i], pts[i + 1])
	put(game, "belt", pts[pts.size() - 1], 1)
	# зигзаг (лесенка)
	var c := s + Vector2i(0, 7)
	for i in 4:
		put(game, "belt", c, 0)
		put(game, "belt", c + Vector2i(1, 0), 1)
		c += Vector2i(1, 1)
	put(game, "belt", c, 0)
	# груз
	var src = put(game, "chest", s + Vector2i(-1, 0), 0)
	if src:
		src.inv.add("iron_ore", 200)
	var src2 = put(game, "chest", z0 + Vector2i(-1, 0), 0)
	if src2:
		src2.inv.add("copper_ore", 200)
	game.flags["no_waves"] = true
	var fc: Vector2i = [s + Vector2i(4, 10), s + Vector2i(2, 2), z0 + Vector2i(1, 3), s + Vector2i(2, 9)][focus]
	game.player.position = World.cell_to_world(fc) + Vector3(0, 0, 3)
	game.cam_focus = game.player.position
	game.day_t = 0.4


## Стыки лент со зданиями: ящик, плавильня, контейнер, разделитель, штаб, вход сбоку.
static func ports(game, focus := 0) -> void:
	var hq: Vector2i = game.factory.hq.cell
	var s := hq + Vector2i(-14, 4)
	for x in range(-2, 14):
		for z in range(-2, 12):
			game.world.remove_node(World.wc(s + Vector2i(x, z)))
	# ящик -> лента -> плавильня -> лента -> контейнер
	var src = put(game, "chest", s, 0)
	if src:
		src.inv.add("iron_ore", 200)
	belt_path(game, s + Vector2i(1, 0), s + Vector2i(3, 0))
	put(game, "belt", s + Vector2i(3, 0), 0)
	put(game, "smelter", s + Vector2i(4, 0), 0)
	belt_path(game, s + Vector2i(5, 0), s + Vector2i(7, 0))
	put(game, "belt", s + Vector2i(7, 0), 0)
	put(game, "container", s + Vector2i(8, 0), 0)
	# ящик выдаёт вниз, лента идёт вбок, на разделитель и в два ящика
	var src2 = put(game, "chest", s + Vector2i(0, 3), 1)
	if src2:
		src2.inv.add("copper_ore", 200)
	put(game, "belt", s + Vector2i(0, 4), 0)
	belt_path(game, s + Vector2i(1, 4), s + Vector2i(3, 4))
	put(game, "belt", s + Vector2i(3, 4), 0)
	put(game, "splitter", s + Vector2i(4, 4), 0)
	put(game, "belt", s + Vector2i(4, 5), 1)
	put(game, "furnace", s + Vector2i(4, 6), 1)
	put(game, "belt", s + Vector2i(5, 4), 0)
	put(game, "chest", s + Vector2i(6, 4), 0)
	# лента в штаб
	var to_hq := hq + Vector2i(0, 1)
	put(game, "belt", to_hq + Vector2i(-2, 0), 0)
	put(game, "belt", to_hq + Vector2i(-1, 0), 0)
	game.flags["no_waves"] = true
	var fc: Vector2i = [s + Vector2i(4, 3), hq + Vector2i(-1, 1), s + Vector2i(1, 1), s + Vector2i(4, 4)][focus]
	game.player.position = World.cell_to_world(fc) + Vector3(0, 0, 5)
	game.cam_focus = game.player.position
	game.day_t = 0.4


## Разные предметы на лентах и на земле (у каждого своя модель).
## Красивый уголок для скриншотов: опушка с цветами, сжигатель биомассы, ветки и кусты, которые можно собрать.
## Энергосеть для снимков: опоры с проводами, ветряки, угольный генератор, аккумулятор, плавильни.
## focus: 0 — вид сверху, 1 — окно опоры с графиком, 2 — режим «Провода» с проводом в руке.
## Холм у штаба: площадка из фундаментов, ярус выше, рампа, машины и стена (для снимков).
static func terrain_demo(game) -> void:
	var f = game.factory
	var w = game.world
	var hq: Vector2i = f.hq.cell
	game.flags["free_build"] = true
	var best := hq
	var bd := INF
	for x in range(0, w.W, 2):
		for z in range(0, w.W, 2):
			var c := Vector2i(x, z)
			if w.h_cell(c) < 2.0:
				continue
			var d: float = Vector2(c - hq).length()
			if d < bd:
				var ok := true
				for dx in range(-6, 7, 2):
					for dz in range(-6, 7, 2):
						if w.water_at(c + Vector2i(dx, dz)) or w.nest_cells.has(World.wc(c + Vector2i(dx, dz))):
							ok = false
				if ok:
					bd = d
					best = c
	var s := best - Vector2i(4, 4)
	for x in range(-2, 12):
		for z in range(-2, 12):
			w.remove_node(World.wc(s + Vector2i(x, z)))
	# площадка 3×3 из фундаментов 2×2
	for i in 3:
		for j in 3:
			game.cmd("place", {"type": "found_2", "cell": s + Vector2i(i * 2, j * 2), "dir": 0})
	# ярус выше и рампа к нему
	game.cmd("place", {"type": "found_2", "cell": s + Vector2i(2, 0), "dir": 0})
	game.cmd("place", {"type": "found_2", "cell": s + Vector2i(4, 0), "dir": 0})
	game.cmd("place", {"type": "found_ramp", "cell": s + Vector2i(3, 2), "dir": 3})
	game.cmd("place", {"type": "found_ramp", "cell": s + Vector2i(6, 2), "dir": 2})
	var sm = game.cmd("place", {"type": "smelter", "cell": s + Vector2i(0, 4), "dir": 0})
	game.cmd("place", {"type": "assembler", "cell": s + Vector2i(4, 0), "dir": 1})
	game.cmd("place", {"type": "chest", "cell": s + Vector2i(2, 1), "dir": 0})
	game.cmd("place", {"type": "lamp", "cell": s + Vector2i(5, 5), "dir": 0})
	for x in range(0, 6):
		game.cmd("place", {"type": "found_wall", "cell": s + Vector2i(x, 5), "dir": 0})
	for z in range(4):
		game.cmd("place", {"type": "belt", "cell": s + Vector2i(1, 4 - z - 1) + Vector2i(0, 0), "dir": 3})
	if sm:
		sm.inv.add("iron_ore", 20)
	var pl = game.player
	pl.position = World.cell_to_world(s + Vector2i(3, 8))
	pl.position.y = f.support_at(pl.position)
	game.cam_focus = pl.position
	game.flags["free_build"] = false


static func power_demo(game, focus := 0) -> void:
	var f = game.factory
	var hq: Vector2i = f.hq.cell
	var s := hq + Vector2i(6, -2)
	for x in range(-1, 16):
		for z in range(-4, 9):
			game.world.remove_node(World.wc(s + Vector2i(x, z)))
	var p1 = put(game, "pole", s + Vector2i(1, 1), 0)
	var p2 = put(game, "pole", s + Vector2i(7, 1), 0)
	var c1 = put(game, "coal_generator", s + Vector2i(9, -2), 0)
	if c1:
		c1.fuel.add("coal", 40)
	var w1 = put(game, "wind_turbine", s + Vector2i(11, 3), 0)
	var w2 = put(game, "wind_turbine", s + Vector2i(13, 0), 0)
	var bt = put(game, "battery_block", s + Vector2i(5, 4), 0)
	var sm1 = put(game, "smelter", s + Vector2i(3, -2), 0)
	var sm2 = put(game, "smelter", s + Vector2i(3, 4), 0)
	var as1 = put(game, "assembler", s + Vector2i(8, 5), 0)
	for b in [sm1, sm2]:
		if b:
			b.inv.add("iron_ore", 30)
	f._rebuild_power()
	# история графика: прогоняем сеть полминуты
	for k in 40:
		game.play_time += 1.0
		for b in [sm1, sm2, as1]:
			if b:
				b.want = k % 9 < 6
		f._power(1.0)
		f.hist_t = 1.0
	if bt:
		bt.energy = 900.0
	game.player.position = World.cell_to_world(s + Vector2i(5, 2))
	game.cam_focus = game.player.position
	game.cam_dist_target = 30.0
	if focus == 1 and p1:
		game.hud.open_building(p1)
	elif focus == 2:
		game.ui_action("wire")
		game.wire_from = p2
		var extra = put(game, "smelter", s + Vector2i(10, 7), 0)
		if extra:
			f.unwire(extra)


static func art(game, focus := 0) -> void:
	var w = game.world
	var hq: Vector2i = game.factory.hq.cell
	var best := hq + Vector2i(0, 12)
	var found := false
	for r in range(14, 70, 2):
		for k in 24:
			var a := k / 24.0 * TAU
			var c := World.wc(hq + Vector2i(roundi(cos(a) * r), roundi(sin(a) * r)))
			if w.zone_at(c) == "forest_edge" and not w.water_at(c) and not w.nodes.has(c):
				best = c
				found = true
				break
		if found:
			break
	var s: Vector2i = best
	for x in range(-3, 4):
		for z in range(-3, 4):
			if Vector2i(x, z).length() < 2.5:
				w.remove_node(World.wc(s + Vector2i(x, z)))
	var bb = put(game, "biomass_burner", s, 0)
	if bb:
		bb.fuel.add("biomass", 20)
	put(game, "lamp", s + Vector2i(2, 0), 0)
	put(game, "pole", s + Vector2i(1, 1), 0)
	w.add_node("leaf_bush", s + Vector2i(-2, 2))
	w.add_node("burdock", s + Vector2i(0, 3))
	w.add_node("fallen_branch", s + Vector2i(2, 3))
	w.add_node("brushwood", s + Vector2i(-2, -2))
	w.add_node("burdock", s + Vector2i(3, -2))
	for it in [["leaves", 12], ["biomass", 6], ["branch", 8], ["fiber", 5]]:
		game.player.inv.add(it[0], it[1])
	game.player.position = World.cell_to_world(s + Vector2i(1, 3))
	game.cam_focus = game.player.position
	if focus == 1:
		game.hud.open_building(bb)


## Для снимков: ряд зданий (или ресурсов с префиксом «r:») возле штаба, камера на середине.
static func lineup(game, ids: Array) -> void:
	game.flags["free_build"] = true
	var hq: Vector2i = game.factory.hq.cell
	var step := 2
	for id in ids:
		if DB.data.buildings.has(id):
			step = maxi(step, int(DB.data.buildings[id].get("size", 1)) + 2)
	var n := ids.size()
	var s := hq + Vector2i(-n * step / 2 + 1, 16)
	for x in range(-3, n * step + 3):
		for z in range(-4, 5):
			game.world.remove_node(World.wc(s + Vector2i(x, z)))
	for i in n:
		var id: String = ids[i]
		var c := World.wc(s + Vector2i(i * step, 0))
		if id.begins_with("r:"):
			game.world.add_node(id.substr(2), c)
		elif id.begins_with("e:"):
			var e = game.enemies.spawn(id.substr(2), World.cell_to_world(c))
			if e != null:
				e.guard = true
				e.home = e.pos
				e.yaw = -PI * 0.35
				e.calm_t = 1e9
		elif DB.data.buildings.has(id):
			if str(DB.data.buildings[id].get("behavior", "")) == "miner":
				for di in game.world.deposits.size():
					if str(game.world.deposits[di].get("item", "")) == "iron_ore":
						game.world.set_deposit(c, di)
						break
			if put(game, id, c, 0) == null:
				print("LINEUP ", id, ": ", game.factory.can_place(id, c))
	game.player.position = World.cell_to_world(s + Vector2i(n * step / 2 - 1, 3))
	game.cam_focus = World.cell_to_world(s + Vector2i(n * step / 2, 0))


## 18: для скриншота — мастерская роботов-строителей, стена и лента, часть разрушена (контуры), робот идёт отстраивать.
static func builders18(game) -> void:
	game.flags["free_build"] = true
	var hq: Vector2i = game.factory.hq.cell
	var s := hq + Vector2i(-4, 14)
	for x in range(-4, 14):
		for z in range(-4, 8):
			game.world.remove_node(World.wc(s + Vector2i(x, z)))
	put(game, "builder_bay", s, 0)
	put(game, "builder_bay_mk2", s + Vector2i(0, 3), 0)
	var lost := []
	for x in range(3, 12):
		var w = put(game, "wall", s + Vector2i(x, -2), 0)
		if w and x % 3 == 0:
			lost.append(w)
		var b = put(game, "belt", s + Vector2i(x, 2), 0)
		if b and x % 4 == 1:
			lost.append(b)
	game.flags["free_build"] = false
	for k in ["stone", "iron_plate", "iron_ingot", "plank", "concrete", "steel"]:
		game.factory.hq.inv.add(k, 200)
	for b in lost:
		game.factory.damage(b, 99999.0)
	game.player.position = World.cell_to_world(s + Vector2i(5, 6))
	game.cam_focus = World.cell_to_world(s + Vector2i(6, 1))


## 1.0.8: кадры для скриншотов — залежи разной формы, сканер по этапам, серые здания, режимы.
static func shots19(game, what: String) -> void:
	var hq: Vector2i = game.factory.hq.cell
	var pl = game.player
	match what:
		"deposits":
			var s := hq + Vector2i(-8, 3)
			var deps: Array = DB.data.world.get("deposits", [])
			game.tutorial.skip()
			var i := 0
			for x in range(-2, 20):
				for z in range(-2, 16):
					game.world.remove_node(World.wc(s + Vector2i(x, z)))
			for d in deps:
				var mid := str(d.get("marker", ""))
				if not DB.data.models.has(mid):
					continue
				var c := s + Vector2i((i % 6) * 3, (i / 6) * 3)
				var n := ModelLib.make_node(mid)
				var fp := maxi(1, int(d.get("cells", 1)))
				n.scale = Vector3.ONE * fp
				n.position = World.cell_to_world(c) + Vector3(0, game.world.height_at(World.cell_to_world(c)), 0)
				game.add_child(n)
				var l := Label3D.new()
				l.text = str(DB.item(str(d.get("item", ""))).get("name", ""))
				l.font_size = 40
				l.outline_size = 10
				l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				l.position = n.position + Vector3(0, 2.2, 0)
				game.add_child(l)
				i += 1
			pl.position = World.cell_to_world(s + Vector2i(7, 4)) + Vector3(1, 0, 1)
			game.cam_focus = pl.position
		"scan", "build":
			game.tutorial.skip()
			DB.discovery = true
			DB.researched.clear()
			DB.known.clear()
			for k in ["branch", "stone", "fiber", "log", "plank", "iron_ore"]:
				DB.known[k] = true
			for k in ["branch", "stone", "fiber", "log"]:
				DB.researched[k] = true
			pl.inv.add("plank", 3)
			pl.inv.add("iron_ore", 6)
			game.scanner.prog["plank"] = 2
			if what == "scan":
				game.hud.open("scan")
			else:
				game.hud.build_cat = str(DB.building("chest").get("category", ""))
				game.hud.open("build")
		"wire":
			game.wiring = true
		"demolish":
			game.demolish = true


static func item_belts(game) -> void:
	var hq: Vector2i = game.factory.hq.cell
	var s := hq + Vector2i(6, -8)
	for x in range(-2, 16):
		for z in range(-2, 10):
			game.world.remove_node(World.wc(s + Vector2i(x, z)))
	var groups := [["iron_ore", "copper_ore", "coal", "crystal", "quartz", "sulfur", "stone", "geode"],
		["iron_ingot", "copper_ingot", "steel", "plank", "iron_plate", "gear", "circuit", "wire"],
		["motor", "glass", "concrete", "rope", "battery", "ammo", "medkit", "apple"]]
	for gi in groups.size():
		var row := s + Vector2i(0, gi * 2)
		put(game, "container", row, 0)
		belt_path(game, row + Vector2i(1, 0), row + Vector2i(11, 0))
		put(game, "belt", row + Vector2i(11, 0), 0)
		put(game, "chest", row + Vector2i(12, 0), 0)
		# груз кладём прямо на ленты, чтобы на каждой ехали разные предметы
		for i in 11:
			var bb = game.factory.building_at(World.wc(row + Vector2i(1 + i, 0)))
			if bb and bb.beh == "belt":
				game.factory.set_item(bb, groups[gi][i % groups[gi].size()])
	var ground := ["log", "branch", "mushroom", "berry", "fiber", "fang", "chitin", "goo", "monster_core", "sword", "iron_axe", "water_flask", "jerky", "stim_speed"]
	for i in ground.size():
		game.drops._spawn_real(ground[i], 1, World.cell_to_world(s + Vector2i(2 + i % 7, 6 + i / 7)) + Vector3(0, 0.5, 0))
	game.flags["no_waves"] = true
	game.player.position = World.cell_to_world(s + Vector2i(8, 5))
	game.cam_focus = game.player.position
	game.day_t = 0.4


## Панель быстрого доступа для скриншота: оружие, еда, лекарства и здания.
static func hotbar_demo(game) -> void:
	build(game)
	Prefs.values["hotbar_slots"] = 12
	var p = game.player
	p.inv.slots.fill(null)
	var put_slot := func(i: int, id: String, n: int): p.inv.slots[i] = {"id": id, "n": n}
	put_slot.call(0, "iron_axe", 1)
	put_slot.call(1, "sword", 1)
	put_slot.call(2, "blaster", 1)
	put_slot.call(3, "medkit", 3)
	put_slot.call(4, "berry", 12)
	put_slot.call(5, "grenade", 4)
	put_slot.call(12, "ammo", 80)
	p.hot_builds[6] = "belt"
	p.hot_builds[7] = "miner"
	p.hot_builds[8] = "turret"
	p.hot_builds[9] = "wall"
	p.hot_builds[10] = "lamp"
	p.hot_builds[11] = "medbay"
	p.inv.changed.emit()
	game.hot_select(6)


## Огромный завод для замера производительности.
static func stress(game, n: int) -> void:
	var hq: Vector2i = game.factory.hq.cell
	var side := int(sqrt(float(n) / 2.0))
	var base := hq + Vector2i(8, 8)
	for x in side:
		for z in range(0, side * 2, 2):
			var c := base + Vector2i(x, z)
			var b = put(game, "belt", c, 0)
			if b and x == 0:
				game.factory.set_item(b, "iron_ore")
		put(game, "belt", base + Vector2i(side, 0), 1)
	for z in range(0, side * 2, 2):
		var b0 = game.factory.building_at(base + Vector2i(0, z))
		if b0:
			game.factory.set_item(b0, "copper_ore")
	game.flags["no_waves"] = true


## Большая база для замера скорости: ленты с рудой, машины, турели, фонари, склады, монстры вокруг.
static func big_base(game, belts: int, machines: int, mobs: int) -> void:
	var f = game.factory
	game.flags["free_build"] = true
	stress(game, belts)
	var hq: Vector2i = f.hq.cell
	var kinds := ["assembler", "smelter", "chest", "lamp", "turret", "laser_turret", "generator", "wind_turbine", "pole"]
	var n := 0
	var r := 10
	while n < machines and r < 120:
		for dx in range(-r, r + 1, 2):
			for dz in [-r, r]:
				if n >= machines:
					break
				var c: Vector2i = hq + Vector2i(dx, dz) + Vector2i(-60, 0)
				game.world.remove_node(World.wc(c))
				var b = put(game, kinds[n % kinds.size()], c, 0)
				if b:
					n += 1
					if b.fuel:
						b.fuel.add("coal", 50)
		r += 3
	f.auto_wire_all()
	f.power_dirty = true
	var EN = game.enemies
	for i in mobs:
		var a := randf() * TAU
		var m = EN.spawn(["crawler", "runner", "spitter", "brute", "bomber", "thief", "drone", "guard"][i % 8] if true else "", game.player.position + Vector3(cos(a), 0, sin(a)) * randf_range(25.0, 90.0))
		if m:
			m.hp = 1e6
			m.maxhp = 1e6
	game.flags["no_waves"] = true


## Автотесты: --test=имя. Печатают TEST ... OK / FAIL.
static func test(game, name: String) -> void:
	var tree: SceneTree = game.get_tree()
	game.hud.close_all()
	await _test(game, name, tree)
	print("TEST done frames=", game._frame, " avg_proc_ms=", game._proc_sum / maxi(1, game._frame - 30))
	tree.quit()


static func _test(game, name: String, tree: SceneTree) -> void:
	match name:
		"wiredrop115":
			var pl = game.player
			game.flags["free_build"] = true
			var ws = null
			for off in [Vector2i(6, 6), Vector2i(-8, 6), Vector2i(8, -8)]:
				if ws == null:
					ws = put(game, "workshop", World.world_to_cell(pl.position) + off, 0)
			pl.inv.add("copper_ingot", 10)
			while pl.inv.can_add("log", 1):
				pl.inv.add("log", 1)   # 1.1.16: рюкзак забит — готовое должно уйти в штаб, а не на землю
			var hq_w0: int = game.factory.hq.inv.count("wire")
			print("HUNT inv before ", pl.inv.to_array().filter(func(x): return x != null))
			game.queue_craft("wire", 5, "workshop")
			print("HUNT queue ", game.craft_queue.size())
			game.hud.close_all()
			game.select_build("workbench")
			await tree.create_timer(25.0).timeout
			print("HUNT inv after ", pl.inv.to_array().filter(func(x): return x != null), " drops=", game.drops.list.map(func(d): return [d.id, d.n]))
			var hq_w: int = game.factory.hq.inv.count("wire") - hq_w0
			print("HUNT hq wire +", hq_w, " strategy=", game.strategy)
			var ok_w: bool = game.drops.list.is_empty() and hq_w > 0 if game.strategy else game.drops.list.size() > 0
			print("TEST wiredrop115 ", "OK" if ok_w else "FAIL")
		"fix117_115":
			# 1.1.17: лента не цепляется к станции энергии; ремонт 5 с; авторемонт +10%/мин за уровень
			var f = game.factory
			game.flags["free_build"] = true
			var base: Vector2i = f.hq.cell + Vector2i(14, 6)
			var pole = put(game, "pole", base, 0)
			var bl = put(game, "belt", base + Vector2i(-1, 0), 0)   # dir 0 = +x, смотрит в столб
			var fu = put(game, "furnace", base + Vector2i(0, 6), 0)
			var bl2 = null
			if fu != null:
				for side in 4:
					var c: Vector2i = fu.cell + f.DIRS[side]
					if bl2 == null and fu.pin.has(World.wc(c)):
						bl2 = put(game, "belt", c, (side + 2) % 4)
			# разделитель вплотную к прямой ленте (её начало дальше) — в неё не сыплет
			var lane0: Vector2i = base + Vector2i(0, 12)
			var lane := []
			for k in 5:
				lane.append(put(game, "belt", lane0 + Vector2i(k, 0), 0))   # прямая лента на +x
			var sp = put(game, "splitter", lane0 + Vector2i(2, -1), 0)   # правый выход разделителя — сбоку на середину ленты
			var side_ok := true
			if sp != null and lane[2] != null:
				f.set_item(sp, "stone")
				for i in 30:
					await tree.process_frame
				side_ok = sp.item == "stone"
			await tree.process_frame
			var no_pole: bool = pole != null and bl != null and bl.next == null and f.port_keys.get(bl, []).is_empty()
			var to_fu: bool = bl2 == null or bl2.next == fu
			var rt: float = game.repair_time()
			var ar: Array = [f.auto_repair_pct(1.0), f.auto_repair_pct(3.0), f.auto_repair_pct(5.0)]
			var ok: bool = no_pole and to_fu and side_ok and absf(rt - 5.0) < 0.01 and ar == [10.0, 30.0, 50.0]
			print("TEST fix117_115 split_side=", side_ok, " no_pole=", no_pole, " to_furnace=", to_fu, " repair_t=", rt, " auto=", ar, " ", "OK" if ok else "FAIL")
		"dep118_115":
			# 1.1.19: у штаба по одной залежи железа, меди и камня; другие — не в зоне, но каждая есть сразу за ней; всё видно
			var W = game.world
			var zr: float = W._start_zone_cells()
			var inner: float = zr if zr > 0.0 else 20.0
			var cnt := {}
			var ring := {}
			for c in W.deposit:
				var dv = World.delta(W.cell_to_world(W.center), W.cell_to_world(c))
				var dd: float = Vector2(dv.x, dv.z).length() / World.C
				var it: String = str(W.deposits[W.deposit[c]].get("item", ""))
				if dd < inner:
					cnt[it] = int(cnt.get(it, 0)) + 1
				elif dd < inner + 20.0:
					ring[it] = true
			var patches := {}
			var missing := []
			for idx in W.deposits.size():
				var d0: Dictionary = W.deposits[idx]
				var it2: String = str(d0.get("item", ""))
				var fp: int = W.dep_fp(d0)
				if cnt.has(it2):
					patches[it2] = int(ceil(float(cnt[it2]) / float(maxi(1, fp) * maxi(1, fp))))
				if fp > 0 and int(d0.get("patches", 0)) > 0 and not it2 in ["iron_ore", "copper_ore", "stone"] and not ring.has(it2):
					missing.append(it2)
			var one: bool = int(patches.get("iron_ore", 0)) == 1 and int(patches.get("copper_ore", 0)) == 1 and int(patches.get("stone", 0)) == 1 and patches.size() == 3
			game.tech.done = {"t_start": true}
			game.tech.refresh_locks()
			var none_locked: bool = DB.locked.keys().filter(func(k): return str(k).begins_with("d:")).is_empty()
			var zone_ok: bool = game.zone.blocks == 15
			var ok: bool = one and missing.is_empty() and none_locked and zone_ok
			print("TEST dep118_115 patches=", patches, " ring_missing=", missing, " none_locked=", none_locked, " zone=", game.zone.blocks, " ", "OK" if ok else "FAIL")
		"chest120_115":
			# 1.1.20: конструктор + ящик (составное) — всё сделанное копится в ящике, «забрать» отдаёт в рюкзак
			var f = game.factory
			game.flags["free_build"] = true
			var c: Vector2i = f.hq.cell + Vector2i(16, 12)
			for dx in range(-4, 14):
				for dz in range(-4, 14):
					game.world.remove_node(World.wc(c + Vector2i(dx, dz)))
			var h = put_near(game, "constructor", c, 0)
			c = h.cell
			var ch = put(game, "chest", c + Vector2i(h.size, 0), 0)
			var g = put(game, "generator", c + Vector2i(0, h.size + 1), 0)
			if g.fuel: g.fuel.add("coal", 200)
			print("HUNT why=", f.fz.combo_why(h, ch))
			var ok_f: bool = game.cmd("fuse", {"a": h, "b": ch, "kind": "combo"}) != null
			var hb = h if not h.dead else ch
			var sub = Fusion.chest_of(hb)
			print("HUNT fused=", ok_f, " host=", hb.type, " sub=", sub.type if sub else null, " sub slots=", sub.inv.size() if sub else -1, " xs=", f.fz.sub_xform(hb, 0).basis.get_scale() if sub else null)
			f.auto_wire_all()
			f.power_dirty = true
			f.set_recipe(hb, "iron_rod")
			var t := 0.0
			var counts := []
			while t < 600.0:
				if hb.inv.count("iron_ingot") < 20:
					for k in 5:
						f.accept(hb, "iron_ingot", null)
				f._tick(Factory.TICK)
				t += Factory.TICK
				if int(t * 10) % 600 == 0:
					counts.append([int(t), sub.inv.count("iron_rod"), hb.out.count("iron_rod")])
			var in_chest: int = sub.inv.count("iron_rod")
			print("HUNT counts=", counts)
			var pl = game.player
			for i in pl.inv.slots.size():
				pl.inv.slots[i] = null
			pl.position = hb.center() + Vector3(2, 0, 0)
			game.cmd("take", {"b": hb})
			var got: int = pl.inv.count("iron_rod")
			print("HUNT in_chest=", in_chest, " host_out=", hb.out.count("iron_rod"), " took=", got, " chest after=", sub.inv.count("iron_rod"))
			var ok: bool = in_chest >= 100 and got >= in_chest and f.fz.sub_xform(hb, 0).basis.get_scale().x >= 0.8
			print("TEST chest120_115 ", "OK" if ok else "FAIL")
		"chest_host120_115":
			# сеть: хозяин строит конструктор + ящик (составное), гость (--net_chest_probe) смотрит ящик и забирает
			var N = Net._self()
			var f = game.factory
			game.flags["free_build"] = true
			for i in 400:
				await tree.create_timer(0.1).timeout
				if not N.puppets.is_empty():
					break
			await tree.create_timer(3.0).timeout
			N.room["access"] = "all"
			var c: Vector2i = World.wc(f.hq.cell + Vector2i(16, 12))
			for r in 40:
				var cc: Vector2i = World.wc(f.hq.cell + Vector2i(10 + (r % 8) * 4, 8 + (r / 8) * 4))
				if f.can_place("constructor", cc) == "" and f.can_place("chest", cc + Vector2i(2, 0)) == "" and f.can_place("generator", cc + Vector2i(0, 3)) == "":
					c = cc
					break
			var h = game.cmd("place", {"type": "constructor", "cell": c, "dir": 0})
			h = f.building_at(c)
			var ch = game.cmd("place", {"type": "chest", "cell": c + Vector2i(2, 0), "dir": 0})
			ch = f.building_at(c + Vector2i(2, 0))
			var g = game.cmd("place", {"type": "generator", "cell": c + Vector2i(0, 3), "dir": 0})
			g = f.building_at(c + Vector2i(0, 3))
			print("HUNT host h=", h.cell, " ch=", ch.cell if ch else null, " g=", g.cell if g else null)
			if g and g.fuel: g.fuel.add("coal", 200)
			game.cmd("fuse", {"a": h, "b": ch, "kind": "combo"})
			game.cmd("recipe", {"b": h, "rid": "iron_rod"})
			f.auto_wire_all()
			f.power_dirty = true
			print("HUNT host built subs=", h.subs.size(), " cell=", h.cell)
			var sub = Fusion.chest_of(h)
			var t0 := Time.get_ticks_msec()
			var mx := 0
			while Time.get_ticks_msec() - t0 < 70000:
				if h.inv.count("iron_ingot") < 20:
					for k in 5:
						f.accept(h, "iron_ingot", null)
				mx = maxi(mx, sub.inv.count("iron_rod"))
				await tree.process_frame
			print("TEST chest_host120_115 max_in_chest=", mx, " now=", sub.inv.count("iron_rod"), " ", "OK" if mx >= 10 and sub.inv.count("iron_rod") < mx else "FAIL")
		"duelA_fz115":
			var f = game.factory
			game.flags["free_build"] = true
			var c: Vector2i = f.hq.cell + Vector2i(8, 6)
			for dx in range(-4, 8):
				for dz in range(-4, 8):
					game.world.remove_node(World.wc(c + Vector2i(dx, dz)))
			var a = put(game, "chest", c, 0)
			var b = put(game, "chest", c + Vector2i(1, 0), 0)
			for i in a.inv.size():
				a.inv.slots[i] = {"id": "stone", "n": 50}
				b.inv.slots[i] = {"id": "stone", "n": 50}
			var tot0: int = a.inv.count("stone") + b.inv.count("stone")
			var pl0: int = game.player.inv.count("stone")
			var ok = game.cmd("fuse", {"a": a, "b": b, "kind": "level"})
			print("HUNT fuse_level ok=", ok, " lvl=", a.lvl, " size=", a.inv.size(), " in_chest=", a.inv.count("stone"), " of ", tot0, " player_delta=", game.player.inv.count("stone") - pl0, " drops=", game.drops.get_child_count() if game.drops is Node else -1)
			print("TEST duelA_fz115 done")
		"duelA_fz2115":
			var f = game.factory
			game.flags["free_build"] = true
			var c: Vector2i = f.hq.cell + Vector2i(8, 6)
			for dx in range(-4, 10):
				for dz in range(-4, 10):
					game.world.remove_node(World.wc(c + Vector2i(dx, dz)))
			var h = put(game, "constructor", c, 0)
			print("HUNT constructor size=", h.size if h else -1)
			var ch1 = put(game, "chest", c + Vector2i(h.size, 0), 0)
			var r1 = game.cmd("fuse", {"a": h, "b": ch1, "kind": "combo"})
			var ch2 = put(game, "chest", c + Vector2i(h.size, 1), 0)
			var tw = f.fz.sub_twin(h, ch2)
			var r2 = game.cmd("fuse", {"a": h, "b": ch2, "kind": "sub"})
			var cs = Fusion.chest_of(h)
			print("HUNT combo=", r1, " twin=", tw != null, " sub=", r2, " chest_sub lvl=", cs.lvl, " slots=", cs.inv.size(), " (single chest slots=", int(cs.p("slots", 0)), ")")
			var ch3 = put(game, "chest", c + Vector2i(h.size, 2 if h.size > 2 else -1), 0)
			var r3 = game.cmd("fuse", {"a": h, "b": ch3, "kind": "combo"})
			print("HUNT second chest combo=", r3, " subs=", h.subs.size())
			h.recipe = "" if h.recipe == null else h.recipe
			for i in cs.inv.size():
				cs.inv.slots[i] = {"id": "stone", "n": 50}
			h.out.slots[0] = {"id": "iron_rod", "n": 5}
			for k in 5:
				f.fz.flow(h)
			var c3 = h.subs[h.subs.size() - 1]
			print("HUNT chest1 full; host.out rod=", h.out.count("iron_rod"), " chest3 rod=", c3.inv.count("iron_rod"), " chest3 type=", c3.type, " next=", h.next)
			print("TEST duelA_fz2115 done")
		"duelA_demo115":
			var f = game.factory
			game.flags["free_build"] = true
			var c: Vector2i = f.hq.cell + Vector2i(8, 6)
			for dx in range(-4, 10):
				for dz in range(-4, 10):
					game.world.remove_node(World.wc(c + Vector2i(dx, dz)))
			for k in 5:
				put(game, "belt", c + Vector2i(k + 1, 0), 0)
				put(game, "belt", c + Vector2i(k + 1, 3), 0)
			game.demolish = true
			game.build_type = ""
			# A: нажали на пустой клетке рядом с лентой и протянули по линии
			game.hover_cell = c
			game._click_world()
			for k in 5:
				game.hover_cell = c + Vector2i(k + 1, 0)
				game._drag_world()
			var left_a := 0
			for k in 5:
				if f.building_at(c + Vector2i(k + 1, 0)) != null:
					left_a += 1
			# B: нажали прямо на первую ленту
			game.hover_cell = c + Vector2i(1, 3)
			game._click_world()
			for k in range(1, 5):
				game.hover_cell = c + Vector2i(k + 1, 3)
				game._drag_world()
			var left_b := 0
			for k in 5:
				if f.building_at(c + Vector2i(k + 1, 3)) != null:
					left_b += 1
			print("HUNT demolish drag from empty cell: belts left=", left_a, "/5 layer=", game.demo_layer, "; from belt: left=", left_b, "/5")
			print("TEST duelA_demo115 done")
		"duelA_rep115":
			var f = game.factory
			game.flags["free_build"] = true
			var c: Vector2i = f.hq.cell + Vector2i(8, 6)
			var ch = put_near(game, "chest", c, 0)
			f.damage(ch, ch.maxhp * 0.5)
			game.hud.open_building(ch)
			await game.get_tree().process_frame
			var found := ""
			var stack: Array = [game.hud]
			while not stack.is_empty():
				var n = stack.pop_back()
				if n is Label and "держать" in n.text:
					found = n.text
				for ch2 in n.get_children():
					stack.append(ch2)
			print("HUNT repair hint='", found, "' repair111.time=", DB.setting("repair111", {}).get("time", -1))
			print("TEST duelA_rep115 done")
		"duelA_heart115":
			var f = game.factory
			var c: Vector2i = f.hq.cell + Vector2i(6, 8)
			game.flags["free_build"] = true
			for dx in range(-3, 12):
				for dz in range(-3, 6):
					game.world.remove_node(World.wc(c + Vector2i(dx, dz)))
			var first = put(game, "chest", c, 0)
			DB.data.settings["heart_limit"]["hq"] = game.hearts.used() + 1 - 0
			game.hearts._n = -1
			put(game, "chest", c + Vector2i(2, 0), 0)
			game.hearts._n = -1
			print("HUNT used=", game.hearts.used(), " cap=", game.hearts.cap())
			var rc: Vector2i = first.cell
			f.damage(first, 1e9)
			game.hearts._n = -1
			var rr = game.builders.ruin_at(rc)
			print("HUNT ruin=", rr != null, " used=", game.hearts.used(), " cap=", game.hearts.cap())
			var nb = put(game, "chest", c + Vector2i(4, 0), 0)
			game.hearts._n = -1
			print("HUNT after new chest=", nb != null, " used=", game.hearts.used(), " cap=", game.hearts.cap())
			game._once.clear()
			game.flags.erase("free_build")
			f.hq.inv.add("plank", 50)
			var r = game.cmd("repair", {"cell": rc})
			print("HUNT repair=", r, " why_place='", f.can_place("chest", rc), "' once_keys=", game._once.keys())
			print("TEST duelA_heart115 done")
		"duelA_putall115":
			var f = game.factory
			game.flags["free_build"] = true
			var ch = put_near(game, "chest", f.hq.cell + Vector2i(8, 6), 0)
			var pinv = game.player.inv
			for i in pinv.slots.size():
				pinv.slots[i] = null
			pinv.slots[0] = {"id": "stone_pickaxe", "n": 1, "dur": 0.8}
			pinv.slots[1] = {"id": "stone_axe", "n": 1, "dur": 0.9}
			pinv.slots[2] = {"id": "berry", "n": 5}
			pinv.slots[Player.hot_n() + 1] = {"id": "stone", "n": 30}
			game.cmd("put_all", {"b": ch})
			print("HUNT hot_n=", Player.hot_n(), " after put_all: slot0=", pinv.slots[0], " slot1=", pinv.slots[1], " slot2=", pinv.slots[2], " bag stone=", pinv.count("stone"), " chest=", ch.inv.totals())
			for i in pinv.slots.size():
				pinv.slots[i] = null
			pinv.slots[0] = {"id": "stone_pickaxe", "n": 1, "dur": 0.8}
			pinv.slots[Player.hot_n() + 1] = {"id": "stone", "n": 30}
			game.factory.hq.inv.slots.fill(null)
			game.player.position = f.hq.center() + Vector3(3, 0, 0)
			game.cmd("store_hq", {})
			print("HUNT store_hq: slot0=", pinv.slots[0], " bag stone=", pinv.count("stone"))
			print("TEST duelA_putall115 done")
		"duelA_link115":
			var f = game.factory
			game.flags["free_build"] = true
			var card = game.hud._build_card("hq_link")
			var txt := []
			var st: Array = [card]
			while not st.is_empty():
				var n = st.pop_back()
				if n is Label and "⚡" in n.text:
					txt.append(n.text)
				for c2 in n.get_children():
					st.append(c2)
			var ln = put_near(game, "hq_link", f.hq.cell + Vector2i(6, 6), 0)
			for k in 10:
				f._tick(0.1)
			print("HUNT hq_link card='", txt, "' desc_has_20=", "Энергия: 20" in str(DB.building("hq_link").get("desc", "")), " actual power=", ln.p("power", 0), " setting power_min=", DB.setting("hq_link115", {}).get("power_min"))
			print("TEST duelA_link115 done")
		"duelA_lbelt115":
			var f = game.factory
			game.flags["free_build"] = true
			var c: Vector2i = f.hq.cell + Vector2i(8, 6)
			for dx in range(-3, 12):
				for dz in range(-3, 8):
					game.world.remove_node(World.wc(c + Vector2i(dx, dz)))
			var res := []
			var k := 0
			for t in ["laser_turret", "tesla_coil", "flame_turret", "pole", "wall"]:
				var tc: Vector2i = c + Vector2i(k * 3, 0)
				var tb = put(game, t, tc + Vector2i(0, 2), 0)
				var b1 = put(game, "belt", tc, 1)
				var b2 = put(game, "belt", tc + Vector2i(0, 1), 1)
				f.set_item(b1, "iron_plate")
				for i in 30:
					f._tick(0.1)
				res.append([t, tb != null, "next=" + (b2.next.type if b2.next != null else "null"), "stuck=" + b2.item, "acc=" + str(f.accept(tb, "iron_plate", b2)) if tb != null else ""])
				k += 1
			print("HUNT ", res)
			print("TEST duelA_lbelt115 done")
		"duelA_sim115":
			var f = game.factory
			game.flags["free_build"] = true
			var c: Vector2i = f.hq.cell + Vector2i(10, 8)
			for dx in range(-6, 8):
				for dz in range(-3, 4):
					game.world.remove_node(World.wc(c + Vector2i(dx, dz)))
			var src = put(game, "chest", c + Vector2i(-4, 0), 0)
			for k in range(1, 4):
				put(game, "belt", c + Vector2i(-k, 0), 0)
			var fu = put(game, "furnace", c, 0)
			for k in range(1, 4):
				put(game, "belt", c + Vector2i(k, 0), 0)
			var dst = put(game, "chest", c + Vector2i(4, 0), 0)
			var cc = put(game, "chest", c + Vector2i(0, 1), 0)
			var mode: String = "combo"
			var ok = f.fz.fuse_combo(fu, cc)
			src.inv.add("iron_ore", 200)
			fu.fuel.add("coal", 50)
			f._rebuild_power()
			for i in 3000:
				f._tick(0.05)
			var ch = Fusion.chest_of(fu)
			print("HUNT fused=", ok, " src_ore=", src.inv.count("iron_ore"), " furnace in=", fu.inv.totals(), " out=", fu.out.totals(), " composite_chest=", ch.inv.totals() if ch else {}, " dst=", dst.inv.totals(), " fu.next=", fu.next.type if fu.next else "null")
			print("TEST duelA_sim115 done")
		"duelB_hchest115":
			# B14: хозяин — составное конструктор + ящик с 30 железными пластинами; печатает, что в ящике и в штабе
			var N = Net._self()
			var f = game.factory
			game.flags["free_build"] = true
			for i in 400:
				await tree.create_timer(0.1).timeout
				if not N.puppets.is_empty():
					break
			await tree.create_timer(2.0).timeout
			N.room["access"] = "all"
			var c: Vector2i = World.wc(f.hq.cell + Vector2i(16, 12))
			for r in 40:
				var cc: Vector2i = World.wc(f.hq.cell + Vector2i(10 + (r % 8) * 4, 8 + (r / 8) * 4))
				if f.can_place("constructor", cc) == "" and f.can_place("chest", cc + Vector2i(2, 0)) == "":
					c = cc
					break
			game.cmd("place", {"type": "constructor", "cell": c, "dir": 0})
			var h = f.building_at(c)
			game.cmd("place", {"type": "chest", "cell": c + Vector2i(2, 0), "dir": 0})
			var ch = f.building_at(c + Vector2i(2, 0))
			game.cmd("fuse", {"a": h, "b": ch, "kind": "combo"})
			var sub = Fusion.chest_of(h)
			sub.inv.add("iron_plate", 30)
			sub.inv._bump()
			print("HUNT host composite subs=", h.subs.size(), " chest plates=", sub.inv.count("iron_plate"))
			var t0 := Time.get_ticks_msec()
			while Time.get_ticks_msec() - t0 < float(OS.get_environment("HT") if OS.get_environment("HT") != "" else "60") * 1000.0:
				await tree.create_timer(3.0).timeout
				print("HUNT host t=", (Time.get_ticks_msec() - t0) / 1000, " chest plates=", sub.inv.count("iron_plate"), " hq plates=", f.hq.inv.count("iron_plate"), " guest last_inv plates=", _cnt_arr(N.puppets.values()[0].last_inv if not N.puppets.is_empty() and N.puppets.values()[0].get("last_inv") != null else [], "iron_plate"))
			print("TEST duelB_hchest115 done")
			game.get_tree().quit()
		"duelB_hoffer115":
			# B14: хозяин ничего не строит; печатает свои окошки «Объединить?»
			var N = Net._self()
			game.tech.done["t_fuse1"] = true
			game.tech.done["t_fuse2"] = true
			game.tech.refresh_locks()
			for i in 400:
				await tree.create_timer(0.1).timeout
				if not N.puppets.is_empty():
					break
			var t0 := Time.get_ticks_msec()
			var seen := 0
			while Time.get_ticks_msec() - t0 < 40000:
				await tree.create_timer(1.0).timeout
				var fo: Array = game.factory.fz.offers
				if fo.size() != seen:
					seen = fo.size()
					print("HUNT host zone c=", game.zone.center, " half=", game.zone.half(), " blocks=", game.zone.blocks, " rects=", game.zone.rects, " on=", game.zone.on(), " cells=", fo.map(func(o): return [o.a.cell, game.zone.inside_cell(o.a.cell)]))
					print("HUNT host offers=", fo.map(func(o): return [o.a.type, o.b.type, o.kind, str(o.a.bstate.get("owner", "")), str(o.b.bstate.get("owner", ""))]), " popup visible=", game.hud.offer_box != null and game.hud.offer_box.visible, " host pos=", World.world_to_cell(game.player.position))
			print("TEST duelB_hoffer115 done")
			game.get_tree().quit()
		"duelB_special115":
			# B14: особые склады (аванпост, лавка, капсула, сундук подземелья, дезактиватор) встраиваются в печь
			var f = game.factory
			game.flags["free_build"] = true
			var res := []
			var k := 0
			for t in ["outpost", "player_market", "supply_capsule", "dungeon_chest", "decon_station", "waste_storage"]:
				var c: Vector2i = f.hq.cell + Vector2i(-40 + k * 12, 18)
				k += 1
				for dx in range(-3, 10):
					for dz in range(-3, 8):
						game.world.remove_node(World.wc(c + Vector2i(dx, dz)))
				var sb = put_near(game, t, c, 0)
				if sb != null:
					c = sb.cell
					for dx in range(-3, 10):
						for dz in range(-3, 8):
							game.world.remove_node(World.wc(c + Vector2i(dx, dz)))
				if sb == null:
					res.append([t, "no place"])
					continue
				sb.bstate["owner"] = "Аня"
				if sb.inv: sb.inv.add("iron_ingot", 7)
				var fu = put(game, "furnace", c + Vector2i(sb.size, 0), 0)
				if fu == null:
					res.append([t, "no furnace"])
					continue
				f.fz.offers.clear()
				var before := str(game.coop.outpost_of("Аня"))
				f.fz.check_offers(fu)
				var offer: Array = f.fz.offers.map(func(o): return o.kind)
				var why: String = f.fz.combo_why(fu, sb)
				var ok = game.cmd("fuse", {"a": fu, "b": sb, "kind": "combo"})
				var host = fu if not fu.dead else sb
				res.append([t, "why='" + why + "'", "offer=" + str(offer), "fused=" + str(ok != null and not (ok is bool and not ok)), "in_all=" + str(sb in f.all), "sub_of=" + (host.type if sb.host != null else "-"), "outpost_of(Аня) before=" + before + " after=" + str(game.coop.outpost_of("Аня")), "is_market=" + str(Coop.is_market(sb))])
			for r in res:
				print("HUNT special ", r)
			print("TEST duelB_special115 done")
		"duelB_hput115":
			# B14: комната «чужое — только класть»; ящик хозяина с 50 сталью
			var N = Net._self()
			var f = game.factory
			var mk := OS.get_environment("MARKET") == "1"
			N.room["access"] = "all" if mk else "put"
			var ch = put_near(game, "player_market" if mk else "chest", f.hq.cell + Vector2i(8, 0), 0)
			ch.bstate["owner"] = N.nick
			ch.inv.add("steel", 50)
			ch.inv._bump()
			print("HUNT host chest ", ch.cell, " owner=", N.nick, " access=", N.room.get("access"))
			for i in 400:
				await tree.create_timer(0.1).timeout
				if not N.puppets.is_empty():
					break
			var t0 := Time.get_ticks_msec()
			while Time.get_ticks_msec() - t0 < 35000:
				await tree.create_timer(3.0).timeout
				print("HUNT host t=", (Time.get_ticks_msec() - t0) / 1000, " chest=", ch.inv.to_array().filter(func(x): return x != null), " access=", N.room.get("access"))
			print("TEST duelB_hput115 done")
			game.get_tree().quit()
		"duelB_heart115":
			# B14: предел зданий («Сердца») не считает «украшения», а среди них — энергия, щиты, лаборатории
			var f = game.factory
			game.flags["free_build"] = true
			var H = game.hearts
			print("HUNT hearts on=", H.on(), " used=", H.used(), " cap=", H.cap())
			var k := 0
			var guard := 0
			while H.used() < H.cap() and guard < 400:
				guard += 1
				var c: Vector2i = f.hq.cell + Vector2i(-30 + (k % 30) * 2, 10 + (k / 30) * 2)
				k += 1
				put(game, "chest", c, 0)
			print("HUNT filled used=", H.used(), " cap=", H.cap(), " chest why='", H.why("chest", f.hq.cell), "'")
			var res := []
			for t in ["antimatter_gen", "research_lab", "shield_dome", "barrier_large", "repair_tower", "drone_hub", "tesla", "builder_bay", "quantum_portal", "recycler", "heater"]:
				var why: String = H.why(t, f.hq.cell)
				var b = put_near(game, t, f.hq.cell + Vector2i(-20, -24 + res.size() * 5), 0)
				res.append([t, "why='" + why + "'", "placed=" + str(b != null)])
			print("HUNT after: used=", H.used(), " cap=", H.cap())
			for r in res:
				print("HUNT heart ", r)
			print("TEST duelB_heart115 done")
		"duelB_hown115":
			# B14: комната «чужое — нельзя»; составное хозяина (печь + конструктор с 20 слитками в сырье);
			# через 14 с — «перезагрузка» встроенных так же, как main.gd save_dict/load_game (save_subs/load_subs)
			var N = Net._self()
			var f = game.factory
			game.flags["free_build"] = true
			N.room["access"] = "own"
			var h = put_near(game, "furnace", f.hq.cell + Vector2i(10, 4), 0)
			var m = put(game, "constructor", h.cell + Vector2i(h.size, 0), 0)
			if m == null:
				m = put_near(game, "constructor", h.cell + Vector2i(h.size + 1, 0), 0)
			h.bstate["owner"] = N.nick
			m.bstate["owner"] = N.nick
			print("HUNT host fuse=", f.fz.fuse_combo(h, m), " subs=", h.subs.size())
			var sub = h.subs[0]
			f.set_recipe(sub, "iron_rod")
			sub.inv.add("iron_ingot", 20)
			sub.inv._bump()
			print("HUNT host sub owner='", sub.bstate.get("owner", ""), "' recipe=", sub.recipe, " inv=", sub.inv.count("iron_ingot"))
			for i in 400:
				await tree.create_timer(0.1).timeout
				if not N.puppets.is_empty():
					break
			await tree.create_timer(30.0).timeout
			print("HUNT host before reload: sub recipe=", h.subs[0].recipe, " inv=", h.subs[0].inv.count("iron_ingot"))
			var arr: Array = f.fz.save_subs(h)
			for s0 in h.subs:
				f.renderer(s0.type).remove(s0)
			h.subs = []
			f.fz.load_subs(h, arr)
			sub = h.subs[0]
			print("HUNT host RELOADED sub owner='", sub.bstate.get("owner", ""), "' recipe=", sub.recipe, " inv=", sub.inv.count("iron_ingot"))
			var t0 := Time.get_ticks_msec()
			while Time.get_ticks_msec() - t0 < 20000:
				await tree.create_timer(3.0).timeout
				print("HUNT host sub recipe=", h.subs[0].recipe, " inv=", h.subs[0].inv.count("iron_ingot"), " guest bag ingots=", _cnt_arr(N.puppets.values()[0].last_inv if N.puppets.values()[0].get("last_inv") != null else [], "iron_ingot"))
			print("TEST duelB_hown115 done")
			game.get_tree().quit()
		"duelB_qsub115":
			# B14: запутанный ящик встроен в составное — после сохранения/загрузки пара рвётся, содержимое удваивается
			var f = game.factory
			game.flags["free_build"] = true
			var ca = put_near(game, "entangled_chest", f.hq.cell + Vector2i(-12, 8))
			var cb = put_near(game, "entangled_chest", f.hq.cell + Vector2i(14, -12))
			for dx in range(-3, 6):
				for dz in range(-3, 6):
					game.world.remove_node(World.wc(cb.cell + Vector2i(dx, dz)))
			ca.inv.add("steel", 50)
			print("HUNT pair=", game.quantum.partner(ca) == cb, " a=", ca.inv.count("steel"), " b=", cb.inv.count("steel"))
			var fu = put(game, "furnace", cb.cell + Vector2i(1, 0), 0)
			var why: String = f.fz.combo_why(fu, cb)
			var ok = game.cmd("fuse", {"a": fu, "b": cb, "kind": "combo"})
			var sub = Fusion.chest_of(fu)
			print("HUNT fuse why='", why, "' ok=", ok, " sub=", sub != null, " shared=", sub != null and sub.inv == ca.inv)
			var total := func():
				var t := 0
				var seen := []
				for b in f.all:
					if b.dead:
						continue
					for bb in [b] + b.subs:
						if bb.inv != null and not bb.inv in seen:
							seen.append(bb.inv)
							t += bb.inv.count("steel")
				return t
			print("HUNT before save: total steel (distinct inventories)=", total.call())
			for round in 2:
				var sd: Dictionary = JSON.parse_string(JSON.stringify(game.save_dict()))
				game.load_game(sd)
				await tree.process_frame
				print("HUNT after load ", round + 1, ": total steel=", total.call())
			print("TEST duelB_qsub115 done")
		"duelA_drone115":
			var f = game.factory
			game.flags["free_build"] = true
			var c: Vector2i = f.hq.cell + Vector2i(8, 6)
			for dx in range(-4, 10):
				for dz in range(-4, 10):
					game.world.remove_node(World.wc(c + Vector2i(dx, dz)))
			var h = put(game, "constructor", c, 0)
			var ch1 = put(game, "chest", c + Vector2i(h.size, 0), 0)
			game.cmd("fuse", {"a": h, "b": ch1, "kind": "combo"})
			var ch3 = put(game, "chest", c + Vector2i(h.size, 1), 0)
			var r3 = game.cmd("fuse", {"a": h, "b": ch3, "kind": "combo"})
			var subs: Array = h.subs.filter(func(x): return x.beh == "storage")
			print("HUNT chests in composite=", subs.size(), " r3=", r3)
			var c1 = subs[0]
			for i in c1.inv.size():
				c1.inv.slots[i] = {"id": "stone", "n": 50}
			game.drones.f = f
			var left: int = game.drones.deliver(h, "iron_plate", 20)
			print("HUNT drone deliver 20 iron_plate: left=", left, " chest2 plate=", subs[1].inv.count("iron_plate"), " host.out=", h.out.totals() if h.out else {})
			subs[1].inv.add("copper_plate", 30)
			var srcs: Array = game.drones.src_invs(h)
			print("HUNT drone sources include chest2=", srcs.has(subs[1].inv), " n_src=", srcs.size())
			print("TEST duelA_drone115 done")
		"duelA_pow115":
			var f = game.factory
			DB.data.settings["power_mode"] = "stations"
			game._apply_sizes(true, true)
			game.flags["free_build"] = true
			var c: Vector2i = f.hq.cell + Vector2i(12, 0)
			for dx in range(-6, 16):
				for dz in range(-8, 10):
					game.world.remove_node(World.wc(c + Vector2i(dx, dz)))
			var gens := []
			for k in 4:
				var g = put(game, "generator", c + Vector2i(k * 3, -6), 0)
				if g and g.fuel: g.fuel.add("coal", 50)
				gens.append(g)
			var res := []
			var x := 0
			for t in ["manufacturer", "tesla_coil", "sink", "barrier_small", "builder_bay", "assembler"]:
				var m = put(game, t, c + Vector2i(x, 0), 0)
				var pl = put(game, "pole", c + Vector2i(x, -2), 0)
				res.append([t, m, pl])
				x += 4
			var near_hq = put_near(game, "manufacturer", f.hq.cell + Vector2i(0, 5), 0)
			f.power_dirty = true
			for i in 40:
				f._tick(0.1)
				await tree.process_frame
			f._rebuild_power()
			for i in 5:
				f._power(1.0)
			print("HUNT dbg st_pairs=", f.st_pairs.size(), " consumers=", f.consumers.size(), " nodes=", f.power_nodes.size(), " caps=", f.power_nodes.map(func(n): return [n.type, n.cell, n.net]), " cons=", f.consumers.map(func(n): return [n.type, n.cell]), " wired=", f.wired(), " mode=", DB.setting("power_mode", "?"), " links=", f.links.size())
			for e in res:
				var m = e[1]
				if m == null:
					print("HUNT ", e[0], " not placed")
					continue
				print("HUNT ", e[0], " power=", m.p("power", 0), " pw_state=", m.pw_state, " feeder=", m.feeder.type if m.feeder else null, " pole_net=", e[2].net if e[2] else -9, " sat=", f.sat_c(m))
			if near_hq:
				print("HUNT manufacturer@hq dist=", World.dist(near_hq.center(), f.hq.center()) / World.C, " pw_state=", near_hq.pw_state, " feeder=", near_hq.feeder.type if near_hq.feeder else null)
			print("TEST duelA_pow115 done")
		"duelA_sl115":
			var f = game.factory
			DB.data.settings["power_mode"] = "stations"
			var sig := func() -> Dictionary:
				var out := {}
				for b in f.all:
					var k := "%s@%d,%d" % [b.type, b.cell.x, b.cell.y]
					var e := {"d": b.dir, "hp": snappedf(b.hp, 1), "r": b.recipe, "it": b.item, "lvl": b.lvl, "cfg": b.cfg, "crafting": b.crafting, "fuel_t": snappedf(b.fuel_t, 0.1), "kind": b.kind, "lift": b.lift, "pw": b.pw_state, "feeder": b.feeder.type if b.feeder else "", "next": b.next.type if b.next else "", "en": snappedf(b.energy, 1), "size": b.size}
					for kk in ["inv", "out", "fuel"]:
						var iv = b.get(kk)
						if iv != null:
							e[kk] = [iv.size(), iv.totals()]
					e["subs"] = b.subs.map(func(x): return [x.type, x.lvl, x.inv.size() if x.inv else 0, x.inv.totals() if x.inv else {}, x.out.totals() if x.out else {}, x.recipe, x.bstate])
					var bs: Dictionary = b.bstate.duplicate(true)
					bs.erase("st_load"); bs.erase("st_cap"); bs.erase("st_short"); bs.erase("seen")
					e["bs"] = bs
					out[k] = e
				out["_player"] = [game.player.inv.to_array(), game.player.selected, game.credits, game.tech.done.size(), game.tutorial.step, game.research if "research" in game else 0]
				return out
			if not DB.has_meta("duelA_p2"):
				game._apply_sizes(true, true)
				game.flags["free_build"] = true
				var c: Vector2i = f.hq.cell + Vector2i(8, 6)
				for dx in range(-6, 16):
					for dz in range(-8, 14):
						game.world.remove_node(World.wc(c + Vector2i(dx, dz)))
				var fu = put(game, "furnace", c, 0)
				fu.inv.add("iron_ore", 20)
				fu.fuel.add("coal", 10)
				var ch = put(game, "chest", c + Vector2i(4, 0), 0)
				ch.inv.add("stone", 37)
				var ch2 = put(game, "chest", c + Vector2i(5, 0), 0)
				ch2.inv.add("iron_plate", 11)
				game.cmd("fuse", {"a": ch, "b": ch2, "kind": "level"})
				var h = put(game, "constructor", c + Vector2i(0, 4), 0)
				var hc = put(game, "chest", c + Vector2i(0 + h.size, 4), 0)
				game.cmd("fuse", {"a": h, "b": hc, "kind": "combo"})
				var hc2 = put(game, "chest", c + Vector2i(0 + h.size, 5), 0)
				game.cmd("fuse", {"a": h, "b": hc2, "kind": "sub"})
				f.set_recipe(h, "iron_rod")
				h.inv.add("iron_ingot", 10)
				var sp = put(game, "smart_splitter", c + Vector2i(8, 0), 0)
				sp.cfg = {"outs": {"0": {"mode": "items", "items": ["coal"]}, "3": {"mode": "overflow"}}}
				var mg = put(game, "smart_merger", c + Vector2i(8, 3), 0)
				mg.cfg = {"prio": 2}
				for k in 4:
					var bl = put(game, "belt", c + Vector2i(10 + k, 0), 0)
					if bl: f.set_item(bl, "wire")
				var lf = put(game, "lift_mk1", c + Vector2i(10, 2), 0)
				var tu = put(game, "turret", c + Vector2i(10, 5), 0)
				if tu and tu.inv: tu.inv.add("ammo", 7)
				var g = put(game, "generator", c + Vector2i(0, -5), 0)
				if g and g.fuel: g.fuel.add("coal", 20)
				var pl = put(game, "pole", c + Vector2i(3, -3), 0)
				var bat = put(game, "battery_block", c + Vector2i(5, -5), 0)
				var ln = put(game, "hq_link", c + Vector2i(13, 5), 0)
				if ln: ln.cfg = {"mode": "take", "items": ["iron_plate"]}
				var hp_dmg = put(game, "chest", c + Vector2i(13, 8), 0)
				if hp_dmg: f.damage(hp_dmg, hp_dmg.maxhp * 0.4)
				game.flags.erase("free_build")
				game.player.inv.slots[0] = {"id": "stone_pickaxe", "n": 1, "dur": 0.37}
				game.player.inv.slots[5] = {"id": "berry", "n": 7, "fresh": 0.5}
				game.player.selected = 0
				f.power_dirty = true
				for i in 100:
					f._tick(0.1)
					await tree.process_frame
				print("HUNT phase1 placed=", [fu, ch, h, sp, mg, lf, tu, g, pl, bat, ln, hp_dmg].map(func(x): return x != null))
				var s1: Dictionary = sig.call()
				game.save_game("duelA_sl", true)
				DB.set_meta("duelA_p2", JSON.stringify(s1))
				var d = DB.read_file(DB.saves_dir().path_join("duelA_sl.json"))
				DB.set_meta("new_game", {"profession": d.get("profession", "engineer"), "save": d, "map_mode": "save"})
				tree.change_scene_to_file.call_deferred("res://scenes/main.tscn")
				var nd := Node.new()
				await nd.renamed
				return
			print("HUNT p2 start frame=", game._frame, " items_on_belts=", f.items_on_belts, " drops=", game.drops.list.map(func(d): return [d.id, d.n]), " belts=", f.all.filter(func(x): return x.type == "belt").map(func(x): return [x.cell, x.item, x.next.type if x.next else null]))
			var s1: Dictionary = JSON.parse_string(str(DB.get_meta("duelA_p2")))
			var s2: Dictionary = JSON.parse_string(JSON.stringify(sig.call()))
			var diffs := 0
			for k in s1:
				if not s2.has(k):
					print("HUNT MISSING after load ", k)
					diffs += 1
					continue
				for kk in s1[k] if s1[k] is Dictionary else {}:
					if str(s1[k][kk]) != str(s2[k].get(kk)):
						print("HUNT DIFF ", k, " ", kk, ": ", s1[k][kk], " -> ", s2[k].get(kk))
						diffs += 1
				if s1[k] is Array and str(s1[k]) != str(s2[k]):
					print("HUNT DIFF ", k, ": ", s1[k], " -> ", s2[k])
			for k in s2:
				if not s1.has(k):
					print("HUNT EXTRA after load ", k)
			print("HUNT diffs=", diffs)
			f.power_dirty = true
			for i in 20:
				f._tick(0.1)
				await tree.process_frame
			var s3: Dictionary = JSON.parse_string(JSON.stringify(sig.call()))
			for k in s1:
				if s3.has(k) and s1[k] is Dictionary:
					for kk in ["pw", "feeder", "next", "kind"]:
						if str(s1[k].get(kk)) != str(s3[k].get(kk)):
							print("HUNT DIFF2s ", k, " ", kk, ": ", s1[k].get(kk), " -> ", s3[k].get(kk))
			print("TEST duelA_sl115 done")
		"duelA_mhq115":
			var f = game.factory
			game.flags["free_build"] = true
			var res := {}
			for item in ["iron_ore", "coal"]:
				var dc: Vector2i = nearest_deposit(game, item, f.hq.cell)
				var m = put(game, "miner", dc, 0)
				if m == null:
					print("HUNT no miner on ", item)
					continue
				var g = put_near(game, "generator", dc + Vector2i(0, 4), 0)
				if g and g.fuel: g.fuel.add("coal", 100)
				f.auto_wire_all()
				f.power_dirty = true
				var got := {}
				var hand := {}
				for i in 12000:
					f._tick(0.1)
					for sl in m.out.slots:
						if sl != null:
							got[sl.id] = int(got.get(sl.id, 0)) + int(sl.n)
					for j in m.out.slots.size():
						m.out.slots[j] = null
				res[item] = [m.recipe, m.out.size(), got]
			# hand mining for comparison
			var dc2: Vector2i = nearest_deposit(game, "coal", f.hq.cell + Vector2i(30, 30))
			print("HUNT miner 20 min: ", res)
			print("TEST duelA_mhq115 done")
		"duelA_bm115":
			var f = game.factory
			game.flags["free_build"] = true
			var c: Vector2i = f.hq.cell + Vector2i(10, 8)
			for dx in range(-6, 8):
				for dz in range(-6, 8):
					game.world.remove_node(World.wc(c + Vector2i(dx, dz)))
			var bm = put(game, "black_market", c, 0)
			var res := []
			for side in 4:
				var d: Vector2i = Factory.DIRS[side]
				var b1 = put(game, "belt", c + d * 2, (side + 2) % 4)
				var b2 = put(game, "belt", c + d, (side + 2) % 4)
				f.set_item(b1, "iron_ingot")
				res.append([side, b2])
			var cr0 = game.credits
			for i in 200:
				f._tick(0.1)
			print("HUNT ports_on=", Factory.ports_on(), " bm.pon=", bm.pon, " pin=", bm.pin, " cell=", bm.cell)
			for e in res:
				print("HUNT side ", e[0], " belt next=", e[1].next.type if e[1].next else null, " stuck=", e[1].item)
			for t in ["player_market", "assembler_mk2"]:
				var pm = put_near(game, t, c + Vector2i(0, 20), 0)
				if pm:
					print("HUNT ", t, " size=", pm.size, " pon=", pm.pon, " inputs=", pm.pin.size(), " port_counts=", Factory.port_counts(t), " sides=", pm.pin_side)
			print("TEST duelA_bm115 done")
		"duelA_wb115":
			var f = game.factory
			game.flags["free_build"] = true
			var wb = put_near(game, "workbench", f.hq.cell + Vector2i(8, 6), 0)
			var pinv = game.player.inv
			for i in pinv.slots.size():
				pinv.slots[i] = null
			pinv.slots[Player.hot_n() + 2] = {"id": "log", "n": 7}
			game.player.position = wb.center() + Vector3(2, 0, 0)
			game.hover_cell = wb.cell
			game._interact()
			await tree.process_frame
			print("HUNT opened craft=", game.hud.is_open("craft"), " building_win=", game.hud.is_open("building"), " hud.bld=", game.hud.bld, " wb.inv=", wb.inv, " station=", game.hud.station)
			game.hud.quick_move(pinv, Player.hot_n() + 2, true)
			await tree.process_frame
			var where := []
			for i in pinv.slots.size():
				if pinv.slots[i] != null:
					where.append([i, pinv.slots[i]])
			print("HUNT after double-click logs: ", where, " hot_n=", Player.hot_n(), " tutorial step10 hint=", DB.setting("tutorial", {}).steps[10].hint)
			print("TEST duelA_wb115 done")
		"duelA_hand115":
			var f = game.factory
			var dc: Vector2i = nearest_deposit(game, "iron_ore", f.hq.cell)
			game.world.remove_node(dc)
			var pinv = game.player.inv
			for i in pinv.slots.size():
				pinv.slots[i] = null
			game.player.selected = 0
			game.player.position = game.world.cell_to_world(dc) + Vector3(1.5, 0, 0)
			var n0: int = game.drops.list.size()
			var hits := 0
			for k in 20:
				game.player.start_swing(dc)
				for j in 30:
					game.player._update_swing(0.05)
				hits += 1
			var ore := 0
			for d in game.drops.list:
				if d.id == "iron_ore":
					ore += d.n
			print("HUNT can_mine=", game.world.can_mine(dc), " bare-hand swings=", hits, " iron_ore dropped=", ore, " selected=", game.player.selected_item())
			print("TEST duelA_hand115 done")
		"pow120_115":
			# 1.1.20: крупному зданию мощность складывается из нескольких станций рядом (изготовитель 55 от трёх станций Mk1 по 20)
			var f = game.factory
			DB.data.settings["power_mode"] = "stations"
			game._apply_sizes(true, true)
			game.flags["free_build"] = true
			var c: Vector2i = f.hq.cell + Vector2i(14, 10)
			for dx in range(-8, 16):
				for dz in range(-10, 10):
					game.world.remove_node(World.wc(c + Vector2i(dx, dz)))
			for k in 4:
				var g = put(game, "generator", c + Vector2i(k * 3, -8), 0)
				if g and g.fuel: g.fuel.add("coal", 50)
			var m = put(game, "manufacturer", c, 0)
			var poles := []
			for off in [Vector2i(-2, 0), Vector2i(0, -2), Vector2i(4, 0)]:
				poles.append(put(game, "pole", c + off, 0))
			f.power_dirty = true
			for i in 20:
				f._tick(0.1)
			f._rebuild_power()
			for i in 5:
				f._power(1.0)
			var ok: bool = m != null and m.pw_state == 1 and m.feeder != null
			print("TEST pow120_115 placed=", m != null, " poles=", poles.filter(func(p): return p != null).size(), " state=", m.pw_state if m else -1, " ", "OK" if ok else "FAIL")
		"drag119_115":
			# 1.1.19: лента, протянутая по фундаменту, поворачивает на углу; снос ленты не сносит фундамент
			var f = game.factory
			game.flags["free_build"] = true
			var res := []
			for on_found in [false, true]:
				var base: Vector2i = f.hq.cell + (Vector2i(14, 10) if on_found else Vector2i(14, -14))
				if on_found:
					for x in range(-1, 6):
						for z in range(-1, 6):
							put(game, "found_1", base + Vector2i(x, z), 0)
				game.select_build("belt")
				game.build_dir = 0
				game.hover_cell = base
				game.drag_last = base
				game.drag_placed = game.cmd("place", {"type": "belt", "cell": base, "dir": 0})
				for c in [base + Vector2i(1, 0), base + Vector2i(2, 0), base + Vector2i(2, 1), base + Vector2i(2, 2)]:
					game.hover_cell = c
					game._drag_world()
				var corner = f.grid.get(World.wc(base + Vector2i(2, 0)))
				res.append([on_found, corner != null and corner.dir == 1 and corner.kind != 0])
				game.cancel_build()
				if on_found:
					var bl = f.grid.get(World.wc(base + Vector2i(0, 0)))
					game.demolish = true
					game.hover_cell = base
					game._click_world()
					for i in 3:
						game._drag_world()   # то же нажатие держится — фундамент под лентой остаётся
					game.demolish = false
					await tree.process_frame
					var still: bool = f.found.has(World.wc(base)) and not f.found[World.wc(base)].is_empty()
					res.append(["found_kept", still and f.grid.get(World.wc(base)) == null])
			var ok := true
			for r0 in res:
				ok = ok and r0[1]
			print("TEST drag119_115 ", res, " ", "OK" if ok else "FAIL")
		"oremix115":
			# 1.1.16: печь с обычной рудой берёт и богатую (и наоборот)
			var pl = game.player
			game.flags["free_build"] = true
			var fu = null
			for off in [Vector2i(6, 6), Vector2i(-8, 6), Vector2i(8, -8)]:
				if fu == null:
					fu = put(game, "furnace", World.world_to_cell(pl.position) + off, 0)
			var f = game.factory
			var a1: bool = f.accept(fu, "iron_ore", null)
			var a2: bool = f.accept(fu, "iron_ore_hq", null)
			var fu2 = null
			for off in [Vector2i(-6, -6), Vector2i(10, 2), Vector2i(2, 10)]:
				if fu2 == null:
					fu2 = put(game, "furnace", World.world_to_cell(pl.position) + off, 0)
			var b1: bool = f.accept(fu2, "iron_ore_hq", null)
			var b2: bool = f.accept(fu2, "iron_ore", null)
			var b3: bool = f.accept(fu2, "copper_ore", null)
			print("HUNT oremix ", [a1, a2, b1, b2, b3], " ", fu.inv.totals(), " ", fu2.inv.totals())
			print("TEST oremix115 ", "OK" if a1 and a2 and b1 and b2 and not b3 else "FAIL")
		"hearts115":
			# 1.1.15: «Сердца» — предел зданий и цепная реакция
			var f = game.factory
			var H = game.hearts
			game.flags["free_build"] = true
			var base: Vector2i = f.hq.cell + Vector2i(12, 0)
			var free_cells := []
			for r in range(0, 30):
				for dx in range(-r, r + 1):
					for dz in range(-r, r + 1):
						if maxi(absi(dx), absi(dz)) != r:
							continue
						var c := World.wc(base + Vector2i(dx * 2, dz * 2))
						if f.can_place("chest", c) == "":
							free_cells.append(c)
				if free_cells.size() > 80:
					break
			var cap0: int = H.cap()
			var placed := []
			var fi := 0
			while H.used() < H.cap() and fi < free_cells.size():
				var b = put(game, "chest", free_cells[fi], 0)
				fi += 1
				if b != null:
					placed.append(b)
			var why_full: String = f.can_place("chest", free_cells[fi])
			var blocked: bool = why_full != ""
			# сердце рядом с другим — нельзя; на расстоянии 3 клеток — можно
			var h1 = null
			while h1 == null and fi < free_cells.size():
				h1 = put(game, "heart", free_cells[fi], 0)
				fi += 1
			var near_why: String = H.why("heart", h1.cell + Vector2i(2, 0)) if h1 != null else "x"
			var gap_ok: bool = near_why != "" and near_why.contains("2")
			var cap1: int = H.cap()
			var used1: int = H.used()   # 1.1.16: само сердце места не занимает
			var more_ok: bool = f.can_place("chest", free_cells[fi]) == ""
			# второе сердце — среди 10 ближайших к первому; вокруг второго свои здания
			var h2 = null
			for off in [Vector2i(3, 0), Vector2i(0, 3), Vector2i(-3, 0), Vector2i(0, -3), Vector2i(3, 3), Vector2i(-3, -3)]:
				if h1 != null and h2 == null:
					var c2: Vector2i = World.wc(h1.cell + off)
					for fc in f.footprint("heart", c2):
						game.world.remove_node(World.wc(fc))
					if f.can_place("heart", c2) == "":
						h2 = f.place("heart", c2, 0)
			var pulse_n: int = f.renderer("heart").parts_with_role("heart").size()
			await tree.create_timer(0.3).timeout
			var alive0 := 0
			for b in f.all:
				if not b.dead and b.beh != "hq":
					alive0 += 1
			if h1 != null:
				f.damage(h1, 1.0e9)
			await tree.create_timer(4.0).timeout
			var alive1 := 0
			for b in f.all:
				if not b.dead and b.beh != "hq":
					alive1 += 1
			var lost: int = alive0 - alive1
			var chain: bool = h2 != null and (h2.dead or not f.all.has(h2)) and lost >= 18
			var ok: bool = cap0 == 50 and blocked and h1 != null and gap_ok and cap1 == 60 and used1 == placed.size() and more_ok and pulse_n >= 3 and chain and not f.hq.dead
			print("TEST hearts115 cap0=", cap0, " used=", placed.size(), " blocked=", blocked, " why='", why_full, "' gap=", gap_ok, " cap1=", cap1,
				" more=", more_ok, " pulse_parts=", pulse_n, " h2=", h2 != null, " lost=", lost, " chain=", chain, " ", "OK" if ok else "FAIL")
		"strat_host115":
			# сеть: комната «Стратегия» (--net_host --net_strategy), гость входит с --net_strat_probe
			var N = Net._self()
			var pp = null
			for i in 400:
				await tree.create_timer(0.1).timeout
				if not N.puppets.is_empty():
					pp = N.puppets.values()[0]
					break
			await tree.create_timer(4.0).timeout
			var e = null
			if pp != null:
				DB.data.settings["monster_calm_time"] = 0.0
				e = game.enemies.spawn("crawler", pp.position + Vector3(3, 0, 0))
			await tree.create_timer(3.0).timeout
			var prof := ""
			for i in 300:
				for nk in N.saved:
					var pf := str(N.saved[nk].get("me", {}).get("profession", ""))
					if pf != "":
						prof = pf
				if prof != "" and prof != "engineer":
					break
				await tree.create_timer(0.1).timeout
			var ok: bool = game.strategy and pp != null and not pp.visible and e != null and not (e.target is Player) and game.hit_targets().is_empty() and prof != "" and prof != "engineer"
			print("TEST strat_host115 strategy=", game.strategy, " guest=", pp != null, " guest_hidden=", pp != null and not pp.visible,
				" mob_target=", (e.target.get_class() if e != null and e.target != null else "none"), " guest_prof=", prof, " ", "OK" if ok else "FAIL")
		"strategy115":
			# 1.1.15: режим «Стратегия» — без героя
			var pl = game.player
			var w = game.world
			await tree.create_timer(0.5).timeout
			var hidden: bool = game.strategy and not pl.visible and game.hit_targets().is_empty()
			# камера летит сквозь всё, быстрее, чем бегает герой
			var p0: Vector3 = pl.position
			Input.action_press("move_right")
			await tree.create_timer(1.0).timeout
			Input.action_release("move_right")
			var flown: float = World.dist(p0, pl.position)
			# урона нет, голода нет
			pl.damage(500.0)
			var no_dmg: bool = pl.alive and pl.hp >= pl.maxhp - 0.01
			var food_ok: bool = pl.food >= 99.0
			# добыча щелчком по камню или дереву вдали от «героя» — лучшим инструментом из рюкзака
			pl.inv.add("stone_axe", 1)
			pl.inv.add("stone_pickaxe", 1)
			pl.selected = 0
			var nc := Vector2i(-1, -1)
			var pc := World.world_to_cell(pl.position)
			for r in range(8, 40):
				for dx in range(-r, r + 1):
					for c2 in [pc + Vector2i(dx, -r), pc + Vector2i(dx, r)]:
						var c3: Vector2i = World.wc(c2)
						if w.nodes.has(c3) and game.factory.building_at(c3) == null and game.zone.inside_cell(c3):
							nc = c3
							break
					if nc.x >= 0:
						break
				if nc.x >= 0:
					break
			var hp0: float = w.nodes[nc].hp if nc.x >= 0 else 0.0
			var far_d: float = World.dist(pl.position, World.cell_to_world(nc)) if nc.x >= 0 else 0.0
			var mined := false
			for k in 6:
				game.hover_point = World.cell_to_world(nc)
				game.hover_cell = nc
				game.target = game.find_target()
				game._primary_action()
				await tree.create_timer(0.5).timeout
				if not w.nodes.has(nc) or w.nodes[nc].hp < hp0 - 0.1:
					mined = true
					break
			# добыча на земле: курсор над предметом — он улетает к панели уровня и оказывается в рюкзаке
			await tree.create_timer(2.0).timeout
			var drop_at: Vector3 = game.camera.project_position(game.get_viewport().get_visible_rect().size * 0.5, game.cam_dist)
			game.hover_point = drop_at + Vector3(8, 0, 0)
			game.drops.spawn("iron_ore", 1, drop_at)
			for tick in 30:
				game.drops.update(0.02)
			var cnt0 := 0
			for sl in pl.inv.slots:
				if sl != null:
					cnt0 += int(sl.n)
			var nd: int = game.drops.list.size()
			var far_kept: bool = nd > 0   # сами к камере не летят
			for d in game.drops.list.duplicate():
				game.hover_point = d.pos
				game.drops.update(0.02)
			var cnt1 := 0
			for sl in pl.inv.slots:
				if sl != null:
					cnt1 += int(sl.n)
			var flew: bool = game.drops.flying > 0
			var hover_ok: bool = far_kept and cnt1 > cnt0 and game.drops.list.size() < nd and flew
			print("HUNT drops=", nd, " inv ", cnt0, "->", cnt1, " flying=", game.drops.flying, " left=", game.drops.list.size())
			# щелчок по зданию открывает его окно, где бы ни была камера
			var bc := World.world_to_cell(pl.position) + Vector2i(14, 9)
			var b = null
			for off in [Vector2i(0, 0), Vector2i(-20, 6), Vector2i(8, -18), Vector2i(-12, -14), Vector2i(18, 12)]:
				b = put(game, "workbench", World.wc(bc + off), 0)
				if b != null:
					break
			game.hud.close_all()
			if b != null:
				game.hover_cell = b.cell
				game.hover_point = b.center()
				game._click_world()
			var opened: bool = b != null and game.hud.any_window_open()
			print("HUNT bld=", b.type if b != null else "none")
			game.hud.close_all()
			game.lmb = false
			# монстр не замечает «героя» и идёт на здание
			DB.data.settings["monster_calm_time"] = 0.0
			var e = game.enemies.spawn("crawler", pl.position + Vector3(4, 0, 0))
			await tree.create_timer(2.0).timeout
			var ignores: bool = e != null and not (e.target is Player)
			# навыки героя скрыты и не качаются
			game.skill_points = 1
			game.upgrade_skill("athletics")
			var skill_ok: bool = int(game.skills.get("athletics", 0)) == 0 and game.skill_points == 1
			# мороз: иней на экране и камера вязнет
			game.events.active["frost"] = 60.0
			await tree.create_timer(2.5).timeout
			var frost_ok: bool = game.strat.fx.frost > 0.3 and game.strat.pan_k() < 0.9 and not game.strat.rect.visible   # 1.1.17: без картинки на экране
			game.events.active.erase("frost")
			game.events.active["acid_rain"] = 60.0
			await tree.create_timer(1.5).timeout
			var acid_ok: bool = game.strat.fx.toxic > 0.2
			game.events.active.erase("acid_rain")
			# 1.1.16: вещей героя нет — нож не выдан, бинт/меч не крафтятся, аптечка не кладётся, кирка — да
			var hand: Array = DB.recipes_for("hand") + DB.recipes_for("workbench")
			var left_pk: int = game.player.inv.add("medkit", 2)
			var no_pers: bool = game.player.inv.count("knife") == 0 and game.player.inv.count("medkit") == 0 and left_pk == 0 \
				and not ("bandage" in hand) and not ("sword" in hand) and ("stone_pickaxe" in hand) and game.factory.can_place("medbay", game.factory.hq.cell + Vector2i(9, 9)) != ""
			game.player.inv.add("stone_pickaxe", 1)
			no_pers = no_pers and game.player.inv.count("stone_pickaxe") > 0
			print("HUNT strat personal ", no_pers, " hand=", hand.size())
			var ok: bool = hidden and flown > 8.0 and no_dmg and food_ok and mined and hover_ok and opened and ignores and skill_ok and frost_ok and acid_ok and no_pers
			print("TEST strategy115 pers=", no_pers, " hidden=", hidden, " flown=", snappedf(flown, 0.1), " no_dmg=", no_dmg, " food=", food_ok, " mined=", mined, " hover_pick=", hover_ok, " far=", snappedf(far_d, 0.1),
				" opened=", opened, " ignores=", ignores, " skill=", skill_ok, " frost=", frost_ok, " acid=", acid_ok, " ", "OK" if ok else "FAIL")
		"duelA_autosave0_115_r13_115":
			# Комната/сервер: «Автосохранение мира комнаты, мин» = 0 (у одиночной игры 0 — «выключено») → сохранение каждый кадр
			var N = Net._self()
			var co = DB.data.settings.get("coop", {}).duplicate()
			co["autosave_min"] = 0.0
			DB.data.settings["coop"] = co
			print("HUNT host err='", N.host(24799, 8, {"name": "Auto0"}), "' mode=", N.mode)
			var sp: String = DB.saves_dir().path_join(N.room_slot() + ".json")
			var saves := 0
			for i in 30:
				DirAccess.remove_absolute(sp)
				await tree.process_frame
				if FileAccess.file_exists(sp):
					saves += 1
			print("HUNT autosave_min=0: world saved ", saves, " times in 30 frames (", sp.get_file(), ")")
			DirAccess.remove_absolute(sp)
			DirAccess.remove_absolute(sp.replace(".json", ".meta.json"))
			N.leave()
			print("TEST duelA_autosave0_115 ", "FAIL(save every frame)" if saves > 5 else "OK")
		"duelA_menuopen115_r13_115":
			# Мод «только данные» (.fcmod, лишь menu.json): кнопка главного меню «Новая игра» с командой "open ..." → OS.shell_open(любой путь/URI)
			var mark := "/tmp/claude-0/duel/duelA_menuopen115_marker.txt"
			DirAccess.remove_absolute(mark)
			var zp := "/tmp/claude-0/duel/duelA_menu115.fcmod"
			var zw := ZIPPacker.new()
			zw.open(zp)
			zw.start_file("menu115/mod.json"); zw.write_file(JSON.stringify({"name": "Красивое меню", "version": "1.0"}).to_utf8_buffer()); zw.close_file()
			zw.start_file("menu115/menu.json"); zw.write_file(JSON.stringify({"buttons": [{"id": "command", "text": "Новая игра", "command": "open file:///home/victim/Downloads/setup.exe"}, {"id": "quit"}]}).to_utf8_buffer()); zw.close_file()
			zw.close()
			var res: Dictionary = ModKit.install(zp)
			print("HUNT install: ok=", res.get("ok"), " files=", res.get("files"), " skipped=", res.get("skipped"))
			DB.load_all()   # следующий запуск игры: моды включены по умолчанию
			print("HUNT menu buttons from mod: ", DB.menu("buttons", []))
			var mn = load("res://scripts/menu.gd").new()
			tree.root.add_child(mn)
			await tree.process_frame
			var hit = null
			var texts := []
			for b in mn.find_children("*", "Button", true, false):
				texts.append(b.text)
				if b.text == "Новая игра":
					hit = b
			print("HUNT menu shows buttons: ", texts)
			if hit:
				hit.pressed.emit()
			var t0 := Time.get_ticks_msec()
			while not FileAccess.file_exists(mark) and Time.get_ticks_msec() - t0 < 3000:
				await tree.process_frame
			var opened := FileAccess.file_exists(mark)
			print("HUNT shell_open reached: ", opened, " ", FileAccess.get_file_as_string(mark).strip_edges() if opened else "")
			var md: String = ModKit.dir_of(str(res.get("id", "menu115")))
			for fn in DirAccess.get_files_at(md):
				DirAccess.remove_absolute(md.path_join(fn))
			DirAccess.remove_absolute(md)
			print("TEST duelA_menuopen115 ", "FAIL(data-only mod button runs OS.shell_open on arbitrary path)" if opened else "OK")
		"duelA_bpbig115_r13_115":
			# Чужой чертёж .fcbp: проверяются только w/h (правило blueprint_max), координаты зданий — нет
			var B = game.blueprints
			var fp: String = B.share_dir().path_join("duelA_bpbig115.fcbp")
			var its := []
			for i in 5:
				its.append({"t": "belt", "x": i * 40, "z": i * 40, "d": 0})
			DB.write_file(fp, {"format": "frontier_blueprint", "version": 1, "blueprint": {"name": "Малыш115", "w": 2, "h": 2, "items": its}})
			var got: Array = B.import_all()
			print("HUNT max_size=", B.max_size(), " imported=", got)
			game.flags["free_build"] = true
			var at: Vector2i = game.factory.hq.cell + Vector2i(8, 8)
			var n: int = B.paste(B.saved.get("Малыш115", {}), at, 0)
			var far := 0
			for b in game.factory.all:
				if b.type == "belt" and not b.dead:
					far = maxi(far, maxi(absi(b.cell.x - at.x), absi(b.cell.y - at.y)))
			print("HUNT placed=", n, " span cells=", far + 1, " (limit ", B.max_size(), ")")
			DirAccess.remove_absolute(fp)
			print("TEST duelA_bpbig115 ", "FAIL(blueprint spans beyond blueprint_max)" if far + 1 > B.max_size() else "OK")
		"duelA_modtxt115_r12_115":
			# Мод «только данные» (.fcmod): .gd отбрасывается, но GDScript в файле .txt + поле предмета "script" исполняется
			var mark := "/tmp/claude-0/duel/duelA_modtxt115_pwned.txt"
			DirAccess.remove_absolute(mark)
			var zp := "/tmp/claude-0/duel/duelA_evil115.fcmod"
			var zw := ZIPPacker.new()
			zw.open(zp)
			zw.start_file("evil115/mod.json"); zw.write_file(JSON.stringify({"name": "evil115", "version": "1.0", "author": "x"}).to_utf8_buffer()); zw.close_file()
			zw.start_file("evil115/items.json"); zw.write_file(JSON.stringify({"evil_cookie115": {"name": "Печенька", "price": 1, "script": "readme.txt"}}).to_utf8_buffer()); zw.close_file()
			zw.start_file("evil115/payload.gd"); zw.write_file("extends RefCounted".to_utf8_buffer()); zw.close_file()
			var src := "extends RefCounted\nfunc _init():\n\tvar f = FileAccess.open(\"%s\", FileAccess.WRITE)\n\tf.store_string(\"code ran as \" + OS.get_environment(\"USER\") + \" pid \" + str(OS.get_process_id()))\n\tf.close()\nfunc on_use(g, id):\n\treturn true\n" % mark
			zw.start_file("evil115/readme.txt"); zw.write_file(src.to_utf8_buffer()); zw.close_file()
			zw.close()
			var res: Dictionary = ModKit.install(zp)
			print("HUNT install: ", res)
			DB.load_all()   # как при следующем запуске игры (моды включены по умолчанию)
			print("HUNT item loaded: ", DB.data.items.has("evil_cookie115"), " script=", DB.item("evil_cookie115").get("script", ""), " find_file=", DB.find_file("readme.txt"))
			game.player.inv.add("evil_cookie115", 1)
			var slot := -1
			for i in game.player.inv.slots.size():
				if game.player.inv.slots[i] != null and game.player.inv.slots[i].id == "evil_cookie115":
					slot = i
			game.player.use_item(slot)
			var ran := FileAccess.file_exists(mark)
			print("HUNT payload file: ", ran, " ", FileAccess.get_file_as_string(mark) if ran else "")
			# уборка: удалить мод
			var md: String = ModKit.dir_of(str(res.get("id", "evil115")))
			for fn in DirAccess.get_files_at(md):
				DirAccess.remove_absolute(md.path_join(fn))
			DirAccess.remove_absolute(md)
			print("TEST duelA_modtxt115 ", "FAIL(GDScript from .txt in data-only mod executed)" if ran else "OK")
		"duelB_lobby115_r11_115":
			# B11: общий список комнат (ntfy, писать может кто угодно): чужое «closed» с t из будущего прячет комнату
			var L = Net._self().lobby
			var now := int(Time.get_unix_time_from_system())
			var real := {"fc": 18, "id": "abcd1234ef01", "name": "Комната Бори", "host": "Боря", "game": DB.game_name(), "ip": "203.0.113.7", "port": 24680, "t": now - 10}
			var lines := [JSON.stringify({"event": "message", "message": JSON.stringify(real)})]
			L.parse("\n".join(lines))
			print("HUNT lobby honest feed: rooms=", L.rooms.keys())
			var forged := {"fc": 18, "id": "abcd1234ef01", "closed": true, "t": now + 100000000}
			lines.append(JSON.stringify({"event": "message", "message": JSON.stringify(forged)}))
			real["t"] = now   # хозяин объявляет снова (раз в 240 с) — уже не помогает
			lines.append(JSON.stringify({"event": "message", "message": JSON.stringify(real)}))
			L.parse("\n".join(lines))
			print("HUNT lobby + forged closed (anyone can POST it) + host re-announce: rooms=", L.rooms.keys())
		"duelA_melt115_r11_115":
			# Авария АЭС: урон только game.player — второй герой сплитскрина (и гости) у реактора невредимы
			var f = game.factory
			game.flags["free_build"] = true
			var sp = game.split
			sp.start(1)
			await tree.process_frame
			var p1 = sp.p1()
			var p2 = sp.p2()
			print("HUNT split running=", sp.running(), " p1=", p1, " p2=", p2)
			var c: Vector2i = f.hq.cell + Vector2i(16, 0)
			var r = put_near(game, "nuclear_reactor", c, 0)
			print("HUNT reactor=", r != null)
			var rp: Vector3 = r.center()
			p1.position = rp + Vector3(6, 0, 0) * World.C
			p2.position = rp + Vector3(0, 0, 6) * World.C
			p1.hp = p1.maxhp
			p2.hp = p2.maxhp
			var h1: float = p1.hp
			var h2: float = p2.hp
			f.nuc.meltdown(r)
			print("HUNT after meltdown: p1 hp ", h1, " -> ", p1.hp, " ; p2 hp ", h2, " -> ", p2.hp, " (same distance)")
			print("TEST duelA_melt115 ", "FAIL(p2 untouched)" if p2.hp >= h2 and p1.hp < h1 else "OK")
		"duelA_met115_r11_115":
			# модуль «События мира» выключен — одиночные метеориты всё равно падают
			game.ng_modules["events"] = false
			var EV = game.events
			print("HUNT module events=", game.module("events"))
			var before := 0
			for c in game.world.nodes:
				if game.world.nodes[c].res == "meteorite":
					before += 1
			var hp0: float = game.player.hp
			EV._met_t = 0.5
			EV.update(1.1)
			var after := 0
			for c in game.world.nodes:
				if game.world.nodes[c].res == "meteorite":
					after += 1
			print("HUNT meteorites before=", before, " after=", after)
			print("TEST duelA_met115 ", "FAIL(events module off, meteor fell %d)" % (after - before) if after > before else "OK")
		"duelA_ration115_r11_115":
			# Неполное исправление A-3 r9: кап очков только у самих товаров магазина; «Сухпаёк» из них — без капа
			var e18: Dictionary = (DB.setting("economy18", {}) as Dictionary).duplicate()
			e18["on"] = true
			DB.data.settings["economy18"] = e18
			var f = game.factory
			game.flags["free_build"] = true
			game.tech.unlock("t_electro")
			game.tech.refresh_locks()
			var c: Vector2i = f.hq.cell + Vector2i(12, 8)
			for dx in range(-4, 16):
				for dz in range(-4, 14):
					game.world.remove_node(World.wc(c + Vector2i(dx, dz)))
			var sk = put_near(game, "sink", c, 0)
			var shop = put_near(game, "sink_shop", c + Vector2i(5, 0), 0)
			var wb = put_near(game, "workbench", c + Vector2i(9, 0), 0)
			for gx in [0, 4, 8]:
				var g = put_near(game, "coal_generator", c + Vector2i(gx, 7), 0)
				if g and g.fuel:
					g.fuel.add("coal", 50)
			f.auto_wire_all()
			f.power_dirty = true
			var pl = game.player
			for i in pl.inv.slots.size():
				pl.inv.slots[i] = null
			for k in ["canned_food", "berry", "ration"]:
				f.hq.inv.remove(k, f.hq.inv.count(k))
			var C0 := 30
			pl.inv.add("sink_coupon", C0)
			pl.position = shop.center() + Vector3(1.5, 0, 0)
			game.cmd("craft", {"rid": "shop_canned_food", "n": 10, "station": "sink_shop"})
			game.cmd("craft", {"rid": "shop_berry", "n": 8, "station": "sink_shop"})
			for k in 3000:
				game._update_craft(0.1)
				if game.craft_queue.is_empty():
					break
			var cf: int = pl.inv.count("canned_food") + f.hq.inv.count("canned_food")
			var be: int = pl.inv.count("berry") + f.hq.inv.count("berry")
			print("HUNT 30 coupons -> canned_food=", cf, " berry=", be, " coupons left=", pl.inv.count("sink_coupon"))
			pl.position = wb.center() + Vector3(1.5, 0, 0)
			game.cmd("craft", {"rid": "ration", "n": mini(cf, be / 2), "station": "workbench"})
			for k in 6000:
				game._update_craft(0.1)
				if game.craft_queue.is_empty():
					break
			var ra: int = pl.inv.count("ration") + f.hq.inv.count("ration")
			print("HUNT crafted ration=", ra, " sink_points(ration)=", Blocks.sink_points("ration", 100.0), " vs canned_food=", Blocks.sink_points("canned_food", 100.0))
			pl.inv.remove("ration", pl.inv.count("ration"))
			f.hq.inv.remove("ration", f.hq.inv.count("ration"))
			for q in ra:
				f.accept(sk, "ration", sk) or sk.inv.add("ration", 1)
			for k in 4000:
				f._tick(0.04)
				if sk.inv.first_item() == "" and k > 50:
					break
			var cp: int = (sk.out.count("sink_coupon") if sk.out else 0) + pl.inv.count("sink_coupon")
			print("HUNT after sink: coupons ", C0, " -> ", cp)
			print("TEST duelA_ration115 ", "FAIL(coupon loop via ration: %d -> %d)" % [C0, cp] if cp > C0 else "OK(%d -> %d)" % [C0, cp])
		"duelA_ufo115_r11_115":
			# Петля купонов через НЛО: купоны → ТВЭЛ (магазин утилизации, 15) → НЛО ценит по цене 8831 × 0.6 → антиматерия → Утилизатор 90000 очков
			var e18: Dictionary = (DB.setting("economy18", {}) as Dictionary).duplicate()
			e18["on"] = true
			DB.data.settings["economy18"] = e18
			var f = game.factory
			game.flags["free_build"] = true
			game.ng_modules["ufo"] = true
			var c: Vector2i = f.hq.cell + Vector2i(12, 8)
			for dx in range(-4, 16):
				for dz in range(-4, 14):
					game.world.remove_node(World.wc(c + Vector2i(dx, dz)))
			var sk = put_near(game, "sink", c, 0)
			var shop = put_near(game, "sink_shop", c + Vector2i(5, 0), 0)
			var pad = put_near(game, "ufo_pad", c + Vector2i(10, 0), 0)
			for gx in [0, 4, 8]:
				var g = put_near(game, "coal_generator", c + Vector2i(gx, 7), 0)
				if g and g.fuel:
					g.fuel.add("coal", 50)
			f.auto_wire_all()
			f.power_dirty = true
			var pl = game.player
			for i in pl.inv.slots.size():
				pl.inv.slots[i] = null
			var C0 := 255
			pl.inv.add("sink_coupon", C0)
			pl.position = shop.center() + Vector3(1.5, 0, 0)
			game.cmd("craft", {"rid": "shop_fuel_rod", "n": C0 / 15, "station": "sink_shop"})
			for k in 3000:
				game._update_craft(0.1)
				if game.craft_queue.is_empty():
					break
			var rods: int = pl.inv.count("fuel_rod") + f.hq.inv.count("fuel_rod")
			pl.inv.remove("fuel_rod", pl.inv.count("fuel_rod"))
			f.hq.inv.remove("fuel_rod", f.hq.inv.count("fuel_rod"))
			print("HUNT ", C0, " coupons -> fuel_rod x", rods, " (station would pay only ", game.sell_price("fuel_rod"), " cr each)")
			var SW = game.star
			SW.setup(pad)
			pad.inv.add("fuel_rod", rods)
			var s: Dictionary = SW.st(pad)
			s.orders = [{"id": "antimatter", "n": 99}]
			print("HUNT ufo sell_value(fuel_rod)=", SW.sell_value("fuel_rod"), " price(antimatter) today=", SW.price("antimatter"))
			var r1: Dictionary = SW.trade(pad)
			var r2: Dictionary = SW.trade(pad)
			var am: int = pad.out.count("antimatter")
			print("HUNT ufo trade1=", r1, " trade2=", r2, " antimatter delivered=", am, " balance left=", s.balance)
			pad.out.remove("antimatter", am)
			var pts := 0.0
			for q in am:
				f.accept(sk, "antimatter", sk) or sk.inv.add("antimatter", 1)
			for k in 4000:
				f._tick(0.04)
				if sk.inv.first_item() == "" and k > 50:
					break
			var cp: int = sk.out.count("sink_coupon") if sk.out else 0
			print("HUNT sink_points(antimatter)=", Blocks.sink_points("antimatter", 100.0), " -> coupons now=", cp, " (+", sk.bstate.get("pts", "?"), " pts)")
			print("TEST duelA_ufo115 ", "FAIL(coupon loop via UFO: %d -> %d coupons)" % [C0, cp] if cp > C0 else "OK(%d -> %d)" % [C0, cp])
		"duelA_buff_115_r10_115":
			# эффекты хранятся по ключу характеристики: «Маяк ускорения», буря и стимуляторы затирают друг друга
			var f = game.factory
			game.flags["free_build"] = true
			game.ng_modules["boosters"] = true
			var pl = game.player
			for i in pl.inv.slots.size():
				pl.inv.slots[i] = null
			pl.inv.add("stim_speed", 2)
			var used: bool = pl.use_item(0)
			var m0 = game.effects.get("move", {}).duplicate()
			print("HUNT ate stim_speed used=", used, " effect move=", m0, " bonus(move)=", game.bonus("move"))
			# а) прошёл мимо маяка ускорения
			var c: Vector2i = World.world_to_cell(pl.position) + Vector2i(3, 0)
			var bc = put_near(game, "boost_beacon", c, 0)
			var gen = put_near(game, "coal_generator", c + Vector2i(0, 4), 0)
			if gen and gen.fuel:
				gen.fuel.add("coal", 50)
			f.auto_wire_all()
			f.power_dirty = true
			for k in 50:
				f._tick(0.04)
			var m1 = game.effects.get("move", {}).duplicate()
			pl.position += Vector3(40, 0, 0) * World.C
			for k in 50:
				f._tick(0.04)
				game._update_effects(0.04)
			var m2 = game.effects.get("move", {}).duplicate()
			print("HUNT near beacon: ", m1, " ; walked away 2 s: ", m2, " bonus(move)=", game.bonus("move"))
			# б) буря: стимулятор снимает замедление бури, а буря — стимулятор
			game.effects.clear()
			game.events.start("storm")
			var s0 = game.bonus("move")
			var slot := -1
			for i in pl.inv.slots.size():
				if pl.inv.slots[i] != null and pl.inv.slots[i].id == "stim_speed":
					slot = i
			pl.use_item(slot)
			var s1 = game.bonus("move")
			print("HUNT keys ", game.effects.keys())
			print("HUNT storm: bonus before stim ", s0, " ; after stim ", s1, " (storm still active=", game.events.active.has("storm"), ")")
			print("TEST duelA_buff_115 done")
			var bug: bool = m2.is_empty() or (s1.get("name", "") != "" and not str(s0.get("name", "")) in str(s1.get("name", "")) and game.events.active.has("storm"))
			print("TEST duelA_buff_115 ", "FAIL(stim lost at beacon / stim cancels storm slowdown)" if bug else "OK")
		"duelA_daily_115_r10_115":
			# Заказ дня: need = clamp(3000 / цена, 10, 300) — для дорогих предметов минимум 10 штук, награда = цена × 10 × 0.5
			DB.data.settings["daily"] = {"enabled": true, "speed_bonus": 0.25, "value": 3000, "credit_k": 0.5}   # как в core/settings.json (тесты его выключают)
			var P = game.progress17
			var rows := []
			for it in ["plank", "circuit", "superconductor", "helium3", "fuel_rod"]:
				P.made = {it: 1}
				P.daily = {}
				game.day_n += 1
				P._daily_tick()
				rows.append([it, DB.item(it).get("price"), P.daily.get("need"), P.daily.get("reward"), snappedf(float(P.daily.get("need", 0)) * float(DB.item(it).get("price", 1)), 1)])
			for r in rows:
				print("HUNT daily item=", r[0], " price=", r[1], " need=", r[2], " reward=", r[3], " (value of order ", r[4], ", setting value=3000, credit_k 0.5)")
			print("TEST duelA_daily_115 ", "FAIL(daily reward for fuel_rod = %s, ~%d x normal 1500)" % [rows[4][3], int(rows[4][3]) / 1500] if rows[4][3] != null and int(rows[4][3]) > 3000 else "OK")
		"duelA_drkill_115_r10_115":
			# Дрон станции сбит (или станция снесена) с изношенным инструментом в грузе — на землю падает новый
			var f = game.factory
			game.flags["free_build"] = true
			var ds = put_near(game, "drone_station", f.hq.cell + Vector2i(10, 6), 0)
			game.drones.sync()
			var d: Dictionary = game.drones.st[ds].d[0]
			d.item = "steel_pickaxe"
			d.n = 1
			d["sl"] = [{"id": "steel_pickaxe", "n": 1, "dur": 4.0}]
			d.state = "fly"
			var n0: int = game.drops.list.size()
			game.drones._kill(d)
			var got := []
			for i in range(n0, game.drops.list.size()):
				got.append([game.drops.list[i].id, game.drops.list[i].n, game.drops.list[i].slot])
			# второй случай: станцию снесли, пока дрон в пути
			var d2: Dictionary = game.drones.st[ds].d[0]
			d2.state = "fly"
			d2.item = "raw_meat"
			d2.n = 5
			d2["sl"] = [{"id": "raw_meat", "n": 5, "fresh": 3.0}]
			var n1: int = game.drops.list.size()
			game.drones._drop_station(ds)
			for i in range(n1, game.drops.list.size()):
				got.append([game.drops.list[i].id, game.drops.list[i].n, game.drops.list[i].slot])
			print("HUNT drops after kill / station removal: ", got)
			var bug := false
			for g in got:
				if (g[2] as Dictionary).is_empty():
					bug = true
			print("TEST duelA_drkill_115 ", "FAIL(drone cargo with dur/fresh falls as new items)" if bug else "OK")
		"duelA_he3_115_r10_115":
			# Гелий-3 из отходов: 4 отработанных ТВЭЛа (цена 0) + 1 сверхпроводник (137) → 3 гелия-3 (по 6000)
			var e18: Dictionary = (DB.setting("economy18", {}) as Dictionary).duplicate()
			e18["on"] = true   # как в обычной игре (тесты по умолчанию — на старой экономике)
			DB.data.settings["economy18"] = e18
			print("HUNT econ_on=", Blocks.econ_on())
			var f = game.factory
			game.flags["free_build"] = true
			var c: Vector2i = f.hq.cell + Vector2i(12, 8)
			for dx in range(-4, 14):
				for dz in range(-4, 12):
					game.world.remove_node(World.wc(c + Vector2i(dx, dz)))
			var cf = put_near(game, "centrifuge", c, 0)
			var sk = put_near(game, "sink", c + Vector2i(5, 0), 0)
			var gen = put_near(game, "coal_generator", c + Vector2i(0, 5), 0)
			var gen2 = put_near(game, "coal_generator", c + Vector2i(4, 5), 0)
			for g in [gen, gen2]:
				if g and g.fuel:
					g.fuel.add("coal", 50)
			f.auto_wire_all()
			f.power_dirty = true
			f.set_recipe(cf, "helium_from_waste")
			print("HUNT recipe=", cf.recipe, " price waste=", DB.item("nuclear_waste").get("price"), " sc=", DB.item("superconductor").get("price"), " he3=", DB.item("helium3").get("price"), " sell_value(sc)=", snappedf(game.sell_value("superconductor"), 0.1))
			cf.inv.add("nuclear_waste", 4)
			cf.inv.add("superconductor", 1)
			for k in 1500:
				f._tick(0.04)
				if cf.out.count("helium3") >= 3:
					break
			var he: int = cf.out.count("helium3")
			print("HUNT centrifuge made helium3=", he, " left waste=", cf.inv.count("nuclear_waste"), " sc=", cf.inv.count("superconductor"))
			cf.out.remove("helium3", he)
			var left := he
			for k in 6000:
				while left > 0 and f.accept(sk, "helium3", sk):
					left -= 1
				f._tick(0.04)
				if left == 0 and sk.inv.first_item() == "":
					break
			var got: int = sk.out.count("sink_coupon") if sk.out else 0
			print("HUNT sink: ", he, " helium3 -> ", got, " coupons (fuel rod in shop = 15 coupons => ", got / 15, " rods => ", got / 15, " waste)")
			var c0: int = game.credits
			game.player.inv.add("helium3", 3)
			game.sell("helium3", 3)
			print("HUNT station: 3 helium3 -> ", game.credits - c0, " cr (input superconductor worth ", snappedf(game.sell_value("superconductor"), 0.1), " cr)")
			var c1: int = game.credits
			game.player.inv.add("fuel_rod", 1)
			game.sell("fuel_rod", 1)
			print("HUNT station: 1 fuel_rod (15 coupons in shop) -> ", game.credits - c1, " cr")
			print("TEST duelA_he3_115 ", "FAIL(4 waste + 1 superconductor -> %d coupons; one cycle pays for %d fuel rods)" % [got, got / 15] if got > 60 else "OK")
		"duelA_lang10_115_r10_115":
			Prefs.values["language"] = "en"
			Lang.rebuild()
			var arr = JSON.parse_string(FileAccess.get_file_as_string("/tmp/claude-0/-home-user/6fafaceb-db96-58c1-b5cd-7e4e38e4c559/scratchpad/lits.json"))
			var fa := FileAccess.open("/tmp/claude-0/-home-user/6fafaceb-db96-58c1-b5cd-7e4e38e4c559/scratchpad/untr10.txt", FileAccess.WRITE)
			var rx := RegEx.create_from_string("[А-Яа-яЁё]")
			var bad := 0
			for e in arr:
				var s: String = str(e[2]).c_unescape()
				var t: String = Lang.t(s)
				if rx.search(t) != null:
					bad += 1
					fa.store_line("%s:%d\t%s\t=>\t%s" % [e[0], int(e[1]), s.replace("\n", "\\n"), t.replace("\n", "\\n")])
			fa.close()
			print("HUNT lang10 bad=", bad, " of ", arr.size())
			print("TEST duelA_lang10_115 done")
		"duelA_link_115_r10_115":
			# Канал штаба «Из штаба» берёт по id: изношенная кирка и подгнившая еда выходят новыми
			var f = game.factory
			game.flags["free_build"] = true
			var c: Vector2i = f.hq.cell + Vector2i(6, 3)
			for dx in range(-3, 9):
				for dz in range(-3, 9):
					game.world.remove_node(World.wc(c + Vector2i(dx, dz)))
			var ln = put_near(game, "hq_link", c, 0)
			var gen = put_near(game, "coal_generator", c + Vector2i(0, 4), 0)
			if gen and gen.fuel:
				gen.fuel.add("coal", 50)
			for i in f.hq.inv.slots.size():
				if f.hq.inv.slots[i] != null and str(f.hq.inv.slots[i].id) in ["steel_pickaxe", "raw_meat"]:
					f.hq.inv.slots[i] = null
			f.hq.inv.add_slot({"id": "steel_pickaxe", "n": 1, "dur": 3.0})
			f.hq.inv.add_slot({"id": "steel_pickaxe", "n": 1, "dur": 5.0})
			f.hq.inv.add_slot({"id": "raw_meat", "n": 10, "fresh": 5.0})
			f.auto_wire_all()
			f._rebuild_power()
			ln.cfg = {"mode": "take", "items": ["steel_pickaxe", "raw_meat"]}
			for k in 60 * 20:
				f._tick(f.TICK)
				if f.hq.inv.count("steel_pickaxe") == 0 and f.hq.inv.count("raw_meat") == 0:
					break
			var outs := []
			for s in ln.out.slots:
				if s != null:
					outs.append(s)
			print("HUNT hq after: pick=", f.hq.inv.count("steel_pickaxe"), " meat=", f.hq.inv.count("raw_meat"), " ; channel out slots=", outs, " (max dur ", DB.item("steel_pickaxe").get("durability"), ", spoil ", DB.item("raw_meat").get("spoil"), ")")
			var bug := false
			for s in outs:
				if not (s.has("dur") or s.has("fresh")):
					bug = true
			print("TEST duelA_link_115 ", "FAIL(channel repairs worn tools / refreshes food)" if bug else "OK")
		"duelA_order0_115_r10_115":
			# Заказ на покупку предмета с ценой 0 (отработанный ТВЭЛ): рынок 0 → любое количество за 1 кр
			var e18: Dictionary = (DB.setting("economy18", {}) as Dictionary).duplicate()
			e18["on"] = true
			DB.data.settings["economy18"] = e18
			game.ng_modules["orders"] = true
			game.credits = 100
			var cr0: int = game.credits
			var w0: int = game.factory.hq.inv.count("nuclear_waste") + game.player.inv.count("nuclear_waste")
			var o: Dictionary = game.orders.place("buy", "nuclear_waste", 500, 1)
			print("HUNT order market_total=", game.orders.market_total(o), " greed=", game.orders.greed(o))
			for k in 60:
				game.orders.update(20.0)
				if not o.offers.is_empty():
					break
			print("HUNT offers=", o.offers)
			var ok := false
			if not o.offers.is_empty():
				ok = game.orders.accept(o, o.offers[0])
			var w1: int = game.factory.hq.inv.count("nuclear_waste") + game.player.inv.count("nuclear_waste")
			var paid: int = cr0 - game.credits
			print("HUNT deal=", ok, " paid ", paid, " cr for ", w1 - w0, " nuclear_waste")
			# что из них делается: 1 отход + 10 серной кислоты → 10 обогащённого урана (Утилизатор: 1500 очков = 15 купонов = ТВЭЛ)
			print("HUNT recycle_waste: 10 enriched_uranium sink pts=", Blocks.sink_points("enriched_uranium", 100.0) * 10, " station=", snappedf(game.sell_value("enriched_uranium") * 10, 0.1), " cr; sulfuric_acid buy=", game.buy_price("sulfuric_acid"))
			var f = game.factory
			game.flags["free_build"] = true
			var c: Vector2i = f.hq.cell + Vector2i(12, 8)
			for dx in range(-4, 14):
				for dz in range(-4, 12):
					game.world.remove_node(World.wc(c + Vector2i(dx, dz)))
			var cf = put_near(game, "centrifuge", c, 0)
			var gen = put_near(game, "coal_generator", c + Vector2i(0, 5), 0)
			gen.fuel.add("coal", 50)
			f.auto_wire_all()
			f.power_dirty = true
			f.set_recipe(cf, "recycle_waste")
			cf.inv.add("nuclear_waste", 1)
			cf.inv.add("sulfuric_acid", 10)
			for k in 2000:
				f._tick(0.04)
				if cf.out.count("enriched_uranium") >= 10:
					break
			var eu: int = cf.out.count("enriched_uranium")
			var c2: int = game.credits
			game.player.inv.add("enriched_uranium", eu)
			game.sell("enriched_uranium", eu)
			print("HUNT centrifuge recycle_waste: 1 waste + 10 acid (", game.buy_price("sulfuric_acid") * 10, " cr) -> EU=", eu, " -> station ", game.credits - c2, " cr")
			print("TEST duelA_order0_115 ", "FAIL(%d nuclear_waste for %d cr; 1 waste + 60 cr acid -> 10 EU -> 170 cr)" % [w1 - w0, paid] if w1 - w0 >= 100 and paid <= 5 else "OK")
		"duelA_rodcr_115_r10_115":
			# Кредиты через магазин утилизации: брёвна со станции → лесопилка → Утилизатор → 15 купонов → ТВЭЛ → станция
			var e18: Dictionary = (DB.setting("economy18", {}) as Dictionary).duplicate()
			e18["on"] = true
			DB.data.settings["economy18"] = e18
			var f = game.factory
			game.flags["free_build"] = true
			var c: Vector2i = f.hq.cell + Vector2i(12, 8)
			for dx in range(-4, 14):
				for dz in range(-4, 12):
					game.world.remove_node(World.wc(c + Vector2i(dx, dz)))
			var sm = put_near(game, "sawmill", c, 0)
			var sk = put_near(game, "sink", c + Vector2i(5, 0), 0)
			var shop = put_near(game, "sink_shop", c + Vector2i(9, 0), 0)
			for gx in [0, 4, 8]:
				var g = put_near(game, "coal_generator", c + Vector2i(gx, 6), 0)
				if g and g.fuel:
					g.fuel.add("coal", 50)
			f.auto_wire_all()
			f.power_dirty = true
			f.set_recipe(sm, "d17_planks_saw")
			game.credits = 1000
			var cr0: int = game.credits
			var hq0: int = f.hq.inv.count("log")
			game.buy("log", 120)
			var bought: int = f.hq.inv.count("log") - hq0
			f.hq.inv.remove("log", bought)
			print("HUNT bought ", bought, " logs for ", cr0 - game.credits, " cr (buy_price log=", game.buy_price("log"), ")")
			var logs := bought
			for k in 20000:
				while logs > 0 and sm.inv.count("log") < 5:
					sm.inv.add("log", 1)
					logs -= 1
				var pk: int = sm.out.count("plank")
				if pk > 0:
					sm.out.remove("plank", pk)
					for q in pk:
						f.accept(sk, "plank", sk) or sk.inv.add("plank", 1)
				f._tick(0.04)
				if logs == 0 and sm.inv.count("log") == 0 and sm.out.is_empty() and sk.inv.first_item() == "" and k > 100:
					break
			var cp: int = sk.out.count("sink_coupon") if sk.out else 0
			print("HUNT logs -> planks -> sink: coupons=", cp)
			var pl = game.player
			sk.out.remove("sink_coupon", cp)
			pl.inv.add("sink_coupon", cp)
			pl.position = shop.center() + Vector3(1.5, 0, 0)
			game.cmd("craft", {"rid": "shop_fuel_rod", "n": cp / 15, "station": "sink_shop"})
			for k in 3000:
				game._update_craft(0.1)
				if game.craft_queue.is_empty():
					break
			var rods: int = pl.inv.count("fuel_rod") + f.hq.inv.count("fuel_rod")
			var cr1: int = game.credits
			game.sell("fuel_rod", rods)
			print("HUNT shop gave fuel_rod=", rods, "; station paid ", game.credits - cr1, " cr; total ", cr0, " -> ", game.credits, " cr")
			print("TEST duelA_rodcr_115 ", "FAIL(credits loop: %d -> %d cr)" % [cr0, game.credits] if game.credits > cr0 else "OK")
		"duelA_tut_115_r10_115":
			# Обучение: шаг «Пройти 20 м» — пройденное сохраняется (walked), но загрузка его обнуляет (_enter)
			var T = game.tutorial
			T.done = false
			T.active = true
			T.step = 1
			T._enter()
			T.walked = 17.0
			var d: Dictionary = T.to_dict()
			T.load_dict(d)
			print("HUNT step goal=", T.cur().get("goal"), " saved walked=", d.walked, " after load walked=", T.walked, " progress=", T.progress())
			print("TEST duelA_tut_115 ", "FAIL(walked %s -> %s after load)" % [d.walked, T.walked] if T.walked < float(d.walked) else "OK")
		"duelA_fuse115_r9b_115":
			# Объединение двух ящиков по уровню / встроенный ящик убрали: износ инструментов и свежесть еды
			var f = game.factory
			game.ng_modules["survival"] = true
			game.ng_modules["combo"] = true
			game.flags["free_build"] = true
			var c: Vector2i = f.hq.cell + Vector2i(14, 8)
			var a = put_near(game, "chest", c, 0)
			var b = put(game, "chest", a.cell + Vector2i(1, 0), 0)
			for ch in [a, b]:
				for i in ch.inv.slots.size():
					ch.inv.slots[i] = null
			b.inv.slots[0] = {"id": "iron_pickaxe", "n": 1, "dur": 3.0}
			b.inv.slots[1] = {"id": "fried_meat", "n": 10, "fresh": 5.0}
			print("HUNT level why=", f.fz.level_why(a, b), " b before=", b.inv.slots.filter(func(s): return s != null))
			var ok = game.cmd("fuse", {"a": a, "b": b, "kind": "level"})
			print("HUNT fused=", ok, " lvl=", a.lvl, " a now=", a.inv.slots.filter(func(s): return s != null))
			var lvl_bug := false
			for s in a.inv.slots:
				if s != null and s.id == "iron_pickaxe" and not s.has("dur"):
					lvl_bug = true
			# составное: плавильня + ящик, ящик убирают кнопкой «Убрать»
			var sm = put_near(game, "smelter", c + Vector2i(0, 6), 0)
			var ch2 = put(game, "chest", sm.cell + Vector2i(2, 0), 0)
			print("HUNT combo why=", f.fz.combo_why(sm, ch2))
			f.fz.fuse_combo(sm, ch2)
			var sub = null
			for s in sm.subs:
				if s.type == "chest":
					sub = s
			var det_bug := false
			if sub != null:
				for i in sub.inv.slots.size():
					sub.inv.slots[i] = null
				sub.inv.slots[0] = {"id": "iron_pickaxe", "n": 1, "dur": 2.0}
				sub.inv.slots[1] = {"id": "fried_meat", "n": 10, "fresh": 4.0}
				var pl = game.player
				for i in pl.inv.slots.size():
					pl.inv.slots[i] = null
				game.cmd("detach", {"h": sm, "s": sub})
				var got: Array = pl.inv.slots.filter(func(s): return s != null)
				print("HUNT after detach hero got=", got)
				for s in got:
					if s.id == "iron_pickaxe" and not s.has("dur"):
						det_bug = true
			print("TEST duelA_fuse115 ", "FAIL(fuse/detach repairs worn tools and refreshes food: lvl=%s detach=%s)" % [lvl_bug, det_bug] if lvl_bug or det_bug else "OK")
		"duelA_sink115_r9_115":
			# Купоны утилизации: Магазин утилизации → Утилизатор → больше купонов, чем потрачено
			var f = game.factory
			game.flags["free_build"] = true
			var c: Vector2i = f.hq.cell + Vector2i(10, 10)
			var shop = put_near(game, "sink_shop", c, 0)
			var sk = put_near(game, "sink", c + Vector2i(3, 0), 0)
			var gen = put_near(game, "coal_generator", c + Vector2i(0, 4), 0)
			if gen and gen.fuel:
				gen.fuel.add("coal", 50)
			f.auto_wire_all()
			f.power_dirty = true
			var pl = game.player
			for i in pl.inv.slots.size():
				pl.inv.slots[i] = null
			pl.position = shop.center() + Vector3(1.5, 0, 0)
			pl.inv.add("sink_coupon", 2)
			print("HUNT start coupons=", pl.inv.count("sink_coupon"), " near=", game.near_stations())
			for cyc in 3:
				var nc: int = pl.inv.count("sink_coupon")
				game.cmd("craft", {"rid": "shop_ammo", "n": nc / 2, "station": "sink_shop"})
				for k in 300:
					game._update_craft(0.1)
					if game.craft_queue.is_empty():
						break
				var am: int = pl.inv.count("ammo")
				pl.inv.remove("ammo", am)
				var left := am
				for k in 4000:
					while left > 0 and f.accept(sk, "ammo", sk):
						left -= 1
					f._tick(0.04)
					if left == 0 and sk.inv.first_item() == "":
						break
				var got: int = sk.out.count("sink_coupon") if sk.out else 0
				sk.out.remove("sink_coupon", got)
				pl.inv.add("sink_coupon", got)
				print("HUNT cycle ", cyc, ": spent ", nc, " coupons -> ammo ", am, " -> sink gave ", got, " coupons (pts left ", snappedf(float(sk.bstate.get("b0", {}).get("pts", 0.0)) if sk.bstate.get("b0") is Dictionary else -1.0, 0.1), ")")
			var endc: int = pl.inv.count("sink_coupon")
			print("TEST duelA_sink115 ", "FAIL(coupon loop: 2 -> %d coupons)" % endc if endc > 2 else "OK")
		"duelA_alu115_r9_115":
			# Цена алюминиевого лома: 6 штук из 4 алунита + 2 угля (через раствор глинозёма)
			var buy_in: int = game.buy_price("alunite") * 4 + game.buy_price("coal") * 2
			var sell_out: int = game.sell_price("aluminum_scrap") * 6
			print("HUNT price scrap=", DB.item("aluminum_scrap").get("price"), " ingot=", DB.item("aluminum_ingot").get("price"), " (8 scrap -> 1 ingot)")
			print("HUNT buy 4 alunite + 2 coal = ", buy_in, " cr -> 6 scrap sell = ", sell_out, " cr; ingot from 24 scrap sells ", game.sell_price("aluminum_ingot") * 3)
			var f = game.factory
			game.flags["free_build"] = true
			var cp = put_near(game, "chem_plant", f.hq.cell + Vector2i(14, 0), 0)
			f.set_recipe(cp, "aluminum_scrap")
			cp.inv.add("alumina", 40)
			cp.inv.add("coal", 20)
			var gen = put_near(game, "coal_generator", f.hq.cell + Vector2i(14, 6), 0)
			gen.fuel.add("coal", 50)
			f.auto_wire_all()
			f.power_dirty = true
			for k in 1000:
				f._tick(0.04)
			print("HUNT chem plant 40 s: scrap=", cp.out.count("aluminum_scrap"), " (worth ", game.sell_price("aluminum_scrap") * cp.out.count("aluminum_scrap"), " cr)")
			var c0: int = game.credits
			game.player.inv.add("aluminum_scrap", 60)
			game.sell("aluminum_scrap", 60)
			var c1: int = game.credits
			game.player.inv.add("aluminum_ingot", 60)
			game.sell("aluminum_ingot", 60)
			print("HUNT econ_on=", Blocks.econ_on(), " real sale at station: 60 scrap -> ", c1 - c0, " cr; 60 aluminum ingots -> ", game.credits - c1, " cr; bm_value scrap=", snappedf(Blocks.bm_value(game, "aluminum_scrap"), 0.01), " ingot=", snappedf(Blocks.bm_value(game, "aluminum_ingot"), 0.01), " steel=", snappedf(Blocks.bm_value(game, "steel"), 0.01), " circuit=", snappedf(Blocks.bm_value(game, "circuit"), 0.01))
			print("TEST duelA_alu115 ", "FAIL(aluminum_scrap price 132: craft from 22 cr of ore sells for %d)" % sell_out if sell_out > buy_in * 5 else "OK")
		"duelA_fuse115_r9_115":
			var f = game.factory
			var w = game.world
			var fz = f.fz
			game.flags["free_build"] = true
			var c: Vector2i = f.hq.cell + Vector2i(12, 10)
			for dx in range(-3, 12):
				for dz in range(-3, 12):
					w.remove_node(World.wc(c + Vector2i(dx, dz)))
			var asm = put(game, "assembler", c, 0)
			var fu = put(game, "furnace", c + Vector2i(asm.size, 0), 0)
			print("HUNT sizes asm=", asm.size, " fu=", fu.size, " fuel_before=", fu.fuel != null)
			game.cmd("fuse", {"a": asm, "b": fu, "kind": "combo"})
			var s = null
			for x in asm.subs:
				if x.type == "furnace":
					s = x
			print("HUNT combo host=", asm.type, " subs=", asm.subs.map(func(q): return q.type), " sub_fuel_inv=", s != null and s.fuel != null)
			if s != null and s.fuel != null:
				s.fuel.add("coal", 7)
			var arr: Array = fz.save_subs(asm)
			print("HUNT saved=", JSON.stringify(arr))
			# simulate load
			var asm2 = put(game, "assembler", c + Vector2i(0, 5), 0)
			fz.load_subs(asm2, arr)
			var s2 = asm2.subs[0] if not asm2.subs.is_empty() else null
			print("HUNT loaded sub fuel_inv=", s2 != null and s2.fuel != null, " coal_after=", s2.fuel.count("coal") if s2 and s2.fuel else -1)
			# does the loaded furnace smelt without fuel?
			if s2 != null:
				s2.recipe = "smelt_iron"
				var rin: Dictionary = DB.data.recipes.get(s2.recipe, {}).get("in", {})
				for k in rin:
					s2.inv.add(k, int(rin[k]) * 3)
				f._rebuild_power()
				f._power(0.05)
				var made := 0
				for i in 400:
					fz.tick_subs(0.05)
				made = s2.out.count(DB.data.recipes.get(s2.recipe, {}).get("out", {}).keys()[0]) if s2.recipe != "" else -1
				print("HUNT loaded furnace sub recipe=", s2.recipe, " made_without_fuel=", made, " fuel_t=", s2.fuel_t)
				# compare: original sub (has fuel inv) with no fuel
				s.fuel.slots.fill(null)
				s.fuel_t = 0.0
				s.recipe = s2.recipe
				for k in rin:
					s.inv.add(k, int(rin[k]) * 3)
				for i in 400:
					fz.tick_subs(0.05)
				print("HUNT original furnace sub made_without_fuel=", s.out.count(DB.data.recipes.get(s.recipe, {}).get("out", {}).keys()[0]))
			# level fusion loses in-progress crafting
			var c3: Vector2i = c + Vector2i(0, 9)
			var a1 = put(game, "smelter", c3, 0)
			var a2 = put(game, "smelter", c3 + Vector2i(a1.size, 0), 0)
			var rid := "smelt_iron"
			var rin2: Dictionary = DB.data.recipes[rid].get("in", {})
			var ore: String = rin2.keys()[0]
			a2.inv.add(ore, int(rin2[ore]))
			a2.recipe = rid
			f._crafter(a2, 0.01)
			var p_before: int = game.player.inv.count(ore)
			var tot_before: int = p_before + a1.inv.count(ore) + a2.inv.count(ore) + (int(rin2[ore]) if a2.crafting != "" else 0)
			fz.fuse_level(a1, a2)
			var tot_after: int = game.player.inv.count(ore) + a1.inv.count(ore) + (int(rin2[ore]) if a1.crafting != "" else 0)
			print("HUNT fuse_level crafting=", a2.crafting, " ore_total before=", tot_before, " after=", tot_after, " lvl=", a1.lvl)
			game.flags.erase("free_build")
			print("TEST duelA_fuse115 done")
		"duelA_belt115_r9_115":
			# Ящик → лента → ящик: изношенная кирка и почти сгнившая еда едут по ленте
			var f = game.factory
			game.ng_modules["survival"] = true
			game.flags["free_build"] = true
			var c: Vector2i = f.hq.cell + Vector2i(16, -10)
			var a = put_near(game, "chest", c, 0)
			var bl = put(game, "belt", a.cell + Vector2i(1, 0), 0)
			var bl2 = put(game, "belt", a.cell + Vector2i(2, 0), 0)
			var b = put(game, "chest", a.cell + Vector2i(3, 0), 0)
			print("HUNT placed a=", a != null, " belt=", bl != null, " b=", b != null, " a.next=", a.next.type if a.next else "-")
			for ch in [a, b]:
				for i in ch.inv.slots.size():
					ch.inv.slots[i] = null
			a.inv.slots[0] = {"id": "iron_pickaxe", "n": 1, "dur": 3.0}
			a.inv.slots[1] = {"id": "fried_meat", "n": 5, "fresh": 5.0}
			for k in 400:
				f._tick(0.04)
			print("HUNT a=", a.inv.slots.filter(func(s): return s != null), " b=", b.inv.slots.filter(func(s): return s != null), " maxdur=", DB.item("iron_pickaxe").get("durability"))
			var bug := false
			for s in b.inv.slots:
				if s != null and s.id == "iron_pickaxe" and not s.has("dur"):
					bug = true
			print("TEST duelA_belt115 ", "FAIL(belt transport repairs worn tool / refreshes food)" if bug else "OK")
		"duelA_tur115_r9_115":
			# Турель «Объединение 3» против трёх отдельных турелей: урон и расход патронов за 10 с
			var f = game.factory
			game.flags["free_build"] = true
			game.flags["no_waves"] = true
			var out := {}
			for mode in ["two", "fused"]:
				var c: Vector2i = f.hq.cell + (Vector2i(40, 0) if mode == "two" else Vector2i(-40, 0))
				var ts := []
				ts.append(put_near(game, "turret", c, 0))
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
					var t2 = put(game, "turret", ts[0].cell + d, 0)
					if t2 != null:
						ts.append(t2)
						break
				c = ts[0].cell
				var pole = put_near(game, "pole", c + Vector2i(0, 2), 0)
				var gen = put_near(game, "coal_generator", c + Vector2i(0, 4), 0)
				gen.fuel.add("coal", 50)
				if mode == "fused":
					f.fz.fuse_level(ts[0], ts[1])
					ts = [ts[0]]
				f.auto_wire_all()
				f.power_dirty = true
				for k in 5:
					f._tick(0.04)
				print("HUNT sat=", f.sat_c(ts[0]), " pole=", pole != null)
				for t in ts:
					if t.inv:
						t.inv.add("ammo", 200)
				var pos: Vector3 = World.cell_to_world(c) + Vector3(0, 0, 12)
				var e = game.enemies.spawn("brute", pos)
				e.hp = 1e6
				e.maxhp = 1e6
				e.speed = 0.0 if "speed" in e else 0.0
				var a0 := 0
				for t in ts:
					a0 += t.inv.count("ammo")
				for k in 250:
					e.pos = pos
					e.hp = maxf(e.hp, 1000.0) if false else e.hp
					f._tick(0.04)
				var a1 := 0
				for t in ts:
					a1 += t.inv.count("ammo")
				out[mode] = [ts.size(), ts[0].lvl, a0 - a1, snappedf(1e6 - e.hp, 1)]
				print("HUNT ", mode, ": turrets=", ts.size(), " lvl=", ts[0].lvl, " ammo used=", a0 - a1, " damage dealt=", snappedf(1e6 - e.hp, 1))
				game.enemies.list.erase(e)
			var dmg_per_ammo_3: float = out.two[3] / maxf(1, out.two[2])
			var dmg_per_ammo_f: float = out.fused[3] / maxf(1, out.fused[2])
			print("TEST duelA_tur115 ", "FAIL(fused turret: %.1f dmg/ammo vs %.1f for separate)" % [dmg_per_ammo_f, dmg_per_ammo_3] if dmg_per_ammo_f > dmg_per_ammo_3 * 1.5 else "OK")
		"duelA_cq115_r9_115":
			# Сплитскрин: второй игрок поставил крафт в очередь, мир сохранён и загружен — кому достанется изделие?
			Pad.fake_pads = [0, 1]
			var sp = game.split
			var press := func(down: bool):
				var e := InputEventJoypadButton.new()
				e.device = 1
				e.button_index = JOY_BUTTON_START
				e.pressed = down
				Input.parse_input_event(e)
			press.call(true)
			await tree.process_frame
			await tree.process_frame
			press.call(false)
			await tree.process_frame
			var p1 = sp.p1()
			var p2 = sp.p2()
			for pl in [p1, p2]:
				for i in pl.inv.slots.size():
					pl.inv.slots[i] = null
			p2.inv.add("log", 10)
			sp.with_seat(1, func(): return game.cmd("craft", {"rid": "plank", "n": 3, "station": "hand"}))
			print("HUNT queue=", game.craft_queue, " p2 logs left=", p2.inv.count("log"))
			var sd: Dictionary = JSON.parse_string(JSON.stringify(game.save_dict()))
			game.craft_queue.clear()
			game.load_game(sd)
			print("HUNT after load queue=", game.craft_queue, " split active=", sp.active)
			for k in 200:
				game._update_craft(0.1)
				if game.craft_queue.is_empty():
					break
			print("HUNT planks: p1=", p1.inv.count("plank"), " p2=", p2.inv.count("plank"), " p2 logs=", p2.inv.count("log"))
			print("TEST duelA_cq115 ", "FAIL(P2 queued craft goes to P1 after save/load: seat not saved)" if p1.inv.count("plank") > 0 and p2.inv.count("plank") == 0 else "OK")
		"duelA_subcraft115_r9_115":
			# Встроенная плавильня посреди плавки: «Убрать» её из составного / снести составное — что с сырьём?
			var f = game.factory
			game.ng_modules["combo"] = true
			game.flags["free_build"] = true
			var res := []
			for mode in ["detach", "demolish"]:
				var c: Vector2i = f.hq.cell + Vector2i(18, -14 if mode == "detach" else 14)
				var h = put_near(game, "assembler", c, 0)
				var s0 = put(game, "smelter", h.cell + Vector2i(2, 0), 0)
				var why: String = f.fz.combo_why(h, s0)
				f.fz.fuse_combo(h, s0)
				var sub = null
				for s in h.subs:
					if s.type == "smelter":
						sub = s
				if sub == null:
					print("HUNT no sub: ", why)
					continue
				var rid := ""
				for r in DB.recipes_for(sub.p("station", "smelter")):
					if DB.data.recipes[r].get("in", {}).has("iron_ore"):
						rid = r
						break
				sub.crafting = rid
				sub.prog = 0.5
				var pl = game.player
				for i in pl.inv.slots.size():
					pl.inv.slots[i] = null
				pl.position = h.center() + Vector3(3, 0, 0)
				if mode == "detach":
					game.cmd("detach", {"h": h, "s": sub})
				else:
					game.cmd("demolish", {"cell": h.cell})
				await tree.process_frame
				var ore: int = pl.inv.count("iron_ore") + (f.hq.inv.count("iron_ore") if false else 0)
				print("HUNT ", mode, ": sub was crafting ", rid, " (in ", DB.data.recipes.get(rid, {}).get("in"), ") -> hero iron_ore=", ore, " hero inv=", pl.inv.slots.filter(func(x): return x != null))
				res.append(ore)
			print("TEST duelA_subcraft115 ", "FAIL(in-progress craft of embedded machine lost on detach/demolish: %s)" % str(res) if res.has(0) else "OK")
		"duelA_fresh115_r8_115":
			# Свежесть еды при объединении стопок в рюкзаке
			game.ng_modules["survival"] = true
			var pl = game.player
			var inv: Inventory = pl.inv
			for i in inv.slots.size():
				inv.slots[i] = null
			var sp := float(DB.item("fried_meat").get("spoil", 0))
			# а) почти сгнившая стопка перетаскивается на свежую (как в окне рюкзака, hud.gd:1447)
			inv.slots[10] = {"id": "fried_meat", "n": 5, "fresh": 3.0}
			inv.slots[11] = {"id": "fried_meat", "n": 5, "fresh": sp}
			Inventory.move_between(inv, 10, inv, 11)
			print("HUNT a) old(fresh 3 s) dragged onto new(fresh ", sp, " s): slot11=", inv.slots[11], " slot10=", inv.slots[10])
			# б) только что приготовленное мясо (inv.add, как готовый ручной крафт main.gd:3487 или подбор) — в старую стопку
			var a_fresh := float(inv.slots[11].get("fresh", 0))
			inv.slots[11] = null
			inv.slots[12] = {"id": "fried_meat", "n": 2, "fresh": 3.0}
			inv.add("fried_meat", 8)
			print("HUNT b) +8 fresh-cooked meat via inv.add next to old stack(fresh 3 s): slot12=", inv.slots[12])
			for k in 5:
				game._spoil_acc = 0.0
				game._update_survival(1.0)
			var rot := inv.count("rotten")
			print("HUNT after 5 s: fried_meat=", inv.count("fried_meat"), " rotten=", rot, " slot11=", inv.slots[11], " slot12=", inv.slots[12])
			print("TEST duelA_fresh115 ", "FAIL(stack merge takes dst freshness: rotten food revived, fresh food rots with old)" if rot >= 10 and a_fresh > 100.0 else "OK")
		"duelA_p2bag115_r8_115":
			# Сплитскрин: второй расширил рюкзак, вышел (Пауза → Убрать второго игрока) и снова вошёл
			Pad.fake_pads = [0, 1]
			var sp = game.split
			var press := func(down: bool):
				var e := InputEventJoypadButton.new()
				e.device = 1
				e.button_index = JOY_BUTTON_START
				e.pressed = down
				Input.parse_input_event(e)
			press.call(true)
			await tree.process_frame
			await tree.process_frame
			press.call(false)
			await tree.process_frame
			var p2 = sp.p2()
			var hq = game.factory.hq
			var st0 := Player.bag_next(p2.bag_level)
			for it in st0.get("cost", {}):
				hq.inv.add(it, int(st0.cost[it]))
			sp.with_seat(1, func(): return game.cmd("bag_up", {}))
			p2.hp = 20.0
			p2.food = 5.0
			p2.water = 5.0
			print("HUNT p2 bag level=", p2.bag_level, " size=", p2.inv.size(), " paid=", st0.get("cost"), " hp=", p2.hp, " food=", p2.food)
			sp.stop()
			await tree.process_frame
			await tree.process_frame
			print("HUNT after leave: split2 save=", JSON.stringify(game.save_dict().get("split2", {})).substr(0, 120))
			press.call(true)
			await tree.process_frame
			await tree.process_frame
			press.call(false)
			await tree.process_frame
			var q = sp.p2()
			print("HUNT P2 rejoined: active=", sp.active, " bag level=", q.bag_level if q else -1, " size=", q.inv.size() if q else -1, " hp=", q.hp if q else -1, " food=", q.food if q else -1, " water=", q.water if q else -1)
			print("TEST duelA_p2bag115 ", "FAIL(P2 bag level lost on leave; hp/food refilled)" if q != null and q.bag_level == 0 else "OK")
		"duelA_deadsave115_r8_115":
			# Сохранение, пока герой мёртв (ждёт восстановления у штаба), → загрузка
			var pl = game.player
			var hq = game.factory.hq
			pl.position = hq.center() + Vector3(120, 0, 80)
			pl.inv.add("iron_ingot", 30)
			await tree.process_frame
			pl.damage(99999.0)
			print("HUNT died: alive=", pl.alive, " hp=", pl.hp, " graves=", game.graves.size(), " dist to hq=", snappedf(World.dist(pl.position, hq.center()), 0.1))
			var sd: Dictionary = game.save_dict()
			print("HUNT saved player=", JSON.stringify(sd.player).substr(0, 90))
			# как новая сцена: герой жив у штаба, сундуков нет
			for g in game.graves.duplicate():
				game._remove_grave(g)
			pl.alive = true
			pl.hp = pl.maxhp
			pl.position = hq.center() + Vector3(5, 0, 5)
			game.load_game(sd)
			for k in 30:
				await tree.process_frame
			print("HUNT after load: alive=", pl.alive, " hp=", pl.hp, " dist to hq=", snappedf(World.dist(pl.position, hq.center()), 0.1), " graves=", game.graves.size(), " iron in inv=", pl.inv.count("iron_ingot"))
			print("TEST duelA_deadsave115 ", "FAIL(dead hero loads alive with hp 0 at death spot, grabs grave instantly)" if pl.alive and pl.hp < 5.0 and World.dist(pl.position, hq.center()) > 50.0 else "OK")
		"duelA_hubacc115_r8_115":
			# Узел дронов: маршрут «ящик → турель/плавильня» везёт то, что здание не принимает
			var f = game.factory
			game.flags["free_build"] = true
			var c: Vector2i = f.hq.cell + Vector2i(22, -16)
			var hub = put_near(game, "drone_hub", c, 0)
			var a = put_near(game, "chest", c + Vector2i(6, 0), 0)
			var tu = put_near(game, "turret", c + Vector2i(-6, 0), 0)
			var sm = put_near(game, "smelter", c + Vector2i(0, 7), 0)
			a.cfg["tag"] = "A"
			for i in a.inv.slots.size():
				a.inv.slots[i] = null
			a.inv.add("iron_ore", 200)
			a.inv.add("log", 100)
			var bl: Dictionary = {}
			for ob in Blocks.of("drone_hub"):
				if str(ob.get("type", "")) == "route":
					bl = ob
			print("HUNT accept(turret, iron_ore)=", f.accept(tu, "iron_ore", null) if false else "n/a", " turret mag allow iron_ore=", tu.inv.allow.call("iron_ore"), " slots=", tu.inv.slots.size())
			var steps := [{"item": "iron_ore", "n": 50, "from_tag": "A", "to_tag": "turret", "keep": 0}, {"item": "log", "n": 50, "from_tag": "A", "to_tag": "smelter", "keep": 0}]
			for stp in steps:
				for trip in 3:
					game.carriers.route_step(hub, bl, stp)
					for k in 400:
						game.carriers.update(0.05)
						if game.carriers.flights.is_empty():
							break
			print("HUNT turret magazine=", tu.inv.slots, " can take ammo now=", tu.inv.can_add("ammo", 1))
			print("HUNT smelter input=", sm.inv.slots.filter(func(s): return s != null), " recipe=", sm.recipe)
			var dr: int = game.drops.list.filter(func(d): return d.id in ["iron_ore", "log"]).size()
			print("HUNT drops on ground=", dr)
			print("TEST duelA_hubacc115 ", "FAIL(hub route ignores accept/allow: junk in turret magazine)" if tu.inv.count("iron_ore") > 0 else "OK")
		"duelA_demol115_r8_115":
			# Снос ящика с изношенной киркой и подпорченной едой: что вернётся герою?
			var f = game.factory
			game.flags["free_build"] = true
			var ch = put_near(game, "chest", f.hq.cell + Vector2i(12, 6), 0)
			game.flags["free_build"] = false
			for i in ch.inv.slots.size():
				ch.inv.slots[i] = null
			ch.inv.slots[0] = {"id": "iron_pickaxe", "n": 1, "dur": 3.0}
			ch.inv.slots[1] = {"id": "fried_meat", "n": 10, "fresh": 5.0}
			var pl = game.player
			for i in pl.inv.slots.size():
				pl.inv.slots[i] = null
			pl.position = ch.center() + Vector3(3, 0, 0)
			print("HUNT chest before demolish: ", ch.inv.slots.filter(func(s): return s != null), " maxdur=", DB.item("iron_pickaxe").get("durability"))
			game.cmd("demolish", {"cell": ch.cell})
			await tree.process_frame
			var got: Array = pl.inv.slots.filter(func(s): return s != null and s.id in ["iron_pickaxe", "fried_meat"])
			print("HUNT hero after demolish: ", got)
			var fixed := false
			for s in got:
				if s.id == "iron_pickaxe" and not s.has("dur"):
					fixed = true
			print("TEST duelA_demol115 ", "FAIL(demolish returns worn tool as new / food fresh)" if fixed else "OK")
		"duelB_disk115_r7_115":
			# B7: запись мира при нехватке места (ulimit -f): портится ли прежний файл?
			var pth := DB.saves_dir().path_join("duelb7.json")
			var mode := "first" if not FileAccess.file_exists(pth) else "second"
			if mode == "second":
				var d0 = DB.read_file(pth)
				print("HUNT before: size=", FileAccess.get_file_as_bytes(pth).size(), " valid=", d0 is Dictionary)
			game.play_time = 777.0 if mode == "first" else 999.0
			game.save_game("duelb7", true)
			var d1 = DB.read_file(pth)
			print("HUNT ", mode, ": size=", FileAccess.get_file_as_bytes(pth).size(), " valid=", d1 is Dictionary, " tmp left=", FileAccess.file_exists(pth + ".tmp"))
			if mode == "second" or OS.get_cmdline_user_args().has("--duelB_clean"):
				DirAccess.remove_absolute(pth)
				DirAccess.remove_absolute(DB.saves_dir().path_join("duelb7.meta.json"))
				DirAccess.remove_absolute(pth + ".tmp")
			print("TEST duelB_disk115 done")
		"duelA_spoil115_r7_115":
			# Сплитскрин: еда в рюкзаках двух героев — портится одинаково?
			Pad.fake_pads = [0, 1]
			var sp = game.split
			var e1 := InputEventJoypadButton.new()
			e1.device = 1
			e1.button_index = JOY_BUTTON_START
			e1.pressed = true
			Input.parse_input_event(e1)
			await tree.process_frame
			await tree.process_frame
			var e2 := InputEventJoypadButton.new()
			e2.device = 1
			e2.button_index = JOY_BUTTON_START
			e2.pressed = false
			Input.parse_input_event(e2)
			await tree.process_frame
			var p1 = sp.p1()
			var p2 = sp.p2()
			p1.inv.slots[20] = {"id": "fried_meat", "n": 5, "fresh": 300.0}
			p2.inv.slots[20] = {"id": "fried_meat", "n": 5, "fresh": 300.0}
			game.ng_modules["survival"] = true
			print("HUNT split=", sp.active, " survival=", game.module("survival"))
			# так же, как главный цикл main._process: за кадр _update_survival у каждого места (1/60 с)
			for fr in 600:
				for si in 2:
					sp.use(si)
					game._update_survival(1.0 / 60.0)
				sp.use(0)
			print("HUNT after 10 s (600 frames @60fps): p1 meat=", p1.inv.slots[20], " p2 meat=", p2.inv.slots[20])
			var t0 := Time.get_ticks_msec()
			for k in 240:
				await tree.process_frame
			print("HUNT after ", (Time.get_ticks_msec() - t0) / 1000.0, " s real frames: p1 meat=", p1.inv.slots[20], " p2 meat=", p2.inv.slots[20])
			print("TEST duelA_spoil115 done")
		"duelA_mod2_115_r7_115":
			# A-4 r6 в реальной игре: оба мода из конструктора («Мой мод», автор — пустой, как пишет ModKit.ensure)
			var tmp := ProjectSettings.globalize_path("user://duelA_mods")
			DirAccess.make_dir_recursive_absolute(tmp)
			var my: String = ModKit.ensure("Мой мод")   # mod_ctor.gd:97 — так создаёт конструктор
			ModKit.put(my, "items", "duela_my_sword", {"name": "Мой меч"})
			print("HUNT my mod: id=", my, " info=", ModKit.info(my), " items=", ModKit._file(my, "items").keys())
			# друг: тот же конструктор у себя → «Поделиться файлом» (ModKit.pack) — архив с такими же mod.json
			var pc: String = tmp.path_join("friend.fcmod")
			var z := ZIPPacker.new()
			z.open(pc)
			z.start_file(my + "/mod.json")
			z.write_file(JSON.stringify({"name": "Мой мод", "version": "1.0", "author": "", "desc": "Сделано в конструкторе игры"}).to_utf8_buffer())
			z.start_file(my + "/items.json")
			z.write_file(JSON.stringify({"duela_friend_hat": {"name": "Шляпа друга"}}).to_utf8_buffer())
			z.close()
			var rc: Dictionary = ModKit.install(pc)
			print("HUNT friend install: ok=", rc.get("ok"), " id=", rc.get("id"), " msg=", rc.get("msg"), " | my items now=", ModKit._file(my, "items").keys())
			print("TEST duelA_mod2_115 ", "FAIL(friend's mod overwrote mine)" if not ModKit._file(my, "items").has("duela_my_sword") else "OK")
			DirAccess.remove_absolute(pc)
			DirAccess.remove_absolute(tmp)
		"duelA_car2_115_r7_115":
			# Ровер после сохранения/загрузки: водитель не сохраняется (vehicles.to_dict) — второй игрок присоединился
			var f = game.factory
			game.flags["free_build"] = true
			var rv = put_near(game, "rover", f.hq.cell + Vector2i(14, 14), 0)
			game.player.position = rv.center()
			game.vehicles.enter(rv)
			var d: Dictionary = game.save_dict()
			print("HUNT saved vehicle=", d.get("vehicle"))
			# загрузка: свежий объект машин, как в новой игре → load_game: vehicles.load_dict(data.vehicle)
			if game.vehicles.node:
				game.vehicles.node.queue_free()
			game.vehicles = preload("res://scripts/vehicles.gd").new(game)
			game.vehicles.load_dict(d.vehicle)
			await tree.process_frame
			# второй игрок нажал Start
			Pad.fake_pads = [0, 1]
			var sp = game.split
			var e1 := InputEventJoypadButton.new()
			e1.device = 1
			e1.button_index = JOY_BUTTON_START
			e1.pressed = true
			Input.parse_input_event(e1)
			await tree.process_frame
			await tree.process_frame
			var e2 := InputEventJoypadButton.new()
			e2.device = 1
			e2.button_index = JOY_BUTTON_START
			e2.pressed = false
			Input.parse_input_event(e2)
			await tree.process_frame
			var p1 = sp.p1()
			var p2 = sp.p2()
			p2.position = p1.position + Vector3(70, 0, 0)
			for k in 5:
				await tree.process_frame
			print("HUNT after load + P2 joined: split=", sp.active, " driving=", game.vehicles.driving, " driver=", game.vehicles.driver, " speed_mult p1=", game.vehicles.speed_mult(p1), " p2=", game.vehicles.speed_mult(p2), " p1 hips vis=", p1.hips.visible)
			print("HUNT rover node->p1=", snappedf(World.dist(game.vehicles.node.position, p1.position), 0.1), " ->p2=", snappedf(World.dist(game.vehicles.node.position, p2.position), 0.1))
			sp.with_seat(1, func(): game._interact())   # второй нажал E в 70 м от ровера
			await tree.process_frame
			var rb = null
			for bb in f.all:
				if bb.type == "rover":
					rb = bb
			print("HUNT after P2 presses E: driving='", game.vehicles.driving, "' parked near p1=", (snappedf(World.dist(rb.center(), p1.position), 0.1) if rb else -1), " near p2=", (snappedf(World.dist(rb.center(), p2.position), 0.1) if rb else -1), " p1 hips vis=", p1.hips.visible)
			print("TEST duelA_car2_115 ", "FAIL(P2 exits P1's rover after load; P1 stays invisible)" if rb != null and not p1.hips.visible else "OK")
		"duelA_p2mon115_r7_115":
			# Сплитскрин: монстр рядом со ВТОРЫМ героем (первый у штаба) — нападает ли?
			Pad.fake_pads = [0, 1]
			var sp = game.split
			var e1 := InputEventJoypadButton.new()
			e1.device = 1
			e1.button_index = JOY_BUTTON_START
			e1.pressed = true
			Input.parse_input_event(e1)
			await tree.process_frame
			await tree.process_frame
			var e2 := InputEventJoypadButton.new()
			e2.device = 1
			e2.button_index = JOY_BUTTON_START
			e2.pressed = false
			Input.parse_input_event(e2)
			await tree.process_frame
			var p1 = sp.p1()
			var p2 = sp.p2()
			var hq: Vector3 = game.factory.hq.center()
			p1.position = hq + Vector3(6, 0, 6)
			p2.position = hq + Vector3(90, 0, 0)
			var res := {}
			for who in [["p2", p2], ["p1", p1]]:
				var pl = who[1]
				var hp0: float = pl.hp
				var m = game.enemies.spawn("crawler", pl.position + Vector3(3, 0, 0))
				for k in 240:
					p1.position = hq + Vector3(6, 0, 6) if who[0] == "p2" else p1.position
					p2.position = hq + Vector3(90, 0, 0)
					await tree.process_frame
				res[who[0]] = [hp0, pl.hp, (("p1" if m.target == p1 else ("p2" if m.target == p2 else str(m.target))) if m.alive else "dead")]
				if m.alive:
					game.enemies.hit(m, 999999.0)
				pl.hp = pl.maxhp
				if who[0] == "p2":
					p1.position = hq + Vector3(-90, 0, 0)
					p2.position = hq + Vector3(6, 0, 6)
					await tree.process_frame
			print("HUNT crawler 3 m from p2 for 240 frames: p2 hp ", res.p2[0], "->", res.p2[1], " target=", res.p2[2])
			print("HUNT crawler 3 m from p1 for 240 frames: p1 hp ", res.p1[0], "->", res.p1[1], " target=", res.p1[2])
			print("TEST duelA_p2mon115 ", "FAIL(monsters ignore P2)" if res.p2[1] >= res.p2[0] and res.p1[1] < res.p1[0] else "OK")
		"duelA_p2grave115_r7_115":
			# Сплитскрин: второй погиб — может ли он сам забрать свой сундук?
			Pad.fake_pads = [0, 1]
			var sp = game.split
			var e1 := InputEventJoypadButton.new()
			e1.device = 1
			e1.button_index = JOY_BUTTON_START
			e1.pressed = true
			Input.parse_input_event(e1)
			await tree.process_frame
			await tree.process_frame
			var e2 := InputEventJoypadButton.new()
			e2.device = 1
			e2.button_index = JOY_BUTTON_START
			e2.pressed = false
			Input.parse_input_event(e2)
			await tree.process_frame
			var p1 = sp.p1()
			var p2 = sp.p2()
			var hq: Vector3 = game.factory.hq.center()
			p1.position = hq + Vector3(-40, 0, 0)
			p2.position = hq + Vector3(30, 0, 10)
			for i in p2.inv.slots.size():
				p2.inv.slots[i] = null
			p2.inv.slots[3] = {"id": "iron_pickaxe", "n": 1, "dur": 40.0}
			p2.inv.slots[4] = {"id": "copper", "n": 25}
			# смерть второго (как player.damage → on_player_died за его место)
			sp.with_seat(1, func(): game.on_player_died())
			print("HUNT p2 died: graves=", game.graves.size(), " grave at p2=", (snappedf(World.dist(game.graves[0].pos, p2.position), 0.1) if not game.graves.is_empty() else -1.0), " p2 inv empty=", p2.inv.is_empty())
			for k in 120:
				p2.position = game.graves[0].pos if not game.graves.is_empty() else p2.position
				p1.position = hq + Vector3(-40, 0, 0)
				await tree.process_frame
			print("HUNT p2 stood on own grave 2 s: graves=", game.graves.size(), " p2 inv=", p2.inv.slots.filter(func(x): return x != null))
			var gpos: Vector3 = game.graves[0].pos if not game.graves.is_empty() else Vector3.ZERO
			p2.position = hq + Vector3(30, 0, 40)
			p1.position = gpos
			for k in 10:
				await tree.process_frame
			print("HUNT p1 walks onto it: graves=", game.graves.size(), " p1 has pickaxe=", p1.inv.count("iron_pickaxe"), " p1 copper=", p1.inv.count("copper"))
			print("TEST duelA_p2grave115 done")
		"duelA_dung115_r7_115":
			# Подземелье: стража и босс перебиты → сохранение/загрузка → снова подошли
			DB.data.settings["dungeons"]["enabled"] = true
			game.dungeons.list.clear()
			game.dungeons.generate()
			print("HUNT dungeons=", game.dungeons.list.size())
			if not game.dungeons.list.is_empty():
				var d0: Dictionary = game.dungeons.list[0]
				var wp: Vector3 = World.cell_to_world(d0.cell)
				var count_g := func() -> int:
					var n := 0
					for e in game.enemies.list:
						if e.alive and e.guard and World.dist(e.pos, wp) < 20.0:
							n += 1
					return n
				game.player.position = wp + Vector3(30, 0, 0)
				game.dungeons.update(0.1)
				var n1: int = count_g.call()
				var cr0: int = game.credits
				for e in game.enemies.list.duplicate():
					if e.alive and World.dist(e.pos, wp) < 20.0:
						game.enemies.hit(e, 999999.0, true)
				await tree.process_frame
				print("HUNT first visit: guards+boss spawned=", n1, " killed all, credits +", game.credits - cr0, " alive now=", count_g.call(), " chest left=", d0.chest.inv.first_item() if d0.chest else "-")
				game.player.position = World.cell_to_world(game.factory.hq.cell)
				var sd: Dictionary = game.save_dict()
				# загрузка: main.load_game → dungeons.from_dict(data.dungeons)
				game.dungeons.from_dict(JSON.parse_string(JSON.stringify(sd.dungeons)))
				game.player.position = wp + Vector3(30, 0, 0)
				game.dungeons.update(0.1)
				var cr1: int = game.credits
				var n2: int = count_g.call()
				for e in game.enemies.list.duplicate():
					if e.alive and World.dist(e.pos, wp) < 20.0:
						game.enemies.hit(e, 999999.0, true)
				await tree.process_frame
				print("HUNT after save/load, approach again: guards+boss spawned=", n2, " killed again, credits +", game.credits - cr1)
				print("TEST duelA_dung115 ", "FAIL(dungeon guards & boss respawn after every load)" if n2 > 0 else "OK")
			DB.data.settings["dungeons"]["enabled"] = false
		"duelA_p2cloth115_r7_115":
			# Сплитскрин: второй надел куртку и расширил рюкзак → вышел (Back) / сохранение
			Pad.fake_pads = [0, 1]
			var sp = game.split
			var e1 := InputEventJoypadButton.new()
			e1.device = 1
			e1.button_index = JOY_BUTTON_START
			e1.pressed = true
			Input.parse_input_event(e1)
			await tree.process_frame
			await tree.process_frame
			var e2 := InputEventJoypadButton.new()
			e2.device = 1
			e2.button_index = JOY_BUTTON_START
			e2.pressed = false
			Input.parse_input_event(e2)
			await tree.process_frame
			var p2 = sp.p2()
			p2.inv.add("fur_coat", 1)
			var ok_on: bool = sp.with_seat(1, func(): return game.climate.put_on("fur_coat"))
			var st0 := Player.bag_next(p2.bag_level)
			var hq = game.factory.hq
			for it in st0.get("cost", {}):
				hq.inv.add(it, int(st0.cost[it]))
			var size0: int = p2.inv.size()
			sp.with_seat(1, func(): return game.cmd("bag_up", {}))
			print("HUNT p2 wears=", p2.clothes, " (put_on ", ok_on, ") bag ", size0, "->", p2.inv.size(), " level=", p2.bag_level, " cost=", st0.get("cost"))
			var s2: Dictionary = sp.save_state()
			print("HUNT save_state (saved for P2)=", JSON.stringify(s2).substr(0, 200), " has clothes=", JSON.stringify(s2).contains("fur_coat"), " has bag=", s2.has("bag"))
			var coats0: int = hq.inv.count("fur_coat")
			sp.stop()
			await tree.process_frame
			print("HUNT after P2 left: fur_coat in hq ", coats0, "->", hq.inv.count("fur_coat"), " in p1 inv=", game.player.inv.count("fur_coat"), " drops=", game.drops.list.filter(func(d): return d.id == "fur_coat").size())
			print("TEST duelA_p2cloth115 ", "FAIL(P2 clothes lost)" if hq.inv.count("fur_coat") == coats0 and game.player.inv.count("fur_coat") == 0 else "OK")
		"duelA_drsave115_r7_115":
			# Дрон с изношенной киркой в пути → сохранение/загрузка → долетает какой?
			var f = game.factory
			game.flags["free_build"] = true
			var c: Vector2i = f.hq.cell + Vector2i(22, -16)
			var stn = put_near(game, "drone_station", c, 0)
			var a = put_near(game, "chest", c + Vector2i(6, 0), 0)
			var z = put_near(game, "chest", c + Vector2i(-6, 0), 0)
			var g = put_near(game, "generator", c + Vector2i(0, 6), 0)
			g.fuel.add("coal", 50)
			f.add_wire(g, stn)
			f._rebuild_power()
			for i in a.inv.slots.size():
				a.inv.slots[i] = null
			a.inv.slots[0] = {"id": "iron_pickaxe", "n": 1, "dur": 3.0}
			game.drones.set_routes(stn, [{"from": [a.cell.x, a.cell.y], "to": [z.cell.x, z.cell.y], "item": "", "keep": 0, "on": true}])
			var carrying = null
			for k in 2400:
				f._power(0.05)
				game.drones.update(0.05)
				for d in game.drones.drones_of(stn):
					if int(d.n) > 0:
						carrying = d
				if carrying != null:
					break
			print("HUNT in flight: item=", carrying.item if carrying else "-", " sl=", carrying.get("sl") if carrying else "-")
			var sd: Dictionary = game.save_dict()
			game.drones.load_list(JSON.parse_string(JSON.stringify(sd.drones)))
			for d in game.drones.drones_of(stn):
				if int(d.n) > 0:
					print("HUNT after load: item=", d.item, " n=", d.n, " sl=", d.get("sl"))
			for k in 2400:
				f._power(0.05)
				game.drones.update(0.05)
				if z.inv.count("iron_pickaxe") > 0:
					break
			print("HUNT B=", z.inv.slots.filter(func(s): return s != null))
			var bad := false
			for s in z.inv.slots:
				if s != null and s.id == "iron_pickaxe" and not s.has("dur"):
					bad = true
			print("TEST duelA_drsave115 ", "FAIL(worn pickaxe repaired by save/load in flight)" if bad else "OK")
		"duelA_p2photo_r6", "duelA_p2photo115":
			# Сплитскрин: первый включает свободную камеру — что с камерой второго?
			Pad.fake_pads = [0, 1]
			var sp = game.split
			var e1 := InputEventJoypadButton.new()
			e1.device = 1
			e1.button_index = JOY_BUTTON_START
			e1.pressed = true
			Input.parse_input_event(e1)
			await tree.process_frame
			await tree.process_frame
			var e2 := InputEventJoypadButton.new()
			e2.device = 1
			e2.button_index = JOY_BUTTON_START
			e2.pressed = false
			Input.parse_input_event(e2)
			await tree.process_frame
			var p1 = sp.p1()
			var p2 = sp.p2()
			p2.position = p1.position + Vector3(60, 0, 0)
			for k in 30:
				await tree.process_frame
			var cam2 = sp.with_seat(1, func(): return game.camera)
			var cam1 = sp.with_seat(0, func(): return game.camera)
			print("HUNT before: cam1->p1=", snappedf(World.dist(cam1.global_position, p1.position), 0.1), " cam2->p2=", snappedf(World.dist(cam2.global_position, p2.position), 0.1), " same cam=", cam1 == cam2)
			game.free_camera()
			game.photo.pos = p1.position + Vector3(-40, 20, 0)
			for k in 30:
				await tree.process_frame
			print("HUNT free cam: photo_mode=", game.photo_mode, " cam1 pos=", cam1.global_position.snappedf(0.1), " cam2 pos=", cam2.global_position.snappedf(0.1), " cam2->p2=", snappedf(World.dist(cam2.global_position, p2.position), 0.1), " hud2 visible=", sp.hud_of(1).visible)
			print("TEST duelA_p2photo115 done")
		"duelA_ov_r6", "duelA_ov115":
			# Правила мира (заготовка «Мирный») + собранный узор → выход из мира: правила возвращаются?
			var SS = preload("res://scripts/server_settings.gd")
			var d0 = DB.data.settings.get("difficulty")
			var m0 = DB.data.settings.get("death", {}).get("mode")
			SS.apply({"settings/difficulty": 0.25, "settings/death/mode": "keep"})
			print("HUNT base difficulty=", d0, " death=", m0, " | in world: difficulty=", DB.data.settings.get("difficulty"), " death=", DB.data.settings.death.get("mode"))
			# собрать первый узор (starworks.try_pattern → DB.revision += 1)
			var st = game.star
			var pts: Array = st.patterns()
			var msg := ""
			if not pts.is_empty():
				var v: Array = st.variants(pts[0])[0]
				var inv := Inventory.new(30)
				for x in v:
					if str(x) != "":
						inv.add(str(x), 1)
				var rv0: int = DB.revision
				msg = st.try_pattern(v, inv)
				print("HUNT pattern '", pts[0].get("name", ""), "': ", msg, " revision ", rv0, "->", DB.revision)
			SS.restore()   # main._exit_tree при выходе в меню
			print("HUNT after leaving world: difficulty=", DB.data.settings.get("difficulty"), " death=", DB.data.settings.death.get("mode"))
			print("TEST duelA_ov115 ", "FAIL(world rules leak into next game)" if DB.data.settings.get("difficulty") != d0 else "OK")
		"duelA_hub_r6", "duelA_hub115":
			# Узел дронов (маршрут A→B): изношенная кирка и подпорченная еда — долетают такими же?
			var f = game.factory
			game.flags["free_build"] = true
			var c: Vector2i = f.hq.cell + Vector2i(22, -16)
			var hub = put_near(game, "drone_hub", c, 0)
			var a = put_near(game, "chest", c + Vector2i(6, 0), 0)
			var z = put_near(game, "chest", c + Vector2i(-6, 0), 0)
			a.cfg["tag"] = "A"
			z.cfg["tag"] = "B"
			for i in a.inv.slots.size():
				a.inv.slots[i] = null
			a.inv.slots[0] = {"id": "iron_pickaxe", "n": 1, "dur": 3.0}
			a.inv.slots[1] = {"id": "fried_meat", "n": 10, "fresh": 50.0}
			var bl: Dictionary = {}
			for ob in Blocks.of("drone_hub"):
				if str(ob.get("type", "")) == "route":
					bl = ob
			var stp: Dictionary = {"item": "", "n": 10, "from_tag": "A", "to_tag": "B", "keep": 0}
			for trip in 4:
				game.carriers.route_step(hub, bl, stp)
				for k in 400:
					game.carriers.update(0.05)
					if game.carriers.flights.is_empty():
						break
			print("HUNT A=", a.inv.slots.filter(func(s): return s != null), " B=", z.inv.slots.filter(func(s): return s != null))
			var bad := false
			for s in z.inv.slots:
				if s != null and ((s.id == "iron_pickaxe" and not s.has("dur")) or (s.id == "fried_meat" and float(s.get("fresh", 0)) > 50.0) or (s.id == "fried_meat" and not s.has("fresh"))):
					bad = true
			print("TEST duelA_hub115 ", "FAIL(hub drones repair/refresh)" if bad else "OK")
		"duelA_p2fog_r6", "duelA_p2fog115":
			# Сплитскрин: второй игрок уходит в неизведанное — открывается ли туман войны?
			Pad.fake_pads = [0, 1]
			var sp = game.split
			var e1 := InputEventJoypadButton.new()
			e1.device = 1
			e1.button_index = JOY_BUTTON_START
			e1.pressed = true
			Input.parse_input_event(e1)
			await tree.process_frame
			await tree.process_frame
			var e2 := InputEventJoypadButton.new()
			e2.device = 1
			e2.button_index = JOY_BUTTON_START
			e2.pressed = false
			Input.parse_input_event(e2)
			await tree.process_frame
			var p1 = sp.p1()
			var p2 = sp.p2()
			var hq: Vector3 = game.factory.hq.center()
			var far1: Vector3 = hq + Vector3(180, 0, 0)
			var far2: Vector3 = hq + Vector3(-180, 0, 0)
			print("HUNT fog on=", game.fog.on(), " split=", sp.active, " before: at far1=", game.fog.explored(far1), " at far2=", game.fog.explored(far2))
			p1.position = far1
			p2.position = far2
			for k in 60:
				await tree.process_frame
			p1.position = far1
			p2.position = far2
			for k in 8:
				game.fog.update(0.3)
			print("HUNT after both stood far away: p1 spot explored=", game.fog.explored(far1), " p2 spot explored=", game.fog.explored(far2))
			print("TEST duelA_p2fog115 ", "FAIL(P2 does not reveal fog)" if game.fog.explored(far1) and not game.fog.explored(far2) else "OK")
		"duelA_vein_r6", "duelA_vein115":
			# Богатая жила: метка на карте остаётся после того, как жилу выкопали?
			var m0: int = game.marks.size()
			var ok: bool = game.events.start("rich_vein")
			var vm = null
			for mk in game.marks:
				if mk is Dictionary and str(mk.get("name", "")).begins_with("Жила"):
					vm = mk
			print("HUNT started=", ok, " marks ", m0, "->", game.marks.size(), " vein mark=", vm)
			if vm != null:
				var c0: Vector2i = World.world_to_cell(Vector3(float(vm.x), 0, float(vm.z)))
				var removed := 0
				for dx in range(-5, 6):
					for dz in range(-5, 6):
						var c := World.wc(c0 + Vector2i(dx, dz))
						if game.world.nodes.has(c):
							game.world.remove_node(c)
							removed += 1
				for k in 600:
					game.events.update(0.1)
				game.events._check_capsules()
				print("HUNT vein mined out: nodes removed=", removed, " vein mark still on map=", game.marks.has(vm), " marks=", game.marks.size())
			# фоторежим: предел отдаления камеры после выхода
			var cm0: float = game.cam_max
			game._action("photo")
			game._action("photo")
			print("HUNT photo: cam_max before=", cm0, " after enter+leave=", game.cam_max, " photo_mode=", game.photo_mode)
			print("TEST duelA_vein115 done")
		"duelA_mod_r6", "duelA_mod115":
			# Установка чужого мода (.fcmod/.zip): фильтр путей, корень архива, совпадение имени со своим модом
			var tmp := ProjectSettings.globalize_path("user://duelA_mods")
			DirAccess.make_dir_recursive_absolute(tmp)
			var mk := func(p: String, files: Dictionary) -> void:
				var z := ZIPPacker.new()
				z.open(p)
				for k in files:
					z.start_file(k)
					z.write_file(str(files[k]).to_utf8_buffer())
				z.close()
			# A) обратная косая черта
			var pa: String = tmp.path_join("evil.fcmod")
			mk.call(pa, {"evil/mod.json": JSON.stringify({"name": "evil"}), "evil/..\\..\\..\\pwn_duelA.json": "{}"})
			var ra: Dictionary = ModKit.install(pa)
			print("HUNT A backslash: ok=", ra.get("ok"), " files=", ra.get("files"), " skipped=", ra.get("skipped"), " written=", DirAccess.get_files_at(ModKit.dir_of(str(ra.get("id", "evil")))))
			# B) корень архива по первому json
			var pb: String = tmp.path_join("flat.zip")
			mk.call(pb, {"models/duela_m.json": "{}", "mod.json": JSON.stringify({"name": "Flat mod"}), "items.json": JSON.stringify({"duela_flat_item": {"name": "X"}})})
			var rb: Dictionary = ModKit.install(pb)
			var bid := str(rb.get("id", ""))
			print("HUNT B flat zip: ok=", rb.get("ok"), " id=", bid, " files=", rb.get("files"), " skipped=", rb.get("skipped"), " has items.json=", FileAccess.file_exists(ModKit.dir_of(bid).path_join("items.json")), " name=", ModKit.info(bid).get("name"))
			# C) свой мод «Мой мод» и чужой с тем же названием
			var my: String = ModKit.ensure("Мой мод", "я")
			ModKit.put(my, "items", "duela_my_sword", {"name": "Мой меч"})
			var pc: String = tmp.path_join("friend.fcmod")
			mk.call(pc, {my + "/mod.json": JSON.stringify({"name": "Мой мод", "author": "друг"}), my + "/items.json": JSON.stringify({"duela_friend_hat": {"name": "Шляпа"}})})
			var rc: Dictionary = ModKit.install(pc)
			print("HUNT C same name: ok=", rc.get("ok"), " id=", rc.get("id"), " my id=", my, " my items now=", ModKit._file(my, "items").keys(), " author=", ModKit.info(my).get("author"))
			print("TEST duelA_mod115 done")
		"duelA_p2car_r6", "duelA_p2car115":
			# Сплитскрин: второй игрок садится в ровер — кто едет, кто ускоряется, кто прячется?
			Pad.fake_pads = [0, 1]
			var sp = game.split
			var e1 := InputEventJoypadButton.new()
			e1.device = 1
			e1.button_index = JOY_BUTTON_START
			e1.pressed = true
			Input.parse_input_event(e1)
			await tree.process_frame
			await tree.process_frame
			var e2 := InputEventJoypadButton.new()
			e2.device = 1
			e2.button_index = JOY_BUTTON_START
			e2.pressed = false
			Input.parse_input_event(e2)
			await tree.process_frame
			var p1 = sp.p1()
			var p2 = sp.p2()
			var f = game.factory
			game.flags["free_build"] = true
			var c: Vector2i = f.hq.cell + Vector2i(14, 14)
			var rv = put_near(game, "rover", c, 0)
			p1.position = World.cell_to_world(f.hq.cell + Vector2i(-12, -12))
			p2.position = rv.center() + Vector3(2, 0, 2)
			print("HUNT split=", sp.active, " rover=", rv != null)
			sp.with_seat(1, func(): game.vehicles.enter(rv))
			for k in 5:
				await tree.process_frame
			print("HUNT p2 drives: driving=", game.vehicles.driving, " speed_mult(any hero)=", game.vehicles.speed_mult(), " p1 hips vis=", p1.hips.visible, " p2 hips vis=", p2.hips.visible)
			print("HUNT rover node at p1 dist=", World.dist(game.vehicles.node.position, p1.position), " at p2 dist=", World.dist(game.vehicles.node.position, p2.position))
			# P1 жмёт E далеко от ровера
			game._interact()
			await tree.process_frame
			var rb = null
			for bb in f.all:
				if bb.type == "rover":
					rb = bb
			print("HUNT after P1 presses E: driving='", game.vehicles.driving, "' rover parked near p1=", (World.dist(rb.center(), p1.position) if rb else -1), " near p2=", (World.dist(rb.center(), p2.position) if rb else -1), " p2 hips vis=", p2.hips.visible)
			print("TEST duelA_p2car115 done")
		"duelA_p2photo_r6":
			# Сплитскрин: первый включает свободную камеру — что с камерой второго?
			Pad.fake_pads = [0, 1]
			var sp = game.split
			var e1 := InputEventJoypadButton.new()
			e1.device = 1
			e1.button_index = JOY_BUTTON_START
			e1.pressed = true
			Input.parse_input_event(e1)
			await tree.process_frame
			await tree.process_frame
			var e2 := InputEventJoypadButton.new()
			e2.device = 1
			e2.button_index = JOY_BUTTON_START
			e2.pressed = false
			Input.parse_input_event(e2)
			await tree.process_frame
			var p1 = sp.p1()
			var p2 = sp.p2()
			p2.position = p1.position + Vector3(60, 0, 0)
			for k in 30:
				await tree.process_frame
			var cam2 = sp.with_seat(1, func(): return game.camera)
			var cam1 = sp.with_seat(0, func(): return game.camera)
			print("HUNT before: cam1->p1=", snappedf(World.dist(cam1.global_position, p1.position), 0.1), " cam2->p2=", snappedf(World.dist(cam2.global_position, p2.position), 0.1), " same cam=", cam1 == cam2)
			game.free_camera()
			game.photo.pos = p1.position + Vector3(-40, 20, 0)
			for k in 30:
				await tree.process_frame
			print("HUNT free cam: photo_mode=", game.photo_mode, " cam1 pos=", cam1.global_position.snappedf(0.1), " cam2 pos=", cam2.global_position.snappedf(0.1), " cam2->p2=", snappedf(World.dist(cam2.global_position, p2.position), 0.1), " hud2 visible=", sp.hud_of(1).visible)
			print("TEST duelA_p2photo115 done")
		"duelA_ov_r6":
			# Правила мира (заготовка «Мирный») + собранный узор → выход из мира: правила возвращаются?
			var SS = preload("res://scripts/server_settings.gd")
			var d0 = DB.data.settings.get("difficulty")
			var m0 = DB.data.settings.get("death", {}).get("mode")
			SS.apply({"settings/difficulty": 0.25, "settings/death/mode": "keep"})
			print("HUNT base difficulty=", d0, " death=", m0, " | in world: difficulty=", DB.data.settings.get("difficulty"), " death=", DB.data.settings.death.get("mode"))
			# собрать первый узор (starworks.try_pattern → DB.revision += 1)
			var st = game.star
			var pts: Array = st.patterns()
			var msg := ""
			if not pts.is_empty():
				var v: Array = st.variants(pts[0])[0]
				var inv := Inventory.new(30)
				for x in v:
					if str(x) != "":
						inv.add(str(x), 1)
				var rv0: int = DB.revision
				msg = st.try_pattern(v, inv)
				print("HUNT pattern '", pts[0].get("name", ""), "': ", msg, " revision ", rv0, "->", DB.revision)
			SS.restore()   # main._exit_tree при выходе в меню
			print("HUNT after leaving world: difficulty=", DB.data.settings.get("difficulty"), " death=", DB.data.settings.death.get("mode"))
			print("TEST duelA_ov115 ", "FAIL(world rules leak into next game)" if DB.data.settings.get("difficulty") != d0 else "OK")
		"duelA_hub_r6":
			# Узел дронов (маршрут A→B): изношенная кирка и подпорченная еда — долетают такими же?
			var f = game.factory
			game.flags["free_build"] = true
			var c: Vector2i = f.hq.cell + Vector2i(22, -16)
			var hub = put_near(game, "drone_hub", c, 0)
			var a = put_near(game, "chest", c + Vector2i(6, 0), 0)
			var z = put_near(game, "chest", c + Vector2i(-6, 0), 0)
			a.cfg["tag"] = "A"
			z.cfg["tag"] = "B"
			for i in a.inv.slots.size():
				a.inv.slots[i] = null
			a.inv.slots[0] = {"id": "iron_pickaxe", "n": 1, "dur": 3.0}
			a.inv.slots[1] = {"id": "fried_meat", "n": 10, "fresh": 50.0}
			var bl: Dictionary = {}
			for ob in Blocks.of("drone_hub"):
				if str(ob.get("type", "")) == "route":
					bl = ob
			var stp: Dictionary = {"item": "", "n": 10, "from_tag": "A", "to_tag": "B", "keep": 0}
			for trip in 4:
				game.carriers.route_step(hub, bl, stp)
				for k in 400:
					game.carriers.update(0.05)
					if game.carriers.flights.is_empty():
						break
			print("HUNT A=", a.inv.slots.filter(func(s): return s != null), " B=", z.inv.slots.filter(func(s): return s != null))
			var bad := false
			for s in z.inv.slots:
				if s != null and ((s.id == "iron_pickaxe" and not s.has("dur")) or (s.id == "fried_meat" and float(s.get("fresh", 0)) > 50.0) or (s.id == "fried_meat" and not s.has("fresh"))):
					bad = true
			print("TEST duelA_hub115 ", "FAIL(hub drones repair/refresh)" if bad else "OK")
		"duelA_p2fog_r6":
			# Сплитскрин: второй игрок уходит в неизведанное — открывается ли туман войны?
			Pad.fake_pads = [0, 1]
			var sp = game.split
			var e1 := InputEventJoypadButton.new()
			e1.device = 1
			e1.button_index = JOY_BUTTON_START
			e1.pressed = true
			Input.parse_input_event(e1)
			await tree.process_frame
			await tree.process_frame
			var e2 := InputEventJoypadButton.new()
			e2.device = 1
			e2.button_index = JOY_BUTTON_START
			e2.pressed = false
			Input.parse_input_event(e2)
			await tree.process_frame
			var p1 = sp.p1()
			var p2 = sp.p2()
			var hq: Vector3 = game.factory.hq.center()
			var far1: Vector3 = hq + Vector3(180, 0, 0)
			var far2: Vector3 = hq + Vector3(-180, 0, 0)
			print("HUNT fog on=", game.fog.on(), " split=", sp.active, " before: at far1=", game.fog.explored(far1), " at far2=", game.fog.explored(far2))
			p1.position = far1
			p2.position = far2
			for k in 60:
				await tree.process_frame
			p1.position = far1
			p2.position = far2
			for k in 8:
				game.fog.update(0.3)
			print("HUNT after both stood far away: p1 spot explored=", game.fog.explored(far1), " p2 spot explored=", game.fog.explored(far2))
			print("TEST duelA_p2fog115 ", "FAIL(P2 does not reveal fog)" if game.fog.explored(far1) and not game.fog.explored(far2) else "OK")
		"duelA_vein_r6":
			# Богатая жила: метка на карте остаётся после того, как жилу выкопали?
			var m0: int = game.marks.size()
			var ok: bool = game.events.start("rich_vein")
			var vm = null
			for mk in game.marks:
				if mk is Dictionary and str(mk.get("name", "")).begins_with("Жила"):
					vm = mk
			print("HUNT started=", ok, " marks ", m0, "->", game.marks.size(), " vein mark=", vm)
			if vm != null:
				var c0: Vector2i = World.world_to_cell(Vector3(float(vm.x), 0, float(vm.z)))
				var removed := 0
				for dx in range(-5, 6):
					for dz in range(-5, 6):
						var c := World.wc(c0 + Vector2i(dx, dz))
						if game.world.nodes.has(c):
							game.world.remove_node(c)
							removed += 1
				for k in 600:
					game.events.update(0.1)
				game.events._check_capsules()
				print("HUNT vein mined out: nodes removed=", removed, " vein mark still on map=", game.marks.has(vm), " marks=", game.marks.size())
			# фоторежим: предел отдаления камеры после выхода
			var cm0: float = game.cam_max
			game._action("photo")
			game._action("photo")
			print("HUNT photo: cam_max before=", cm0, " after enter+leave=", game.cam_max, " photo_mode=", game.photo_mode)
			print("TEST duelA_vein115 done")
		"duelA_mod_r6":
			# Установка чужого мода (.fcmod/.zip): фильтр путей, корень архива, совпадение имени со своим модом
			var tmp := ProjectSettings.globalize_path("user://duelA_mods")
			DirAccess.make_dir_recursive_absolute(tmp)
			var mk := func(p: String, files: Dictionary) -> void:
				var z := ZIPPacker.new()
				z.open(p)
				for k in files:
					z.start_file(k)
					z.write_file(str(files[k]).to_utf8_buffer())
				z.close()
			# A) обратная косая черта
			var pa: String = tmp.path_join("evil.fcmod")
			mk.call(pa, {"evil/mod.json": JSON.stringify({"name": "evil"}), "evil/..\\..\\..\\pwn_duelA.json": "{}"})
			var ra: Dictionary = ModKit.install(pa)
			print("HUNT A backslash: ok=", ra.get("ok"), " files=", ra.get("files"), " skipped=", ra.get("skipped"), " written=", DirAccess.get_files_at(ModKit.dir_of(str(ra.get("id", "evil")))))
			# B) корень архива по первому json
			var pb: String = tmp.path_join("flat.zip")
			mk.call(pb, {"models/duela_m.json": "{}", "mod.json": JSON.stringify({"name": "Flat mod"}), "items.json": JSON.stringify({"duela_flat_item": {"name": "X"}})})
			var rb: Dictionary = ModKit.install(pb)
			var bid := str(rb.get("id", ""))
			print("HUNT B flat zip: ok=", rb.get("ok"), " id=", bid, " files=", rb.get("files"), " skipped=", rb.get("skipped"), " has items.json=", FileAccess.file_exists(ModKit.dir_of(bid).path_join("items.json")), " name=", ModKit.info(bid).get("name"))
			# C) свой мод «Мой мод» и чужой с тем же названием
			var my: String = ModKit.ensure("Мой мод", "я")
			ModKit.put(my, "items", "duela_my_sword", {"name": "Мой меч"})
			var pc: String = tmp.path_join("friend.fcmod")
			mk.call(pc, {my + "/mod.json": JSON.stringify({"name": "Мой мод", "author": "друг"}), my + "/items.json": JSON.stringify({"duela_friend_hat": {"name": "Шляпа"}})})
			var rc: Dictionary = ModKit.install(pc)
			print("HUNT C same name: ok=", rc.get("ok"), " id=", rc.get("id"), " my id=", my, " my items now=", ModKit._file(my, "items").keys(), " author=", ModKit.info(my).get("author"))
			print("TEST duelA_mod115 done")
		"duelA_p2car_r6":
			# Сплитскрин: второй игрок садится в ровер — кто едет, кто ускоряется, кто прячется?
			Pad.fake_pads = [0, 1]
			var sp = game.split
			var e1 := InputEventJoypadButton.new()
			e1.device = 1
			e1.button_index = JOY_BUTTON_START
			e1.pressed = true
			Input.parse_input_event(e1)
			await tree.process_frame
			await tree.process_frame
			var e2 := InputEventJoypadButton.new()
			e2.device = 1
			e2.button_index = JOY_BUTTON_START
			e2.pressed = false
			Input.parse_input_event(e2)
			await tree.process_frame
			var p1 = sp.p1()
			var p2 = sp.p2()
			var f = game.factory
			game.flags["free_build"] = true
			var c: Vector2i = f.hq.cell + Vector2i(14, 14)
			var rv = put_near(game, "rover", c, 0)
			p1.position = World.cell_to_world(f.hq.cell + Vector2i(-12, -12))
			p2.position = rv.center() + Vector3(2, 0, 2)
			print("HUNT split=", sp.active, " rover=", rv != null)
			sp.with_seat(1, func(): game.vehicles.enter(rv))
			for k in 5:
				await tree.process_frame
			print("HUNT p2 drives: driving=", game.vehicles.driving, " speed_mult(any hero)=", game.vehicles.speed_mult(), " p1 hips vis=", p1.hips.visible, " p2 hips vis=", p2.hips.visible)
			print("HUNT rover node at p1 dist=", World.dist(game.vehicles.node.position, p1.position), " at p2 dist=", World.dist(game.vehicles.node.position, p2.position))
			# P1 жмёт E далеко от ровера
			game._interact()
			await tree.process_frame
			var rb = null
			for bb in f.all:
				if bb.type == "rover":
					rb = bb
			print("HUNT after P1 presses E: driving='", game.vehicles.driving, "' rover parked near p1=", (World.dist(rb.center(), p1.position) if rb else -1), " near p2=", (World.dist(rb.center(), p2.position) if rb else -1), " p2 hips vis=", p2.hips.visible)
			print("TEST duelA_p2car115 done")
		"langchk":
			for t in ["залежь (бур)", "Уголь, залежь (бур)", "Добывается: Уголь, залежь (бур)", "\nДобывается: залежь (бур)", "топливо: 0 с", "Не работает: нужно топливо или солнце · топливо: 0 с", "мало энергии (0%)", "Блоки: мало энергии (0%)", "Тонкая настройка: Кислотность (pH)", "Кислотность (pH)"]:
				print("LC '", t.c_escape(), "' -> '", Lang.t(t).c_escape(), "'")
			print("TEST langchk done")
		"duelA_pwoff_r5":
			# Энергоблок (генератор-основа + встроенный угольный генератор), основа «Выключено»
			var f = game.factory
			game.flags["free_build"] = true
			var c: Vector2i = f.hq.cell + Vector2i(-34, 26)
			for dx in range(-6, 20):
				for dz in range(-6, 20):
					game.world.remove_node(World.wc(c + Vector2i(dx, dz)))
			var h = put_near(game, "generator", c, 0)
			var g2 = put(game, "coal_generator", h.cell + Vector2i(h.size, 0), 0)
			print("HUNT h=", h, " g2=", g2)
			print("HUNT why=", f.fz.combo_why(h, g2), " host=", f.fz.pick_host(h, g2).type)
			var ok: bool = f.fz.fuse_combo(h, g2)
			var hh = h if not h.subs.is_empty() else g2
			var s = hh.subs[0]
			s.fuel.add("coal", 20)
			var la = put_near(game, "assembler", c + Vector2i(0, 8), 0)
			f.add_wire(hh, la)
			la.recipe = DB.recipes_for(str(la.p("station", "")))[0]
			var nc: Dictionary = hh.cfg.duplicate(true)
			nc["off"] = true
			game.cmd("bcfg", {"b": hh, "cfg": nc})
			f._rebuild_power()
			var c0: int = s.fuel.count("coal")
			for k in 600:
				la.want = true
				f._power(0.1)
				f.fz.tick_power(0.1)
			var ni: Dictionary = f.net_info(la)
			print("HUNT fused=", ok, " host=", hh.type, " off=", hh.cfg.get("off"), " clock(sub)=", Factory.clock(s), " sub active=", s.active, " coal used in 60s=", c0 - s.fuel.count("coal"), " fuel_t=", snappedf(s.fuel_t, 0.1), " net supply=", ni.get("supply"), " demand=", ni.get("demand"), " sat=", ni.get("sat"))
			print("TEST duelA_pwoff115 ", "FAIL(bug: off block burns fuel)" if c0 - s.fuel.count("coal") > 0 else "OK")
		"duelA_def2_r5":
			var f = game.factory
			game.flags["free_build"] = true
			var c: Vector2i = f.hq.cell + Vector2i(30, 20)
			var br = put_near(game, "barrier_small", c, 0)
			print("HUNT br=", br, " why=", f.can_place("barrier_small", c))
			var ch = put(game, "chest", br.cell + Vector2i(br.size, 0), 0)
			print("HUNT why=", f.fz.combo_why(br, ch))
			f.fz.fuse_combo(br, ch)
			f._rebuild_power()
			for k in 30:
				f._power(0.1)
				f.fz.tick_power(0.1)
				game.defense.update(0.1)
			print("HUNT barrier+chest net=", br.net, " subs=", br.subs.size(), " csat=", br.csat, " cneed=", br.cneed, " active=", game.defense._active(br))
			print("TEST duelA_def2115 ", "FAIL" if game.defense._active(br) and br.net < 0 else "OK")
		"duelA_thief2_r5":
			# Вор и стопка еды (после 1 с в рюкзаке у еды есть "fresh"): сколько унесёт? (steal = 8)
			var pl = game.player
			for i in pl.inv.slots.size():
				pl.inv.slots[i] = null
			pl.selected = 0
			pl.inv.slots[0] = {"id": "stone_axe", "n": 1}
			pl.inv.slots[4] = {"id": "fried_meat", "n": 20, "fresh": 1700.0}
			var e = game.enemies.spawn("thief", pl.position + Vector3(3, 0, 3))
			print("HUNT thief steal=", e.d.get("steal"), " meat before=", pl.inv.count("fried_meat"))
			game.enemies._steal(e, pl)
			print("HUNT stolen=", e.stolen, " meat left=", pl.inv.count("fried_meat"))
			var got: int = 20 - pl.inv.count("fried_meat")
			print("TEST duelA_thief2115 ", "FAIL(bug: steals whole stack)" if got > int(e.d.get("steal", 0)) else "OK")
		"duelA_entut_r5":
			# Английский: карточка обучения на каждом шаге — что остаётся по-русски
			var T = game.tutorial
			var rx := RegEx.create_from_string("[А-Яа-яЁё]")
			var seen := {}
			print("HUNT lang=", Lang.current(), " steps=", Tutorial.steps().size())
			for i in Tutorial.steps().size():
				T.done = false
				T.active = true
				T.step = i
				T._enter()
				T._build_card()
				await tree.process_frame
				await tree.process_frame
				for n in T.card.find_children("*", "", true, false):
					var txts := []
					if n is Label or n is Button:
						txts.append(n.text)
					elif n is RichTextLabel:
						txts.append(n.text)
					if n is Control and n.tooltip_text != "":
						txts.append(n.tooltip_text)
					for s in txts:
						var tt: String = TranslationServer.translate(str(s)) if n.auto_translate_mode != Node.AUTO_TRANSLATE_MODE_DISABLED else str(s)
						if rx.search(tt) != null and not seen.has(tt):
							seen[tt] = true
							print("HUNT step ", i, " ", Tutorial.steps()[i].get("goal", ""), " | ", tt.replace("\n", "\\n").substr(0, 200))
				var gt: String = TranslationServer.translate(T.goal_text())
				if rx.search(gt) != null and not seen.has(gt):
					seen[gt] = true
					print("HUNT goal ", i, " | ", gt)
			print("TEST duelA_entut115 ", "FAIL" if seen.size() > 0 else "OK", " n=", seen.size())
		"duelA_axe_r5":
			# Подсказка топора: {key:rotate} подставляется?
			var tip: String = UI.item_tip("stone_axe")
			print("HUNT tip=", tip.replace("\n", " | "))
			game.player.inv.add("iron_axe", 1)
			game.hud.open("inventory")
			await tree.process_frame
			await tree.process_frame
			var shown := []
			for n in game.hud.windows.inventory.find_children("*", "", true, false):
				if n is Control and (n.tooltip_text.find("{key:") >= 0 or ((n is Label or n is RichTextLabel) and n.text.find("{key:") >= 0)):
					shown.append(n.get_class())
			print("HUNT inventory controls with literal {key:} = ", shown.size())
			print("TEST duelA_axe115 ", "FAIL(literal placeholder)" if tip.find("{key:") >= 0 else "OK")
		"duelA_spike_r5":
			# Шипы подземелья (trap_dps_player 22): второй игрок сплитскрина стоит на них — ранит?
			Pad.fake_pads = [0, 1]
			var sp = game.split
			var f = game.factory
			var e1 := InputEventJoypadButton.new()
			e1.device = 1
			e1.button_index = JOY_BUTTON_START
			e1.pressed = true
			Input.parse_input_event(e1)
			await tree.process_frame
			await tree.process_frame
			var e2 := InputEventJoypadButton.new()
			e2.device = 1
			e2.button_index = JOY_BUTTON_START
			e2.pressed = false
			Input.parse_input_event(e2)
			await tree.process_frame
			var p1 = sp.p1()
			var p2 = sp.p2()
			print("HUNT split active=", sp.active, " p2=", p2 != null)
			var c: Vector2i = f.hq.cell + Vector2i(14, -14)
			var t1 = put_near(game, "dungeon_spikes", c, 0)
			var t2 = put_near(game, "dungeon_spikes", c + Vector2i(8, 0), 0)
			game.maze.rebuild()
			print("HUNT traps=", game.maze.traps.size())
			for k in 40:
				p1.position = t1.center()
				p1.position.y = f.support_at(p1.position)
				p2.position = t2.center()
				p2.position.y = f.support_at(p2.position)
				if k == 0:
					p1.hp = p1.maxhp
					p2.hp = p2.maxhp
				game.maze._traps(0.25)
			print("HUNT after 10s on spikes: p1 hp=", p1.hp, "/", p1.maxhp, " p2 hp=", p2.hp, "/", p2.maxhp, " game.player==p1:", game.player == p1)
			print("TEST duelA_spike115 ", "FAIL(p2 immune)" if p2.hp >= p2.maxhp and p1.hp < p1.maxhp else "OK")
		"duelA_p2hit_r5":
			# Сплитскрин: взрыв бомбера и плевок плевальщика рядом со ВТОРЫМ игроком
			Pad.fake_pads = [0, 1]
			var sp = game.split
			var f = game.factory
			var e1 := InputEventJoypadButton.new()
			e1.device = 1
			e1.button_index = JOY_BUTTON_START
			e1.pressed = true
			Input.parse_input_event(e1)
			await tree.process_frame
			await tree.process_frame
			var e2 := InputEventJoypadButton.new()
			e2.device = 1
			e2.button_index = JOY_BUTTON_START
			e2.pressed = false
			Input.parse_input_event(e2)
			await tree.process_frame
			var p1 = sp.p1()
			var p2 = sp.p2()
			var EN = game.enemies
			var res := {}
			for who in ["p1", "p2"]:
				var pl = p1 if who == "p1" else p2
				p1.hp = p1.maxhp
				p2.hp = p2.maxhp
				var at: Vector3 = f.hq.center() + Vector3(30, 0, 30) if who == "p1" else f.hq.center() + Vector3(-30, 0, 30)
				at.y = f.support_at(at)
				pl.position = at
				var bm = EN.spawn("bomber", at + Vector3(1.0, 0, 0))
				EN._explode(bm)
				var after_boom: float = pl.hp
				# плевок: снаряд летит прямо в героя
				EN.spit.append([at + Vector3(0.3, 1.0, 0), Vector3(0, 0, 0), 3.0, 20.0])
				EN._update_spit(0.016)
				res[who] = [pl.maxhp - after_boom, after_boom - pl.hp]
				print("HUNT ", who, " boom dmg=", pl.maxhp - after_boom, " spit dmg=", after_boom - pl.hp, " hp=", pl.hp, "/", pl.maxhp)
			print("TEST duelA_p2hit115 ", "FAIL(p2 immune)" if res.p1[0] > 0 and res.p2[0] <= 0 else "OK")
		"duelA_p2env_r5":
			# Сплитскрин: кислота в рюкзаке (опасности) у второго героя
			Pad.fake_pads = [0, 1]
			var sp = game.split
			var e1 := InputEventJoypadButton.new()
			e1.device = 1
			e1.button_index = JOY_BUTTON_START
			e1.pressed = true
			Input.parse_input_event(e1)
			await tree.process_frame
			await tree.process_frame
			var e2 := InputEventJoypadButton.new()
			e2.device = 1
			e2.button_index = JOY_BUTTON_START
			e2.pressed = false
			Input.parse_input_event(e2)
			await tree.process_frame
			var p1 = sp.p1()
			var p2 = sp.p2()
			var H = game.hazards
			print("HUNT hazards on=", H.enabled(), " climate on=", game.climate.enabled())
			for who in ["p2", "p1"]:
				var pl = p1 if who == "p1" else p2
				for s in [p1, p2]:
					s.hp = s.maxhp
					for i in s.inv.slots.size():
						if s.inv.slots[i] != null and s.inv.slots[i].id == "canister_acid":
							s.inv.slots[i] = null
				pl.inv.add("canister_acid", 10)
				for k in 10:
					H._step(1.0)
				print("HUNT ", who, " carries 10 acid canisters 10s: p1 hp=", p1.hp, " p2 hp=", p2.hp, " acid_hit=", H.acid_hit)
			print("TEST duelA_p2env115 done")
		"duelA_p2inv_r5":
			# Сплитскрин: вещи второго героя при выходе и при сохранении
			Pad.fake_pads = [0, 1]
			var sp = game.split
			var f = game.factory
			var startp2 := func():
				var e1 := InputEventJoypadButton.new()
				e1.device = 1
				e1.button_index = JOY_BUTTON_START
				e1.pressed = true
				Input.parse_input_event(e1)
				await tree.process_frame
				await tree.process_frame
				var e2 := InputEventJoypadButton.new()
				e2.device = 1
				e2.button_index = JOY_BUTTON_START
				e2.pressed = false
				Input.parse_input_event(e2)
				await tree.process_frame
			await startp2.call()
			var p2 = sp.p2()
			for i in p2.inv.slots.size():
				p2.inv.slots[i] = null
			p2.inv.slots[0] = {"id": "iron_pickaxe", "n": 1, "dur": 3.0}
			p2.inv.add("copper_ingot", 40)
			# (1) сохранение со вторым игроком → загрузка → сохранение без него → загрузка
			var d1: Dictionary = JSON.parse_string(JSON.stringify(game.save_dict()))
			print("HUNT save1 split2=", d1.get("split2", {}).get("inv", []).filter(func(s): return s != null))
			sp.stop()
			await tree.process_frame
			# вещи ушли в штаб при выходе: прочность кирки?
			var hq_pick = null
			for s in f.hq.inv.slots:
				if s != null and s.id == "iron_pickaxe":
					hq_pick = s
			print("HUNT after stop: hq pickaxe slot=", hq_pick, " (was dur=3)")
			game.load_game(d1)
			print("HUNT loaded save1: p2_start_inv=", sp.p2_start_inv.filter(func(s): return s != null), " split active=", sp.active)
			var d2: Dictionary = JSON.parse_string(JSON.stringify(game.save_dict()))
			print("HUNT save2 (P2 not pressed Start yet) has split2=", d2.has("split2"))
			game.load_game(d2)
			print("HUNT loaded save2: p2_start_inv=", sp.p2_start_inv.filter(func(s): return s != null))
			print("TEST duelA_p2inv115 ", "FAIL(P2 items lost)" if not d2.has("split2") else "OK")
		"duelA_p2die_r5":
			# Сплитскрин: монстр убил ВТОРОГО героя (урон приходит из enemies.update, место 0)
			Pad.fake_pads = [0, 1]
			var sp = game.split
			var e1 := InputEventJoypadButton.new()
			e1.device = 1
			e1.button_index = JOY_BUTTON_START
			e1.pressed = true
			Input.parse_input_event(e1)
			await tree.process_frame
			await tree.process_frame
			var e2 := InputEventJoypadButton.new()
			e2.device = 1
			e2.button_index = JOY_BUTTON_START
			e2.pressed = false
			Input.parse_input_event(e2)
			await tree.process_frame
			var p1 = sp.p1()
			var p2 = sp.p2()
			for s in [p1, p2]:
				for i in s.inv.slots.size():
					s.inv.slots[i] = null
			p1.inv.add("iron_ingot", 50)
			p2.inv.add("copper_ingot", 30)
			p2.position = p1.position + Vector3(20, 0, 0)
			var g0: int = game.graves.size()
			sp.use(0)
			var m = game.enemies.spawn("crawler", p2.position + Vector3(1, 0, 0))
			m.target = p2
			m.dmg = 1.0e6
			print("HUNT before: game.player==p1:", game.player == p1, " cur=", sp.cur, " mode=", DB.data.settings.get("death", {}), " p1 inv empty=", p1.inv.is_empty())
			p2.damage(1.0e6)   # как в enemies.update: `if e.target == player: player.damage(e.dmg)` при player = e.target
			print("HUNT right after: graves=", game.graves.size(), " p1 iron=", p1.inv.count("iron_ingot"), " p2.game==game:", p2.game == game, " p2 hp=", p2.hp)
			await tree.process_frame
			var gpos = game.graves[-1].pos if game.graves.size() > g0 else null
			print("HUNT p2 alive=", p2.alive, " p1 alive=", p1.alive)
			print("HUNT after P2 death: p1 iron=", p1.inv.count("iron_ingot"), " p2 copper=", p2.inv.count("copper_ingot"), " new graves=", game.graves.size() - g0)
			if game.graves.size() > g0:
				var gr = game.graves[-1]
				print("HUNT grave has iron=", gr.inv.count("iron_ingot"), " copper=", gr.inv.count("copper_ingot"), " dist to p1=", snappedf(World.dist(gr.node.position, p1.position), 0.1), " to p2=", snappedf(World.dist(gr.node.position, p2.position), 0.1))
			print("TEST duelA_p2die115 ", "FAIL(P1 loses items)" if p1.inv.count("iron_ingot") < 50 else "OK")
		"duelA_p2craft_r5":
			# Сплитскрин: второй игрок крафтит в руках — куда приходит готовое?
			Pad.fake_pads = [0, 1]
			var sp = game.split
			var e1 := InputEventJoypadButton.new()
			e1.device = 1
			e1.button_index = JOY_BUTTON_START
			e1.pressed = true
			Input.parse_input_event(e1)
			await tree.process_frame
			await tree.process_frame
			var e2 := InputEventJoypadButton.new()
			e2.device = 1
			e2.button_index = JOY_BUTTON_START
			e2.pressed = false
			Input.parse_input_event(e2)
			await tree.process_frame
			var p1 = sp.p1()
			var p2 = sp.p2()
			for s in [p1, p2]:
				for i in s.inv.slots.size():
					s.inv.slots[i] = null
			p2.inv.add("branch", 3)
			p2.inv.add("stone", 2)
			p2.inv.add("fiber", 2)
			sp.with_seat(1, func(): game.queue_craft("stone_axe", 1, "hand"))
			print("HUNT queued=", game.craft_queue.size(), " p2 branch left=", p2.inv.count("branch"))
			for k in 3000:
				await tree.process_frame
				if game.craft_queue.is_empty():
					break
			print("HUNT queue empty=", game.craft_queue.is_empty(), " paused=", game.paused)
			for k in 5:
				await tree.process_frame
			print("HUNT done: p1 axes=", p1.inv.count("stone_axe"), " p2 axes=", p2.inv.count("stone_axe"))
			print("TEST duelA_p2craft115 ", "FAIL(P2 craft goes to P1)" if p1.inv.count("stone_axe") > 0 and p2.inv.count("stone_axe") == 0 else "OK")
		"duelA_drone_r5":
			# Дрон везёт изношенную кирку из ящика А в ящик Б — износ сохраняется?
			var f = game.factory
			game.flags["free_build"] = true
			var c: Vector2i = f.hq.cell + Vector2i(22, -16)
			var stn = put_near(game, "drone_station", c, 0)
			var a = put_near(game, "chest", c + Vector2i(6, 0), 0)
			var z = put_near(game, "chest", c + Vector2i(-6, 0), 0)
			var g = put_near(game, "generator", c + Vector2i(0, 6), 0)
			g.fuel.add("coal", 50)
			f.add_wire(g, stn)
			f._rebuild_power()
			a.inv.slots[0] = {"id": "iron_pickaxe", "n": 1, "dur": 3.0}
			a.inv.slots[1] = {"id": "fried_meat", "n": 10, "fresh": 50.0}
			game.drones.set_routes(stn, [{"from": [a.cell.x, a.cell.y], "to": [z.cell.x, z.cell.y], "item": "", "keep": 0, "on": true}])
			for k in 2400:
				f._power(0.05)
				game.drones.update(0.05)
				if a.inv.is_empty() and game.drones.drones_of(stn).all(func(d): return int(d.n) == 0):
					break
			print("HUNT A=", a.inv.slots.filter(func(s): return s != null), " B=", z.inv.slots.filter(func(s): return s != null))
			var ok := false
			for s in z.inv.slots:
				if s != null and s.id == "iron_pickaxe" and not s.has("dur"):
					ok = true
			print("TEST duelA_drone115 ", "FAIL(worn pickaxe arrives new)" if ok else "OK")
		"duelA_p2med_r5":
			# Сплитскрин: медпункт лечит второго героя?
			Pad.fake_pads = [0, 1]
			var sp = game.split
			var f = game.factory
			game.flags["free_build"] = true
			var e1 := InputEventJoypadButton.new()
			e1.device = 1
			e1.button_index = JOY_BUTTON_START
			e1.pressed = true
			Input.parse_input_event(e1)
			await tree.process_frame
			await tree.process_frame
			var e2 := InputEventJoypadButton.new()
			e2.device = 1
			e2.button_index = JOY_BUTTON_START
			e2.pressed = false
			Input.parse_input_event(e2)
			await tree.process_frame
			var p1 = sp.p1()
			var p2 = sp.p2()
			var mb = put_near(game, "medbay", f.hq.cell + Vector2i(18, 18), 0)
			var g = put_near(game, "generator", mb.cell + Vector2i(5, 0), 0)
			g.fuel.add("coal", 50)
			f.add_wire(g, mb)
			f._rebuild_power()
			p1.position = f.hq.center() + Vector3(-40, 0, -40)
			p2.position = mb.center() + Vector3(1.0, 0, 0)
			p1.hp = 50.0
			p2.hp = 50.0
			for k in 40:
				f._power(0.25)
				Blocks.update(f, mb, 0.25)
			print("HUNT medbay sat=", f.sat_c(mb), " p2 (at medbay) hp=", p2.hp, " p1 (far) hp=", p1.hp)
			p1.position = mb.center() + Vector3(-1.0, 0, 0)
			for k in 8:
				f._power(0.25)
				Blocks.update(f, mb, 0.25)
			print("HUNT p1 at medbay 2s: p1 hp=", p1.hp)
			print("TEST duelA_p2med115 ", "FAIL(P2 not healed)" if p2.hp <= 50.0 and p1.hp > 50.0 else "OK")
		"langchk":
			for t in ["залежь (бур)", "Уголь, залежь (бур)", "Добывается: Уголь, залежь (бур)", "\nДобывается: залежь (бур)", "топливо: 0 с", "Не работает: нужно топливо или солнце · топливо: 0 с", "мало энергии (0%)", "Блоки: мало энергии (0%)", "Тонкая настройка: Кислотность (pH)", "Кислотность (pH)"]:
				print("LC '", t.c_escape(), "' -> '", Lang.t(t).c_escape(), "'")
			print("TEST langchk done")
		"duelA_bp_r4":
			# Чертёж составного и объединённого здания
			var f = game.factory
			game.flags["free_build"] = true
			var h = put_near(game, "assembler", f.hq.cell + Vector2i(24, 10), 0)
			var c: Vector2i = h.cell
			var sm = put(game, "smelter", c + Vector2i(h.size, 0), 0)
			f.fz.fuse_combo(h, sm)
			var m1 = put_near(game, "furnace", c + Vector2i(0, 6), 0)
			var m2 = put(game, "furnace", m1.cell + Vector2i(m1.size, 0), 0)
			var lv_ok: bool = m2 != null and f.fz.fuse_level(m1, m2)
			var bp: Dictionary = game.blueprints.copy_rect(c + Vector2i(-1, -1), c + Vector2i(10, 12))
			print("HUNT src: host subs=", h.subs.size(), " miner lvl=", m1.lvl, " fused=", lv_ok)
			print("HUNT blueprint items=", bp.items)
			var n: int = game.blueprints.paste(bp, c + Vector2i(30, 0), 0)
			var nh = null
			var nm = null
			for b in f.all:
				if b.type == "assembler" and b != h: nh = b
				if b.type == "furnace" and b != m1: nm = b
			print("HUNT pasted n=", n, " assembler subs=", nh.subs.size() if nh else -1, " miner lvl=", nm.lvl if nm else -1)
			print("TEST duelA_bp115 done")
		"duelA_thief_r4":
			# Вор утаскивает изношенную кирку; убили вора — выпадает новая?
			var pl = game.player
			for i in pl.inv.slots.size():
				pl.inv.slots[i] = null
			pl.selected = 0
			pl.inv.slots[5] = {"id": "iron_pickaxe", "n": 1, "dur": 3.0}
			var e = game.enemies.spawn("thief", pl.position + Vector3(3, 0, 3))
			game.enemies._steal(e, pl)
			print("HUNT stolen=", e.stolen, " player has=", pl.inv.count("iron_pickaxe"))
			game.enemies._kill(e)
			var dd = null
			for d in game.drops.list:
				if d.id == "iron_pickaxe":
					dd = d
			if dd != null:
				game.drops.take(dd)
			var left: int = pl.inv.add("iron_pickaxe", 1) if dd == null else (pl.inv.add(dd.id, dd.n) if dd.slot.is_empty() else pl.inv.add_slot(dd.slot))
			var dur = null
			for s in pl.inv.slots:
				if s != null and s.id == "iron_pickaxe":
					dur = s.get("dur", "нет (= новая, %d)" % int(DB.item("iron_pickaxe").get("durability", 0)))
			print("HUNT drop found=", dd != null, " picked dur=", dur)
			print("TEST duelA_thief115 ", "FAIL(bug: worn tool returns new)" if dd != null and not (dur is float and dur <= 3.0) else "OK")
		"duelA_qfuse_r4":
			# Две запутанные шкатулки ОДНОЙ пары вплотную → «Объединение 2»
			var f = game.factory
			game.flags["free_build"] = true
			var c: Vector2i = f.hq.cell + Vector2i(20, 12)
			for dx in range(-3, 6):
				for dz in range(-3, 6):
					game.world.remove_node(World.wc(c + Vector2i(dx, dz)))
			var a = game.cmd("place", {"type": "entangled_chest", "cell": c, "dir": 0})
			var b = game.cmd("place", {"type": "entangled_chest", "cell": c + Vector2i(1, 0), "dir": 0})
			print("HUNT pair a=", a.cfg.get("qpair"), " b=", b.cfg.get("qpair"), " shared=", a.inv == b.inv)
			a.inv.add("iron_ingot", 120)
			a.inv.add("copper_ingot", 40)
			var before: int = a.inv.count("iron_ingot") + a.inv.count("copper_ingot")
			var pinv0: int = game.player.inv.count("iron_ingot") + game.player.inv.count("copper_ingot")
			var hq0: int = f.hq.inv.count("iron_ingot") + f.hq.inv.count("copper_ingot")
			print("HUNT why=", f.fz.level_why(a, b))
			var ok: bool = f.fz.fuse_level(a, b)
			var after: int = a.inv.count("iron_ingot") + a.inv.count("copper_ingot")
			var pinv1: int = game.player.inv.count("iron_ingot") + game.player.inv.count("copper_ingot")
			var hq1: int = f.hq.inv.count("iron_ingot") + f.hq.inv.count("copper_ingot")
			var drops := 0
			for d in game.drops.list:
				if d.id in ["iron_ingot", "copper_ingot"]:
					drops += int(d.n)
			print("HUNT fused=", ok, " lvl=", a.lvl, " items before=", before, " after(in chest)=", after, " +player=", pinv1 - pinv0, " +hq=", hq1 - hq0, " drops=", drops, " partner=", game.quantum.partner(a))
			print("TEST duelA_qfuse115 ", "FAIL" if ok and after + (pinv1 - pinv0) + (hq1 - hq0) + drops != before else "OK")
		"duelA_kit_r4":
			var f = game.factory
			game.flags["free_build"] = true
			var kb = put_near(game, "kitchen", f.hq.cell + Vector2i(8, 8), 0)
			var sb = put_near(game, "sink_shop", kb.cell + Vector2i(3, 0), 0)
			game.player.position = kb.center() + Vector3(1.5, 0, 1.5)
			print("HUNT near=", game.near_stations())
			for st in ["kitchen", "sink_shop"]:
				game.hud.station = st
				game.hud.open("craft")
				await tree.process_frame
				await tree.process_frame
				var w = game.hud.windows.craft
				var tabs := []
				for bt in w.body.get_child(0).get_children():
					if bt is Button:
						tabs.append(bt.text)
				print("HUNT station=", st, " title='", w.title_lbl.text, "' tabs=", tabs)
				game.hud.close_all()
			print("TEST duelA_kit115 done")
		"duelA_blk_r4":
			# Блочные здания (утилизатор, маяк ускорения) при ползунке мощности 5%
			var f = game.factory
			game.flags["free_build"] = true
			var c: Vector2i = f.hq.cell + Vector2i(30, 20)
			var res := {}
			for clk in [100.0, 5.0]:
				var sk = put_near(game, "sink", c, 0)
				var bb = put_near(game, "boost_beacon", c + Vector2i(6, 0), 0)
				var g1 = put_near(game, "generator", c + Vector2i(0, 6), 0)
				g1.fuel.add("coal", 40)
				f.add_wire(g1, sk)
				f.add_wire(g1, bb)
				for b in [sk, bb]:
					var nc: Dictionary = b.cfg.duplicate(true)
					nc["clock"] = clk
					game.cmd("bcfg", {"b": b, "cfg": nc})
				f._rebuild_power()
				sk.inv.add("iron_ingot", 300)
				var n0: int = sk.inv.count("iron_ingot")
				game.player.position = bb.center()
				for k in 8:
					f._power(0.25)
					Blocks.update(f, sk, 0.25)
					Blocks.update(f, bb, 0.25)
				var burned: int = n0 - sk.inv.count("iron_ingot")
				var ni: Dictionary = f.net_info(sk)
				res[clk] = [burned, ni.get("demand"), game.effects.has("move")]
				print("HUNT clock=", clk, "% sink burned in 2s=", burned, " net demand=", ni.get("demand"), " sat_c=", f.sat_c(sk), " move buff=", game.effects.get("move", {}).get("value", 0.0), " pts=", sk.bstate.get("pts"))
				game.effects.clear()
				for b in [sk, bb, g1]:
					f.remove(b)
				c += Vector2i(0, 16)
			print("TEST duelA_blk115 ", "FAIL(bug: 5% clock = full throughput)" if res[5.0][0] == res[100.0][0] else "OK")
		"duelA_en2_r4":
			var tip: String = UI.item_tip("log")
			print("HUNT tip_en=", TranslationServer.translate(tip).replace("\n", " | "))
			for s in ["\nСтопка: до 50 шт.", "Стопка: до 50 шт.", "\nЦена на станции: ~2 кр", "Цена на станции: ~2 кр", "Бревно 0/10", "Бревно", "Have: 0 в инвентаре"]:
				print("HUNT tr[", s.replace("\n", "\\n"), "] = ", TranslationServer.translate(s).replace("\n", "\\n"))
			var d: Dictionary = DB.data.lang.en
			var nl := 0
			for k in d:
				if str(k).begins_with("\n") or str(k).begins_with(" "):
					nl += 1
			print("HUNT keys starting with newline/space: ", nl, " of ", d.size())
			var ex := str(DB.building("pole").get("explain", ""))
			print("HUNT explain alone = ", TranslationServer.translate(ex).substr(0, 80))
			print("HUNT explain in window = ", TranslationServer.translate("[color=#9fd8ff]Как это работает:[/color] " + ex).substr(0, 120))
			var np := "Нет энергии: протяните провод от опоры или генератора (клавиша V)"
			print("HUNT nopower alone = ", TranslationServer.translate(np))
			print("HUNT nopower colored = ", TranslationServer.translate("[color=#ff6b5a]%s[/color]" % np))
			print("TEST duelA_en2115 done")
		"duelA_en_r4":
			# Английский: открыть все окна и окна всех зданий, собрать показанные тексты с кириллицей
			var f = game.factory
			game.flags["free_build"] = true
			var rx := RegEx.create_from_string("[А-Яа-яЁё]")
			var seen := {}
			var out := []
			var scan := func(where: String, root: Node):
				for n in root.find_children("*", "", true, false):
					if not (n is Control) or not n.is_visible_in_tree():
						continue
					var txts := []
					if n is Label or n is Button or n is LineEdit:
						txts.append(n.text)
					elif n is RichTextLabel:
						txts.append(n.text)
					if n.tooltip_text != "":
						txts.append(n.tooltip_text)
					if n is OptionButton:
						for i in n.item_count:
							txts.append(n.get_item_text(i))
					for t in txts:
						var s := str(t)
						if s == "":
							continue
						var tt: String = TranslationServer.translate(s) if n.auto_translate_mode != Node.AUTO_TRANSLATE_MODE_DISABLED else s
						if rx.search(tt) != null and not seen.has(tt):
							seen[tt] = true
							out.append(where + "\t" + tt.replace("\n", "\\n"))
			print("HUNT lang=", Lang.current())
			for id in game.hud.windows.keys():
				if id in ["building"] or OS.get_environment("DUEL_SKIPWIN") != "":
					continue
				game.hud.open(id)
				await tree.process_frame
				await tree.process_frame
				await tree.process_frame
				scan.call("win:" + id, game.hud.windows[id])
				game.hud.close_all()
			var c: Vector2i = f.hq.cell + Vector2i(30, 30)
			var types: Array = DB.data.buildings.keys()
			var k := 0
			for t in types:
				if not bool(DB.data.buildings[t].get("params", {}).get("buildable", true)):
					continue
				var b = put_near(game, t, c + Vector2i((k % 8) * 7, (k / 8) * 7), 0)
				k += 1
				if b == null:
					continue
				game.player.position = b.center() + Vector3(2, 0, 2)
				game.hud.open_building(b)
				await tree.process_frame
				await tree.process_frame
				if k < 3:
					print("HUNT bld ", t, " vis=", game.hud.windows.building.visible, " intree=", game.hud.windows.building.is_visible_in_tree(), " kids=", game.hud.windows.building.find_children("*", "Label", true, false).size())
				scan.call("bld:" + t, game.hud.windows.building)
				game.hud.close_all()
			var fa := FileAccess.open("user://duelA_en.txt", FileAccess.WRITE)
			for l in out:
				fa.store_line(l)
			fa.close()
			print("HUNT untranslated shown=", out.size(), " file=", ProjectSettings.globalize_path("user://duelA_en.txt"))
			print("TEST duelA_en115 ", "FAIL" if out.size() > 0 else "OK")
		"duelA_tut_r4":
			# Шаг «Энергия»: бур + станция + генератор БЕЗ топлива — шаг засчитан?
			var f = game.factory
			game.flags["free_build"] = true
			var T = game.tutorial
			var si := -1
			var ss: Array = Tutorial.steps()
			for i in ss.size():
				if str(ss[i].get("goal", "")) == "powered":
					si = i
			T.step = si
			var c: Vector2i = f.hq.cell + Vector2i(40, 25)
			var ore := nearest_deposit(game, "iron_ore", c)
			var mi = put(game, "miner", ore, 0)
			var gen = put_near(game, "generator", ore + Vector2i(5, 0), 0)
			var po = put_near(game, "pole", ore + Vector2i(2, 2), 0)
			print("HUNT placed mi=", mi, " gen=", gen, " po=", po, " w1=", f.wire_why(gen, po), " w2=", f.wire_why(po, mi))
			f.add_wire(gen, po)
			f.add_wire(po, mi)
			f._rebuild_power()
			for k in 20:
				f._power(0.1)
				f._miner(mi, 0.1)
			var ni: Dictionary = f.net_info(mi)
			print("HUNT step=", si, " stations=", f.stations_mode(), " miner net=", mi.net, " feeder=", mi.feeder != null, " supply=", ni.get("supply"), " gen_max=", ni.get("gen_max"), " sat=", ni.get("sat"), " gen fuel=", gen.fuel.first_item() if gen.fuel else "?", " miner active=", mi.active, " fuel_t=", gen.fuel_t)
			print("HUNT progress=", T.progress(), " goal='", T.goal_text(), "'")
			print("TEST duelA_tut115 ", "FAIL(bug: step done without fuel)" if T.progress()[0] >= 1 and float(ni.get("supply", 0)) <= 0.0 else "OK")
		"duelA_off_r4":
			# Составное (сборщик + плавильня + генератор): «Выключить» у основы — встроенная плавильня работает?
			var f = game.factory
			game.flags["free_build"] = true
			var c: Vector2i = f.hq.cell + Vector2i(30, 20)
			for dx in range(-4, 14):
				for dz in range(-4, 14):
					game.world.remove_node(World.wc(c + Vector2i(dx, dz)))
			var h = put_near(game, "assembler", c, 0)
			c = h.cell
			var sm = put(game, "smelter", c + Vector2i(h.size, 0), 0)
			print("HUNT placed ", h, " ", sm)
			var g = put(game, "generator", c + Vector2i(0, h.size), 0)
			print("HUNT why1=", f.fz.combo_why(h, sm))
			f.fz.fuse_combo(h, sm)
			print("HUNT why2=", f.fz.combo_why(h, g))
			f.fz.fuse_combo(h, g)
			var ssm = null
			var sg = null
			for s in h.subs:
				if s.type == "smelter": ssm = s
				if s.type == "generator": sg = s
			if sg.fuel != null:
				sg.fuel.add("coal", 30)
			f.set_recipe(ssm, "smelt_iron")
			ssm.inv.add("iron_ore", 40)
			if OS.get_environment("DUEL_HALT") != "":
				h.ev_halt = true   # как events._hazards при солнечном выбросе (stop_machines)
				print("HUNT mode: ev_halt on host")
			else:
				var nc: Dictionary = h.cfg.duplicate(true)
				nc["off"] = true
				game.cmd("bcfg", {"b": h, "cfg": nc})
			f._rebuild_power()
			for k in 300:
				f._power(0.1)
				f.fz.tick_power(0.1)
				f.fz.tick_subs(0.1)
			var made: int = ssm.out.count("iron_ingot") if ssm.out != null else -1
			print("HUNT host off=", h.cfg.get("off", false), " clock(host)=", Factory.clock(h), " need=", f.fz._need(h), " csat=", h.csat, " sub ingots after 30s=", made, " ore left=", ssm.inv.count("iron_ore"), " gen fuel left=", sg.fuel.count("coal") if sg.fuel else -1)
			print("TEST duelA_off115 ", "FAIL(bug: off composite still works)" if made > 0 else "OK")
		"duelA_def_r4":
			# Барьер-основа составного (барьер + ящик) — без сети/генератора: работает ли щит?
			var f = game.factory
			game.flags["free_build"] = true
			var c: Vector2i = f.hq.cell + Vector2i(30, 20)
			for dx in range(-4, 12):
				for dz in range(-4, 12):
					game.world.remove_node(World.wc(c + Vector2i(dx, dz)))
			var br = put(game, "barrier_small", c, 0)
			var ch = put(game, "chest", c + Vector2i(br.size, 0), 0)
			var br2 = put(game, "barrier_small", c + Vector2i(0, 6), 0)
			print("HUNT why=", f.fz.combo_why(br, ch), " host_role=", Fusion.role(br))
			f.fz.fuse_combo(br, ch)
			f._rebuild_power()
			for k in 30:
				f._power(0.1)
				f.fz.tick_power(0.1)
				game.defense.update(0.1)
			print("HUNT barrier+chest net=", br.net, " subs=", br.subs.size(), " csat=", br.csat, " cneed=", br.cneed, " active=", game.defense._active(br), " hp=", game.defense.state(br).hp)
			print("HUNT plain barrier net=", br2.net, " active=", game.defense._active(br2))
			var dmg_left: float = game.defense.absorb(br.center(), 50.0)
			print("HUNT absorb 50 -> left ", dmg_left)
			print("TEST duelA_def115 ", "FAIL(bug: free shield)" if game.defense._active(br) and br.net < 0 else "OK")
		"curves":
			var c: Vector2i = game.factory.hq.cell + Vector2i(6, -6)
			belt_path(game, c, c + Vector2i(3, 0))
			belt_path(game, c + Vector2i(3, 0), c + Vector2i(3, 3))
			var k: int = game.factory.building_at(c + Vector2i(3, 0)).kind
			var k2: int = game.factory.building_at(c + Vector2i(2, 0)).kind
			print("TEST curves corner_kind=", k, " straight_kind=", k2, " ", "OK" if k != 0 and k2 == 0 else "FAIL")
		"noplace_player":
			var pc: Vector2i = World.world_to_cell(game.player.position)
			var why: String = game.factory.can_place("chest", pc)
			print("TEST noplace_player why='", why, "' ", "OK" if why != "" else "FAIL")
		"gather":
			# подходим к ближайшему дереву и бьём
			var best = null
			var bd := INF
			for cc in game.world.nodes:
				var n = game.world.nodes[cc]
				var rd: Dictionary = DB.data.resources[n.res]
				if rd.get("category", "") == "Деревья" and rd.get("drops", []).any(func(dr): return dr.get("item", "") == "log"):
					var d: float = World.dist(game.player.position, n.xf.origin)
					if d < bd:
						bd = d
						best = cc
			if best == null:
				print("TEST gather FAIL no trees")
				return
			game.player.position = World.cell_to_world(best) + Vector3(2.2, 0, 0)
			game.player.inv.add("stone_axe", 1)
			game.player.selected = game.player.inv.slots.find(game.player.inv.slots.filter(func(s): return s != null and s.id == "stone_axe")[0])
			for i in 40:
				game.player.swing_t = -1.0
				game.cmd("hit", {"cell": best})
				await tree.create_timer(0.5).timeout
				if not game.world.nodes.has(best) or game.world.nodes[best].res == "stump":
					break
			await tree.create_timer(2.0).timeout
			# брёвна в рюкзаке или ещё лежат на земле (могли разлететься дальше радиуса подбора)
			var logs: int = game.player.inv.count("log")
			for dd in game.drops.list:
				if dd.id == "log":
					logs += dd.n
			var stump: bool = game.world.nodes.has(best) and game.world.nodes[best].res == "stump"
			print("TEST gather logs=", logs, " branch=", game.player.inv.count("branch"), " stump=", stump, " ", "OK" if logs > 0 else "FAIL")
		"craft":
			game.player.inv.add("branch", 6)
			game.player.inv.add("stone", 6)
			game.player.inv.add("fiber", 4)
			game.cmd("craft", {"rid": "stone_axe", "n": 1, "station": "hand"})
			await tree.create_timer(3.33).timeout
			print("TEST craft axe=", game.player.inv.count("stone_axe"), " ", "OK" if game.player.inv.count("stone_axe") > 0 else "FAIL")
		"power":
			var hq: Vector2i = game.factory.hq.cell
			var ore := nearest_deposit(game, "iron_ore", hq)
			var m = put(game, "miner", ore, 0)
			var gen = null
			for off in [Vector2i(0, 2), Vector2i(0, -2), Vector2i(2, 0), Vector2i(-2, 0), Vector2i(2, 2), Vector2i(-2, -2)]:
				gen = put(game, "generator", ore + off, 0)
				if gen:
					break
			if gen:
				gen.fuel.add("coal", 10)
			await tree.create_timer(6.0).timeout
			var produced: int = m.out.count("iron_ore") if m else -1
			print("TEST power miner_net=", m.net if m else -9, " ore=", produced, " ", "OK" if produced > 0 else "FAIL")
		"console":
			game.console.run("give iron_ingot 7")
			game.console.run("money 500")
			var ok: bool = game.player.inv.count("iron_ingot") >= 7 and game.credits >= 500
			print("TEST console ", "OK" if ok else "FAIL")
		"wrap":
			var w: float = game.world.W * World.C
			# ряд без воды у края карты; деревья и камни на пути убираем
			var zc: int = game.world.W / 2
			for tries in 60:
				var ok_row := true
				for x in [0, 1, game.world.W - 1, game.world.W - 2, game.world.W - 3]:
					if game.world.water_at(Vector2i(x, zc)):
						ok_row = false
				if ok_row:
					break
				zc += 3
			for x in [0, 1, 2, game.world.W - 1, game.world.W - 2, game.world.W - 3, game.world.W - 4]:
				for dz in [-1, 0, 1]:
					game.world.remove_node(World.wc(Vector2i(x, zc + dz)))
			game.player.position = Vector3(1.0, 0, (zc + 0.5) * World.C)
			game.player.move_dir = Vector3(-9, 0, 0)
			for f in 30:
				Input.action_press("move_left")
				await tree.process_frame
			Input.action_release("move_left")
			var x: float = game.player.position.x
			print("TEST wrap x=", x, " ", "OK" if x > w * 0.5 else "FAIL")
		"death":
			game.player.inv.add("iron_ingot", 12)
			var before: int = game.player.inv.count("iron_ingot")
			var where: Vector3 = game.player.position + Vector3(20, 0, 0)
			game.player.position = where
			game.console.run("kill")
			var dead_ok: bool = game.graves.size() == 1 and game.player.inv.is_empty()
			await tree.create_timer(float(DB.data.settings.death.get("respawn_time", 6)) + 1.0).timeout
			var at_hq: bool = World.dist(game.player.position, game.factory.hq.center()) < 12.0 and game.player.alive
			for k in 10:
				if game.graves.is_empty():
					break
				game.player.position = game.graves[0].pos
				await tree.create_timer(0.2).timeout
			var back: int = game.player.inv.count("iron_ingot")
			print("TEST death chest=", dead_ok, " respawn_hq=", at_hq, " got_back=", back, "/", before, " graves_left=", game.graves.size(), " ", "OK" if dead_ok and at_hq and back == before and game.graves.is_empty() else "FAIL")
		"jump":
			game.player.jump()
			var top := 0.0
			for i in 30:
				await tree.create_timer(0.02).timeout
				top = max(top, game.player.jump_y)
				if OS.get_cmdline_user_args().has("--dbg"):
					print("dbg jy=", game.player.jump_y, " vy=", game.player.vel_y, " air=", game.player.airborne, " pre=", game.player._pre_t)
			await tree.create_timer(0.5).timeout
			print("TEST jump top=", snappedf(top, 0.01), " landed=", game.player.jump_y == 0.0, " ", "OK" if top > 0.8 and game.player.jump_y == 0.0 else "FAIL")
		"pack":
			game.player.position = game.factory.hq.center() + Vector3(60, 0, 0)
			game.player.hp = 99999.0
			game.player.maxhp = 99999.0
			var pk = game.enemies.spawn_pack(game.player.position + Vector3(14, 0, 0))
			var n0: int = pk.members.size() if pk else 0
			await tree.create_timer(2.0).timeout
			var aggro: bool = pk != null and pk.aggro
			var hp0: float = game.player.hp
			await tree.create_timer(4.0).timeout
			var hurt: bool = game.player.hp < hp0
			game.console.run("killall")
			await tree.create_timer(0.3).timeout
			print("TEST pack members=", n0, " aggro=", aggro, " hurt_player=", hurt, " packs_left=", game.enemies.packs.size(), " drops=", game.drops.list.size() if "list" in game.drops else -1, " ", "OK" if n0 >= 3 and aggro and hurt and game.enemies.packs.is_empty() else "FAIL")
		"roam_spawn":
			DB.data.waves.roaming.first_delay = 0.5
			game.enemies.roam_timer = 0.5
			await tree.create_timer(1.5).timeout
			print("TEST roam_spawn packs=", game.enemies.packs.size(), " monsters=", game.enemies.roaming_count(), " ", "OK" if game.enemies.packs.size() >= 1 else "FAIL")
		"attrs":
			game.add_xp(500)
			var pts: int = game.attr_points
			var mv0: float = game.bonus("move")
			game.upgrade_attr("agility")
			game.upgrade_attr("agility")
			print("TEST attrs level=", game.level, " points=", pts, " move_bonus ", mv0, "->", game.bonus("move"), " ", "OK" if pts >= 2 and game.bonus("move") > mv0 else "FAIL")
		"droprate":
			var hits := {}
			var ore := nearest_deposit(game, "iron_ore", game.factory.hq.cell)
			for i in 3000:
				for d in game.factory._deposit_drops("iron_ore"):
					if randf() < float(d.chance):
						hits[d.item] = hits.get(d.item, 0) + 1
			var hq_n: int = hits.get("iron_ore_hq", 0)
			print("TEST droprate iron_ore_hq per 3000 = ", hq_n, " ", "OK" if hq_n > 10 and hq_n < 60 else "FAIL")
		"unstuck":
			# здание появилось прямо на герое (например, после загрузки) — героя выталкивает
			var pc: Vector2i = World.world_to_cell(game.player.position)
			game.factory.place("wall", pc, 0)
			await tree.create_timer(0.6).timeout
			var now: Vector2i = World.world_to_cell(game.player.position)
			print("TEST unstuck from=", pc, " to=", now, " ", "OK" if now != pc and not game.player._cell_blocked(now) else "FAIL")
		"take_put":
			var hq: Vector2i = game.factory.hq.cell
			var ch = put(game, "chest", hq + Vector2i(5, 0), 0)
			ch.inv.add("iron_ingot", 9)
			game.cmd("take", {"b": ch})
			var took: int = game.player.inv.count("iron_ingot")
			game.cmd("put_all", {"b": ch})
			var back: int = ch.inv.count("iron_ingot")
			print("TEST take_put took=", took, " put_back=", back, " ", "OK" if took == 9 and back == 9 else "FAIL")
		"console16":
			# 1.6: команды разработчика только после ключа
			var con = game.console
			var was = Prefs.get_value("dev_console", false)
			Prefs.set_value("dev_console", false)
			con.test_locked = true
			var g0: bool = game.player.god
			con._submit("god")
			var blocked: bool = game.player.god == g0
			con._submit("aloverdoz1135852x")
			var still: bool = not con.unlocked()
			con._submit("aloverdoz1135852")
			var opened: bool = con.unlocked()
			con._submit("god")
			var works: bool = game.player.god != g0
			var hidden: bool = not con.history.has("aloverdoz1135852")
			con.test_locked = false
			Prefs.set_value("dev_console", was)
			print("TEST console16 blocked=", blocked, " wrong_key=", still, " opened=", opened, " works=", works, " not_in_history=", hidden, " ",
				"OK" if blocked and still and opened and works and hidden else "FAIL")
		"tut15":
			# 1.5: обучение и задания по порядку — всё, что просит шаг, существует и открыто к этому шагу
			var tc = game.tech
			var opened := {}
			for id in tc.nodes():
				if bool(tc.nodes()[id].get("start", false)):
					opened[id] = true
			var built := {"hand": true}
			var bad: Array = []
			for st in game.tutorial.steps():
				var g := str(st.get("goal", ""))
				if g == "tech":
					var t := str(st.get("tech", ""))
					if not tc.nodes().has(t):
						bad.append("tech:" + t)
					opened[t] = true
				elif g == "build":
					var b := str(st.get("building", ""))
					var by := ""
					for id in opened:
						if b in tc.nodes()[id].get("unlocks", {}).get("buildings", []):
							by = id
					if DB.building(b).is_empty() or by == "":
						bad.append("build:" + b)
					built[str(DB.bparam(b, "station", b))] = true
				elif g == "have":
					var it := str(st.get("item", ""))
					var ok_it: bool = DB.data.items.has(it)
					var made := false
					for r in DB.data.recipes:
						if DB.data.recipes[r].get("out", {}).has(it):
							for stn in DB.data.recipes[r].get("stations", []):
								if built.has(str(stn)):
									made = true
					if not ok_it or not (made or it in ["branch", "fiber", "stone", "log", "iron_ore", "coal"]):
						bad.append("have:" + it)
			# задание «открыть узел» засчитывается только за свой узел
			tc.done.clear()
			var q := {"goal": "tech", "n": 1, "item": "t_workshop"}
			var q0: Array = game.quest_progress(q)
			tc.done["t_mining"] = true
			var q1: Array = game.quest_progress(q)
			tc.done["t_workshop"] = true
			var q2: Array = game.quest_progress(q)
			var qok: bool = q0[0] == 0 and q1[0] == 0 and q2[0] == 1
			var orders := {}
			for k in DB.data.quests:
				orders[int(DB.data.quests[k].get("order", 0))] = orders.get(int(DB.data.quests[k].get("order", 0)), 0) + 1
			var dup: Array = orders.keys().filter(func(o): return orders[o] > 1 and o < 30)
			print("TEST tut15 steps=", game.tutorial.steps().size(), " bad=", bad, " quest_tech=", qok, " dup_order=", dup, " ", "OK" if bad.is_empty() and qok and dup.is_empty() else "FAIL")
		"pace15":
			# 1.5: темп угрозы по прогрессу, мирная сложность, цена участков тумана, стартовые залежи
			var en = game.enemies
			var tc = game.tech
			tc.done.clear()
			en._pace_t = -1.0
			var p0: Dictionary = en.pace()
			en.wave = 10
			var ew0: int = en.eff_wave()
			var boss0: bool = en.bosses_allowed()
			var iv: float = float(DB.data.waves.get("interval", 900))
			en.wave = 0
			en.start_wave()
			var t0: float = en.wave_timer
			var cnt0: int = en.wave_live
			for e in en.list.duplicate():
				en.vanish(e)
			# открыть первые два этапа целиком
			for id in tc.nodes():
				if int(tc.nodes()[id].get("tier", 0)) in [1, 2]:
					tc.done[id] = true
			en._pace_t = -1.0
			var p2: Dictionary = en.pace()
			var boss2: bool = en.bosses_allowed()
			en.wave = 10
			var ew2: int = en.eff_wave()
			var pace_ok: bool = absf(float(p0.progress)) < 0.01 and ew0 == 2 and not boss0 and absf(t0 - iv * 2.0) < 1.0 and cnt0 <= 2 \
				and absf(float(p2.progress) - 2.0) < 0.01 and boss2 and ew2 == 7
			game.difficulty = 0.25
			var calm: bool = not en.waves_on() and not game.sieges.enabled()
			game.difficulty = 1.0
			# участки тумана: каждые 3 открытых — следующий шаг цены
			var zn = game.zone
			var rc0: Array = zn.rects.duplicate()
			zn.rects = []
			var c_a: Dictionary = zn.patch_cost()
			zn.rects = [Vector2i(90, 90), Vector2i(91, 90), Vector2i(92, 90)]
			var c_b: Dictionary = zn.patch_cost()
			zn.rects = rc0
			var zone_ok: bool = c_a.keys() != c_b.keys()
			# стартовые залежи: каждая «near_start» есть рядом со штабом
			var w = game.world
			var miss := []
			for di in w.deposits.size():
				var dd: Dictionary = w.deposits[di]
				if int(dd.get("near_start", 0)) <= 0:
					continue
				var found := false
				for c in w.deposit:
					if int(w.deposit[c]) == di and Vector2(c - w.center).length() <= 26.0:
						found = true
						break
				if not found:
					miss.append(str(dd.get("item", di)))
			print("TEST pace15 p0=", snappedf(float(p0.progress), 0.01), " ew0=", ew0, " boss0=", boss0, " first_iv=", t0, " count0=", cnt0, " p2=", snappedf(float(p2.progress), 0.01),
				" boss2=", boss2, " ew2=", ew2, " calm=", calm, " zone_cost=", c_a, "->", c_b, " start_missing=", miss, " ",
				"OK" if pace_ok and calm and zone_ok and miss.is_empty() else "FAIL")
		"furnace15":
			# 1.5: печь — брёвна только сгорают (не появляются сами); перетаскивание из печи и Shift-клик идут командой
			var pl = game.player
			var hq: Vector2i = game.factory.hq.cell
			var fu = put(game, "furnace", hq + Vector2i(6, 2), 0)
			pl.inv.remove("log", pl.inv.count("log"))
			pl.inv.add("log", 50)
			pl.inv.add("iron_ore", 10)
			pl.position = fu.center() + Vector3(3, 0, 0)
			game.cmd("put_all", {"b": fu})
			var logs := func() -> int:
				var n: int = pl.inv.count("log")
				for k in ["inv", "out", "fuel"]:
					var iv = fu.get(k)
					if iv != null:
						n += iv.count("log")
				return n
			var l0: int = logs.call()
			var mx := l0
			for i in 20:
				await tree.create_timer(0.5).timeout
				mx = maxi(mx, logs.call())
			var l1: int = logs.call()
			game.hud.open_building(fu)
			var drag_ok := true
			var src: Inventory = fu.fuel if fu.fuel != null and not fu.fuel.is_empty() else fu.inv
			var si := -1
			for i in src.size():
				if src.slots[i] != null:
					si = i
					break
			var free_i := -1
			for i in range(pl.inv.size() - 1, 9, -1):
				if pl.inv.slots[i] == null:
					free_i = i
					break
			if si >= 0 and free_i >= 0:
				var moved_id: String = src.slots[si].id
				var n_before: int = src.count(moved_id) + pl.inv.count(moved_id)
				game.hud.move_slot(src, si, pl.inv, free_i)
				drag_ok = pl.inv.slots[free_i] != null and src.count(moved_id) + pl.inv.count(moved_id) == n_before
				game.hud.move_slot(pl.inv, free_i, src, si)
				drag_ok = drag_ok and pl.inv.slots[free_i] == null and src.count(moved_id) + pl.inv.count(moved_id) == n_before
			game.hud.close_all() if game.hud.has_method("close_all") else null
			print("TEST furnace15 logs_start=", l0, " max=", mx, " end=", l1, " drag=", drag_ok, " ", "OK" if mx <= l0 and l1 <= l0 and l0 == 50 and drag_ok else "FAIL")
		"craft_queue":
			game.player.inv.add("branch", 20)
			game.player.inv.add("stone", 20)
			game.player.inv.add("fiber", 20)
			game.cmd("craft", {"rid": "stone_axe", "n": 3, "station": "hand"})
			var q0: int = game.craft_queue.size()
			await tree.create_timer(0.5).timeout
			var t_mid: float = game.craft_queue[0].t if not game.craft_queue.is_empty() else -1.0
			await tree.create_timer(12.0).timeout
			var axes: int = game.player.inv.count("stone_axe")
			print("TEST craft_queue queued=", q0, " progress=", snappedf(t_mid, 0.01), " made=", axes, " ", "OK" if q0 == 3 and t_mid > 0.0 and axes >= 3 else "FAIL")
		"power_partial":
			var hq: Vector2i = game.factory.hq.cell
			var ore := nearest_deposit(game, "iron_ore", hq)
			var m = put(game, "miner", ore, 0)
			# медный бур — подальше от штаба и солнечной панели, чтобы остался без энергии
			var m2 = put(game, "miner", nearest_deposit(game, "copper_ore", hq, [hq, ore], 16.0), 0)
			var gen = null
			for off in [Vector2i(0, 2), Vector2i(0, -2), Vector2i(2, 0), Vector2i(-2, 0), Vector2i(2, 2), Vector2i(-2, -2)]:
				gen = put(game, "solar", ore + off, 0)
				if gen:
					break
			await tree.create_timer(1.0).timeout
			var info: Dictionary = game.factory.net_info(m) if m else {}
			var sat: float = float(info.get("sat", -1.0))
			var off_sat: float = game.factory._sat(m2) if m2 else -1.0
			print("TEST power_partial sat=", snappedf(sat, 0.01), " supply=", info.get("supply", 0), " demand=", info.get("demand", 0), " unpowered=", off_sat, " ", "OK" if off_sat == 0.0 and sat >= 0.0 else "FAIL")
		"menus":
			game.save_game("save7", true)
			var meta_ok := FileAccess.file_exists(DB.saves_dir().path_join("save7.meta.json"))
			var newest_ok := SavesUI.newest() == "save7"
			var info: Dictionary = SavesUI.info("save7")
			SavesUI.delete("save7")
			var del_ok := not SavesUI.exists("save7") and not FileAccess.file_exists(DB.saves_dir().path_join("save7.meta.json"))
			var old_lang = Prefs.get_value("language", "ru")
			Prefs.values["language"] = "en"
			var en_ok := DB.t("@m_new") == "New game" and DB.tx("st_kills") == "Monsters killed"
			Prefs.values["language"] = "ru"
			var ru_ok := DB.t("@m_new") == "Новая игра" and DB.t("простой текст") == "простой текст"
			Prefs.values["language"] = old_lang
			# условие победы: «продержаться до дня 1» срабатывает сразу
			DB.data.menu["victory"] = {"mode": "day", "value": 1}
			game._victory_t = 5.0
			game._check_victory(0.1)
			var win_ok: bool = game.victory and game.hud.end_win.visible
			# модули новой игры перекрывают правила
			game.ng_modules["survival"] = true
			var mod_ok: bool = game.module("survival")
			game.ng_modules.erase("survival")
			print("TEST menus meta=", meta_ok, " newest=", newest_ok, " day=", info.get("day", -1), " delete=", del_ok, " en=", en_ok, " ru=", ru_ok, " victory=", win_ok, " modules=", mod_ok, " ",
				"OK" if meta_ok and newest_ok and del_ok and en_ok and ru_ok and win_ok and mod_ok else "FAIL")
		"hero":
			var cols := {}
			for bp in game.player.body_parts:
				cols[str(bp[1])] = cols.get(str(bp[1]), 0) + 1
			print("TEST hero parts=", game.player.body_parts.size(), " colors=", cols, " prof=", game.profession, " ", "OK" if game.player.body_parts.size() >= 12 else "FAIL")
		"decor":
			var w = game.world
			var total := 0
			for k in w.decor_mm:
				total += w.decor_mm[k].multimesh.instance_count
			var zones := {}
			for i in 400:
				var c := Vector2i(randi() % w.W, randi() % w.W)
				var z: String = w.zone_at(c)
				zones[z] = zones.get(z, 0) + 1
			var bio := 0
			for c in w.nodes:
				if w.nodes[c].res in ["fallen_branch", "brushwood", "leaf_bush", "burdock"]:
					bio += 1
			print("TEST decor chunks=", w.decor_mm.size(), " instances=", total, " zones=", zones, " gatherables=", bio, " ", "OK" if total > 2000 and bio > 50 else "FAIL")
		"ui_items":
			# задачи из данных: 14 штук, прогресс «есть/нужно», выполнение даёт награду
			var nq: int = game.quests.size()
			game.quest_i = 0
			var q0: Dictionary = game.quests[0]
			game.player.inv.remove(q0.item, game.player.inv.count(q0.item))
			game.player.inv.add(q0.item, 3)
			var p0: Array = game.quest_progress(q0)
			var txt_ok: bool = "(3/%d)" % q0.n in game.quest_text()
			game.player.inv.add(q0.item, 10)
			var cr: int = game.credits
			game._quest_acc = 1.0
			game._check_quests()
			var done_ok: bool = game.quest_i == 1 and game.credits == cr + q0.reward
			# продажа берёт сначала со склада штаба, потом из рюкзака
			game.factory.hq.inv.remove("stone", game.factory.hq.inv.count("stone"))
			game.player.inv.remove("stone", game.player.inv.count("stone"))
			game.factory.hq.inv.add("stone", 2)
			game.player.inv.add("stone", 3)
			game.sell("stone", -1)
			var sell_ok: bool = game.factory.hq.inv.count("stone") == 0 and game.player.inv.count("stone") == 0
			# сообщение о нехватке называет предмет и сколько не хватает
			var miss: String = game.missing_text({"log": 5, "stone": 1}, func(_k): return 2)
			var miss_ok := "×3" in miss and "×1" not in miss
			# выбранный предмет подписан над панелью
			game.player.selected = 0
			game.player.inv.slots[0] = {"id": "log", "n": 7}
			var sel: String = game.hud._selected_text(game.player)
			var sel_ok := DB.item_name("log") in sel and "×7" in sel
			print("TEST ui_items quests=", nq, " progress=", p0, " text=", txt_ok, " done=", done_ok, " sell=", sell_ok, " missing='", miss, "' selected='", sel, "' ",
				"OK" if nq >= 10 and p0 == [3, q0.n] and txt_ok and done_ok and sell_ok and miss_ok and sel_ok else "FAIL")
		"aim":
			# автоцель: курсор рядом с деревом (не точно) — цель дерево; курсор далеко — ближайшее перед героем
			var pl = game.player
			for e in game.enemies.list.duplicate():
				game.enemies.list.erase(e)
			var pc := World.world_to_cell(pl.position)
			for dx in range(-4, 5):
				for dz in range(-4, 5):
					game.world.remove_node(World.wc(pc + Vector2i(dx, dz)))
			var tc := World.wc(pc + Vector2i(1, 0))
			game.world.add_node("tree_pine", tc)
			pl.selected = 0
			pl.inv.slots[0] = null
			var tp := World.cell_to_world(tc)
			game.hover_point = tp + Vector3(1.4, 0, 0.9)
			var t1: Dictionary = game.find_target()
			var near_ok: bool = not t1.is_empty() and t1.kind == "node" and t1.cell == tc
			pl.hips.rotation.y = 0.0
			game.hover_point = pl.position + Vector3(-25, 0, 0)
			var t2: Dictionary = game.find_target()
			var front_ok: bool = not t2.is_empty() and t2.kind == "node"
			var e = game.enemies.spawn("crawler", pl.position + Vector3(0, 0, 1.6))
			game.hover_point = e.pos + Vector3(0.8, 0, 0.5)
			var t3: Dictionary = game.find_target()
			var enemy_ok: bool = not t3.is_empty() and t3.kind == "enemy"
			# на бегу герой смотрит по ходу, а не на курсор
			pl.action_t = 0.0
			pl.move_dir = Vector3(0, 0, 9)
			pl.aim = pl.position + Vector3(0, 0, -20)
			for k in 20:
				pl._animate(0.05, false)
			var want_yaw := atan2(-9.0, 0.0)
			var face_ok: bool = absf(wrapf(pl.hips.rotation.y - pl._pel - want_yaw, -PI, PI)) < 0.1 and absf(pl.torso.rotation.y) < 0.35   # 1.3: плечи покачиваются навстречу тазу
			# карточка предмета по клику
			pl.inv.slots[1] = {"id": "log", "n": 5}
			game.hud.open("inventory")
			game.hud.show_item_info(pl.inv, 1)
			var info_ok: bool = game.hud.info_box.visible and game.hud.info_box.get_child_count() > 0
			print("TEST aim near=", near_ok, " front=", front_ok, " enemy=", enemy_ok, " face=", face_ok, " info=", info_ok, " ",
				"OK" if near_ok and front_ok and enemy_ok and face_ok and info_ok else "FAIL")
		"stations21":
			# 21: станции энергии: станция Mk1 отдаёт 20 зданиям в радиусе 3, ближним первыми; здание у другой станции не в счёт
			var f = game.factory
			DB.data.buildings["hq"]["params"]["power"] = 1000
			DB.data.buildings["smelter"]["params"]["power"] = 5   # как бур из примера: 5 энергии
			var hq: Vector2i = f.hq.cell
			var bridge = put(game, "pole", hq + Vector2i(7, 0), 0)
			var a0: Vector2i = hq + Vector2i(14, 0)
			var sa = put(game, "pole", a0, 0)
			var offs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(2, 0)]
			var ms := []
			for o in offs:
				ms.append(put(game, "smelter", a0 + o, 0))
			var m6 = put(game, "smelter", a0 + Vector2i(0, 3), 0)
			var sb = put(game, "pole", a0 + Vector2i(0, 4), 0)
			var placed: bool = bridge != null and sa != null and sb != null and m6 != null and not ms.has(null)
			if not placed:
				print("DBG ", bridge != null, sa != null, sb != null, m6 != null, ms.map(func(x): return x != null), " why=", f.can_place("miner", a0 + Vector2i(1, 0)), f.can_place("miner", a0 + Vector2i(0, 3)), f.can_place("smelter", a0 + Vector2i(1, 0)), " / ", f.can_place("pole", a0 + Vector2i(5, 5)))
			f._rebuild_power()
			f._power(0.1)
			var fed_a := 0
			for m in ms:
				if m != null and m.feeder == sa:
					fed_a += 1
			var short_ok: bool = placed and ms[4].pw_state == 2 and ms[4].net == -1 and f._sat(ms[4]) == 0.0
			var b_ok: bool = placed and m6.feeder == sb
			var sat_ok: bool = placed and f._sat(ms[0]) > 0.9
			var load_ok: bool = placed and int(sa.bstate.get("st_load", 0)) == 20 and int(sa.bstate.get("st_short", 0)) == 1
			# станция выше уровнем прямо поверх старой: мощности хватает всем пяти
			var up = f.upgrade_target("pole_mk2", sa.cell) if placed else null
			var sa2 = f.upgrade(up, "pole_mk2") if up != null else null
			f._rebuild_power()
			var all5 := 0
			for m in ms:
				if m != null and not m.dead and sa2 != null and m.feeder == sa2:
					all5 += 1
			var view_ok := false
			game.pview.on = true
			game.pview.update(1.0)
			view_ok = game.pview.mi.mesh != null
			game.pview.on = false
			print("TEST stations21 placed=", placed, " fed_a=", fed_a, " short=", short_ok, " other_station=", b_ok, " sat=", sat_ok, " load=", load_ok, " upgraded=", sa2 != null, " all5=", all5, " view=", view_ok, " ",
				"OK" if placed and fed_a == 4 and short_ok and b_ok and sat_ok and load_ok and sa2 != null and all5 == 5 and view_ok else "FAIL")
		"upgrade21":
			# 21: здание выше уровнем ставится поверх старого; встроенные в него здания остаются
			var f = game.factory
			var hq: Vector2i = f.hq.cell
			# ближайшее к штабу месторождение со свободными соседями
			var c0: Vector2i = hq
			var bestd := INF
			for dc in game.world.deposit:
				var dd: float = Vector2(dc - hq).length()
				if dd > 6 and dd < bestd and f.can_place("miner", dc) == "" and game.world.deposit.get(dc + Vector2i(1, 0)) == null and game.world.deposit.get(dc + Vector2i(0, 1)) == null:
					bestd = dd
					c0 = dc
			var m = put(game, "miner", c0, 0)
			var sm = put(game, "smelter", c0 + Vector2i(1, 0), 0)
			var ch = put(game, "chest", c0 + Vector2i(0, 1), 0)
			var fused: bool = m != null and sm != null and ch != null and f.fz.fuse_combo(m, sm) and f.fz.fuse_combo(m if not m.dead else sm, ch)
			var host = m if m != null and not m.dead else null
			var subs0 := []
			if host != null:
				for x in host.subs:
					subs0.append(x.type)
			var down = f.upgrade_target("miner", c0)
			var cross = f.upgrade_target("smelter_mk2", c0)
			var up = f.upgrade_target("miner_mk2", c0)
			var nb = f.upgrade(up, "miner_mk2") if up != null else null
			var subs1 := []
			if nb != null:
				for x in nb.subs:
					subs1.append(x.type)
			var kept: bool = nb != null and subs1.has("smelter") and subs1.has("chest") and nb in f.fz.hosts and f.building_at(c0) == nb
			# через команду игры (как кликом мыши)
			game.flags["free_build"] = true
			var up3 = game.cmd("place", {"type": "miner_mk3", "cell": c0, "dir": 0})
			var nb3 = f.building_at(c0)
			var cmd_ok: bool = nb3 != null and nb3.type == "miner_mk3" and nb3.subs.size() == subs1.size()
			print("TEST upgrade21 fused=", fused, " subs=", subs0, " down=", down == null, " cross=", cross == null, " up=", nb != null, " kept=", subs1, " ", kept, " cmd=", cmd_ok, " ",
				"OK" if fused and down == null and cross == null and kept and cmd_ok else "FAIL")
		"wires":
			# провода: опора сама цепляется к штабу, машина — к опоре; ручной провод; лимит разъёмов; пробки
			var f = game.factory
			var hq: Vector2i = f.hq.cell
			var p1 = put(game, "pole", hq + Vector2i(8, 1), 0)
			var auto_pole: bool = p1 != null and f.wired_to(p1, f.hq)
			var sms := []
			for k in 4:
				var sm = put(game, "smelter", hq + Vector2i(9 + (k % 2) * 2, -1 + (k / 2) * 4), 0)
				if sm:
					sms.append(sm)
			f._rebuild_power()
			# у опоры 4 разъёма: 1 к штабу и 3 машины; четвёртая машина цепляется к штабу
			var auto_cons: bool = sms.size() == 4 and sms.all(func(x): return x.net == f.hq.net and x.net >= 0) and f.wire_count(p1) == 4
			f.unwire(sms[0])
			f._rebuild_power()
			var cut_ok: bool = sms[0].net == -1
			# пятая машина: у опоры кончились разъёмы (1 к штабу + 3 машины после снятия первой)
			var full_why: String = f.wire_why(sms[0], p1)
			var manual_ok: bool = full_why == "" and game.cmd("wire", {"a": sms[0], "b": p1}) == true
			var extra = put(game, "smelter", hq + Vector2i(7, 4), 0)
			var limit_ok: bool = extra != null and f.wire_why(extra, p1) != ""
			var far = null
			for fo in [Vector2i(40, 0), Vector2i(-40, 0), Vector2i(0, 40), Vector2i(0, -40), Vector2i(36, 8), Vector2i(-36, -8)]:
				if far == null and f.can_place("pole", hq + fo) == "":
					far = put(game, "pole", hq + fo, 0)
			var far_ok: bool = far != null and f.wire_why(far, p1) != ""
			f._rebuild_power()
			# перегрузка: 4 плавильни по 8 > 20 от штаба — выбивает пробки (плавильня  берёт 4 — для проверки ставим 8)
			var p_sm = DB.data.buildings["smelter"].params.get("power", 4)
			DB.data.buildings["smelter"].params["power"] = 8
			for x in sms:
				x.want = true
			for k in 6:
				for x in sms:
					x.want = true
				f._power(0.5)
			var ni: Dictionary = f.net_info(sms[1])
			var trip_ok: bool = bool(ni.get("tripped", false)) and f._sat(sms[1]) == 0.0
			DB.data.buildings["smelter"].params["power"] = p_sm
			game.cmd("reset_net", {"b": p1})
			var reset_ok: bool = not f.nets[p1.net].tripped and not f.hq.tripped
			game.save_game("save8", true)
			var sd = DB.read_file(DB.saves_dir().path_join("save8.json"))
			var save_ok: bool = sd is Dictionary and sd.get("wires", []).size() == f.links.size() and f.links.size() >= 5
			# предпросмотр провода в руке
			game.ui_action("wire")
			game.wire_from = p1
			game.hover_point = p1.center() + Vector3(6, 0, 3)
			game._update_wire_preview()
			var prev_ok: bool = game.wiring and game.wire_line.visible and game.wire_line.mesh != null
			game.cancel_build()
			var wv: float = game.wind()
			print("TEST wires auto_pole=", auto_pole, " auto_cons=", auto_cons, " cut=", cut_ok, " manual=", manual_ok, " limit=", limit_ok, " far=", far_ok,
				" trip=", trip_ok, " reset=", reset_ok, " save=", save_ok, " preview=", prev_ok, " wind=", snappedf(wv, 0.01), " ",
				"OK" if auto_pole and auto_cons and cut_ok and manual_ok and limit_ok and far_ok and trip_ok and reset_ok and save_ok and prev_ok and wv >= 0.0 and wv <= 1.0 else "FAIL")
		"batch":
			# пакет правок: монстр отстаёт, вода по пояс, прыжок через руду, деление стопки, инвентарь со зданием, бур Mk2
			var pl = game.player
			var w = game.world
			var f = game.factory
			DB.data.settings["monster_chase_time"] = 0.6
			DB.data.settings["monster_calm_time"] = 5.0
			var e = game.enemies.spawn("crawler", pl.position + Vector3(6, 0, 0))
			e.target = pl
			await tree.create_timer(1.2).timeout
			var chase_ok: bool = e.target != pl and e.calm_t > 0.0
			# вода: ищем воду у берега
			var wc := Vector2i(-1, -1)
			for x in w.W:
				for z in w.W:
					var c := Vector2i(x, z)
					if w.water_at(c) and not w.water_at(c + Vector2i(0, 1)) and not w.nest_cells.has(c):
						wc = c
						break
				if wc.x >= 0:
					break
			pl.position = World.cell_to_world(wc)
			await tree.create_timer(0.8).timeout
			var wade_ok: bool = pl.in_water() and pl.position.y < f.support_at(pl.position) - 0.5
			var can_out: bool = not pl._blocked(World.cell_to_world(wc + Vector2i(0, 1)))
			# руда: без прыжка не пройти, в прыжке — можно
			var oc := Vector2i(-1, -1)
			for c in w.nodes:
				if str(w.nodes[c].res).begins_with("ore_"):
					oc = c
					break
			pl.position = World.cell_to_world(oc + Vector2i(-1, 0))
			pl.position.y = f.support_at(pl.position)
			pl.jump_y = 0.0
			var blk: bool = pl._blocked(World.cell_to_world(oc))
			# 1.3: в прыжке — ноги выше верха камня (hop_top), тогда клетка проходима
			var y0: float = pl.position.y
			pl.position.y = maxf(y0, pl.hop_top(oc)) + 0.1
			var jump_ok: bool = blk and not pl._blocked(World.cell_to_world(oc))
			pl.position.y = y0
			# деление стопки
			pl.inv.slots[14] = {"id": "stone", "n": 10}
			var split_ok: bool = game.hud.split_slot(pl.inv, 14, 3) and pl.inv.slots[14].n == 7 and pl.inv.count("stone") >= 10
			# окно ящика открывает и инвентарь, закрытие — закрывает оба
			game.flags["free_build"] = true
			var ch = put(game, "chest", f.hq.cell + Vector2i(-4, 4), 0)
			game.hud.open_building(ch)
			await tree.process_frame
			var inv_open: bool = game.hud.is_open("inventory")
			game.hud.close("building")
			var inv_ok: bool = inv_open and not game.hud.is_open("inventory")
			# бур Mk2: подробная модель с шестернями и шнеком
			var parts: Array = DB.data.models.miner_mk2.parts
			var shapes := {}
			for pt in parts:
				shapes[pt.get("shape", "box")] = true
			var gm: Mesh = ModelLib.unit_mesh("gear", 0.8, 16)
			var sm: Mesh = ModelLib.unit_mesh("screw", 0.3, 4)
			# этап 20: бур — готовая модель из Blender (меши), шестерни и шнек остаются фигурами для редактора
			var model_ok: bool = parts.size() >= 5 and shapes.has("mesh") and gm.get_surface_count() > 0 and sm.get_surface_count() > 0
			print("TEST batch chase=", chase_ok, " wade=", wade_ok, " out=", can_out, " jump=", jump_ok, " split=", split_ok, " inv=", inv_ok, " model=", model_ok, " parts=", parts.size(), " ",
				"OK" if chase_ok and wade_ok and can_out and jump_ok and split_ok and inv_ok and model_ok else "FAIL")
		"bigmap":
			# большая карта: строится быстро, флора растёт кусками вокруг героя, миникарта и метки работают
			var w = game.world
			var pl = game.player
			var n0: int = w.nodes.size()
			var ch0: int = w.chunks_done.size()
			pl.position += Vector3(400, 0, 300)
			for i in 120:
				await tree.process_frame
			var fc := Vector2i(floori(pl.position.x / World.C / World.CHUNK), floori(pl.position.z / World.C / World.CHUNK))
			var grown: bool = w.chunks_done.has(w._norm_chunk(fc)) and w.nodes.size() > n0
			var decor_ok: bool = w.decor_done.has(w._norm_chunk(fc))
			game.hud.open("map")
			await tree.process_frame
			var bm = game.hud.bigmap
			bm.add_mark(bm.to_world(bm.size * 0.5 + Vector2(40, 0)))
			var mark_ok: bool = game.marks.size() == 1 and game.hud.minimap.is_visible_in_tree()
			var t0 := Time.get_ticks_msec()
			game.save_game("save10", true)
			var save_ms := Time.get_ticks_msec() - t0
			var sz: int = FileAccess.get_file_as_bytes(DB.saves_dir().path_join("save10.json")).size()
			# загрузка сохранения: карта строится заново из зерна, вырубленное остаётся вырубленным
			var sd = DB.read_file(DB.saves_dir().path_join("save10.json"))
			var w3 := World.new()
			game.add_child(w3)
			w3.load_map(sd.map)
			var same: bool = w3.W == w.W and w3.nodes.size() == w.nodes.size() and absf(w3.h_cell(Vector2i(500, 700)) - w.h_cell(Vector2i(500, 700))) < 0.01 and w3.water_at(Vector2i(900, 900)) == w.water_at(Vector2i(900, 900)) and w3.deposit.size() == w.deposit.size()
			w3.queue_free()
			print("TEST bigmap reload_same=", same, " W=", w.W, " lazy=", w.lazy, " gen_ms=", game.gen_ms, " chunks ", ch0, "->", w.chunks_done.size(), " nodes ", n0, "->", w.nodes.size(),
				" grown=", grown, " decor=", decor_ok, " mark=", mark_ok, " save_mb=", snappedf(sz / 1048576.0, 0.1), " save_ms=", save_ms, " ",
				"OK" if w.lazy and grown and decor_ok and mark_ok and same else "FAIL")
		"terrain":
			# рельеф: холмы есть, на склон без фундамента не построить, фундаменты ставятся ярусами,
			# рампа поднимает, деревья мешают стройке, на воду — только фундамент
			var f = game.factory
			var w = game.world
			var hq: Vector2i = f.hq.cell
			var hmax := 0.0
			var slope := Vector2i(-1, -1)
			for x in w.W:
				for z in w.W:
					var hh: float = w.height.get_pixel(x, z).r
					hmax = maxf(hmax, hh)
			# склон: ищем ближе к штабу свободную клетку с перепадом > 1 м
			var best_d := INF
			for x in w.W:
				for z in w.W:
					var c := Vector2i(x, z)
					var gr: Vector2 = w.ground_range([c])
					if gr.y - gr.x < 1.0 or w.water_at(c) or w.nodes.has(c) or w.nest_cells.has(c) or f.grid.has(c):
						continue
					var ok_n := true
					for d in [Vector2i(1, 0), Vector2i(0, 1)]:
						if w.water_at(c + d) or w.nodes.has(World.wc(c + d)) or w.nest_cells.has(World.wc(c + d)):
							ok_n = false
					var dd: float = Vector2(c - hq).length()
					if ok_n and dd < best_d:
						best_d = dd
						slope = c
			var hills_ok: bool = hmax > 1.5 and slope.x >= 0
			var why_slope: String = f.can_place("smelter", slope)
			var slope_ok: bool = why_slope.contains("неровная")
			game.flags["free_build"] = true
			var f1 = game.cmd("place", {"type": "found_1", "cell": slope, "dir": 0})
			var f_ok: bool = f1 != null and f1.top > w.ground_range([slope]).y and f1.y < w.ground_range([slope]).x
			var ch = game.cmd("place", {"type": "chest", "cell": slope, "dir": 0})
			var on_ok: bool = ch != null and absf(ch.y - f1.top) < 0.01
			game.cmd("demolish", {"cell": slope})
			var f2 = game.cmd("place", {"type": "found_1", "cell": slope, "dir": 0}) if ch != null and ch.dead else null
			var stack_ok: bool = f2 != null and absf(f2.y - f1.top) < 0.01 and absf(f2.top - f1.top - 1.0) < 0.01 and f.found[World.wc(slope)].size() == 2
			# нижний ярус нельзя снести, пока сверху стоит другой
			var low_ok: bool = f.found_why(f1) != "" and f.found_why(f2) == ""
			# рампа рядом: по стрелке поднимается
			var rc := slope + Vector2i(1, 0)
			var rp = game.cmd("place", {"type": "found_ramp", "cell": rc, "dir": 0})
			var rcen: Vector3 = World.cell_to_world(rc)
			var ramp_ok: bool = rp != null and f.support_at(rcen + Vector3(0.9, 0, 0)) > f.support_at(rcen + Vector3(-0.9, 0, 0)) + 0.5
			var no_on_ramp: bool = f.can_place("chest", rc) != ""
			# герой не запрыгивает без прыжка на 2 яруса, но заходит на землю рядом
			var pl = game.player
			pl.position = World.cell_to_world(slope + Vector2i(0, 2))
			pl.position.y = f.support_at(pl.position)
			var hi_block: bool = pl._blocked(World.cell_to_world(slope) + Vector3(0, 0, 0.5))
			# деревья мешают стройке
			var tree_c := Vector2i(-1, -1)
			for c in w.nodes:
				if str(DB.data.resources.get(w.nodes[c].res, {}).get("category", "")) == "Деревья" and f.grid.get(c) == null:
					tree_c = c
					break
			var tree_why: String = f.can_place("chest", tree_c)
			var tree_ok: bool = tree_why.begins_with("Мешает")
			# вода: сундук нельзя, фундамент можно, а на нём — сундук
			var wcell := Vector2i(-1, -1)
			for x in w.W:
				for z in w.W:
					if w.water_at(Vector2i(x, z)) and not w.nest_cells.has(Vector2i(x, z)):
						wcell = Vector2i(x, z)
						break
				if wcell.x >= 0:
					break
			var water_ok: bool = f.can_place("chest", wcell) != "" and game.cmd("place", {"type": "found_1", "cell": wcell, "dir": 0}) != null and game.cmd("place", {"type": "chest", "cell": wcell, "dir": 0}) != null
			# сохранение и загрузка: ярусы на месте
			game.save_game("save9", true)
			var sd = DB.read_file(DB.saves_dir().path_join("save9.json"))
			var hmap_ok: bool = sd is Dictionary and str(sd.get("map", {}).get("height", "")) != ""
			print("TEST terrain hmax=", snappedf(hmax, 0.1), " hills=", hills_ok, " slope='", why_slope, "' found=", f_ok, " on=", on_ok, " stack=", stack_ok,
				" low=", low_ok, " ramp=", ramp_ok, " no_on_ramp=", no_on_ramp, " climb_block=", hi_block, " tree='", tree_why, "' water=", water_ok, " hmap=", hmap_ok, " ",
				"OK" if hills_ok and slope_ok and f_ok and on_ok and stack_ok and low_ok and ramp_ok and no_on_ramp and hi_block and tree_ok and water_ok and hmap_ok else "FAIL")
		"batch2":
			# правки 10.10: побег от монстра, монстры ломают здания, провода вручную, лента от бокового выхода разделителя, окно само закрывается
			var pl = game.player
			var f = game.factory
			var hq: Vector2i = f.hq.cell
			game.flags["free_build"] = true
			DB.data.settings["monster_escape_time"] = 1.0
			var e = game.enemies.spawn("crawler", pl.position + Vector3(5, 0, 0))
			e.target = pl
			e.speed = 0.0
			e.hp = 1e9
			var p0: Vector3 = pl.position
			pl.position = p0 + Vector3(40, 0, 0)
			await tree.create_timer(0.5).timeout
			var still: bool = e.target == pl
			await tree.create_timer(1.2).timeout
			var gave_up: bool = e.target != pl
			pl.position = e.pos + Vector3(3, 0, 0)
			await tree.create_timer(1.2).timeout
			var again: bool = e.target == pl
			# без героя — ломает ленту рядом
			pl.position = p0 + Vector3(60, 0, 60)
			var bc := World.world_to_cell(e.pos) + Vector2i(2, 0)
			var belt = put(game, "belt", bc, 0)
			e.far_t = 99.0
			await tree.create_timer(2.5).timeout
			var at_bld: bool = belt != null and e.target != null and e.target != pl
			e.alive = false
			# провода: с выключенным «Провода тянутся сами» новые здания не подключаются сами (14.10: по умолчанию включено)
			DB.data.settings["auto_wire"] = false
			var pole = put(game, "pole", hq + Vector2i(6, -6), 0)
			var gen = put(game, "generator", hq + Vector2i(8, -6), 0)
			var manual: bool = pole != null and gen != null and not f.wired_to(pole, gen)
			# разделитель: лента у бокового выхода, повёрнутая вниз, загибается к нему и получает стык
			var sp = put(game, "splitter", hq + Vector2i(-8, -8), 0)
			var side := World.wc(sp.cell + Factory.DIRS[3])
			var sb = put(game, "belt", side, 3)
			var sb2 = put(game, "belt", hq + Vector2i(-8, -6), 1)
			var down = put(game, "belt", World.wc(sp.cell + Factory.DIRS[1]), 1)
			var kind_ok: bool = down != null and down.kind != 0 or (down != null and f.port_keys.has(down))
			# окно здания закрывается, если отойти
			pl.position = gen.center() + Vector3(3, 0, 0)
			game.hud.open_building(gen)
			await tree.process_frame
			var opened: bool = game.hud.is_open("building")
			pl.position = gen.center() + Vector3(40, 0, 0)
			await tree.create_timer(0.6).timeout
			var closed: bool = not game.hud.is_open("building")
			print("TEST batch2 still=", still, " gave_up=", gave_up, " again=", again, " at_building=", at_bld, " manual_wires=", manual,
				" side_belt=", kind_ok, " ports=", f.port_keys.has(down), " opened=", opened, " closed=", closed, " ",
				"OK" if still and gave_up and again and at_bld and manual and kind_ok and f.port_keys.has(down) and opened and closed else "FAIL")
		"tech":
			# дерево открытий: бур закрыт → сдаём ресурсы → открыт; задание станции; залежи серы появляются после «Химии»
			var f = game.factory
			var T: Tech = game.tech
			var hq: Vector2i = f.hq.cell
			var locked0: bool = Tech.building_locked("miner") and not Tech.building_locked("workbench")
			var why0: String = f.can_place("miner", hq + Vector2i(6, 6))
			var hand_ok: bool = not "steel" in DB.recipes_for("smelter")
			var sulfur_hidden := true
			for c in game.world.deposit:
				if str(game.world.deposits[game.world.deposit[c]].get("item", "")) == "sulfur" and game.world.deposit_item(c) != "":
					sulfur_hidden = false
			# сдаём частями: сначала половину
			f.hq.inv.add("iron_ingot", 5)
			f.hq.inv.add("plank", 10)
			game.cmd("donate", {"id": "t_mining"})
			var part: bool = T.state("t_mining") == "open" and T.left_of("t_mining").get("iron_ingot", 0) == 5
			game.player.inv.add("iron_ingot", 5)
			game.cmd("donate", {"id": "t_mining"})
			var opened: bool = T.done.has("t_mining") and not Tech.building_locked("miner")
			# лента в терминал: узел со звёздочкой
			var term = put(game, "tech_terminal", hq + Vector2i(-6, 6), 0)
			T.target = "t_found"
			var took := 0
			for i in 45:
				if f.accept(term, "stone", null):
					took += 1
			var found_ok: bool = T.done.has("t_found") and took == 40
			# задание станции: сдать доски
			f.hq.inv.add("plank", 30)
			game.cmd("c_deliver", {"id": "c_planks"})
			var c_ok: bool = T.c_done.has("c_planks") and T.research == 5
			# цепочка условий и залежи
			var free_why: String = T.why_not("t_chem")   # 15.1: свободный порядок — «нужно сначала» не держит
			DB.data.settings["tech_ui"]["free"] = false
			var chem_why: String = T.why_not("t_chem") if free_why == "" else ""
			DB.data.settings["tech_ui"]["free"] = true
			for id in ["t_workshop", "t_power"]:
				T.unlock(id)
			game.credits += 500
			f.hq.inv.add("quartz", 15)
			f.hq.inv.add("coal", 20)
			game.cmd("donate", {"id": "t_chem"})
			var revealed := false
			for c in game.world.deposit:
				if str(game.world.deposits[game.world.deposit[c]].get("item", "")) == "sulfur" and game.world.deposit_item(c) == "sulfur":
					revealed = true
					break
			# сохранение
			var d := T.to_dict()
			var T2 := Tech.new(game)
			T2.from_dict(d)
			var save_ok: bool = T2.done.has("t_chem") and T2.c_done.has("c_planks") and T2.research == 5
			T.refresh_locks()
			game.hud.tech_tab = 0
			game.hud.open("tech")
			await tree.process_frame
			var ui_ok: bool = game.hud.windows.tech.body.get_child_count() > 1
			print("TEST tech locked=", locked0, " why='", why0, "' steel_hidden=", hand_ok, " sulfur_hidden=", sulfur_hidden, " part=", part, " opened=", opened,
				" belt_took=", took, " found=", found_ok, " contract=", c_ok, " chem_why='", chem_why, "' revealed=", revealed, " save=", save_ok, " ui=", ui_ok, " ",
				"OK" if locked0 and why0.find("дереве") >= 0 and hand_ok and sulfur_hidden and part and opened and found_ok and c_ok and chem_why != "" and revealed and save_ok and ui_ok else "FAIL")
		"events":
			# 8.6: лаборатория даёт очки исследований, события мира, загрязнение
			var f = game.factory
			var E = game.events
			var hq: Vector2i = f.hq.cell
			var lab_d: Dictionary = DB.data.buildings.research_lab
			lab_d.params["power"] = 0
			for bl in lab_d.blocks:
				bl["needs_power"] = false
				bl["time"] = 0.5
			var lab = put(game, "research_lab", hq + Vector2i(-6, 6), 0)
			var r0: int = game.tech.research
			var took := 0
			for it in ["goo", "goo", "chitin", "monster_core", "stone"]:
				if f.accept(lab, it, null):
					took += 1
			await tree.create_timer(1.6).timeout
			var lab_ok: bool = took == 4 and game.tech.research == r0 + 29
			# буря
			E.start("storm")
			var storm_on: bool = E.storm_target > 0.5 and game.bonus("move") < 0.0 and E.active.has("storm")
			E.storm = 1.0
			var sun_less: bool = game.sun_power() <= game.daylight() * 0.31 + 0.001
			var wind_up: bool = game.wind() >= 0.8
			E.finish("storm")
			var storm_off: bool = E.storm_target == 0.0 and not E.active.has("storm")
			# метеоритный дождь
			var n0 := 0
			for c in game.world.nodes:
				if game.world.nodes[c].res == "meteorite":
					n0 += 1
			E.start("meteor_shower")
			E._meteor_t = 0.0
			await tree.create_timer(4.0).timeout
			var n1 := 0
			for c in game.world.nodes:
				if game.world.nodes[c].res == "meteorite":
					n1 += 1
			# нашествие: внеочередная волна
			var w0: int = game.enemies.wave
			E.start("invasion")
			var inv_ok: bool = game.enemies.wave == w0 + 1 and game.enemies.list.size() > 0
			game.console.run("kill_all")
			for e in game.enemies.list.duplicate():
				game.enemies.hit(e, 999999.0)
			# своё событие по кубику нового дня
			DB.data.events.supply_drop["chance"] = 1.0
			for id in DB.data.events:
				if id != "supply_drop":
					DB.data.events[id]["chance"] = 0.0
			var d0: int = game.drops.list.size()
			E.active.clear()
			E.last_day = game.day_n
			game.day_n += 1
			E._acc = 1.0
			E.update(0.01)
			# 13.10: сначала зловещая надпись, само событие — через «за сколько секунд»
			var omened: bool = E.pending.has("supply_drop") and not E.active.has("supply_drop")
			for i in 10:
				E._acc = 1.0
				E.update(0.01)
			var drop_ok: bool = omened and game.drops.list.size() > d0 and E.active.has("supply_drop")
			# загрязнение
			E.pollution = 100.0
			var mult: float = E.wave_mult()
			var pol_ok: bool = absf(mult - 1.4) < 0.01 and E.building_pollution("miner") == 1.0 and E.building_pollution("research_lab") == 0.0
			game.ng_modules["pollution"] = false
			var pol_off: bool = E.wave_mult() == 1.0
			game.ng_modules["pollution"] = true
			# сохранение
			var dd: Dictionary = E.to_dict()
			var E2 = load("res://scripts/events.gd").new(game)
			E2.load_dict(dd)
			var save_ok: bool = E2.pollution == 100.0 and E2.active.has("supply_drop")
			var txt_ok: bool = game.clock_text().find("загрязнение") >= 0
			print("TEST events lab=", lab_ok, " research=", game.tech.research - r0, " storm=", storm_on, " sun=", sun_less, " wind=", wind_up, " storm_off=", storm_off,
				" meteors=", n1 - n0, " invasion=", inv_ok, " day_roll=", drop_ok, " pollution=", pol_ok, " off=", pol_off, " save=", save_ok, " hud=", txt_ok, " ",
				"OK" if lab_ok and storm_on and sun_less and wind_up and storm_off and n1 > n0 and inv_ok and drop_ok and pol_ok and pol_off and save_ok and txt_ok else "FAIL")
		"transport":
			# 8.6: чертежи, машина, дроны и грузовики, фоторежим, вид сверху
			var f = game.factory
			var hq: Vector2i = f.hq.cell
			game.flags["free_build"] = true
			var base := hq + Vector2i(-14, 8)
			put(game, "chest", base, 0)
			put(game, "belt", base + Vector2i(1, 0), 0)
			put(game, "belt", base + Vector2i(2, 0), 1)
			var asm = put(game, "assembler", base + Vector2i(0, 2), 2)
			var rid := ""
			for r in DB.recipes_for("assembler"):
				rid = r
				break
			if asm != null and rid != "":
				f.set_recipe(asm, rid)
			var BP = game.blueprints
			var bp: Dictionary = BP.copy_rect(base + Vector2i(2, 2), base + Vector2i(-1, -1))
			var copied: bool = bp.items.size() == 4 and int(bp.w) == 4 and int(bp.h) == 4
			var to := base + Vector2i(0, 12)
			for tries in 40:
				var ok_all := true
				for Lx in BP.layout(bp, 0):
					if f.can_place(str(Lx.e.t), World.wc(to + Vector2i(Lx.x, Lx.z))) != "":
						ok_all = false
				if ok_all:
					break
				to += Vector2i(5 if tries % 2 == 0 else 0, 5 if tries % 2 == 1 else 0)
			var n_placed: int = BP.paste(bp, to, 0)
			var b2 = f.building_at(to + Vector2i(1, 3))
			var b3 = f.building_at(to + Vector2i(3, 1))
			var same: bool = b2 != null and b2.type == "assembler" and b2.recipe == rid and b3 != null and b3.dir == 1
			# поворот: лента (1,0) смотрит вправо → после поворота на 90° смотрит вниз (+z)
			var L: Array = BP.layout({"items": [{"t": "belt", "x": 1, "z": 0, "d": 0}], "w": 3, "h": 1}, 1)
			var rot_ok: bool = int(L[0].x) == 0 and int(L[0].z) == 1 and int(L[0].d) == 1
			BP.cur = bp
			BP.save_current("тест")
			BP._load()
			var saved_ok: bool = BP.saved.has("тест")
			# 14.1: предел размера и обмен одним файлом
			var limit_ok: bool = BP.too_big(base, base + Vector2i(16, 0)) and not BP.too_big(base, base + Vector2i(15, 15))
			var fpath: String = BP.export_file("тест")
			BP.remove("тест")
			var bp_got: Array = BP.import_all()
			var share_ok: bool = fpath.ends_with(".fcbp") and bp_got.has("тест") and BP.saved.has("тест")
			DirAccess.remove_absolute(fpath)
			saved_ok = saved_ok and limit_ok and share_ok
			if not (limit_ok and share_ok):
				print("BP limit=", limit_ok, " share=", share_ok)
			BP.remove("тест")
			# машина
			var pl = game.player
			var car_cell := hq + Vector2i(8, -8)
			var car = put(game, "rover", car_cell, 0)
			pl.position = car.center() + Vector3(2, 0, 0)
			game.hover_cell = car_cell
			game._interact()
			var in_car: bool = game.vehicles.driving == "rover" and f.building_at(car_cell) == null and game.vehicles.speed_mult() > 2.0
			var vd: Dictionary = game.vehicles.to_dict()
			pl.position += Vector3(30, 0, 0)
			await tree.process_frame
			game._interact()
			var parked: bool = game.vehicles.driving == "" and f.all.any(func(o): return o.type == "rover")
			# дроны
			var src = put(game, "drone_port", hq + Vector2i(10, 10), 0)
			var dst = put(game, "drone_dock", hq + Vector2i(22, 10), 0)
			for t in ["drone_port", "drone_dock"]:
				for bl in DB.data.buildings[t].blocks:
					bl["needs_power"] = false
					bl["every"] = 0.5
			var took := 0
			for i in 12:
				if f.accept(src, "iron_ingot", null):
					took += 1
			await tree.create_timer(0.8).timeout
			var flying: bool = game.carriers.flights.size() > 0
			await tree.create_timer(3.0).timeout
			var got: int = (dst.out.count("iron_ingot") if dst.out else 0)
			var drone_ok: bool = took == 12 and flying and got >= 10
			# фоторежим и вид сверху
			game._action("photo")
			var photo_ok: bool = not game.hud.visible
			game._action("photo")
			photo_ok = photo_ok and game.hud.visible
			game._action("top_view")
			for i in 3:
				await tree.process_frame
			var top_ok: bool = game.top_view and game.camera.global_transform.basis.z.y > 0.95
			game._action("top_view")
			print("TEST transport copied=", copied, " placed=", n_placed, " same=", same, " rot=", rot_ok, " saved=", saved_ok, " in_car=", in_car, " vsave=", vd.get("driving", ""),
				" parked=", parked, " drone_took=", took, " flying=", flying, " got=", got, " photo=", photo_ok, " top=", top_ok, " ",
				"OK" if copied and n_placed == 4 and same and rot_ok and saved_ok and in_car and parked and drone_ok and photo_ok and top_ok else "FAIL")
		"npcs":
			# этап 9: торговец приходит к базе, торговля, подарок, налётчик грабит склад, «тень» ночью вредит, сон вдали
			var f = game.factory
			var N = game.npcs
			var E = game.enemies
			var hq: Vector2i = f.hq.cell
			game.day_t = 0.4
			var tr: Array = N.spawn_visit("trader", 1)
			var t = tr[0] if not tr.is_empty() else null
			var peaceful_ok: bool = t != null and t.peaceful and E.nearest(t.pos, 5.0) == null
			t.pos = t.goal + Vector3(3, 0, 0)
			await tree.create_timer(1.5).timeout
			var arrived: bool = t.state == "stay"
			game.player.position = t.pos + Vector3(2, 0, 0)
			game.hover_cell = World.world_to_cell(t.pos)
			game.credits = 500
			game._interact()
			await tree.process_frame
			var win_ok: bool = game.hud.is_open("npc")
			var r0: int = N.rep_of("merchants")
			var cr0: int = game.credits
			var bought: bool = N.buy_from(t, 0) and game.credits < cr0
			game.player.inv.add("log", 3)
			var sold: bool = N.sell_to(t, "log") and game.player.inv.count("log") == 2
			game.player.inv.add("crystal", 1)
			var up: int = N.gift(t, "crystal")
			var rep_ok: bool = N.rep_of("merchants") >= r0 + 2 + up - 0 and up > 0
			var cheaper: bool = N.price_k("merchants") < 1.0
			game.hud.close("npc")
			# налётчик грабит ящик
			var chest = put(game, "chest", hq + Vector2i(-7, -7), 0)
			chest.inv.add("iron_ingot", 30)
			var bs: Array = N.spawn_visit("bandit", 1)
			var bnd = bs[0]
			bnd.pos = chest.center() + Vector3(2.2, 0, 0)
			game.player.position = f.hq.center() + Vector3(40, 0, 40)
			game.flags["god"] = true
			game.player.god = true
			await tree.create_timer(3.0).timeout
			var robbed: bool = chest.inv.count("iron_ingot") < 30 and not bnd.loot.is_empty()
			var bandit_hostile: bool = not bnd.peaceful
			var rr0: int = N.rep_of("raiders")
			var d0: int = game.drops.list.size()
			E.hit(bnd, 99999.0)
			var loot_back: bool = game.drops.list.size() > d0 and N.rep_of("raiders") == rr0 + 5
			# «тень» ночью
			var inf: Array = N.spawn_visit("infiltrator", 1)
			var sh = inf[0]
			var belt = put(game, "chest", hq + Vector2i(9, -7), 0)
			belt.inv.add("stone", 10)
			sh.pos = belt.center() + Vector3(1.5, 0, 0)
			game.day_t = 0.9
			sh.state = "sneak"
			sh.target = belt
			sh.timer = 0.0
			await tree.create_timer(1.5).timeout
			var revealed: bool = sh.revealed and not sh.peaceful and E.nearest(sh.pos, 5.0) == sh
			var stolen: bool = belt.inv.count("stone") < 10 or belt.hp < belt.maxhp
			game.day_t = 0.4
			# путник проходит мимо и исчезает
			var tv: Array = N.spawn_visit("traveler", 1)
			var trv = tv[0]
			trv.pos = trv.goal + Vector3(0.5, 0, 0)
			await tree.create_timer(0.5).timeout
			var passed: bool = not trv.alive
			# сон: монстр далеко от героя и базы не двигается
			var far_p: Vector3 = f.hq.center() + Vector3(400, 0, 400)
			var mon = E.spawn("crawler", far_p)
			var p0: Vector3 = mon.pos
			await tree.create_timer(1.0).timeout
			var slept: bool = Vector2(mon.pos.x - p0.x, mon.pos.z - p0.z).length() < 0.01
			E.hit(mon, 99999.0)
			# событие «visit» и сохранение репутации
			var c0: int = N.count()
			game.events.start("travelers")
			var visit_ok: bool = N.count() > c0
			var dd: Dictionary = N.to_dict()
			var N2 = load("res://scripts/npcs.gd").new(game)
			N2.load_dict(dd)
			var save_ok: bool = N2.rep_of("merchants") == N.rep_of("merchants")
			print("TEST npcs peaceful=", peaceful_ok, " arrived=", arrived, " window=", win_ok, " bought=", bought, " sold=", sold, " gift=", up, " rep=", rep_ok, " cheaper=", cheaper,
				" robbed=", robbed, " hostile=", bandit_hostile, " loot_back=", loot_back, " revealed=", revealed, " sabotage=", stolen, " passed=", passed, " slept=", slept,
				" visit=", visit_ok, " save=", save_ok, " ",
				"OK" if peaceful_ok and arrived and win_ok and bought and sold and rep_ok and cheaper and robbed and bandit_hostile and loot_back and revealed and stolen and passed and slept and visit_ok and save_ok else "FAIL")
		"npcmem":
			# 14.7 память и характер НПС: имя, характер, помнит покупки, подарки и удары; знакомый возвращается; налётчики мстят
			var N = game.npcs
			var EN = game.enemies
			DB.data.settings["npc_return_chance"] = 1.0
			game.credits = 100000
			var t1 = N.spawn_visit("trader", 1)[0]
			var p1: Dictionary = N.person(t1)
			var pid: String = t1.person
			var named: bool = str(p1.get("name", "")) != "" and N.characters().has(str(p1.get("char", "")))
			var gr1: String = N.greeting(t1)
			var first_ok: bool = gr1.find(str(p1.get("name", "?"))) >= 0 and int(p1.visits) == 1
			var bought: bool = N.buy_from(t1, 0) and int(p1.bought) == 1
			game.player.inv.add("steel", 3)
			var up: int = N.gift(t1, "steel")
			var gift_ok: bool = up > 0 and int(p1.gifts) == 1 and int(p1.rel) > 0
			var rel0: int = int(p1.rel)
			EN.hit(t1, 1.0, true)
			var hurt_ok: bool = int(p1.hits) == 1 and int(p1.rel) < rel0
			# характер меняет цены
			p1.rel = 0
			p1.char = "kind"
			var pk: int = N.good_price(t1, 0)
			p1.char = "greedy"
			var pg: int = N.good_price(t1, 0)
			var char_price: bool = pg > pk
			# сильно обижен — не торгует
			p1.rel = -100
			var refuse_ok: bool = N.refuses(t1) and not N.buy_from(t1, 0) and N.next_line(t1) != ""
			p1.rel = 40
			# ушёл и вернулся: тот же человек, помнит
			EN.remove_silent(t1)
			var t2 = N.spawn_visit("trader", 1)[0]
			var back_ok: bool = t2.person == pid and int(N.person(t2).visits) == 2 and N.greeting(t2) != gr1
			# сохранение
			var dd: Dictionary = N.to_dict()
			var N2 = load("res://scripts/npcs.gd").new(game)
			N2.load_dict(JSON.parse_string(JSON.stringify(dd)))
			var save_ok: bool = N2.people.has(pid) and int(N2.people[pid].bought) == 1 and int(N2.people[pid].hits) == 1
			# погиб — больше не придёт
			EN.hit(t2, 1e9, true)
			var t3 = N.spawn_visit("trader", 1)[0]
			var dead_ok: bool = not bool(N.people[pid].alive) and t3.person != pid
			EN.remove_silent(t3)
			# налётчики помнят убитых и приходят сильнее
			var b0 = N.spawn_visit("bandit", 1)[0]
			var hp_norm: float = b0.maxhp
			EN.remove_silent(b0)
			N.fm("raiders").kills = 5
			var b1 = N.spawn_visit("bandit", 1)[0]
			var revenge_ok: bool = b1.maxhp > hp_norm * 1.2 and N.say(b1, "revenge").find("5") >= 0
			EN.remove_silent(b1)
			var ok: bool = named and first_ok and bought and gift_ok and hurt_ok and char_price and refuse_ok and back_ok and save_ok and dead_ok and revenge_ok
			print("TEST npcmem named=", named, " first=", first_ok, " bought=", bought, " gift=", gift_ok, " hurt=", hurt_ok, " char_price=", char_price, "(", pk, "/", pg, ")",
				" refuse=", refuse_ok, " back=", back_ok, " save=", save_ok, " dead=", dead_ok, " revenge=", revenge_ok, " ", "OK" if ok else "FAIL")
		"mechstyle":
			# 13.10 стиль «механика»: дрон (винты, парение), паук (6 ног), громила (колёса), шагоход; герой-робот; мультяшный свет и обводка
			game.flags["god"] = true
			var EN = game.enemies
			var pl = game.player
			var kinds := {"spitter": "mech_drone", "crawler": "mech_spider", "brute": "mech_roller", "runner": "mech_scout"}
			var mobs := {}
			var i := 0
			for k in kinds:
				var e = EN.spawn(k, pl.position + Vector3(6 + i * 3, 0, 4))
				e.speed = 0.0
				mobs[k] = e
				i += 1
			for f in 20:
				await tree.process_frame
			var rigs_ok := true
			for k in mobs:
				rigs_ok = rigs_ok and EN.rigs.has(mobs[k]) and str(DB.data.enemies[k].model) == kinds[k]
			# винт дрона крутится, корпус парит
			var dr = EN.rigs.get(mobs.spitter)
			var rot_ok := false
			var hover_ok := false
			if dr:
				var b0: Basis = dr.bones["b:rot0"].basis
				var y0: float = dr.bones["b:body"].position.y
				for f in 15:
					await tree.process_frame
				rot_ok = not dr.bones["b:rot0"].basis.is_equal_approx(b0)
				hover_ok = absf(dr.bones["b:body"].position.y - y0) > 0.001
			# колёса громилы крутятся, когда он едет
			var rl = EN.rigs.get(mobs.brute)
			var wheel_ok := false
			if rl:
				var w0: Basis = rl.bones["b:wheel0"].basis
				for f in 20:
					mobs.brute.pos += Vector3(0.12, 0, 0)
					await tree.process_frame
				wheel_ok = not rl.bones["b:wheel0"].basis.is_equal_approx(w0)
			# паук переставляет ноги
			var sp = EN.rigs.get(mobs.crawler)
			var legs_ok := false
			if sp:
				var h0: Basis = sp.bones["b:hip0l"].basis
				for f in 20:
					mobs.crawler.pos += Vector3(0.1, 0, 0)
					await tree.process_frame
				legs_ok = not sp.bones["b:hip0l"].basis.is_equal_approx(h0)
			# вспышка при попадании
			EN.hit(mobs.crawler, 1.0, true)
			await tree.process_frame
			var flash_ok: bool = mobs.crawler.flash > 0.0
			# стиль: мультяшный шейдер и обводка у врагов и героя, палитра
			var toon_ok := false
			var outline_ok := false
			for mp in ModelLib.merged_parts("mech_drone", true, true):
				if mp[1] is ShaderMaterial and (mp[1] as ShaderMaterial).shader == ModelLib.PART_TOON_SHADER:
					toon_ok = true
					if (mp[1] as ShaderMaterial).next_pass != null:
						outline_ok = true
			var hero_ok: bool = str(DB.setting("hero_model", "")) == "hero_robot"
			var pal_ok: bool = DB.color("@enemy_glow").is_equal_approx(Color("#ff4a1c")) and DB.color("@hero_glow").is_equal_approx(Color("#38d6ff"))
			var plain_ok := true
			for mp2 in ModelLib.merged_parts("furnace", true):
				if mp2[1] is ShaderMaterial and (mp2[1] as ShaderMaterial).shader == ModelLib.PART_TOON_SHADER:
					plain_ok = false
			var ok: bool = rigs_ok and rot_ok and hover_ok and wheel_ok and legs_ok and flash_ok and toon_ok and outline_ok and hero_ok and pal_ok and plain_ok
			print("TEST mechstyle rigs=", rigs_ok, " rotors=", rot_ok, " hover=", hover_ok, " wheels=", wheel_ok, " legs=", legs_ok, " flash=", flash_ok,
				" toon=", toon_ok, " outline=", outline_ok, " hero=", hero_ok, " palette=", pal_ok, " buildings_plain=", plain_ok, " ", "OK" if ok else "FAIL")
		"glbhero":
			# своя модель героя из GLB с анимациями: подбор анимаций по названиям и смена при движении
			var gpath := OS.get_user_data_dir().path_join("test_hero_anim.glb")
			var root := Node3D.new()
			root.name = "Hero"
			var mi := MeshInstance3D.new()
			mi.name = "Body"
			var cm := CapsuleMesh.new()
			cm.height = 180.0
			cm.radius = 30.0
			mi.mesh = cm
			mi.position.y = 90.0
			root.add_child(mi)
			var ap := AnimationPlayer.new()
			root.add_child(ap)
			var lib := AnimationLibrary.new()
			for an in ["Idle", "Walk", "Run", "Attack", "Death"]:
				var a := Animation.new()
				a.length = 1.0
				var tr := a.add_track(Animation.TYPE_POSITION_3D)
				a.track_set_path(tr, NodePath("Body"))
				a.position_track_insert_key(tr, 0.0, Vector3(0, 90, 0))
				a.position_track_insert_key(tr, 1.0, Vector3(0, 100, 0))
				lib.add_animation(an, a)
			ap.add_animation_library("", lib)
			var doc := GLTFDocument.new()
			var gst := GLTFState.new()
			doc.append_from_scene(root, gst)
			doc.write_to_filesystem(gst, gpath)
			root.free()
			var names := ModelLib.glb_anims(gpath)
			DB.data.models["test_glb_hero"] = {"name": "Тест", "parts": [], "glb": gpath, "scale": 1.0}
			DB.data.settings["hero_model"] = "test_glb_hero"
			# размер подгоняет редактор; здесь — вручную, как после «Выбрать…»
			var bx := ModelLib.glb_aabb(gpath)
			DB.data.models["test_glb_hero"]["scale"] = 2.0 / bx.size.y
			var P2 = load("res://scripts/player.gd")
			var hero = P2.new()
			hero.game = game
			game.add_child(hero)
			hero.position = game.player.position + Vector3(2, 0, 0)
			hero.build()
			var built: bool = hero.glb_node != null and hero.glb_ap != null
			hero._glb_update(0.1)
			var idle: String = hero.glb_cur
			hero.move_dir = Vector3(3, 0, 0)
			hero._glb_update(0.1)
			var walk: String = hero.glb_cur
			hero._run_k = 1.0
			hero.move_dir = Vector3(6, 0, 0)
			hero._glb_update(0.1)
			var run: String = hero.glb_cur
			hero.swing_t = 0.1
			hero._glb_update(0.1)
			var atk: String = hero.glb_cur
			hero.swing_t = -1.0
			hero.alive = false
			hero._glb_update(0.1)
			var die: String = hero.glb_cur
			DB.data.models["test_glb_hero"]["glb_anims"] = {"walk": "Run"}
			hero.alive = true
			hero._run_k = 0.0
			hero.move_dir = Vector3(3, 0, 0)
			hero._glb_update(0.1)
			var mapped: String = hero.glb_cur
			var no_parts := true
			for c in hero.get_children():
				if c is Node3D and c != hero.glb_node:
					var stack: Array = [c]
					while not stack.is_empty():
						var n = stack.pop_back()
						stack.append_array(n.get_children())
						if n is MeshInstance3D and str(n.get_meta("role", "")) == "glb":
							no_parts = false
			# 1.7: такой же герой другого игрока по сети тоже играет свою анимацию ходьбы
			DB.data.models["test_glb_hero"].erase("glb_anims")
			var pp = load("res://scripts/remote_player.gd").new()
			pp.game = game
			pp.nick = "Друг"
			game.add_child(pp)
			pp.build()
			pp.setup_label()
			pp.position = game.player.position + Vector3(-3, 0, 0)
			pp.move_dir = Vector3(3, 0, 0)
			for i in 5:
				await tree.process_frame
			var puppet_walk: String = pp.glb_cur
			pp.queue_free()
			var ok: bool = names.size() == 5 and built and idle == "Idle" and walk == "Walk" and run == "Run" and atk == "Attack" and die == "Death" and mapped == "Run" and no_parts and puppet_walk == "Walk"
			print("TEST glbhero names=", names, " built=", built, " idle=", idle, " walk=", walk, " run=", run, " attack=", atk, " die=", die, " mapped=", mapped, " no_static=", no_parts, " puppet=", puppet_walk, " OK" if ok else " FAIL")
			DB.data.settings.erase("hero_model")
			hero.queue_free()
		"climate":
			# 14.7 сезоны и выживание: зимой холодно (снег), летом жарко, одежда, костёр, обогреватель, горячая еда с кухни
			var CL = game.climate
			var pl = game.player
			var f = game.factory
			game.flags["god"] = false
			game.flags["free_build"] = true
			pl.clothes = ""
			# зима, ночь
			game.day_n = 16
			game.day_t = 0.0
			CL.step(0.1)
			var winter_air: float = CL.air
			var cold_ok: bool = str(game.season().get("name", "")) == "Зима" and winter_air < -15.0
			CL.chill = 0.0
			CL.step(10.0)
			var chilling: bool = CL.chill > 5.0
			CL.chill = 100.0
			var hp0: float = pl.hp
			CL.step(2.0)
			var hurt_ok: bool = pl.hp < hp0 and CL.speed_k() < 0.95
			pl.hp = pl.maxhp
			# одежда
			var feel0: float = CL.feel
			pl.inv.add("fur_coat", 1)
			var slot := -1
			for i in pl.inv.slots.size():
				if pl.inv.slots[i] != null and pl.inv.slots[i].id == "fur_coat":
					slot = i
			pl.use_item(slot)
			CL.step(0.1)
			var coat_ok: bool = pl.clothes == "fur_coat" and pl.inv.count("fur_coat") == 0 and CL.feel >= feel0 + 25.0
			# костёр рядом
			var fire = put_near(game, "campfire", World.world_to_cell(pl.position) + Vector2i(2, 0))
			var fire_heat: float = CL.heat_at(pl.position)
			var fire_ok: bool = fire != null and fire_heat > 12.0
			# обогреватель без энергии не греет
			var htr = put_near(game, "heater", World.world_to_cell(pl.position) + Vector2i(-2, 0))
			var heater_off: bool = htr != null and absf(CL.heat_at(pl.position) - fire_heat) < 0.01
			# кухня: жаркое греет
			var has_kitchen: bool = DB.data.buildings.has("kitchen") and DB.data.recipes.get("hot_stew", {}).get("stations", []).has("kitchen")
			pl.inv.add("hot_stew", 1)
			for i in pl.inv.slots.size():
				if pl.inv.slots[i] != null and pl.inv.slots[i].id == "hot_stew":
					slot = i
			pl.use_item(slot)
			var stew_ok: bool = has_kitchen and game.bonus("warmth") >= 15.0
			# снег зимой на земле
			CL._vis_init = false
			CL._visuals(0.1)
			var snow_ok: bool = float(game.world.ground_mat.get_shader_parameter("season_snow")) > 0.5
			# лето, полдень: жарко, шуба мешает, лёгкий костюм спасает
			if fire:
				f.remove(fire)
			game.day_n = 6
			game.day_t = 0.5
			game.effects.clear()
			CL.step(0.1)
			var summer_air: float = CL.air
			var feel_coat: float = CL.feel
			pl.inv.add("light_suit", 1)
			for i in pl.inv.slots.size():
				if pl.inv.slots[i] != null and pl.inv.slots[i].id == "light_suit":
					slot = i
			pl.use_item(slot)
			CL.step(0.1)
			var hot_ok: bool = summer_air > 33.0 and feel_coat > summer_air and CL.feel < feel_coat - 10.0 and pl.inv.count("fur_coat") == 1
			CL.heat = 0.0
			game.day_n = 1
			game.day_t = 0.3
			CL.step(0.1)
			# сохранение
			var cd: Dictionary = CL.to_dict()
			var save_ok: bool = cd.has("chill") and pl.clothes == "light_suit"
			CL.take_off()
			var off_ok: bool = pl.clothes == "" and pl.inv.count("light_suit") == 1
			var ok: bool = cold_ok and chilling and hurt_ok and coat_ok and fire_ok and heater_off and stew_ok and snow_ok and hot_ok and save_ok and off_ok
			print("TEST climate winter=", snappedf(winter_air, 0.1), " cold=", cold_ok, " chilling=", chilling, " hurt=", hurt_ok, " coat=", coat_ok, " fire=", fire_ok, "(", snappedf(fire_heat, 0.1), ")",
				" heater_off=", heater_off, " stew=", stew_ok, " snow=", snow_ok, " summer=", snappedf(summer_air, 0.1), " hot=", hot_ok, " save=", save_ok, " off=", off_ok, " ", "OK" if ok else "FAIL")
		"events2":
			# 14.3 вторая часть: кислотный дождь, мороз, зной, затмение, туман, вредители, капсула, жила, вторжения к штабу
			var E = game.events
			var f = game.factory
			var pl = game.player
			var EN = game.enemies
			game.flags["god"] = false
			game.flags["free_build"] = true
			game.day_t = 0.5
			pl.position = f.hq.center() + Vector3(30, 0, 30)
			# кислотный дождь: жжёт героя снаружи, портит здания, капли
			var box = put_near(game, "chest", World.world_to_cell(pl.position) + Vector2i(4, 0))
			E.start("acid_rain")
			pl.hp = pl.maxhp
			var bhp: float = box.hp if box else 0.0
			E._hazards(5.0, false)
			for i in 20:
				E._update_visuals(0.5)
			var acid_ok: bool = pl.hp < pl.maxhp and box != null and box.hp < bhp and E.rain > 0.5 and E._rain != null and E._rain.emitting
			E.finish("acid_rain")
			pl.hp = pl.maxhp
			# мороз
			var air0: float = game.climate.air_now()
			E.start("frost")
			for i in 40:
				E._update_visuals(0.5)
			var frost_ok: bool = game.climate.air_now() < air0 - 25.0 and E.snow > 0.3
			E.finish("frost")
			# зной
			E.start("heatwave")
			var heat_ok: bool = game.climate.air_now() > air0 + 12.0 and E.thirst_mult() >= 1.9
			E.finish("heatwave")
			# затмение
			var sun0: float = game.sun_power()
			E.start("eclipse")
			for i in 30:
				E._update_visuals(0.5)
			var eclipse_ok: bool = game.is_night() and game.sun_power() < sun0 * 0.3
			E.finish("eclipse")
			E.dark = 0.0
			# туман
			var vr0: float = game.view_range()
			E.start("dense_fog")
			for i in 30:
				E._update_visuals(0.5)
			var fog_ok: bool = game.view_range() < vr0 * 0.6
			E.finish("dense_fog")
			E.fog = 0.0
			# вредители едят еду со склада
			var store = put_near(game, "chest", f.hq.cell + Vector2i(-6, 6))
			if store:
				store.inv.add("berry", 20)
			E.start("locusts")
			var pests: Array = E.spawned.get("locusts", [])
			for m in pests:
				m.hp = 99999.0
				if store:
					m.pos = store.center() + Vector3(1.0, 0, 0)
			for i in 3:
				E._pests(1.0)
			var pests_ok: bool = pests.size() >= 5 and E.eaten > 0 and store != null and store.inv.count("berry") < 20 and pests[0].target == store
			E.finish("locusts")
			# капсула с добычей и меткой на карте
			var marks0: int = game.marks.size()
			E.start("capsule_crash")
			var cap_ok: bool = E.capsules.size() == 1 and game.marks.size() == marks0 + 1 and E.capsules[0][0].inv.first_item() != ""
			var guards_ok: bool = E.spawned.get("capsule_crash", []).size() == 2
			if E.capsules.size() == 1:
				var cb = E.capsules[0][0]
				for sl in cb.inv.slots.duplicate():
					if sl != null:
						cb.inv.remove(sl.id, sl.n)
				E._check_capsules()
			var cap_done: bool = E.capsules.is_empty() and game.marks.size() == marks0
			# жила
			var n0: int = game.world.nodes.size()
			E.start("rich_vein")
			var vein_ok: bool = game.world.nodes.size() >= n0 + 7 and game.marks.size() == marks0 + 1
			# вторжение идёт к штабу
			E.start("gnome_raid")
			var raid: Array = E.spawned.get("gnome_raid", [])
			var raid_ok: bool = raid.size() >= 6 and raid.all(func(m): return m.target == f.hq and not m.hunt)
			for e in EN.list.duplicate():
				EN.vanish(e)
			for id in E.active.keys():
				E.finish(id)
			var ok: bool = acid_ok and frost_ok and heat_ok and eclipse_ok and fog_ok and pests_ok and cap_ok and guards_ok and cap_done and vein_ok and raid_ok
			print("TEST events2 acid=", acid_ok, " frost=", frost_ok, " heat=", heat_ok, " eclipse=", eclipse_ok, " fog=", fog_ok, " pests=", pests_ok, "(", E.eaten, ")",
				" capsule=", cap_ok, " guards=", guards_ok, " cap_done=", cap_done, " vein=", vein_ok, " raid=", raid_ok, " ", "OK" if ok else "FAIL")
		"tris":
			# сколько треугольников рисует каждая группа (для поиска тяжёлых моделей)
			for id in ["tree_pine", "rock_small", "tree_birch"]:
				for p in ModelLib.merged_parts(id, false):
					var d: Dictionary = RenderingServer.mesh_get_surface(p[0].get_rid(), 0)
					var ls := ""
					ls = str(d.get("lods", []).size())
					print("LOD ", id, " base=", int(d.get("index_count", 0)) / 3, " lods=", ls)
			big_base(game, 2400, 220, 90)
			for i in 30:
				await tree.process_frame
			var rows := []
			var roots := {"factory": game.factory, "enemies": game.enemies, "world": game.world, "drops": game.drops, "fx": game.fx}
			var tot := 0
			for rn in roots:
				var stack: Array = [roots[rn]]
				var per := {}
				while not stack.is_empty():
					var n = stack.pop_back()
					for c in n.get_children():
						stack.append(c)
					if n is MultiMeshInstance3D and n.multimesh and n.multimesh.mesh and n.visible:
						var mm: MultiMesh = n.multimesh
						var cnt: int = mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
						var tri := 0
						for si in mm.mesh.get_surface_count():
							var ia = mm.mesh.surface_get_arrays(si)
							var idx = ia[Mesh.ARRAY_INDEX]
							tri += (idx.size() if idx != null and idx.size() > 0 else ia[Mesh.ARRAY_VERTEX].size()) / 3
						var key: String = rn + ":" + str(n.get_parent().get("model_id") if n.get_parent().get("model_id") != null else n.get_parent().name)
						var shadow: bool = n.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
						if not per.has(key):
							per[key] = [0, 0, 0]
						per[key][0] += tri * cnt
						per[key][1] += 1
						per[key][2] += tri * cnt if shadow else 0
					elif n is MeshInstance3D and n.mesh and n.visible:
						var tri2 := 0
						for si in n.mesh.get_surface_count():
							var ia2 = n.mesh.surface_get_arrays(si)
							var idx2 = ia2[Mesh.ARRAY_INDEX]
							tri2 += (idx2.size() if idx2 != null and idx2.size() > 0 else ia2[Mesh.ARRAY_VERTEX].size()) / 3
						var key2: String = rn + ":mesh:" + str(n.get_parent().name)
						if not per.has(key2):
							per[key2] = [0, 0, 0]
						per[key2][0] += tri2
						per[key2][1] += 1
				for k in per:
					rows.append([per[k][0], k, per[k][1], per[k][2]])
					tot += per[k][0]
			rows.sort_custom(func(a, b): return a[0] > b[0])
			print("TRIS total=", tot)
			for r in rows.slice(0, 30):
				print("TRIS ", r[1], " tris=", r[0], " nodes=", r[2], " shadow_tris=", r[3])
			print("TEST tris OK")
		"perf":
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("--perf_profile=") and arg.substr(15) in ["low","medium","high"]:
					Prefs.values["quality"] = arg.substr(15)
					Prefs._apply_quality(str(Prefs.values["quality"]))
			# замер скорости на большой базе: сколько миллисекунд занимает каждая часть кадра
			game.flags["god"] = true
			big_base(game, 2400, 220, 90)
			var fr := 300
			for ua in OS.get_cmdline_user_args():
				if ua.begins_with("--perf_frames="):
					fr = int(ua.substr(14))
				if ua.begins_with("--perf_lod="):
					Prefs.values["lod_px"] = float(ua.substr(11))
					Prefs.apply("lod_px")
				if ua == "--perf_stations":
					DB.data.settings["power_mode"] = "stations"
					game.factory.power_dirty = true
				if ua.begins_with("--perf_anim="):
					Prefs.values["live_anim_max"] = int(ua.substr(12))
					Prefs.values["live_anim_dist"] = 60
			for i in mini(60, fr):
				await tree.process_frame
			game.prof_on = true
			game.prof.clear()
			game.factory.prof_tick = 0
			game.factory.prof_ticks = 0
			var t0 := Time.get_ticks_usec()
			var worst := 0
			var last := Time.get_ticks_usec()
			var spikes := []
			for i in fr:
				var snap: Dictionary = game.prof.duplicate()
				snap["factory.tick"] = game.factory.prof_tick
				await tree.process_frame
				var now := Time.get_ticks_usec()
				worst = maxi(worst, now - last)
				if now - last > 35000 and spikes.size() < 8:
					var cur: Dictionary = game.prof.duplicate()
					cur["factory.tick"] = game.factory.prof_tick
					var top := []
					for k in cur:
						var dv: int = int(cur[k]) - int(snap.get(k, 0))
						if dv > 4000:
							top.append("%s=%.0f" % [k, dv / 1000.0])
					spikes.append("%.0fms[%s]" % [(now - last) / 1000.0, ",".join(top)])
				last = now
			var total: float = (Time.get_ticks_usec() - t0) / 1000.0 / fr
			game.prof["factory.tick"] = game.factory.prof_tick
			var keys: Array = game.prof.keys()
			keys.sort_custom(func(a, b): return game.prof[a] > game.prof[b])
			var parts := []
			for k in keys.slice(0, 22):
				parts.append("%s=%.2f" % [k, game.prof[k] / 1000.0 / fr])
			print("PERF frame_ms=%.2f worst_ms=%.1f buildings=%d enemies=%d draw_calls=%d objects=%d prims=%d" % [total, worst / 1000.0, game.factory.all.size(), game.enemies.list.size(),
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
			print("PERF parts_ms ", " ".join(parts))
			print("PERF spikes ", " ".join(spikes))
			print("TEST perf OK")
		"perf15":
			# 1.5: обычное начало игры — сколько стоит кадр и что тормозит при открытии участка тумана
			for i in 60:
				await tree.process_frame
			game.prof_on = true
			var measure := func(frames: int) -> Array:
				game.prof.clear()
				game.factory.prof_tick = 0
				var t0 := Time.get_ticks_usec()
				var last := t0
				var worst := 0
				var worst_parts := ""
				for i in frames:
					var snap: Dictionary = game.prof.duplicate()
					await tree.process_frame
					var now := Time.get_ticks_usec()
					if now - last > worst:
						worst = now - last
						var top := []
						for k in game.prof:
							var dv: int = int(game.prof[k]) - int(snap.get(k, 0))
							if dv > 2000:
								top.append("%s=%.0f" % [k, dv / 1000.0])
						worst_parts = ",".join(top)
					last = now
				var keys: Array = game.prof.keys()
				keys.sort_custom(func(a, b): return game.prof[a] > game.prof[b])
				var parts := []
				for k in keys.slice(0, 12):
					parts.append("%s=%.2f" % [k, game.prof[k] / 1000.0 / frames])
				return [(Time.get_ticks_usec() - t0) / 1000.0 / frames, worst / 1000.0, " ".join(parts), worst_parts]
			var m1: Array = await measure.call(300)
			print("PERF15 normal frame_ms=%.2f worst_ms=%.1f parts: %s | worst: %s" % m1)
			var zn = game.zone
			var rc: Vector2i = zn.patch_at(game.player.position + Vector3(zn.half() + 6.0, 0, 0))
			var t_open := Time.get_ticks_usec()
			var opened: bool = zn.open_patch(rc, true)
			var open_ms := (Time.get_ticks_usec() - t_open) / 1000.0
			var m2: Array = await measure.call(60)
			print("PERF15 patch opened=%s open_call_ms=%.1f frame_ms=%.2f worst_ms=%.1f parts: %s | worst: %s" % [opened, open_ms, m2[0], m2[1], m2[2], m2[3]])
			game.player.position += Vector3(zn.half() + 6.0, 0, 0)
			var m3: Array = await measure.call(120)
			print("PERF15 walk_in frame_ms=%.2f worst_ms=%.1f parts: %s | worst: %s" % m3)
			print("TEST perf15 OK")
		"net_host":
			# сетевая игра (вместе с --net_join у второй копии): ждём гостя, даём ему монстра, проверяем его действия
			var N = Net._self()
			# 14.23: площадка НЛО с заказом и заражённая земля — гость должен их видеть
			game.flags["free_build"] = true
			var pc: Vector2i = game.factory.hq.cell + Vector2i(-12, -12)
			for dx in range(-3, 4):
				for dz in range(-3, 4):
					game.world.remove_node(World.wc(pc + Vector2i(dx, dz)))
			var npad = put_near(game, "ufo_pad", pc)
			Starworks.st(npad).orders = [{"id": "helium3", "n": 7}]
			Starworks.st(npad).ufo_t = 5000.0
			game.hazards.contaminate(World.cell_to_world(pc + Vector2i(20, 0)), 4.0, 30.0)
			# 16: ящик хозяина (гостю можно только класть) и рынок хозяина с железом по 5 кр
			var hch = put_near(game, "chest", game.factory.hq.cell + Vector2i(-9, 9))
			hch.bstate["owner"] = N.nick
			hch.inv.add("stone", 10)
			var hmk = put_near(game, "player_market", game.factory.hq.cell + Vector2i(14, -6))
			hmk.bstate["owner"] = N.nick
			hmk.inv.add("iron_ingot", 20)
			hmk.cfg = {"prices": {"iron_ingot": 5}}
			game.flags["free_build"] = false
			var hc0: int = game.credits
			var joined := false
			var t_join := Time.get_ticks_msec() + 200000
			while Time.get_ticks_msec() < t_join:
				await tree.process_frame
				if N.puppets.size() > 0:
					joined = true
					break
			var gid: int = N.puppets.keys()[0] if joined else 0
			var pp = N.puppets.get(gid)
			for i in 30:
				await tree.process_frame
			var e = game.enemies.spawn("crawler", (pp.position if pp else game.player.position) + Vector3(14, 0, 0)) if joined else null
			if e:
				e.hp = 500.0
				e.maxhp = 500.0
			var cell: Vector2i = game.factory.hq.cell + Vector2i(9, 9)
			var placed := false
			var got_chat := false
			var hit := false
			var stored := false
			var t_end := Time.get_ticks_msec() + 200000
			var r16 := false
			var planted14 := false
			while Time.get_ticks_msec() < t_end:
				await tree.process_frame
				var b = game.factory.building_at(cell)
				placed = b != null and b.type == "chest"
				stored = stored or (placed and b.inv.count("plank") >= 5)   # 1.5: гость потом докладывает ещё (net_inv15)
				hit = e != null and e.hp < 500.0
				got_chat = N.chat_log.any(func(c): return str(c[2]) == "привет от гостя")
				var g_orders: bool = npad != null and (Starworks.st(npad).orders as Array).size() == 2
				var g_tune: bool = npad != null and int(npad.cfg.get("tune", 0)) == 77
				r16 = hch.inv.count("stone") == 10 and hch.inv.count("plank") == 1 and game.credits == hc0 + 70 and hmk.inv.count("iron_ingot") == 10 and game.coop.seen.has("confetti") and int(N.get_meta("refused_n", 0)) >= 1
				planted14 = planted14 or game.world.nodes.values().any(func(nd): return str(nd.res) == "young_birch")
				if placed and stored and hit and got_chat and g_orders and g_tune and r16 and planted14:
					for j in 200:
						await tree.process_frame   # гость ещё проверяет, что видит хозяина
					break
			# 18: вещи и уровень гостя хранятся у хозяина; мир комнаты сохраняется в свою ячейку net_…
			var me_ok := false
			for i in 900:
				await tree.process_frame
				if int(N.saved.get("Гость", {}).get("me", {}).get("level", 0)) == 7:
					me_ok = true
					break
			# 1.7: гостевая линия лент повёрнута по ходу, печи гостя объединены и у хозяина, задания гостя хранятся у хозяина
			var A17: Vector2i = game.factory.hq.cell + Vector2i(9, 14)
			var line17 := true
			for k in 4:
				var bb = game.factory.building_at(A17 + Vector2i(k, 0))
				line17 = line17 and bb != null and bb.beh == "belt" and bb.dir == 0
			var fz17 = game.factory.building_at(A17 + Vector2i(0, 2))
			var fused17: bool = fz17 != null and fz17.type == "furnace" and fz17.lvl == 2
			var q17: bool = N.saved.get("Гость", {}).get("me", {}).has("quest_i")
			print("TEST net_host17 guest_line=", line17, " guest_fuse=", fused17, " guest_quests_kept=", q17, " ", "OK" if line17 and fused17 and q17 else "FAIL")
			game.save_game("autosave", true)
			var rslot: String = N.room_slot()
			var slot_ok: bool = rslot.begins_with("net_") and SavesUI.exists(rslot) and str(SavesUI.info(rslot).get("room", "")) == "Проверка" and SavesUI.net_slots().has(rslot)
			var sd18 = DB.read_file(SavesUI.path(rslot))
			var kept: bool = sd18 is Dictionary and int(sd18.get("net_players", {}).get("Гость", {}).get("me", {}).get("level", 0)) == 7
			var rec18: Dictionary = N._player_record("Гость")
			var shared_scan: bool = DB.researched.has("quartz")
			print("TEST net_save18 guest_state=", me_ok, " slot=", rslot, " slot_ok=", slot_ok, " in_save=", kept, " record_inv=", (rec18.get("inv", []) as Array).size(), " shared_scan=", shared_scan, " ",
				"OK" if me_ok and slot_ok and kept and shared_scan and (rec18.get("inv", []) as Array).size() > 0 else "FAIL")
			var orders2: bool = npad != null and (Starworks.st(npad).orders as Array).size() == 2
			var tune2: bool = npad != null and int(npad.cfg.get("tune", 0)) == 77
			# 1.0.8: гость вошёл «через интернет» — хозяин получил запрос и слал пакеты на тот порт, с которого гость пришёл
			if OS.get_cmdline_user_args().has("--lobby_url=http://127.0.0.1:8099"):
				var rports := []
				var mp = N.multiplayer.multiplayer_peer
				if mp is ENetMultiplayerPeer:
					for pid in N.peers:
						if int(pid) != 1 and mp.get_peer(int(pid)) != null:
							rports.append(mp.get_peer(int(pid)).get_remote_port())
				var pk_ok: bool = N.lobby.punched >= 1 and rports.any(func(x): return N.lobby.punch_ports.has(x)) and N.port == 443
				print("TEST net_punch19 punched=", N.lobby.punched, " punch_ports=", N.lobby.punch_ports.keys(), " guest_ports=", rports, " room_port=", N.port, " ", "OK" if pk_ok else "FAIL")
			print("TEST net_host16 refused_wrong_pass=", int(N.get_meta("refused_n", 0)), " chest_stone=", hch.inv.count("stone"), " chest_plank=", hch.inv.count("plank"), " host_credits=", game.credits - hc0, " market_left=", hmk.inv.count("iron_ingot"), " fun=", game.coop.seen.keys(), " ", "OK" if r16 else "FAIL")
			print("TEST net_host joined=", joined, " placed=", placed, " stored=", stored, " hit=", hit, " chat=", got_chat, " guest_orders=", orders2, " guest_tune=", tune2, " guest_sapling=", planted14, " ",
				"OK" if joined and placed and stored and hit and got_chat and orders2 and tune2 and r16 and planted14 else "FAIL")
		"monsters":
			# 14.4 около 500 монстров: семейства, скелеты всех видов, варианты окраски, умения
			var EN = game.enemies
			var pl = game.player
			game.flags["god"] = false
			var all: Dictionary = DB.data.enemies
			var fams := {}
			for id in all:
				if all[id].has("family"):
					fams[all[id].family] = true
			var models := {}
			for id in all:
				models[str(all[id].get("model", id))] = true
			var rig_ok := 0
			var rig_bad := []
			for mid in models:
				var rg = preload("res://scripts/creature_rig.gd").new()
				if rg.build(mid):
					rig_ok += 1
				elif ModelLib.model(mid).has("rig"):
					rig_bad.append(mid)
				rg.free()
			# 13.10: только роботы — ни одного старого монстра, у всех модель «Роботы» со скелетом
			var tinted := true
			for id in all:
				var bh := str(all[id].get("behavior", ""))
				if not bh in ["trader", "traveler", "bandit", "infiltrator"] and not str(all[id].get("model", "")).begins_with("mech_"):
					tinted = false
			var auto: int = EN.auto_groups().size()
			game.day_n = 40
			var picked := {}
			for i in 200:
				var t: String = EN._pick_type(DB.data.waves.get("groups", []))
				if all.get(t, {}).has("family"):
					picked[t] = true
			game.day_n = 1
			for e in EN.list.duplicate():
				EN.vanish(e)
			var base: Vector3 = pl.position
			# полёт
			var fly = EN.spawn("drone", base + Vector3(20, 0, 20))
			# телепорт
			var blink = EN.spawn("sniper", base + Vector3(-22, 0, 0))
			if blink:
				blink.target = pl
				blink.tp_t = 0.1
			# призыв
			var scream = EN.spawn("carrier", base + Vector3(0, 0, -24))
			if scream:
				scream.target = pl
				scream.sum_t = 0.1
			# лечение
			var healer = EN.spawn("medic", base + Vector3(30, 0, -30))
			var hurt = EN.spawn("crawler_t2", base + Vector3(31, 0, -30))
			if healer and hurt:
				healer.target = pl
				healer.heal_t = 0.1
				hurt.hp = hurt.maxhp * 0.3
			var hurt_hp0: float = hurt.hp if hurt else 0.0
			# кража
			pl.inv.add("plank", 30)
			var planks0: int = pl.inv.count("plank")
			var thief = EN.spawn("thief", base + Vector3(1.0, 0, 0))
			if thief:
				thief.target = pl
				thief.cd = 0.0
			for i in 90:
				await tree.process_frame
			var flying: bool = fly != null and fly.alive and fly.pos.y > game.factory.support_at(fly.pos) + 1.5
			var teleported: bool = blink != null and blink.alive and World.dist(blink.pos, pl.position) < 10.0
			var summoned: int = scream.kids if scream else 0
			var healed: bool = hurt != null and hurt.hp > hurt_hp0
			var stolen: bool = pl.inv.count("plank") < planks0 and thief != null and not thief.stolen.is_empty() and thief.flee_t > 0.0
			var drops0: int = game.drops.list.size()
			if thief and thief.alive:
				EN.hit(thief, 9999.0, true)
			for i in 5:
				await tree.process_frame
			var dropped: bool = game.drops.list.size() > drops0
			# взрыв
			pl.hp = pl.maxhp
			var hp0: float = pl.hp
			var fat = EN.spawn("bomber", pl.position + Vector3(1.0, 0, 0))
			if fat:
				fat.target = pl
				fat.cd = 0.0
			for i in 60:
				await tree.process_frame
				if fat and not fat.alive:
					break
			var exploded: bool = fat != null and not fat.alive and pl.hp < hp0
			var ok: bool = all.size() >= 60 and fams.size() == 1 and rig_bad.is_empty() and rig_ok >= 12 and tinted and auto >= 40 and picked.size() >= 6 \
				and flying and teleported and summoned > 0 and healed and stolen and dropped and exploded
			print("TEST monsters count=", all.size(), " families=", fams.size(), " rigs=", rig_ok, " bad=", rig_bad, " tinted=", tinted, " auto=", auto, " picked_fams=", picked.size(),
				" fly=", flying, " teleport=", teleported, " summon=", summoned, " heal=", healed, " steal=", stolen, " dropped=", dropped, " explode=", exploded, " ",
				"OK" if ok else "FAIL")
		"rework":
			# 13.10 переделка: зона бури, залежи под один бур, добыча руками, сканер, оборона, углы ленты
			var f = game.factory
			var w = game.world
			var Z = game.zone
			var pl = game.player
			game.flags["god"] = true
			for e in game.enemies.list.duplicate():
				game.enemies.vanish(e)
			# зона: старт 10×10 блоков, снаружи строить нельзя, расширение стоит ресурсов
			var z_on: bool = Z.on() and Z.blocks == int(DB.data.settings.zone.get("start_blocks", 10))
			var hq_c: Vector2i = World.world_to_cell(Z.center)
			var far_c: Vector2i = hq_c + Vector2i(int(Z.half() / World.C) + 4, 0)
			var in_ok: bool = Z.inside_cell(hq_c) and not Z.inside_cell(far_c)
			var blocked: bool = f.can_place("chest", far_c).begins_with("За стеной бури")
			var cost: Dictionary = Z.next_cost()
			var poor: bool = not cost.is_empty() and Z.can_expand() != ""
			for it in cost:
				f.hq.inv.add(it, int(cost[it]))
			var b0: int = Z.blocks
			var expanded: bool = Z.expand() and Z.blocks == b0 + 1
			var paid := true
			for it in cost:
				if f.hq.inv.count(it) != 0:
					paid = false
			# форма: не квадрат — угол квадрата под тучами; волна роботов выходит прямо из туч на краю
			var hz: float = Z.half()
			var round_ok: bool = Z.sd(Z.center + Vector3(hz * 0.97, 0, hz * 0.97)) > 0.0 and Z.inside(Z.center + Vector3(hz * 0.5, 0, 0))
			for e in game.enemies.list.duplicate():
				game.enemies.vanish(e)
			game.enemies.start_wave()
			var edge_n := 0
			var wave_n: int = game.enemies.list.size()
			for e in game.enemies.list:
				if absf(Z.sd(e.pos)) < 4.0:
					edge_n += 1
			var at_edge: bool = wave_n > 0 and edge_n == wave_n
			for e in game.enemies.list.duplicate():
				game.enemies.vanish(e)
			# залежи: рудная — одна клетка (влезает ровно один бур), рядом нет таких же клеток
			var single := true
			var dep_n := 0
			var near_iron := false
			for c in w.deposit:
				var it: String = w.deposit_item(c)
				if DB.is_fluid(it) or int(w.deposits[w.deposit[c]].get("cells", 1)) != 1:
					continue
				dep_n += 1
				for dx in [-1, 0, 1]:
					for dz in [-1, 0, 1]:
						if (dx != 0 or dz != 0) and w.deposit.has(World.wc(c + Vector2i(dx, dz))) and w.deposit_item(World.wc(c + Vector2i(dx, dz))) == it:
							if single:
								print("REWORK adjacent ", it, " ", c, " ", c + Vector2i(dx, dz))
							single = false
				if it == "iron_ore" and Z.inside_cell(c):
					near_iron = true
			# качество залежей: разные встречаются; бур Mk1 = «в минуту» качества, MkN = ×N; ленты Mk1–Mk5
			var kinds := {}
			for c in w.deposit:
				var pq: Dictionary = w.purity_of(c)
				if not pq.is_empty():
					kinds[str(pq.id)] = true
			var pc: Vector2i = nearest_deposit(game, "copper_ore", hq_c)
			w.set_purity(pc, "rich")
			var m1 = put(game, "miner", pc, 0)
			var r1: float = f.miner_rate(m1) if m1 else 0.0
			if m1:
				f.remove(m1)
			var m3 = put(game, "miner_mk3", pc, 0)
			var r3: float = f.miner_rate(m3) if m3 else 0.0
			# за 10 секунд бур Mk3 на богатой залежи (480 в минуту, ×4) даёт ~80 штук (выход забирается)
			var got := 0
			var p3 = DB.data.buildings["miner_mk3"].params.get("power", 0)
			DB.data.buildings["miner_mk3"].params["power"] = 0   # без энергосети для проверки
			if m3:
				for i in 250:
					f._miner(m3, f.TICK)
					got += m3.out.count(m3.recipe)
					m3.out.remove(m3.recipe, m3.out.count(m3.recipe))
				f.remove(m3)
			DB.data.buildings["miner_mk3"].params["power"] = p3
			var pur_ok: bool = kinds.size() >= 3 and is_equal_approx(r1, 120.0) and is_equal_approx(r3, 480.0) and got >= 78 and got <= 81
			var belt_ok: bool = is_equal_approx(f.belt_rate("belt") * 60.0, 60.0) and is_equal_approx(f.belt_rate("belt_mk5") * 60.0, 780.0) and 60.0 / 1360.0 > f.TICK
			# зловещие надписи: перед событием (заранее, событие начинается позже), перед волной роботов
			var EV = game.events
			game.hud.last_omen = ""
			EV.show_omen("earthquake")
			var om_ev: bool = game.hud.last_omen == str(DB.data.events.earthquake.omen) and game.hud.omen_lbl.visible
			EV.pending["storm"] = 0.5
			EV.update(1.05)
			var om_later: bool = EV.active.has("storm") and not EV.pending.has("storm")
			game.hud.last_omen = ""
			game.enemies.wave_timer = 3.0
			game.enemies.update(0.1)
			var om_wave: bool = game.hud.last_omen == str(DB.data.waves.omen)
			game.enemies.wave_timer = 400.0
			var omen_ok: bool = om_ev and om_later and om_wave
			# кислотный зонтик: в рюкзаке снимает урон кислотного дождя и изнашивается; без него — урон
			game.flags["god"] = false
			var plh = game.player
			plh.hp = plh.maxhp
			var hz_acid: bool = DB.data.recipes.has("acid_umbrella") and "hand" in DB.data.recipes.acid_umbrella.get("stations", [])
			EV.active.clear()
			EV.active["acid_rain"] = 60.0
			plh.inv.add("acid_umbrella", 1)
			var hp_a: float = plh.hp
			EV._hazards(1.0, false)
			var slot_u = null
			for sl in plh.inv.slots:
				if sl != null and sl.id == "acid_umbrella":
					slot_u = sl
			var guarded: bool = plh.hp == hp_a and slot_u != null and float(slot_u.get("dur", 60)) < 60.0 and EV._guard_node != null
			for i in plh.inv.slots.size():
				if plh.inv.slots[i] != null and plh.inv.slots[i].id == "acid_umbrella":
					plh.inv.slots[i] = null
			EV._hazards(1.0, false)
			var hurt: bool = plh.hp < hp_a
			EV.active.clear()
			EV._hazards(1.0, false)
			plh.hp = plh.maxhp
			game.flags["god"] = true
			var umb_ok: bool = hz_acid and guarded and hurt
			# мусорка: выбросить стопку и вернуть
			var ti: int = -1
			plh.inv.add("stone", 7)
			for i in plh.inv.slots.size():
				if plh.inv.slots[i] != null and plh.inv.slots[i].id == "stone":
					ti = i
			var st0: int = plh.inv.count("stone")
			game.hud.trash(plh.inv, ti)
			var gone_ok: bool = plh.inv.count("stone") < st0
			game.hud.untrash()
			var trash_ok: bool = gone_ok and plh.inv.count("stone") == st0
			# добыча руками/киркой прямо с залежи
			var dc: Vector2i = nearest_deposit(game, "iron_ore", hq_c)
			var drops0: int = game.drops.list.size()
			var mined := false
			for i in 10:
				if w.mine_deposit(dc, 10.0, "pickaxe"):
					mined = true
			var dropped: bool = mined and game.drops.list.size() > drops0
			var drill_ok: bool = f.can_place("miner", dc) == ""
			# сканер: найденное, но не изученное нельзя в рецептах; неизвестное — безымянно
			var S = game.scanner
			var unknown_name: bool = DB.discovery and not DB.is_known("circuit") and DB.item_name("circuit") == "Неизвестный ресурс"
			var rid := ""
			for r in DB.data.recipes:
				if DB.data.recipes[r].get("in", {}).has("iron_ore") and DB.data.recipes[r].get("in", {}).size() == 1:
					rid = r
			DB.researched.erase("iron_ore")
			S.prog.erase("iron_ore")
			pl.inv.add("iron_ore", 40)
			S._t = 0.0
			S.update(0.1)
			var found: bool = DB.is_known("iron_ore")
			var hidden: bool = rid != "" and not DB.recipe_known(rid)
			var scanned: int = S.scan("iron_ore")
			var opened: bool = DB.is_researched("iron_ore") and DB.recipe_known(rid) and scanned == DB.scan_need("iron_ore")
			if not S.on():
				# 1.5: изучения нет — всё названо своими именами, рецепты открыты
				unknown_name = DB.item_name("circuit") != "Неизвестный ресурс"
				hidden = rid != "" and DB.recipe_known(rid)
				opened = hidden
			# оборона: щит принимает урон, стазис замедляет, пушка бьёт по площади, ремонт чинит
			var saved_p := {}
			for t in ["barrier_small", "stasis_field", "repair_tower"]:
				saved_p[t] = DB.data.buildings[t].params.get("power", 0)
				DB.data.buildings[t].params["power"] = 0
			var base: Vector2i = hq_c + Vector2i(-8, 6)
			var bar = put(game, "barrier_small", base, 0)
			var sta = put(game, "stasis_field", base + Vector2i(6, 0), 0)
			var can = put(game, "cannon_turret", base + Vector2i(0, 6), 0)
			var rep = put(game, "repair_tower", base + Vector2i(-4, 0), 0)
			f.hq.inv.add("ammo", 50)
			game.defense._scan_t = 0.0
			game.defense.update(0.1)
			var left: float = game.defense.absorb(bar.center() if bar else Vector3.ZERO, 100.0) if bar else 100.0
			var soaked: bool = bar != null and left == 0.0 and game.defense.state(bar).hp < float(bar.p("barrier_hp"))
			if not soaked: print("DBG shield bar=", bar != null, " left=", left, " why=", f.can_place("barrier_small", base) if bar == null else "")
			var cpos: Vector3 = (sta.center() if sta else pl.position) + Vector3(1.5, 0, 0)
			var slow_e = game.enemies.spawn("crawler", cpos)
			var e1 = game.enemies.spawn("brute", (can.center() if can else pl.position) + Vector3(12, 0, 0))
			var e2 = game.enemies.spawn("brute", (can.center() if can else pl.position) + Vector3(13.2, 0, 0.6))
			for e in [slow_e, e1, e2]:
				if e:
					e.target = null
			var e2hp: float = e2.hp if e2 else 0.0
			if can and e1:
				can.target = e1
				can.cd = 0.0
			if rep:
				rep.hp = maxf(1.0, rep.hp * 0.5)
			var rep_hp: float = rep.hp if rep else 0.0
			for i in 90:
				game.defense.update(1.0 / 60.0)
				await tree.process_frame
			var slowed: bool = slow_e != null and slow_e.slow_k < 1.0
			var splashed: bool = e2 != null and (not e2.alive or e2.hp < e2hp)
			var repaired: bool = rep != null and rep.hp > rep_hp
			for t in saved_p:
				DB.data.buildings[t].params["power"] = saved_p[t]
			# углы ленты: длинные детали прямой ленты гнутся по дуге кусками, короткие просто поворачиваются
			var long_parts: Array = f._bend_part(Transform3D(Basis.from_scale(Vector3(2.0, 0.1, 0.1)), Vector3(0, 0.2, 0.6)), 1)
			var short_parts: Array = f._bend_part(Transform3D(Basis.from_scale(Vector3(0.1, 0.2, 0.1)), Vector3(0.4, 0.1, -0.6)), -1)
			var bent: bool = long_parts.size() == 6 and short_parts.size() == 1
			var ok: bool = umb_ok and trash_ok and omen_ok and pur_ok and belt_ok and round_ok and at_edge and z_on and in_ok and blocked and poor and expanded and paid and single and dep_n > 10 and near_iron and dropped and drill_ok \
				and unknown_name and found and hidden and opened and soaked and slowed and splashed and repaired and bent
			print("TEST rework umbrella=", hz_acid, "/", guarded, "/", hurt, " trash=", trash_ok, " omen=", om_ev, "/", om_later, "/", om_wave, " purity=", kinds.keys(), " mk1=", r1, " mk3=", r3, " got10s=", got, " belts=", belt_ok, " round=", round_ok, " wave_edge=", edge_n, "/", wave_n, " zone=", z_on, " inside=", in_ok, " blocked=", blocked, " poor=", poor, " expand=", expanded, " paid=", paid,
				" single=", single, " deps=", dep_n, " near_iron=", near_iron, " hand=", dropped, " drill=", drill_ok,
				" unknown=", unknown_name, " found=", found, " hidden=", hidden, " scan=", opened, " shield=", soaked, " slow=", slowed,
				" splash=", splashed, " repair=", repaired, " belt=", bent, " ", "OK" if ok else "FAIL")
		"rules":
			# 14.5 правила поведения блоками у монстров + дроны по маршруту между складами с метками
			var EN = game.enemies
			var pl = game.player
			var f = game.factory
			game.flags["god"] = true
			game.flags["free_build"] = true
			for e in EN.list.duplicate():
				EN.vanish(e)
			var base: Vector3 = pl.position
			# свой монстр: «если здоровья меньше 50% → убегать»
			var rec: Dictionary = DB.data.enemies["crawler"].duplicate(true)
			rec["rules"] = [{"if": "hp_below", "n": 0.5, "then": "flee"}, {"if": "always", "then": "attack_player"}]
			DB.data.enemies["test_rule_mob"] = rec
			var coward = EN.spawn("test_rule_mob", base + Vector3(6, 0, 0))
			var chief = EN.spawn("boss_titan", base + Vector3(-20, 0, 18))
			var queen = EN.spawn("boss_hive", base + Vector3(18, 0, -18))
			var guard = EN.spawn("guard", base + Vector3(-40, 0, -40))
			var berserk = EN.spawn("brute", base + Vector3(25, 0, 25))
			var troll = EN.spawn("boss_hive", base + Vector3(-25, 0, 30))
			for i in 60:
				await tree.process_frame
				if coward and coward.rule_mode == "attack_player":
					break
			var attacking: bool = coward != null and coward.rule_mode == "attack_player" and coward.target == pl
			coward.maxhp = 100000.0   # герой рядом бьёт сам — чтобы трус не погиб раньше проверки
			coward.hp = coward.maxhp * 0.3
			var d0: float = World.dist(coward.pos, pl.position)
			if queen:
				EN.hit(queen, 1.0, true)
			if guard:
				guard.pos = guard.pos + Vector3(8, 0, 0)
			var sp0: float = berserk.speed if berserk else 0.0
			if berserk:
				berserk.hp = berserk.maxhp * 0.4
			var thp0 := 0.0
			if troll:
				troll.hp = troll.maxhp * 0.2
				thp0 = troll.hp
			var dmax := d0
			for i in 400:
				if coward.rule_mode == "flee" and dmax > d0 + 1.0 and (queen == null or queen.kids > 0) and (troll == null or troll.hp > thp0):
					break
				await tree.process_frame
				dmax = maxf(dmax, World.dist(coward.pos, pl.position))
			var fled: bool = coward.rule_mode == "flee" and dmax > d0 + 0.5
			var to_base: bool = chief != null and chief.rule_mode == "attack_base" and chief.target == f.hq
			var summoned: bool = queen != null and queen.kids > 0
			var home: bool = guard != null and guard.rule_mode == "go_home" and guard.home.is_equal_approx(guard.born_pos)
			var fast: bool = berserk != null and berserk.speed > sp0 * 1.3
			var healed: bool = troll != null and troll.hp > thp0
			# редактор: поля правила зависят от «Если» и «То»
			var ES = load("res://scripts/editor/schema.gd")   # в сборке игры редактора нет — грузим по пути
			var sf: Array = ES.sub_for("mob_rule", {"if": "hp_below", "then": "summon"})
			var keys := sf.map(func(x): return x[0])
			var ed_ok: bool = "n" in keys and "value" in keys and "enemy" in keys and ES.enum_table("MOB_IF").size() >= 15
			for e in EN.list.duplicate():
				EN.vanish(e)
			DB.data.enemies.erase("test_rule_mob")
			# дроны по маршруту: склад «А» → склад «Б»
			var hc: Vector2i = f.hq.cell
			var ca = put_near(game, "chest", hc + Vector2i(10, 8))
			var cb = put_near(game, "chest", hc + Vector2i(-10, 14))
			var hub = put_near(game, "drone_hub", hc + Vector2i(0, 12))
			var gen = put_near(game, "generator", (hub.cell if hub else hc) + Vector2i(3, 0))
			if gen and gen.fuel:
				gen.fuel.add("coal", 50)
			f.auto_wire_all()
			f.power_dirty = true
			var tagged := false
			if ca and cb:
				ca.cfg = {"x": 1}
				game.cmd("bcfg", {"b": ca, "cfg": {"x": 1, "tag": "A"}})
				game.cmd("bcfg", {"b": cb, "cfg": {"tag": "B"}})
				tagged = game.carriers.tag_ok(ca, "A") and game.carriers.tag_ok(cb, "B") and int(ca.cfg.get("x", 0)) == 1
				ca.inv.add("iron_plate", 25)
			var got := 0
			for i in 900:
				await tree.process_frame
				if hub and i % 30 == 0:
					hub.bstate["b0"] = 999.0   # не ждать «Рейс каждые»
				got = cb.inv.count("iron_plate") if cb else 0
				if got >= 20:
					break
			var route_ok: bool = got >= 20 and ca.inv.count("iron_plate") <= 5
			var ok: bool = attacking and fled and to_base and summoned and home and fast and healed and ed_ok and tagged and route_ok
			print("TEST rules attack=", attacking, " flee=", fled, " base=", to_base, " summon=", summoned, " home=", home, " speed=", fast, " heal=", healed,
				" editor=", ed_ok, " tag=", tagged, " route=", got, " ", "OK" if ok else "FAIL")
		"mods":
			# 14.6 конструктор в игре: своё здание и предмет → мод → один файл .fcmod → забрать обратно
			game.flags["free_build"] = true
			var f = game.factory
			var mid := ModKit.ensure("Тестовый мод")
			_rm_tree(ModKit.dir_of(mid))
			mid = ModKit.ensure("Тестовый мод")
			var ct := ModCtor.new(game.hud)
			ct.mod_id = mid
			ct.new_object("buildings")
			ct.rec["name"] = "Тест-башня"
			ct.rec["blocks"] = [{"type": "produce", "item": "stone", "n": 1, "every": 2.0, "needs_power": false}]
			ct.base_model = "chest"
			ct.extra = [{"shape": "cylinder", "size": [0.4, 2.0, 0.4], "pos": [0, 2.0, 0], "rot": [0, 0, 0], "color": "#40c0ff", "mat": "glow"}]
			var bid: String = ct.save()
			var crate_n: int = DB.model_def("chest").get("parts", []).size()
			var b_ok: bool = DB.data.buildings.has(bid) and DB.model_def(bid + "_model").get("parts", []).size() == crate_n + 1
			var placed = put_near(game, bid, f.hq.cell + Vector2i(8, -8))
			if placed and placed.out:
				placed.bstate["b0"] = 1.95
				for i in 400:
					await tree.process_frame
					if placed.out.count("stone") > 0:
						break
			var works: bool = placed != null and placed.out != null and placed.out.count("stone") > 0
			ct.new_object("items")
			ct.rec["name"] = "Тест-кристалл"
			ct.recipe = {"in": {"stone": 2}, "n": 3, "time": 1.0, "stations": ["hand"]}
			var iid: String = ct.save()
			var i_ok: bool = DB.data.items.has(iid) and DB.data.recipes.has(iid + "_recipe") and (iid + "_recipe") in DB.recipes_for("hand")
			# окно конструктора строится
			game.hud.open("constructor")
			for i in 5:
				await tree.process_frame
			var ui_ok: bool = game.hud.windows.constructor.body.get_child_count() > 5
			game.hud.close("constructor")
			# поделиться одним файлом и забрать у «друга»
			var pk := ModKit.pack(mid)
			var packed: bool = pk.ok and FileAccess.file_exists(pk.path) and pk.path.ends_with(".fcmod")
			_rm_tree(ModKit.dir_of(mid))
			DB.data.buildings.erase(bid)
			DB.data.items.erase(iid)
			var inst := ModKit.install(pk.path)
			var back: Dictionary = ModKit.contents(str(inst.get("id", "")))
			if inst.ok:
				ModKit.apply_now(inst.id)
			var restored: bool = inst.ok and back.buildings.has(bid) and back.items.has(iid) and DB.data.buildings.has(bid) and DB.data.items.has(iid)
			# чужой файл со скриптом и путём «наружу» — такое не берётся
			var evil := ModKit.share_dir().path_join("evil_test.fcmod")
			var zp := ZIPPacker.new()
			zp.open(evil)
			for nm in ["evil/mod.json", "evil/items.json", "evil/run.gd", "evil/../../escape.json"]:
				zp.start_file(nm)
				zp.write_file(("{}" if nm.ends_with(".json") else "extends Node").to_utf8_buffer())
				zp.close_file()
			zp.close()
			var ev := ModKit.install(evil)
			var safe: bool = ev.ok and int(ev.get("skipped", 0)) >= 2 and not FileAccess.file_exists(ModKit.dir_of(str(ev.get("id", ""))).path_join("run.gd")) \
				and not FileAccess.file_exists(DB.base_dir().path_join("escape.json"))
			# уборка
			_rm_tree(ModKit.dir_of(mid))
			_rm_tree(ModKit.dir_of(str(ev.get("id", "evil"))))
			DirAccess.remove_absolute(evil)
			DirAccess.remove_absolute(pk.path)
			var ok: bool = b_ok and works and i_ok and ui_ok and packed and restored and safe
			print("TEST mods building=", b_ok, " works=", works, " item=", i_ok, " ui=", ui_ok, " packed=", packed, " restored=", restored, " safe=", safe, " ",
				"OK" if ok else "FAIL")
		"sieges":
			# 14.7 осада с боссом: утром предупреждение, ночью босс со свитой, награда за победу
			var SG = game.sieges
			var EN = game.enemies
			game.flags["god"] = true
			for e in EN.list.duplicate():
				EN.vanish(e)
			var bosses := 0
			for id in DB.data.enemies:
				if DB.data.enemies[id].get("boss", false):
					bosses += 1
			game.day_n = 4
			var no_siege: bool = not SG.siege_day(4) and SG.siege_day(5) and SG.siege_day(10) and SG.next_day() == 5
			game.day_n = 5
			game.day_t = 0.4
			for i in 3:
				await tree.process_frame
			var announced: bool = SG.announced_day == 5 and SG.boss_type != "" and game.hud.siege_lbl.visible
			game.day_t = 0.8
			for i in 3:
				await tree.process_frame
			var boss = SG.boss
			var spawned: bool = boss != null and boss.alive and bool(boss.d.get("boss", false)) and SG.fired_day == 5
			var escorts := 0
			for e in EN.list:
				if e.alive and e != boss:
					escorts += 1
			for i in 3:
				await tree.process_frame
			var bar: bool = game.hud.boss_box.visible and game.hud.boss_bar.max_value > 1000.0
			var save: Dictionary = SG.save()
			var cr0: int = game.credits
			if boss:
				EN.hit(boss, 1e9, true)
			for i in 3:
				await tree.process_frame
			var won: bool = SG.won == 1 and game.credits >= cr0 + 1500 and not game.hud.boss_box.visible
			SG.load_from(save)
			# 1.1.15: сохранено посреди осады (босс жив) — после загрузки осада придёт заново этой ночью
			var loaded: bool = SG.fired_day == -1 and SG.count == 0 and SG.announced_day == 5
			for e in EN.list.duplicate():
				EN.vanish(e)
			var ok: bool = bosses >= 5 and no_siege and announced and spawned and escorts >= 10 and bar and won and loaded
			print("TEST sieges bosses=", bosses, " schedule=", no_siege, " announced=", announced, " spawned=", spawned, " escorts=", escorts, " bar=", bar,
				" won=", won, " save=", loaded, " ", "OK" if ok else "FAIL")
		"photo":
			# 14.7 фото- и видеорежим: свободная камера, фильтры, запись ролика в .avi
			var PH = game.photo
			game._action("photo")
			var entered: bool = game.photo_mode and not game.hud.visible
			PH.key(KEY_F, false)
			var p0: Vector3 = game.camera.global_position
			Input.action_press("move_up")
			var pl0: Vector3 = game.player.position
			PH.pos += Vector3(5, 3, 0)
			for i in 5:
				await tree.process_frame
			Input.action_release("move_up")
			var moved: bool = PH.free_cam and game.camera.global_position.distance_to(p0) > 2.0 and game.player.position.distance_to(pl0) < 0.3
			var s0: float = game.env.adjustment_saturation
			PH.key(KEY_BRACKETRIGHT, false)
			PH.key(KEY_BRACKETRIGHT, false)
			var bw: bool = PH.filters().size() >= 6 and game.env.adjustment_saturation < s0 * 0.1
			PH.key(KEY_V, false)
			var dof: bool = game.camera.attributes != null
			# запись ролика: AVI с кадрами JPEG
			var AW = preload("res://scripts/avi_writer.gd")
			var aw = AW.new()
			var ap := DB.saves_dir().get_base_dir().path_join("videos").path_join("test.avi")
			DirAccess.make_dir_recursive_absolute(ap.get_base_dir())
			aw.open(ap, 64, 48, 30)
			for i in 12:
				var im := Image.create(64, 48, false, Image.FORMAT_RGB8)
				im.fill(Color(i / 12.0, 0.5, 1.0 - i / 12.0))
				aw.add_image(im)
			aw.close(24)
			var raw := FileAccess.get_file_as_bytes(ap)
			var flen := raw.size()
			var riff := raw.decode_u32(4) if flen > 8 else 0
			var idx_at := raw.size() - 12 * 16 - 8
			var avi_ok: bool = raw.slice(0, 4).get_string_from_ascii() == "RIFF" and raw.slice(8, 12).get_string_from_ascii() == "AVI " and riff == flen - 8 and aw.frames == 12 \
				and idx_at > 0 and raw.slice(idx_at, idx_at + 4).get_string_from_ascii() == "idx1"
			DirAccess.remove_absolute(ap)
			game._action("photo")
			var left: bool = not game.photo_mode and game.hud.visible and game.camera.attributes == null and absf(game.env.adjustment_saturation - s0) < 0.01
			var ok: bool = entered and moved and bw and dof and avi_ok and left
			print("TEST photo entered=", entered, " freecam=", moved, " filter=", bw, " dof=", dof, " avi=", avi_ok, " left=", left, " ", "OK" if ok else "FAIL")
		"fog":
			# 14.7 туман войны: открыто у штаба, герой открывает по пути, радар и дрон-разведчик открывают округу
			var FG = game.fog
			var f = game.factory
			game.flags["free_build"] = true
			game.flags["god"] = true
			var hqp: Vector3 = f.hq.center()
			var far := hqp + Vector3(260, 0, 0)
			var start_ok: bool = FG.on() and FG.res > 0 and FG.explored(hqp) and not FG.explored(far) and not FG.explored(hqp + Vector3(0, 0, -400))
			game.player.position = far
			for i in 4:
				FG.update(0.3)
			var walk_ok: bool = FG.explored(far) and not FG.explored(far + Vector3(120, 0, 0))
			game.player.position = hqp + Vector3(4, 0, 4)
			# радар
			var rc: Vector2i = World.world_to_cell(hqp + Vector3(-60, 0, 60))
			var radar = put_near(game, "radar_tower", rc)
			var gen = put_near(game, "generator", rc + Vector2i(4, 0))
			if gen and gen.fuel:
				gen.fuel.add("coal", 50)
			f.auto_wire_all()
			f.power_dirty = true
			for i in 20:
				await tree.process_frame
			FG._radar_t = 0.0
			FG.update(0.1)
			var radar_ok: bool = radar != null and FG.explored(radar.center() + Vector3(-110, 0, 0)) and not FG.explored(radar.center() + Vector3(-200, 0, 0))
			# дрон-разведчик (через предмет)
			game.player.inv.add("scout_drone", 1)
			game.camera.look_at(game.camera.global_position + Vector3(0, -0.5, -1))
			var target: Vector3 = game.player.position + Vector3(0, 0, -280)
			var before: bool = FG.explored(target)
			game.console.run_actions([{"do": "scout", "dist": "320"}], {})
			for i in 30:
				FG.update(0.5)
			var scout_ok: bool = not before and FG.explored(target) and FG.scouts.is_empty()
			# сохранение
			var dd: Dictionary = FG.to_dict()
			var share: float = FG.explored_share()
			FG.bits.fill(0)
			FG.from_dict(dd)
			var save_ok: bool = absf(FG.explored_share() - share) < 0.0001 and share > 0.0
			await tree.process_frame
			var mm_ok: bool = game.hud.minimap.mat.get_shader_parameter("fog_on") == true
			var ok: bool = start_ok and walk_ok and radar_ok and scout_ok and save_ok and mm_ok
			print("TEST fog start=", start_ok, " walk=", walk_ok, " radar=", radar_ok, " scout=", scout_ok, " save=", save_ok, " share=", snappedf(share, 0.0001), " minimap=", mm_ok, " ",
				"OK" if ok else "FAIL")
		"maze":
			# 14.7 лабиринты и ловушки: обход стен, шипы, катушка Теслы с цепью молний
			var f = game.factory
			var MZ = game.maze
			var EN = game.enemies
			game.flags["free_build"] = true
			game.flags["god"] = true
			for e in EN.list.duplicate():
				EN.vanish(e)
			# свободное ровное место без воды (карта случайная)
			var c: Vector2i = f.hq.cell + Vector2i(36, 0)
			var offs: Array = []
			for rr in [36, 42, 48, 54, 60]:   # внутри поля обхода (maze_radius 70)
				for k in 16:
					offs.append(Vector2i(roundi(cos(k * TAU / 16.0) * rr), roundi(sin(k * TAU / 16.0) * rr)))
			for off in offs:
				var good := true
				for dz in range(-6, 13):
					for dx in range(-14, 7):
						var cc := World.wc(f.hq.cell + off + Vector2i(dx, dz))
						if f.grid.has(cc):
							if f.grid[cc] == f.hq:
								good = false
							continue
						game.world.remove_node(cc)
						if f.can_place("steel_wall", cc) != "":
							good = false
				if good:
					c = f.hq.cell + off
					break
			for dz in range(-6, 9):
				for dx in range(-6, 7):
					game.world.remove_node(World.wc(c + Vector2i(dx, dz)))
					var old = f.grid.get(World.wc(c + Vector2i(dx, dz)))
					if old != null and old != f.hq:
						f.remove(old)
			var chest = DemoSetup.put(game, "chest", c, 0)
			var walls := 0
			for dz in range(-2, 3):
				for dx in range(-2, 3):
					if maxi(absi(dx), absi(dz)) == 2 and not (dz == 2 and dx == 0):
						if DemoSetup.put(game, "steel_wall", c + Vector2i(dx, dz), 0) != null:
							walls += 1
			MZ.rebuild()
			var start: Vector3 = World.cell_to_world(World.wc(c + Vector2i(0, -4)))
			var d_start: int = MZ.dist[MZ._idx(World.world_to_cell(start))]
			# идём по полю: путь не проходит через стены и приводит к сундуку через проход на юге
			var p := start
			var through_gap := false
			var hit_wall := false
			for i in 200:
				var dv: Vector3 = MZ.dir_at(p)
				if dv == Vector3.ZERO:
					break
				p += dv * 0.5
				var b = f.grid.get(World.world_to_cell(p))
				if b != null and b.beh == "wall":
					hit_wall = true
				if World.world_to_cell(p) == World.wc(c + Vector2i(0, 2)):
					through_gap = true
			var near_chest: bool = chest != null and World.dist(p, chest.center()) < 3.5
			var path_ok: bool = walls == 15 and d_start > 6 and through_gap and not hit_wall and near_chest
			# закрыли проход — пути нет, монстр пойдёт напрямую и сломает стену
			DemoSetup.put(game, "steel_wall", c + Vector2i(0, 2), 0)
			MZ.rebuild()
			var d_closed: int = MZ.dist[MZ._idx(World.world_to_cell(start))]
			var closed: bool = d_closed > d_start + 10
			# шипы
			var sp = DemoSetup.put(game, "spike_trap", c + Vector2i(0, 6), 0)
			MZ.rebuild()
			var mob = EN.spawn("crawler", sp.center() if sp else start)
			var hp0: float = mob.hp if mob else 0.0
			var sp_hp0: float = sp.hp if sp else 0.0
			mob.pos = sp.center()
			MZ._traps(1.0)
			var spikes_ok: bool = sp != null and mob != null and mob.hp < hp0 - 20.0 and sp.hp < sp_hp0
			EN.vanish(mob)
			# катушка Теслы: молния бьёт троих сразу
			var tc = put_near(game, "tesla_coil", c + Vector2i(-8, 10))
			var gen = put_near(game, "generator", c + Vector2i(-12, 10))
			if gen and gen.fuel:
				gen.fuel.add("coal", 50)
			f.auto_wire_all()
			f.power_dirty = true
			var mobs := []
			if tc:
				for k in 3:
					var m = EN.spawn("brute", tc.center() + Vector3(6 + k * 2.0, 0, 0))
					m.hp = 10000.0
					m.maxhp = 10000.0
					m.speed = 0.0
					mobs.append(m)
			for i in 120:
				await tree.process_frame
				var n_hit := 0
				for m in mobs:
					if m.hp < 10000.0:
						n_hit += 1
				if n_hit >= 3:
					break
			var chained := 0
			for m in mobs:
				if m.hp < 10000.0:
					chained += 1
			for e in EN.list.duplicate():
				EN.vanish(e)
			var ok: bool = path_ok and closed and spikes_ok and chained >= 3
			print("TEST maze walls=", walls, " detour=", d_start, " gap=", through_gap, " wall_hit=", hit_wall, " reached=", near_chest, " closed=", closed, "(", d_closed, ")",
				" spikes=", spikes_ok, " tesla_chain=", chained, " ", "OK" if ok else "FAIL")
		"dungeons":
			# 14.7 подземелья: руины на карте, стража просыпается, ловушка ранит героя, сундук с чертежом, редкое здание, телепорт
			var f = game.factory
			var DG = game.dungeons
			var EN = game.enemies
			var pl = game.player
			game.flags["free_build"] = true
			game.flags["god"] = false
			# по умолчанию подземелья выключены (11.10); включаем для проверки, как через «Настройки → Подземелья»
			var off_default: bool = DG.list.is_empty()
			var plasma_by_tech: bool = str(DB.locked.get("b:plasma_turret", "")) != "__rare"
			DB.data.settings["dungeons"]["enabled"] = true
			DG.generate()
			DB.revision += 1
			game.tech.refresh_locks()
			var gen_n: int = DG.list.size()
			var walls := 0
			var arch := false
			var chest_ok := false
			var bp_in := ""
			if gen_n > 0:
				var d0: Dictionary = DG.list[0]
				for dz in range(-6, 7):
					for dx in range(-6, 7):
						var b = f.grid.get(World.wc(d0.cell + Vector2i(dx, dz)))
						if b == null:
							continue
						if b.type == "ruin_wall":
							walls += 1
						elif b.type == "ruin_arch":
							arch = true
				if d0.chest != null and d0.chest.inv != null:
					for sl in d0.chest.inv.slots:
						if sl != null and str(sl.id).begins_with("bp_"):
							bp_in = str(sl.id)
					chest_ok = bp_in != "" and d0.chest.inv.count("crystal") > 0
			var gen_ok: bool = gen_n >= 3 and walls >= 30 and arch and chest_ok
			# стража: подошли — проснулась
			var d1: Dictionary = DG.list[0] if gen_n > 0 else {}
			var n0: int = EN.list.size()
			var wake_ok := false
			if gen_n > 0:
				game.teleport_player(World.cell_to_world(d1.cell) + Vector3(20, 0, 0))
				DG.update(0.1)
				var guards := 0
				for e in EN.list:
					if e.guard and World.dist(e.pos, World.cell_to_world(d1.cell)) < 12.0:
						guards += 1
				wake_ok = d1.guards and guards >= 3 and EN.list.size() > n0
			for e in EN.list.duplicate():
				EN.vanish(e)
			# ловушка подземелья ранит героя, в прыжке — нет
			var trap = null
			for b in f.all:
				if b.type == "dungeon_spikes" and not b.dead:
					trap = b
					break
			var trap_ok := false
			if trap:
				game.maze.rebuild()
				pl.hp = pl.maxhp
				pl.position = trap.center()
				pl.position.y = f.support_at(pl.position)
				game.maze._traps(1.0)
				var hit: bool = pl.hp < pl.maxhp - 10.0
				pl.hp = pl.maxhp
				pl.position.y += 2.0
				game.maze._traps(1.0)
				trap_ok = hit and pl.hp >= pl.maxhp - 0.1
				pl.position.y -= 2.0
			game.flags["god"] = true
			# редкое здание закрыто, чертёж открывает
			var bpk: String = bp_in.substr(3) if bp_in != "" else "teleporter"
			var was_locked: bool = Tech.building_locked(bpk)
			pl.inv.add("bp_" + bpk, 1)
			var slot: int = -1
			for i in pl.inv.slots.size():
				if pl.inv.slots[i] != null and pl.inv.slots[i].id == "bp_" + bpk:
					slot = i
			if slot >= 0:
				pl.use_item(slot)
			var rare_ok: bool = was_locked and not Tech.building_locked(bpk) and game.tech.to_dict().get("rare", {}).has(bpk)
			# сундук опустошили — подземелье пройдено
			var done_ok := false
			if gen_n > 0 and d1.chest != null:
				for sl in d1.chest.inv.slots.duplicate():
					if sl != null:
						d1.chest.inv.remove(sl.id, sl.n)
				DG.update(0.1)
				done_ok = d1.done
			# сохранение
			var dd: Array = DG.to_dict()
			DG.from_dict(dd)
			var save_ok: bool = DG.list.size() == gen_n and DG.list[0].done and DG.list[0].chest != null
			# телепорты: два — переносит к другому
			game.tech.unlock_rare("teleporter")
			var hc: Vector2i = f.hq.cell
			var t1 = put_near(game, "teleporter", hc + Vector2i(-10, 14))
			var t2 = put_near(game, "teleporter", hc + Vector2i(30, -20))
			var tp_ok := false
			if t1 and t2:
				var to = game.next_teleporter(t1)
				if to == t2:
					game.teleport_player(to.center())
					tp_ok = World.dist(pl.position, t2.center()) < 2.0 and game.next_teleporter(t2) == t1
			var ok: bool = off_default and plasma_by_tech and gen_ok and wake_ok and trap_ok and rare_ok and done_ok and save_ok and tp_ok
			print("TEST dungeons off_default=", off_default, " plasma_by_tech=", plasma_by_tech, " count=", gen_n, " walls=", walls, " arch=", arch, " chest=", chest_ok, "(", bp_in, ") wake=", wake_ok, " trap=", trap_ok,
				" rare=", rare_ok, " done=", done_ok, " save=", save_ok, " tp=", tp_ok, " ", "OK" if ok else "FAIL")
		"hazards":
			# 14.3 опасные события: солнечный выброс, бункер, щит-купол, землетрясение, «Рёв матери», «Дрожь земли»
			var f = game.factory
			var E = game.events
			var pl = game.player
			game.flags["free_build"] = true
			game.flags["god"] = false
			var hc: Vector2i = f.hq.cell
			var dome = put_near(game, "shield_dome", hc + Vector2i(-4, 0))
			var gen = put_near(game, "generator", (dome.cell if dome else hc) + Vector2i(-3, 0))
			if gen and gen.fuel:
				gen.fuel.add("coal", 50)
			var bunker = put_near(game, "bunker", hc + Vector2i(14, 0))
			var m_in = put_near(game, "assembler", (dome.cell if dome else hc) + Vector2i(0, 3))
			var m_out = put_near(game, "assembler", hc + Vector2i(-30, 30))
			var chest_out = put_near(game, "chest", hc + Vector2i(-26, 26))
			f.power_dirty = true
			for i in 30:
				await tree.process_frame
			var dome_on: bool = dome != null and f.shield_on(dome)
			# герой далеко от укрытий
			pl.position = World.cell_to_world(hc + Vector2i(-28, 28))
			pl.hp = pl.maxhp if "maxhp" in pl else 200.0
			var hp0: float = pl.hp
			var mon = game.enemies.spawn("crawler", pl.position + Vector3(12, 0, 0))
			if mon:
				mon.hp = 10.0
			var ev: Dictionary = E.list()["solar_flare"]
			E.start("solar_flare")
			E.active["solar_flare"] = float(ev.duration) - float(ev.delay) - 0.5   # опасность уже идёт
			var credits0: int = game.credits
			var drops0: int = game.drops.list.size() if "list" in game.drops else 0
			for i in 150:
				await tree.process_frame
			var burned: bool = pl.hp < hp0
			var halt_out: bool = m_out != null and m_out.ev_halt
			var run_in: bool = m_in != null and not m_in.ev_halt
			var dmg_out: bool = chest_out != null and chest_out.hp < chest_out.maxhp
			var mon_dead: bool = mon != null and not mon.alive
			var no_loot: bool = game.credits == credits0
			E._update_domes()
			var domes: int = E.domes.size()
			# у бункера безопасно
			pl.position = bunker.center() + Vector3(5, 0, 0) if bunker else pl.position
			for i in 20:
				await tree.process_frame
			var hp1: float = pl.hp
			for i in 120:
				await tree.process_frame
			var safe: bool = pl.hp >= hp1 - 0.01
			E.finish("solar_flare")
			for i in 70:
				await tree.process_frame
			var resumed: bool = m_out != null and not m_out.ev_halt
			# землетрясение: половина прочности, на фундаменте — четверть
			var c_plain = put_near(game, "chest", hc + Vector2i(20, -20))
			var fnd = put_near(game, "found_1", hc + Vector2i(-20, -20))
			var c_found = put(game, "chest", fnd.cell, 0) if fnd else null
			if c_plain:
				c_plain.hp = c_plain.maxhp
			E.start("earthquake")
			var q_plain: float = c_plain.hp / c_plain.maxhp if c_plain else -1.0
			var q_found: float = c_found.hp / c_found.maxhp if c_found else -1.0
			var shook: bool = E.shake > 0.5
			E.finish("earthquake")
			# «Рёв матери»: толпа идёт на героя
			pl.position = World.cell_to_world(hc + Vector2i(-28, 28))
			var n0: int = game.enemies.list.size()
			E.start("mother_roar")
			var horde: Array = E.spawned.get("mother_roar", [])
			var kinds := {}
			for m in horde:
				kinds[m.type] = true
			for i in 30:
				await tree.process_frame
			var chasing := 0
			for m in horde:
				if m.alive and m.target == pl:
					chasing += 1
			E.finish("mother_roar")
			for m in horde:
				if m.alive:
					game.enemies.vanish(m)
			# «Дрожь земли»: черви под землёй, по ним не попасть; после события уходят
			E.start("ground_tremor")
			var worms: Array = E.spawned.get("ground_tremor", [])
			var hidden := worms.size() > 0
			for w in worms:
				if game.enemies.targetable(w) or w.under < 0.9:
					hidden = false
			var surfaced := false
			for i in 600:
				await tree.process_frame
				for w in worms:
					if w.alive and w.under < 0.2:
						surfaced = true
				if surfaced:
					break
			E.finish("ground_tremor")
			var gone := true
			for w in worms:
				if w.alive:
					gone = false
			var ok: bool = dome_on and burned and halt_out and run_in and dmg_out and mon_dead and no_loot and domes > 0 and safe and resumed \
				and absf(q_plain - 0.5) < 0.05 and absf(q_found - 0.75) < 0.05 and shook and horde.size() == 18 and kinds.size() >= 3 and chasing >= 15 \
				and worms.size() == 4 and hidden and surfaced and gone
			print("TEST hazards dome_on=", dome_on, " burned=", burned, " halt_out=", halt_out, " run_in=", run_in, " dmg_out=", dmg_out, " mon_dead=", mon_dead,
				" no_loot=", no_loot, " domes=", domes, " safe=", safe, " resumed=", resumed, " quake=", snappedf(q_plain, 0.01), "/", snappedf(q_found, 0.01), " shook=", shook,
				" horde=", horde.size(), " kinds=", kinds.size(), " chasing=", chasing, " worms=", worms.size(), " hidden=", hidden, " surfaced=", surfaced, " gone=", gone, " ",
				"OK" if ok else "FAIL")
		"flow":
			# 14.1 карта потоков: застрявшая лента красная, машина без сырья жёлтая
			var f = game.factory
			game.flags["free_build"] = true
			var c0: Vector2i = f.hq.cell + Vector2i(-16, -12)
			var bl = put(game, "belt", c0, 0)
			var asm = put(game, "assembler", c0 + Vector2i(4, 4), 0)
			f.set_item(bl, "iron_ingot")
			for i in 60:
				await tree.process_frame
			f.sim_time += 10.0
			game.flow_map.toggle()
			var st_belt: String = game.flow_map.state_of(bl) if bl != null else ""
			var st_asm: String = game.flow_map.state_of(asm) if asm != null else ""
			var shown: int = game.flow_map.marks.size()
			game._action("flow_map")
			var hidden: bool = not game.flow_map.on and not game.flow_map.canvas.visible
			print("TEST flow belt=", st_belt, " asm=", st_asm, " shown=", shown, " hidden=", hidden, " ",
				"OK" if st_belt == "stuck" and st_asm in ["starve", "nopower"] and shown > 0 and hidden else "FAIL")
		"economy":
			# 14.1 живая экономика: сезоны, события, «чего много — дешевле»
			game.day_n = 1
			var spring_food: int = game.sell_price("berry")
			var s1: String = str(game.season().get("name", ""))
			game.day_n = 16
			var winter_food: int = game.sell_price("berry")
			var s4: String = str(game.season().get("name", ""))
			var season_ok: bool = s1 == "Весна" and s4 == "Зима" and winter_food > spring_food
			game.day_n = 1
			var st0: int = game.sell_price("iron_ingot")
			game.factory.hq.inv.add("iron_ingot", 900)
			game.update_abundance()
			var st1: int = game.sell_price("iron_ingot")
			var abund_ok: bool = st1 < st0 and game.buy_price("iron_ingot") > st0
			# A-2 r10: патроны продаются в магазине утилизации по 0,6 кр — их цена продажи упирается в потолок; берём меч (категория «Оружие»)
			var am0: int = game.sell_price("sword")
			game.events.active["invasion"] = 10.0
			var am1: int = game.sell_price("sword")
			var why: Array = game.econ_reasons("sword")
			game.events.active.erase("invasion")
			var event_ok: bool = am1 > am0 and not why.is_empty()
			var buy_ok := true
			for it in ["berry", "iron_ingot", "ammo", "iron_ingot", "coal"]:
				for d in [1, 6, 11, 16]:
					game.day_n = d
					if game.buy_price(it) <= game.sell_price(it):
						buy_ok = false
			print("TEST economy season=", season_ok, " ", s1, ">", s4, " food ", spring_food, "->", winter_food, " abundance=", abund_ok, " ingot ", st0, "->", st1,
				" event=", event_ok, " ammo ", am0, "->", am1, " buy_gt_sell=", buy_ok, " ", "OK" if season_ok and abund_ok and event_ok and buy_ok else "FAIL")
		"orders":
			# этап 10: заказы на станции, честные цены, живой рынок, история
			var f = game.factory
			var O = game.orders
			var it := "iron_ingot"
			game.price_mult[it] = 1.0
			var unit: float = O.unit_price(it)
			var fair = O.place("sell", it, 100, roundi(unit * 100))
			var greedy = O.place("sell", it, 1, 1000000)
			var cheap = O.place("sell", it, 100, roundi(unit * 60))
			var n_fair := 0
			var n_greedy := 0
			var n_cheap := 0
			for i in 200:
				fair.offers.clear(); greedy.offers.clear(); cheap.offers.clear()
				O._maybe_offer(fair); O._maybe_offer(greedy); O._maybe_offer(cheap)
				n_fair += fair.offers.size(); n_greedy += greedy.offers.size(); n_cheap += cheap.offers.size()
			var greed_ok: bool = n_greedy == 0 and n_cheap > n_fair and n_fair > 0
			# честная цена: предложение от рынка, а не от суммы игрока
			var of: Dictionary = O.make_offer(cheap)
			var val: float = float(of.credits) if of.pay_item == "" else O.unit_price(of.pay_item) * of.pay_n
			var fair_ok: bool = val > unit * 100 * 0.8 and val < unit * 100 * 1.2
			# продаём по предложению за кредиты
			O.list.clear()
			var o1 = O.place("sell", it, 40, roundi(unit * 40))
			f.hq.inv.add(it, 40)
			var have0: int = f.hq.inv.count(it)
			var cr0: int = game.credits
			var offer := {"from": "Тест", "credits": 333, "pay_item": "", "pay_n": 0, "t": 100.0}
			o1.offers.append(offer)
			var acc: bool = O.accept(o1, offer)
			var sell_ok: bool = acc and f.hq.inv.count(it) == have0 - 40 and game.credits == cr0 + 333 and O.list.is_empty() and O.history.size() == 1
			var dropped: bool = float(game.price_mult[it]) < 1.0
			# покупка
			var o2 = O.place("buy", "glass", 10, 100)
			var off2 := {"from": "Тест", "credits": 120, "pay_item": "", "pay_n": 0, "t": 100.0}
			game.credits = 500
			var g0: int = f.hq.inv.count("glass")
			var buy_ok: bool = O.accept(o2, off2) and f.hq.inv.count("glass") == g0 + 10 and game.credits == 380
			# рынок оживает: давно не продававшийся товар дорожает
			game.price_mult["glass"] = 1.0
			game.last_sold.erase("glass")
			for i in 30:
				game.market_timer = 0.0
				game._update_market(0.1)
			var rare_up: bool = float(game.price_mult["glass"]) > 1.05
			# время: заказ получает предложения сам
			var o3 = O.place("sell", it, 10, roundi(O.unit_price(it) * 7))
			for i in 20:
				O._acc = 999.0
				O.update(0.1)
			var auto_ok: bool = not o3.offers.is_empty()
			var dd: Dictionary = O.to_dict()
			var O2 = load("res://scripts/orders.gd").new(game)
			O2.load_dict(dd)
			var save_ok: bool = O2.list.size() == O.list.size() and O2.history.size() == 2
			game.hud.open("orders")
			await tree.process_frame
			var ui_ok: bool = game.hud.windows.orders.body.get_child_count() > 2
			print("TEST orders fair=", n_fair, " greedy=", n_greedy, " cheap=", n_cheap, " greed=", greed_ok, " fair_price=", fair_ok, " sell=", sell_ok, " dropped=", dropped,
				" buy=", buy_ok, " rare_up=", rare_up, " auto=", auto_ok, " save=", save_ok, " ui=", ui_ok, " ",
				"OK" if greed_ok and fair_ok and sell_ok and dropped and buy_ok and rare_up and auto_ok and save_ok and ui_ok else "FAIL")
		"fluids":
			# нефть: качалка → трубы и бак → нефтезавод (топливо) → топливный генератор
			var f = game.factory
			for t in ["oil_pump", "refinery", "packager"]:
				DB.data.buildings[t].params["power"] = 0
			var base: Vector2i = f.hq.cell + Vector2i(8, 7)
			var L := fluid_layout(game, base)
			var placed: bool = L.pump != null and L.ref != null and L.gen != null and L.tank != null and not L.pipes.has(null)
			var oil_i := -1
			for i in game.world.deposits.size():
				if str(game.world.deposits[i].get("item", "")) == "oil":
					oil_i = i
			game.world.set_deposit(base + Vector2i(-2, 4), oil_i)
			var why_miner: String = f.can_place("miner", base + Vector2i(-2, 4))
			var why_pump: String = f.can_place("oil_pump", base + Vector2i(0, 4))
			f._rebuild_fluids()
			var nets: int = f.fnets.size()
			var oi := {}
			var fi := {}
			var seen := {}
			# сначала нефтезавод не перерабатывает — нефть копится в трубах и баке
			L.ref.recipe = "pack_oil"
			var acc_amt := 0.0
			var acc_pipes := 0.0
			for step in int(80.0 / Factory.TICK):
				f._tick(Factory.TICK)
				if step == int(30.0 / Factory.TICK):
					acc_amt = f.fluid_info(L.pipes[0]).amt
					f.sync_fluids()
					for pp in L.pipes + [L.tank]:
						acc_pipes += pp.famt
					f.set_recipe(L.ref, "refine_fuel")
				if step % 20 == 0:
					var a: Dictionary = f.fluid_info(L.pipes[0])
					var b2: Dictionary = f.fluid_info(L.pipes[4])
					seen[a.fluid] = true
					seen[b2.fluid] = true
					if a.fluid != "":
						oi = a
					if b2.fluid != "":
						fi = b2
			var flow_end: float = f.fluid_info(L.pipes[0]).flow
			var fuel_flow: float = f.fluid_info(L.pipes[4]).flow
			var ref_out: int = L.ref.out.count("fuel")
			var gen_fuel: int = L.gen.fuel.count("fuel")
			var bag_left: int = game.player.inv.add("oil", 5)
			var belt_clean: bool = L.belt == null or L.belt.item == ""
			# сохранение: жидкость в трубах раскладывается и возвращается
			f.sync_fluids()
			var in_pipes := acc_pipes
			f.drain(L.pipes[0])
			var drained: bool = f.fluid_info(L.pipes[0]).amt == 0.0
			print("TEST fluids placed=", placed, " nets=", nets, " oil=", oi.get("fluid", ""), ":", int(oi.get("amt", 0)), " flow=", int(flow_end), " fuel_flow=", int(fuel_flow),
				" fuel_net=", fi.get("fluid", ""), " ref_out=", ref_out, " gen_fuel=", gen_fuel, " made=", f.rate_now(L.ref),
				" why_miner='", why_miner, "' why_pump='", why_pump, "' bag_left=", bag_left, " belt_clean=", belt_clean,
				" stored=", snappedf(acc_amt, 0.1), " in_pipes=", snappedf(in_pipes, 0.1), " drained=", drained, " ",
				"OK" if placed and nets == 2 and oi.get("fluid", "") == "oil" and flow_end > 30 and fuel_flow > 20 and gen_fuel > 0
					and why_miner.find("насос") >= 0 and why_pump.find("Насос") >= 0 and bag_left == 5 and belt_clean and acc_amt > 5.0 and absf(in_pipes - acc_amt) < 0.5 and drained else "FAIL")
		"tiers":
			# пропускная способность лент Mk1/Mk2/Mk3: гоним груз 40 с модельного времени и считаем, сколько доехало
			var f = game.factory
			var hq: Vector2i = f.hq.cell
			var res := {}
			var row := 0
			for bt in ["belt", "belt_mk2", "belt_mk3"]:
				var z := hq.y + 8 + row * 3
				row += 1
				var line := []
				for x in range(12):
					var c := World.wc(Vector2i(hq.x - 6 + x, z))
					game.world.remove_node(c)
					var lb = put(game, bt, c, 0)
					if lb:
						line.append(lb)
				var end_c := World.wc(Vector2i(hq.x + 6, z))
				var chest = put(game, "chest", end_c, 0)
				res[bt] = [line, chest]
			var counts := {}
			var last_in := {}
			for step in int(50.0 / Factory.TICK):
				for bt in res:
					var first = res[bt][0][0]
					if first.item == "":
						# источник тоже подаёт ровно в такт ленты
						f.set_item(first, "stone", last_in.get(bt, -10.0) + first.period)
						last_in[bt] = first.t_in
				f._tick(Factory.TICK)
				if step == int(10.0 / Factory.TICK):
					for bt in res:
						counts[bt] = res[bt][1].inv.count("stone")
			var per_min := {}
			for bt in res:
				per_min[bt] = (res[bt][1].inv.count("stone") - counts[bt]) * 60.0 / 40.0
			var sp_ok: bool = absf(per_min.belt - 60) <= 4 and absf(per_min.belt_mk2 - 120) <= 6 and absf(per_min.belt_mk3 - 270) <= 12
			# улучшение поверх: груз и направление сохраняются
			var b0 = res["belt"][0][3]
			f.set_item(b0, "log")
			var d0: int = b0.dir
			game.flags["free_build"] = true
			var nb = game.cmd("place", {"type": "belt_mk2", "cell": b0.cell, "dir": 2})
			var up_ok: bool = nb != null and nb.type == "belt_mk2" and nb.dir == d0 and nb.item == "log" and b0.dead
			# машина: максимум в минуту и «что мешает»
			var sm = put(game, "smelter", hq + Vector2i(-5, -6), 0)
			var mx: float = f.rate_max(sm, "smelt_iron") if sm else 0.0
			var bn: String = f.bottleneck(sm) if sm else ""
			print("TEST tiers per_min=", per_min, " upgrade=", up_ok, " smelter_max=", snappedf(mx, 0.1), " why='", bn, "' ",
				"OK" if sp_ok and up_ok and mx > 0.0 and bn != "" else "FAIL")
		"take_ready":
			# «Забрать готовое» не трогает сырьё; двойной клик переносит стопку в здание и обратно
			var pl = game.player
			var hq: Vector2i = game.factory.hq.cell
			var sm = put(game, "smelter", hq + Vector2i(-4, 3), 0)
			sm.inv.add("iron_ore", 5)
			sm.out.add("iron_ingot", 3)
			var before: int = pl.inv.count("iron_ingot")
			game.cmd("take_ready", {"b": sm})
			var ready_ok: bool = pl.inv.count("iron_ingot") == before + 3 and sm.inv.count("iron_ore") == 5 and sm.out.count("iron_ingot") == 0
			pl.inv.remove("iron_ore", pl.inv.count("iron_ore"))
			pl.inv.slots[12] = {"id": "iron_ore", "n": 4}
			pl.position = sm.center() + Vector3(3, 0, 0)
			game.hud.open_building(sm)
			var ore0: int = sm.inv.count("iron_ore")
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = true
			ev.double_click = true
			game.hud.inv_slots[12]._gui_input(ev)
			var to_bld: bool = sm.inv.count("iron_ore") == ore0 + 4 and pl.inv.count("iron_ore") == 0
			var si := -1
			for k in sm.inv.slots.size():
				if sm.inv.slots[k] != null:
					si = k
			var back := false
			for s2 in game.hud.bld_slots:
				if s2.inv == sm.inv and s2.index == si:
					s2._gui_input(ev)
					back = pl.inv.count("iron_ore") > 0
			var has_btn := false
			for b2 in game.hud.windows.building.body.find_children("*", "Button", true, false):
				if (b2 as Button).text == "Забрать готовое":
					has_btn = true
			print("TEST take_ready ready=", ready_ok, " dbl_to_building=", to_bld, " dbl_back=", back, " button=", has_btn, " ",
				"OK" if ready_ok and to_bld and back and has_btn else "FAIL")
		"item_models":
			item_belts(game)
			await tree.create_timer(0.3).timeout
			var models := {}
			for k in game.factory.belt_item_key:
				models[game.factory.belt_item_key[k].split("|")[2]] = true
			var shown: int = game.factory.belt_item_key.size()
			print("TEST item_models belts_with_items=", shown, " models=", models.size(), " ", "OK" if shown >= 20 and models.size() >= 12 else "FAIL")
		"ports":
			ports(game, 0)
			await tree.create_timer(0.3).timeout
			var n := 0
			for k in game.factory.port_keys:
				n += game.factory.port_keys[k].size()
			# повернуть ящик: стык должен пропасть, разобрать ленту — тоже
			var ch = game.factory.building_at(game.factory.hq.cell + Vector2i(-14, 4))
			game.factory.set_dir(ch, 2)
			var after_rot := 0
			for k in game.factory.port_keys:
				after_rot += game.factory.port_keys[k].size()
			var bl = game.factory.building_at(game.factory.hq.cell + Vector2i(-11, 4))
			game.factory.remove(bl)
			var after_rm := 0
			for k in game.factory.port_keys:
				after_rm += game.factory.port_keys[k].size()
			print("TEST ports count=", n, " after_rotate=", after_rot, " after_remove=", after_rm, " ", "OK" if n >= 8 and after_rot == n - 1 and after_rm == n - 2 else "FAIL")
		"drops_direct":
			DB.data.settings["drops_on_ground"] = false
			var before: int = game.player.inv.count("stone")
			game.drops.spawn("stone", 3, game.player.position + Vector3(8, 0, 0))
			var after: int = game.player.inv.count("stone")
			DB.data.settings["drops_on_ground"] = true
			game.drops.spawn("stone", 2, game.player.position + Vector3(8, 0, 0))
			var on_ground: int = game.drops.list.size()
			print("TEST drops_direct inv=", after - before, " on_ground=", on_ground, " ", "OK" if after - before == 3 and on_ground >= 1 else "FAIL")
		"gate":
			var hq: Vector2i = game.factory.hq.cell
			# место без воды рядом со штабом
			var gc: Vector2i = hq + Vector2i(6, 6)
			for tries in 40:
				if not game.world.water_at(World.wc(gc)) and not game.world.water_at(World.wc(gc + Vector2i(0, 2))) and game.factory.building_at(gc) == null and game.factory.building_at(gc + Vector2i(0, 2)) == null:
					break
				gc += Vector2i(1, 1)
			var g = put(game, "gate", gc, 0)
			var w = put(game, "wall", gc + Vector2i(0, 2), 0)
			var p_ok: bool = g != null and not game.player._cell_blocked(g.cell)
			var w_ok: bool = w != null and game.player._cell_blocked(w.cell)
			var monster_blocked: bool = g != null and not game.factory.walkable(g)
			print("TEST gate player_passes=", p_ok, " wall_blocks=", w_ok, " monsters_blocked=", monster_blocked, " ", "OK" if p_ok and w_ok and monster_blocked else "FAIL")
		"heroes13":
			# 1.3: герои на выбор — девять людей из Blender в списке, каждый собирается с костями из своей модели,
			# людей не красит цвет профессии, оружие в руке без наклона, сетевой гость меняет модель на месте
			var want := ["hero_anime", "hero_serafim", "hero_myaura", "hero_klara", "hero_grom", "hero_viktoria", "hero_gawain", "hero_prapor", "hero_tiel",
				"hero_uriel", "hero_castiel", "hero_harry", "hero_valera", "hero_grato", "hero_neuro", "hero_adam", "hero_bastet", "hero_lu", "hero_sporty"]
			var lk := Player.looks()
			var listed: bool = lk.slice(0, want.size()) == want and "hero_robot" in lk and not "hero_fat" in lk and not "hero_suit" in lk \
				and DB.data.models.has("hero_fat") and DB.data.models.has("hero_suit")
			var built := 0
			var tint_ok := true
			for id in want:
				var p := Player.new()
				p.process_mode = Node.PROCESS_MODE_DISABLED
				p.look = id
				game.add_child(p)
				p.build()
				var bn: Dictionary = ModelLib.model(id).get("bones", {})
				if p.model_id == id and p.skel != null and p.skel.get_bone_count() == 16 and absf(p.gun.rotation.z) < 0.01 \
						and p.gun.get_children().any(func(c): return c is MultiMeshInstance3D) \
						and (p.chest.position + p.head.position).is_equal_approx(Vector3(bn.head[0], bn.head[1], bn.head[2])):
					built += 1
				for bp in p.body_parts:
					var pc := Color(0.92, 0.55, 0.12)
					if (bp[1] as Color).is_equal_approx(pc) or (bp[1] as Color).is_equal_approx(Color.WHITE.lerp(pc, 0.35)):
						tint_ok = false
				p.queue_free()
			# аниме-девушка (модель игрока из нейросети): одна сетка на костях с текстурой и бластер в руке
			var pa := Player.new()
			pa.process_mode = Node.PROCESS_MODE_DISABLED
			pa.look = "hero_anime"
			game.add_child(pa)
			pa.build()
			var anime_ok: bool = pa.model_id == "hero_anime" and pa.skel != null and pa.skel.get_bone_count() == 16 \
				and pa.gun.get_children().any(func(c): return c is MultiMeshInstance3D) and "hero_anime" in lk
			pa.queue_free()
			# выбор в настройках — свой герой при следующей сборке
			var had = Prefs.values.get("hero_look", null)
			Prefs.values["hero_look"] = "hero_elf"
			var mine := Player.my_look() == "hero_elf"
			if had == null:
				Prefs.values.erase("hero_look")
			else:
				Prefs.values["hero_look"] = had
			# сетевая кукла: новая модель от хозяина — пересобирается там же
			var n = Net._self()
			var g0 = n.game
			n.game = game
			n.peers[7] = {"nick": "Гость", "color": "#ff8040", "look": "hero_grom"}
			n._spawn_puppet(7)
			var pp = n.puppets.get(7)
			var relook := false
			if pp != null:
				pp.position = Vector3(5, 0, 6)
				n.look_of(7, "hero_klara")
				var p2 = n.puppets.get(7)
				relook = p2 != null and p2 != pp and p2.model_id == "hero_klara" and p2.position.is_equal_approx(Vector3(5, 0, 6))
			if n.puppets.has(7):
				n.puppets[7].queue_free()
			n.puppets.erase(7)
			n.peers.erase(7)
			n.game = g0
			print("TEST heroes13 listed=", listed, " built=", built, "/", want.size(), " tint=", tint_ok, " pref=", mine, " relook=", relook, " anime=", anime_ok, " ",
				"OK" if listed and built == want.size() and tint_ok and mine and relook and anime_ok else "FAIL")
			tree.quit()
		"pad":
			# 1.3: геймпад — стик ходит, правый стик двигает курсор, Back открывает рюкзак, B закрывает,
			# Start на втором геймпаде просит второго игрока
			Pad.fake_pads = [0, 1]   # без настоящих геймпадов: события кнопок и стиков подаём сами
			var pl = game.player
			var jev := func(dev: int, btn: int, on: bool):
				var e := InputEventJoypadButton.new()
				e.device = dev
				e.button_index = btn
				e.pressed = on
				Input.parse_input_event(e)
			var jax := func(dev: int, ax: int, v: float):
				var e := InputEventJoypadMotion.new()
				e.device = dev
				e.axis = ax
				e.axis_value = v
				Input.parse_input_event(e)
			var asked := [-1]
			Pad.join_request.connect(func(d): asked[0] = d)
			var p0: Vector3 = pl.position
			jax.call(0, JOY_AXIS_LEFT_X, 1.0)
			for i in 40:
				await tree.process_frame
			jax.call(0, JOY_AXIS_LEFT_X, 0.0)
			var walked: float = World.dist(p0, pl.position)
			var c0: Vector2 = Pad.cursor
			jax.call(0, JOY_AXIS_RIGHT_Y, -1.0)
			for i in 20:
				await tree.process_frame
			jax.call(0, JOY_AXIS_RIGHT_Y, 0.0)
			var cur_up: bool = Pad.cursor.y < c0.y - 5.0 and Pad.active   # без окна экран 64×64 — курсор сдвигается меньше
			var mp_ok: bool = Pad.mouse_pos(game.get_viewport()) == Pad.cursor
			jev.call(0, JOY_BUTTON_BACK, true)
			await tree.process_frame
			await tree.process_frame
			jev.call(0, JOY_BUTTON_BACK, false)
			await tree.process_frame
			var inv_open: bool = game.hud.is_open("inventory")
			jev.call(0, JOY_BUTTON_B, true)
			await tree.process_frame
			await tree.process_frame
			jev.call(0, JOY_BUTTON_B, false)
			await tree.process_frame
			var inv_closed: bool = not game.hud.is_open("inventory")
			jev.call(1, JOY_BUTTON_START, true)
			await tree.process_frame
			await tree.process_frame
			jev.call(1, JOY_BUTTON_START, false)
			await tree.process_frame
			print("TEST pad walked=", snappedf(walked, 0.1), " cursor=", cur_up, " vs=", game.get_viewport().get_visible_rect().size, " c=", c0, "->", Pad.cursor, " mouse=", mp_ok, " inv=", inv_open, "/", inv_closed, " join=", asked[0], " ",
				"OK" if walked > 2.0 and cur_up and mp_ok and inv_open and inv_closed and asked[0] == 1 else "FAIL")
			tree.quit()
		"split":
			# 1.3: сплитскрин в одной копии игры — два вида на общий мир, второй герой ходит своим геймпадом,
			# у него свои окна и свой подбор; выход возвращает камеру и интерфейс первому игроку
			Pad.fake_pads = [0, 1]
			var sp = game.split
			var p1 = game.player
			var cam1: Camera3D = game.camera
			var hud1 = game.hud
			var jev := func(dev: int, btn: int, on: bool):
				var e := InputEventJoypadButton.new()
				e.device = dev
				e.button_index = btn
				e.pressed = on
				Input.parse_input_event(e)
			var jax := func(dev: int, ax: int, v: float):
				var e := InputEventJoypadMotion.new()
				e.device = dev
				e.axis = ax
				e.axis_value = v
				Input.parse_input_event(e)
			jev.call(1, JOY_BUTTON_START, true)
			await tree.process_frame
			await tree.process_frame
			jev.call(1, JOY_BUTTON_START, false)
			await tree.process_frame
			var started: bool = sp.active and sp.views.size() == 2 and cam1.get_viewport() == sp.views[0][1] and hud1.get_viewport() == sp.views[0][1]
			var p2 = sp.p2()
			sp.pad2.fake_pads = [1]
			var a1: Vector3 = p1.position
			var a2: Vector3 = p2.position
			jax.call(1, JOY_AXIS_LEFT_X, 1.0)
			for i in 40:
				await tree.process_frame
			jax.call(1, JOY_AXIS_LEFT_X, 0.0)
			await tree.process_frame
			var walk2: float = World.dist(a2, p2.position)
			var still1: float = World.dist(a1, p1.position)
			var swap_ok: bool = game.player == p1 and sp.cur == 0 and game.hud == hud1
			jev.call(1, JOY_BUTTON_BACK, true)
			await tree.process_frame
			await tree.process_frame
			jev.call(1, JOY_BUTTON_BACK, false)
			await tree.process_frame
			var inv2: bool = sp.hud_of(1).is_open("inventory") and not hud1.is_open("inventory")
			jev.call(1, JOY_BUTTON_B, true)
			await tree.process_frame
			await tree.process_frame
			jev.call(1, JOY_BUTTON_B, false)
			await tree.process_frame
			var inv2_closed: bool = not sp.hud_of(1).is_open("inventory")
			var s0: int = p2.inv.count("stone")
			game.drops.spawn("stone", 3, p2.position + Vector3(0.6, 1.0, 0))
			var tk := Time.get_ticks_msec() + 4000   # 1.7: по времени — без окна кадры идут слишком быстро
			while Time.get_ticks_msec() < tk and p2.inv.count("stone") < s0 + 3:
				await tree.process_frame
			var pick2: bool = p2.inv.count("stone") >= s0 + 3
			var near2: bool = game.nearest_player(p2.position) == p2
			var sd: Dictionary = game.save_dict()
			var save_ok: bool = sd.has("split2") and absf(float(sd.player.pos[0]) - p1.position.x) < 0.01 and game.player == p1
			sp.stop()
			await tree.process_frame
			await tree.process_frame
			var back: bool = not sp.active and game.camera == cam1 and cam1.get_viewport() == game.get_viewport() and hud1.get_viewport() == game.get_viewport() and game.player == p1 and not is_instance_valid(p2)
			print("TEST split started=%s walk2=%.1f still1=%.2f swap=%s inv2=%s/%s pick2=%s near2=%s save=%s back=%s " % [started, walk2, still1, swap_ok, inv2, inv2_closed, pick2, near2, save_ok, back],
				"OK" if started and walk2 > 1.0 and still1 < 0.3 and swap_ok and inv2 and inv2_closed and pick2 and near2 and save_ok and back else "FAIL")
			tree.quit()
		"v13":
			# 1.3: участок 3×3 (старые 5×5 сохраняются), Shift+клик — весь предмет, Alt — в мусорку,
			# рекорды без купонов, залежь под размер бура и бур прилипает к ней по центру
			var f = game.factory
			var z = game.zone
			var zn_ok: bool = z.patch_n() == 3
			z.rects.append(Vector2i(40, 40))
			z.rect_n[Vector2i(40, 40)] = 3
			var zd: Dictionary = z.to_dict()
			zd.rects.append([60, 60])   # участок из сохранения 1.2 — без размера
			z.from_dict(zd)
			zn_ok = zn_ok and int(z.rect_n.get(Vector2i(40, 40), 0)) == 3 and int(z.rect_n.get(Vector2i(60, 60), 0)) == 5
			z.rects.clear()
			z.rect_n.clear()
			z.rebuild()
			# Shift+клик: три стопки руды целиком в ящик и обратно
			game.flags["free_build"] = true
			var pl = game.player
			var cc: Vector2i = f.hq.cell + Vector2i(9, 9)
			for dx in range(-1, 3):
				for dz in range(-1, 3):
					game.world.remove_node(World.wc(cc + Vector2i(dx, dz)))
			var ch = put_near(game, "chest", cc, 0)
			for i in pl.inv.slots.size():
				pl.inv.slots[i] = null
			var hn := Player.hot_n()
			pl.inv.slots[hn] = {"id": "iron_ore", "n": 30}
			pl.inv.slots[hn + 2] = {"id": "iron_ore", "n": 30}
			pl.inv.slots[hn + 4] = {"id": "iron_ore", "n": 15}
			pl.inv.changed.emit()
			if ch:
				pl.position = ch.center() + Vector3(2.5, 0, 0)
			game.hud.bld = ch
			game.hud.open("building")
			var opened: bool = game.hud.is_open("building")
			game.hud.quick_move(pl.inv, hn, true)
			var in_chest: int = ch.inv.count("iron_ore") if ch else 0
			var left_pl: int = pl.inv.count("iron_ore")
			var ci := -1
			if ch:
				for i in ch.inv.slots.size():
					if ch.inv.slots[i] != null:
						ci = i
						break
			if ci >= 0:
				game.hud.quick_move(ch.inv, ci, true)
			var back_pl: int = pl.inv.count("iron_ore")
			var back_ch: int = ch.inv.count("iron_ore") if ch else -1
			game.hud.close("building")
			if ch == null:
				print("v13 no chest: ", f.can_place("chest", cc))
			var move_ok: bool = in_chest == 75 and left_pl == 0 and back_pl == 75 and back_ch == 0
			# Alt+клик — стопка, Shift+Alt+клик — все такие, «Вернуть» — всё назад
			var i0 := -1
			for i in pl.inv.slots.size():
				if pl.inv.slots[i] != null:
					i0 = i
					break
			game.hud.trash(pl.inv, i0)
			var after_one: int = pl.inv.count("iron_ore")
			game.hud.untrash()
			for i in pl.inv.slots.size():
				if pl.inv.slots[i] != null:
					i0 = i
					break
			game.hud.trash_all(pl.inv, i0)
			var after_all: int = pl.inv.count("iron_ore")
			game.hud.untrash()
			var trash_ok: bool = after_one < 75 and after_one > 0 and after_all == 0 and pl.inv.count("iron_ore") == 75
			# рекорд производства: деньги есть, купонов нет
			var cr0: int = game.credits
			var cp0: int = pl.inv.count("sink_coupon")
			game.progress17.made["steel"] = 100000
			game.progress17._check("steel")
			var rec_ok: bool = game.credits > cr0 and pl.inv.count("sink_coupon") == cp0 and int(Progress17.reward_of("steel", 10000).coupons) == 0
			# залежь под бур: 2×2 у бура 2×2, бур прилипает к углу залежи
			var w = game.world
			var msz := int(DB.building("miner").get("size", 1))
			var dep_c = null
			for c in w.deposit:
				var dd: Dictionary = w.deposits[w.deposit[c]]
				if int(dd.get("cells", 0)) == 1 and not DB.is_fluid(str(dd.get("item", ""))) and not w.deposit_hidden(w.deposit[c]):
					dep_c = w.dep_corner(c)
					break
			var fit_n := 0
			var snap_ok := false
			if dep_c != null:
				for dx in 3:
					for dz in 3:
						if w.deposit.get(World.wc(dep_c + Vector2i(dx, dz)), -1) == w.deposit[dep_c]:
							fit_n += 1
				game.build_type = "miner"
				game.hover_point = World.cell_to_world(dep_c + Vector2i(1, 1)) + Vector3(0.7, 0, 0.4)
				game.hover_cell = World.world_to_cell(game.hover_point)
				var sn = game._miner_snap()
				game.build_type = ""
				snap_ok = sn != null and sn == dep_c and f._miner_why("miner", dep_c) == ""
			var dep_ok: bool = msz == 2 and fit_n == 4 and snap_ok
			print("TEST v13 zone=", zn_ok, " open=", opened, " move=", in_chest, "/", left_pl, "/", back_pl, "/", back_ch, " trash=", after_one, "/", after_all, " rec=", rec_ok,
				" dep=", msz, "/", fit_n, "/", snap_ok, " ", "OK" if zn_ok and move_ok and trash_ok and rec_ok and dep_ok else "FAIL")
			tree.quit()
		"quantum21":
			# 21: квантовое измерение — портал, жилы в суперпозиции, запутанные пары, тени
			var f = game.factory
			var Q = game.quantum
			game.flags["free_build"] = true
			DB.data.buildings["quantum_portal"]["params"]["power"] = 0
			var pc: Vector2i = f.hq.cell + Vector2i(8, -10)
			for dx in range(-1, 5):
				for dz in range(-1, 5):
					game.world.remove_node(World.wc(pc + Vector2i(dx, dz)))
			var portal = put(game, "quantum_portal", pc, 0)
			await tree.create_timer(0.6).timeout
			var nveins: int = Q.veins.size()
			var vid: int = Q.veins.keys()[0] if nveins > 0 else 0
			var q0 = Q.veins[vid].cells[0] if vid > 0 else [0, 0]
			var vc := Vector2i(q0[0], q0[1])
			var why_before: String = f._miner_why("miner_mk4", vc)
			# смотрим на жилу: герой рядом, камера на неё
			game.player.position = World.cell_to_world(vc) + Vector3(-3, 0, 3)
			game.cam_focus = game.player.position
			for i in 30:
				await tree.process_frame
			var by_look: bool = str(Q.veins[vid].item) != ""
			if not by_look:
				Q.collapse(vid)
			var item: String = str(Q.veins[vid].item)
			var why_after: String = f._miner_why("miner_mk4", vc)
			# вернуть в суперпозицию свободные (бура нет)
			game.flags["free_build"] = false
			f.hq.inv.add("quantum_shard", 20)
			var rs: int = Q.reset_free()
			var back_super: bool = str(Q.veins[vid].item) == "" and game.world.deposit_item(vc) == "q_superposition"
			game.flags["free_build"] = true
			# запутанные ящики
			var ca = put_near(game, "entangled_chest", f.hq.cell + Vector2i(-8, 8))
			var cb = put_near(game, "entangled_chest", f.hq.cell + Vector2i(30, -20))
			ca.inv.add("iron_plate", 7)
			var shared: bool = cb.inv.count("iron_plate") == 7 and Q.partner(ca) == cb
			var had: int = game.player.inv.count("iron_plate")
			f.deconstruct(ca)
			var kept: bool = cb.inv.count("iron_plate") == 7 and game.player.inv.count("iron_plate") == had
			# запутанные станции: одна сеть через всю карту
			DB.data.settings["power_mode"] = "stations"
			var pa = put_near(game, "entangled_pole", f.hq.cell + Vector2i(-40, 30))
			var pb = put_near(game, "entangled_pole", f.hq.cell + Vector2i(45, -35))
			f.power_dirty = true
			await tree.create_timer(0.3).timeout
			var one_net: bool = pa != null and pb != null and pa.net >= 0 and pa.net == pb.net
			# тень: на виду замирает, за спиной — бежит
			var cam: Camera3D = game.get_viewport().get_camera_3d()
			var pp: Vector3 = game.player.position
			var fwd: Vector3 = -cam.global_transform.basis.z if cam else Vector3(0, 0, -1)
			fwd.y = 0
			fwd = fwd.normalized()
			var e1 = game.enemies.spawn("q_shade", pp + fwd * 14.0)
			var e2 = game.enemies.spawn("q_shade", pp - fwd * 14.0)
			await tree.process_frame
			var a1: Vector3 = e1.pos
			var a2: Vector3 = e2.pos
			await tree.create_timer(0.8).timeout
			var m1: float = World.dist(a1, e1.pos)
			var m2: float = World.dist(a2, e2.pos)
			print("TEST quantum21 veins=%d before='%s' looked=%s item=%s after_ok=%s reset=%d super=%s shared=%s kept=%s one_net=%s seen_moved=%.2f unseen_moved=%.2f " % [nveins, why_before.left(20), by_look, item, why_after == "", rs, back_super, shared, kept, one_net, m1, m2],
				"OK" if portal != null and nveins >= 3 and why_before != "" and item != "" and why_after == "" and rs >= 1 and back_super and shared and kept and one_net and m1 < 0.1 and m2 > 0.3 else "FAIL")
		"sizes21":
			# 21: машины крупнее героя — 2×2 (крупные 3×3–4×4), модель увеличена вместе с местом
			var f = game.factory
			game.flags["free_build"] = true
			var sm_size := int(DB.building("smelter").get("size", 1))
			var md: Dictionary = DB.data.models.get(DB.building("smelter").get("model", "smelter"), {})
			var sk: float = float(md.get("scale", 1.0)) / float(md.get("scale0", 1.0))
			var scale_ok: bool = sk >= 1.99 and sk < 2.3   # 1.3: машины чуть крупнее в своём месте
			var ore := nearest_deposit(game, "iron_ore", f.hq.cell)
			var mn = null
			for off in [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1)]:
				mn = put(game, "miner", game.world.dep_corner(ore) + off, 0)
				if mn != null:
					break
			var mine_ok: bool = mn != null and mn.recipe == "iron_ore" and mn.size == 2
			# печь 2×2 у штаба: лента сзади кормит её рудой, слиток выходит
			var c: Vector2i = f.hq.cell + Vector2i(-1, 6)
			for dx in range(-4, 6):
				for dz in range(-1, 4):
					game.world.remove_node(World.wc(c + Vector2i(dx, dz)))
			var sm = put(game, "smelter", c, 0)
			var bl = put(game, "belt", c + Vector2i(-1, 0), 0)
			var cells: int = f.footprint("smelter", c).size() if sm != null else 0
			if bl != null:
				bl.item = ""
				f.set_item(bl, "iron_ore", f.sim_time)
			sm.recipe = "smelt_iron" if DB.data.recipes.has("smelt_iron") else sm.recipe
			sm.inv.add("iron_ore", 6)
			await tree.create_timer(6.0).timeout
			var made: int = sm.out.count("iron_ingot") if sm.out != null else 0
			var rh2: float = f.roof_h("smelter")
			var hq_size: int = f.hq.size
			print("TEST sizes21 smelter_size=%d cells=%d scale_x2=%s miner=%s (%s) made=%d roof=%.2f hq=%d " % [sm_size, cells, scale_ok, mine_ok, mn.recipe if mn else "-", made, rh2, hq_size],
				"OK" if sm_size == 2 and cells == 4 and scale_ok and mine_ok and made > 0 and hq_size == 4 else "FAIL")
		"physics21":
			# 21: обломки, взрыв толкает монстров и предметы, тело убитого отлетает, предметы катятся
			var f = game.factory
			game.flags["free_build"] = true
			var c: Vector2i = f.hq.cell + Vector2i(14, 12)
			for dx in range(-8, 9):
				for dz in range(-8, 9):
					game.world.remove_node(World.wc(c + Vector2i(dx, dz)))
			var pl = game.player
			pl.position = World.cell_to_world(c + Vector2i(-6, -6))
			var sm = put(game, "smelter", c, 0)
			f.damage(sm, 99999.0)
			var n_deb: int = game.physics.pieces.size()
			var y0 := 0.0
			for pc in game.physics.pieces:
				y0 += pc.pos.y
			await tree.create_timer(1.5).timeout
			var landed := 0
			for pc in game.physics.pieces:
				if pc.pos.y < f.support_at(pc.pos) + 0.6:
					landed += 1
			var mid: Vector3 = World.cell_to_world(c + Vector2i(4, 0))
			var e = game.enemies.spawn("crawler", mid + Vector3(2.0, 0, 0))
			e.speed = 0.0
			game.drops.spawn("iron_ore", 1, mid + Vector3(-1.5, 0.4, 0))
			await tree.create_timer(1.0).timeout
			var dr = game.drops.list.back()
			var dx0: float = Vector2(dr.pos.x - mid.x, dr.pos.z - mid.z).length()
			var ex0: float = e.pos.x
			game.fx.explosion(mid, 2.0, Color(1, 0.5, 0.2))
			await tree.create_timer(0.8).timeout
			var e_moved: float = e.pos.x - ex0
			var d_moved: float = Vector2(dr.pos.x - mid.x, dr.pos.z - mid.z).length() - dx0
			# тело: монстр рядом с героем, толчок и смерть — тело летит дальше
			pl.position = mid + Vector3(-4, 0, 3)
			var e2 = game.enemies.spawn("crawler", mid + Vector3(0, 0, 3))
			e2.speed = 0.0
			await tree.create_timer(0.5).timeout
			var had_rig: bool = game.enemies.rigs.has(e2)
			var cx0: float = e2.pos.x
			game.enemies.knock(e2, Vector3(9, 0, 0), 5.0)
			game.enemies.hit(e2, 99999.0)
			await tree.create_timer(0.7).timeout
			var c_moved: float = e2.pos.x - cx0
			print("TEST physics21 debris=%d landed=%d blast_monster=%.1f blast_drop=%.1f rig=%s corpse_flew=%.1f " % [n_deb, landed, e_moved, d_moved, had_rig, c_moved],
				"OK" if n_deb >= 6 and landed >= n_deb / 2 and e_moved > 0.8 and d_moved > 0.8 and (c_moved > 0.8 or not had_rig) else "FAIL")
		"export_heroes":
			# 1.3: герои в позах для картинки-заставки (Blender): кожа на костях запекается в позу,
			# инструмент и оружие — отдельными деталями; GLB в --out=папку (по умолчанию /tmp/heroes13)
			var out := "/tmp/heroes13"
			for a in OS.get_cmdline_user_args():
				if a.begins_with("--out="):
					out = a.substr(6)
			DirAccess.make_dir_recursive_absolute(out)
			# [герой, предмет, ход (скорость), фаза шага, удар (поза 0..1 или −1)]
			var list := [["hero_valera", "iron_pickaxe", 0.0, 0.0, 0.32], ["hero_lu", "iron_axe", 2.2, 0.3, -1.0],
				["hero_harry", "blaster", 0.0, 0.0, -1.0], ["hero_castiel", "iron_pickaxe", 2.4, 0.7, -1.0],
				["hero_anime", "blaster", 0.0, 0.0, -1.0], ["hero_klara", "iron_axe", 0.0, 0.0, 0.55]]
			var okn := 0
			for e in list:
				var pl = load("res://scripts/player.gd").new()
				pl.game = {"flags": {}, "profession": ""}
				pl.look = e[0]
				game.add_child(pl)
				pl.build()
				pl.inv.slots[0] = {"id": e[1], "n": 1}
				pl.selected = 0
				pl._update_tool_visual()
				pl.position = Vector3.ZERO
				pl.rotation = Vector3.ZERO
				var spd: float = e[2]
				for f in 90:
					pl.move_dir = Vector3(spd, 0, 0)
					pl.aim = Vector3(5, 1.2, 0)
					if float(e[4]) >= 0.0:
						pl.game.flags["pose"] = e[4]
					pl.t = float(e[3]) + f * 0.016
					pl._animate(0.016, false)
				pl.rotation = Vector3.ZERO
				pl.position = Vector3.ZERO
				if _export_hero(pl, "%s/%s.glb" % [out, e[0]]):
					okn += 1
				pl.queue_free()
			print("TEST export_heroes n=%d " % okn, "OK" if okn == list.size() else "FAIL")
		"fuse13":
			# 1.3: бур + печь в одном здании: печь жжёт уголь (из своей ячейки и с ленты), без угля не плавит
			var f = game.factory
			var fz = f.fz
			game.flags["free_build"] = true
			var c: Vector2i = f.hq.cell + Vector2i(-14, -10)
			for dx in range(-3, 9):
				for dz in range(-3, 9):
					game.world.remove_node(World.wc(c + Vector2i(dx, dz)))
			var di := -1
			for i in game.world.deposits.size():
				if str(game.world.deposits[i].get("item", "")) == "iron_ore":
					di = i
			for fc in f.footprint("miner", c):
				game.world.set_deposit(fc, di)
			var mn = put(game, "miner", c, 0)
			var msz: int = int(DB.building("miner").get("size", 1))
			var sm = put(game, "furnace", c + Vector2i(msz, 0), 0)
			var wt = put(game, "wind_turbine", c + Vector2i(0, msz), 0)
			game.cmd("fuse", {"a": mn, "b": sm, "kind": "combo"})
			game.cmd("fuse", {"a": mn, "b": wt, "kind": "combo"})
			var built: bool = mn != null and sm != null and sm.host == mn
			# без угля — не плавит
			for step in int(20.0 / Factory.TICK):
				f._tick(Factory.TICK)
			var dry_out: int = mn.out.count("iron_ingot") + (mn.inv.count("iron_ingot") if mn.inv else 0)
			# уголь с ленты (accept в основу) уходит в печь и сгорает
			var took: bool = f.accept(mn, "coal", null)
			for i in 4:
				f.accept(mn, "coal", null)
			var fuel0: int = sm.fuel.count("coal") if sm.fuel else -1
			for step in int(90.0 / Factory.TICK):
				f._tick(Factory.TICK)
			var fuel1: int = sm.fuel.count("coal") if sm.fuel else -1
			var ingots: int = mn.out.count("iron_ingot") + (mn.inv.count("iron_ingot") if mn.inv else 0) + sm.out.count("iron_ingot")
			var burns: bool = fuel0 > 0 and fuel1 < fuel0
			# уголь, положенный в саму основу (окно здания, бур на угле), тоже уходит в печь
			sm.fuel.slots.fill(null)
			sm.fuel_t = 0.0
			mn.out.add("coal", 3)
			for step in int(30.0 / Factory.TICK):
				f._tick(Factory.TICK)
			var from_host: bool = mn.out.count("coal") < 3
			print("TEST fuse13 built=%s dry=%d took=%s fuel=%d→%d ingots=%d power=%.2f host_fuel=%s " % [built, dry_out, took, fuel0, fuel1, ingots, mn.csat, from_host],
				"OK" if built and dry_out == 0 and burns and ingots > 0 and from_host else "FAIL")
		"rocks13":
			# 1.3: камни лежат по 1–2 (не кучами), не на месторождениях, после добычи не появляются снова
			var w = game.world
			var crowd := 0
			var on_dep := 0
			var total := 0
			for c in w.nodes:
				var n = w.nodes[c]
				if not World._is_rock(n.res) or n.res == "meteorite":
					continue
				total += 1
				var near := 0
				for dx in range(-2, 3):
					for dz in range(-2, 3):
						var m = w.nodes.get(World.wc(c + Vector2i(dx, dz)))
						if (dx != 0 or dz != 0) and m != null and World._is_rock(m.res):
							near += 1
				if near > 2:
					crowd += 1
				if w.deposit.has(c):
					on_dep += 1
			var rc := Vector2i(-1, -1)
			for c in w.nodes:
				if str(w.nodes[c].res).begins_with("ore_"):
					rc = c
					break
			var r0: int = w.respawns.size()
			var gone := false
			if rc.x >= 0:
				for i in 100:
					if w.hit_node(rc, 1000.0, "pickaxe", true):
						gone = true
						break
			w.update_respawns(1000.0)
			var no_back: bool = gone and not w.nodes.has(rc) and w.respawns.size() == r0
			print("TEST rocks13 total=%d crowded=%d on_deposit=%d mined=%s no_respawn=%s " % [total, crowd, on_dep, gone, no_back],
				"OK" if total > 50 and crowd * 50 <= total and on_dep == 0 and no_back else "FAIL")
		"trees14":
			# 1.4: пень снова становится деревом; саженец сажается в свободную клетку и сам вырастает
			var w = game.world
			var tc := Vector2i(-1, -1)
			var tres := ""
			for c in w.nodes:
				if str(w.nodes[c].res) == "tree_oak" or str(w.nodes[c].res) == "tree_pine":
					tc = c
					tres = str(w.nodes[c].res)
					break
			var felled := false
			if tc.x >= 0:
				for i in 100:
					if w.hit_node(tc, 1000.0, "axe", true):
						felled = true
						break
			var stump_ok: bool = felled and w.nodes.has(tc) and str(w.nodes[tc].res) == "stump"
			w.update_respawns(10000.0)
			var regrow_ok: bool = w.nodes.has(tc) and str(w.nodes[tc].res) == tres
			var drop_ok: bool = DB.data.resources.get("tree_oak", {}).get("drops", []).any(func(d): return d.get("item", "") == "sapling_oak")
			var pl = game.player
			for dx in range(-4, 5):
				for dz in range(-4, 5):
					w.remove_node(World.wc(World.world_to_cell(pl.position) + Vector2i(dx, dz)))
			pl.inv.add("sapling_birch", 2)
			var slot: int = pl.inv.slots.find(pl.inv.slots.filter(func(x): return x != null and x.id == "sapling_birch")[0])
			var used: bool = pl.use_item(slot)
			var young := Vector2i(-1, -1)
			for c in w.nodes:
				if str(w.nodes[c].res) == "young_birch":
					young = c
			var planted: bool = used and young.x >= 0 and pl.inv.count("sapling_birch") == 1
			w.update_respawns(10000.0)
			var grown: bool = young.x >= 0 and w.nodes.has(young) and str(w.nodes[young].res) == "tree_birch"
			print("TEST trees14 felled=%s stump=%s regrow=%s sapling_drop=%s planted=%s grown=%s " % [felled, stump_ok, regrow_ok, drop_ok, planted, grown],
				"OK" if felled and stump_ok and regrow_ok and drop_ok and planted and grown else "FAIL")
		"ports13":
			# 1.3: у здания 2×2 два выхода (обе клетки передней стороны), на стене видны разъёмы; поток делится
			var f = game.factory
			game.flags["free_build"] = true
			var c: Vector2i = f.hq.cell + Vector2i(-12, 8)
			for dx in range(-3, 8):
				for dz in range(-3, 8):
					game.world.remove_node(World.wc(c + Vector2i(dx, dz)))
			var sm = put(game, "smelter", c, 0)
			var sz: int = sm.size if sm else 0
			var socks0: int = f.socket_keys.get(sm, []).size()
			var fr: Array = sm.fronts()
			var b1 = put(game, "belt", fr[0], 0)
			var b2 = put(game, "belt", fr[1], 0) if fr.size() > 1 else null
			var socks1: int = f.socket_keys.get(sm, []).size()
			sm.out.add("iron_ingot", 6)
			var got1 := 0
			var got2 := 0
			for step in int(6.0 / Factory.TICK):
				f._tick(Factory.TICK)
				if b1 and b1.item != "":
					got1 += 1
					b1.item = ""
					f.items_on_belts -= 1
					f._drop_item_visual(b1)
				if b2 and b2.item != "":
					got2 += 1
					b2.item = ""
					f.items_on_belts -= 1
					f._drop_item_visual(b2)
			print("TEST ports13 size=%d sockets=%d→%d outs=%d got=%d+%d " % [sz, socks0, socks1, sm.nexts.size(), got1, got2],
				"OK" if sz == 2 and socks0 == 2 and socks1 == 0 and sm.nexts.size() == 2 and got1 > 0 and got2 > 0 else "FAIL")
		"tune13":
			# 1.3: тонкая настройка ветряка поднимает выдачу (и отдельного, и встроенного); составное ест энергию
			var f = game.factory
			game.flags["free_build"] = true
			var c: Vector2i = f.hq.cell + Vector2i(14, -14)
			for dx in range(-3, 12):
				for dz in range(-3, 12):
					game.world.remove_node(World.wc(c + Vector2i(dx, dz)))
			var wt = put(game, "wind_turbine", c, 0)
			var sm = put(game, "smelter", c + Vector2i(2, 0), 0)
			sm.inv.add("iron_ore", 50)
			var sup := func() -> float:
				for i in 5:
					f._tick(Factory.TICK)
				return float(f.nets[wt.net].supply) if wt.net >= 0 and wt.net < f.nets.size() else -1.0
			var s0: float = sup.call()
			wt.cfg["tune"] = Tuning.center(Tuning.kind_of(wt))
			var s1: float = sup.call()
			var solo_ok: bool = s0 > 0.0 and s1 > s0 * 1.2
			# встроенный ветряк
			var mn = put(game, "assembler", c + Vector2i(0, 5), 0)
			var w2 = put(game, "wind_turbine", c + Vector2i(1, 5), 0)
			game.cmd("fuse", {"a": mn, "b": w2, "kind": "combo"})
			var host = w2.host if w2.host != null else mn
			for i in 5:
				f._tick(Factory.TICK)
			var g0: float = host.gen_cap
			w2.cfg["tune"] = Tuning.center(Tuning.kind_of(w2))
			for i in 5:
				f._tick(Factory.TICK)
			var g1: float = host.gen_cap
			var sub_ok: bool = g0 > 0.0 and g1 > g0 * 1.2
			# составное без генератора: ест энергию из сети
			var a1 = put(game, "smelter", c + Vector2i(6, 0), 0)
			var a2 = put(game, "assembler", c + Vector2i(7, 0), 0)
			game.cmd("fuse", {"a": a1, "b": a2, "kind": "combo"})
			var h2 = a2.host if a2.host != null else a1
			h2.inv.add("iron_ore", 30)
			for i in 40:
				f._tick(Factory.TICK)
			var eats: bool = h2.cneed > 0.0
			print("TEST tune13 solo=%.1f→%.1f sub_gen=%.1f→%.1f combo_need=%.1f " % [s0, s1, g0, g1, h2.cneed],
				"OK" if solo_ok and sub_ok and eats else "FAIL")
		"rush13":
			# 1.3: «Натиск» — начинается через start_min, дальше каждые every_min, монстров больше и они сильнее
			var en = game.enemies
			var r: Dictionary = DB.data.waves.rush
			r.enabled = true
			r.start_min = 0.5
			r.every_min = 0.25
			en.rush_timer = -1.0
			en.wave_timer = 99999.0
			var counts := []
			var hps := []
			var t_first := -1.0
			var t := 0.0
			while t < 90.0 and counts.size() < 3:
				var n0: int = en.list.size()
				var n_before: int = en.rush_n
				en._update_rush(0.5)
				t += 0.5
				if en.rush_n > n_before:
					if t_first < 0.0: t_first = t
					counts.append(en.list.size() - n0)
					var hp := 0.0
					for i in range(n0, en.list.size()):
						hp += en.list[i].maxhp / float(DB.data.enemies[en.list[i].type].get("hp", 40))
					hps.append(hp / maxf(1.0, en.list.size() - n0))
			r.enabled = false
			var ok: bool = counts.size() == 3 and absf(t_first - 30.0) < 1.0 and counts[2] > counts[0] and hps[2] > hps[0]
			print("TEST rush13 first=%.1f counts=%s hp_k=%s " % [t_first, counts, hps], "OK" if ok else "FAIL")
		"mod13":
			# 1.3: мод добавляет руду (залежь в мир), монстра в волны, модель героя, здание в дерево открытий и свой перевод
			var mp: String = DB.mods_dir().path_join("test_mod13")
			DirAccess.make_dir_recursive_absolute(mp)
			var ore: Dictionary = DB.data.items.iron_ore.duplicate(true)
			ore["name"] = "Кобальтовая руда"
			ore["name_en"] = "Cobalt ore"
			var dep: Dictionary = DB.data.world.deposits[0].duplicate(true)
			dep["item"] = "cobalt_ore"
			var beast: Dictionary = DB.data.enemies[DB.data.waves.groups[0].enemy].duplicate(true)
			beast["name"] = "Мод-жук"
			beast["name_en"] = "Mod bug"
			beast["spawn_weight"] = 5.0
			var hero: Dictionary = DB.data.models[Player.looks()[0]].duplicate(true)
			hero["category"] = "Герои"
			hero["name"] = "Мод-герой"
			var fb: Dictionary = DB.data.buildings.furnace.duplicate(true)
			fb["name"] = "Мод-печь"
			var n_dep: int = DB.data.world.deposits.size()
			DB.write_file(mp.path_join("mod.json"), {"name": "Тестовый мод", "version": "1.0"})
			DB.write_file(mp.path_join("items.json"), {"cobalt_ore": ore})
			DB.write_file(mp.path_join("world.json"), {"deposits_add": [dep]})
			DB.write_file(mp.path_join("enemies.json"), {"mod_bug": beast})
			DB.write_file(mp.path_join("models.json"), {"hero_mod13": hero})
			DB.write_file(mp.path_join("buildings.json"), {"mod_furnace": fb})
			DB.write_file(mp.path_join("tech.json"), {"t_start": {"_patch": true, "unlocks": {"buildings_add": ["mod_furnace"]}}})
			DB.write_file(mp.path_join("lang.json"), {"en": {"Мод-печь": "Mod furnace", "Мод-герой": "Mod hero"}})
			DB.load_all()
			var r := {
				"ore": DB.data.items.has("cobalt_ore"),
				"dep": DB.data.world.deposits.size() == n_dep + 1 and str(DB.data.world.deposits[-1].item) == "cobalt_ore",
				"beast": game.enemies.auto_groups().any(func(g): return g.enemy == "mod_bug"),
				"hero": "hero_mod13" in Player.looks(),
				"tech": "mod_furnace" in DB.data.tech.t_start.unlocks.buildings and "furnace" in DB.data.tech.t_start.unlocks.buildings,
			}
			var old_l = Prefs.values.get("language", "ru")
			Prefs.values["language"] = "en"
			Lang.apply_locale()
			r["tr_ore"] = game.tr("Кобальтовая руда") == "Cobalt ore"
			r["tr_bug"] = game.tr("Мод-жук") == "Mod bug"
			r["tr_lang"] = game.tr("Мод-печь") == "Mod furnace"
			Prefs.values["language"] = old_l
			Lang.apply_locale()
			for fn in DirAccess.get_files_at(mp):
				DirAccess.remove_absolute(mp.path_join(fn))
			DirAccess.remove_absolute(mp)
			DB.load_all()
			r["clean"] = not DB.data.items.has("cobalt_ore") and DB.data.world.deposits.size() == n_dep
			var ok := r.values().all(func(x): return x)
			print("TEST mod13 %s " % [r], "OK" if ok else "FAIL")
		"demo13":
			# 1.3: демо — этапы дерева выше 3 закрыты насовсем, этапы 1–3 открываются как обычно
			var T = game.tech
			DB.data.settings["demo"] = {"enabled": true, "max_tier": 3, "text": "Ожидайте релиз!"}
			T.done.clear()
			T.refresh_locks()
			var hi := ""
			var lo := ""
			for id in T.nodes():
				var tr_n := int(T.nodes()[id].get("tier", 0))
				if tr_n > 3 and hi == "" and not T.nodes()[id].get("unlocks", {}).get("buildings", []).is_empty():
					hi = id
				if tr_n == 2 and lo == "":
					lo = id
			var hb := str(T.nodes()[hi].unlocks.buildings[0])
			var locked_hi: bool = str(DB.locked.get("b:" + hb, "")) == "__demo"
			var why_hi: String = T.why_not(hi)
			T.unlock(hi)
			var still: bool = not T.done.has(hi) and Tech.building_locked(hb)
			T.unlock_all()
			var lo_done: bool = T.done.has(lo)
			var hi_after: bool = T.done.has(hi)
			var opener: String = T.opener("b", hb)
			DB.data.settings["demo"]["enabled"] = false
			T.unlock_all()
			var full_ok: bool = T.done.has(hi) and not Tech.building_locked(hb)
			var ok: bool = locked_hi and why_hi.begins_with("Демо") and still and lo_done and not hi_after and opener == "Ожидайте релиз!" and full_ok
			print("TEST demo13 hi=%s b=%s locked=%s why=%s still=%s lo=%s hi_after=%s full=%s " % [hi, hb, locked_hi, why_hi, still, lo_done, hi_after, full_ok], "OK" if ok else "FAIL")
		"lang13":
			# 1.3: английский — словарь, шаблоны с числами, строки по частям, поле name_en у объекта мода
			var old_l = Prefs.values.get("language", "ru")
			DB.data.items["iron_ore"]["name_en"] = "Iron ore (mod)"
			Lang.rebuild()
			Prefs.values["language"] = "en"
			Lang.apply_locale()
			var lb := Label.new()
			game.add_child(lb)
			var cases := [["Рюкзак", "Backpack"], ["Рюкзак: 24 ячеек", "Backpack: 24 slots"], ["Сила ×1.5", "Strength ×1.5"],
				["Рюкзак\nСдать", "Backpack\nDeliver"], [str(DB.data.items.iron_ore.name), "Iron ore (mod)"], ["Abc 12", "Abc 12"],
				["Сегодня ночью осада: Голем идёт с севера! Стройте оборону.", ""]]
			var ok := true
			var outs := []
			for c in cases:
				lb.text = c[0]
				var got := lb.tr(c[0])
				outs.append(got)
				if c[1] != "" and got != c[1]:
					ok = false
			ok = ok and outs[6].begins_with("Siege tonight:") and outs[6].ends_with("Build defenses.")
			Prefs.values["language"] = "ru"
			Lang.apply_locale()
			var ru_back := lb.tr("Рюкзак")
			print("lang13 ok_en=", ok, " ru=", ru_back, " loc=", TranslationServer.get_locale())
			ok = ok and ru_back == "Рюкзак"
			Prefs.values["language"] = old_l
			Lang.apply_locale()
			DB.data.items["iron_ore"].erase("name_en")
			Lang.rebuild()
			lb.queue_free()
			print("TEST lang13 %s " % [outs], "OK" if ok else "FAIL")
		"hop13":
			# 1.3: костёр и камень не обходить — перешагнуть нельзя (выше шага), перепрыгнуть можно; стена — нельзя
			var f = game.factory
			game.flags["free_build"] = true
			var pl = game.player
			var c: Vector2i = f.hq.cell + Vector2i(-12, -12)
			for dx in range(-4, 5):
				for dz in range(-4, 5):
					game.world.remove_node(World.wc(c + Vector2i(dx, dz)))
			var cf = put(game, "campfire", c, 0)
			var wl = put(game, "wall", c + Vector2i(0, 2), 0)
			pl.position = World.cell_to_world(c + Vector2i(-1, 0))
			pl.position.y = f.support_at(pl.position)
			var ht: float = pl.hop_top(c)
			var walk_block: bool = pl._blocked(World.cell_to_world(c)) if ht - pl.position.y > 0.7 else true
			pl.position.y += ht + 0.1 - f.support_at(pl.position)
			var air_pass: bool = not pl._blocked(World.cell_to_world(c))
			pl.position.y += 1.0
			var wall_block: bool = pl._blocked(World.cell_to_world(c + Vector2i(0, 2)))
			var rock_ok := true
			game.world.add_node("ore_iron", c + Vector2i(2, 0))
			var rt: float = pl.hop_top(c + Vector2i(2, 0))
			rock_ok = rt >= 0.0
			print("TEST hop13 fire_top=%.2f walk_block=%s air_pass=%s wall_block=%s rock=%.2f " % [ht, walk_block, air_pass, wall_block, rt],
				"OK" if cf != null and ht >= 0.0 and walk_block and air_pass and wall_block and rock_ok else "FAIL")
		"roofs21":
			# 21: ряд печей не надо обходить — прыжком на крышу, по крышам, вниз с другой стороны
			var f = game.factory
			game.flags["free_build"] = true
			var c: Vector2i = f.hq.cell + Vector2i(-14, 10)
			for dx in range(-6, 7):
				for dz in range(-6, 7):
					game.world.remove_node(World.wc(c + Vector2i(dx, dz)))
			# 1.3: прыжок обычный — на крышу выше «Высоты прыжка» + шага не запрыгнуть; берём здание пониже
			var low := ""
			for bt in DB.data.buildings:
				var bd: Dictionary = DB.data.buildings[bt]
				if str(bd.get("behavior", "")) in ["storage", "crafter", "generator", "tank", "battery"] and int(bd.get("size", 1)) <= 2 \
						and not (bd.get("params") is Dictionary and bd.params.get("no_climb", false)):
					var h0: float = f.roof_h(bt)
					if h0 > 1.0 and h0 < 2.0:
						low = bt
						break
			var placed := 0
			for dz in range(-4, 5):
				if put(game, low, c + Vector2i(0, dz), 0) != null:
					placed += 1
			var pl = game.player
			var rh: float = f.roof_h(low)
			var tall_no: bool = f.roof_h("smelter") > float(DB.setting("jump_height", 1.5)) + float(DB.setting("climb_height", 0.7))
			game.cam_yaw = 0.0; game.cam_yaw_target = 0.0
			pl.position = World.cell_to_world(c + Vector2i(-3, 0))
			pl.position.y = f.support_at(pl.position)
			Input.action_press("move_right")
			await tree.create_timer(1.6).timeout
			var stuck_x: float = pl.position.x - World.cell_to_world(c).x
			var walk_blocked: bool = stuck_x < -0.5
			var top_y := -99.0
			for i in 14:
				pl.jump()
				for k in 8:
					await tree.process_frame
					if pl.on_roof():
						top_y = maxf(top_y, pl.position.y)
				if OS.get_cmdline_user_args().has("--dbg"):
					print("dbg jt=", pl.jump_t, " jy=", pl.jump_y, " p=", pl.position - World.cell_to_world(c), " rt=", f.roof_top(f.grid.get(c)))
			Input.action_release("move_right")
			await tree.create_timer(0.6).timeout
			var past: float = pl.position.x - World.cell_to_world(c).x
			var crossed: bool = past > 1.5
			var on_ground: bool = absf(pl.position.y - f.support_at(pl.position)) < 0.2
			var wall = put(game, "wall", c + Vector2i(3, 3), 0)
			var wall_ok: bool = f.roof_top(wall) < 0.0
			print("low=", low, " placed=", placed, " tall_unreachable=", tall_no)
			print("TEST roofs21 roof_h=%.2f blocked_walk=%s (dx %.1f) climbed=%s (y %.2f) crossed=%s (dx %.1f) down=%s wall_no_climb=%s " % [rh, walk_blocked, stuck_x, top_y > -99.0, top_y, crossed, past, on_ground, wall_ok],
				"OK" if tall_no and walk_blocked and top_y > -99.0 and crossed and on_ground and wall_ok else "FAIL")
		"v17":
			# 1.7: кротовины подряд, кротовина сама на пересечении, рамка в рюкзаке, НПС ждёт в разговоре, залежи у штаба,
			# пни, снос/энергия в обучении, личные задания гостя
			var f = game.factory
			game.flags["free_build"] = true
			var c: Vector2i = f.hq.cell + Vector2i(10, -14)
			for dx in range(-6, 14):
				for dz in range(-6, 14):
					game.world.remove_node(World.wc(c + Vector2i(dx, dz)))
			# а) две кротовины подряд: лента → J → J → лента → ящик
			var b0 = put(game, "belt", c, 0)
			put(game, "mole_junction", c + Vector2i(1, 0), 0)
			put(game, "mole_junction", c + Vector2i(2, 0), 0)
			put(game, "belt", c + Vector2i(3, 0), 0)
			var ch = put(game, "chest", c + Vector2i(4, 0), 0)
			for step in int(12.0 / Factory.TICK):
				if step % 10 == 0:
					f.accept(b0, "iron_ore", null)
				f._tick(Factory.TICK)
			var chain_ok: bool = ch != null and ch.inv.count("iron_ore") >= 5
			# б) линия лент поперёк готовой ленты — на пересечении встаёт кротовина
			var vc: Vector2i = c + Vector2i(3, 4)
			for k in 5:
				put(game, "belt", vc + Vector2i(0, k), 1)
			var hs: Vector2i = vc + Vector2i(-3, 2)
			game.build_type = "belt"
			game.build_dir = 0
			game.hover_cell = hs
			game.drag_last = Vector2i(-999, -999)
			game.drag_last = hs
			game.drag_placed = game.cmd("place", {"type": "belt", "cell": hs, "dir": 0})
			game.hover_cell = hs + Vector2i(6, 0)
			game._drag_world()
			var xb = f.building_at(vc + Vector2i(0, 2))
			var auto_jn: bool = xb != null and xb.type == "mole_junction"
			var after = f.building_at(vc + Vector2i(1, 2))
			var line_ok: bool = after != null and after.beh == "belt" and after.dir == 0
			game.build_type = ""
			# в) рамка выбора идёт за щелчком
			game.hud.open("inventory")
			await tree.process_frame
			game.player.inv.add("stone", 5)
			var pick := Player.hot_n() + 3
			game.player.inv.slots[pick] = {"id": "log", "n": 3}
			game.player.inv.changed.emit()
			game.hud._refresh_inventory()
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = true
			game.hud.inv_slots[pick]._gui_input(ev)
			var frame_ok: bool = game.hud.inv_slots[pick].selected and not game.hud.inv_slots[game.player.selected].selected
			game.hot_select(0)
			game.hud._refresh_inventory()
			var frame_back: bool = game.hud.inv_slots[0].selected and not game.hud.inv_slots[pick].selected
			# в2) окно тянется мышью, ширина и высота запоминаются, в ряд рюкзака помещается больше ячеек
			var iw = game.hud.windows.inventory
			iw.position = Vector2(10, 10)
			var w0: Vector2 = iw.size
			iw.resize_by(Vector2(260, 160), 3)
			iw.save_size()
			for i in 4:
				await tree.process_frame
			game.hud._refresh_inventory()
			await tree.process_frame
			var grown: bool = iw.size.x > w0.x + 200.0 and iw.size.y > w0.y + 100.0 and game.hud.inv_grid.columns > 9
			var remembered: bool = Prefs.get_value("win_size_inventory", null) is Array
			iw.reset_user_size()
			game.hud.close_all()
			# г) НПС стоит, пока с ним говорят
			game.day_t = 0.4
			var tr: Array = game.npcs.spawn_visit("trader", 1)
			var t = tr[0] if not tr.is_empty() else null
			var talk_ok := false
			if t != null:
				t.pos = game.player.position + Vector3(3, 0, 0)
				t.state = "leave"
				t.goal = t.pos + Vector3(60, 0, 0)
				game.hud.open_npc(t)
				var p0: Vector3 = t.pos
				for i in 90:
					await tree.process_frame
				talk_ok = game.hud.is_open("npc") and World.dist(p0, t.pos) < 0.5
				game.hud.close_all()
			# д) у штаба: открытые с начала залежи — по 2, следующие этапы — 1–2 сразу за стартовой зоной
			var w = game.world
			var later := {}
			for tid in DB.data.tech:
				for it in DB.data.tech[tid].get("unlocks", {}).get("deposits", []):
					later[str(it)] = true
			var cnt := {}
			for cc in w.deposit:
				var dv := World.delta(World.cell_to_world(w.center), World.cell_to_world(cc))
				if Vector2(dv.x, dv.z).length() / World.C < 20.0 + 16.0 + 4.0:
					cnt[w.deposit[cc]] = int(cnt.get(w.deposit[cc], 0)) + 1
			var dep_bad := []
			for idx in w.deposits.size():
				var d: Dictionary = w.deposits[idx]
				var fp: int = w.dep_fp(d)
				if fp <= 0 or int(d.get("patches", 0)) <= 0:
					continue
				var nn := int(ceil(float(cnt.get(idx, 0)) / float(fp * fp)))
				if nn < (1 if later.has(str(d.get("item", ""))) else 2):
					dep_bad.append("%s=%d" % [str(d.get("item", "")), nn])
			# е) пни: в режиме «оставлять» автоцель их не берёт
			var sc: Vector2i = World.world_to_cell(game.player.position) + Vector2i(1, 0)
			for k in 4:
				w.remove_node(World.wc(sc + Vector2i(k - 2, 0)))
			w.add_node("stump", sc)
			game.hover_point = World.cell_to_world(sc)
			Prefs.set_value("axe_keep_stumps", true)
			var tg1: Dictionary = game.find_target()
			var kept: bool = tg1.is_empty() or tg1.get("cell", Vector2i(-1, -1)) != sc
			game.toggle_stumps()
			var tg2: Dictionary = game.find_target()
			var uproot: bool = tg2.get("cell", Vector2i(-1, -1)) == sc
			game.toggle_stumps()
			# ж) обучение: шаги «Станция энергии», «Энергия», «Снос»; снос засчитывается
			var titles := []
			for st in game.tutorial.steps():
				titles.append(str(st.get("title", "")))
			var tut_steps: bool = "Станция энергии" in titles and "Энергия" in titles and "Снос" in titles and not "Провод" in titles
			game.tutorial.active = true
			game.tutorial.done = false
			game.tutorial.step = titles.find("Снос")
			game.tutorial._enter()
			var junk = put(game, "chest", c + Vector2i(8, 8), 0)
			game.cmd("demolish", {"cell": junk.cell})
			var dem_ok: bool = game.tutorial.progress()[0] == 1
			game.tutorial.step = titles.find("Энергия")
			game.tutorial._enter()
			DB.data.settings["power_mode"] = "stations"
			var g = put(game, "generator", c + Vector2i(-4, 8), 0)
			var pl = put(game, "pole", c + Vector2i(0, 8), 0)
			var ct := ""
			for bid in DB.data.buildings:
				var bd: Dictionary = DB.data.buildings[bid]
				if str(bd.get("behavior", "")) == "crafter" and float(bd.get("params", {}).get("power", 0)) > 0 and int(bd.get("size", 1)) <= 2 and not Tech.building_locked(bid):
					ct = bid
					break
			var mn = put(game, ct, c + Vector2i(1, 9), 0) if ct != "" else null
			if g != null:
				g.fuel.add("coal", 10)
			for i in 30:
				f._tick(Factory.TICK)
			await tree.process_frame
			var pw: Array = game.tutorial.progress()
			game.tutorial.skip()
			# з) задания гостя хранятся у него
			var ps: Dictionary = game.personal_state()
			var quest_saved: bool = ps.has("quest_i") and ps.has("tutorial")
			var fiber := 0.0
			for fl in DB.data.world.get("flora", []):
				if str(fl.get("resource", "")) == "bush_fiber":
					fiber += float(fl.get("density", 0))
			print("TEST v17 resize=", grown, "/", remembered, " chain=", chain_ok, " auto_junction=", auto_jn, " line=", line_ok, " frame=", frame_ok, "/", frame_back, " npc_waits=", talk_ok,
				" deposits_missing=", dep_bad, " stumps=", kept, "/", uproot, " tut=", tut_steps, " demolish=", dem_ok, " powered=", pw, " quest_saved=", quest_saved,
				" fiber=", fiber, " ", "OK" if grown and remembered and chain_ok and auto_jn and line_ok and frame_ok and frame_back and talk_ok and dep_bad.is_empty() and kept and uproot \
				and tut_steps and dem_ok and pw[0] >= 1 and quest_saved and fiber >= 0.06 else "FAIL")
		"v18":
			# 1.1.8: зона без участков и дешевле, Чёрный рынок, открытия за кредиты, НПС 1/50/всё, пояснения, залежь на фундаменте, лифты
			var f = game.factory
			var econ_ok: bool = Blocks.econ_on()
			var z = game.zone
			var steps: Array = DB.setting("zone", {}).get("steps", [])
			var zone_ok: bool = not bool(DB.setting("zone", {}).get("patches", true)) and steps.size() >= 20
			for i in mini(20, steps.size()):
				if steps[i].get("cost", {}).has("sink_coupon"):
					zone_ok = false
			var cr0: int = game.credits
			# а) открытие за кредиты: Мастерская — 100 кр
			var tw: Dictionary = DB.data.tech.get("t_workshop", {})
			game.tech.done.erase("t_workshop")
			game.tech.refresh_locks()
			for k in tw.get("cost", {}):
				f.hq.inv.add(k, int(tw.cost[k]))
			game.cmd("donate", {"id": "t_workshop"})
			var tech_ok: bool = int(tw.get("credits", 0)) == 100 and game.tech.done.has("t_workshop") and game.credits == cr0 - 100
			var later_ok: bool = int(DB.data.tech.get("t_mk2", {}).get("credits", 0)) > int(DB.data.tech.get("t_power", {}).get("credits", 0)) \
				and int(DB.data.tech.get("t_mk5", {}).get("credits", 0)) > 10000
			# б) Чёрный рынок: 30 пластин за минуту, кредиты на счёт; руда — тысячные доли кредита
			game.flags["free_build"] = true
			var c: Vector2i = f.hq.cell + Vector2i(10, -14)
			for dx in range(-6, 14):
				for dz in range(-6, 14):
					game.world.remove_node(World.wc(c + Vector2i(dx, dz)))
			var bm = put(game, "black_market", c, 0)
			var v_ore: float = Blocks.bm_value(game, "iron_ore")
			var v_pl: float = Blocks.bm_value(game, "iron_plate")
			var v_mo: float = Blocks.bm_value(game, "motor")
			var curve_ok: bool = v_ore > 0.0005 and v_ore < 0.002 and v_pl / 11.0 > v_ore / 2.0 * 5.0 and v_mo / 399.0 > v_pl / 11.0
			var cr1: int = game.credits
			var fed := 0
			var bm_ok := false
			if bm != null:
				for i in 8:
					if f.accept(bm, "motor", null):
						fed += 1
				for i in int(20.0 / 0.25):
					Blocks.update(f, bm, 0.25)
				var st: Dictionary = bm.bstate
				bm_ok = int(st.get("sold", 0)) == 8 and int(st.get("paid", 0)) == int(floor(v_mo * 8.0)) and game.credits == cr1 + int(st.get("paid", 0)) \
					and game.trade_earned >= int(st.get("paid", 0))
			var rate_ok := false
			if bm != null:
				bm.bstate.clear()
				for i in 8:
					f.accept(bm, "iron_ore", null)
				for i in 9:
					Blocks.update(f, bm, 0.25)   # 2,25 с — при 30 в минуту продан ровно один
				rate_ok = int(bm.bstate.get("sold", 0)) == 1 and float(bm.bstate.get("cr", 0.0)) > 0.0
			# в) бортиков нет в меню, предметы с поворотов не падают
			var rails_ok: bool = not bool(DB.building("belt_rails").get("params", {}).get("buildable", true)) and float(DB.setting("belt_spill_pct", 1.0)) == 0.0 \
				and not bool(DB.building("market").get("params", {}).get("buildable", true))
			# г) НПС: продать 50 и всё
			game.day_t = 0.4
			var tr: Array = game.npcs.spawn_visit("trader", 1)
			var t = tr[0] if not tr.is_empty() else null
			var npc_ok := false
			if t != null:
				game.player.inv.remove("log", game.player.inv.count("log"))
				game.player.inv.add("log", 120)
				var c0: int = game.credits
				var s50: bool = game.npcs.sell_to(t, "log", 50)
				var left50: int = game.player.inv.count("log")
				var sall: bool = game.npcs.sell_to(t, "log", -1)
				var pr: int = game.npcs.sell_price_to(t, "log")
				npc_ok = s50 and sall and left50 == 70 and game.credits - c0 == (120 - game.player.inv.count("log")) * pr and int(t.cash) >= 0
			# д) пояснения
			var expl_ok := true
			for bid in ["black_market", "mole_junction", "lift_mk1", "splitter", "teleporter"]:
				if str(DB.building(bid).get("explain", "")) == "":
					expl_ok = false
			# е) залежь на фундаменте видна сверху
			var w = game.world
			var dep_ok := false
			var dep_y := [0.0, 0.0]
			for cc in w.dep_marks.keys():
				var m: Node3D = w.dep_marks[cc]
				if not is_instance_valid(m) or f.grid.has(cc) or not z.inside_cell(cc):
					continue
				var fp: int = w.dep_fp(w.deposits[w.deposit[cc]])
				var y0: float = m.position.y
				var fd = put(game, "found_1", cc, 0) if fp == 1 else put(game, "found_2", cc, 0)
				if fd == null:
					continue
				dep_y = [y0, m.position.y]
				dep_ok = m.position.y >= float(fd.top) and m.position.y > y0 + 0.3
				f.remove(fd)
				dep_ok = dep_ok and absf(m.position.y - y0) < 0.01
				break
			# ж) лифт: лента на земле → лифт → лента на фундаменте → ящик на фундаменте
			var lc: Vector2i = c + Vector2i(0, 6)
			for k in range(2, 5):
				put(game, "found_1", lc + Vector2i(k, 0), 0)
			var lb0 = put(game, "belt", lc, 0)
			var lf = put(game, "lift_mk1", lc + Vector2i(1, 0), 0)
			put(game, "belt", lc + Vector2i(2, 0), 0)
			put(game, "belt", lc + Vector2i(3, 0), 0)
			var lch = put(game, "chest", lc + Vector2i(4, 0), 0)
			for step in int(10.0 / Factory.TICK):
				if step % 10 == 0 and lb0 != null:
					f.accept(lb0, "iron_ore", null)
				f._tick(Factory.TICK)
			var lift_ok: bool = lf != null and lch != null and lch.inv.count("iron_ore") >= 4 and lch.y > lb0.y + 0.5
			var lxf: Transform3D = f._xform(lf) if lf != null else Transform3D()
			var lift_vis: bool = lf != null and lxf.basis.get_scale().y > 0.6 and absf(lxf.origin.y - lb0.y) < 0.3
			var bt = put(game, "belt", lc + Vector2i(0, 2), 0)
			var over_ok: bool = bt != null and f.upgrade_target("lift_mk2", bt.cell) != null and f.upgrade_target("belt", lf.cell) == null
			# з) обучение и задание про рынок
			var tut_ok := false
			for stp in game.tutorial.steps():
				if str(stp.get("title", "")) == "Чёрный рынок" and str(stp.get("building", "")) == "black_market":
					tut_ok = true
			var q_ok: bool = int(DB.data.quests.get("q_trade", {}).get("n", 0)) == 5
			var ver_ok: bool = DB.game_version().begins_with("1.1.")
			print("TEST v18 econ=", econ_ok, " zone=", zone_ok, " tech=", tech_ok, "/", later_ok, " curve=", curve_ok, " ore=", v_ore, " plate=", v_pl, " motor=", v_mo,
				" bm=", bm_ok, " rate=", rate_ok, " rails=", rails_ok, " npc=", npc_ok, " explain=", expl_ok, " dep=", dep_ok, dep_y, " lift=", lift_ok, "/", lift_vis, "/", over_ok,
				" tut=", tut_ok, " q=", q_ok, " ver=", ver_ok, " ",
				"OK" if econ_ok and zone_ok and tech_ok and later_ok and curve_ok and bm_ok and rate_ok and rails_ok and npc_ok and expl_ok and dep_ok and lift_ok and lift_vis \
				and over_ok and tut_ok and q_ok and ver_ok else "FAIL")
		"anim110":
			# 1.1.10: полный скелет героя — стопы, кисти, грудь; перекат стопы; поворот на месте шагами;
			# позвоночник не перекручивается; у сетки на костях есть веса стоп и левой кисти; у робота стопы отрезаны от голеней
			var res := {}
			for id in ["hero_robot", "hero_valera"]:
				var h := Player.new()
				h.process_mode = Node.PROCESS_MODE_DISABLED
				h.look = id
				h.game = game
				game.add_child(h)
				h.build()
				h.position = game.player.position + Vector3(4, 0, 4)
				var bones_ok: bool = h.chest != null and h.foot_l != null and h.foot_r != null and h.hand_l != null \
					and h.head.get_parent() == h.chest and h.foot_l.get_parent() == h.shin_l and h.foot_l.position.y < -0.2
				var geo_ok := false
				if h.skel != null:
					geo_ok = h.skel.get_bone_count() == 16
					var mi: MeshInstance3D = h.skel.get_child(0)
					var arr := mi.mesh.surface_get_arrays(0)
					var bo: PackedInt32Array = arr[Mesh.ARRAY_BONES]
					var wo: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
					var cnt := {}
					for i in bo.size():
						if wo[i] > 0.3:
							var nm: String = h.skel.get_bone_name(bo[i])
							cnt[nm] = int(cnt.get(nm, 0)) + 1
					geo_ok = geo_ok and int(cnt.get("foot_l", 0)) > 20 and int(cnt.get("foot_r", 0)) > 20 and int(cnt.get("hand_l", 0)) > 10 and int(cnt.get("chest", 0)) > 50
				else:
					geo_ok = h.foot_l.get_child_count() > 0 and h.foot_r.get_child_count() > 0 and h.hand_l.get_child_count() > 0
				# ходьба: стопа перекатывается (носок то вверх, то вниз относительно земли)
				h.move_dir = Vector3(3.0, 0, 0)
				h.aim = h.position + Vector3(20, 0, 0)
				var pmin := 9.0
				var pmax := -9.0
				for i in 160:
					h.t += 0.016
					h._animate(0.016, false)
					var abs_p: float = h.leg_l.rotation.z + h.shin_l.rotation.z + h.foot_l.rotation.z
					pmin = minf(pmin, abs_p)
					pmax = maxf(pmax, abs_p)
				var roll_ok := pmin < -0.3 and pmax > 0.1
				# стоя: цель сзади-справа — герой поворачивается, ступни переступают, позвоночник ≤ 50°
				h.move_dir = Vector3.ZERO
				for i in 80:
					h.t += 0.016
					h._animate(0.016, false)
				h.aim = h.position + Vector3(0, 0, 20)
				var lifted := false
				var tw_max := 0.0
				for i in 150:
					h.t += 0.016
					h._animate(0.016, false)
					lifted = lifted or h.shin_l.rotation.z < -0.3 or h.shin_r.rotation.z < -0.3
					tw_max = maxf(tw_max, absf(h.torso.rotation.y + h.chest.rotation.y))
				var face: float = h.hips.rotation.y - h._pel
				var turned := absf(wrapf(face - atan2(-20.0, 0.0), -PI, PI)) < 0.6
				var feet_follow := absf(wrapf(h._fy_l - face, -PI, PI)) < 0.2 and absf(wrapf(h._fy_r - face, -PI, PI)) < 0.2
				var turn_ok := turned and lifted and feet_follow and tw_max < deg_to_rad(52.0)
				res[id] = [bones_ok, geo_ok, roll_ok, turned, lifted, feet_follow, snappedf(rad_to_deg(tw_max), 0.1)]
				h.queue_free()
			var ok := true
			for id in res:
				for k in 6:
					ok = ok and bool(res[id][k])
			print("TEST anim110 ", res, " ", "OK" if ok else "FAIL")
		"cardjit":
			# 1.1.10: карточка обучения не «скачет»: на каждом шаге высота за 3 с не меняется
			var T = game.tutorial
			var bad := []
			var n: int = T.steps().size()
			for st in n:
				if OS.get_environment("CARDSTEPS") != "" and not str(st) in OS.get_environment("CARDSTEPS").split(","):
					continue
				T.active = true
				T.done = false
				T.step = st
				T._enter()
				T.card.visible = true
				var lo := 1e9
				var hi := 0.0
				var t0 := Time.get_ticks_msec()
				var seq0 := []
				var cur_st: int = T.step
				while Time.get_ticks_msec() - t0 < 1600:
					await tree.process_frame
					if T.card.modulate.a < 0.5:
						continue   # карточка раскладывается (прозрачная) — игрок её не видит
					var e0 := "%d/%d/%d|%s" % [T.card.size.y, T.card.get_child(0).get_combined_minimum_size().y, T.card.size.x, T._goal_lbl.text]
					if seq0.is_empty() or not str(seq0[-1]).ends_with(e0):
						seq0.append("%d:%s" % [Time.get_ticks_msec() - t0, e0])
					if Time.get_ticks_msec() - t0 < 300:
						continue
					if T.step != cur_st:
						cur_st = T.step   # шаг выполнен и сменился — меряем уже новый
						lo = 1e9
						hi = 0.0
					lo = minf(lo, T.card.size.y)
					hi = maxf(hi, T.card.size.y)
				var need: float = T.card.get_child(0).get_combined_minimum_size().y
				if hi - lo > 1.0 or hi > need + 40.0:
					bad.append([st, lo, hi, need])
					if OS.get_environment("CARDLOG") != "":
						print("CARD0 ", st, " ", seq0)
						var seq := []
						var t2 := Time.get_ticks_msec()
						while Time.get_ticks_msec() - t2 < 2500:
							await tree.process_frame
							seq.append("%d/%d/%d" % [T.card.size.y, T.card.get_child(0).get_combined_minimum_size().y, T._goal_lbl.size.x])
						print("CARDLOG ", st, " ", T.cur().get("title"), " goal=", T._goal_lbl.text, " ", seq)
			T.skip()
			print("TEST cardjit bad=", bad, " ", "OK" if bad.is_empty() else "FAIL")
		"v111":
			# 1.1.11: печь — вход руды и вход топлива; брёвна руками идут в топку; старое сохранение с брёвнами в сырье оживает;
			# обход всех зданий: число входов, каждый вход что-то принимает, бок без порта — нет, выход один
			var f = game.factory
			game.flags["free_build"] = true
			var hq: Vector2i = f.hq.cell
			var c0: Vector2i = hq + Vector2i(14, -14)
			for dx in range(-4, 12):
				for dz in range(-4, 12):
					game.world.remove_node(World.wc(c0 + Vector2i(dx, dz)))
			var pc_ok: bool = Factory.port_counts("furnace") == [2, 1] and Factory.port_counts("coke_oven") == [2, 1] \
				and Factory.port_counts("blast_furnace") == [3, 1] and Factory.port_counts("smelter") == [2, 1]
			var fu = put(game, "furnace", c0, 0)
			var lay_ok: bool = fu != null and fu.pin.size() == 2 and fu.pfuel == -1
			# брёвна руками → в топку, не в сырьё
			game.player.inv.add("log", 10)
			game.player.position = fu.center() + Vector3(3, 0, 0)
			game.cmd("put_all", {"b": fu})
			var hand_ok: bool = fu.fuel.count("log") == 10 and fu.inv.count("log") == 0
			# лента руды — во вход сырья, лента угля — во вход топлива
			var ore_belt = put(game, "belt", fu.pin[0], (fu.pin_side[0] + 2) % 4)
			var fuel_belt = put(game, "belt", fu.pin[1], (fu.pin_side[1] + 2) % 4)
			var ore_in: bool = f.accept(fu, "iron_ore", ore_belt)
			var ore_in_fuel_port: bool = f.accept(fu, "iron_ore", fuel_belt)
			var logs_back: int = fu.fuel.count("log")
			fu.fuel.remove("log", logs_back)
			var coal_in: bool = f.accept(fu, "coal", fuel_belt)
			var coal_via_ore_port: bool = f.accept(fu, "coal", ore_belt) and fu.inv.count("coal") == 0 and fu.fuel.count("coal") == 2
			for k in 5:
				f.accept(fu, "iron_ore", ore_belt)
			for i in 600:
				f._tick(Factory.TICK)
			var smelt_ok: bool = fu.out.count("iron_ingot") >= 3
			# старое сохранение: брёвна лежат в сырье, топка пуста — печь перекладывает их в топку и берёт руду
			var fu2 = put(game, "furnace", c0 + Vector2i(5, 0), 0)
			fu2.inv.add("log", 1)
			for i in 30:
				f._tick(Factory.TICK)
			var b2 = put(game, "belt", fu2.pin[0], (fu2.pin_side[0] + 2) % 4)
			var old_ok: bool = fu2.fuel.count("log") == 1 and f.accept(fu2, "iron_ore", b2)
			# выбран рецепт «древесный уголь» — брёвна руками идут в сырьё
			var fu3 = put(game, "furnace", c0 + Vector2i(0, 5), 0)
			f.set_recipe(fu3, "charcoal")
			f.accept(fu3, "log", null)
			var rec_ok: bool = fu3.inv.count("log") == 1
			# обход всех зданий
			var bad := []
			var checked := 0
			var fuels := []
			for it in DB.data.items:
				if float(DB.item(it).get("fuel", 0)) > 0.0:
					fuels.append(it)
			var base: Vector2i = hq + Vector2i(-60, 40)
			var slot := 0
			for t in DB.data.buildings:
				var d := DB.building(t)
				var beh := str(d.get("behavior", ""))
				if beh in ["belt", "splitter", "merger", "junction", "pipe", "foundation", "hq"] or not bool(d.get("params", {}).get("buildable", true)):
					continue
				var pc: Array = Factory.port_counts(t)
				if pc[0] < 0:
					continue
				var sz := int(d.get("size", 1))
				if t == "cloud_breaker":   # принимает только то, что нужно для расширения зоны — своя проверка
					continue
				var cell := base + Vector2i((slot % 8) * 9, (slot / 8) * 9)
				slot += 1
				var wet := true
				while wet and slot < 400:
					wet = false
					for dx in range(-2, sz + 2):
						for dz in range(-2, sz + 2):
							wet = wet or game.world.water_at(World.wc(cell + Vector2i(dx, dz)))
					if wet:
						cell = base + Vector2i((slot % 8) * 9, (slot / 8) * 9)
						slot += 1
				var lv: float = game.world.h_cell(cell)
				for k in 2:
					game.world.paint_height(cell + Vector2i(sz / 2, sz / 2), float(sz + 4), "flatten", 1.0, lv)
				for dx in range(-2, sz + 2):
					for dz in range(-2, sz + 2):
						var cc := World.wc(cell + Vector2i(dx, dz))
						game.world.remove_node(cc)
						var o = f.building_at(cc)
						if o != null:
							f.remove(o)
				if beh == "miner" or str(d.get("params", {}).get("on_deposit", "")) != "":
					var di := -1
					var want := str(d.get("params", {}).get("on_deposit", ""))
					for k in game.world.deposits.size():
						var it2 := str(game.world.deposits[k].get("item", ""))
						if (want != "" and it2 == want) or (want == "" and it2 == "iron_ore"):
							di = k
					if di >= 0:
						for x in sz:
							for z in sz:
								game.world.set_deposit(cell + Vector2i(x, z), di)
				var b = put(game, t, cell, 0)
				if b == null:
					if OS.get_environment("V111LOG") != "":
						print("SKIP ", t, " ", f.can_place(t, cell))
					continue   # нужна особая местность (вода, залежь жидкости) — проверяется своими тестами
				checked += 1
				var why := ""
				if b.pin.size() != pc[0] or b.pout.size() != mini(pc[1], 1):
					why = "count %d/%d out %d" % [b.pin.size(), pc[0], b.pout.size()]
				# кандидаты: сырьё рецептов, топливо, что угодно
				var cand := []
				var pr: Dictionary = d.get("params", {})
				for rid in DB.recipes_for(str(pr.get("station", t))):
					for it3 in DB.data.recipes[rid].get("in", {}):
						if not DB.is_fluid(it3) and not it3 in cand:
							cand.append(it3)
				for bl0 in d.get("blocks", []):
					for it8 in bl0.get("in", {}):
						if not it8 in cand:
							cand.append(it8)
				for it4 in pr.get("fuels", []):
					if not it4 in cand:
						cand.append(it4)
				for it5 in ["coal", "log", "iron_ore", "iron_ingot", "iron_plate", "stone", "gear", "circuit"] + fuels:
					if not it5 in cand:
						cand.append(it5)
				for i in b.pin.size():
					var bl = put(game, "belt", b.pin[i], (b.pin_side[i] + 2) % 4)
					if bl == null:
						why += " no_belt_at_in%d(%s)" % [i, f.can_place("belt", b.pin[i])]
						continue
					var took := ""
					for it6 in cand:
						if f.accept(b, it6, bl):
							took = it6
							break
					if took == "" and t != "hq_link":   # канал штаба без энергии не принимает (проверяется в v1115)
						why += " in%d_takes_nothing" % i
					f.remove(bl)
				# 1.1.12: все входы равноправны — каждый предмет (на новом здании) берут все входы одинаково
				var bt: String = b.type
				var bc: Vector2i = b.cell
				var pins: Array = b.pin.duplicate()
				var sides: Array = b.pin_side.duplicate()
				if pins.size() > 1:
					for it9 in cand.slice(0, 8):
						var res9 := []
						for i in pins.size():
							f.remove(b)
							b = put(game, bt, bc, 0)
							var bl9 = put(game, "belt", pins[i], (sides[i] + 2) % 4)
							res9.append(b != null and bl9 != null and f.accept(b, it9, bl9))
							if bl9 != null:
								f.remove(bl9)
						if res9.has(true) and res9.has(false):
							why += " ports_differ_%s%s" % [it9, res9]
				# бок без порта — не принимает
				for sd in 4:
					for sc in Factory.side_cells(b.cell, b.size, sd):
						var wc2: Vector2i = World.wc(sc)
						if wc2 in b.pin or wc2 in b.pout:
							continue
						var sb = put(game, "belt", wc2, (sd + 2) % 4)
						if sb != null:
							for it7 in cand.slice(0, 6):
								if f.accept(b, it7, sb):
									why += " side_took_" + it7
									break
							f.remove(sb)
						break
				if pc[1] > 0:
					var ob = put(game, "belt", b.pout[0], b.pout_side[0])
					if ob == null or b.next != ob:
						why += " out_not_linked"
					if ob != null:
						f.remove(ob)
				if why != "":
					bad.append(t + ":" + why)
			print("TEST v111 counts=", pc_ok, " layout=", lay_ok, " hand_logs_to_fuel=", hand_ok, " ore_in=", ore_in, " ore_in_second=", ore_in_fuel_port,
				" coal_in=", coal_in, " coal_via_ore_port=", coal_via_ore_port, " smelt=", smelt_ok, " ", fu.out.totals(), " old_save=", old_ok, " recipe_logs=", rec_ok,
				" buildings=", checked, " bad=", bad, " ",
				"OK" if pc_ok and lay_ok and hand_ok and ore_in and ore_in_fuel_port and coal_in and coal_via_ore_port and smelt_ok and old_ok and rec_ok and checked > 60 and bad.is_empty() else "FAIL")
		"admin111":
			# 1.1.11: админ-панель в своей игре: admin из закрытой консоли, вкладки, выдача, уровень, сброс, стройка даром, мир
			Console.test_locked = true
			var dev0 = Prefs.get_value("dev_console", false)
			Prefs.set_value("dev_console", false)
			var A = game.admin
			game.console.toggle()
			game.console._submit("admin")
			var open_ok: bool = A.ok and game.hud.is_open("admin")
			var tabs_ok := true
			for tb in AdminPanel.TABS:
				A.tab = tb[0]
				A.refresh()
				tabs_ok = tabs_ok and A._win.body.get_child_count() > 1
			A.item_q = "шест"
			A.tab = "items"
			A.refresh()
			A.tab = "players"
			var g0: int = game.player.inv.count("gear")
			A.act("give", {"to": 1, "item": "gear", "n": 250})
			var give_ok: bool = game.player.inv.count("gear") > g0   # что не влезло — в склад или на землю
			var hq0: int = game.factory.hq.inv.count("motor")
			A.act("give", {"to": 1, "item": "motor", "n": 5, "hq": true})
			var hq_ok: bool = game.factory.hq.inv.count("motor") == hq0 + 5
			var ap0: int = game.attr_points
			A.act("player", {"to": 1, "set": {"level": 12}})
			var lvl_ok: bool = game.level == 12 and game.attr_points == ap0 + 11 * int(DB.data.levels.get("attr_points_per_level", 2))
			A.act("player", {"to": 1, "set": {"attr_points": 7, "skill_points": 3}})
			game.upgrade_attr(DB.data.attributes.keys()[0])
			var ap1: int = game.attr_points
			A.act("player", {"to": 1, "set": {"reset": true}})
			var reset_ok: bool = game.attr_points == ap1 + 1 and game.attrs.values().all(func(v): return int(v) == 0)
			A.act("player", {"to": 1, "set": {"free_build": true, "god": true}})
			var fb_ok: bool = game.flags.get("free_build", false) and game.player.god
			game.player.inv.slots.fill(null)
			var c: Vector2i = game.factory.hq.cell + Vector2i(8, 8)
			for dx in range(-1, 4):
				for dz in range(-1, 4):
					game.world.remove_node(World.wc(c + Vector2i(dx, dz)))
			var placed = game.cmd("place", {"type": "assembler", "cell": c, "dir": 0})
			var free_ok: bool = placed != null and game.factory.building_at(c) != null
			A.act("time", {"t": 0.9})
			var time_ok: bool = absf(game.day_t - 0.9) < 0.01
			A.act("waves", {"on": false})
			var waves_ok: bool = game.flags.get("no_waves", false)
			A.act("tech_all")
			var tech_ok: bool = not Tech.building_locked("assembler_mk2")
			A.act("player", {"to": 1, "set": {"free_build": false, "god": false}})
			var off_ok: bool = not game.flags.get("free_build", false) and not game.player.god
			Console.test_locked = false
			Prefs.set_value("dev_console", dev0)
			print("TEST admin111 open=", open_ok, " tabs=", tabs_ok, " give=", give_ok, " hq=", hq_ok, " level=", lvl_ok, " reset=", reset_ok, " free=", fb_ok, " place_free=", free_ok,
				" time=", time_ok, " waves=", waves_ok, " tech=", tech_ok, " off=", off_ok, " ",
				"OK" if open_ok and tabs_ok and give_ok and hq_ok and lvl_ok and reset_ok and fb_ok and free_ok and time_ok and waves_ok and tech_ok and off_ok else "FAIL")
		"netbld111":
			# 1.1.11: рассылка зданий гостям — только изменившиеся; размер и время на большой базе
			var f = game.factory
			game.flags["free_build"] = true
			var hq: Vector2i = f.hq.cell
			var n0 := 0
			for x in range(-30, 30):
				for z in range(12, 32):
					var c := hq + Vector2i(x, z)
					var b = put(game, "chest", c, 0)
					if b != null:
						b.inv.add("iron_ore", 1 + (x + 40) % 7)
						n0 += 1
			var net = Net._self()
			var g0 = net.game
			net.game = game
			var t0 := Time.get_ticks_usec()
			var full: PackedByteArray = net.bld_payload(true)
			var t_full := (Time.get_ticks_usec() - t0) / 1000.0
			var full_n: int = net.bld_last
			var full_kb := full.compress(FileAccess.COMPRESSION_ZSTD).size() / 1024.0
			t0 = Time.get_ticks_usec()
			var none: PackedByteArray = net.bld_payload(false)
			var t_delta := (Time.get_ticks_usec() - t0) / 1000.0
			var none_ok: bool = none.is_empty() and net.bld_last == 0 and full_n >= n0
			var k := 0
			for b in f.all:
				if b.type == "chest" and k < 3:
					b.inv.add("coal", 1)
					k += 1
			var three: PackedByteArray = net.bld_payload(false)
			var three_ok: bool = net.bld_last == 3 and three.size() < full.size() / 20 and t_delta < t_full
			net.game = g0
			print("TEST netbld111 buildings=", n0, " full_sent=", full_n, " full_kb=", snappedf(full_kb, 0.1), " full_ms=", snappedf(t_full, 0.1), " delta_ms=", snappedf(t_delta, 0.1),
				" unchanged_sends_nothing=", none_ok, " three_changed=", three_ok, " (", three.size(), " bytes) ", "OK" if n0 > 800 and none_ok and three_ok else "FAIL")
		"repair112":
			# 1.1.12: ремонт за полцены (по доле урона) с удержанием ПКМ 15 с; восстановление из развалин; новое здание убирает развалины
			var f = game.factory
			var hq: Vector2i = f.hq.cell
			var c: Vector2i = hq + Vector2i(9, 6)
			for dx in range(-2, 8):
				for dz in range(-2, 5):
					game.world.remove_node(World.wc(c + Vector2i(dx, dz)))
			game.flags.erase("free_build")
			var fu = put(game, "furnace", c, 0)
			game.player.position = fu.center() + Vector3(3, 0, 3)
			game.hud.close_all()
			game.player.inv.remove("stone", game.player.inv.count("stone"))
			f.hq.inv.remove("stone", f.hq.inv.count("stone"))
			f.damage(fu, fu.maxhp * 0.5)
			var cost: Dictionary = game.repair_cost(game.repair_target(c))
			var cost_ok: bool = cost == {"stone": 5}
			var hold := func(sec: float) -> void:
				game.rmb = true
				game.build_type = ""
				game.hover_cell = c
				var tt := 0.0
				while tt < sec:
					game._update_repair(0.25)
					tt += 0.25
				game.rmb = false
				game._update_repair(0.25)
			# без камня — не чинится
			hold.call(16.0)
			var no_res_ok: bool = fu.hp < fu.maxhp
			game.player.inv.add("stone", 12)
			hold.call(14.0)
			var not_yet: bool = fu.hp < fu.maxhp and game.player.inv.count("stone") == 12
			var tip0: String = game.info_text()
			hold.call(15.25)
			var fixed: bool = fu.hp >= fu.maxhp and game.player.inv.count("stone") == 7
			var tip: String = tip0
			# разрушить: развалины, восстановить за 10 камня
			f.damage(fu, fu.maxhp * 2.0)
			var ruin = game.builders.ruin_at(c)
			var ruin_ok: bool = ruin != null and f.building_at(c) == null
			game.hover_cell = c
			var rtip: String = game.info_text()
			game.player.inv.add("stone", 3)
			hold.call(15.25)
			var nb = f.building_at(c)
			var rebuilt: bool = nb != null and nb.type == "furnace" and game.builders.ruin_at(c) == null and game.player.inv.count("stone") == 0
			# снова разрушить и поставить сверху ящик — развалины пропадают
			if nb != null:
				f.damage(nb, nb.maxhp * 2.0)
			var had_ruin: bool = game.builders.ruin_at(c) != null
			# 1.1.13: куски разрушенного здания летят и тают, а не висят в воздухе (рендерер терял их по ключу-словарю)
			var ph = game.physics
			var n_deb: int = ph.pieces.size()
			ph.update(0.3)
			var moved := 0
			for pc in ph.pieces:
				var i: int = ph.r.index_of.get(pc.id, -1)
				if i >= 0 and (ph.r.base_xf[i] as Transform3D).origin.distance_to(pc.pos) < 0.01:
					moved += 1
			var deb_ok: bool = n_deb > 0 and moved == n_deb and ph.r.owners.size() == n_deb
			game.flags["free_build"] = true
			game.cmd("place", {"type": "chest", "cell": c, "dir": 0})
			var cleared: bool = had_ruin and game.builders.ruin_at(c) == null and game.builders.ruin_at(c + Vector2i(1, 1)) == null
			var deb_left := 0
			for pc in ph.pieces:
				if World.wc(World.world_to_cell(pc.pos)) == World.wc(c):
					deb_left += 1
			var deb_sync: bool = ph.r.owners.size() == ph.pieces.size()
			f.damage(f.building_at(c), 99999.0)
			for k in 60:
				ph.update(0.25)
			var deb_gone: bool = ph.pieces.is_empty() and ph.r.owners.is_empty()
			deb_ok = deb_ok and deb_left == 0 and deb_sync and deb_gone
			print("TEST repair112 cost=", cost, " no_res=", no_res_ok, " not_before_15s=", not_yet, " fixed=", fixed, " tip=", tip.contains("ПКМ 15"), " ruin=", ruin_ok,
				" ruin_tip=", rtip.contains("Развалины"), " rebuilt=", rebuilt, " new_clears_ruin=", cleared, " debris=", n_deb, "/", moved, " deb_left=", deb_left, " deb_gone=", deb_gone, " ",
				"OK" if deb_ok and cost_ok and no_res_ok and not_yet and fixed and tip.contains("ПКМ 15") and ruin_ok and rtip.contains("Развалины") and rebuilt and cleared else "FAIL")
		"autorep114":
			# 1.1.14: авторемонт от навыка «Инженерия» — бесплатный, работает и на сервере (по навыку гостя), развалины не трогает
			var f = game.factory
			var hq: Vector2i = f.hq.cell
			var c: Vector2i = hq + Vector2i(9, 6)
			for dx in range(-2, 8):
				for dz in range(-2, 5):
					game.world.remove_node(World.wc(c + Vector2i(dx, dz)))
			game.flags["free_build"] = true
			var fu = put(game, "furnace", c, 0)
			var ch = put(game, "chest", c + Vector2i(4, 0), 0)
			game.flags.erase("free_build")
			game.skills.clear()
			game.attrs.clear()
			for inv in [game.player.inv, f.hq.inv]:
				for s in inv.slots.duplicate():
					if s != null:
						inv.remove(str(s.id), inv.count(str(s.id)))
			f.damage(fu, fu.maxhp * 0.5)
			var hp0: float = fu.hp
			f._auto_repair(1.0)
			f._auto_repair(1.0)
			var no_skill_ok: bool = absf(fu.hp - hp0) < 0.01
			game.skills["engineering"] = 2
			for k in 60:
				f._auto_repair(1.0)
			# 2-й уровень: 3% прочности в минуту, бесплатно
			var heal_ok: bool = absf(fu.hp - (hp0 + fu.maxhp * 0.03)) < fu.maxhp * 0.002 and game.player.inv.slots.all(func(s): return s == null)
			var pcts := [1, 2, 3, 4, 5].map(func(l): return f.auto_repair_pct(l))
			heal_ok = heal_ok and pcts == [2.0, 3.0, 4.0, 5.0, 6.0]
			# развалины сам не отстраивает
			f.damage(ch, ch.maxhp * 2.0)
			var had_ruin: bool = game.builders.ruin_at(c + Vector2i(4, 0)) != null
			for k in 5:
				f._auto_repair(1.0)
			var ruin_stays: bool = had_ruin and f.building_at(c + Vector2i(4, 0)) == null and game.builders.ruin_at(c + Vector2i(4, 0)) != null
			# сервер: навык гостя считается, невидимый герой сервера — нет
			game.skills.clear()
			var n = Net._self()
			var m0: String = n.mode
			var p0: Dictionary = n.peers
			var s0: Dictionary = n.saved
			n.mode = "host"
			n.peers = {7: {"nick": "Гость", "color": Color.WHITE}}
			n.saved = {"Гость": {"me": {"skills": {"engineering": 3}}}}
			var tb_guest: float = game.team_bonus("repair")
			n.saved = {}
			game.skills["engineering"] = 1
			var tb_host: float = game.team_bonus("repair")
			var srv0 = n.server
			n.server = Node.new()
			var tb_ded: float = game.team_bonus("repair")
			n.server.free()
			n.server = srv0
			n.mode = m0
			n.peers = p0
			n.saved = s0
			var team_ok: bool = tb_guest == 3.0 and tb_host == 1.0 and tb_ded == 0.0
			print("TEST autorep114 no_skill=", no_skill_ok, " heal=", snappedf(hp0, 0.1), "->", snappedf(fu.hp, 0.1), " free=", heal_ok, " pct=", pcts, " ruin_stays=", ruin_stays,
				" team=", [tb_guest, tb_host, tb_ded], " autosave_min=", DB.setting("coop", {}).get("autosave_min"), " ",
				"OK" if no_skill_ok and heal_ok and ruin_stays and team_ok and float(DB.setting("coop", {}).get("autosave_min", 0)) == 1.0 else "FAIL")
		"duelB_off115":
			# выключенная (cfg.off) турель / канал штаба: не едят энергию, но работают?
			var f = game.factory
			var w = game.world
			var hq: Vector2i = f.hq.cell
			var c: Vector2i = hq + Vector2i(6, 0)
			for dx in range(-3, 9):
				for dz in range(-4, 6):
					w.remove_node(World.wc(c + Vector2i(dx, dz)))
			game.flags["free_build"] = true
			var tu = put(game, "turret", c, 0)
			var lz = put(game, "laser_turret", c + Vector2i(0, 2), 0)
			var ln = put(game, "hq_link", c + Vector2i(3, 0), 0)
			game.flags.erase("free_build")
			f.auto_wire_all()
			f._rebuild_power()
			f._power(0.05)
			print("HUNT nets tu.net=", tu.net, " lz.net=", lz.net, " ln.net=", ln.net, " sat=", f._sat(tu), f._sat(lz), f._sat(ln))
			for b in [tu, lz, ln]:
				game.cmd("bcfg", {"b": b, "cfg": {"off": true}})
			var ammo := str(tu.p("ammo", ""))
			tu.inv.add(ammo, 20)
			var e = game.enemies.spawn("crawler" if DB.data.enemies.has("crawler") else DB.data.enemies.keys()[0], tu.center() + Vector3(5, 0, 0))
			var hp0: float = e.hp
			f._power(0.05)
			var dem: float = f.nets[tu.net].demand if tu.net >= 0 else -1.0
			for k in 40:
				f._turrets(0.05)
			print("HUNT tgt=", tu.target != null, " lz tgt=", lz.target != null, " active=", tu.active, lz.active)
			var used: int = 20 - tu.inv.count(ammo)
			var s0: int = f.hq.inv.count("stone")
			var acc := 0
			for k in 10:
				if f.accept(ln, "stone", null):
					acc += 1
			print("HUNT off: demand_on_net=", dem, " ammo_used=", used, " enemy_hp ", hp0, "->", e.hp, " alive=", game.enemies.is_alive(e), " link_accepted=", acc, " hq_stone+", f.hq.inv.count("stone") - s0)
			print("TEST duelB_off115 done")
		"duelB_recipes115":
			var f = game.factory
			var w = game.world
			game.flags["free_build"] = true
			f.nets.append({"supply": 1000.0, "demand": 0.0, "sat": 1.0, "stored": 0.0, "cap": 0.0, "tripped": false, "over_t": 0.0, "gen_max": 0.0})
			var fake_net: int = f.nets.size() - 1
			var bad := []
			var nok := 0
			var base: Vector2i = f.hq.cell + Vector2i(-40, 30)
			for bt in DB.data.buildings:
				var bd: Dictionary = DB.data.buildings[bt]
				if str(bd.get("behavior", "")) != "crafter":
					continue
				var st := str(bd.get("params", {}).get("station", bt))
				var b = put_near(game, bt, base, 0)
				if b == null:
					bad.append("%s:noplace" % bt)
					continue
				for rid in DB.data.recipes:
					var r: Dictionary = DB.data.recipes[rid]
					if not st in r.get("stations", []):
						continue
					var flu := false
					for k in r.get("in", {}).keys() + r.get("out", {}).keys():
						if DB.is_fluid(str(k)):
							flu = true
					if flu:
						continue
					b.inv.slots.fill(null)
					b.out.slots.fill(null)
					b.crafting = ""
					b.prog = 0.0
					b.recipe = rid
					b.idle_key = -1
					var fit := true
					for k in r.in:
						if b.inv.add(str(k), int(r.in[k])) != 0:
							fit = false
					if b.fuel != null:
						b.fuel.slots.fill(null)
						b.fuel.add("coal", 20)
						b.fuel_t = 0.0
					var made := false
					for i in 4000:
						b.net = fake_net
						f._crafter(b, 0.25)
						var all_out := true
						for k in r.out:
							if b.out.count(str(k)) < int(r.out[k]):
								all_out = false
						if all_out:
							made = true
							break
					# с ленты: сколько возьмёт вход
					var belt_ok := true
					b.inv.slots.fill(null)
					b.crafting = ""
					for k in r.in:
						var nacc := 0
						while nacc < int(r.in[k]) + 1 and b.inv.can_add(str(k), 1) and f._is_input(b, str(k)) and b.inv.count(str(k)) < f.in_cap(b, str(k)):
							b.inv.add(str(k), 1)
							nacc += 1
						if nacc < int(r.in[k]):
							belt_ok = false
					if made and fit and belt_ok:
						nok += 1
					else:
						bad.append("%s/%s fit=%s made=%s belt=%s slots=%d" % [bt, rid, fit, made, belt_ok, b.inv.slots.size()])
				f.remove(b)
			print("HUNT recipes ok=", nok, " bad=", bad.size())
			for x in bad:
				print("HUNT bad ", x)
			print("TEST duelB_recipes115 done")
		"duelB_meteor115":
			var f = game.factory
			var w = game.world
			var zc = JSON.parse_string(FileAccess.get_file_as_string("res://core/settings.json"))["zone"]
			DB.data.settings["zone"] = zc
			game.zone.setup(f.hq.center())
			game.player.position = f.hq.center() + Vector3(0, 0, 8)
			var outside := 0
			var total := 0
			var reach_bad := 0
			for k in 200:
				var before := {}
				for nc in w.nodes:
					if w.nodes[nc].res == "meteorite":
						before[nc] = true
				game.events._drop_meteor(game.player.position)
				for nc in w.nodes:
					if w.nodes[nc].res == "meteorite" and not before.has(nc):
						total += 1
						if not game.zone.inside_cell(nc):
							outside += 1
						w.remove_node(nc)
			print("HUNT meteor zone_on=", game.zone.on(), " half_m=", game.zone.half(), " landed=", total, " outside_zone=", outside)
			print("TEST duelB_meteor115 done")
		"duelB_misc115":
			var f = game.factory
			var w = game.world
			var cl = game.climate
			var hq: Vector2i = f.hq.cell
			# 1) холодная пустая печь греет героя
			var c: Vector2i = hq + Vector2i(-14, 10)
			for dx in range(-6, 10):
				for dz in range(-6, 10):
					w.remove_node(World.wc(c + Vector2i(dx, dz)))
			game.flags["free_build"] = true
			var fu = put(game, "furnace", c, 0)
			game.flags.erase("free_build")
			var p: Vector3 = fu.center() + Vector3(2.5, 0, 0)
			var h_cold: float = cl.heat_at(p)
			print("HUNT furnace empty fuel=", fu.fuel.first_item(), " fuel_t=", fu.fuel_t, " active=", fu.active, " heat_at_hero=", h_cold)
			f.remove(fu)
			# 2) обогреватель выключен — греет?
			game.flags["free_build"] = true
			var ht = put(game, "heater", c, 0)
			game.flags.erase("free_build")
			f.nets.append({"supply": 1000.0, "demand": 0.0, "sat": 1.0, "stored": 0.0, "cap": 0.0, "tripped": false, "over_t": 0.0, "gen_max": 0.0})
			ht.net = f.nets.size() - 1
			var h_on: float = cl.heat_at(ht.center() + Vector3(2, 0, 0))
			game.cmd("bcfg", {"b": ht, "cfg": {"off": true}})
			var h_off: float = cl.heat_at(ht.center() + Vector3(2, 0, 0))
			print("HUNT heater net=", ht.net, " heat_on=", h_on, " heat_off=", h_off, " demand_off=", f.nets[ht.net].demand if ht.net >= 0 else -1.0)
			f.remove(ht)
			# 3) доменная печь на 5% мощности: топливо горит как на 100%
			game.flags["free_build"] = true
			var bf = put(game, "blast_furnace", c, 0)
			game.flags.erase("free_build")
			if bf != null:
				f.nets.append({"supply": 1000.0, "demand": 0.0, "sat": 1.0, "stored": 0.0, "cap": 0.0, "tripped": false, "over_t": 0.0, "gen_max": 0.0})
				var fk: int = f.nets.size() - 1
				var rid := ""
				for r in DB.recipes_for("blast_furnace"):
					var ok := true
					for k in DB.data.recipes[r].in:
						if DB.is_fluid(str(k)):
							ok = false
					if ok:
						rid = r
						break
				var res := []
				for clk in [100.0, 5.0]:
					bf.cfg = {"clock": clk}
					bf.inv.slots.fill(null)
					bf.out.slots.fill(null)
					bf.crafting = ""
					bf.recipe = rid
					for k in DB.data.recipes[rid].in:
						bf.inv.add(str(k), int(DB.data.recipes[rid].in[k]) * 3)
					bf.fuel.slots.fill(null)
					bf.fuel.add("coal", 50)
					bf.fuel_t = 0.0
					for i in 400:
						bf.net = fk
						f._crafter(bf, 0.1)
					var outn := 0
					for k in DB.data.recipes[rid].out:
						outn += bf.out.count(str(k))
					res.append([clk, "coal_used", 50 - bf.fuel.count("coal"), "out", outn, "prog", snappedf(bf.prog, 0.01)])
				print("HUNT blast rid=", rid, " ", res)
			# 4) дрон сбит по дороге к упавшему предмету — предмет навсегда «занят»
			var dr_ok := "skip"
			if game.get("drones") != null and game.drones != null:
				var D = game.drones
				D.f = f
				var dd = game.drops.spawn("iron_ore", 3, f.hq.center() + Vector3(10, 0.5, 10))
				var fake := {"st": f.hq, "i": 0, "pos": f.hq.center(), "state": "dock", "bat": 400.0, "hp": 60.0, "item": "", "n": 0, "src": null, "dst": null, "route": -1, "t": 0.0, "dead_t": 0.0, "retire": false, "node": null, "box": null, "yaw": 0.0, "hit_t": 0.0}
				var drp = game.drops.list.back() if not game.drops.list.is_empty() else null
				if drp != null:
					drp.landed = true
					D._try_pickup(f.hq, fake, f.hq.center(), 1.15)
					var claimed0: bool = D._claimed.has(drp)
					D._kill(fake)
					dr_ok = "claimed_before=%s state=%s claimed_after_kill=%s" % [claimed0, fake.state, D._claimed.has(drp)]
			print("HUNT drone ", dr_ok)
			print("TEST duelB_misc115 done")
		"duelB_contract115":
			var tc = game.tech
			tc.done.erase("t_defense")
			tc.c_done.erase("c_hold")
			tc.c_start.erase("c_hold")
			tc.refresh_locks()
			var st0: String = tc.c_state("c_hold")
			game.enemies.waves_survived = 2
			# игрок просто открыл окно «Задания станции», пока задание закрыто
			var vb := VBoxContainer.new()
			game.hud._contracts_ui(vb)
			vb.free()
			var start_set: bool = tc.c_start.has("c_hold")
			# проходят 3 волны, потом изучается «Оборона»
			game.enemies.waves_survived = 5
			tc.unlock("t_defense")
			tc._acc = 1.0
			tc.update(0.1)
			print("HUNT contract c_hold state_before=", st0, " c_start_set_while_locked=", start_set, " start=", tc.c_start.get("c_hold"), " done_right_after_unlock=", tc.c_done.has("c_hold"))
			print("TEST duelB_contract115 done")
		"duelB_tip115":
			var f = game.factory
			var w = game.world
			var dc: Vector2i = DemoSetup.nearest_deposit(game, "iron_ore", f.hq.cell + Vector2i(20, 20))
			game.hud.close_all()
			game.hover_cell = dc
			var txt: String = game.info_text()
			var line := ""
			for l in txt.split("\n"):
				if l.contains("Mk3"):
					line = l
			game.flags["free_build"] = true
			var rates := []
			for t in ["miner", "miner_mk2", "miner_mk3"]:
				var m = put(game, t, dc, 0)
				if m != null:
					rates.append([t, f.miner_rate(m)])
					f.remove(m)
				else:
					rates.append([t, "noplace " + f.can_place(t, dc)])
			game.flags.erase("free_build")
			print("HUNT tip line=", line)
			print("HUNT real rates=", rates)
			# ремонт объединённого здания: цена как за одно
			game.flags["free_build"] = true
			var c2: Vector2i = f.hq.cell + Vector2i(-20, -14)
			for dx in range(-3, 8):
				for dz in range(-3, 6):
					w.remove_node(World.wc(c2 + Vector2i(dx, dz)))
			var a1 = put(game, "furnace", c2, 0)
			game.flags.erase("free_build")
			if a1 != null:
				f.fz.set_level(a1, 3)
				a1.hp = 1.0
				var t1: Dictionary = game.repair_target(a1.cell)
				var rc: Dictionary = game.repair_cost(t1)
				print("HUNT repair lvl=", a1.lvl, " maxhp=", a1.maxhp, " repair_cost=", rc, " one_building_cost=", game._scaled_cost("furnace"))
			print("TEST duelB_tip115 done")
		"duelB_lab115":
			var f = game.factory
			var w = game.world
			var c: Vector2i = f.hq.cell + Vector2i(5, 4)
			for dx in range(-3, 6):
				for dz in range(-3, 6):
					w.remove_node(World.wc(c + Vector2i(dx, dz)))
			game.flags["free_build"] = true
			var lab = put_near(game, "research_lab", c, 0)
			game.flags.erase("free_build")
			f.auto_wire_all()
			f._rebuild_power()
			lab.inv.add("goo", 10)
			lab.inv.add("chitin", 5)
			var r0: int = game.tech.research
			var dem := []
			for i in 100:
				f._tick(0.25)
				if i % 20 == 0:
					dem.append([snappedf(f.nets[lab.net].demand, 0.1) if lab.net >= 0 else -1, lab.want])
			print("HUNT lab net=", lab.net, " sat=", f._sat(lab), " research +", game.tech.research - r0, " demand/want samples=", dem, " lab power=", lab.p("power", 0))
			lab.inv.slots.fill(null)
			lab.inv.add("monster_core", 2)
			var dem2 := []
			for i in 40:
				f._tick(0.25)
				if i % 10 == 0:
					dem2.append([snappedf(f.nets[lab.net].demand, 0.1) if lab.net >= 0 else -1, lab.want])
			print("HUNT lab cores demand/want=", dem2)
			print("TEST duelB_lab115 done")
		"duelB_boiler115":
			var f = game.factory
			var w = game.world
			var c: Vector2i = f.hq.cell + Vector2i(-12, -10)
			for dx in range(-3, 8):
				for dz in range(-3, 6):
					w.remove_node(World.wc(c + Vector2i(dx, dz)))
			game.flags["free_build"] = true
			var wb = put_near(game, "wood_boiler", c, 0)
			var gn = put_near(game, "generator", c + Vector2i(4, 0), 0)
			game.flags.erase("free_build")
			var res := {}
			for it in ["fuel_rod", "fusion_cell", "cut_resonite", "log"]:
				res[it] = [f.accept(wb, it, null), f.accept(gn, it, null)]
			# «Положить» из рюкзака: герой несёт брёвна и ТВЭЛы
			wb.fuel.slots.fill(null)
			var inv = game.player.inv
			inv.slots.fill(null)
			inv.add("fusion_cell", 2)
			inv.add("log", 3)
			var moved: int = f.put_from(wb, inv)
			print("HUNT boiler accept [wood_boiler, generator]=", res, " put_all moved=", moved, " fusion_cells_in_boiler=", wb.fuel.count("fusion_cell"), " left_in_bag=", inv.count("fusion_cell"))
			print("TEST duelB_boiler115 done")
		"duelB_chain115":
			var f = game.factory
			var w = game.world
			game.flags["free_build"] = true
			var res := []
			DB.data.buildings["hq"]["params"]["power"] = 900
			DB.data.buildings["hq"]["params"]["transfer"] = 900
			for d in 4:
				var D: Vector2i = f.DIRS[d]
				var base: Vector2i = f.hq.cell + Vector2i(-8 + d * 7, 9)
				for dx in range(-7, 8):
					for dz in range(-7, 8):
						w.remove_node(World.wc(base + Vector2i(dx, dz)))
				var ln = put(game, "hq_link", base, d)
				if ln == null:
					res.append([d, "link null", f.can_place("hq_link", base)])
					continue
				var lay: Dictionary = f.port_layout("hq_link", base, d)
				var pout: Vector2i = lay.out[0]
				var b1 = put(game, "belt", pout, d)
				var b2 = put(game, "belt", pout + D, d)
				var tl: Dictionary = f.port_layout("turret", pout + D * 2, d)
				var tu = put(game, "turret", pout + D * 2, d)
				ln.cfg = {"mode": "take", "items": ["ammo"]}
				f.hq.inv.add("ammo", 40)
				res.append([d, "turret_in=", tl["in"], "belt_at=", pout + D, "tu_null", tu == null])
				f.auto_wire_all()
				f._rebuild_power()
				for i in 60 * 20:
					f._tick(f.TICK)
				res.append([d, "mag", tu.inv.count("ammo") if tu else -1, "b2.next", b2.next.type if b2 and b2.next else "-", "link_out", ln.out.count("ammo"), "sat", f._sat(ln), f._sat(tu) if tu else -1])
			game.flags.erase("free_build")
			for r in res:
				print("HUNT chain ", r)
			print("TEST duelB_chain115 done")
		"duelB_bp115":
			var f = game.factory
			var w = game.world
			var a: Vector2i = f.hq.cell + Vector2i(-16, 14)
			var a2: Vector2i = a + Vector2i(0, 6)
			for dx in range(-2, 12):
				for dz in range(-2, 10):
					w.remove_node(World.wc(a + Vector2i(dx, dz)))
			# линия из 8 лент (за ресурсы), на каждой — по стальному слитку
			for k in 8:
				f.hq.inv.add("iron_ingot", 1)
				var bl = game.cmd("place", {"type": "belt", "cell": a + Vector2i(k, 0), "dir": 2})
				if bl != null:
					f.set_item(bl, "steel")
			var bp: Dictionary = game.blueprints.copy_rect(a, a + Vector2i(7, 0))
			var with_it: int = bp.items.filter(func(e): return e.has("it")).size()
			# ставим чертёж 3 раза в другом месте и разбираем — сталь появляется из ничего
			var steel0: int = game.player.inv.count("steel") + f.hq.inv.count("steel")
			var ing0: int = game.player.inv.count("iron_ingot") + f.hq.inv.count("iron_ingot")
			f.hq.inv.add("iron_ingot", 8)
			var n: int = game.blueprints.paste(bp, a2, 0)
			var got_items := 0
			for k in 8:
				var b = f.building_at(a2 + Vector2i(k, 0))
				if b != null and b.item == "steel":
					got_items += 1
				if b != null:
					f.deconstruct(b)
			var steel1: int = game.player.inv.count("steel") + f.hq.inv.count("steel")
			var ing1: int = game.player.inv.count("iron_ingot") + f.hq.inv.count("iron_ingot")
			print("HUNT bp items_with_it=", with_it, " placed=", n, " belts_with_steel_after_paste=", got_items, " steel gained=", steel1 - steel0, " ingot net (paid 8, refunded)=", ing1 - ing0 - 8)
			print("TEST duelB_bp115 done")
		"duelB_bp2115":
			var f = game.factory
			var w = game.world
			var a: Vector2i = f.hq.cell + Vector2i(-16, 14)
			for dx in range(-2, 12):
				for dz in range(-2, 12):
					w.remove_node(World.wc(a + Vector2i(dx, dz)))
			var cap = f.place("supply_capsule", a, 0)
			var bp: Dictionary = game.blueprints.copy_rect(a, a)
			var cost: Dictionary = game.blueprints.total_cost(bp)
			var res := []
			for k in 3:
				var n: int = game.blueprints.paste(bp, a + Vector2i(2 + k * 2, 4), 0)
				var b = f.building_at(a + Vector2i(2 + k * 2, 4))
				res.append([n, b.type if b else "-", b.inv.slots.size() if b and b.inv else 0, b.maxhp if b else 0])
			print("HUNT bp2 blueprint=", bp.items, " cost=", cost, " pasted=", res, " capsules_tracked=", game.events.capsules.size())
			print("TEST duelB_bp2115 done")
		"duelB_autorep115":
			var f = game.factory
			var w = game.world
			var c: Vector2i = f.hq.cell + Vector2i(-14, -12)
			for dx in range(-3, 9):
				for dz in range(-3, 6):
					w.remove_node(World.wc(c + Vector2i(dx, dz)))
			game.flags["free_build"] = true
			var a = put(game, "furnace", c, 0)
			var ctl = put(game, "furnace", c + Vector2i(4, 0), 0)
			game.flags.erase("free_build")
			f.damage(a, a.maxhp * 0.5)
			var d: Dictionary = game.save_dict()
			f.remove(a)
			game.load_game(d)
			var a2 = f.building_at(c)
			f.damage(ctl, ctl.maxhp * 0.5)
			game.skills["engineering"] = 5
			var h0: float = a2.hp
			var hc0: float = ctl.hp
			for i in 30:
				f._repair_acc = 1.0
				f._auto_repair(0.1)
			print("HUNT autorep pct/min=", f.auto_repair_pct(game.team_bonus("repair")), " loaded_damaged hp ", h0, "->", a2.hp, " in_damaged=", f.damaged.has(a2), " | control hp ", hc0, "->", ctl.hp)
			print("TEST duelB_autorep115 done")
		"duelB_wave115":
			var en = game.enemies
			en.start_wave()
			var n_live: int = en.list.size()
			var d: Dictionary = game.save_dict()
			var js := JSON.stringify(d)
			var has_mon := false
			for e in en.list:
				if js.contains("\"%s\"" % e.type) and js.find("\"%s\"" % e.type) >= 0:
					pass
			var keys := []
			for k in d.keys():
				if str(k).contains("enem") or str(k).contains("wave") or str(k).contains("mon") or str(k).contains("pack"):
					keys.append([k, d[k]])
			print("HUNT wave started wave=", en.wave, " wave_live=", en.wave_live, " monsters=", n_live, " save keys about waves/monsters=", keys)
			print("TEST duelB_wave115 done")
		"duelB_bot115":
			var f = game.factory
			var w = game.world
			var B = game.builders
			DB.data.buildings["hq"]["params"]["power"] = 900
			var c: Vector2i = f.hq.cell + Vector2i(-14, -6)
			for dx in range(-8, 12):
				for dz in range(-8, 10):
					w.remove_node(World.wc(c + Vector2i(dx, dz)))
			game.flags["free_build"] = true
			var bay = put(game, "builder_bay", c, 0)
			var fu = put(game, "furnace", c + Vector2i(4, 0), 0)
			var ww = put(game, "wall_wood", c + Vector2i(0, 6), 0)
			game.flags.erase("free_build")
			f.fz.set_level(fu, 3)
			f.auto_wire_all()
			f._rebuild_power()
			f._power(0.1)
			# разрушают монстры: печь ×3 и деревянную стену
			f.damage(fu, 99999.0)
			f.damage(ww, 99999.0)
			var n_ruins: int = B.ruins.size()
			var costs := []
			for r in B.ruins:
				costs.append([r.type, r.get("lvl", 1), B.ruin_cost(r)])
			# в штабе хватает на одну печь и на стену, но не на печь ×3
			f.hq.inv.remove("stone", f.hq.inv.count("stone"))
			f.hq.inv.add("stone", 30)
			f.hq.inv.add("log", 10)
			var msgs := {}
			f.nets.append({"supply": 1000.0, "demand": 0.0, "sat": 1.0, "stored": 0.0, "cap": 0.0, "tripped": false, "over_t": 0.0, "gen_max": 0.0})
			var fk: int = f.nets.size() - 1
			for i in 1200:
				bay.net = fk
				B.update(0.1)
				if bay in B.bays:
					msgs[str(B.bays[bay].msg)] = true
			var left := []
			for r in B.ruins:
				left.append(r.type)
			print("HUNT bot sat=", f._sat(bay), " ruins=", n_ruins, " costs=", costs, " after 120s left=", left, " built=", B.bays[bay].get("built", 0) if bay in B.bays else -1, " stone=", f.hq.inv.count("stone"), " msgs=", msgs.keys())
			print("TEST duelB_bot115 done")
		"duelB_bio115":
			var f = game.factory
			var w = game.world
			var c: Vector2i = f.hq.cell + Vector2i(-12, -10)
			for dx in range(-3, 8):
				for dz in range(-3, 6):
					w.remove_node(World.wc(c + Vector2i(dx, dz)))
			game.flags["free_build"] = true
			var bb = put_near(game, "biomass_burner", c, 0)
			game.flags.erase("free_build")
			var inv = game.player.inv
			inv.slots.fill(null)
			inv.add("apple", 5)
			inv.add("berry", 8)
			inv.add("mushroom", 3)
			inv.add("branch", 4)
			var moved: int = f.put_from(bb, inv)
			print("HUNT biomass put_all moved=", moved, " fuel=", bb.fuel.totals(), " bag left=", inv.totals())
			print("TEST duelB_bio115 done")
		"duelB_orders115":
			var o = game.orders
			game.abundance.clear()
			var p_buy0: float = o.unit_price("iron_plate", "buy")
			var shop0: int = game.buy_price("iron_plate")
			game.abundance["iron_plate"] = 0.7   # у игрока плит больше всего
			var p_buy1: float = o.unit_price("iron_plate", "buy")
			var shop1: int = game.buy_price("iron_plate")
			print("HUNT orders buy unit_price ", p_buy0, " -> ", p_buy1, " (abundance 0.7); station buy_price ", shop0, " -> ", shop1)
			print("TEST duelB_orders115 done")
		"duelA_sp115":
			var f = game.factory
			var hq: Vector2i = f.hq.cell
			game.flags["free_build"] = true
			var port = put_near(game, "drone_port", hq + Vector2i(12, 0))
			var dock = put_near(game, "drone_dock", hq + Vector2i(24, 0))
			var cnt := func(d: Dictionary) -> int:
				var k := 0
				for b in d.buildings:
					for key in ["inv", "out", "fuel"]:
						for s in b.get(key, []):
							if s is Dictionary and str(s.get("id", "")) == "iron_plate":
								k += int(s.n)
				for s in d.player.inv:
					if s is Dictionary and str(s.get("id", "")) == "iron_plate":
						k += int(s.n)
				return k
			print("HUNT sp port=", port.type if port else null, " dock=", dock.type if dock else null)
			var plates0: int = cnt.call(game.save_dict())
			port.inv.add("iron_plate", 10)
			var plates1: int = cnt.call(game.save_dict())
			port.inv.remove("iron_plate", 10)
			game.carriers.launch(port, dock, "iron_plate", 10, "drone_carrier", 14.0, false)
			print("HUNT sp flights now=", game.carriers.flights.size(), " port_inv=", port.inv.count("iron_plate"))
			var d2: Dictionary = game.save_dict()
			print("HUNT sp carriers: in_save before=", plates1 - plates0, " in_flight=", game.carriers.flights.size(), " in_save during flight=", cnt.call(d2) - plates0, " save keys has carriers=", d2.has("carriers"))
			var fu = put_near(game, "furnace", hq + Vector2i(-12, -12))
			game.factory.fz.set_level(fu, 3)
			fu.hp = fu.maxhp
			var hq_m0: float = f.hq.maxhp
			var m0: float = fu.maxhp
			game.skill_points = 1
			game.upgrade_skill("mining")
			print("HUNT sp skill-up: furnace lvl=", fu.lvl, " maxhp ", m0, " -> ", fu.maxhp, " hp=", fu.hp, " ; hq maxhp ", hq_m0, " -> ", f.hq.maxhp)
			# /pay to a nick with a space (auto-renamed duplicate nick «Гость 92»)
			var N = Net._self()
			print("HUNT sp host err='", N.host(24797, 8, {"wallets": "own"}), "'")
			N.peers[5] = {"nick": "Гость", "color": "#fff"}
			N.peers[6] = {"nick": "Гость 92", "color": "#fff"}
			N.wallets["Гость"] = 0
			N.wallets["Гость 92"] = 0
			game.credits = 1000
			game.coop.chat_command("/pay Гость 92 5")
			print("HUNT sp /pay 'Гость 92' 5 -> wallets=", N.wallets, " host credits=", game.credits)
			N.peers.erase(5)
			N.peers.erase(6)
			N.leave()
			print("TEST duelA_sp115 done")
		"duelA_lang115":
			for s in ["Слишком много попыток — подождите минуту", "Нет прав администратора", "Для заказа нужно %d × %s" % [5, "Железный слиток"], "Продано за %d кр" % 40, "Мир сохраняет хозяин комнаты. Ваши вещи, уровень и навыки отправлены ему и сохранятся вместе с миром", "Связь с хозяином игры потеряна. Игра продолжается без сети", "Не хватает кредитов"]:
				print("HUNT lang '", s, "' -> '", Lang.t(s), "'")
			print("TEST duelA_lang115 done")
		"duelA_nethost4_115":
			var N = Net._self()
			var f = game.factory
			game.profession = "mechanic"
			game.flags["free_build"] = true
			var ch = put_near(game, "chest", f.hq.cell + Vector2i(-10, 8))
			game.flags["free_build"] = false
			print("HUNT host chest cell=", ch.cell, " maxhp=", ch.maxhp, " hp=", ch.hp, " hq maxhp=", f.hq.maxhp)
			f.hq.inv.add("iron_ingot", 20)
			var ho = game.orders.place("sell", "iron_ingot", 5, 50)
			var of = game.orders.make_offer(ho)
			of.pay_item = ""
			of.pay_n = 0
			of.credits = 77
			ho.offers.append(of)
			print("HUNT host err='", N.host(24795, 8, {"name": "DuelA4", "wallets": "shared", "access": "all"}), "' mode=", N.mode)
			var waitchat := func(word: String, sec: float) -> bool:
				var tq := Time.get_ticks_msec() + int(sec * 1000)
				while Time.get_ticks_msec() < tq:
					await tree.process_frame
					for l in N.chat_log:
						if str(l[2]) == word:
							return true
				return false
			var ok1: bool = await waitchat.call("G1READY", 120)
			var gid: int = N.puppets.keys()[0] if not N.puppets.is_empty() else 0
			print("HUNT host g1 ready=", ok1, " guest nick='", N.peers.get(gid, {}).get("nick", "?"), "' credits=", game.credits, " hq iron=", f.hq.inv.count("iron_ingot"), " host orders=", game.orders.list.size(), " offers=", (ho.offers as Array).size())
			var acc: bool = game.orders.accept(ho, of) if game.orders.list.has(ho) else false
			print("HUNT host accepts same offer again: ok=", acc, " credits=", game.credits, " hq iron=", f.hq.inv.count("iron_ingot"))
			N.kick(gid)
			await tree.create_timer(2.0).timeout
			print("HUNT host kicked, banned=", N.banned)
			var tq2 := Time.get_ticks_msec() + 90000
			while Time.get_ticks_msec() < tq2 and N.puppets.is_empty():
				await tree.process_frame
			var gid2: int = N.puppets.keys()[0] if not N.puppets.is_empty() else 0
			print("HUNT host after kick rejoin: accepted=", gid2 != 0, " nick='", N.peers.get(gid2, {}).get("nick", "?"), "' banned=", N.banned)
			await waitchat.call("G2READY", 60)
			f.damage(f.hq, 1.0e9)
			print("HUNT host HQ destroyed: game_over=", game.game_over, " hq.hp=", f.hq.hp, " hq in all=", f.all.has(f.hq))
			await waitchat.call("DONE", 120)
			N.leave()
			print("TEST duelA_nethost4_115 done")
		"duelA_adm115":
			var N = Net._self()
			game.credits = 1111
			game.save_game("save1", true)
			var s1a = DB.read_file(DB.saves_dir().path_join("save1.json"))
			print("HUNT adm single-player save1 credits=", s1a.credits, " has net_players=", s1a.has("net_players"))
			print("HUNT adm host err='", N.host(24797, 8, {"name": "AdmRoom"}), "'")
			game.credits = 2222
			game.admin.ok = true
			var msg = game.admin.host_act("save", {}, 1)
			var s1b = DB.read_file(DB.saves_dir().path_join("save1.json"))
			print("HUNT adm after admin 'save' (", msg, "): save1 credits=", s1b.credits, " has net_players=", s1b.has("net_players"), " room slot exists=", FileAccess.file_exists(DB.saves_dir().path_join(N.room_slot() + ".json")))
			# kill_all kills peaceful traders too
			var tr: Array = game.npcs.spawn_visit("trader", 1)
			var rep0 = game.npcs.rep.duplicate()
			var m = game.enemies.spawn("crawler", game.player.position + Vector3(30, 0, 0))
			print("HUNT adm kill_all: ", game.admin.host_act("kill_all", {}, 1), " trader alive=", tr[0].alive if not tr.is_empty() else "none", " rep ", rep0, " -> ", game.npcs.rep, " fmem=", game.npcs.fmem)
			N.leave()
			print("TEST duelA_adm115 done")
		"duelA_nethost5_115":
			var N = Net._self()
			var f = game.factory
			f.hq.inv.add("iron_ingot", 40)
			print("HUNT host err='", N.host(24795, 8, {"name": "DuelA5", "start": "near", "wallets": "own", "access": "none"}), "' mode=", N.mode)
			var t_join := Time.get_ticks_msec() + 120000
			while Time.get_ticks_msec() < t_join and N.puppets.is_empty():
				await tree.process_frame
			var tq := Time.get_ticks_msec() + 3000
			while Time.get_ticks_msec() < tq:
				await tree.process_frame
			var gid: int = N.puppets.keys()[0] if not N.puppets.is_empty() else 0
			var gnk: String = str(N.peers.get(gid, {}).get("nick", ""))
			var ob = game.coop.outpost_of(gnk)
			print("HUNT host before: hq owner=", f.hq.bstate.get("owner", ""), " hq iron_ingot=", f.hq.inv.count("iron_ingot"), " hq iron_plate=", f.hq.inv.count("iron_plate"), " guest outpost=", ob != null, " wallet=", N.wallets.get(gnk, -1), " host credits=", game.credits)
			var done := false
			var tq2 := Time.get_ticks_msec() + 120000
			while Time.get_ticks_msec() < tq2 and not done:
				await tree.process_frame
				for l in N.chat_log:
					if str(l[2]) == "DONE":
						done = true
			print("HUNT host after guest sell/buy: hq iron_ingot=", f.hq.inv.count("iron_ingot"), " hq iron_plate=", f.hq.inv.count("iron_plate"), " outpost iron_plate=", ob.inv.count("iron_plate") if ob else -1, " guest wallet=", N.wallets.get(gnk, -1), " host credits=", game.credits)
			N.leave()
			print("TEST duelA_nethost5_115 done")
		"duelA_adm2_115":
			var N = Net._self()
			print("HUNT adm2 host err='", N.host(24797, 8, {"name": "AdmRoom2"}), "'")
			game.admin.ok = true
			N.peers[7] = {"nick": "Вася", "color": "#fff"}
			print("HUNT adm2 make_admin: ", game.admin.host_act("make_admin", {"to": 7, "on": true}, 1), " ; free_build: ", game.admin.host_act("player", {"to": 7, "set": {"free_build": true}}, 1))
			N._on_peer_disconnected(7)
			print("HUNT adm2 Вася left: peers=", N.peers.keys(), " admin_nicks=", game.admin.admin_nicks, " free_nicks=", game.admin.free_nicks)
			N.peers[9] = {"nick": "Вася", "color": "#fff"}
			print("HUNT adm2 stranger joins as 'Вася' (id 9): is_admin_peer=", game.admin.is_admin_peer(9), " host_login(any pw)=", game.admin.host_login(9, "Вася", "wrong"))
			N.peers.erase(9)
			N.leave()
			print("TEST duelA_adm2_115 done")
		"duelA_chat115":
			var N = Net._self()
			print("HUNT chat host err='", N.host(24797, 8, {"name": "ChatRoom"}), "'")
			N._build_ui()
			print("HUNT chat box=", N.chat_box != null)
			N.chat_msg("[font_size=90][url=http://evil]Сервер[/url][/font_size]", "#ff0000][font_size=60", "[b]text[/b]")
			await tree.process_frame
			var l = N.chat_box.get_child(N.chat_box.get_child_count() - 1) if N.chat_box else null
			if l:
				print("HUNT chat parsed='", l.get_parsed_text(), "' raw_has_url=", l.text.contains("[url="))
			N.leave()
			print("TEST duelA_chat115 done")
		"duelA_bpq115":
			var f = game.factory
			var hq: Vector2i = f.hq.cell
			game.flags["free_build"] = true
			var a = put_near(game, "entangled_chest", hq + Vector2i(14, 0))
			var b2 = put_near(game, "entangled_chest", hq + Vector2i(20, 0))
			print("HUNT bpq a=", a.cfg if a else null, " b=", b2.cfg if b2 else null, " shared=", a != null and b2 != null and a.inv == b2.inv)
			var bp: Dictionary = game.blueprints.copy_rect(a.cell, a.cell)
			print("HUNT bpq bp=", bp)
			var at: Vector2i = hq + Vector2i(-20, 14)
			for q in range(0, 6):
				for fc in f.footprint("entangled_chest", World.wc(at + Vector2i(q, 0))):
					game.world.remove_node(World.wc(fc))
			var n: int = game.blueprints.paste(bp, at, 0)
			var p = f.building_at(World.wc(at))
			print("HUNT bpq pasted n=", n, " p.cfg=", p.cfg if p else null, " partner(p)=", game.quantum.partner(p).cell if p and game.quantum.partner(p) else null, " pairs=", game.quantum.pairs.keys())
			var nn = put_near(game, "entangled_chest", hq + Vector2i(-20, -14))
			print("HUNT bpq new n.cfg=", nn.cfg, " n.inv==p.inv ", nn.inv == p.inv, " a.inv==p.inv ", a.inv == p.inv)
			p.inv.add("iron_plate", 50)
			var cntf := func() -> int:
				var k := 0
				for bb in f.all:
					if bb.type == "entangled_chest":
						k += bb.inv.count("iron_plate")
				return k
			var uniq := {}
			for bb in f.all:
				if bb.type == "entangled_chest":
					uniq[bb.inv] = bb.inv.count("iron_plate")
			print("HUNT bpq before load unique-inventory plates=", uniq.values(), " ids=", uniq.keys().map(func(x): return x.get_instance_id()))
			p.inv.remove("iron_plate", 50)
			print("HUNT bpq after taking 50 from pasted chest: newchest has ", nn.inv.count("iron_plate"))
			p.inv.add("iron_plate", 50)
			var sd = JSON.parse_string(JSON.stringify(game.save_dict()))
			for bb in f.all.duplicate():
				if bb != f.hq:
					f.remove(bb)
			game.load_game(sd)
			var uniq2 := {}
			for bb in f.all:
				if bb.type == "entangled_chest":
					uniq2[bb.inv] = bb.inv.count("iron_plate")
					print("HUNT bpq after load ", bb.cell, " qpair=", bb.cfg.get("qpair"), " plates=", bb.inv.count("iron_plate"), " inv_id=", bb.inv.get_instance_id())
			print("HUNT bpq after load unique-inventory plates=", uniq2.values())
			print("TEST duelA_bpq115 done")
		"duelA_dem115":
			var f = game.factory
			var hq: Vector2i = f.hq.cell
			game.flags["free_build"] = true
			var far: Vector2i = hq + Vector2i(70, 70)
			for dx in range(-20, 20):
				for dz in range(-20, 20):
					game.world.remove_node(World.wc(far + Vector2i(dx, dz)))
			var pole = put_near(game, "pole", far)
			var bl := []
			for T in ["quantum_portal", "radar_tower", "decon_station", "searchlight", "sink"]:
				var b = null
				for r in range(1, 8):
					b = put_near(game, T, pole.cell + Vector2i(r * 2, r % 2 * 2))
					if b != null:
						break
				bl.append(b)
			for i in 40:
				f._tick(Factory.TICK)
			for b in bl:
				if b == null:
					print("HUNT dem null")
					continue
				print("HUNT dem ", b.type, " net=", b.net, " want=", b.want, " sat_c=", f.sat_c(b), " in_consumers=", b in f.consumers)
			print("HUNT dem net=", f.net_info(bl[0]) if bl[0] else null)
			print("HUNT dem portal open=", game.quantum.is_open(), " portal()=", game.quantum.portal())
			var sk = bl[4]
			if sk != null:
				var p2 = put_near(game, "pole", sk.cell + Vector2i(sk.size + 1, 0))
				f.power_dirty = true
				for i in 4:
					f._tick(Factory.TICK)
				print("HUNT dem sink net=", sk.net, " sat_c=", f.sat_c(sk), " pole2=", p2 != null)
				sk.inv.add("steel", 40)
				for i in 40:
					f._tick(Factory.TICK)
				print("HUNT dem sink steel left=", sk.inv.count("steel"), " coupons=", sk.out.count("sink_coupon") if sk.out else -1, " net=", f.net_info(sk))
			print("TEST duelA_dem115 done")
		"duelA_tut115":
			var f = game.factory
			var hq: Vector2i = f.hq.cell
			game.flags["free_build"] = true
			var tu = game.tutorial
			var ss: Array = tu.steps()
			for i in ss.size():
				if str(ss[i].get("goal", "")) == "powered":
					tu.step = i
			print("HUNT tut step=", tu.step, " goal=", tu.cur().get("goal"), " progress0=", tu.progress(), " stations_mode=", f.stations_mode())
			var far: Vector2i = hq + Vector2i(60, 60)
			var pole = put_near(game, "pole", far)
			var m = null
			for r in range(1, 6):
				m = put_near(game, "smelter", pole.cell + Vector2i(r * 2, 0))
				if m != null:
					break
			for i in 30:
				f._tick(Factory.TICK)
			print("HUNT tut pole net=", pole.net, " smelter net=", m.net if m else null, " feeder=", m.feeder if m else null, " sat=", f.sat_c(m) if m else null, " dist_hq=", World.dist(m.center(), f.hq.center()) if m else null)
			if m != null and m.net >= 0:
				print("HUNT tut net info=", f.net_info(m))
			print("HUNT tut progress1=", tu.progress(), " text=", tu.goal_text())
			print("TEST duelA_tut115 done")
		"duelA_clk115":
			var f = game.factory
			var hq: Vector2i = f.hq.cell
			game.flags["free_build"] = true
			var c: Vector2i = hq + Vector2i(14, 0)
			for dx in range(-12, 12):
				for dz in range(-12, 12):
					game.world.remove_node(World.wc(c + Vector2i(dx, dz)))
			var gen = put_near(game, "generator", c)
			gen.fuel.add("coal", 50)
			var pole = put_near(game, "pole", c + Vector2i(2, 0))
			var rt = put_near(game, "repair_tower", c + Vector2i(4, 0))
			var bar = put_near(game, "barrier_small", c + Vector2i(4, 4))
			var vic = put_near(game, "chest", c + Vector2i(6, 0))
			var res := {}
			for clk in [100.0, 50.0]:
				rt.cfg["clock"] = clk
				bar.cfg["clock"] = clk
				for i in 20:
					f._tick(Factory.TICK)
				game.defense.update(1.0)
				vic.hp = vic.maxhp * 0.2
				var h0: float = vic.hp
				for i in 5:
					game.defense._rep_t = 0.0
					game.defense.update(0.1)
				var healed: float = vic.hp - h0
				game.defense.state(bar).hp = float(bar.p("barrier_hp", 500)) * bar.mult
				var left: float = game.defense.absorb(bar.center(), 100.0)
				var ni = f.net_info(rt)
				print("HUNT clk clock=", clk, " net demand=", ni.get("demand"), " sat_c(rt)=", f.sat_c(rt), " sat_c(bar)=", f.sat_c(bar), " repaired_in_5_ticks=", healed, " barrier absorbed of 100=", 100.0 - left)
			print("TEST duelA_clk115 done")
		"duelA_rover115":
			var f = game.factory
			game.profession = "mechanic"
			game.flags.erase("free_build")
			game.tech.unlock_all()
			var tot := func() -> Dictionary:
				var o := {}
				for k in ["iron_plate", "motor", "rubber"]:
					o[k] = game.player.inv.count(k) + f.hq.inv.count(k)
				return o
			f.hq.inv.add("iron_plate", 100)
			f.hq.inv.add("motor", 10)
			f.hq.inv.add("rubber", 10)
			print("HUNT rover build_cost bonus=", game.bonus("build_cost"), " scaled=", game._scaled_cost("rover"))
			var t0: Dictionary = tot.call()
			var c: Vector2i = f.hq.cell + Vector2i(10, 10)
			for dx in range(-4, 5):
				for dz in range(-4, 5):
					game.world.remove_node(World.wc(c + Vector2i(dx, dz)))
			game.player.position = World.cell_to_world(c + Vector2i(5, 5))
			for cyc in 3:
				var b = game.cmd("place", {"type": "rover", "cell": c, "dir": 0})
				if b == null:
					print("HUNT rover place failed why=", f.can_place("rover", World.wc(c)), " locked=", Tech.building_locked("rover"), " avail=", f.available("iron_plate"))
					break
				var paid0 = b.paid
				game.vehicles.enter(b)
				game.player.position = World.cell_to_world(c + Vector2i(-6, -6))
				game.vehicles.leave()
				var b2 = null
				if b2 == null or b2.type != "rover":
					for bb in f.all:
						if bb.type == "rover":
							b2 = bb
				print("HUNT rover cyc", cyc, " paid at build=", paid0, " paid after leave=", b2.paid if b2 else null)
				f.deconstruct(b2)
				game.player.position = World.cell_to_world(c + Vector2i(5, 5))
			var t1: Dictionary = tot.call()
			print("HUNT rover before=", t0, " after 3 cycles=", t1)
			print("TEST duelA_rover115 done")
		"duelA_nuc115":
			var f = game.factory
			game.flags["free_build"] = true
			var c: Vector2i = f.hq.cell + Vector2i(-40, 30)
			for dx in range(-20, 21):
				for dz in range(-20, 21):
					game.world.remove_node(World.wc(c + Vector2i(dx, dz)))
			var r = put_near(game, "nuclear_reactor", c)
			r.fuel.add("fuel_rod", 4)
			var pole = put_near(game, "pole", c + Vector2i(6, 0))
			var sm = put_near(game, "arc_furnace", c + Vector2i(8, 4))
			var res := []
			for clk in [100.0, 50.0, 5.0]:
				r.cfg["clock"] = clk
				var s: Dictionary = Nuclear.st(r)
				s.load = 4
				s.rods_set = 0.0
				s.rods = 0.0
				s.T = 200.0
				s.water = 60.0
				s.burn = 0.0
				var sup := 0.0
				for i in 40:
					s.water = 60.0
					f.power_dirty = true
					f._tick(Factory.TICK)
				print("HUNT nuc clock=", clk, " out_pw=", snappedf(float(s.out_pw), 0.1), " burn_after_40_ticks=", snappedf(float(s.burn), 0.01), " net gen_max=", f.net_info(r).get("gen_max"), " supply=", f.net_info(r).get("supply"))
			print("TEST duelA_nuc115 done")
		"duelA_subclk115":
			var f = game.factory
			game.flags["free_build"] = true
			var c: Vector2i = f.hq.cell + Vector2i(-30, -30)
			for dx in range(-12, 13):
				for dz in range(-12, 13):
					game.world.remove_node(World.wc(c + Vector2i(dx, dz)))
			var res := []
			for clk in [100.0, 50.0]:
				var host = put(game, "assembler", c + Vector2i(0, int(clk) / 10), 0)
				var g = put(game, "generator", host.cell + Vector2i(host.size, 0), 0)
				g.cfg["clock"] = clk
				var ok: bool = f.fz.fuse_combo(host, g)
				var s = null
				for sb in host.subs:
					if sb.beh == "generator":
						s = sb
				host.recipe = DB.recipes_for(str(host.p("station", "")))[0] if not DB.recipes_for(str(host.p("station", ""))).is_empty() else ""
				host.want = true
				s.fuel.add("coal", 10)
				s.fuel_t = 0.0
				var c0: int = s.fuel.count("coal")
				for i in int(120.0 / Factory.TICK):
					host.want = true
					f.fz.tick_power(Factory.TICK)
				print("HUNT subclk clock=", clk, " fused=", ok, " sub cfg=", s.cfg, " gen_cap=", host.gen_cap, " coal used in 120s=", c0 - s.fuel.count("coal"), " fuel_t=", snappedf(s.fuel_t, 0.1), " clock panel for sub: host!=null ->", s.host != null)
			print("TEST duelA_subclk115 done")
		"duelA_siege115":
			var f = game.factory
			var sg = game.sieges
			game.day_n = 5
			print("HUNT siege enabled=", sg.enabled(), " siege_day(5)=", sg.siege_day(5))
			sg.announce()
			sg.start()
			var alive_before: int = game.enemies.list.filter(func(e): return e.alive and not e.peaceful).size()
			print("HUNT siege started boss=", sg.boss != null, " type=", sg.boss_type, " fired_day=", sg.fired_day, " hostile=", alive_before, " credits=", game.credits)
			var sd = JSON.parse_string(JSON.stringify(game.save_dict()))
			for bb in f.all.duplicate():
				if bb != f.hq:
					f.remove(bb)
			for e in game.enemies.list.duplicate():
				game.enemies.remove_silent(e)
			game.sieges.boss = null
			game.load_game(sd)
			var hostile: int = game.enemies.list.filter(func(e): return e.alive and not e.peaceful).size()
			print("HUNT siege after load boss=", sg.boss, " fired_day=", sg.fired_day, " day=", game.day_n, " hostile=", hostile, " won=", sg.won)
			# простоим до конца ночи: осада не повторится, награды нет
			var fired := false
			for i in 200:
				game.day_t = 0.6
				sg.update(1.0)
				if sg.boss != null:
					fired = true
			print("HUNT siege respawned=", fired, " credits=", game.credits)
			print("TEST duelA_siege115 done")
		"duelA_lang2_115":
			Prefs.values["language"] = "en"
			Lang.rebuild()
			var arr = JSON.parse_string(FileAccess.get_file_as_string("/tmp/claude-0/-home-user/6fafaceb-db96-58c1-b5cd-7e4e38e4c559/scratchpad/lits.json"))
			var fa := FileAccess.open("/tmp/claude-0/-home-user/6fafaceb-db96-58c1-b5cd-7e4e38e4c559/scratchpad/untr.txt", FileAccess.WRITE)
			var rx := RegEx.create_from_string("[А-Яа-яЁё]")
			var bad := 0
			for e in arr:
				var s: String = str(e[2]).c_unescape()
				var t: String = Lang.t(s)
				if rx.search(t) != null:
					bad += 1
					fa.store_line("%s:%d\t%s\t=>\t%s" % [e[0], int(e[1]), s.replace("\n", "\\n"), t.replace("\n", "\\n")])
			fa.close()
			print("HUNT lang2 bad=", bad, " of ", arr.size())
			print("TEST duelA_lang2_115 done")
		"duelA_lang3_115":
			Prefs.values["language"] = "en"
			Lang.rebuild()
			for s in ["Мирная — без волн и боссов", "Обычная — роботы ×1", "Безумие — роботы ×3, волны часто", "Ад — роботы ×4, волны очень часто",
				"Сила роботов ×1. Волны чаще или реже и больше или меньше роботов — по сложности и по тому, как далеко продвинулся завод.",
				"Снесено: 1 / 3", "Зданий с энергией: 2 / 5", "Открыть в дереве открытий: «Сталь»",
				"Подойдите ближе, чтобы чинить", "Для ремонта не хватает: Железная пластина ×3", "Отремонтировано: Плавильня", "Восстановлено: Плавильня", "Здесь не восстановить: место занято",
				"Ленты пересеклись. Откройте «Кротовину» в дереве открытий — она будет ставиться сама",
				"Здесь негде посадить — нужна свободная земля", "посажено: вырастет через 5 мин",
				"Завод растёт — роботы заметили: волны станут чуть сильнее",
				"У торговца кончились кредиты", "Продать 1", "Продать 50", "Получите 40 кр",
				"Патронов в турели: 5 · подвозите лентой, через канал штаба или кнопкой «Положить»",
				"Склад базы. Отсюда берутся ресурсы на стройку.", "Работает без помех",
				"ПКМ (держать %d с) по зданию или развалинам — ремонт за полцены",
				"Понятно", "Это окно показывается один раз. Потом то же самое — в окне здания (E).",
				"Станция платит вдвое меньше Чёрного рынка — продавать выгоднее там.",
				"Чёрный рынок: продаёт предметы с лент за кредиты (чем ценнее предмет, тем большая доля цены)",
				"Потяните, чтобы поменять размер окна. Двойной клик по заголовку — обычный размер"]:
				print("HUNT lang3 '", s, "' -> '", Lang.t(s), "'")
			print("TEST duelA_lang3_115 done")
		"duelA_lang4_115":
			Prefs.values["language"] = "en"
			Lang.rebuild()
			var arr = JSON.parse_string(FileAccess.get_file_as_string("/tmp/claude-0/-home-user/6fafaceb-db96-58c1-b5cd-7e4e38e4c559/scratchpad/dmiss.json"))
			var rx := RegEx.create_from_string("[А-Яа-яЁё]")
			var bad := 0
			for e in arr:
				var t: String = Lang.t(str(e[3]))
				if rx.search(t) != null:
					bad += 1
					if bad <= 12:
						print("HUNT lang4 ", e[0], " ", e[1], ".", e[2], " -> '", t.substr(0, 90), "'")
			print("HUNT lang4 bad=", bad, " of ", arr.size())
			print("TEST duelA_lang4_115 done")
		"v1115":
			# 1.1.15: канал штаба, турели на энергии и своих патронах, метеорит раз в ~5 минут, навес от жары/мороза,
			# пауза зоны, camera, порох с «Химией», залежи по дереву открытий, настройка частей составного по сети
			var f = game.factory
			var w = game.world
			var hq: Vector2i = f.hq.cell
			var c: Vector2i = hq + Vector2i(5, 3)
			for dx in range(-3, 9):
				for dz in range(-3, 7):
					w.remove_node(World.wc(c + Vector2i(dx, dz)))
			game.flags["free_build"] = true
			var ln = put(game, "hq_link", c, 0)
			var tu = put(game, "turret", c + Vector2i(3, 0), 0)
			var far = put_near(game, "hq_link", hq + Vector2i(60, 40), 0)
			game.flags.erase("free_build")
			f._rebuild_power()
			f._power(1.0)
			f._hq_link_take(ln, 0.0)
			f._hq_link_take(far, 0.0)
			var cells: float = World.dist(ln.center(), f.hq.center()) / World.C
			var pw_ok: bool = ln.pow_ov == 20.0 and far.pow_ov == 20.0 and float(ln.p("power")) == ln.pow_ov   # 1.1.19: всегда 20
			# «В штаб»: из 10 предметов в штаб доходит 5
			var n0: int = f.hq.inv.count("stone")
			var acc := 0
			for k in 10:
				if f.accept(ln, "stone", null):
					acc += 1
			var send_ok: bool = acc == 10 and f.hq.inv.count("stone") - n0 == 5
			var far_refuse: bool = not f.accept(far, "stone", null)
			# «Из штаба»: выбранное уходит на выход, каждый второй теряется
			ln.cfg["mode"] = "take"
			ln.cfg["items"] = ["iron_plate"]
			f.hq.inv.add("iron_plate", 20)
			var p0: int = f.hq.inv.count("iron_plate")
			ln.out.remove("iron_plate", ln.out.count("iron_plate"))
			for k in 6:
				f._hq_link_take(ln, 1.05)
			var took: int = p0 - f.hq.inv.count("iron_plate")
			var take_ok: bool = took == 6 and ln.out.count("iron_plate") == 3 and not f.accept(ln, "stone", null)
			# турель: свои патроны (лентой/руками), без энергии не стреляет
			var ammo := str(tu.p("ammo", ""))
			var mag_ok: bool = tu.inv != null and f.accept(tu, ammo, null) and not f.accept(tu, "stone", null) and tu.inv.count(ammo) == 1
			tu.inv.add(ammo, 9)
			f.hq.inv.add(ammo, 50)
			var hq_ammo: int = f.hq.inv.count(ammo)
			var e = game.enemies.spawn("crawler" if DB.data.enemies.has("crawler") else DB.data.enemies.keys()[0], tu.center() + Vector3(6, 0, 0))
			tu.cd = 0.0
			tu.target = null
			f._turrets(0.05)
			var shot: bool = tu.inv.count(ammo) == 9 and f.hq.inv.count(ammo) == hq_ammo
			var net0: int = tu.net
			tu.net = -1
			tu.cd = 0.0
			f._turrets(0.05)
			var no_pow: bool = tu.inv.count(ammo) == 9 and not tu.active
			tu.net = net0
			if e != null:
				game.enemies.hit(e, 99999.0)
			var pc: Array = f.port_counts(tu.type)
			var def_ok: bool = mag_ok and shot and no_pow and int(DB.bparam("turret", "power", 0)) == 3 and pc[0] == 1
			# метеорит раз в ~5 минут
			var mets := func():
				var m := 0
				for nc in w.nodes:
					if w.nodes[nc].res == "meteorite":
						m += 1
				return m
			var m0: int = mets.call()
			game.events._met_t = 0.01
			game.events._lone_meteor(0.1)
			var m1: int = mets.call()
			var met_ok: bool = m1 > m0 and game.events._met_t >= 240.0 and game.events._met_t <= 360.0
			# навес/бункер: ни жары, ни мороза
			var cl = game.climate
			var cc: Dictionary = cl.cfg()
			game.events.shelters = [[game.player.position, 10.0, f.hq, false]]
			cl.step(0.1)
			var canopy_ok: bool = cl.feel >= float(cc.get("comfort_min", 8)) and cl.feel <= float(cc.get("comfort_max", 30)) and game.events.thirst_mult() == 1.0
			game.events.shelters = []
			# расширение зоны: пауза минута
			var z = game.zone
			var zone_ok := true
			if z.on():
				z.next_ok_ms = 0
				f.hq.inv.add("crystal", 0)
				z.expand(true)
				zone_ok = z.cooldown_left() > 55.0 and z.can_expand().begins_with("Следующее")
				z.next_ok_ms = 0
			# camera
			game.free_camera()
			var cam_on: bool = game.photo_mode and game.photo.free_cam
			game.free_camera()
			var cam_ok: bool = cam_on and not game.photo_mode
			# порох и патроны с «Химией»: пороховой цех + сборщик
			var tc = game.tech
			tc.done.erase("t_chem")
			tc.refresh_locks()
			var lock0: bool = DB.locked.has("r:gunpowder") and DB.locked.has("b:powder_mill") and not DB.locked.has("d:sulfur")   # 1.1.19: залежи видны сразу
			tc.unlock("t_chem")
			var chem_ok: bool = lock0 and not DB.locked.has("r:gunpowder") and not DB.locked.has("r:ammo") and not DB.locked.has("b:powder_mill") \
				and "powder_mill" in DB.data.recipes.gunpowder.stations and "assembler" in DB.data.recipes.ammo.stations
			# все залежи из дерева открытий есть в мире: скрыты до открытия, видны после
			var dep_bad := []
			for tid in DB.data.tech:
				for it in DB.data.tech[tid].get("unlocks", {}).get("deposits", []):
					var idx := -1
					for i in w.deposits.size():
						if str(w.deposits[i].get("item", "")) == str(it):
							idx = i
					var cnt := 0
					var any_c := Vector2i(-1, -1)
					for dc in w.deposit:
						if w.deposit[dc] == idx:
							cnt += 1
							any_c = dc
					if idx < 0 or cnt == 0:
						dep_bad.append("%s:none" % it)
						continue
					var was: bool = tc.done.has(tid)
					tc.done.erase(tid)
					tc.refresh_locks()
					w.reveal_deposits()
					var hid: bool = w.deposit_hidden(idx) and w.deposit_item(any_c) == "" and w.ore_img.get_pixelv(any_c).a < 0.01
					tc.unlock(tid)
					var vis: bool = not w.deposit_hidden(idx) and w.deposit_item(any_c) == str(it) and w.ore_img.get_pixelv(any_c).a > 0.5
					if not was:
						pass
					if not (hid and vis):
						dep_bad.append("%s:%s/%s" % [it, hid, vis])
			# настройка части составного здания по сети: _pack/_unpack попадают в саму часть
			var c2: Vector2i = hq + Vector2i(-9, 6)
			for dx in range(-2, 4):
				for dz in range(-2, 4):
					w.remove_node(World.wc(c2 + Vector2i(dx, dz)))
			game.flags["free_build"] = true
			var fu = put(game, "furnace", c2, 0)
			var asm = put(game, "assembler", c2 + Vector2i(1, 0), 0)
			game.flags.erase("free_build")
			var sub_ok := false
			if fu != null and asm != null:
				game.cmd("fuse", {"a": fu, "b": asm, "kind": "combo"})
				var nn = Net._self()
				var pk: Dictionary = nn._pack({"b": asm})
				var up = nn._unpack(pk)
				sub_ok = asm.host == fu and pk.b.has("_s") and up != null and up.b == asm
			# заказы станции: актуальные сверху, выполненные скрыты
			var cids: Array = tc.contracts().keys()
			var ord_ok := true
			if cids.size() >= 2:
				for cid in cids:
					if tc.c_state(cid) != "locked":
						tc.c_done[cid] = true
						break
				var vb := VBoxContainer.new()
				game.hud.contracts_done_show = false
				game.hud._contracts_ui(vb)
				var txt := ""
				for ch0 in vb.get_children():
					if ch0 is Button:
						txt += (ch0 as Button).text + "\n"
					for l0 in ch0.find_children("*", "Label", true, false):
						txt += (l0 as Label).text + "\n"
				ord_ok = not txt.contains("✔ ") and txt.contains("Показать выполненные")
				vb.free()
			print("TEST v1115 orders=", ord_ok, " link_pow=", [ln.pow_ov, far.pow_ov, snappedf(cells, 0.1)], " pw=", pw_ok, " send=", send_ok, " far_refuse=", far_refuse, " take=", take_ok, "(", took, ",", ln.out.count("iron_plate"), ")",
				" turret=", [mag_ok, shot, no_pow, pc], " meteor=", met_ok, [m0, m1], " canopy=", canopy_ok, snappedf(cl.feel, 0.1), " zone=", zone_ok, " cam=", cam_ok, " chem=", chem_ok,
				" deps_bad=", dep_bad, " sub=", sub_ok, " ",
				"OK" if pw_ok and send_ok and far_refuse and take_ok and def_ok and met_ok and canopy_ok and zone_ok and cam_ok and chem_ok and dep_bad.is_empty() and sub_ok and ord_ok else "FAIL")
		"fix1115":
			# 1.1.15: найденное агентом-проверяльщиком: ленты в протягивании, развалины составных, поворот составного, меню стройки
			var f = game.factory
			game.flags["free_build"] = true
			var c: Vector2i = f.hq.cell + Vector2i(10, -14)
			for dx in range(-8, 16):
				for dz in range(-8, 16):
					game.world.remove_node(World.wc(c + Vector2i(dx, dz)))
			# а) линия упирается в сундук и поворачивает — лента перед сундуком не разворачивается боком
			put(game, "chest", c + Vector2i(2, 0), 0)
			game.build_type = "belt"
			game.build_dir = 0
			game.hover_cell = c
			game.drag_last = c
			game.drag_placed = game.cmd("place", {"type": "belt", "cell": c, "dir": 0})
			for hc in [c + Vector2i(1, 0), c + Vector2i(2, 0), c + Vector2i(2, 1)]:
				game.hover_cell = hc
				game._drag_world()
			var b1 = f.building_at(c + Vector2i(1, 0))
			var d1_ok: bool = b1 != null and b1.dir == 0
			# б) Mk2 поперёк линии Mk1 — перекрёсток (кротовина), поперечная линия цела
			var vc: Vector2i = c + Vector2i(4, 4)
			for k in 5:
				put(game, "belt", vc + Vector2i(0, k), 1)
			var hs: Vector2i = vc + Vector2i(-3, 2)
			game.build_type = "belt_mk2"
			game.hover_cell = hs
			game.drag_last = hs
			game.drag_placed = game.cmd("place", {"type": "belt_mk2", "cell": hs, "dir": 0})
			game.hover_cell = hs + Vector2i(6, 0)
			game._drag_world()
			var xb = f.building_at(vc + Vector2i(0, 2))
			var d2_ok: bool = xb != null and (xb.beh == "junction" or (xb.type == "belt" and xb.dir == 1))
			# в) Mk2 по линии Mk1 в обратную сторону — улучшается и смотрит вдоль новой линии
			var ec: Vector2i = c + Vector2i(0, 10)
			for k in 4:
				put(game, "belt", ec + Vector2i(k, 0), 2)
			game.hover_cell = ec
			game.drag_last = ec
			game.drag_placed = game.cmd("place", {"type": "belt_mk2", "cell": ec, "dir": 0})
			game.hover_cell = ec + Vector2i(3, 0)
			game._drag_world()
			var eb = f.building_at(ec + Vector2i(2, 0))
			var d3_ok: bool = eb != null and eb.type == "belt_mk2" and eb.dir == 0
			game.build_type = ""
			# г) развалины объединения 2 со встроенным сборщиком восстанавливаются целиком
			var rc: Vector2i = f.hq.cell + Vector2i(16, -10) + Vector2i(0, 14)
			for dx in range(-3, 8):
				for dz in range(-3, 8):
					game.world.remove_node(World.wc(rc + Vector2i(dx, dz)))
			var a1 = put(game, "furnace", rc, 0)
			var a2 = put(game, "furnace", rc + Vector2i(a1.size, 0), 0)
			f.fz.fuse_level(a1, a2)
			var asm = put(game, "assembler", rc + Vector2i(0, a1.size), 0)
			f.fz.fuse_combo(a1, asm)
			var lv0: int = a1.lvl
			var sb0: int = a1.subs.size()
			f.damage(a1, 1e9)
			var rr = game.builders.ruin_at(rc)
			var rcost: Dictionary = game.builders.ruin_cost(rr) if rr != null else {}
			game.cmd("repair", {"cell": rc})
			var nb = f.building_at(rc)
			var ruin_ok: bool = lv0 == 2 and sb0 == 1 and nb != null and nb.lvl == 2 and nb.subs.size() == 1 and nb.subs[0].type == "assembler"
			var bc: Dictionary = game._scaled_cost("furnace")
			var cost_ok: bool = rr != null and int(rcost.get(bc.keys()[0], 0)) >= int(bc.values()[0]) * 2
			var saved: Dictionary = game.builders.to_dict()
			# д) поворот составного — встроенная машина поворачивается тоже
			var rot_ok := false
			if nb != null and not nb.subs.is_empty():
				var s0 = nb.subs[0]
				var r = f.renderer(s0.type)
				var gx := func():
					var sr = r._owner_sub.get(s0)
					return sr.base_xf[sr.index_of[s0]] if sr != null else null
				game.cmd("rotate", {"b": nb})
				rot_ok = gx.call() == f.fz.sub_xform(nb, 0)
			# е) меню стройки: новое здание видно сразу после изучения
			var T = game.tech
			T.done.clear()
			T.refresh_locks()
			game.flags.erase("free_build")
			game.hud.build_cat = "logistics"
			game.hud.open("build")
			await tree.process_frame
			game.hud._refresh_build()
			var has_split := func():
				for n in game.hud.windows.build.find_children("*", "", true, false):
					if n is BaseButton and "bid" in n and n.bid == "splitter" and n.modulate.a > 0.9:
						return true
				return false
			var before: bool = has_split.call()
			T.unlock("t_logistics")
			await tree.process_frame
			game.hud._refresh_build()
			var menu_ok: bool = not before and has_split.call()
			game.hud.close("build")
			# ж) пересчёт закрытого без изменений не пересобирает меню (у гостей — раз в секунду)
			var lr0: int = Tech.lock_rev
			T.refresh_locks()
			T.refresh_locks()
			var lr_ok: bool = Tech.lock_rev == lr0
			# з) патроны лентой во встроенную турель — в её магазин, не в штаб
			game.flags["free_build"] = true
			var tcx: Vector2i = f.hq.cell + Vector2i(-12, -12)
			for dx in range(-3, 6):
				for dz in range(-3, 6):
					game.world.remove_node(World.wc(tcx + Vector2i(dx, dz)))
			var t1 = put(game, "turret", tcx, 0)
			var t2 = put(game, "furnace", tcx + Vector2i(t1.size if t1 else 1, 0), 0)
			var comp_ok := false
			if t1 != null and t2 != null:
				game.cmd("fuse", {"a": t2, "b": t1, "kind": "combo"})
				var host = t2 if not t2.subs.is_empty() else t1
				var tsub = null
				for sb in host.subs:
					if sb.beh == "turret":
						tsub = sb
				var hq0: int = f.hq.inv.count("ammo")
				var okn := 0
				for k in 5:
					if f.accept(host, "ammo", null):
						okn += 1
				comp_ok = tsub != null and tsub.inv != null and tsub.inv.count("ammo") >= 1 and f.hq.inv.count("ammo") == hq0
				if not comp_ok:
					print("DBG comp host=", host.type, " subs=", host.subs.map(func(x): return x.type), " okn=", okn, " sub_ammo=", tsub.inv.count("ammo") if tsub and tsub.inv else -1)
			# и) канал без дела не ест энергию
			var lk = put(game, "hq_link", f.hq.cell + Vector2i(4, -6), 0)
			var idle_ok: bool = lk != null and not f.link_busy(lk)
			if lk != null:
				f.accept(lk, "stone", null)
				idle_ok = idle_ok and (f.link_busy(lk) or lk.net < 0)
			# к) старое сохранение: магазины турелей заряжаются из штаба
			var mig_ok := false
			if t1 != null:
				f.hq.inv.add("ammo", 30)
				var mt = null
				for tt in f.turrets:
					if not tt.dead and tt.inv != null:
						tt.inv.remove("ammo", tt.inv.count("ammo"))
						mt = tt
				game._migrate_turrets_115("1.1.14")
				mig_ok = mt != null and mt.inv.count("ammo") > 0
			game.flags.erase("free_build")
			print("TEST fix1115 lock_rev_stable=", lr_ok, " comp_turret=", comp_ok, " link_idle=", idle_ok, " migrate=", mig_ok, " drag_chest=", d1_ok, " cross=", d2_ok, " reverse_up=", d3_ok, " ruin=", ruin_ok, " ruin_cost=", cost_ok, " rot=", rot_ok, " menu=", [before, menu_ok], " ",
				"OK" if d1_ok and d2_ok and d3_ok and ruin_ok and cost_ok and rot_ok and menu_ok and lr_ok and comp_ok and idle_ok and mig_ok else "FAIL")
		"duelA_ports115":
			game._apply_sizes(true)
			DB.data.settings["ports18"] = {"on": true}
			var f = game.factory
			var w = game.world
			game.flags["free_build"] = true
			var C0: Vector2i = f.hq.cell + Vector2i(30, 30)
			var bad := []
			var nok := 0
			for T in DB.data.buildings:
				var bd: Dictionary = DB.data.buildings[T]
				var beh := str(bd.get("behavior", ""))
				if beh in ["belt", "splitter", "merger", "junction", "pipe", "foundation", "rails", "vehicle"]:
					continue
				var pc: Array = f.port_counts(T)
				if pc[0] < 0:
					continue
				for d in 4:
					for dx in range(-4, 10):
						for dz in range(-4, 10):
							var cc: Vector2i = World.wc(C0 + Vector2i(dx, dz))
							var ob = f.grid.get(cc)
							if ob != null and ob != f.hq:
								f.remove(ob)
							w.remove_node(cc)
					var b = put(game, T, C0, d)
					if b == null:
						bad.append("%s d%d unplaceable:%s" % [T, d, f.can_place(T, C0)])
						break
					if b.pin.size() != pc[0] or b.pout.size() != pc[1]:
						bad.append("%s d%d portcount pin=%d pout=%d pc=%s" % [T, d, b.pin.size(), b.pout.size(), pc])
					var ins := []
					for i in b.pin.size():
						var bl = put(game, "belt", b.pin[i], (b.pin_side[i] + 2) % 4)
						ins.append(bl)
						if bl == null:
							bad.append("%s d%d in%d belt unplaceable at %s why=%s" % [T, d, i, b.pin[i], f.can_place("belt", b.pin[i])])
					var ob2 = null
					if not b.pout.is_empty():
						ob2 = put(game, "belt", b.pout[0], b.pout_side[0])
						if ob2 == null:
							bad.append("%s d%d out belt unplaceable at %s why=%s" % [T, d, b.pout[0], f.can_place("belt", b.pout[0])])
					for i in ins.size():
						var bl = ins[i]
						if bl == null:
							continue
						if bl.next != b or f._input_index(b, bl) != i:
							bad.append("%s d%d in%d belt.next=%s idx=%d" % [T, d, i, bl.next.type if bl.next else "null", f._input_index(b, bl)])
						# port cell must be adjacent to footprint
						var adj := false
						for fc in f.footprint(T, b.cell):
							if World.wc(fc + Vector2i(1,0)) == bl.cell or World.wc(fc - Vector2i(1,0)) == bl.cell or World.wc(fc + Vector2i(0,1)) == bl.cell or World.wc(fc - Vector2i(0,1)) == bl.cell:
								adj = true
						if not adj:
							bad.append("%s d%d in%d not adjacent" % [T, d, i])
					if ob2 != null and b.next != ob2:
						bad.append("%s d%d out next=%s" % [T, d, b.next.type if b.next else "null"])
					if ob2 != null and ob2.next == b:
						bad.append("%s d%d outbelt loops back" % [T, d])
					# a belt at an input cell must not be the building's output
					for bl in ins:
						if bl != null and (b.next == bl or bl in b.nexts):
							bad.append("%s d%d input belt is also output" % [T, d])
					nok += 1
			game.flags.erase("free_build")
			print("HUNT ports checked=", nok, " bad=", bad.size())
			for x in bad:
				print("HUNT  ", x)
			print("TEST duelA_ports115 ", "OK" if bad.is_empty() else "FAIL")
		"duelA_fuse115":
			var f = game.factory
			var w = game.world
			var fz = f.fz
			game.flags["free_build"] = true
			var c: Vector2i = f.hq.cell + Vector2i(12, 10)
			for dx in range(-3, 12):
				for dz in range(-3, 12):
					w.remove_node(World.wc(c + Vector2i(dx, dz)))
			var asm = put(game, "assembler", c, 0)
			var fu = put(game, "furnace", c + Vector2i(asm.size, 0), 0)
			print("HUNT sizes asm=", asm.size, " fu=", fu.size, " fuel_before=", fu.fuel != null)
			game.cmd("fuse", {"a": asm, "b": fu, "kind": "combo"})
			var s = null
			for x in asm.subs:
				if x.type == "furnace":
					s = x
			print("HUNT combo host=", asm.type, " subs=", asm.subs.map(func(q): return q.type), " sub_fuel_inv=", s != null and s.fuel != null)
			if s != null and s.fuel != null:
				s.fuel.add("coal", 7)
			var arr: Array = fz.save_subs(asm)
			print("HUNT saved=", JSON.stringify(arr))
			# simulate load
			var asm2 = put(game, "assembler", c + Vector2i(0, 5), 0)
			fz.load_subs(asm2, arr)
			var s2 = asm2.subs[0] if not asm2.subs.is_empty() else null
			print("HUNT loaded sub fuel_inv=", s2 != null and s2.fuel != null, " coal_after=", s2.fuel.count("coal") if s2 and s2.fuel else -1)
			# does the loaded furnace smelt without fuel?
			if s2 != null:
				s2.recipe = "smelt_iron"
				var rin: Dictionary = DB.data.recipes.get(s2.recipe, {}).get("in", {})
				for k in rin:
					s2.inv.add(k, int(rin[k]) * 3)
				f._rebuild_power()
				f._power(0.05)
				var made := 0
				for i in 400:
					fz.tick_subs(0.05)
				made = s2.out.count(DB.data.recipes.get(s2.recipe, {}).get("out", {}).keys()[0]) if s2.recipe != "" else -1
				print("HUNT loaded furnace sub recipe=", s2.recipe, " made_without_fuel=", made, " fuel_t=", s2.fuel_t)
				# compare: original sub (has fuel inv) with no fuel
				s.fuel.slots.fill(null)
				s.fuel_t = 0.0
				s.recipe = s2.recipe
				for k in rin:
					s.inv.add(k, int(rin[k]) * 3)
				for i in 400:
					fz.tick_subs(0.05)
				print("HUNT original furnace sub made_without_fuel=", s.out.count(DB.data.recipes.get(s.recipe, {}).get("out", {}).keys()[0]))
			# level fusion loses in-progress crafting
			var c3: Vector2i = c + Vector2i(0, 9)
			var a1 = put(game, "smelter", c3, 0)
			var a2 = put(game, "smelter", c3 + Vector2i(a1.size, 0), 0)
			var rid := "smelt_iron"
			var rin2: Dictionary = DB.data.recipes[rid].get("in", {})
			var ore: String = rin2.keys()[0]
			a2.inv.add(ore, int(rin2[ore]))
			a2.recipe = rid
			f._crafter(a2, 0.01)
			var p_before: int = game.player.inv.count(ore)
			var tot_before: int = p_before + a1.inv.count(ore) + a2.inv.count(ore) + (int(rin2[ore]) if a2.crafting != "" else 0)
			fz.fuse_level(a1, a2)
			var tot_after: int = game.player.inv.count(ore) + a1.inv.count(ore) + (int(rin2[ore]) if a1.crafting != "" else 0)
			print("HUNT fuse_level crafting=", a2.crafting, " ore_total before=", tot_before, " after=", tot_after, " lvl=", a1.lvl)
			game.flags.erase("free_build")
			print("TEST duelA_fuse115 done")
		"duelA_flow115":
			game._apply_sizes(true)
			DB.data.settings["ports18"] = {"on": true}
			var f = game.factory
			var w = game.world
			game.flags["free_build"] = true
			var res := []
			for d in 4:
				var D: Vector2i = f.DIRS[d]
				var P: Vector2i = f.DIRS[(d + 1) % 4]
				var F: Vector2i = f.hq.cell + Vector2i(-40 + d * 0, 0) + Vector2i(0, 0)
				var found := false
				for att in 400:
					F = f.hq.cell + Vector2i(randi_range(-90, 90), randi_range(-90, 90))
					var okc := true
					for dx in range(-9, 11):
						for dz in range(-9, 11):
							var cc := World.wc(F + Vector2i(dx, dz))
							w.remove_node(cc)
							if f.can_place("belt", cc) != "":
								okc = false
					if okc and f.can_place("furnace", F) == "" and f.can_place("chest", F + Vector2i(-8, 0)) == "":
						found = true
						break
				if not found:
					print("HUNT no spot d=", d)
					continue
				var lay: Dictionary = f.port_layout("furnace", F, d)
				var fu = put(game, "furnace", F, d)
				fu.fuel.add("coal", 50)
				var pin: Vector2i = lay["in"][0]
				var pout: Vector2i = lay.out[0]
				var seq := ["belt", "lift_mk1", "belt", "mole_junction", "belt", "belt_mk2"]
				var placed := []
				for k in seq.size():
					var bl = put(game, seq[k], pin - D * k, d)
					placed.append(bl)
				# crossing line through junction
				var jc: Vector2i = pin - D * 3
				for k in [-2, -1, 1, 2]:
					put(game, "belt", jc + P * k, (d + 1) % 4)
				var src = put(game, "chest", pin - D * seq.size(), d)
				if src == null:
					print("HUNT src null why=", f.can_place("chest", pin - D * seq.size()), " placed=", placed.map(func(q): return q.type if q else "null"))
					continue
				src.inv.add("iron_ore", 30)
				var oseq := ["belt", "splitter", "belt", "merger", "belt"]
				for k in oseq.size():
					placed.append(put(game, oseq[k], pout + D * k, d))
				var dst = put(game, "chest", pout + D * oseq.size(), d)
				var nulls := placed.filter(func(q): return q == null).size()
				for i in 25 * 60:
					f._tick(f.TICK)
				var info := {"d": d, "nulls": nulls, "src_left": src.inv.count("iron_ore"), "fu_in": fu.inv.count("iron_ore"), "fu_out": fu.out.count("iron_ingot"), "dst": dst.inv.count("iron_ingot"),
					"chain": placed.map(func(q): return "%s:%s>%s" % [q.type, q.item, q.next.type if q and q.next else "-"] if q else "null")}
				res.append(info)
				print("HUNT flow ", JSON.stringify(info))
			game.flags.erase("free_build")
			print("TEST duelA_flow115 done")
		"duelA_misc115":
			game._apply_sizes(true)
			DB.data.settings["ports18"] = {"on": true}
			var f = game.factory
			var w = game.world
			var spot := func(t: String, n: int) -> Vector2i:
				for att in 600:
					var F: Vector2i = f.hq.cell + Vector2i(randi_range(-80, 80), randi_range(-80, 80))
					var okc := true
					for dx in range(-2, n + 2):
						for dz in range(-2, 4):
							var cc := World.wc(F + Vector2i(dx, dz))
							w.remove_node(cc)
							if f.can_place("belt", cc) != "":
								okc = false
					if okc and f.can_place(t, F) == "" and f.can_place(t, F + Vector2i(n, 0)) == "":
						return F
				return Vector2i(-1, -1)
			# 1) upgrade of a fused (lvl 2) smelter
			var F: Vector2i = spot.call("smelter", 3)
			var give := func(t: String, k: int):
				var cst: Dictionary = game._scaled_cost(t)
				for it in cst:
					f.hq.inv.add(it, int(cst[it]) * k)
			give.call("smelter", 2)
			var a = game.cmd("place", {"type": "smelter", "cell": F, "dir": 0})
			var b = game.cmd("place", {"type": "smelter", "cell": F + Vector2i(a.size, 0), "dir": 0})
			game.cmd("fuse", {"a": a, "b": b, "kind": "level"})
			a.cfg["clock"] = 50.0
			a.cfg["off"] = true
			print("HUNT fused lvl=", a.lvl, " paid=", a.paid)
			give.call("smelter_mk2", 1)
			var keys := ["iron_ingot", "concrete", "gear", "steel", "circuit", "motor"]
			var before := {}
			for k in keys:
				before[k] = f.available(k)
			var u = game.cmd("place", {"type": "smelter_mk2", "cell": a.cell, "dir": 0})
			var after := {}
			for k in keys:
				after[k] = f.available(k) - before[k]
			print("HUNT upgrade type=", u.type if u else null, " lvl=", u.lvl if u else -1, " mult=", u.mult if u else -1, " paid=", u.paid if u else null, " cfg=", u.cfg if u else null, " delta=", after)
			# 2) R over a 2x2 building
			var F2: Vector2i = spot.call("smelter", 3)
			game.flags["free_build"] = true
			var s2 = put(game, "smelter", F2, 0)
			var ch = put(game, "chest", F2 + Vector2i(4, 0), 0)
			game.flags.erase("free_build")
			game.build_type = ""
			game.hover_cell = s2.cell
			game._action("rotate")
			var s2d: int = s2.dir
			game.hover_cell = ch.cell
			game._action("rotate")
			print("HUNT rotate R: smelter(size ", s2.size, ") dir 0->", s2d, "  chest(size ", ch.size, ") dir 0->", ch.dir)
			# 3) meteor on water
			var wc0 := Vector2i(-1, -1)
			for r in range(0, 200):
				for k in 40:
					var cc: Vector2i = World.wc(f.hq.cell + Vector2i(randi_range(-r, r), randi_range(-r, r)))
					if w.water_at(cc) and not w.nodes.has(cc):
						wc0 = cc
						break
				if wc0.x >= 0:
					break
			if wc0.x >= 0:
				game.events.meteor_land(wc0)
				print("HUNT meteor on water cell=", wc0, " node=", w.nodes.get(wc0).res if w.nodes.has(wc0) else "none")
			print("TEST duelA_misc115 done")
		"duelA_rt115":
			game._apply_sizes(true)
			DB.data.settings["ports18"] = {"on": true}
			var f = game.factory
			var w = game.world
			game.flags["free_build"] = true
			var base: Vector2i = f.hq.cell + Vector2i(-60, -60)
			var i := 0
			var placed := 0
			for T in DB.data.buildings:
				var beh := str(DB.data.buildings[T].get("behavior", ""))
				if beh in ["vehicle", "foundation", "hq"] or T in ["star_gate", "ufo_pad"]:
					continue
				var bb = null
				for att in 6:
					var c: Vector2i = base + Vector2i((i % 18) * 7, (i / 18) * 7)
					i += 1
					for dx in range(-1, 6):
						for dz in range(-1, 6):
							w.remove_node(World.wc(c + Vector2i(dx, dz)))
					if f.can_place(T, c) == "":
						bb = put(game, T, c, (i % 4))
						break
				if bb == null:
					continue
				placed += 1
				bb.cfg["clock"] = 70.0
				if bb.beh == "crafter":
					var rs: Array = DB.recipes_for(str(bb.p("station", "")))
					if not rs.is_empty():
						bb.recipe = rs[0]
						for k in DB.data.recipes[rs[0]].get("in", {}):
							if not DB.is_fluid(k):
								bb.inv.add(k, 1)
					if bb.fuel != null:
						bb.fuel.add("coal", 3)
					bb.out.add("stone", 2)
				elif bb.inv != null:
					f.accept(bb, "stone", null)
					f.accept(bb, str(bb.p("ammo", "stone")), null)
				if bb.fuel != null and bb.beh != "crafter":
					bb.fuel.add("coal", 3)
				if bb.beh == "battery":
					bb.energy = 123.0
				if bb.beh == "belt":
					f.set_item(bb, "stone")
				if bb.beh == "hq_link":
					bb.cfg["mode"] = "take"
					bb.cfg["items"] = ["stone"]
				if f.fz.can_level(bb) and i % 3 == 0:
					f.fz.set_level(bb, 3)
			game.flags.erase("free_build")
			var snap := func() -> Dictionary:
				var out := {}
				for b in f.all:
					if b == f.hq or b.dead:
						continue
					var inv := {}
					for k in ["inv", "out", "fuel"]:
						var iv = b.get(k)
						inv[k] = [iv.totals(), iv.size()] if iv != null else null
					out["%s@%d,%d" % [b.type, b.cell.x, b.cell.y]] = {"dir": b.dir, "lvl": b.lvl, "mult": b.mult, "recipe": b.recipe, "cfg": JSON.stringify(b.cfg), "inv": JSON.stringify(inv), "item": b.item,
						"energy": snappedf(b.energy, 0.1), "maxhp": snappedf(b.maxhp, 0.1), "hp": snappedf(b.hp, 0.1), "pin": str(b.pin), "pout": str(b.pout), "pow_ov": b.pow_ov, "subs": b.subs.size(), "paid": JSON.stringify(b.paid), "blk": b.blk, "y": snappedf(b.y, 0.01)}
				return out
			var s1: Dictionary = snap.call()
			var data = JSON.parse_string(JSON.stringify(game.save_dict()))
			for b in f.all.duplicate():
				if b != f.hq:
					f.remove(b)
			game.load_game(data)
			var s2: Dictionary = snap.call()
			var diffs := 0
			for k in s1:
				if not s2.has(k):
					print("HUNT rt missing ", k)
					diffs += 1
					continue
				for fld in s1[k]:
					if str(s1[k][fld]) != str(s2[k][fld]):
						print("HUNT rt diff ", k, " ", fld, ": ", s1[k][fld], " -> ", s2[k][fld])
						diffs += 1
			print("HUNT rt placed=", placed, " diffs=", diffs)
			print("TEST duelA_rt115 done")
		"duelA_thr115":
			game._apply_sizes(true)
			DB.data.settings["ports18"] = {"on": true}
			var f = game.factory
			var w = game.world
			game.flags["free_build"] = true
			var BT := OS.get_environment("BT") if OS.get_environment("BT") != "" else "belt_mk5"
			var mids := [BT, "splitter", "merger", "mole_junction"]
			var rows := []
			var y0 := 0
			for m in mids:
				var c: Vector2i
				var found := false
				for att in 800:
					c = f.hq.cell + Vector2i(randi_range(-90, 90), randi_range(-90, 90))
					var ok := true
					for dx in range(-1, 15):
						for dz in range(-1, 2):
							w.remove_node(World.wc(c + Vector2i(dx, dz)))
							if f.can_place("belt", World.wc(c + Vector2i(dx, dz))) != "":
								ok = false
					if ok and f.can_place("chest", c) == "" and f.can_place("chest", c + Vector2i(13, 0)) == "" and f.can_place(m, c + Vector2i(6, 0)) == "":
						found = true
						break
				if not found:
					print("HUNT nospot ", m)
					continue
				var src = put(game, "chest", c, 0)
				src.inv.resize(64)
				src.inv.add("stone", 3000)
				for k in range(1, 13):
					put(game, m if k == 6 else BT, c + Vector2i(k, 0), 0)
				var dst = put(game, "chest", c + Vector2i(13, 0), 0)
				dst.inv.resize(64)
				rows.append([m, src, dst])
			for i in 25 * 10:
				f._tick(f.TICK)
			var n0 := {}
			for r in rows:
				n0[r[0]] = r[2].inv.count("stone")
			for i in 25 * 60:
				f._tick(f.TICK)
			for r in rows:
				print("HUNT thr mid=", r[0], " per_min=", r[2].inv.count("stone") - n0[r[0]])
			game.flags.erase("free_build")
			print("TEST duelA_thr115 done")
		"duelA_ui115":
			game._apply_sizes(true)
			DB.data.settings["ports18"] = {"on": true}
			var f = game.factory
			var w = game.world
			game.flags["free_build"] = true
			var base: Vector2i = f.hq.cell + Vector2i(-60, -60)
			var i := 0
			var bl := []
			for T in DB.data.buildings:
				var beh := str(DB.data.buildings[T].get("behavior", ""))
				if beh in ["vehicle"]:
					continue
				var bb = null
				for att in 6:
					var c: Vector2i = base + Vector2i((i % 18) * 7, (i / 18) * 7)
					i += 1
					for dx in range(-1, 6):
						for dz in range(-1, 6):
							w.remove_node(World.wc(c + Vector2i(dx, dz)))
					if f.can_place(T, c) == "":
						bb = put(game, T, c, (i % 4))
						break
				if bb != null:
					bl.append(bb)
			# composites
			var hc: Vector2i = base + Vector2i(0, 7 * 12)
			for dx in range(-1, 12):
				for dz in range(-1, 6):
					w.remove_node(World.wc(hc + Vector2i(dx, dz)))
			var host = put(game, "assembler", hc, 0)
			if host:
				for t in ["furnace", "gatling_turret", "chest", "battery_block"]:
					var m = put(game, t, hc + Vector2i(host.size, 0), 0)
					if m:
						f.fz.fuse_combo(host, m)
				bl.append(host)
			print("HUNT ui buildings=", bl.size())
			var n := 0
			for b in bl:
				if b.dead:
					continue
				print("HUNT ui open ", b.type)
				game.hud.open_building(b)
				await tree.process_frame
				await tree.process_frame
				game.hud.close_all()
				n += 1
			print("HUNT ui opened=", n)
			print("TEST duelA_ui115 done")
		"duelA_m2115":
			game._apply_sizes(true)
			DB.data.settings["ports18"] = {"on": true}
			var f = game.factory
			var w = game.world
			game.flags["free_build"] = true
			var spot := func(n: int) -> Vector2i:
				for att in 800:
					var F: Vector2i = f.hq.cell + Vector2i(randi_range(-80, 80), randi_range(-80, 80))
					var okc := true
					for dx in range(-1, n + 1):
						for dz in range(-1, 4):
							var cc := World.wc(F + Vector2i(dx, dz))
							w.remove_node(cc)
							if f.can_place("belt", cc) != "" or f.can_place("smelter", cc) != "":
								okc = false
					if okc:
						return F
				return Vector2i(-1, -1)
			# H5: upgrade a lvl3 smelter with full out/inv
			var F: Vector2i = spot.call(8)
			var a = put(game, "smelter", F, 0)
			f.fz.set_level(a, 3)
			a.recipe = "smelt_iron"
			var put_out := 0
			while a.out.can_add("iron_ingot", 1):
				a.out.add("iron_ingot", 1)
				put_out += 1
			var put_in := 0
			while a.inv.can_add("iron_ore", 1) and put_in < 1000:
				a.inv.add("iron_ore", 1)
				put_in += 1
			var p0: int = game.player.inv.count("iron_ingot") + f.hq.inv.count("iron_ingot")
			var po0: int = game.player.inv.count("iron_ore") + f.hq.inv.count("iron_ore")
			var u = f.upgrade(a, "smelter_mk2")
			var kept_out: int = u.out.count("iron_ingot") + game.player.inv.count("iron_ingot") + f.hq.inv.count("iron_ingot") - p0
			var kept_in: int = u.inv.count("iron_ore") + game.player.inv.count("iron_ore") + f.hq.inv.count("iron_ore") - po0
			print("HUNT upgrade lvl3: out slots ", a.out.size(), "->", u.out.size(), " ingots ", put_out, "->", kept_out, " | inv slots ", a.inv.size(), "->", u.inv.size(), " ore ", put_in, "->", kept_in)
			# H1: lamp fused into composite
			var F2: Vector2i = spot.call(6)
			var h = put(game, "assembler", F2, 0)
			var lamp = put(game, "lamp", F2 + Vector2i(h.size, 0), 0)
			var had: bool = lamp.light != null and lamp in f.lights
			var ok: bool = f.fz.fuse_combo(h, lamp)
			await tree.process_frame
			print("HUNT lamp fused ok=", ok, " light_before=", had, " light_after=", is_instance_valid(lamp.light) and lamp.light != null and not lamp.light.is_queued_for_deletion(), " in_lights=", lamp in f.lights)
			game.flags.erase("free_build")
			print("TEST duelA_m2115 done")
		"duelA_m3115":
			game._apply_sizes(true)
			DB.data.settings["ports18"] = {"on": true}
			var f = game.factory
			var w = game.world
			game.flags["free_build"] = true
			var F: Vector2i
			for att in 800:
				F = f.hq.cell + Vector2i(randi_range(-80, 80), randi_range(-80, 80))
				var okc := true
				for dx in range(-1, 9):
					for dz in range(-1, 4):
						var cc := World.wc(F + Vector2i(dx, dz))
						w.remove_node(cc)
						if f.can_place("belt", cc) != "" or f.can_place("smelter", cc) != "":
							okc = false
				if okc:
					break
			var h = put(game, "furnace", F, 0)
			var ch = put(game, "chest", F + Vector2i(-1, 0), 0)
			if ch == null:
				ch = put(game, "chest", F + Vector2i(0, -1), 0)
			print("HUNT combo=", f.fz.fuse_combo(h, ch), " subs=", h.subs.map(func(q): return q.type))
			h.recipe = "smelt_iron"
			h.fuel.add("coal", 20)
			h.inv.add("iron_ore", 10)
			h.cfg["out_items"] = ["copper_ingot"]
			var ob = put(game, "belt", h.pout[0], h.pout_side[0])
			var ob2 = put(game, "belt", h.pout[0] + f.DIRS[h.pout_side[0]], h.pout_side[0])
			var sink = put(game, "chest", h.pout[0] + f.DIRS[h.pout_side[0]] * 2, h.pout_side[0])
			for i in 25 * 60:
				f._tick(f.TICK)
			var chest_sub = f.fz.chest_of(h)
			print("HUNT out filter=[copper_ingot]: iron_ingot in sub-chest=", chest_sub.inv.count("iron_ingot"), " on belts/sink=", sink.inv.count("iron_ingot") + (1 if ob.item == "iron_ingot" else 0) + (1 if ob2.item == "iron_ingot" else 0), " host.out=", h.out.count("iron_ingot"))
			game.flags.erase("free_build")
			print("TEST duelA_m3115 done")
		"duelA_m4115":
			DB.data.settings["mastery"] = {"enabled": true}
			DB.data.settings["daily"] = {"enabled": true}
			var f = game.factory
			game.flags["free_build"] = true
			var dc: Vector2i = nearest_deposit(game, "iron_ore", f.hq.cell)
			var mn = put(game, "miner", dc, 0)
			var sm = put_near(game, "smelter", f.hq.cell + Vector2i(10, 10), 0)
			sm.recipe = "smelt_iron"
			game.flags.erase("free_build")
			var P = game.progress17
			P.daily = {"item": mn.recipe if mn else "iron_ore", "need": 50, "have": 0, "day": int(game.day_n), "done": false, "reward": 10}
			P._syn_t = 5.0
			P.update(0.1)
			print("HUNT daily=", P.daily.item, " miner=", mn != null, " miner_focus=", mn.bstate.get("focus", 0.0) if mn else -1, " k_miner=", Progress17.k(mn) if mn else -1)
			P.daily = {"item": "iron_ingot", "need": 50, "have": 0, "day": int(game.day_n), "done": false, "reward": 10}
			P._syn_t = 5.0
			P.update(0.1)
			print("HUNT daily=iron_ingot smelter_focus=", sm.bstate.get("focus", 0.0), " k_smelter=", Progress17.k(sm))
			print("TEST duelA_m4115 done")
		"duelA_m5115":
			var f = game.factory
			var w = game.world
			game.flags["free_build"] = true
			var c: Vector2i = f.hq.cell + Vector2i(6, 4)
			for dx in range(-3, 4):
				for dz in range(-3, 4):
					w.remove_node(World.wc(c + Vector2i(dx, dz)))
			var ln = put_near(game, "hq_link", c, 0)
			f._rebuild_power()
			f._power(0.05)
			var d0: int = int(game._delivered_total())
			var h0: int = f.hq.inv.count("stone")
			var acc := 0
			for k in 20:
				if f.accept(ln, "stone", null):
					acc += 1
			print("HUNT link accepted=", acc, " hq_stone_delta=", f.hq.inv.count("stone") - h0, " delivered_delta=", int(game._delivered_total()) - d0)
			# contract c_miners with fused miners
			var d1: Vector2i = nearest_deposit(game, "iron_ore", f.hq.cell)
			var m1 = put(game, "miner", d1, 0)
			var m2 = null
			for off in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
				m2 = put(game, "miner", d1 + off, 0)
				if m2 != null:
					break
			var tc = game.tech
			var p0: Array = tc.c_progress("c_miners") if tc.contracts().has("c_miners") else []
			var ok := false
			if m1 != null and m2 != null:
				ok = f.fz.fuse_level(m1, m2)
			var p1: Array = tc.c_progress("c_miners") if tc.contracts().has("c_miners") else []
			print("HUNT c_miners before=", p0, " fused=", ok, " lvl=", m1.lvl if m1 else -1, " after=", p1)
			game.flags.erase("free_build")
			print("TEST duelA_m5115 done")
		"duelA_m6115":
			var f = game.factory
			var w = game.world
			var c: Vector2i = f.hq.cell + Vector2i(10, 8)
			for dx in range(-3, 8):
				for dz in range(-3, 6):
					w.remove_node(World.wc(c + Vector2i(dx, dz)))
			var types := ["assembler", "furnace", "chest", "battery_block"]
			for t in types:
				var cst: Dictionary = game._scaled_cost(t)
				for it in cst:
					f.hq.inv.add(it, int(cst[it]) * 3)
			var h = game.cmd("place", {"type": "assembler", "cell": c, "dir": 0})
			for t in types.slice(1):
				var m = game.cmd("place", {"type": t, "cell": c + Vector2i(h.size, 0), "dir": 0})
				if m:
					game.cmd("fuse", {"a": h, "b": m, "kind": "combo"})
			print("HUNT composite subs=", h.subs.map(func(q): return [q.type, q.paid]))
			var all_items := {}
			for t in types:
				for it in game._scaled_cost(t):
					all_items[it] = true
			var tot := func() -> int:
				var s := 0
				for it in all_items:
					s += f.available(it)
				return s
			f.damage(h, 1e9)
			print("HUNT destroyed dead=", h.dead, " ruins=", game.builders.ruins.size())
			var t0: int = tot.call()
			var nb = game.cmd("repair", {"cell": c})
			var t1: int = tot.call()
			print("HUNT repaired=", nb != null and not (nb is bool), " subs=", nb.subs.map(func(q): return [q.type, q.paid]) if nb and not (nb is bool) else [], " host paid=", nb.paid if nb and not (nb is bool) else null, " repair spent=", t0 - t1)
			if nb and not (nb is bool):
				game.cmd("demolish", {"cell": nb.cell})
			var t2: int = tot.call()
			print("HUNT demolish refund=", t2 - t1, " net gain over repair+demolish=", t2 - t0)
			print("TEST duelA_m6115 done")
		"duelA_m7115":
			var f = game.factory
			if OS.get_environment("CLK") != "":
				DB.data.settings["fuses"] = false
			var w = game.world
			game.flags["free_build"] = true
			var rows := []
			for lv in [1, 3]:
				var c: Vector2i = f.hq.cell + (Vector2i(40, 0) if lv == 1 else Vector2i(-40, 0))
				for dx in range(-4, 8):
					for dz in range(-4, 8):
						w.remove_node(World.wc(c + Vector2i(dx, dz)))
				var g = put_near(game, "generator", c, 0)
				if OS.get_environment("CLK") != "" and lv == 3:
					g.cfg["clock"] = float(OS.get_environment("CLK"))
				else:
					f.fz.set_level(g, lv)
				g.fuel.add("coal", 50)
				var heaters := []
				for k in 12:
					var hh = put_near(game, "heater", c + Vector2i(4, 0), 0)
					if hh:
						heaters.append(hh)
				rows.append([lv, g, heaters])
			game.flags.erase("free_build")
			f.auto_wire_all()
			f.power_dirty = true
			var c0 := []
			for r in rows:
				c0.append(r[1].fuel.count("coal"))
			var sup := [0.0, 0.0]
			for i in 25 * 60:
				f._tick(f.TICK)
				for j in rows.size():
					var g2 = rows[j][1]
					if g2.net >= 0:
						sup[j] += f.nets[g2.net].supply * f.TICK
			for j in rows.size():
				var g3 = rows[j][1]
				var burned: float = (c0[j] - g3.fuel.count("coal")) * f.burn_time(g3, "coal") - g3.fuel_t
				print("HUNT gen lvl=", rows[j][0], " mult=", g3.mult, " heaters=", rows[j][2].size(), " coal used=", c0[j] - g3.fuel.count("coal"), " fuel-seconds burned=", snappedf(burned, 0.1), " supply/s=", f.nets[g3.net].supply if g3.net >= 0 else -1, " demand/s=", f.nets[g3.net].demand if g3.net >= 0 else -1, " sat=", f.nets[g3.net].sat if g3.net >= 0 else -1)
			print("TEST duelA_m7115 done")
		"duelA_m8115":
			game._apply_sizes(true)
			DB.data.settings["ports18"] = {"on": true}
			var f = game.factory
			var tc = game.tech
			var BT := "exotic_forge"
			tc.done.erase("t_quantum2")
			tc.refresh_locks()
			Factory._pc_rev = -1
			var rev0: int = DB.revision
			game.flags["free_build"] = true
			var a = put_near(game, BT, f.hq.cell + Vector2i(14, 0), 0)
			print("HUNT before t_quantum2: quantum_core locked=", DB.locked.has("r:quantum_core"), " port_counts=", Factory.port_counts(BT), " forge A pins=", a.pin.size())
			tc.unlock("t_quantum2")
			var b = put_near(game, BT, f.hq.cell + Vector2i(-14, 0), 0)
			print("HUNT after t_quantum2: locked=", DB.locked.has("r:quantum_core"), " DB.revision changed=", DB.revision != rev0, " port_counts=", Factory.port_counts(BT), " new forge B pins=", b.pin.size(), " old A pins=", a.pin.size())
			Factory._pc_rev = -1
			print("HUNT after cache reset (restart/load): port_counts=", Factory.port_counts(BT))
			# can a 2-input steel recipe be fed by belts to B?
			game.flags.erase("free_build")
			print("TEST duelA_m8115 done")
		"duelA_m9115":
			game._apply_sizes(true)
			DB.data.settings["ports18"] = {"on": true}
			var f = game.factory
			var tc = game.tech
			var orig = JSON.parse_string(FileAccess.get_file_as_string("res://core/settings.json"))
			DB.data.settings["scan"] = orig.get("scan", {})
			game.scanner.setup()
			# fresh-game tech: only start nodes
			for tid in tc.done.keys():
				if not bool(tc.nodes().get(tid, {}).get("start", false)):
					tc.done.erase(tid)
			tc.refresh_locks()
			Factory._pc_rev = -1
			print("HUNT discovery=", DB.discovery, " known=", DB.known.size(), " researched=", DB.researched.size())
			var crafters := []
			for T in DB.data.buildings:
				if str(DB.data.buildings[T].get("behavior", "")) == "crafter":
					crafters.append(T)
			var early := {}
			for T in crafters:
				early[T] = Factory.port_counts(T)[0]
			var rev0: int = DB.revision
			for id in DB.data.items:
				DB.known[id] = true
				DB.researched[id] = true
			tc.unlock_all()
			var cached := {}
			for T in crafters:
				cached[T] = Factory.port_counts(T)[0]
			Factory._pc_rev = -1
			var diff := []
			for T in crafters:
				var late: int = Factory.port_counts(T)[0]
				if late != early[T] or cached[T] != late:
					diff.append("%s: start=%d, after research (same session)=%d, after restart=%d" % [T, early[T], cached[T], late])
			print("HUNT revision changed=", DB.revision != rev0)
			for d in diff:
				print("HUNT ports ", d)
			print("TEST duelA_m9115 done")
		"duelA_m10115":
			var f = game.factory
			var w = game.world
			game.flags["free_build"] = true
			var c: Vector2i
			for att in 800:
				c = f.hq.cell + Vector2i(randi_range(-60, 60), randi_range(-60, 60))
				var ok := true
				for dx in range(-2, 6):
					for dz in range(-2, 3):
						w.remove_node(World.wc(c + Vector2i(dx, dz)))
						if f.can_place("belt", World.wc(c + Vector2i(dx, dz))) != "":
							ok = false
				if ok:
					break
			# tall stack: 3 tiers of found_tall at c+3
			var top := c + Vector2i(3, 0)
			for k in 3:
				f.place("found_tall", top, 0)
			var ch = put(game, "chest", top, 0)
			var bl = []
			for k in 3:
				bl.append(put(game, "belt", c + Vector2i(k, 0), 0))
			var src = put(game, "chest", c + Vector2i(-1, 0), 0)
			src.inv.add("stone", 10)
			for i in 25 * 20:
				f._tick(f.TICK)
			print("HUNT found top y=", ch.y if ch else -1, " ground belt y=", bl[2].y if bl[2] else -1, " belt.next=", bl[2].next.type if bl[2] and bl[2].next else null, " stone in raised chest=", ch.inv.count("stone") if ch else -1)
			game.flags.erase("free_build")
			print("TEST duelA_m10115 done")
		"endgame112":
			# 1.1.12: мидгейм и эндгейм — каждый рецепт каждой машины (все тиры) реально делается: сырьё внутрь, машина работает,
			# на выходе продукт. Плюс каждый генератор с каждым своим топливом даёт энергию.
			var f = game.factory
			game.flags["free_build"] = true
			game.tech.unlock_all()
			for rid in DB.data.recipes:
				var pid := str(DB.data.recipes[rid].get("pattern", ""))
				if pid != "":
					game.tech.patterns[pid] = true
			game.tech.refresh_locks()
			var hq: Vector2i = f.hq.cell
			var base: Vector2i = hq + Vector2i(-50, -60)
			var slot := 0
			var bad := []
			var ok_n := 0
			var total := 0
			var gens_ok := 0
			var via_belt := 0
			var spot := func(sz: int) -> Vector2i:
				var cell := Vector2i.ZERO
				var wet := true
				while wet:
					cell = base + Vector2i((slot % 10) * 8, (slot / 10) * 8)
					slot += 1
					wet = false
					for dx in range(-1, sz + 1):
						for dz in range(-1, sz + 1):
							wet = wet or game.world.water_at(World.wc(cell + Vector2i(dx, dz)))
				var lv: float = game.world.h_cell(cell)
				for k in 2:
					game.world.paint_height(cell + Vector2i(sz / 2, sz / 2), float(sz + 3), "flatten", 1.0, lv)
				for dx in range(-1, sz + 1):
					for dz in range(-1, sz + 1):
						var cc := World.wc(cell + Vector2i(dx, dz))
						game.world.remove_node(cc)
						var o = f.building_at(cc)
						if o != null and o != f.hq:
							f.remove(o)
				return cell
			for t in DB.data.buildings:
				var d := DB.building(t)
				if str(d.get("behavior", "")) != "crafter" or not bool(d.get("params", {}).get("buildable", true)):
					continue
				var pr: Dictionary = d.params
				var pw0 = pr.get("power", 0)
				pr["power"] = 0   # энергия проверяется отдельно — здесь только рецепты
				for rid in DB.recipes_for(str(pr.get("station", t))):
					var r: Dictionary = DB.data.recipes[rid]
					total += 1
					var cell: Vector2i = spot.call(int(d.get("size", 1)))
					var b = put(game, t, cell, 0)
					if b == null:
						bad.append("%s/%s: не встало (%s)" % [t, rid, f.can_place(t, cell)])
						continue
					f.set_recipe(b, rid)
					# твёрдое сырьё — с ленты по очереди (как в игре: проверяется, что машина не забивается одним сырьём), жидкое — как по трубе
					var feed = null
					if b.pon and not b.pin.is_empty():
						feed = put(game, "belt", b.pin[0], (b.pin_side[0] + 2) % 4)
						if feed != null:
							via_belt += 1
					var want := {}
					for k in r.get("in", {}):
						if DB.is_fluid(k) or feed == null:
							if b.inv.add(k, int(r["in"][k])) > 0:
								bad.append("%s/%s: не влезло сырьё %s" % [t, rid, k])
						else:
							want[k] = int(r["in"][k]) * 2
					var guard := 0
					while not want.is_empty() and guard < 5000:
						guard += 1
						for k in want.keys():
							if f.accept(b, k, feed):
								want[k] -= 1
								if want[k] <= 0:
									want.erase(k)
							else:
								if b.inv.count(k) < int(r["in"][k]):
									bad.append("%s/%s: с ленты не берёт %s (внутри %s)" % [t, rid, k, b.inv.totals()])
								want.erase(k)
					if b.fuel != null:
						b.fuel.add("coal", 20)
					var tm: float = float(r.get("time", 1.0)) / maxf(0.05, float(pr.get("speed", 1.0)))
					var steps: int = int(tm / Factory.TICK * 1.6) + 20
					for i in mini(steps, 20000):
						f._tick(Factory.TICK)
						var done_all := true
						for o in r.get("out", {}):
							done_all = done_all and b.out != null and b.out.count(o) >= int(r["out"][o])
						if done_all:
							break
					var got := true
					for o in r.get("out", {}):
						got = got and b.out != null and b.out.count(o) >= int(r["out"][o])
					if got:
						ok_n += 1
					else:
						bad.append("%s/%s: нет продукта (crafting=%s inv=%s out=%s)" % [t, rid, b.crafting, b.inv.totals(), b.out.totals() if b.out else {}])
					if feed != null:
						f.remove(feed)
					f.remove(b)
				pr["power"] = pw0
			# генераторы на топливе
			var gen_bad := []
			for t in DB.data.buildings:
				var d := DB.building(t)
				if str(d.get("behavior", "")) != "generator":
					continue
				var fl = d.get("params", {}).get("fuels", [])
				if not (fl is Array) or fl.is_empty():
					continue
				for fuel in fl:
					if DB.is_fluid(str(fuel)):
						continue
					var cell: Vector2i = spot.call(int(d.get("size", 1)) + 3)
					var g = put(game, t, cell, 0)
					if g == null or g.fuel == null:
						gen_bad.append("%s: не встал" % t)
						break
					var acc: bool = f.accept(g, str(fuel), null)
					var lmp = put(game, "constructor", cell + Vector2i(int(d.get("size", 1)) + 1, 0), 0)
					f.auto_wire_all()
					f.power_dirty = true
					for i in 40:
						f._tick(Factory.TICK)
					var ni: Dictionary = f.net_info(g)
					var sup: float = maxf(float(ni.get("supply", 0.0)), float(ni.get("gen_max", 0.0)))
					var burns: bool = g.fuel_t > 0.0 or g.fuel.count(str(fuel)) == 0 or bool(g.p("reactor", false))
					if not acc or sup <= 0.0 or not burns:
						gen_bad.append("%s+%s: accept=%s supply=%s burns=%s demand=%s lamp_net=%s gnet=%s" % [t, fuel, acc, sup, burns, ni.get("demand"), lmp.net if lmp else -9, g.net])
					else:
						gens_ok += 1
					if lmp != null:
						f.remove(lmp)
					f.remove(g)
			print("TEST endgame112 recipes=", ok_n, "/", total, " via_belt=", via_belt, " generators_ok=", gens_ok, " bad=", bad, " gen_bad=", gen_bad, " ", "OK" if bad.is_empty() and gen_bad.is_empty() and total > 150 and via_belt > total / 2 else "FAIL")
		"v19":
			# 1.1.9: порты зданий — один выход, входов по числу видов сырья; ленты только к портам; порты видны; призрак;
			# карточка обучения без пустого места; окна не «дышат»
			var f = game.factory
			game.flags["free_build"] = true
			var pc_ok: bool = Factory.port_counts("furnace") == [2, 1] and Factory.port_counts("smelter") == [2, 1] \
				and Factory.port_counts("assembler") == [3, 1] and Factory.port_counts("miner") == [0, 1] and Factory.port_counts("hq") == [-1, -1]
			var ml: Dictionary = Factory.port_layout("miner", Vector2i(10, 10), 0)
			var miner_ok: bool = ml.out.size() == 1 and ml["in"].is_empty()
			var c: Vector2i = f.hq.cell + Vector2i(12, -16)
			for dx in range(-8, 16):
				for dz in range(-8, 16):
					game.world.remove_node(World.wc(c + Vector2i(dx, dz)))
			var sm = put(game, "smelter", c, 0)
			var lay_ok := false
			var feed_ok := false
			var side_blocked := false
			var out_ok := false
			var vis_ok := false
			if sm != null:
				var sz: int = sm.size
				lay_ok = sm.pon and sm.pin.size() == 2 and sm.pout.size() == 1 and sm.pin_side == [2, 2] and sm.pout_side == [0]
				# лента у входа — принимает; лента сбоку (не порт) — нет
				var ib = put(game, "belt", sm.pin[0], 0)
				feed_ok = ib != null and f.accept(sm, "iron_ore", ib)
				var side_c: Vector2i = World.wc(sm.cell + Vector2i(0, -1))
				var sb = put(game, "belt", side_c, 1)
				side_blocked = sb != null and not f.accept(sm, "iron_ore", sb)
				# выход один: лента у выхода стала next
				var ob = put(game, "belt", sm.pout[0], 0)
				out_ok = ob != null and sm.next == ob and sm.nexts.is_empty()
				vis_ok = f.socket_keys.get(sm, []).size() == 3
			# призрак: стрелки ровно у портов
			game.select_build("smelter")
			game.build_dir = 1
			game._ghost_ports()
			var arrows: int = game.ghost.get_node("ports").get_child_count() if game.ghost != null else -1
			game.cancel_build()
			var ghost_ok: bool = arrows == 3
			# карточка обучения: ошибочно большой замер не держится — через секунду карточка по тексту
			var T = game.tutorial
			T.active = true
			T.done = false
			T.step = 3
			T._enter()
			T.card.visible = true
			await tree.process_frame
			T._card_h = 2000.0
			var t0 := Time.get_ticks_msec()
			while Time.get_ticks_msec() - t0 < 1400:
				T._place()
				await tree.process_frame
			var need: float = T.card.get_child(0).get_combined_minimum_size().y
			var card_ok: bool = T.card.size.y < need + 40.0 and T.card.size.y < 900.0
			var card_h: float = T.card.size.y
			# окна не «дышат»: здание с работой, рюкзак, дерево, торговля — размер за 5 с не меняется
			var jit := {}
			if sm != null:
				sm.inv.add("iron_ore", 20)
				game.hud.open_building(sm)
			game.hud.open("inventory")
			var sizes := {}
			var t1 := Time.get_ticks_msec()
			var first := true
			while Time.get_ticks_msec() - t1 < 5000:
				for i in 3:
					f._tick(Factory.TICK)
				await tree.process_frame
				if Time.get_ticks_msec() - t1 < 800:
					continue
				for wid in ["building", "inventory"]:
					var w = game.hud.windows[wid]
					if not w.visible:
						continue
					if not sizes.has(wid):
						sizes[wid] = [w.size.y, w.size.y]
					sizes[wid][0] = minf(sizes[wid][0], w.size.y)
					sizes[wid][1] = maxf(sizes[wid][1], w.size.y)
			for wid in sizes:
				if sizes[wid][1] - sizes[wid][0] > 1.0:
					jit[wid] = sizes[wid]
			game.hud.close_all()
			T.skip()
			print("TEST v19 counts=", pc_ok, " miner_one_out=", miner_ok, " layout=", lay_ok, " feed=", feed_ok, " side_blocked=", side_blocked, " one_out=", out_ok,
				" sockets=", vis_ok, " ghost_arrows=", arrows, " card=", card_ok, " h=", card_h, " jitter=", jit, " ",
				"OK" if pc_ok and miner_ok and lay_ok and feed_ok and side_blocked and out_ok and vis_ok and ghost_ok and card_ok and jit.is_empty() and not sizes.is_empty() else "FAIL")
		"belts21":
			# 21: кротовина (лента через ленту), умный разделитель «руда прямо, уголь вправо», слёт с поворота и бортики
			var f = game.factory
			game.flags["free_build"] = true
			var c: Vector2i = f.hq.cell + Vector2i(10, -14)
			for dx in range(-5, 12):
				for dz in range(-5, 12):
					game.world.remove_node(World.wc(c + Vector2i(dx, dz)))
			# а) крест: ряд A слева направо, ряд B сверху вниз, в центре кротовина
			var jc: Vector2i = c + Vector2i(3, 3)
			var jn = put(game, "mole_junction", jc, 0)
			var a_in = []
			for k in 3:
				a_in.append(put(game, "belt", jc + Vector2i(-3 + k, 0), 0))
				put(game, "belt", jc + Vector2i(1 + k, 0), 0)
				a_in.append(put(game, "belt", jc + Vector2i(0, -3 + k), 1))
				put(game, "belt", jc + Vector2i(0, 1 + k), 1)
			var cha = put(game, "chest", jc + Vector2i(4, 0), 0)
			var chb = put(game, "chest", jc + Vector2i(0, 4), 0)
			var first_a = f.building_at(jc + Vector2i(-3, 0))
			var first_b = f.building_at(jc + Vector2i(0, -3))
			var fed := 0
			for step in int(30.0 / Factory.TICK):
				if fed < 20 and step % 10 == 0:
					if f.accept(first_a, "iron_ore", null) and f.accept(first_b, "coal", null):
						fed += 1
				f._tick(Factory.TICK)
			var cross_ok: bool = jn != null and cha != null and chb != null and cha.inv.count("iron_ore") >= 15 and cha.inv.count("coal") == 0 and chb.inv.count("coal") >= 15 and chb.inv.count("iron_ore") == 0
			# б) умный разделитель: руда прямо, уголь вправо, остальное влево
			var sc: Vector2i = c + Vector2i(0, 9)
			var sp = put(game, "smart_splitter", sc, 0)
			var fr = put(game, "chest", sc + Vector2i(1, 0), 0)
			var rt = put(game, "chest", sc + Vector2i(0, 1), 0)
			var lf = put(game, "chest", sc + Vector2i(0, -1), 0)
			game.cmd("bcfg", {"b": sp, "cfg": {"outs": {"0": {"mode": "items", "items": ["iron_ore"]}, "1": {"mode": "items", "items": ["coal"]}, "3": {"mode": "any", "items": []}}}})
			var mix := ["iron_ore", "coal", "stone", "iron_ore", "coal", "iron_ore"]
			for i in 18:
				var it: String = mix[i % mix.size()]
				var tries := 0
				while not f.accept(sp, it, null) and tries < 200:
					f._tick(Factory.TICK)
					tries += 1
			for step in 50:
				f._tick(Factory.TICK)
			var sort_ok: bool = fr.inv.count("iron_ore") == 9 and fr.inv.count("coal") == 0 and rt.inv.count("coal") == 6 and rt.inv.count("iron_ore") == 0 and lf.inv.count("stone") == 3 and lf.inv.count("iron_ore") + lf.inv.count("coal") == 0
			var seen_ok: bool = sp.bstate.get("seen", {}).has("coal")
			game.hud.bld = sp
			var vb := VBoxContainer.new()
			game.hud._smart_splitter_ui(vb)
			var ui_ok: bool = vb.get_child_count() >= 3
			vb.free()
			# в) слёт с поворота ленты Mk1 и бортики
			DB.data.settings["belt_spill_pct"] = 100.0
			var tc: Vector2i = c + Vector2i(6, 9)
			var b1 = put(game, "belt", tc, 0)
			var b2 = put(game, "belt", tc + Vector2i(1, 0), 1)   # поворот вниз
			var b3 = put(game, "belt", tc + Vector2i(1, 1), 1)
			var sink = put(game, "chest", tc + Vector2i(1, 2), 0)
			var s0 := int(f.stats.get("spilled", 0))
			for i in 4:
				while not f.accept(b1, "plank", null):
					f._tick(Factory.TICK)
			for step in 100:
				f._tick(Factory.TICK)
			var spilled := int(f.stats.get("spilled", 0)) - s0
			var drops_ok: bool = game.drops.list.size() > 0
			game.cmd("place", {"type": "belt_rails", "cell": b2.cell, "dir": 0})
			var rails_on: bool = b2.bstate.get("rails", false)
			var s1 := int(f.stats.get("spilled", 0))
			for i in 4:
				while not f.accept(b1, "plank", null):
					f._tick(Factory.TICK)
			for step in 100:
				f._tick(Factory.TICK)
			var after := int(f.stats.get("spilled", 0)) - s1
			var spill_ok: bool = b2 != null and b2.kind != 0 and spilled == 4 and drops_ok and rails_on and after == 0 and sink.inv.count("plank") == 4
			# дрон-сборщик подбирает слетевшее и везёт на склад
			await tree.create_timer(1.5).timeout
			DB.data.buildings["drone_station"].params["power"] = 0
			var dst_c: Vector2i = tc + Vector2i(4, -3)
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					game.world.remove_node(World.wc(dst_c + Vector2i(dx, dz)))
			var stn = put(game, "drone_station", dst_c, 0)
			game.drones.sync()
			var on_ground0: int = game.drops.list.size()
			for i in 600:
				game.drones.update(0.1)
			var picked: int = game.drones.stats_picked
			spill_ok = spill_ok and stn != null and picked >= 1
			print("TEST belts21_drone ground=", on_ground0, " picked=", picked)
			print("TEST belts21 cross=", cross_ok, " (A ", cha.inv.count("iron_ore") if cha else -1, "/", cha.inv.count("coal") if cha else -1, " B ", chb.inv.count("coal") if chb else -1, "/", chb.inv.count("iron_ore") if chb else -1, ") sort=", sort_ok,
				" (front ", fr.inv.count("iron_ore"), " right ", rt.inv.count("coal"), " left ", lf.inv.count("stone"), ") seen=", seen_ok, " ui=", ui_ok, " spilled=", spilled, " rails=", rails_on, " after=", after, " sink=", sink.inv.count("plank") if sink else -1, " ",
				"OK" if cross_ok and sort_ok and seen_ok and ui_ok and spill_ok else "FAIL")
		"smart_split":
			var c: Vector2i = game.factory.hq.cell + Vector2i(8, -8)
			var sp = put(game, "smart_splitter", c, 0)
			var front = put(game, "chest", c + Vector2i(1, 0), 0)
			var left = put(game, "chest", c + Vector2i(0, -1), 3)
			var right = put(game, "chest", c + Vector2i(0, 1), 1)
			game.cmd("bcfg", {"b": sp, "cfg": {"outs": {"0": {"mode": "rest"}, "3": {"mode": "items", "items": ["iron_ore"]}, "1": {"mode": "overflow"}}}})
			for i in 12:
				var it: String = "iron_ore" if i % 2 == 0 else "copper_ore"
				while not game.factory.accept(sp, it, null):
					await tree.create_timer(0.05).timeout
			await tree.create_timer(1.0).timeout
			var ok: bool = left.inv.count("iron_ore") == 6 and front.inv.count("copper_ore") == 6 and right.inv.count("iron_ore") + right.inv.count("copper_ore") == 0
			print("TEST smart_split left_iron=", left.inv.count("iron_ore"), " front_copper=", front.inv.count("copper_ore"), " front_iron=", front.inv.count("iron_ore"), " right=", right.inv.count("iron_ore") + right.inv.count("copper_ore"), " ", "OK" if ok else "FAIL")
		"fusion2":
			# 14.21: встроенной печи нужно топливо (лента / дрон / ящик), фильтр ящика, «лишнее», энергия ×уровень
			var f = game.factory
			var fz = f.fz
			game.flags["free_build"] = true
			for t in ["assembler", "miner"]:
				DB.data.buildings[t].params["power"] = 0   # энергия тут не проверяется (см. тест fusion)
			var hc: Vector2i = f.hq.cell
			# а) печь-основа без топлива стоит, с углём по «ленте» работает
			var c: Vector2i = hc + Vector2i(10, -8)
			for dx in range(-2, 4):
				for dz in range(-2, 4):
					game.world.remove_node(World.wc(c + Vector2i(dx, dz)))
			var fu = put(game, "furnace", c, 0)
			var asm = put(game, "assembler", c + Vector2i(1, 0), 0)
			var ch = put(game, "chest", c + Vector2i(0, 1), 0)
			f.set_recipe(asm, "iron_plate")
			fz.fuse_combo(fu, asm)
			fz.fuse_combo(fu, ch)
			fu.inv.add("iron_ore", 20)
			for step in int(20.0 / Factory.TICK):
				f._tick(Factory.TICK)
			var no_fuel: bool = ch.inv.count("iron_plate") == 0 and f.bottleneck(fu).contains("топлив")
			for i in 6:
				f.accept(fu, "coal", null)
			for step in int(60.0 / Factory.TICK):
				f._tick(Factory.TICK)
			var with_fuel: bool = ch.inv.count("iron_plate") >= 3
			# б) бур-основа + встроенная печь + ящик: уголь лентой уходит во встроенную печь; в ящике только слитки
			var ore: Vector2i = nearest_deposit(game, "iron_ore", hc + Vector2i(-6, 6))
			for dx in range(-2, 3):
				for dz in range(-2, 3):
					if Vector2i(dx, dz) != Vector2i.ZERO:
						game.world.remove_node(World.wc(ore + Vector2i(dx, dz)))
			var mi = put(game, "miner", ore, 0)
			var mf = null
			var mc = null
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if mf == null:
					mf = put(game, "furnace", ore + d, 0)
				elif mc == null:
					mc = put(game, "chest", ore + d, 0)
			var combo_ok: bool = mi != null and mf != null and mc != null and fz.fuse_combo(mi, mf) and fz.fuse_combo(mi, mc)
			var coal_in := 0
			for i in 5:
				if f.accept(mi, "coal", null):
					coal_in += 1
			var sub_fuel: bool = combo_ok and mf.fuel != null and mf.fuel.count("coal") == coal_in and coal_in == 5
			for step in int(90.0 / Factory.TICK):
				f._tick(Factory.TICK)
			var ingots: int = mc.inv.count("iron_ingot") if mc else 0
			var ore_in_chest: int = mc.inv.count("iron_ore") if mc else -1
			var filter_ok: bool = ingots > 0 and ore_in_chest == 0
			# «всё подряд» — руда тоже в ящик, когда печь занята
			game.cmd("bcfg", {"b": mi, "cfg": {"chest": "all"}})
			for i in mf.fuel.size():
				mf.fuel.slots[i] = null
			mf.fuel_t = 0.0
			for step in int(40.0 / Factory.TICK):
				f._tick(Factory.TICK)
			var all_mode: bool = mc.inv.count("iron_ore") > 0
			# только выбранное: ничего не выбрано → руда в ящик не идёт, бур встаёт; «уничтожать» — бур работает
			for i in mc.inv.size():
				mc.inv.slots[i] = null
			game.cmd("bcfg", {"b": mi, "cfg": {"chest": "list", "chest_items": ["iron_ingot"], "overflow": "trash"}})
			for step in int(60.0 / Factory.TICK):
				f._tick(Factory.TICK)
			var trash_ok: bool = mc.inv.count("iron_ore") == 0 and mi.trashed > 0
			# в) энергия: объединение ест ×уровень
			var m2 = put(game, "smelter", hc + Vector2i(-10, -8), 0)
			var m3 = put(game, "smelter", hc + Vector2i(-9, -8), 0)
			fz.fuse_level(m2, m3)
			var pw: float = float(m2.p("power", 0))
			var power_ok: bool = pw > 0.0 and is_equal_approx(Fusion.power_k(m2), 2.0)
			# г) режим «греется от энергии» (старый): топливо не нужно, если есть генератор
			DB.data.settings.fusion["furnace_fuel"] = "power"
			fu.has_gen = true
			var heat_ok: bool = Fusion.heats_by_power(fu)
			DB.data.settings.fusion["furnace_fuel"] = "fuel"
			heat_ok = heat_ok and not Fusion.heats_by_power(fu)
			# д) сохранение настроек ящика
			var sd: Dictionary = game.save_dict()
			game.load_game(sd)
			var lm = f.building_at(ore)
			var saved: bool = lm != null and str(lm.cfg.get("chest", "")) == "list" and lm.subs.size() == 2
			print("TEST fusion2 no_fuel=", no_fuel, " with_fuel=", with_fuel, " combo=", combo_ok, " sub_fuel=", sub_fuel, " ingots=", ingots, " ore_in_chest=", ore_in_chest,
				" all=", all_mode, " trash=", trash_ok, " power=", power_ok, " heat=", heat_ok, " saved=", saved, " ",
				"OK" if no_fuel and with_fuel and sub_fuel and filter_ok and all_mode and trash_ok and power_ok and heat_ok and saved else "FAIL")
		"bosses":
			# 14.23: босс в режиме «на штаб»: здание на пути ломает (раньше стоял), на героя рядом или ударившего — отвечает
			var f = game.factory
			var en = game.enemies
			game.flags["free_build"] = true
			game.flags["god"] = true
			var hq: Vector3 = f.hq.center()
			var c: Vector2i = f.hq.cell + Vector2i(18, 0)
			for dx in range(-6, 14):
				for dz in range(-6, 7):
					game.world.remove_node(World.wc(c + Vector2i(dx, dz)))
			var walls := []
			for dx in range(-3, 4):
				for dz in range(-3, 4):
					if maxi(absi(dx), absi(dz)) == 3:
						var wb = put(game, "wall", c + Vector2i(dx, dz), 0)
						if wb:
							walls.append(wb)
			game.player.position = hq + Vector3(-40, 0, 40)
			var boss = en.spawn("boss_titan", World.cell_to_world(c))
			var hp0 := 0.0
			for wb in walls:
				hp0 += wb.hp
			var attacked_wall := false
			for i in 600:
				boss.think_slot += 1   # кадр в тесте не меняется — иначе дальний монстр «думает через кадр» и пропускает все шаги
				en.update(0.05)
				var hp1 := 0.0
				for wb in walls:
					hp1 += wb.hp if not wb.dead else 0.0
				if hp1 < hp0 - 1.0:
					attacked_wall = true
					break
			for wb in walls:
				if not wb.dead:
					f.remove(wb)
			# герой бьёт босса — тот разворачивается к герою
			game.player.position = boss.pos + Vector3(0, 0, 7)
			en.hit(boss, 5.0, true)
			for i in 40:
				en.update(0.05)
			var on_player: bool = boss.target == game.player
			# герой рядом (без удара) — тоже замечает
			boss.player_hit_at = -99.0
			boss.target = f.hq
			game.player.position = boss.pos + Vector3(0, 0, 4)
			for i in 20:
				en.update(0.05)
			var sees: bool = boss.target == game.player
			game.player.position = hq + Vector3(-60, 0, 60)
			print("TEST bosses wall=", attacked_wall, " revenge=", on_player, " sees=", sees, " ", "OK" if attacked_wall and on_player and sees else "FAIL")
		"starworks":
			# 14.23: тонкая настройка, НЛО-торговля с плавающим курсом, узор 4×4, звёздные врата
			var f = game.factory
			var sw = game.star
			game.flags["free_build"] = true
			var c: Vector2i = f.hq.cell + Vector2i(-16, 14)
			for dx in range(-8, 14):
				for dz in range(-8, 10):
					game.world.remove_node(World.wc(c + Vector2i(dx, dz)))
			# 1) настройка: 50 — обычная работа, золотая зона — бонус, перегрев — износ
			DB.data.buildings["smelter"].params["power"] = 0
			var sm = put_near(game, "smelter", c)
			var neutral: float = Tuning.k(sm, "speed")
			var g: float = Tuning.center("heat")
			sm.cfg["tune"] = g
			var gold: float = Tuning.k(sm, "speed")
			sm.cfg["tune"] = 99.0
			var hp0: float = sm.hp
			sm.active = true
			Tuning.wear(f, 2.0)
			var worn: bool = sm.hp < hp0
			sm.cfg["tune"] = g
			var away: bool = absf(g - 50.0) >= float(Tuning.cfg().get("width", 12.0))
			var tune_ok: bool = is_equal_approx(neutral, 1.0) and gold > 1.2 and worn and away
			# лишний слиток: 200 плавок в золотой зоне дают больше 200
			sm.inv.add("iron_ore", 20)
			var made := 0
			for i in 3000:
				if sm.inv.count("iron_ore") < 5:
					sm.inv.add("iron_ore", 20)
				f._crafter(sm, 0.2)
				made += sm.out.count("iron_ingot")
				sm.out.slots = sm.out.slots.map(func(x): return null)
			var extra_ok: bool = made > 0
			# 2) НЛО
			var pad = put_near(game, "ufo_pad", c + Vector2i(8, 0))
			var s: Dictionary = Starworks.st(pad)
			var q1: Array = sw.quote("helium3", 1)
			var qs := {}
			for d in range(1, 8):
				qs[sw.quote("helium3", d)[1]] = true
			var swings: bool = qs.size() >= 3
			pad.inv.add("circuit", 1200)
			var cap := int(Starworks.ucfg().get("capacity", 1000))
			var left0: int = pad.inv.count("circuit")
			s.orders = [{"id": "helium3", "n": 2}]
			var r1: Dictionary = sw.trade(pad)
			var took: bool = int(r1.took.get("circuit", 0)) == mini(cap, left0) and pad.inv.count("circuit") == left0 - mini(cap, left0)
			var bought: bool = int(r1.bought.get("helium3", 0)) == 2 and float(s.balance) >= 0.0
			sw.trade(pad)
			var delivered: bool = pad.out.count("helium3") == 2
			# полёт: расписание
			s.phase = "away"
			s.ufo_t = 0.5
			var landed := false
			for i in 120:
				sw.update(0.1)
				if str(s.phase) == "landed":
					landed = true
					break
			# 3) узор
			var tc = game.tech
			tc.patterns.erase("p_steel")
			tc.refresh_locks()
			var locked: bool = DB.locked.has("r:steel_arc")
			var p: Dictionary = Starworks.pattern("p_steel")
			var cells: Array = Starworks.pattern_cells(p)
			var half: Array = cells.duplicate()
			for i in 8:
				half[i + 8] = ""
			var partial: bool = Starworks.match_count(p, half) == 4
			game.player.inv.add("coal_hq", 8)
			game.player.inv.add("iron_ingot", 4)
			# повёрнутый на 90° узор тоже подходит
			var rot: Array = Starworks.variants(p)[1]
			var res: String = sw.try_pattern(rot, game.player.inv)
			var opened: bool = res == "" and not DB.locked.has("r:steel_arc") and tc.patterns.has("p_steel")
			# 4) звёздные врата
			var gate = put_near(game, "star_gate", c + Vector2i(0, 8))
			var st0: Dictionary = Starworks.stages()[0].need
			for k in st0:
				var left := int(st0[k])
				while left > 0:
					var n := mini(left, 500)
					gate.inv.add(k, n)
					sw._megaprojects()
					left -= n
			var mega: bool = Starworks.stage(gate) == 1
			# 5) сохранение
			var sd: Dictionary = game.save_dict()
			game.load_game(sd)
			var saved: bool = game.tech.patterns.has("p_steel") and Starworks.stage(game.factory.building_at(gate.cell)) == 1 and Starworks.st(game.factory.building_at(pad.cell)).orders.size() == 1
			print("TEST starworks tune=", tune_ok, " gold=", snappedf(gold, 0.01), " extra=", extra_ok, " swings=", swings, " q=", q1, " took=", took, " bought=", bought,
				" delivered=", delivered, " landed=", landed, " locked=", locked, " partial=", partial, " opened=", opened, " mega=", mega, " saved=", saved, " ",
				"OK" if tune_ok and extra_ok and swings and took and bought and delivered and landed and locked and partial and opened and mega and saved else "FAIL")
		"atom":
			# 14.22: новые ресурсы по дереву, кислота разъедает трубы, радиация, заражение и очистка
			var f = game.factory
			var hz = game.hazards
			var tc = game.tech
			game.flags["free_build"] = true
			game.flags["god"] = false
			# 1) замки: без открытий уран, селитра, АЭС, порох закрыты; «Химия» открывает селитру и порох
			var done_was: Dictionary = tc.done.duplicate()
			tc.done.clear()
			tc.refresh_locks()
			var locked0: bool = DB.locked.has("d:uranium_ore") and DB.locked.has("d:saltpeter") and DB.locked.has("b:nuclear_reactor") and DB.locked.has("r:gunpowder") and DB.locked.has("d:alunite")
			tc.done["t_chem"] = true
			tc.refresh_locks()
			var chem_ok: bool = not DB.locked.has("d:saltpeter") and not DB.locked.has("r:gunpowder") and DB.locked.has("d:uranium_ore")
			tc.done = done_was
			tc.refresh_locks()
			var deps := {}
			for k in game.world.deposit:
				deps[str(game.world.deposits[game.world.deposit[k]].get("item", ""))] = true
			var on_map: bool = deps.has("uranium_ore") and deps.has("saltpeter") and deps.has("alunite")
			var ammo_r: Dictionary = DB.data.recipes.get("ammo", {})
			var ammo_hard: bool = ammo_r.get("in", {}).has("gunpowder") and DB.data.recipes.has("ammo_crude")
			var alu_line: bool = DB.data.recipes.has("alumina") and DB.data.recipes.has("aluminum_scrap") and DB.data.recipes.has("aluminum_ingot") and DB.item_name("alunite") == "Алунит"
			# 2) кислота: обычная труба лопается → лужа, кислотостойкая цела
			var c: Vector2i = f.hq.cell + Vector2i(-14, -12)
			for dx in range(-2, 12):
				for dz in range(-2, 6):
					game.world.remove_node(World.wc(c + Vector2i(dx, dz)))
			var p1 = put(game, "pipe", c, 0)
			var p2 = put(game, "pipe", c + Vector2i(1, 0), 0)
			var q1 = put(game, "pipe_acid", c + Vector2i(0, 3), 0)
			var q2 = put(game, "pipe_acid", c + Vector2i(1, 3), 0)
			for pp in [p1, p2, q1, q2]:
				pp.fluid = "sulfuric_acid"
				pp.famt = 3.0
			f.fluid_dirty = true
			f._rebuild_fluids()
			for i in 200:
				hz._acid(1.0)
				if p1.dead:
					break
			var corroded: bool = p1.dead and not q1.dead and q1.hp == q1.maxhp
			var spilled: bool = hz.puddles.size() >= 1
			# кислота в рюкзаке без костюма жжёт, в костюме — нет
			var pl = game.player
			pl.position = World.cell_to_world(f.hq.cell + Vector2i(0, 30))
			pl.inv.add("canister_acid", 10)
			pl.clothes = ""
			hz._step(1.0)
			var acid_carry: bool = hz.acid_hit > 0.0
			pl.clothes = "hazmat_suit"
			hz._step(1.0)
			var acid_safe: bool = hz.acid_hit == 0.0
			pl.inv.remove("canister_acid", 10)
			# 3) радиация от ТВЭЛов в рюкзаке; костюм снимает 90%
			pl.clothes = ""
			hz.dose = 0.0
			pl.inv.add("fuel_rod", 5)
			hz._step(1.0)
			var r_bare: float = hz.rate
			pl.clothes = "hazmat_suit"
			hz._step(1.0)
			var r_suit: float = hz.rate
			pl.inv.remove("fuel_rod", 5)
			var rad_ok: bool = r_bare > 0.3 and r_suit < r_bare * 0.2 and hz.dose > 0.0
			# у урановой залежи фонит
			var ucell = null
			for k in game.world.deposit:
				if str(game.world.deposits[game.world.deposit[k]].get("item", "")) == "uranium_ore":
					ucell = k
					break
			var dep_rad: bool = ucell != null and hz.rad_at(World.cell_to_world(ucell), false) > 0.5
			# 4) заражение: строить нельзя; баллон и станция чистят
			pl.clothes = ""
			var zc: Vector2i = f.hq.cell + Vector2i(20, -20)
			var zp := World.cell_to_world(zc)
			hz.contaminate(zp, 10.0, 40.0)
			for dx in range(-3, 4):
				for dz in range(-3, 4):
					game.world.remove_node(World.wc(zc + Vector2i(dx, dz)))
			var blocked: bool = f.can_place("chest", zc).contains("радиац")
			var lv0: float = hz.level_at(zp)
			pl.position = zp
			pl.inv.add("decon_spray", 1)
			var slot: int = -1
			for i in pl.inv.slots.size():
				if pl.inv.slots[i] != null and pl.inv.slots[i].id == "decon_spray":
					slot = i
			pl.use_item(slot)
			var lv1: float = hz.level_at(zp)
			var sprayed: bool = lv1 < lv0 and pl.inv.count("decon_spray") == 0
			hz.zone.clear()
			hz.contaminate(zp, 6.0, 30.0)
			DB.data.buildings["decon_station"].params["power"] = 0
			var ds = put(game, "decon_station", zc + Vector2i(12, 0), 0)
			if ds == null:
				ds = put_near(game, "decon_station", zc + Vector2i(12, 0))
			ds.inv.add("decon_solution", 20)
			pl.position = World.cell_to_world(f.hq.cell + Vector2i(0, 30))
			for i in 150:
				hz._stations(1.0)
				if hz.level_at(zp) < 1.0:
					break
			var st_why: String = f.can_place("chest", zc)
			var station_ok: bool = hz.level_at(zp) < 1.0 and ds.inv.count("decon_solution") < 20 and (st_why == "" or not st_why.contains("радиац"))
			print("TEST atom locked=", locked0, " chem=", chem_ok, " on_map=", on_map, " ammo=", ammo_hard, " alu=", alu_line, " corroded=", corroded, " spilled=", spilled,
				" acid_carry=", acid_carry, " acid_safe=", acid_safe, " rad=", snappedf(r_bare, 0.01), "/", snappedf(r_suit, 0.01), " dep_rad=", dep_rad,
				" blocked=", blocked, " sprayed=", sprayed, " station=", station_ok, " why='", st_why, "' ",
				"OK" if locked0 and chem_ok and on_map and ammo_hard and alu_line and corroded and spilled and acid_carry and acid_safe and rad_ok and dep_rad and blocked and sprayed and station_ok else "FAIL")
		"reactor":
			# 14.22: АЭС: заглушена → ровно работает → отходы → АЗ-5 → авария без воды (разрушения, заражение) → автозащита
			var f = game.factory
			var nuc = f.nuc
			var hz = game.hazards
			game.flags["free_build"] = true
			game.flags["god"] = true
			var c: Vector2i = f.hq.cell + Vector2i(30, 0)
			for dx in range(-20, 21):
				for dz in range(-20, 21):
					game.world.remove_node(World.wc(c + Vector2i(dx, dz)))
			var r = put_near(game, "nuclear_reactor", c)
			var s: Dictionary = Nuclear.st(r)
			var takes: bool = f.accept(r, "fuel_rod", null) and not f.accept(r, "coal", null)
			var cg = put_near(game, "coal_generator", c + Vector2i(-12, -12))
			var coal_no: bool = cg != null and not f.accept(cg, "fuel_rod", null)
			var wants: bool = f.wants_fluid(r, "water") > 0 and f.wants_fluid(r, "oil") == 0
			for i in 5:
				f.accept(r, "fuel_rod", null)
			var feed := func(steps: int, water: bool):
				for i in steps:
					if water:
						Nuclear.add_water(r, 100.0)
					nuc.power(r, 0.1, false)
					if r.dead:
						return
			s.load = 4
			s.pump = 1.0
			s.rods_set = 1.0
			feed.call(300, true)
			var idle: bool = float(s.T) < 30.0 and float(s.out_pw) == 0.0
			s.rods_set = 0.5
			feed.call(1500, true)
			var T_run: float = s.T
			var pw_run: float = s.out_pw
			var running: bool = T_run > 100.0 and T_run < float(Nuclear.c("warn_t", 500.0)) and pw_run > 500.0
			feed.call(6500, true)   # 17.10: ТВЭЛ горит 1200 «стержне-секунд» — первая отработка примерно через 10 минут
			var waste: bool = r.out.count("nuclear_waste") >= 1 and Nuclear.rods_in(r) < 6
			s.scram = true
			feed.call(600, true)
			var scrammed: bool = float(s.rods) > 0.99 and float(s.out_pw) == 0.0 and float(s.T) < T_run
			# авария: стержни вверх, воды нет
			var near = put_near(game, "chest", r.cell + Vector2i(5, 0))
			var far = put_near(game, "chest", c + Vector2i(-40, 0))
			s.scram = false
			s.rods_set = 0.0
			s.pump = 0.0
			s.water = 0.0
			while Nuclear.rods_in(r) < 4:
				r.fuel.add("fuel_rod", 1)
			var rc: Vector3 = r.center()
			var steps := 0
			while not r.dead and steps < 3000:
				nuc.power(r, 0.1, false)
				steps += 1
			var boom: bool = r.dead and near.dead and (far == null or not far.dead)
			var zoned: bool = hz.level_at(rc) > float(Hazards.rcfg().get("build_block", 3.0)) and f.can_place("chest", World.world_to_cell(rc)).contains("радиац")
			var saved_zone: int = hz.zone.size()
			var sd: Dictionary = game.save_dict()
			game.load_game(sd)
			var zone_saved: bool = game.hazards.zone.size() == saved_zone and saved_zone > 0
			# автозащита спасает
			game.hazards.zone.clear()
			var r2 = put_near(game, "nuclear_reactor", c + Vector2i(0, 14))
			var s2: Dictionary = Nuclear.st(r2)
			r2.fuel.add("fuel_rod", 4)
			s2.load = 4
			s2.rods_set = 0.0
			s2.pump = 0.0
			s2.auto = true
			for i in 3000:
				f.nuc.power(r2, 0.1, false)
			var auto_ok: bool = not r2.dead and bool(s2.scram) and float(s2.T) < float(Nuclear.c("melt_t", 1100.0))
			print("TEST reactor takes=", takes, " coal_no=", coal_no, " wants=", wants, " idle=", idle, " T=", int(T_run), " pw=", int(pw_run), " running=", running,
				" waste=", waste, " scram=", scrammed, " boom=", boom, " steps=", steps, " zoned=", zoned, " zone_saved=", zone_saved, " auto=", auto_ok, " ",
				"OK" if takes and coal_no and wants and idle and running and waste and scrammed and boom and zoned and zone_saved and auto_ok else "FAIL")
		"drones":
			# 14.21: станция дронов: маршрут А → Б, батарея, уровни 1/2/4, сбитый дрон и новый, сохранение
			var f = game.factory
			var dr = game.drones
			game.flags["free_build"] = true
			DB.data.buildings["drone_station"].params["power"] = 0
			var hc: Vector2i = f.hq.cell
			var c: Vector2i = hc + Vector2i(-8, 8)
			for dx in range(-12, 13):
				for dz in range(-3, 4):
					game.world.remove_node(World.wc(c + Vector2i(dx, dz)))
			var stn = put(game, "drone_station", c, 0)
			var a = put(game, "chest", c + Vector2i(-8, 0), 0)
			var z = put(game, "chest", c + Vector2i(8, 0), 0)
			a.inv.add("iron_ore", 30)
			dr.sync()
			var one: bool = dr.drones_of(stn).size() == 1
			dr.set_routes(stn, [{"from": [a.cell.x, a.cell.y], "to": [z.cell.x, z.cell.y], "item": "", "keep": 5, "on": true}])
			var saw_fly := false
			var saw_charge := false
			for i in 900:
				dr.update(0.1)
				var d0: Dictionary = dr.drones_of(stn)[0]
				if d0.state in ["go_src", "go_dst"]:
					saw_fly = true
				if saw_fly and d0.state == "dock" and d0.bat < Drones.battery() - 1.0:
					saw_charge = true
			var moved: int = z.inv.count("iron_ore")
			var kept: bool = a.inv.count("iron_ore") == 5 and moved == 25
			# батареи не хватает на дальний маршрут
			DB.data.settings.drones["battery_m"] = 30.0
			dr.st[stn].err = {}
			var d1: Dictionary = dr.drones_of(stn)[0]
			d1.bat = 30.0
			a.inv.add("iron_ore", 10)
			for i in 10:
				dr.update(0.1)
			var bat_err: bool = dr.route_err(stn, 0).contains("батаре") and d1.state == "dock"
			DB.data.settings.drones["battery_m"] = 400.0
			# уровни: 2 станции → 2 дрона, ещё пара → «Объединение 3» = 4 дрона
			var s2 = put(game, "drone_station", c + Vector2i(1, 0), 0)
			game.cmd("fuse", {"a": stn, "b": s2, "kind": "level"})
			var s3 = put(game, "drone_station", c + Vector2i(0, 1), 0)
			var s4 = put(game, "drone_station", c + Vector2i(1, 1), 0)
			game.cmd("fuse", {"a": s3, "b": s4, "kind": "level"})
			game.cmd("fuse", {"a": stn, "b": s3, "kind": "level"})
			dr.sync()
			var lvl_ok: bool = stn.lvl == 3 and dr.drones_of(stn).size() == 4 and dr.st.size() == 1
			# сбитый дрон: робот у станции, новый собирается за ресурсы штаба
			DB.data.settings.drones["rebuild_s"] = 1.0
			for k in ["iron_plate", "circuit", "motor"]:
				f.hq.inv.add(k, 20)
			game.flags["free_build"] = false
			var plates0: int = f.hq.inv.count("iron_plate")
			var foe = game.enemies.spawn("crawler", stn.center() + Vector3(1.0, 0, 0))
			if foe:
				foe.speed = 0.0
			game.flags["god"] = true
			var died := false
			for i in 200:
				dr.update(0.1)
				if dr.drones_of(stn).any(func(x): return x.state == "dead"):
					died = true
					break
			if foe:
				game.enemies.remove_silent(foe)
			for i in 40:
				dr.update(0.1)
			var rebuilt: bool = died and dr.drones_of(stn).all(func(x): return x.state != "dead") and f.hq.inv.count("iron_plate") < plates0
			# сохранение: маршрут и уровень
			var sd: Dictionary = game.save_dict()
			game.load_game(sd)
			var ls = f.building_at(stn.cell)
			game.drones.sync()
			var saved: bool = ls != null and Drones.routes(ls).size() == 1 and game.drones.drones_of(ls).size() == 4
			print("TEST drones one=", one, " fly=", saw_fly, " charge=", saw_charge, " moved=", moved, " kept=", kept, " bat_err=", bat_err, " lvl=", lvl_ok,
				" died=", died, " rebuilt=", rebuilt, " saved=", saved, " ",
				"OK" if one and saw_fly and saw_charge and kept and bat_err and lvl_ok and died and rebuilt and saved else "FAIL")
		"aimodel":
			# модель «от нейросети» (одна сплошная сетка в GLB) → автоскелет → монстр шагает, герой собирается
			var r := ModelGen.generate("ржавый робот-паук с шестью ногами", {"seed": 2, "quality": 0})
			var root := Node3D.new()
			for rel in r.meshes:
				var mi := MeshInstance3D.new()
				mi.mesh = r.meshes[rel]
				mi.rotation_degrees = Vector3(0, -90, 0)
				root.add_child(mi)
			var doc := GLTFDocument.new()
			var gst := GLTFState.new()
			doc.append_from_scene(root, gst)
			var gpath := OS.get_user_data_dir().path_join("ai_test.glb")
			doc.write_to_filesystem(gst, gpath)
			root.free()
			var src := AutoRig.load_mesh(gpath)
			var mon := AutoRig.rig(src, {"kind": "monster", "id": "ai_mon", "height": 1.4})
			for rel in mon.meshes:
				ModelLib.put_mesh(rel, mon.meshes[rel])
			DB.data.models["ai_mon"] = mon.model
			var legs: int = mon.model.rig.legs.size()
			DB.data.enemies["crawler"]["model"] = "ai_mon"
			DB.revision += 1
			var e = game.enemies.spawn("crawler", game.player.position + Vector3(5, 0, 0))
			var rg = preload("res://scripts/creature_rig.gd").new()
			game.add_child(rg)
			var built: bool = rg.build("ai_mon")
			var hb: Node3D = rg.bones.get("b:hip0")
			var q0: Basis = hb.basis if hb else Basis()
			for i in 15:
				rg.animate(1.0 / 30.0, Vector3(i * 0.15, 0, 0), 0.0, 1.0, {"speed": 3.0})
			var walks: bool = hb != null and not hb.basis.is_equal_approx(q0) and rg.skel != null
			rg.queue_free()
			var hero_r := AutoRig.rig(src, {"kind": "hero", "id": "ai_hero"})
			for rel in hero_r.meshes:
				ModelLib.put_mesh(rel, hero_r.meshes[rel])
			DB.data.models["ai_hero"] = hero_r.model
			DB.data.settings["hero_model"] = "ai_hero"
			DB.revision += 1
			var P2 = load("res://scripts/player.gd")
			var hero = P2.new()
			hero.game = game
			game.add_child(hero)
			hero.position = game.player.position + Vector3(2, 0, 0)
			hero.build()
			var hero_ok: bool = hero.skel != null and hero.skel.get_bone_count() >= 12 and hero.arm_r != null
			hero.arm_r.rotation.z = 0.8
			hero._sync_skin()
			hero_ok = hero_ok and not hero.skel.get_bone_pose_rotation(hero.skel.find_bone("arm_r")).is_equal_approx(Quaternion.IDENTITY)
			hero.queue_free()
			DB.data.settings.erase("hero_model")
			var bld := AutoRig.rig(src, {"kind": "building", "id": "ai_bld", "footprint": 2})
			var fit: bool = true
			for rel in bld.meshes:
				var bb: AABB = (bld.meshes[rel] as ArrayMesh).get_aabb()
				fit = fit and maxf(bb.size.x, bb.size.z) <= 4.0 and bb.position.y > -0.01
			print("TEST aimodel legs=", legs, " spawned=", e != null, " built=", built, " walks=", walks, " hero=", hero_ok, " building_fit=", fit, " ",
				"OK" if legs >= 4 and e != null and built and walks and hero_ok and fit else "FAIL")
		"loot17":
			# ядро, клык и мясо снова откуда-то берутся
			var E: Dictionary = DB.data.enemies
			var has_drop := func(eid: String, item: String) -> bool:
				for d in E.get(eid, {}).get("drops", []):
					if d.get("item", "") == item:
						return true
				return false
			var core_ok: bool = has_drop.call("boss_titan", "monster_core") and has_drop.call("brute_t5", "monster_core") and has_drop.call("guard_t4", "monster_core") and not has_drop.call("brute", "monster_core")
			var fang_ok: bool = has_drop.call("runner", "fang")
			var meat_ok := false
			for g in E.get("trader", {}).get("goods", []):
				meat_ok = meat_ok or g.get("item", "") == "raw_meat"
			print("TEST loot17 core=", core_ok, " fang=", fang_ok, " meat=", meat_ok, " ", "OK" if core_ok and fang_ok and meat_ok else "FAIL")
		"doc17":
			# 17.10: утилизатор → купоны, разгонитель облаков оплачивает зону, твёрдые залежи (кирка и бур по уровню), скрытые до открытия
			var f = game.factory
			var w = game.world
			game.flags["free_build"] = true
			var hq: Vector2i = f.hq.cell
			for bid in ["sink", "cloud_breaker"]:
				for bl in DB.data.buildings[bid].get("blocks", []):
					bl["needs_power"] = false
			var sk = null
			var cb = null
			for dx in range(6, 20):
				if sk == null:
					sk = put(game, "sink", hq + Vector2i(dx, 7), 0)
				elif cb == null:
					cb = put(game, "cloud_breaker", hq + Vector2i(dx + 1, 7), 0)
			var sink_ok := false
			var coupons := 0
			var no_coupon_in := false
			if sk != null:
				no_coupon_in = not Blocks.accept(sk, "sink_coupon", f) and Blocks.accept(sk, "iron_plate", f)
				sk.inv.add("iron_plate", 40)
				for i in 20:
					Blocks.update(f, sk, 0.25)
				coupons = sk.out.count("sink_coupon")
				var want := int(floor(40.0 * float(DB.item("iron_plate").get("price", 1)) / 100.0))
				sink_ok = coupons == want and sk.inv.count("iron_plate") == 0 and int(game.sink_points_total) == want * 100
			var zone_ok := false
			var zb0 := -1
			var zb1 := -1
			if cb != null and game.zone != null:
				var zc: Dictionary = game.zone.next_cost()
				zb0 = int(game.zone.blocks)
				var stranger := not Blocks.accept(cb, "sink_coupon", f) or zc.has("sink_coupon")
				for it in zc:
					cb.inv.add(it, int(zc[it]))
				for _i in 5:   # A-8 r4: разгон копится 1 с при полной энергии
					Blocks.update(f, cb, 0.25)
				zb1 = int(game.zone.blocks)
				zone_ok = not zc.is_empty() and zb1 > zb0 and stranger
			# скрытые залежи и твёрдая порода
			var tung := -1
			for i in w.deposits.size():
				if str(w.deposits[i].get("item", "")) == "tungsten_ore":
					tung = i
			# проверка идёт с открытым деревом — закрываем залежь так, как её закрывает узел «Глубокие породы»
			var by_tech := false
			for tid in DB.data.tech:
				by_tech = by_tech or "tungsten_ore" in DB.data.tech[tid].get("unlocks", {}).get("deposits", [])
			DB.locked["d:tungsten_ore"] = "t_geo3"
			var tc := Vector2i(-1, -1)
			for c in w.deposit:
				if w.deposit[c] == tung and not f.grid.has(c):
					tc = c
					break
			var hidden0: bool = by_tech and tung >= 0 and w.deposit_hidden(tung) and tc.x >= 0 and w.deposit_item(tc) == ""
			DB.locked.erase("d:tungsten_ore")
			var weak := true
			var strong := false
			var mk1_why := ""
			var mk2_why := "x"
			if tc.x >= 0:
				weak = w.mine_deposit(tc, 3.0, "pickaxe")
				strong = w.mine_deposit(tc, 1000.0, "pickaxe")
				mk1_why = f._miner_why("miner", tc)
				mk2_why = f._miner_why("miner_mk2", tc)
			var dep_ok: bool = hidden0 and tc.x >= 0 and not weak and strong and mk1_why.find("Mk2") >= 0 and mk2_why == ""
			var counts := {"items": 0, "buildings": 0}
			for it in ["clay", "sand", "tin_ore", "bauxite", "tungsten_ore", "resonite", "natural_gas", "bronze_pickaxe", "gas_mask"]:
				if DB.data.items.has(it):
					counts.items += 1
			for bid in ["foundry", "constructor", "manufacturer", "coke_oven", "crusher", "mixer", "arc_furnace", "clean_room", "gas_extractor", "sink", "sink_shop", "cloud_breaker"]:
				if DB.data.buildings.has(bid):
					counts.buildings += 1
			var bal_ok: bool = int(DB.bparam("belt_mk5", "per_min", 0)) == 780 and is_equal_approx(float(DB.bparam("miner_mk3", "rate_mult", 0)), 4.0) and int(DB.bparam("assembler", "power", 0)) == 15
			print("TEST doc17 sink=", sink_ok, " coupons=", coupons, " coupon_in=", no_coupon_in, " zone=", zb0, "->", zb1, " hidden=", hidden0, " weak=", weak, " strong=", strong,
				" mk1='", mk1_why, "' mk2='", mk2_why, "' have=", counts, " balance=", bal_ok, " ",
				"OK" if sink_ok and no_coupon_in and zone_ok and dep_ok and counts.items == 9 and counts.buildings == 12 and bal_ok else "FAIL")
		"s18":
			# 18: волны 1200/600 и бесконечные; двойной клик — вся стопка; запас машины под рецепт на 50; обучение «изучи»;
			# скрытые рецепты; робот-строитель отстраивает разрушенное, чинит, ломается от монстров и собирается снова
			var f = game.factory
			var w = game.world
			var E = game.enemies
			var wd: Dictionary = DB.data.waves
			var gaps := []
			for wv in [1, 5, 10, 20, 40, 100]:
				gaps.append(maxf(float(wd.get("interval_min", 80)), float(wd.get("interval", 150)) - float(wd.get("interval_step", 8)) * wv))
			var waves_ok: bool = int(wd.get("first_delay", 0)) == 1200 and gaps.min() >= 600.0 and str(DB.menu("victory", {}).get("mode", "")) == "none"
			game.victory = true
			var w0: int = E.wave
			E.start_wave()
			var endless: bool = E.wave == w0 + 1
			game.victory = false
			for e in E.list.duplicate():
				E.kill_visual(e)
			# двойной клик по стопке 50 → в печь уходит вся стопка
			game.flags["free_build"] = true
			var hq: Vector2i = f.hq.cell
			var fur = null
			for dx in range(5, 15):
				fur = put(game, "furnace", hq + Vector2i(dx, 7), 0)
				if fur:
					break
			var pl = game.player
			pl.inv.slots[pl.inv.size() - 1] = {"id": "iron_ore", "n": 50}
			pl.inv.changed.emit()
			game.hud.bld = fur
			game.hud.open("building")
			game.hud.quick_move(pl.inv, pl.inv.size() - 1)
			var dbl_n: int = fur.inv.count("iron_ore") if fur else 0
			game.hud.close("building")
			# машина под ТВЭЛ (50 урана) принимает с ленты больше 20
			var cap_ok := false
			var asm = null
			for bid in ["manufacturer", "assembler", "constructor"]:
				if DB.data.recipes.get("fuel_rod", {}).get("stations", []).has(DB.bparam(bid, "station", "")):
					asm = put_near(game, bid, hq + Vector2i(-10, 8))
					break
			if asm:
				asm.recipe = "fuel_rod"
				var belt_src = put_near(game, "belt", hq + Vector2i(-14, 14))
				var took := 0
				for i in 120:
					if f.accept(asm, "enriched_uranium", belt_src):
						took += 1
				cap_ok = took >= 100 and f.in_cap(asm, "enriched_uranium") == 100
			# обучение: шаг «изучи ветки» и подсказка про скрытые рецепты
			var tu = game.tutorial
			var steps: Array = tu.steps()
			var scan_steps: Array = steps.filter(func(st): return str(st.get("goal", "")) == "scan_item").map(func(st): return str(st.get("item", "")))
			var hid: Dictionary = {"n": 0, "need": {}}
			var tut_ok := false
			if scan_steps.is_empty():
				# 1.5: изучения нет — в обучении шаг «Открытия» (изучить ветку), без сканирования
				tut_ok = steps.any(func(st): return str(st.get("goal", "")) == "tech")
			else:
				DB.discovery = true
				DB.known["fiber"] = true
				DB.researched.erase("fiber")
				hid = DB.hidden_by_scan("hand")
				tu.done = false
				tu.restart()
				tu.step = steps.find(steps.filter(func(st): return str(st.get("item", "")) == "fiber" and str(st.get("goal", "")) == "scan_item")[0])
				var p0: Array = tu.progress()
				pl.inv.add("fiber", 10)
				game.scanner.scan("fiber")
				var p1: Array = tu.progress()
				tut_ok = scan_steps.has("branch") and scan_steps.has("fiber") and scan_steps.has("stone") and p0[0] == 0 and p1[0] >= p1[1] and int(hid.n) > 0 and hid.need.has("fiber")
			tu.skip()
			DB.discovery = false
			# робот-строитель
			game.flags["free_build"] = true
			DB.data.buildings["builder_bay"].params["power"] = 0
			var bay = put_near(game, "builder_bay", hq + Vector2i(0, -10))
			var wall_c: Vector2i = bay.cell + Vector2i(3, 0)
			for dx in range(-1, 6):
				for dz in range(-2, 3):
					w.remove_node(World.wc(bay.cell + Vector2i(dx, dz)))
			var wall = put(game, "belt", wall_c, 1)
			var far_c: Vector2i = bay.cell + Vector2i(40, 0)
			for dz in range(-1, 2):
				w.remove_node(World.wc(far_c + Vector2i(0, dz)))
			var far_b = put(game, "belt", far_c, 1)
			game.flags["free_build"] = false
			for k in f.cost_of("belt"):
				f.hq.inv.add(k, 50)
			f.damage(wall, 99999.0)
			if far_b:
				f.damage(far_b, 99999.0)
			var ruin_n: int = game.builders.ruins.size()
			var hq_before: int = f.hq.inv.count(f.cost_of("belt").keys()[0])
			var rebuilt := false
			for i in 400:
				game.builders.update(0.1)
				var nb = f.building_at(wall_c)
				if nb != null and nb.type == "belt" and nb.dir == 1:
					rebuilt = true
					break
			var paid_ok: bool = f.hq.inv.count(f.cost_of("belt").keys()[0]) < hq_before
			var far_left: bool = f.building_at(far_c) == null   # вне радиуса — не трогает
			# ремонт
			var nb2 = f.building_at(wall_c)
			var rep_ok := false
			if nb2:
				f.damage(nb2, nb2.maxhp * 0.5)
				for i in 300:
					game.builders.update(0.1)
					if nb2.hp >= nb2.maxhp:
						rep_ok = true
						break
			# монстр ломает робота, мастерская собирает нового
			var bot = game.builders.bot_of(bay)
			var mon = E.spawn("crawler", bot.pos + Vector3(1, 0, 0)) if bot else null
			if mon:
				mon.dmg = 50.0
			var dead := false
			for i in 40:
				game.builders.update(0.25)
				if game.builders.bot_of(bay) == null:
					dead = true
					break
			if mon:
				mon.alive = false
				E.kill_visual(mon)
			game.builders.bays[bay].dead_t = 0.0
			for k in DB.setting("builders", {}).get("rebuild_cost", {}):
				f.hq.inv.add(k, 20)
			for i in 5:
				game.builders.update(0.6)
			var reborn: bool = game.builders.bot_of(bay) != null
			var info: String = game.builders.info(bay)
			# сохранение развалин
			f.damage(f.building_at(wall_c), 99999.0)
			var sdb: Dictionary = game.save_dict()
			var saved_ruins: int = (sdb.get("builders18", {}).get("ruins", []) as Array).size()
			var bots_ok: bool = ruin_n >= 1 and rebuilt and paid_ok and far_left and rep_ok and dead and reborn and saved_ruins >= 1 and info.contains("Робот-строитель")
			print("TEST s18 waves=", waves_ok, " gaps=", gaps, " endless=", endless, " dblclick=", dbl_n, " cap=", cap_ok, " tut=", tut_ok, " scan_steps=", scan_steps, " hidden=", hid.n,
				" ruins=", ruin_n, " rebuilt=", rebuilt, " paid=", paid_ok, " far_left=", far_left, " repair=", rep_ok, " bot_dead=", dead, " reborn=", reborn, " saved_ruins=", saved_ruins, " ",
				"OK" if waves_ok and endless and dbl_n == 50 and cap_ok and tut_ok and bots_ok else "FAIL")
		"s19":
			# 1.0.8: очередь крафта 50, ящики 2/3/4/6 строк, месторождения разной формы, «ресурсы мало/много», этапы сканера,
			# серые здания с замком, явные режимы, контуры развалин только у мастерской, порт 443 и разбор ответа STUN
			var f = game.factory
			var pl = game.player
			var hq: Vector2i = f.hq.cell
			# очередь крафта
			var rid := ""
			for r in DB.data.recipes:
				if DB.data.recipes[r].get("stations", []).has("hand") and not DB.data.recipes[r].get("in", {}).is_empty():
					rid = r
					break
			pl.inv.slots.fill(null)
			for k in DB.data.recipes[rid].in:
				pl.inv.add(k, int(DB.data.recipes[rid].in[k]) * 60)
			game.craft_queue.clear()
			game.queue_craft(rid, 70, "hand")
			var q_n: int = game.craft_queue.size()
			game.craft_queue.clear()
			pl.inv.slots.fill(null)
			pl.inv.changed.emit()
			# ящики
			var slots := []
			for bid in ["chest", "chest_iron", "container", "warehouse"]:
				slots.append(int(DB.bparam(bid, "slots", 0)))
			var unl := []
			for nid in DB.data.tech:
				for bid in DB.data.tech[nid].get("unlocks", {}).get("buildings", []):
					if bid in ["chest_iron", "warehouse"]:
						unl.append(bid)
			var chest_ok: bool = slots == [20, 30, 40, 60] and unl.has("chest_iron") and unl.has("warehouse")
			# месторождения: разные модели (по набору форм)
			var sigs := {}
			for d in DB.data.world.get("deposits", []):
				var md: Dictionary = DB.data.models.get(str(d.get("marker", "")), {})
				var sh := []
				for pp in md.get("parts", []):
					sh.append("%s%s%s" % [pp.get("shape", ""), pp.get("seg", ""), pp.get("mesh", "")])
				sigs[str(d.get("item", ""))] = str(sh)
			var uniq := {}
			for k in sigs:
				uniq[sigs[k]] = true
			var dep_ok: bool = sigs.get("quartz", "") != sigs.get("iron_ore", "") and sigs.get("iron_ore", "") != sigs.get("coal", "") and uniq.size() >= 15
			# «ресурсы: мало / много»
			var cnt := []
			for k in [0.5, 1.8]:
				var w2 := World.new()
				game.add_child(w2)
				w2.generate(4242, {"size": 256, "res_k": k}, true)
				cnt.append(w2.deposit.size())
				w2.queue_free()
			var res_ok: bool = cnt[1] > cnt[0] * 2
			# этапы сканера и серые здания
			DB.discovery = true
			var keep_r: Dictionary = DB.researched.duplicate()
			var keep_k: Dictionary = DB.known.duplicate()
			DB.researched.clear()
			DB.known.clear()
			DB.known["plank"] = true
			var stg: Array = game.scanner.stages()
			var st_ok: bool = stg.size() >= 3 and (stg[0].items as Array).size() > 0
			var miss: Array = DB.scan_missing(DB.building("chest").get("cost", {}))
			game.hud.close("scan")
			game.select_build("chest")
			var blocked: bool = game.build_type == "" and game.hud.is_open("scan")
			game.hud._refresh_scan()
			var unk_rows: int = 0
			for l in game.hud.windows.scan.body.find_children("*", "Label", true, false):
				if (l as Label).text == "Неизвестный ресурс":
					unk_rows += 1
			var card: Control = game.hud._build_card("chest")
			var has_lock: bool = not card.find_children("*", "LockIcon", true, false).is_empty() or card.find_children("*", "", true, false).any(func(n): return n.get_script() != null and str(n.get_class()) == "Control")
			card.free()
			game.hud.close("scan")
			DB.researched = keep_r
			DB.known = keep_k
			DB.discovery = false
			var gray_ok: bool = miss.has("plank") and blocked and unk_rows >= 1 and has_lock
			# режимы
			var modes := []
			game.wiring = true
			modes.append(str(game.mode_info().get("id", "")))
			game.wiring = false
			game.demolish = true
			modes.append(str(game.mode_info().get("id", "")))
			for i in 20:
				game.hud._update_mode_hud(0.05)
			var banner: bool = game.hud.mode_box.visible and game.hud.mode_title.text.contains("РАЗБОР") and game.hud.mode_edge.visible
			game.demolish = false
			modes.append(str(game.mode_info().get("id", "")))
			for i in 20:
				game.hud._update_mode_hud(0.05)
			var mode_ok: bool = modes == ["wire", "demolish", ""] and banner and not game.hud.mode_box.visible
			# контуры развалин
			game.flags["free_build"] = true
			# 1.1.12: по умолчанию контуры видны всегда; режим «bay» проверяем явно
			var rw0 = DB.data.settings.get("builders", {}).get("ruins_when", "bay")
			DB.data.settings["builders"]["ruins_when"] = "bay"
			DB.data.buildings["builder_bay"].params["power"] = 0
			var bay = put_near(game, "builder_bay", hq + Vector2i(0, -12))
			var bl = put_near(game, "belt", bay.cell + Vector2i(3, 0), 1)
			game.flags["free_build"] = false
			f.damage(bl, 99999.0)
			game.builders.update(0.1)
			var rn: Array = game.builders.ruins.filter(func(r): return r.node != null)
			var hidden0: bool = not rn.is_empty() and not rn[0].node.visible
			pl.position = bay.center() + Vector3(2, 0, 0)
			game.hud.open_building(bay)
			game.builders.update(0.1)
			var shown: bool = not rn.is_empty() and rn[0].node.visible
			game.hud.close("building")
			game.builders.update(0.1)
			var hidden1: bool = not rn.is_empty() and not rn[0].node.visible
			DB.data.settings["builders"]["ruins_when"] = "always"
			game.builders.update(0.1)
			var always_ok: bool = not rn.is_empty() and rn[0].node.visible
			DB.data.settings["builders"]["ruins_when"] = rw0
			var ruin_ok: bool = hidden0 and shown and hidden1 and always_ok
			# порт и STUN
			var code: String = Net.make_code("93.184.216.34", 443)
			var dec: Array = Net.decode_code(code)
			var tid := PackedByteArray([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12])
			var pkt := PackedByteArray([1, 1, 0, 12, 0x21, 0x12, 0xA4, 0x42])
			pkt.append_array(tid)
			pkt.append_array(PackedByteArray([0, 0x20, 0, 8, 0, 1, (5678 ^ 0x2112) >> 8, (5678 ^ 0x2112) & 255, 1 ^ 0x21, 2 ^ 0x12, 3 ^ 0xA4, 4 ^ 0x42]))
			var stun: Array = preload("res://scripts/lobby.gd").parse_stun(pkt, tid)
			var net_ok: bool = Net.default_port() == 443 and dec == ["93.184.216.34", 443] and stun == ["1.2.3.4", 5678]
			print("TEST s19 queue=", q_n, " chests=", slots, " deposits_unique=", uniq.size(), " res=", cnt, " stages=", stg.size(), " miss=", miss, " blocked=", blocked,
				" unknown_rows=", unk_rows, " lock=", has_lock, " modes=", modes, " banner=", banner, " ruin_hidden=", hidden0, " ruin_shown=", shown, " port=", Net.default_port(), " stun=", stun, " ",
				"OK" if q_n == 50 and chest_ok and dep_ok and res_ok and st_ok and gray_ok and mode_ok and ruin_ok and net_ok else "FAIL")
		"mech17":
			# 17.10: угольный генератор без воды стоит; мастерство, связка, рекорды; геотермалка только на магме; «меньше растительности»; антирад
			var f = game.factory
			var w = game.world
			game.flags["free_build"] = true
			var hq: Vector2i = f.hq.cell
			var ore := nearest_deposit(game, "iron_ore", hq)
			var m = put(game, "miner", ore, 0)
			var gen = null
			# генератор должен оказаться в одной сети с буром (иначе нет нагрузки и он честно не жжёт уголь)
			for off in [Vector2i(0, 2), Vector2i(0, -2), Vector2i(2, 0), Vector2i(-2, 0), Vector2i(2, 2), Vector2i(-2, -2), Vector2i(1, 2), Vector2i(2, 1), Vector2i(-1, -2), Vector2i(-2, -1)]:
				gen = put(game, "coal_generator", ore + off, 0)
				if gen:
					await tree.create_timer(0.6).timeout
					if m and gen.net == m.net:
						break
					f.remove(gen)
					gen = null
			var dry_ok := false
			var wet_ok := false
			var why_dry := ""
			if gen and m:
				gen.fuel.add("coal", 10)
				await tree.create_timer(3.0).timeout
				why_dry = f.bottleneck(gen)
				dry_ok = not gen.active and why_dry.find("воды") >= 0 and f.wants_fluid(gen, "water") > 0
				gen.bstate["water"] = 15.0
				for i in 12:
					if m.out:
						m.out.from_array([])   # бур не должен встать с полным выходом: генератору нужна нагрузка
					await tree.create_timer(0.5).timeout
					# горит и пьёт воду; если в сети в этот момент нет нагрузки, генератор честно ждёт — тогда достаточно, что вода больше не мешает
					wet_ok = wet_ok or (gen.active and float(gen.bstate.get("water", 0.0)) < 15.0) or (i == 11 and f.bottleneck(gen).find("воды") < 0 and float(gen.bstate.get("water", 0.0)) >= 1.0)
			# вода по-настоящему: насос на воде → труба → генератор
			var piped := -1.0
			var wc := Vector2i(-9999, 0)
			for r in range(4, 120):
				for dx in range(-r, r + 1):
					for dz in [-r, r]:
						var c := hq + Vector2i(dx, dz)
						if wc.x == -9999 and w.water_at(c) and not w.water_at(c + Vector2i(1, 0)) and not w.water_at(c + Vector2i(2, 0)) and not w.water_at(c + Vector2i(3, 0)):
							wc = c
				if wc.x != -9999:
					break
			if wc.x != -9999:
				DB.data.buildings["water_pump"].params["power"] = 0
				var wp = put(game, "water_pump", wc, 0)
				var p1 = put(game, "pipe", wc + Vector2i(1, 0), 0)
				var p2 = put(game, "pipe", wc + Vector2i(2, 0), 0)
				var g2 = put(game, "coal_generator", wc + Vector2i(3, 0), 0)
				if wp and p1 and p2 and g2:
					f._rebuild_fluids()
					for step in int(20.0 / Factory.TICK):
						f._tick(Factory.TICK)
					piped = float(g2.bstate.get("water", 0.0))
			var pipe_ok := piped > 1.0
			# мастерство
			var sm = null
			var cn = null
			for dx in range(4, 16):
				if sm == null:
					sm = put(game, "smelter", hq + Vector2i(dx, -8), 0)
				elif cn == null:
					cn = put(game, "constructor", hq + Vector2i(dx + 1, -8), 0)
			var mast_ok := false
			var syn_ok := false
			if sm and cn:
				sm.recipe = "smelt_iron"
				cn.recipe = "iron_plate"
				sm.bstate["crafts"] = 199
				var k0: float = Progress17.k(sm)
				game.progress17.on_made(sm, "", 1)
				mast_ok = Progress17.level(sm) == 1 and Progress17.k(sm) > k0 + 0.04
				game.progress17.update(2.5)
				syn_ok = float(cn.bstate.get("syn", 0.0)) >= 0.1 and float(sm.bstate.get("syn", 0.0)) >= 0.1
			# рекорды
			var cr0: int = game.credits
			if sm:
				game.progress17.on_made(sm, "iron_plate", 100)
			var rec_ok: bool = game.credits > cr0 and game.progress17.got.has("iron_plate|100")
			# заказ дня: из того, что машины уже делали; машины с ним быстрее; за N штук — награда
			var day_ok := false
			if sm and cn:
				game.progress17.daily = {}
				game.progress17.made = {"iron_plate": 100}
				game.progress17.update(2.5)
				var dl: Dictionary = game.progress17.daily
				var fk: float = float(cn.bstate.get("focus", 0.0))
				var cr1: int = game.credits
				game.progress17.on_made(cn, "iron_plate", int(dl.get("need", 0)))
				day_ok = str(dl.get("item", "")) == "iron_plate" and fk > 0.2 and bool(game.progress17.daily.get("done", false)) and game.credits > cr1
			# геотермальная станция: только на выходе магмы
			for dx in range(-8, -3):
				for dz in range(4, 9):
					w.remove_node(World.wc(hq + Vector2i(dx, dz)))
			var geo_why: String = f.can_place("geothermal", hq + Vector2i(-6, 6))
			var vent := Vector2i(-1, -1)
			for c in w.deposit:
				if str(w.deposits[w.deposit[c]].get("item", "")) == "magma":
					vent = c
					break
			DB.locked.erase("d:magma")
			var geo_on: String = f.can_place("geothermal", vent) if vent.x >= 0 else "нет выхода магмы"
			var heat_ok: bool = vent.x >= 0 and game.climate.magma_heat_at(w.cell_to_world(vent)) > 30.0
			# «меньше растительности»
			Prefs.values["flora_less"] = true
			# 1.4: при look.decor_keep (кусты и камешки) набор один и тот же — проверяем, что он не пуст и отфильтрован
			var keep14: Array = DB.data.world.get("look", {}).get("decor_keep", [])
			var lite_ok: bool = (World.decor_list() == DB.data.world.get("decor_lite", []) if keep14.is_empty() else World.decor_list().all(func(d): return str(d.get("model", "")) in keep14)) and not World.decor_list().is_empty()
			Prefs.values.erase("flora_less")
			var full_ok: bool = World.decor_list() == DB.data.world.get("decor", []) if keep14.is_empty() else not World.decor_list().is_empty()
			# антирад
			game.hazards.dose = 80.0
			game.player.inv.add("antirad", 1)
			var rad_ok := false
			for i in game.player.inv.slots.size():
				var s0 = game.player.inv.slots[i]
				if s0 != null and s0.id == "antirad":
					game.player.use_item(i)
					break
			rad_ok = game.hazards.dose <= 41.0
			print("TEST mech17 dry=", dry_ok, " why='", why_dry, "' wet=", wet_ok, " mastery=", mast_ok, " chain=", syn_ok, " records=", rec_ok, " daily=", day_ok, " piped=", piped,
				" geo_off='", geo_why, "' geo_on='", geo_on, "' heat=", heat_ok, " lite=", lite_ok, " full=", full_ok, " antirad=", rad_ok, " ",
				"OK" if dry_ok and wet_ok and pipe_ok and mast_ok and syn_ok and rec_ok and day_ok and geo_why.find("магм") >= 0 and geo_on == "" and heat_ok and lite_ok and full_ok and rad_ok else "FAIL")
		"purity":
			# сколько залежей каждого качества на карте и сколько из них в стартовой зоне
			var w = game.world
			var cnt := {}
			var near_cnt := {}
			var zr: float = w._start_zone_cells()
			var seen := {}
			for c in w.deposit:
				var it := str(w.deposits[w.deposit[c]].get("item", ""))
				if DB.is_fluid(it):
					continue
				var pu := str(w.purity_of(c).get("id", "-"))
				# одна залежь = левый нижний угол квадрата
				if w.deposit.has(c - Vector2i(1, 0)) or w.deposit.has(c - Vector2i(0, 1)):
					continue
				var inside: bool = Vector2(c - w.center).length() < maxf(zr, 20.0) + 2.0
				var dd: Dictionary = near_cnt if inside else cnt
				dd[pu] = int(dd.get(pu, 0)) + 1
			print("TEST purity zone=", snappedf(zr, 0.1), " inside_zone=", near_cnt, " outside=", cnt, " ", "OK" if cnt.size() >= 4 and near_cnt.size() >= 2 and not near_cnt.has("poor") and not near_cnt.has("legendary") else "FAIL")
		"winpos":
			# окна: открываются один раз по центру и больше не прыгают (видимое положение не меняется кадр за кадром)
			var H = game.hud
			var bad := []
			if DisplayServer.get_name() == "headless":
				tree.root.size = Vector2i(1280, 800)
				await tree.process_frame
			for round_i in 2:
				for id in ["inventory", "tech", "craft", "skills", "settings", "help", "build"]:
					H.open(id)
					var w = H.windows[id]
					var seen := []
					for fr in 14:
						await tree.process_frame
						if w.visible and w.modulate.a > 0.5:
							seen.append(w.position)
					var vs: Vector2 = H.root.get_viewport_rect().size / tree.root.content_scale_factor
					var stable := seen.size() >= 10 and seen.all(func(q): return q.distance_to(seen[0]) < 1.0)
					var centred: bool = seen.size() > 0 and absf(seen[0].x + w.size.x * 0.5 - vs.x * 0.5) < 40.0
					var top_stuck: bool = seen.size() > 0 and seen[-1].y <= 5.0 and w.size.y < vs.y - 260.0
					if not stable or not centred or top_stuck:
						bad.append("%s r%d seen=%s size=%s" % [id, round_i, str(seen.slice(0, 3)) + ".." + str(seen.slice(-1)), str(w.size)])
					H.close(id)
					await tree.process_frame
			print("TEST winpos bad=", bad, " ", "OK" if bad.is_empty() else "FAIL")
		"s16":
			# 16: волны и монстры выключаются, код комнаты, рынок игрока, «Куплю», энергия между сетями, краска, табличка, сюрприз, своя база
			var f = game.factory
			var C = game.coop
			game.flags["free_build"] = true
			var hq: Vector2i = f.hq.cell
			game.ng_modules["monsters"] = false
			var no_mon: bool = game.enemies.spawn("crawler", game.player.position + Vector3(10, 0, 0)) == null
			game.ng_modules["waves"] = false
			game.ng_modules["monsters"] = true
			var no_waves: bool = not game.enemies.waves_on()
			game.ng_modules.erase("waves")
			var code: String = Net.make_code("192.168.1.37", 24680)
			var dec: Array = Net.decode_code(code.to_lower())
			var code_ok: bool = code.length() == 11 and dec.size() == 2 and dec[0] == "192.168.1.37" and int(dec[1]) == 24680
			# рынок: цена и покупка, «Куплю» и продажа
			var mk = put_near(game, "player_market", hq + Vector2i(10, 0))
			mk.inv.add("iron_ingot", 20)
			mk.cfg = {"prices": {"iron_ingot": 5}, "wants": {"stone": [3, 10]}}
			game.credits = 100
			var have0: int = game.player.inv.count("iron_ingot")
			game.cmd("mbuy", {"b": mk, "id": "iron_ingot", "n": 6})
			var bought: bool = game.player.inv.count("iron_ingot") == have0 + 6 and mk.inv.count("iron_ingot") == 14
			game.player.inv.add("stone", 20)
			var st0: int = game.player.inv.count("stone")
			game.cmd("msell", {"b": mk, "id": "stone", "n": 99})
			var sold: bool = game.player.inv.count("stone") == st0 - 10 and mk.inv.count("stone") == 10 and int(mk.cfg.wants.stone[1]) == 0
			# энергия: продажа у штаба, покупка далеко — плавильня в чужой сети получает кВт
			game.flags["free_build"] = true
			var se = put_near(game, "power_sell", hq + Vector2i(5, 0))
			game.cmd("wire", {"a": f.hq, "b": se})
			var far: Vector2i = hq + Vector2i(0, 40)
			var bu = put_near(game, "power_buy", far)
			var sm = put_near(game, "smelter", far + Vector2i(3, 0))
			if bu and sm and not f.links.any(func(l): return (l[0] == bu and l[1] == sm) or (l[0] == sm and l[1] == bu)):
				game.cmd("wire", {"a": bu, "b": sm})
			se.cfg = {"kw": 20.0, "price": 1.0}
			bu.cfg = {"from": [se.cell.x, se.cell.y], "kw": 12.0}
			f.power_dirty = true
			for i in 120:
				await tree.process_frame
			var pw_in := float(bu.bstate.get("pw_in", 0.0))
			var energy_ok: bool = se.net >= 0 and bu.net >= 0 and se.net != bu.net and pw_in > 1.0 and float(f.nets[sm.net].supply) >= pw_in - 0.01
			# краска, надпись, сюрприз
			var ch = put_near(game, "chest", hq + Vector2i(-8, 0))
			C.paint(ch, "Шутник")
			var painted: bool = str(ch.bstate.get("paint", "")) == "Шутник" and C._paint.has(ch)
			C.paint(ch, "")
			var cleaned: bool = not ch.bstate.has("paint")
			var sg = put_near(game, "sign", hq + Vector2i(-8, 4))
			sg.cfg = {"text": "Здесь был тест"}
			C._slow()
			var sign_ok: bool = C._labels.has(sg) and C._labels[sg].text == "Здесь был тест"
			game.player.inv.add("surprise", 1)
			game.cmd("put", {"b": ch, "id": "surprise", "n": 1})
			var marked: bool = ch.bstate.has("surprise")
			game.cmd("take", {"b": ch})
			var boo: bool = not ch.bstate.has("surprise") and game.player.inv.count("surprise") == 0
			# подколы предметами и праздник не ломают игру
			var used := 0
			for k in ["snowball", "tomato", "cushion", "firework", "confetti"]:
				if C.use_item(k, k):
					used += 1
			C.splat(Color(1, 0, 0, 0.8))
			C.bubble(game.player, "Ура!")
			var cmd_ok: bool = C.chat_command("/help") and C.chat_command("/roll")
			C.toggle_panel()
			var panel_ok: bool = C.panel_open()
			C.toggle_panel()
			# своя база: аванпост со стартовым набором; стройка берёт материалы оттуда
			var ob = null
			var why_base := ""
			for off in [Vector2i(-30, 30), Vector2i(30, 30), Vector2i(-30, -30), Vector2i(30, -30), Vector2i(0, 36)]:
				var base_c: Vector2i = hq + off
				why_base = f.can_place("outpost", base_c)
				ob = C.make_base(base_c, Vector2i.ZERO, "Друг")
				if ob != null:
					break
			if ob == null:
				print("DBG s16 base: ", why_base)
			var base_ok: bool = ob != null and ob.type == "outpost" and ob.inv.count("plank") >= 30 and Coop.owner_of(ob) == "Друг"
			f.personal = ob.inv if ob else null
			var av: int = f.available("plank")
			game.flags["free_build"] = false
			var pk0: int = ob.inv.count("plank") if ob else 0
			var hq_pk0: int = f.hq.inv.count("plank")
			var pinv: int = game.player.inv.count("plank")
			game.player.inv.take_up_to("plank", pinv)
			f.pay({"plank": 6})
			var paid_ok: bool = ob != null and ob.inv.count("plank") == pk0 - 6 and f.hq.inv.count("plank") == hq_pk0
			game.player.inv.add("plank", pinv)
			f.personal = null
			for i in 30:
				await tree.process_frame
			var ok: bool = no_mon and no_waves and code_ok and bought and sold and energy_ok and painted and cleaned and sign_ok and marked and boo and used == 5 and cmd_ok and panel_ok and base_ok and paid_ok and av >= 30
			print("TEST s16 no_monsters=", no_mon, " no_waves=", no_waves, " code=", code, " code_ok=", code_ok, " bought=", bought, " sold=", sold, " energy=", energy_ok, " pw_in=", snappedf(pw_in, 0.1),
				" paint=", painted, " clean=", cleaned, " sign=", sign_ok, " surprise=", marked and boo, " pranks=", used, " cmds=", cmd_ok, " panel=", panel_ok, " base=", base_ok, " paid_from_base=", paid_ok, " ",
				"OK" if ok else "FAIL")
		"s15":
			# 15: объединение по технологиям, энергия составных, излишек в сеть
			var f = game.factory
			var fz = f.fz
			var T = game.tech
			game.flags["free_build"] = true
			var hq: Vector2i = f.hq.cell
			var ore: Vector2i = nearest_deposit(game, "iron_ore", hq, [], 6.0)
			for dx in range(-3, 4):
				for dz in range(-3, 4):
					if Vector2i(dx, dz) != Vector2i.ZERO:
						game.world.remove_node(World.wc(ore + Vector2i(dx, dz)))
			var m = put(game, "miner", ore, 0)
			var wt = put(game, "wind_turbine", ore + Vector2i(0, 1), 0)
			game.flags["free_build"] = false
			for tid in ["t_fuse1", "t_fuse2", "t_fuse3", "t_fuse4"]:
				T.done.erase(tid)
			var t_block: bool = T.enabled() and fz.combo_why(m, wt).begins_with("Нужна технология")
			for tid in ["t_fuse1", "t_fuse2", "t_fuse3", "t_fuse4"]:
				T.done[tid] = true
			var t_ok: bool = fz.combo_why(m, wt) == ""
			game.flags["free_build"] = true
			game.cmd("fuse", {"a": m, "b": wt, "kind": "combo"})
			var out0: int = m.out.count(m.recipe)
			for step in int(30.0 / Factory.TICK):
				f._tick(Factory.TICK)
			var mined: int = m.out.count(m.recipe) - out0
			print("DBG s15 csat=", m.csat, " has_gen=", m.has_gen, " net=", m.net, " want=", m.want, " active=", m.active, " mined=", mined, " need=", fz._need(m), " recipe=", m.recipe)
			var self_power: bool = mined > 0 and m.csat > 0.9
			# излишек в сеть: провод от составного к сборщику; ветер ровный для проверки
			var asm = put(game, "assembler", ore + Vector2i(3, 0), 0)
			f.set_recipe(asm, "iron_plate")
			var wired: bool = f.add_wire(m, asm)
			f.power_dirty = true
			for step in int(5.0 / Factory.TICK):
				f._tick(Factory.TICK)
			var ni: Dictionary = f.net_info(asm)
			print("DBG net ", ni.get("supply"), "/", ni.get("demand"), " sat=", ni.get("sat"), " surplus=", m.surplus, " cgen=", m.cgen, " cneed=", m.cneed, " asm_need=", asm.p("power", 0))
			var exported: bool = wired and m.surplus > 0.0 and float(ni.get("supply", 0)) >= m.surplus - 0.01 and float(ni.get("demand", 0)) >= float(asm.p("power", 0)) - 0.01
			# потребление ровное: сборщик без сырья всё равно ест (пока включён)
			var steady: bool = float(ni.get("demand", 0)) > 0.0 and asm.crafting == ""
			# мощность 0–100%: 50% — вдвое медленнее и вдвое меньше энергии, «выключено» — ноль
			asm.cfg["clock"] = 50.0
			for step in 3:
				f._tick(Factory.TICK)
			var d50: float = float(f.net_info(asm).get("demand", 0.0))
			asm.cfg["off"] = true
			for step in 3:
				f._tick(Factory.TICK)
			var d0: float = float(f.net_info(asm).get("demand", 0.0))
			asm.cfg.erase("off")
			asm.cfg.erase("clock")
			var clock_ok: bool = is_equal_approx(d50, float(asm.p("power", 0)) * 0.5) and d0 < 0.01
			print("DBG clock d50=", d50, " d0=", d0)
			# бур + печь, рядом ещё печь: выбор «вторая отдельно» или «объединить со встроенной»
			var fu1 = put(game, "furnace", ore + Vector2i(-1, 0), 0)
			game.cmd("fuse", {"a": m, "b": fu1, "kind": "combo"})
			fz.offers.clear()
			var fu2 = game.cmd("place", {"type": "furnace", "cell": ore + Vector2i(-1, 0), "dir": 0})
			var choice: bool = fz.offers.size() > 0 and fz.offers[0].kind == "choice"
			game.cmd("fuse", {"a": m, "b": fu2, "kind": "sub"})
			var merged: bool = fu1.lvl == 2 and fu2.dead and fu1 in m.subs and m.subs.size() == 2
			# выход на ленту: только слитки
			f.set_recipe(fu1, "smelt_iron")
			var cands: Array = fz.out_candidates(m)
			m.cfg["out_items"] = ["iron_ingot"]
			m.out.add("stone", 3)
			var filt_ok: bool = "iron_ingot" in cands and not Fusion.out_ok(m, "stone") and Fusion.out_ok(m, "iron_ingot")
			# убрать встроенную печь — бур остаётся и работает
			var ingots0: int = game.player.inv.count("iron_ingot") + game.player.inv.count("stone")
			var detached: bool = game.cmd("detach", {"h": m, "s": fu1})
			var det_ok: bool = detached and not m.dead and m.subs.size() == 1 and fu1.dead and f.building_at(ore) == m
			# залежи селитры: хоть одна рядом (старт или сразу за ним)
			var wz = game.world
			var zr: float = wz._start_zone_cells()
			var near_salt := 0
			for dc in wz.deposit:
				if str(wz.deposits[wz.deposit[dc]].get("item", "")) == "saltpeter" and Vector2(dc - hq).length() < maxf(zr, 20.0) + 16.0:
					near_salt += 1
			# участок 5×5 по выбору: у края зоны — можно, внутри — нельзя, после открытия там светло
			var z = game.zone
			var edge_p: Vector3 = z.center + Vector3(z.half() + z.block_m() * 1.5, 0, 0)
			var rc: Vector2i = z.patch_at(edge_p)
			var inside_rc: Vector2i = z.patch_at(z.center)
			var far_rc: Vector2i = z.patch_at(z.center + Vector3(z.half() + 200.0, 0, 0))
			var why_in: String = z.patch_why(inside_rc)
			var why_far: String = z.patch_why(far_rc)
			var closed0: bool = not z.inside(edge_p)
			var opened: bool = game.cmd("zone_patch", {"rc": rc})
			var patch_ok: bool = why_in != "" and why_far != "" and closed0 and opened and z.inside(edge_p) and z.inside(z.patch_center(rc)) and z.to_dict().rects.size() == 1
			print("DBG zone why_in=", why_in, " why_far=", why_far, " closed0=", closed0, " opened=", opened, " salt=", near_salt)
			print("DBG sub choice=", choice, " merged=", merged, " lvl=", fu1.lvl, " cands=", cands, " det=", det_ok, " subs=", m.subs.size())
			print("TEST s15 t_block=", t_block, " t_ok=", t_ok, " self_power=", self_power, " exported=", exported, " steady=", steady, " clock=", clock_ok,
				" choice=", choice, " merged=", merged, " filter=", filt_ok, " detach=", det_ok, " salt=", near_salt, " patch=", patch_ok, " ",
				"OK" if t_block and t_ok and self_power and exported and steady and clock_ok and choice and merged and filt_ok and det_ok and near_salt > 0 and patch_ok else "FAIL")
		"fusion":
			# 14.10: объединение одинаковых (уровни) и составные здания (цепочка, своя энергия, сундук, турель)
			var f = game.factory
			var fz = f.fz
			game.flags["free_build"] = true
			var c: Vector2i = f.hq.cell + Vector2i(10, 6)
			for dx in range(-1, 8):
				for dz in range(-1, 8):
					game.world.remove_node(World.wc(c + Vector2i(dx, dz)))
			var a1 = game.cmd("place", {"type": "furnace", "cell": c, "dir": 0})
			var a2 = game.cmd("place", {"type": "furnace", "cell": c + Vector2i(1, 0), "dir": 0})
			var offered: bool = not fz.offers.is_empty() and fz.offers[0].kind == "level"
			var r1: float = f.rate_max(a1, "smelt_iron")
			game.cmd("fuse", {"a": a1, "b": a2, "kind": "level"})
			var lvl2: bool = a1.lvl == 2 and a2.dead and is_equal_approx(f.rate_max(a1, "smelt_iron"), r1 * 2.0)
			var a3 = game.cmd("place", {"type": "furnace", "cell": c + Vector2i(0, 1), "dir": 0})
			var a4 = game.cmd("place", {"type": "furnace", "cell": c + Vector2i(1, 1), "dir": 0})
			game.cmd("fuse", {"a": a3, "b": a4, "kind": "level"})
			var no_mix: bool = fz.level_why(a1, game.cmd("place", {"type": "furnace", "cell": c + Vector2i(-1, 0), "dir": 0})) != ""
			game.cmd("fuse", {"a": a1, "b": a3, "kind": "level"})
			var lvl3: bool = a1.lvl == 3 and a3.dead and a1.mult == 3.0 and a1.deco != null
			# составное: печь + сборщик (пластины) + ветряк + сундук; без проводов
			var c2: Vector2i = c + Vector2i(4, 4)
			var fu = put(game, "furnace", c2, 0)
			var asm = put(game, "assembler", c2 + Vector2i(1, 0), 0)
			var wt = put(game, "wind_turbine", c2 + Vector2i(0, 1), 0)
			var ch = put(game, "chest", c2 + Vector2i(-1, 0), 0)
			f.set_recipe(asm, "iron_plate")
			var c_ok: bool = fz.combo_why(fu, asm) == ""
			game.cmd("fuse", {"a": fu, "b": asm, "kind": "combo"})
			game.cmd("fuse", {"a": fu, "b": wt, "kind": "combo"})
			game.cmd("fuse", {"a": fu, "b": ch, "kind": "combo"})
			var built: bool = c_ok and fu.subs.size() == 3 and asm.dead == false and asm.host == fu and f.building_at(c2 + Vector2i(1, 0)) == null
			fu.inv.add("iron_ore", 20)
			f.accept(fu, "coal", null)   # печь-основа берёт топливо как обычно (14.21)
			fu.fuel.add("coal", 9)
			for step in int(60.0 / Factory.TICK):
				f._tick(Factory.TICK)
			var plates: int = ch.inv.count("iron_plate")
			var chain_ok: bool = plates >= 3 and fu.csat > 0.5 and fu.has_gen
			# турели: объединение бьёт сильнее, турель на крыше составного
			var t1 = put(game, "turret", c + Vector2i(6, 0), 0)
			var t2 = put(game, "turret", c + Vector2i(7, 0), 0)
			game.cmd("fuse", {"a": t1, "b": t2, "kind": "level"})
			var tur_ok: bool = t1.lvl == 2 and t1.mult == 2.0 and t1 in f.turrets and not t2 in f.turrets
			tur_ok = tur_ok and fz.can_level(put(game, "barrier_small", c + Vector2i(6, 5), 0))   # щит тоже объединяется
			var t3 = put(game, "turret", c2 + Vector2i(0, -1), 0)
			game.cmd("fuse", {"a": fu, "b": t3, "kind": "combo"})
			var roof: bool = t3.host == fu and t3 in f.turrets and t3.y > fu.y + 0.5
			var limit: bool = fz.combo_why(fu, put(game, "chest", c2 + Vector2i(1, 0), 0)) != ""   # уже 5 зданий
			# сохранение
			var sd: Dictionary = game.save_dict()
			game.load_game(sd)
			var la = f.building_at(c)
			var lf = f.building_at(c2)
			var saved: bool = la != null and la.lvl == 3 and lf != null and lf.subs.size() == 4 and lf.subs.any(func(x): return x.beh == "storage" and x.inv.count("iron_plate") == plates)
			# разбор возвращает всё
			var paid_before: int = game.player.inv.count("iron_ingot")
			game.flags["free_build"] = false
			game.cmd("demolish", {"cell": c2})
			var gone: bool = f.building_at(c2) == null and f.fz.hosts.is_empty() or not lf in f.fz.hosts
			print("TEST fusion offer=", offered, " lvl2=", lvl2, " no_mix=", no_mix, " lvl3=", lvl3, " built=", built, " plates=", plates, " chain=", chain_ok, " turret=", tur_ok, " roof=", roof, " limit=", limit, " saved=", saved, " gone=", gone, " ",
				"OK" if offered and lvl2 and no_mix and lvl3 and built and chain_ok and tur_ok and roof and limit and saved and gone else "FAIL")
		"steam":
			# Steam: без плагина всё работает, достижения считаются как задачи, оверлей ставит паузу
			var sb = game.get_node_or_null("/root/SteamBridge")
			var achs: Array = DB.data.settings.get("steam", {}).get("achievements", [])
			var off: bool = sb != null and not sb.on_steam
			sb.got.clear()
			sb._check_achievements()
			var none_early: bool = not sb.got.has("ACH_VICTORY") and not sb.got.has("ACH_WAVES_10")
			game.victory = true
			game.enemies.waves_survived = 20   # 18: «Рубеж удержан» — за 20 волн (победы больше нет, волны бесконечные)
			sb._check_achievements()
			var got_late: bool = sb.got.has("ACH_VICTORY") and sb.got.has("ACH_WAVES_10") and sb.got.has("ACH_FIRST_WAVE")
			var keys := {}
			for a in achs:
				keys[str(a.api)] = true
			game.paused = false
			sb._on_overlay(true, true, 0)
			var p1: bool = game.paused
			sb._on_overlay(false, true, 0)
			var p2: bool = game.paused
			print("TEST steam off=", off, " achs=", achs.size(), " unique=", keys.size() == achs.size(), " early=", none_early, " late=", got_late, " overlay=", p1, "/", p2, " ",
				"OK" if off and achs.size() >= 10 and keys.size() == achs.size() and none_early and got_late and p1 and not p2 else "FAIL")
		"tutorial":
			# 13.10: рюкзак растёт за ресурсы, новый вид окон и подсказок, обучение для новичков
			var pl = game.player
			var size0: int = pl.inv.size()
			var st0: Dictionary = Player.bag_next(0)
			var nores = game.cmd("bag_up", {})
			for it in st0.get("cost", {}):
				pl.inv.add(it, int(st0.cost[it]))
			var up = game.cmd("bag_up", {})
			var paid := true
			for it in st0.get("cost", {}):
				if pl.inv.count(it) > 0:
					paid = false
			game.hud.open("inventory")
			game.hud._refresh_inventory()
			var bag_ok: bool = nores == null and up == true and pl.bag_level == 1 and pl.inv.size() == size0 + int(st0.get("add", 9)) and paid and game.hud.inv_slots.size() == pl.inv.size()
			pl.inv.add("stone", 3)
			var sd: Dictionary = game.save_dict()
			pl.bag_level = 0
			game.load_game(sd)
			var bag_save: bool = pl.bag_level == 1 and pl.inv.size() == size0 + int(st0.get("add", 9))
			# интерфейс
			var tip := UI.item_tip("stone")
			var btip := UI.building_tip("miner")
			var tp := UI.tip_panel(btip)
			var ui_ok: bool = UI.SCALE > 1.0 and tip.contains("Нужен для") and btip.contains("Добыча") and btip.contains("Цена") and tp.get_child_count() >= 4 and UI.header_box().get_meta("fill", false)
			tp.free()
			# обучение
			var tu = game.tutorial
			tu.done = false
			tu.restart()
			var t0: bool = tu.active and tu.step == 0 and tu.card.visible
			tu.next_step()
			var on_move: bool = str(tu.cur().get("goal", "")) == "move"
			for k in 40:
				pl.position.x += 1.0
				tu._process(0.05)
			for k in 10:
				tu._process(0.2)
			var moved: bool = tu.step >= 2   # шаг «сканер» без сканера засчитывается сам
			tu.skip()
			var sd2: Dictionary = game.save_dict()
			game.load_game(sd2)
			var skipped: bool = not tu.active and tu.done and not tu.card.visible
			tu.restart()
			var tut_ok: bool = t0 and on_move and moved and skipped and tu.active and tu.step == 0
			print("TEST tutorial bag=", bag_ok, " bag_save=", bag_save, " ui=", ui_ok, " tut=", [t0, on_move, moved, skipped], " ", "OK" if bag_ok and bag_save and ui_ok and tut_ok else "FAIL")
		"split3":
			# 13.10: разветвитель делит поровну на 3 выхода; занятый выход обходится — не ждём его
			var f = game.factory
			var c: Vector2i = f.hq.cell + Vector2i(8, -10)
			var sp = put(game, "splitter", c, 0)
			var left = put(game, "chest", c + Vector2i(0, -1), 3)
			var right = put(game, "chest", c + Vector2i(0, 1), 1)
			var front = put(game, "chest", c + Vector2i(1, 0), 0)
			var fed := 0
			for step in int(6.0 / Factory.TICK):
				if sp.item == "" and f.accept(sp, "stone", null):
					fed += 1
				f._tick(Factory.TICK)
			var l0: int = left.inv.count("stone")
			var r0: int = right.inv.count("stone")
			var f0: int = front.inv.count("stone")
			var equal: bool = fed >= 60 and maxi(l0, maxi(r0, f0)) - mini(l0, mini(r0, f0)) <= 2
			# передний выход — тупиковая лента: забьётся, дальше всё идёт налево и направо без задержек
			f.remove(front)
			var b1 = put(game, "belt", c + Vector2i(1, 0), 0)
			var b2 = put(game, "belt", c + Vector2i(2, 0), 0)
			var fed2 := 0
			var l1: int = left.inv.count("stone")
			var r1: int = right.inv.count("stone")
			for step in int(6.0 / Factory.TICK):
				if sp.item == "" and f.accept(sp, "stone", null):
					fed2 += 1
				f._tick(Factory.TICK)
			var sides: int = left.inv.count("stone") - l1 + right.inv.count("stone") - r1
			var bypass: bool = fed2 >= 60 and sides >= fed2 - 4 and absi((left.inv.count("stone") - l1) - (right.inv.count("stone") - r1)) <= 2
			print("TEST split3 fed=", fed, " l/f/r=", l0, "/", f0, "/", r0, " | blocked_front fed=", fed2, " sides=", sides, " ", "OK" if equal and bypass else "FAIL")
		"merge":
			var m: Vector2i = game.factory.hq.cell + Vector2i(8, -8)
			var mg = put(game, "merger", m, 0)
			var outc = put(game, "chest", m + Vector2i(1, 0), 0)
			put(game, "belt", m + Vector2i(-1, 0), 0)
			var a = put(game, "chest", m + Vector2i(-2, 0), 0)
			put(game, "belt", m + Vector2i(0, -1), 1)
			var bb = put(game, "chest", m + Vector2i(0, -2), 1)
			a.inv.add("stone", 30)
			bb.inv.add("log", 30)
			await tree.create_timer(6.0).timeout
			var s1: int = outc.inv.count("stone")
			var l1: int = outc.inv.count("log")
			# умный: главный вход сзади (камень)
			var c2: Vector2i = m + Vector2i(0, 8)
			var sm = put(game, "smart_merger", c2, 0)
			var out2 = put(game, "chest", c2 + Vector2i(1, 0), 0)
			put(game, "belt", c2 + Vector2i(-1, 0), 0)
			var a2 = put(game, "chest", c2 + Vector2i(-2, 0), 0)
			put(game, "belt", c2 + Vector2i(0, -1), 1)
			var b2 = put(game, "chest", c2 + Vector2i(0, -2), 1)
			game.cmd("bcfg", {"b": sm, "cfg": {"prio": 2}})
			a2.inv.add("stone", 200)
			b2.inv.add("log", 200)
			await tree.create_timer(6.0).timeout
			var s2: int = out2.inv.count("stone")
			var l2: int = out2.inv.count("log")
			var fair: bool = s1 > 3 and l1 > 3 and absi(s1 - l1) <= maxi(3, (s1 + l1) / 4)
			var prio_ok: bool = s2 > 3 and l2 * 3 < s2
			print("TEST merge fair stone=", s1, " log=", l1, " | prio stone=", s2, " log=", l2, " ", "OK" if fair and prio_ok else "FAIL")
		"blocks":
			var f = game.factory
			var base: Vector2i = f.hq.cell + Vector2i(8, -10)
			DB.data.buildings["t_prod"] = {"name": "t", "behavior": "decor", "model": "crate", "hp": 100, "size": 1, "params": {},
				"blocks": [{"type": "produce", "item": "stone", "n": 1, "every": 0.5}]}
			DB.data.buildings["t_conv"] = {"name": "t", "behavior": "decor", "model": "crate", "hp": 100, "size": 1, "params": {},
				"blocks": [{"type": "convert", "in": {"stone": 2}, "out": {"concrete": 1}, "time": 0.5},
					{"type": "trigger", "event": "every", "every": 1.0, "actions": [{"do": "credits", "n": "5"}]},
					{"type": "trigger", "event": "placed", "actions": [{"do": "give", "item": "fang", "n": "1"}]}]}
			# производство → лента → переработка → лента → ящик
			var pr = put(game, "t_prod", base, 0)
			put(game, "belt", base + Vector2i(1, 0), 0)
			var cv = put(game, "t_conv", base + Vector2i(2, 0), 0)
			put(game, "belt", base + Vector2i(3, 0), 0)
			var box = put(game, "chest", base + Vector2i(4, 0), 0)
			# рынок: продаёт положенное
			var mk = put(game, "market", base + Vector2i(0, 3), 0)
			for i in 10:
				f.accept(mk, "iron_ingot", null)
			# котёл + медпункт рядом с героем
			var pc: Vector2i = World.world_to_cell(game.player.position)
			var boiler = put(game, "wood_boiler", pc + Vector2i(2, 2), 0)
			var med = put(game, "medbay", pc + Vector2i(-2, 2), 0)
			f.accept(boiler, "log", null)
			game.player.hp = 40.0
			# мина
			var mine = put(game, "trap_mine", base + Vector2i(0, 6), 0)
			var cr0 = game.enemies.spawn("crawler", World.cell_to_world(base + Vector2i(1, 6)))
			var cr_hp: float = cr0.hp
			var cr1 = game.enemies.spawn("crawler", game.player.position + Vector3(2, 0, 0))
			var cr1_hp: float = cr1.hp
			var cr1_ref = weakref(cr1)
			var c0: int = game.credits
			var fang0: int = game.player.inv.count("fang")
			# предметы с действиями
			var st0: int = game.player.inv.count("stone")
			game.player.inv.add("lucky_box", 1)
			game.player.use_item(game.player.inv.slots.find(game.player.inv.slots.filter(func(x): return x != null and x.id == "lucky_box")[0]))
			var st1: int = game.player.inv.count("stone")
			game.player.inv.add("grenade", 1)
			game.player.use_item(game.player.inv.slots.find(game.player.inv.slots.filter(func(x): return x != null and x.id == "grenade")[0]))
			var gren_ok: bool = not cr1.alive or cr1.hp < cr1_hp
			await tree.create_timer(6.0).timeout
			var prod_ok: bool = box.inv.count("concrete") > 0
			var credits_gain: int = game.credits - c0
			var sell_ok: bool = mk.inv.first_item() == "" and credits_gain >= 10 * game.sell_price("iron_ingot") * 0.8 - 1
			var mine_ok: bool = not cr0.alive or cr0.hp < cr_hp
			var power_ok: bool = boiler.active and f._sat(med) > 0.0 and game.player.hp > 40.0
			print("TEST blocks prod=", box.inv.count("concrete"), " credits+", credits_gain, " sell=", sell_ok, " mine=", mine_ok,
				" boiler=", boiler.active, " hp=", int(game.player.hp), " lucky=", st1 - st0, " grenade=", gren_ok, " placed_fang=", fang0,
				" ", "OK" if prod_ok and sell_ok and mine_ok and power_ok and st1 - st0 >= 5 and gren_ok and fang0 >= 1 else "FAIL")
		"hotbar":
			Prefs.values["hotbar_slots"] = 12
			Prefs.values["hotbar_size"] = 64
			await tree.process_frame
			await tree.create_timer(0.5).timeout
			var n_ok: bool = game.hud.hotbar_slots.size() == 12 and game.hud.hotbar_slots[0].custom_minimum_size.x == 64
			game.player.inv.slots[9] = null
			game.hud.pin_build("belt", 9)
			game.player.inv.add("stone", 500)
			var avoid_ok: bool = game.player.inv.slots[9] == null
			game.hot_select(9)
			var build_ok: bool = game.build_type == "belt"
			game.player.inv.slots[0] = {"id": "stone_axe", "n": 1}
			game.hot_select(0)
			var item_ok: bool = game.build_type == "" and game.player.selected_item() == "stone_axe"
			game.save_game("hb_test")
			game.player.hot_builds.clear()
			game.load_game(DB.read_file(DB.saves_dir().path_join("hb_test.json")))
			var save_ok: bool = game.player.hot_builds.get(9, "") == "belt"
			DirAccess.remove_absolute(DB.saves_dir().path_join("hb_test.json"))
			Prefs.values.erase("hotbar_slots")
			Prefs.values.erase("hotbar_size")
			await tree.create_timer(0.5).timeout
			var back_ok: bool = game.hud.hotbar_slots.size() == 9
			print("TEST hotbar size=", n_ok, " avoid=", avoid_ok, " build=", build_ok, " item=", item_ok, " save=", save_ok, " back9=", back_ok, " ",
				"OK" if n_ok and avoid_ok and build_ok and item_ok and save_ok and back_ok else "FAIL")
		"saveload2":
			var f = game.factory
			# шахта на руде, гнездо уничтожено, топор с износом, лента с грузом
			var hq: Vector2i = f.hq.cell
			var ore := nearest_deposit(game, "iron_ore", hq)
			var mn = put(game, "miner", ore, 0)
			# 13.10: гнёзд больше нет — награду за гнездо проверяем, только если карта их задаёт
			if not game.world.nests.is_empty():
				var n0 = game.world.nests[0]
				n0.hp = 1.0
				game.damage_nest(n0, 5.0)
			game.player.inv.slots[20] = {"id": "iron_axe", "n": 1, "dur": 33.0}
			var bt = put(game, "belt", hq + Vector2i(6, 6), 0)
			f.set_item(bt, "coal")
			game.craft_queue.append({"rid": "rope", "t": 0.5, "station": "hand"})
			game.save_game("sl2")
			var d = DB.read_file(DB.saves_dir().path_join("sl2.json"))
			# «Продолжить» строит ту же карту
			var w2 := World.new()
			w2.load_map(d.map)
			var same_map: bool = w2.deposit_item(ore) == "iron_ore" and w2.nests.size() == game.world.nests.size()
			w2.free()
			# повторная загрузка в ту же игру: награда за гнездо не платится второй раз
			var c0: int = game.credits
			game.credits = 0
			game.load_game(d)
			var no_reward: bool = game.credits == int(d.credits)
			var dur_ok: bool = game.player.inv.slots[20] != null and float(game.player.inv.slots[20].get("dur", -1)) == 33.0 and typeof(game.player.inv.slots[20].n) == TYPE_INT
			var q_ok: bool = game.craft_queue.size() >= 1
			# возврат ресурсов при разборе — ровно то, что заплачено
			game.flags["free_build"] = false
			var cost: Dictionary = game._scaled_cost("chest")
			for k in cost:
				f.hq.inv.add(k, cost[k] * 3)
			var before: int = f.available("plank")
			# свободная клетка рядом (карта случайная: там может оказаться залежь или камень)
			var cc: Vector2i = hq + Vector2i(-6, -6)
			for k in 40:
				if f.can_place("chest", cc) == "":
					break
				cc = hq + Vector2i(-6 - k % 7, -6 - k / 7)
			var ch = game.cmd("place", {"type": "chest", "cell": cc, "dir": 0})
			game.cmd("demolish", {"cell": cc})
			var refund_ok: bool = ch != null and f.available("plank") == before
			DirAccess.remove_absolute(DB.saves_dir().path_join("sl2.json"))
			print("TEST saveload2 same_map=", same_map, " no_double_reward=", no_reward, " dur=", dur_ok, " queue=", q_ok, " refund=", refund_ok, " ",
				"OK" if same_map and no_reward and dur_ok and q_ok and refund_ok else "FAIL")
		"waves0":
			for n in game.world.nests:
				game.kill_nest_silent(n)
			game.enemies.wave_timer = 0.0
			await tree.create_timer(1.0).timeout
			var w: int = game.enemies.wave
			print("TEST waves0 wave=", w, " ", "OK" if w <= 1 else "FAIL")
		"content":
			var kinds := []
			for l in DB.layers:
				kinds.append("%s:%s" % [l.kind, l.id])
			var ok: bool = not DB.studio and DB.layers.size() > 0 and DB.layers[0].kind == "game"
			print("TEST content layers=", kinds, " game=", DB.game_name(), " v", DB.game_version(), " items=", DB.data.items.size(),
				" dlc_gem=", DB.data.items.has("dlc_gem"), " my_tree=", DB.data.models.has("my_test_model"), " errors=", DB.errors, " ", "OK" if ok else "FAIL")
		"smart_ui":
			var c: Vector2i = World.world_to_cell(game.player.position) + Vector2i(3, 0)
			var sp = put(game, "smart_splitter", c, 0)
			game.cmd("bcfg", {"b": sp, "cfg": {"outs": {"0": {"mode": "rest"}, "3": {"mode": "items", "items": ["iron_ore", "copper_ore"]}, "1": {"mode": "overflow"}}}})
			game.hud.open_building(sp)
			await tree.create_timer(30.0).timeout
		"dump":
			build(game)
			var hq: Vector2i = game.factory.hq.cell
			print("TEST dump hq=", hq, " W=", game.world.W, " deposits=", game.world.deposit.size(), " nodes=", game.world.nodes.size())
			for b in game.factory.all:
				print("  ", b.type, " ", b.cell - hq, " dir=", b.dir, " kind=", b.kind)
			for k in game.factory.renderers:
				var r = game.factory.renderers[k]
				print("  R ", k, " count=", r.count() if r.has_method("count") else "?")
		"save":
			game.save_game("test")
			var d = DB.read_file(DB.saves_dir().path_join("test.json"))
			print("TEST save ", "OK" if d is Dictionary and d.buildings.size() > 0 else "FAIL")


## 1.3: поза героя → GLB: кожа считается на процессоре (вершины × веса костей), прочие детали
## (инструмент в руке, оружие) — их сетки в мировых координатах героя. Материалы — простые с текстурой/цветом.
static func _export_hero(pl: Node3D, path: String) -> bool:
	var root := Node3D.new()
	root.name = "hero"
	var inv_root: Transform3D = pl.global_transform.affine_inverse()
	var stack: Array = [pl]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if not (n is GeometryInstance3D) or not (n as Node3D).is_visible_in_tree():
			continue
		var xf: Transform3D = inv_root * (n as Node3D).global_transform
		if n is MeshInstance3D and (n as MeshInstance3D).skin != null:
			var mi := n as MeshInstance3D
			var sk: Skeleton3D = mi.get_node(mi.skeleton)
			var m := _bake_skin(mi.mesh, mi.skin, sk)
			var o := MeshInstance3D.new()
			o.name = "skin"
			o.mesh = m
			o.material_override = _plain_mat(mi.material_override, Color.WHITE)
			o.transform = inv_root * sk.global_transform
			root.add_child(o)
		elif n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh:
			var mm := (n as MultiMeshInstance3D).multimesh
			for i in mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count:
				var o := MeshInstance3D.new()
				o.mesh = mm.mesh
				o.transform = xf * mm.get_instance_transform(i)
				o.material_override = _plain_mat((n as GeometryInstance3D).material_override, mm.get_instance_color(i) if mm.use_colors else Color.WHITE)
				root.add_child(o)
		elif n is MeshInstance3D and (n as MeshInstance3D).mesh:
			var o := MeshInstance3D.new()
			o.mesh = (n as MeshInstance3D).mesh
			o.transform = xf
			o.material_override = _plain_mat((n as GeometryInstance3D).material_override, Color.WHITE)
			root.add_child(o)
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	var err := doc.append_from_scene(root, st)
	if err == OK:
		err = doc.write_to_filesystem(st, path)
	root.free()
	return err == OK


static func _plain_mat(src: Material, col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(col.r, col.g, col.b)
	m.roughness = 0.6
	if src is ShaderMaterial and (src as ShaderMaterial).shader:
		for u in (src as ShaderMaterial).shader.get_shader_uniform_list():
			var v = (src as ShaderMaterial).get_shader_parameter(u.name)
			if v is Texture2D and m.albedo_texture == null and not str(u.name).contains("noise"):
				m.albedo_texture = v
	elif src is StandardMaterial3D:
		m.albedo_texture = (src as StandardMaterial3D).albedo_texture
		m.albedo_color = (src as StandardMaterial3D).albedo_color * col
	m.vertex_color_use_as_albedo = m.albedo_texture == null
	return m


static func _bake_skin(mesh: Mesh, skin: Skin, sk: Skeleton3D) -> ArrayMesh:
	var mats := []
	for bi in skin.get_bind_count():
		var bone := sk.find_bone(skin.get_bind_name(bi)) if skin.get_bind_name(bi) != &"" else skin.get_bind_bone(bi)
		mats.append(sk.get_bone_global_pose(bone) * skin.get_bind_pose(bi))
	var out := ArrayMesh.new()
	for si in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(si)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ns = arr[Mesh.ARRAY_NORMAL]
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var ws: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var k := bones.size() / maxi(1, vs.size())
		for vi in vs.size():
			var p := Vector3.ZERO
			var nn := Vector3.ZERO
			for j in k:
				var w := ws[vi * k + j]
				if w <= 0.0:
					continue
				var t: Transform3D = mats[bones[vi * k + j]]
				p += (t * vs[vi]) * w
				if ns is PackedVector3Array:
					nn += (t.basis * ns[vi]) * w
			vs[vi] = p
			if ns is PackedVector3Array:
				ns[vi] = nn.normalized()
		arr[Mesh.ARRAY_VERTEX] = vs
		if ns is PackedVector3Array:
			arr[Mesh.ARRAY_NORMAL] = ns
		arr[Mesh.ARRAY_BONES] = null
		arr[Mesh.ARRAY_WEIGHTS] = null
		arr[Mesh.ARRAY_TANGENT] = null
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return out
