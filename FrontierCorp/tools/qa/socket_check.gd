extends Node

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	DB.set_meta("new_game",{"seed":72810,"size":128})
	var game = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	var f = game.factory
	var checked := 0
	var failures := []
	for dir in 4:
		var cell: Vector2i = game.world.center+Vector2i(12,10)
		var b = f.place("drone_port",cell,dir)
		for i in b.pin.size():
			var belt_cell: Vector2i = b.pin[i]
			var side: int = b.pin_side[i]
			var belt = f.place("belt",belt_cell,(side+2)%4)
			f._update_sockets(b)
			var key := [b,"port",i]
			var root: PartRenderer = f.port_rs["port_in18"]
			var part: PartRenderer = root._owner_sub.get(key,root)
			if not part.index_of.has(key):
				failures.append([dir,i,"absent"])
				continue
			var index: int = part.index_of[key]
			var pose: Transform3D = part.base_xf[index]
			var outward := Vector3(Factory.DIRS[side].x,0,Factory.DIRS[side].y)
			var lane := World.cell_to_world(belt_cell)
			var wall: Vector3 = f._socket_wall(b,side,lane,Vector3.INF)
			var target := lane-outward*(World.C*.5-.12)
			target.y = belt.y
			var frame: Vector3 = pose.origin-outward*.01
			if frame.distance_to(wall) > .015:
				failures.append([dir,i,"wall"])
			var j: int = part.parts_with_role("stretch")[0]
			var floor_piece: Dictionary = part.parts[j]
			var stretch: Transform3D = floor_piece.mm.get_instance_transform(index) * floor_piece.local.affine_inverse()
			if (stretch * Vector3.RIGHT).distance_to(target) > .14:
				failures.append([dir,i,"belt"])
			checked+=1
			f.remove(belt)
		f.remove(b)
	print("SOCKET_QA real belt connections=",checked," failures=",failures)
	game.queue_free()
	for i in 3:
		await get_tree().process_frame
	get_tree().quit.call_deferred(0 if checked==8 and failures.is_empty() else 1)
