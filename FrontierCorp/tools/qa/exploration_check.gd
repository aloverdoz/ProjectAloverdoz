extends Node

const Balance := preload("res://scripts/balance_preset.gd")
var failures := []
var count := 0

func verify(label: String, ok: bool) -> void:
	count += 1
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failures.append(label)

func _ready() -> void:
	call_deferred("check")

func check() -> void:
	var path := OS.get_temp_dir().path_join("frontier-qa-" + str(OS.get_process_id()))
	DirAccess.make_dir_recursive_absolute(path)
	Balance.write_text(path.path_join("project.godot"), "")
	var preset := Balance.capture(DB.data)
	var previous: int = preset.tables.settings.cargo_capacities[0]
	verify("deploy initial preset", Balance.deploy(path, preset).is_empty())
	preset.tables.settings.cargo_capacities[0] = previous + 4
	verify("deploy replacement", Balance.deploy(path, preset).is_empty())
	var backup_ok := false
	for filename in DirAccess.get_files_at(path):
		if filename.ends_with(".bak"):
			var old = JSON.parse_string(FileAccess.get_file_as_string(path.path_join(filename)))
			backup_ok = old.tables.settings.cargo_capacities[0] == previous
	verify("original preset recoverable", backup_ok)
	var old_dir: String = DB._base_override
	var old_studio: bool = DB.studio
	DB._base_override = path
	DB.studio = false
	DB.load_all()
	verify("game applies deployed preset", DB.setting("cargo_capacities")[0] == previous + 4)
	DB._base_override = old_dir
	DB.studio = old_studio
	DB.load_all()
	for filename in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(filename))
	for folder in DirAccess.get_directories_at(path):
		DirAccess.remove_absolute(path.path_join(folder))
	DirAccess.remove_absolute(path)
	DB.set_meta("new_game", {"seed": 72810, "ov":{"settings/strategy":true}})
	var game = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	verify("strategy start", game.strategy and not game.player.visible)
	var f6 := InputEventKey.new()
	f6.keycode = KEY_F6
	f6.pressed = true
	game._input(f6)
	verify("third person", not game.strategy and game.player.visible)
	game._input(f6)
	game._update_camera(0.02)
	verify("eye-level first person", game.first_person and not game.player.visible and game.camera.position.is_equal_approx(game.player.position + Vector3.UP*1.62))
	var origin: Vector3 = game.player.position
	game._input(f6)
	game.player.position.x += 10
	game._input(f6)
	verify("explorer returns to saved position", game.player.position.is_equal_approx(origin))
	var entrances: Array = game.factory.all.filter(func(b): return b.bstate.has("cave_type"))
	verify("four entrances", entrances.size() == 4)
	for b in entrances:
		game.enter_cave(b)
		var cave = game.get_node("Expedition")
		verify("enter type " + str(cave.kind), get_tree().paused and cave.camera.is_current() and not cave.samples.is_empty())
		if cave.samples.is_empty():
			cave.leave()
			await get_tree().process_frame
			continue
		var key: String = cave.samples.keys()[0]
		cave.walker = cave.samples[key].position
		cave.walker.y = 0
		cave.update_view()
		if cave.kind == 1:
			cave.collect()
			verify("crystals gated by geology", cave.samples.has(key))
			game.tech.done["t_geo2"] = true
		var before: int = game.tech.research
		cave.collect()
		cave.collect()
		verify("sample awarded once", game.tech.research == before+2 and b.bstate.cave_samples.has(key))
		if cave.kind >= 2:
			if cave.kind == 3:
				verify("guardian has real rig", is_instance_valid(cave.guardian) and cave.guardian_clips.has_animation("Attack"))
				cave.walker = cave.guardian.position
				cave.walker.y = 0
				cave._process(.01)
				verify("contact returns to entrance", cave.walker.is_equal_approx(Vector3.ZERO))
			cave.walker = cave.relic.position
			cave.walker.y = 0.0
			cave.update_view()
			var previous_research: int = game.tech.research
			cave.collect()
			verify("relic reward", game.tech.research == previous_research+5 and b.bstate.get("relic_found",false))
		var layout: Array = cave.cells.keys()
		cave.leave()
		await get_tree().process_frame
		verify("safe surface return", not get_tree().paused and not game.has_node("Expedition"))
		game.enter_cave(b)
		cave = game.get_node("Expedition")
		if cave.kind >= 2:
			verify("relic cannot respawn", not is_instance_valid(cave.relic))
		verify("persistent layout and loot", cave.cells.keys() == layout and not cave.samples.has(key))
		cave.leave()
		await get_tree().process_frame
	var saved: Dictionary = JSON.parse_string(JSON.stringify(game.save_dict()))
	verify("all caves in save", saved.buildings.filter(func(b): return b.get("bstate",{}).has("cave_samples")).size() == entrances.size())
	var research: int = game.tech.research
	var stored_at: Vector3 = game.player.position
	game.free()
	await get_tree().process_frame
	DB.set_meta("new_game", {"save":saved})
	var restored = load("res://scenes/main.tscn").instantiate()
	add_child(restored)
	await get_tree().process_frame
	verify("cold load personal camera", not restored.strategy and not restored.first_person and restored.player.visible)
	verify("cold load explorer position", restored.player.position.distance_to(stored_at) < .1)
	verify("cold load expedition research", restored.tech.research == research and restored.tech.done.has("t_geo2"))
	var claimed: Array = restored.factory.all.filter(func(b): return b.bstate.has("cave_samples"))
	verify("cold load cave entrances", claimed.size() == 4)
	if not claimed.is_empty():
		restored.enter_cave(claimed[0])
		var cavern = restored.get_node("Expedition")
		verify("cold load excludes collected sample", cavern.visited.size() == 1 and not cavern.samples.has(cavern.visited.keys()[0]))
		cavern.leave()
		await get_tree().process_frame
	print("EXPLORATION_QA checks=",count," failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
