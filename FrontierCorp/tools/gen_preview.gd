extends Node
## Предпросмотр генератора моделей без игры: строит меш и сохраняет картинку.
## godot --path . tools/gen_preview.tscn -- --out=/tmp/x.png --what=test

var out := "/tmp/claude-0/shots2/gen.png"
var what := "test"
var frames := 0
var cam: Camera3D


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--what="):
			what = a.substr(7)
	var root3 := Node3D.new()
	add_child(root3)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.16, 0.18, 0.22)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.6, 0.7)
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	root3.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	root3.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 150, 0)
	fill.light_energy = 0.35
	root3.add_child(fill)
	var t0 := Time.get_ticks_msec()
	var nodes: Array = ModelGen.preview_nodes(what)
	print("GEN ms=", Time.get_ticks_msec() - t0)
	var aabb := AABB()
	var first := true
	for n in nodes:
		root3.add_child(n)
		var bb: AABB = n.get_meta("aabb", AABB())
		aabb = bb if first else aabb.merge(bb)
		first = false
	var floor_ := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	floor_.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.32, 0.36, 0.3)
	floor_.material_override = fm
	root3.add_child(floor_)
	cam = Camera3D.new()
	root3.add_child(cam)
	var c := aabb.get_center()
	var r := aabb.size.length() * 0.62
	cam.fov = 40
	cam.look_at_from_position(c + Vector3(r * 1.25, r * 0.85, r * 1.55), c, Vector3.UP)


func _process(_d: float) -> void:
	frames += 1
	if frames == 8:
		var img := get_viewport().get_texture().get_image()
		img.save_png(out)
		print("SHOT ", out)
		get_tree().quit()
