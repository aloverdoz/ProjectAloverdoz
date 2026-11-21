extends Node

func _ready() -> void:
	call_deferred("check_rigs")


func check_rigs() -> void:
	var tested := 0
	var failed := []
	for id in ["demon_creature", "dragon", "fantasy_goblin", "grim", "jack_o_lantern", "mushroom_creature", "nurse", "pumpkin_skull_knight", "robert", "robot", "stone_golem", "wooden_forest_golem"]:
		var scene := ModelLib.glb_instance("res://art/colony/%s.glb" % id)
		if scene == null:
			failed.append(id)
			continue
		add_child(scene)
		var player := ModelLib.glb_player(scene)
		var skeletons := scene.find_children("*", "Skeleton3D", true, false)
		if player == null or skeletons.is_empty():
			failed.append(id)
		else:
			var sk: Skeleton3D = skeletons[0]
			var expected := ["Idle", "Walk", "Run", "Attack", "Hurt", "Death", "Jump", "Shoot"]
			if id == "dragon":
				expected.append_array(["Fly", "Takeoff", "Land", "Breath"])
			for clip in expected:
				if not player.has_animation(clip):
					failed.append(id + "/" + clip)
					continue
				player.play(clip)
				player.seek(0.0, true)
				var poses := []
				for i in sk.get_bone_count():
					poses.append(sk.get_bone_pose(i))
				var moved := false
				for step in [0.22, 0.51, 0.83]:
					player.seek(player.current_animation_length * step, true)
					for i in sk.get_bone_count():
						var pose := sk.get_bone_pose(i)
						if not pose.is_finite():
							failed.append(id + "/" + clip + "/invalid")
						moved = moved or not pose.is_equal_approx(poses[i])
				if not moved:
					failed.append(id + "/" + clip + "/static")
				tested += 1
			print(id, " bones=", sk.get_bone_count(), " clips=", expected.size())
		scene.free()
		ModelLib._glb_states.clear()
	print("RIG_QA tested=", tested, " failed=", failed)
	get_tree().quit(0 if failed.is_empty() else 1)
