extends Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("capture")

func photograph(filename: String) -> void:
	for frame in 3:
		await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://previews/"+filename+".jpg")
	var err := get_viewport().get_texture().get_image().save_jpg(path,.94)
	print("CAPTURE ", filename," ",error_string(err))

func capture() -> void:
	DB.set_meta("new_game", {"seed":72810,"ov":{"settings/strategy":true}})
	var game = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	game.flags["free_build"] = true
	if "--cave-only" in OS.get_cmdline_user_args():
		game.set_process(false)
		game.hud.hide()
		get_viewport().scaling_3d_scale = 1.0
		await photograph_cave(game)
		await finish(game)
		return
	var w = game.world
	var base: Vector2i = w.center
	game.hud.hide()
	game.set_process(false)
	game.day_t = .354
	game._apply_sky()
	get_viewport().scaling_3d_scale = 1.0
	game.sun.shadow_enabled = true
	game.sun.directional_shadow_max_distance = 65.
	game.camera.position = World.cell_to_world(base)+Vector3(19,20,24)
	var focus := World.cell_to_world(base)+Vector3(-2,1,-1)
	game.camera.look_at(focus)
	w.update_visuals(focus)
	await photograph("landing")
	for cell in w.dep_marks:
		if w.deposits[w.deposit[cell]].item != "copper_ore":
			continue
		var marker: Node3D = w.dep_marks[cell]
		game.day_t = .751
		game._apply_sky()
		game.camera.position = marker.position+Vector3(3.3,2.2,3.8)
		game.camera.look_at(marker.position+Vector3.UP*.68)
		await photograph("copper")
		break
	game.day_t = .354
	game._apply_sky()
	game.camera.position = World.cell_to_world(base)+Vector3(19,20,24)
	game.camera.look_at(focus)
	for row in [["smelter",3,-4],["drone_port",-2,-4],["assembler",5,1],["research_lab",1,5],["turret",-4,2]]:
		if DB.data.buildings.has(row[0]):
			DemoSetup.put_near(game,row[0],base+Vector2i(row[1],row[2]))
	for x in range(-3,7):
		var b = DemoSetup.put(game,"belt",base+Vector2i(x,-1),1)
		if b:
			b.item = "copper_ore" if x%2 else "iron_ore"
	for cell in w.deposit:
		if cell.distance_to(base)<15 and w.deposits[w.deposit[cell]].item=="iron_ore":
			DemoSetup.put(game,"miner",cell,1)
			break
	w.update_visuals(focus)
	game.factory._tick(.04)
	await photograph("colony")
	await photograph_cave(game)
	await finish(game)

func finish(game: Node) -> void:
	await get_tree().process_frame
	game.queue_free()
	for tick in 3:
		await get_tree().process_frame
	get_tree().quit()

func photograph_cave(game) -> void:
	for entry in game.factory.all:
		if int(entry.bstate.get("cave_type",-1)) == 1:
			game.enter_cave(entry)
			var trip = game.get_node("Expedition")
			trip.info.hide()
			trip.walker = Vector3(3.5,0,3.0)
			trip.yaw = .70
			trip.pitch = -.07
			trip.update_view()
			await photograph("cavern")
			trip.leave()
			break
