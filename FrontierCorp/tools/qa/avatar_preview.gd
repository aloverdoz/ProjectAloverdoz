extends Node3D

func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#21313b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#d9e6ef")
	env.ambient_light_energy = .50
	var space := WorldEnvironment.new()
	space.environment=env
	add_child(space)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-50,-38,0)
	sun.light_energy=.90
	sun.shadow_enabled=true
	add_child(sun)
	var floor_node := MeshInstance3D.new()
	floor_node.mesh = PlaneMesh.new()
	floor_node.mesh.size=Vector2(24,24)
	var mat := StandardMaterial3D.new()
	mat.albedo_color=Color("#334952")
	floor_node.material_override=mat
	add_child(floor_node)
	var cam := Camera3D.new()
	cam.projection=Camera3D.PROJECTION_ORTHOGONAL
	cam.size=3.25
	add_child(cam)
	cam.position=Vector3(0,1.85,7)
	cam.look_at(Vector3(0,1.10,0))
	var players := []
	var index := 0
	for id in ["hero_robot_colonist","hero_robert","hero_nurse"]:
		var pl := Player.new()
		pl.look=id
		add_child(pl)
		pl.build()
		pl.position.x = (index-1)*1.55
		pl.hips.rotation.y=-1.04
		pl.move_dir=Vector3(2,0,0)
		pl._glb_update(.1)
		players.append(pl)
		index+=1
	for i in 3:
		for pl in players:
			pl.glb_ap.stop()
			pl.glb_ap.play("Walk",0.0)
			pl.glb_ap.advance(0)
			pl.glb_ap.advance(pl.glb_ap.current_animation_length*(.12+.3*i))
			pl.glb_ap.pause()
			var sk: Skeleton3D = pl._find_skeleton(pl.glb_node)
			print(pl.look," walk phase ", i," knee ",sk.get_bone_pose_rotation(sk.find_bone("LCalf")))
		for j in 2:
			await RenderingServer.frame_post_draw
		var path := "res://previews/crew.jpg" if i == 1 else "/tmp/frontier-stride-%d.jpg"%i
		get_viewport().get_texture().get_image().save_jpg(ProjectSettings.globalize_path(path),.94)
	get_tree().quit()
