extends Node

var failures := []
var count := 0

func verify(label: String, condition: bool) -> void:
	count += 1
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	call_deferred("check")


func check() -> void:
	DB.set_meta("new_game", {"seed": 72810})
	var game = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	game.flags["free_build"] = true
	var w = game.world
	var f = game.factory
	var base: Vector2i = f.hq.cell
	var port = DemoSetup.put_near(game, "drone_port", base + Vector2i(5, 4))
	var dock = DemoSetup.put_near(game, "drone_dock", base + Vector2i(-6, 4))
	verify("stations placed", port != null and dock != null)
	if port and dock:
		verify("2x2 and two independent ports", port.size == 2 and dock.size == 2 and port.pin.size() == 2 and dock.pout.size() == 2 and port.pin[0] != port.pin[1] and dock.pout[0] != dock.pout[1])
		for cell in dock.pout:
			DemoSetup.put(game, "belt", cell, dock.dir)
		f._link(dock)
		dock.out.add("iron_plate", 2)
		f._push_out(dock)
		f._push_out(dock)
		verify("both belts physically receive", dock.nexts.size() == 2 and dock.nexts.all(func(b): return b.item == "iron_plate"))
		for number in [1,10,100,1000]:
			var minted: int = number - f.hq.inv.add("freighter_2", number)
			var assigned: int = game.carriers.assign(port, 1, number)
			verify("assign manufactured drones " + str(number), minted == number and assigned == number and game.carriers.fleet(port)[1] == number)
			var recalled: int = game.carriers.recall(port, 1, number)
			verify("recall returns fleet " + str(number), recalled == number and game.carriers.fleet(port)[1] == 0)
			f.pay({"freighter_2":number})
		port.bstate["freighters"] = [1000, 10, 2, 3, 1]
		verify("mixed fleet capacity", game.carriers.fleet_capacity(port) == 10550)
		game.carriers.launch(port, dock, "iron_plate", 13, "drone_carrier", 2, false)
		game.carriers.flights.back().sl = [{"id":"iron_plate", "n":13}]
		game.carriers.update(0.2)
		var data: Dictionary = JSON.parse_string(JSON.stringify(game.save_dict()))
		verify("autosave keeps flight moving", data.carriers.size() == 1 and game.carriers.flights.size() == 1 and dock.out.count("iron_plate") == 0)
		game.carriers.restore_flights(data.carriers)
		game.carriers.update(200)
		verify("cargo delivered once after reload", dock.out.count("iron_plate") == 13 and game.carriers.flights.is_empty())
	var pl = game.player
	pl.inv.add("iron_plate", 1)
	pl.pin_item(3, "iron_plate")
	pl.selected = 3
	var old_count: int = pl.inv.count("iron_plate")
	var real_slot: int = pl.hot_slot(3)
	var other_slot: int = pl.inv.size() - 1
	pl.inv.swap(real_slot, other_slot)
	verify("hotbar tracks item across bag moves", pl.selected_item() == "iron_plate" and pl.inv.count("iron_plate") == old_count)
	game.hud.pin_build("belt", 3)
	verify("building shortcut preserves inventory", pl.hot_slot(3) == -1 and pl.inv.count("iron_plate") == old_count)
	var landmarks: Array = f.all.filter(func(b): return b.type == "orbital_elevator")
	verify("one orbital elevator", landmarks.size() == 1)
	if landmarks.size() == 1:
		var terminal = landmarks.front()
		terminal.bstate["surveyed"] = true
		var stage_count: int = DB.setting("orbital_terminal", {}).repair.size()
		var req: Dictionary = game.star.orbital_order(terminal).need
		terminal.inv.add("iron_plate", 1)
		game.star._service_elevator(terminal)
		verify("unpowered elevator holds stock", terminal.inv.count("iron_plate") == 1)
		var first_pole = f.place("pole", terminal.cell - Vector2i(1, 0), 0)
		f._rebuild_nets()
		verify("20 kW pole signals capacity shortage", terminal.pw_state == 2 and first_pole.net >= 0)
		var local_pole = f.place("pole_mk2", terminal.cell + Vector2i(0, -1), 0)
		var generator = f.place("generator", terminal.cell - Vector2i(3, 0), 0)
		generator.fuel_t = 100
		f._rebuild_nets()
		f._power(0.1)
		verify("elevator powered by grid", local_pole.net == terminal.net and f.sat_c(terminal) >= 0.99)
		for step in stage_count:
			for item in req:
				terminal.inv.add(item, int(req[item]))
			game.star._service_elevator(terminal)
			verify("physical delivery repair " + str(step + 1), game.star.stage(terminal) == step + 1)
			req = game.star.orbital_order(terminal).get("need", {})
		if game.star.stage(terminal) == stage_count:
			terminal.bstate["mission"] = 0
			var order: Dictionary = game.star.orbital_order(terminal)
			var before: int = game.credits
			for item in order.need:
				terminal.inv.add(item, int(order.need[item]))
			game.star._service_elevator(terminal)
			verify("real shipment pays once", game.credits == before + int(order.credits) and int(terminal.bstate.get("shipments", 0)) == 1)
	var balance := preload("res://scripts/balance_preset.gd")
	var preset: Dictionary = balance.capture(DB.data)
	verify("preset validates", balance.issue(preset) == "")
	preset.tables.buildings.furnace.cost["missing_item"] = 1
	verify("invalid preset rejected", balance.issue(preset) != "")
	var price := 1000
	for target in [1500, 2250, 3400, 5100, 7650, 11500]:
		price = World.next_order_price(price)
		verify("orbital price " + str(target), price == target)
	for step in 45:
		price = World.next_order_price(price)
	verify("price cap", price == 500000)
	game.credits = 10000
	var idx := -1
	for i in w.deposits.size():
		if not w.deposit_hidden(i):
			idx = i
			break
	var found := false
	if idx >= 0:
		for dx in range(-25, 25):
			for dz in range(-25, 25):
				var cell := World.wc(base + Vector2i(dx, dz))
				if w.order_issue(idx, cell) != "":
					continue
				found = w.order_field(idx, cell)
				if not found:
					continue
				var map: Dictionary = JSON.parse_string(JSON.stringify(w.to_map()))
				verify("purchase charged and serialized", game.credits == 9000 and w.order_price == 1500 and not map.is_empty() and w.ordered_fields.has(cell))
				verify("duplicate rejected", not w.order_field(idx, cell) and game.credits == 9000)
				verify("free removal", w.remove_field(cell) and game.credits == 9000 and w.order_price == 1500 and not w.deposit.has(cell))
				break
			if found:
				break
	verify("suitable orbital site", found)
	print("COLONY_QA checks=", count, " failures=", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
