extends Node

var errors := []
func verify(key: String, ok: bool) -> void:
	print("PASS " if ok else "FAIL ",key)
	if not ok:
		errors.append(key)

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	DB.set_meta("new_game",{"seed":72810,"size":192,"ov":{"settings/strategy":true}})
	var game = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	game.flags["free_build"] = true
	var w = game.world
	var f = game.factory
	var pl = game.player
	game.cycle_camera()
	game._update_camera(.016)
	verify("F6 explorer starts at 9 m",absf(game.cam_dist-9.0)<.01 and game.camera.position.distance_to(pl.position)>7.0)
	game.cycle_camera()
	game.cycle_camera()
	game.cycle_camera()
	verify("independent strategy/explorer zoom",absf(game.cam_dist-9.0)<.01)
	var base: Vector2i = w.center+Vector2i(10,12)
	for x in range(-2,10):
		for z in range(-3,9):
			var c := base+Vector2i(x,z)
			w.remove_node(c)
			w.height.set_pixelv(c,Color.BLACK)
	var gate = f.place("star_gate",base,0)
	var neighbor = f.place("warehouse",base+Vector2i(5,0),0)
	var xedge: float = (base.x+5)*World.C
	var got := true
	for j in 52:
		var point := Vector3(xedge,0,base.y*World.C-.45+j*.20)
		if pl._blocked(point):
			got = false
			break
		pl.position = point
	verify("capsule traverses shared edge, star gate and warehouse",got)
	verify("warehouse still has a solid body",f.body_at(neighbor.center())==neighbor)
	verify("academy 4x4, drone docks 2x2",DB.building("tech_terminal").size==4 and DB.building("drone_port").size==2 and DB.building("drone_dock").size==2)
	verify("visible structures surveyed",f._profiles.size()==DB.data.buildings.size())
	var id := "stone_axe"
	pl.inv.slots.fill(null)
	pl.inv.slots[0]={"id":id,"dur":1,"n":1}
	pl.inv.slots[1]={"id":id,"dur":1,"n":1}
	pl.pin_item(2,id)
	game.wear(0)
	verify("spare axe remains pinned",pl.hot_slot(2)==1)
	game.wear(1)
	verify("last axe removed from shortcut",not pl.hot_items.has(2) and pl.inv.count(id)==0)
	verify("cave entrances dormant",f.all.all(func(b):return not b.bstate.has("cave_type")))
	var steep_cell := base+Vector2i(-2,0)
	w.height.set_pixelv(steep_cell+Vector2i.RIGHT,Color(20,0,0))
	w.height.set_pixelv(steep_cell+Vector2i.RIGHT+Vector2i.DOWN,Color(20,0,0))
	var pos := World.cell_to_world(steep_cell)+Vector3(.6,0,.3)
	verify("flat boulder control",w.add_node("rock_big",base+Vector2i(-1,7))!=null)
	verify("no unsupported boulder on cliff",w.add_node("rock_big",steep_cell,Transform3D(Basis(),pos))==null)
	var h = game.hud
	h.close_all()
	h.open("inventory")
	h._refresh_inventory()
	verify("inventory has live occupancy",h.cargo_count.text.begins_with("0 /"))
	h.close_all()
	h.open("craft")
	h._refresh_craft()
	verify("recipe list and selected recipe",h.selected_recipe!="" and h.windows.craft.body.find_children("*","VSeparator",true,false).size()>0)
	h.close_all()
	h.open("tech")
	h._refresh_tech()
	verify("research uses tier rail",h.windows.tech.body.find_children("*","VSeparator",true,false).size()>0)
	h.close_all()
	var tv = h.broadcast
	tv.transmit()
	verify("5000 messages, non-interactive TV",tv.messages.size()==5000 and tv.mouse_filter==Control.MOUSE_FILTER_IGNORE and tv.remaining==15.0)
	var seen := {}
	for i in 5000:
		tv.transmit()
		seen[tv.line.text]=true
	verify("all 5000 used before first repeat",seen.size()==5000)
	tv._process(15.01)
	verify("TV disappears after 15 seconds",not tv.visible)
	var prev: int = DB.building("tech_terminal").size
	game.layout_version=1
	game._apply_sizes(true,true)
	verify("legacy academy preserves old 2x2 footprint",DB.building("tech_terminal").size==2)
	game.layout_version=2
	game._apply_sizes(true,true)
	verify("new footprint restored",DB.building("tech_terminal").size==prev)
	var save: Dictionary = JSON.parse_string(JSON.stringify(game.save_dict()))
	var sample := {"t":"ruin_arch","c":[2,2],"d":0,"bstate":{"cave_type":2,"cave_samples":{"5,2":true},"relic_found":true}}
	save.buildings.append(sample)
	save.player.hot_items.append([4,"stone_axe"])
	game.free()
	await get_tree().process_frame
	DB.set_meta("new_game",{"save":save})
	var restored = load("res://scenes/main.tscn").instantiate()
	add_child(restored)
	verify("legacy cave arch hidden on load",restored.factory.building_at(Vector2i(2,2))==null)
	var kept: Array = restored.save_dict().buildings.filter(func(entry):return entry.get("bstate",{}).has("cave_type"))
	verify("dormant cave samples and relic survive resave",kept.size()==1 and kept[0].bstate.relic_found and kept[0].bstate.cave_samples.has("5,2"))
	verify("legacy broken pin cleared on load",not restored.player.hot_items.has(4))
	print("REVISION_QA failures=",errors)
	get_tree().quit(0 if errors.is_empty() else 1)
