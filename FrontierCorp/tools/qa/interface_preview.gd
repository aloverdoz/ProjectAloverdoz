extends Node

func _ready() -> void:
	go.call_deferred()

func go() -> void:
	DB.set_meta("new_game",{"seed":72810,"size":192})
	var game = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	if game.strategy:
		game.cycle_camera()
	for key in ["inventory","craft","tech","tv"]:
		game.hud.close_all()
		if key == "tv":
			game.hud.broadcast.transmit()
		else:
			game.hud.open(key)
		for i in 6:
			await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		image.save_jpg(ProjectSettings.globalize_path("res://previews/"+key+".jpg"),.91)
		print("SCREEN ",key)
	get_tree().quit()
