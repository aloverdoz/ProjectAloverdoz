extends RefCounted

static var failures := PackedStringArray()
static func check(label: String, ok: bool) -> void:
	print("OCEAN ", "OK " if ok else "FAIL ",label)
	if not ok: failures.append(label)

static func run(g) -> void:
	var w = g.world
	var f = g.factory
	var island = g.island
	var c: Vector2i = w.center
	if DB.has_meta("shore_test_reload"):
		check("reloaded island, rod, slab and custom price",w.island_cells.size()==25 and g.player.inv.count("salvage_rod")==1 and f.hq.type=="tide_slab" and island.cost(1)=={"log":2})
		check("deadline and partial offering persisted",island.due==21 and island.paid.get("branch")==1)
		check("extinguished fire persists",f.grid[c+Vector2i(0,2)].bstate.get("extinguished",false))
		g.day_n = 21
		island.deadline()
		check("5x5 -> 3x3 and overlapping buildings removed",w.island_cells.size()==9 and f.hq != null and not f.grid.has(c+Vector2i(0,2)) and not f.grid.has(c+Vector2i(1,1)))
		island.deadline()
		check("deadline is idempotent",w.island_cells.size()==9 and island.due==31)
		var added := []
		for x in range(-4,6):
			for y in range(-3,4):
				var p := c+Vector2i(x,y)
				if not w.island_cells.has(p): added.append(p)
		island.change_land(added,[])
		island.change_land([],island.shore.duplicate())
		check("10x7 -> 8x5",w.island_cells.size()==40 and w.island_cells.has(c+Vector2i(4,2)))
		island.change_land([],[c+Vector2i(2,0)])
		check("inland water and cardinal neighbours",c+Vector2i(1,0) in island.shore and c+Vector2i(1,1) not in island.shore)
		var remote := Vector2i(-5000001,5000001)
		island.change_land([remote],[])
		g.player.inv.add("log",50)
		g.player.inv.add("stone",50)
		# Custom distant rows are charged by the same placement command.
		island.set_price(island.ring(remote+Vector2i.RIGHT),{"log":1})
		check("normal purchase beyond ten-million-wide coordinates",g.cmd("shore_expand",{"cell":remote+Vector2i.RIGHT})==true)
		w.center_chart(World.cell_to_world(remote))
		w.set_deposit(remote,0)
		w.set_occupied(remote,true)
		check("distant land, ocean, ore, height and local chart",not w.water_at(remote) and w.water_at(remote+Vector2i.DOWN) and w.deposit.has(remote) and w.h_cell(remote)>.7 and w.water.get_pixelv(remote-w.chart_origin).r<.1)
		var snapshot: Dictionary = JSON.parse_string(JSON.stringify(w.to_map()))
		var clone := World.new()
		clone.ocean=true
		clone.game=g
		g.add_child(clone)
		clone.load_map(snapshot)
		check("distant positive and negative coordinates survive sparse save",clone.island_cells.has(remote) and clone.island_cells.has(remote+Vector2i.RIGHT) and clone.deposit.has(remote))
		clone.queue_free()
		island.change_land([],w.island_cells.keys().filter(func(v): return not (abs(v.x-c.x)<=2 and abs(v.y-c.y)<=2)))
		var home := []
		for xx in range(-2,3):
			for yy in range(-2,3):
				if not w.island_cells.has(c+Vector2i(xx,yy)): home.append(c+Vector2i(xx,yy))
		island.change_land(home,[])
		island.prices.clear()
		f.hq.inv.add("leaves",375)
		var total := 0
		for radius in range(3,11):
			for corners in [false,true]:
				for x in range(-radius,mini(radius+1,10)):
					for y in range(-radius,mini(radius+1,10)):
						if maxi(absi(x),absi(y))!=radius or (absi(x)==radius and absi(y)==radius)!=corners: continue
						if g.cmd("shore_expand",{"cell":c+Vector2i(x,y)})==true: total+=1
		check("5x5 to 20x20: 375 purchases at one common material each",total==375 and w.island_cells.size()==400)
		check("default costs increase after the early rows",island.cost(9).size()==2 and int(island.cost(20).log)>int(island.cost(9).log))
		print("OCEAN RESULT failures=",failures)
		g.get_tree().quit(0 if failures.is_empty() else 1)
		return
	check("new island and two harvestable trees",w.island_cells.size()==25 and w.nodes.size()==2 and w.nests.is_empty() and w.ground_chunks.size()<=4 and w.islands_by_chunk.size()==w.ground_chunks.size())
	check("occupied centre and dry player spawn",f.hq.type=="tide_slab" and f.hq.size==1 and w.island_cells.has(World.world_to_cell(g.player.position)) and g.player.selected_item()=="salvage_rod")
	check("no diagonal expansion",island.issue(c+Vector2i(3,3))!="")
	g.admin.host_act("shore_price",{"ring":1,"cost":{"log":2}},1)
	g.player.inv.add("log",2)
	var edge := c+Vector2i(3,1)
	g.ui_action("zone_pick")
	g.hover_cell = edge
	g._click_world()
	g.cancel_build()
	check("world click charges configured price once",w.island_cells.has(edge) and g.player.inv.count("log")==0 and not island.expand(edge) and island.ring(c+Vector2i(4,0))==2)
	island.change_land([],[edge])
	var fish = island.fishing
	for d in fish.drift.duplicate():
		d.node.queue_free()
		fish.drift.erase(d)
	fish.spawn_timer = 1000.
	var sea := World.cell_to_world(c+Vector2i(0,4))
	check("only shipping containers drift",fish.add("leaves",sea,0.).is_empty())
	var crate: Dictionary = fish.add("crate",sea,.3)
	fish.tick(.45)
	var surface: Vector3 = w.ocean_surface(crate.node.position,fish.clock)
	check("cargo waterline and tilt match the visible swell",absf(crate.node.position.y-surface.x-.09)<.001 and crate.node.basis.y.dot(Vector3(-surface.y,1.,-surface.z).normalized())>.999)
	var before: Dictionary = g.player.inv.totals()
	g.hover_point = sea
	g._click_world()
	fish.tick(1.)
	g._click_world()
	fish.tick(3.)
	var received := {}
	for id in fish.GOODS:
		var gain: int = g.player.inv.count(id)-int(before.get(id,0))
		if gain>0: received[id]=gain
	check("crate reeled in and credited once",fish.by_id(crate.id).is_empty() and received.size()>=3 and received.size()<=5 and received.values().all(func(v): return v>=5 and v<=15))
	for id in received: g.player.inv.remove(id,received[id])
	g._click_world()
	fish.tick(1.)
	fish.tick(float(fish.lines[g.player].bite)+.15)
	g._click_world()
	fish.tick(3.)
	check("fish hooked on bite",g.player.inv.count("reef_fish")==1)
	g.player.food = 10.
	for i in g.player.inv.size():
		var s = g.player.inv.slots[i]
		if s != null and s.id=="reef_fish":
			g.cmd("use_item",{"si":i,"sid":"reef_fish"})
	check("catch can be eaten",g.player.food>10. and g.player.inv.count("reef_fish")==0)
	var kinds := {}
	var limits_ok := true
	for kind in fish.TYPES:
		for i in 150:
			var roll: Dictionary = fish.loot(kind)
			limits_ok = limits_ok and roll.size()>=3 and roll.size()<=5 and roll.values().all(func(v): return v>=5 and v<=15)
			for k in roll: kinds[k]=true
	check("300 crate/barrel rolls: 3–5 unique kinds, 5–15 each, all nine eligible",limits_ok and kinds.size()==9 and not kinds.has("plank"))
	var dry: Vector3 = World.cell_to_world(c+Vector2i(2,0))
	dry.y = .76
	var wet := dry+Vector3.RIGHT*2.
	var original: Vector3 = g.player.position
	g.player.position = dry
	check("walking and jumping off the edge are blocked",g.player._blocked(wet))
	g.player.position = wet+Vector3.RIGHT*3.
	g.player.position.y = -.36
	g.player._unstuck()
	check("in water can swim toward land",g.player.in_water() and not g.player._blocked(g.player.position+Vector3.LEFT*.35))
	g.player.position = wet
	g.player.position.y = -.36
	check("shore needs a jump from below",g.player._blocked(dry))
	g.player.jump()
	for i in 16: g.player._update_jump(.025,-.36)
	check("normal jump clears the shoreline",g.player.airborne and not g.player._blocked(dry))
	g.player.position = original
	g.player.airborne = false
	g.player.vel_y = 0.
	g.player.inv.add("tree_seed",1)
	for idx in g.player.inv.size():
		var slot = g.player.inv.slots[idx]
		if slot != null and slot.id=="tree_seed":
			g.cmd("use_item",{"si":idx,"sid":"tree_seed"})
	var saplings: Array = w.nodes.keys().filter(func(cell): return str(w.nodes[cell].res).begins_with("young_"))
	check("tree seed is consumed and grows a tree on owned land",g.player.inv.count("tree_seed")==0 and saplings.size()==1 and w.island_cells.has(saplings[0]))
	for cell in saplings: w.remove_node(cell)
	var roof = f.place("shore_canopy",c+Vector2i(-1,1),0)
	var covered = f.place("campfire",c+Vector2i(0,1),0)
	var bare = f.place("campfire",c+Vector2i(0,2),0)
	check("roof matches adjacent fire placement",island.sheltered(covered.center()) and not island.sheltered(bare.center()))
	island.fire_weather(6.,1.)
	check("rain extinguishes only uncovered fire",bare.bstate.get("extinguished",false) and not covered.bstate.get("extinguished",false))
	g.player.inv.add("branch",1)
	g.cmd("shore_relight",{"b":bare})
	check("relight consumes kindling",not bare.bstate.get("extinguished",false) and g.player.inv.count("branch")==0)
	island.fire_weather(6.,1.)
	var iron := -1
	for idx in w.deposits.size():
		if w.deposits[idx].item=="iron_ore": iron=idx
	check("offshore ore rejected",w.order_issue(iron,c+Vector2i(8,0))!="")
	var origin := c+Vector2i(-2,1)
	f.remove(roof)
	check("shoreline order crosses water rejected",w.order_issue(iron,c+Vector2i(-2,2))!="")
	check("paid iron deposit",g.cmd("shore_field",{"idx":iron,"cell":origin})==true and w.deposit.has(origin) and g.credits<1200)
	f.place("furnace",c+Vector2i(1,1),0)
	DB.researched["iron_ore"]=true
	var reachable: Dictionary = island.reachable()
	check("reachable production respects installed stations and ores",reachable.has("iron_ingot") and not reachable.has("uranium") and not reachable.has("fuel_rod"))
	island.request={"branch":3,"log":2}
	island.paid={"branch":0,"log":0}
	g.player.inv.add("branch",1)
	g.cmd("shore_offer",{})
	check("partial offering",island.paid.branch==1 and not island.complete())
	g.player.inv.add("branch",2)
	f.hq.inv.add("log",2)
	g.cmd("shore_offer",{})
	g.day_n=11
	island.deadline()
	check("fulfilled quest protects island and rolls new deadline",w.island_cells.size()==25 and island.due==21)
	var spots := {}
	for i in 24:
		var pos: Vector3 = island.wave_origin()
		spots[World.world_to_cell(pos)]=true
	check("random gate uses shore",spots.size()>1 and spots.keys().all(func(p): return p in island.shore))
	g.enemies.start_wave()
	check("wave actually emerges from visible door",not g.enemies.list.is_empty() and g.enemies.list.all(func(e): return World.world_to_cell(e.pos)==World.world_to_cell(island.door.position)))
	island.request={"branch":3}
	island.paid={"branch":0}
	g.player.inv.add("branch",1)
	g.cmd("shore_offer",{})
	var serialized = JSON.parse_string(JSON.stringify(g.save_dict()))
	DB.set_meta("new_game",{"save":serialized})
	DB.set_meta("shore_test_reload",true)
	g.get_tree().reload_current_scene.call_deferred()
