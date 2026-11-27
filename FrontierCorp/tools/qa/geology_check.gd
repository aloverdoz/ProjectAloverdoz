extends Node

var failures := 0

func verify(label: String, ok: bool) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:
		failures += 1

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	DB.set_meta("new_game",{"seed":72810,"size":192})
	var game = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	var w = game.world
	var center: Vector2i = w.center
	var bank_height := 0.0
	var wet := 0
	for x in range(-55,-15):
		for z in range(-30,15):
			var cell := center+Vector2i(x,z)
			bank_height = maxf(bank_height,w.h_cell(cell))
			wet += int(w.water_at(cell))
	verify("landing canyon has water and a raised western bank",wet>30 and bank_height>14.0)
	verify("paving and rock textures loaded", w.ground_mat.get_shader_parameter("slate") != null and w.ground_mat.get_shader_parameter("basalt") != null)
	var types := {}
	var lit := 0
	var too_steep := 0
	for c: Vector2i in w.dep_marks:
		if c.distance_to(center)>18.0:
			continue
		var deposit: Dictionary = w.deposits[w.deposit[c]]
		types[deposit.item] = true
		var bounds: Vector2 = w.ground_range(w.field_cells(c,w.dep_fp(deposit)))
		too_steep += int(bounds.y-bounds.x>.401)
		for child in w.dep_marks[c].get_children():
			if child is OmniLight3D and child.light_energy>0:
				lit += 1
	verify("three starter ores on buildable slopes",types.has("copper_ore") and types.has("iron_ore") and types.has("stone") and too_steep==0)
	verify("local copper illumination",lit>=1)
	verify("independent material for internal crystal bands",ModelLib.parts_of("dep_iron_ore").any(func(part): return part[1] is ShaderMaterial and part[1].shader==preload("res://shaders/gemstone.gdshader")))
	verify("fern patches and cap clusters grow at landing",w.nodes.values().any(func(n):return n.res=="coral_fern" and n.cell.distance_to(center)<12) and w.nodes.values().any(func(n):return n.res=="amethyst_garden" and n.cell.distance_to(center)<12))
	game.flags["free_build"] = true
	var placed = DemoSetup.put_near(game,"chest",center+Vector2i(4,4))
	verify("placed building receives paving",placed!=null and w.yard_img.get_pixelv(placed.cell).r>.9)
	if placed:
		var here: Vector2i = placed.cell
		game.factory.remove(placed)
		verify("paving clears with the last building",w.yard_img.get_pixelv(here).r<.1)
	print("GEOLOGY_QA failures=",failures)
	get_tree().quit(int(failures>0))
