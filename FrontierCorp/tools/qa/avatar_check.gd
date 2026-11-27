extends Node

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	var failed := []
	var measures := {}
	for id in Player.looks():
		var pl := Player.new()
		pl.look = id
		add_child(pl)
		pl.build()
		var bottom := INF
		var top := -INF
		for child in pl.find_children("*","GeometryInstance3D",true,false):
			if pl.gun.is_ancestor_of(child) or pl.hand_r.is_ancestor_of(child):
				continue
			var box: AABB = child.global_transform * child.get_aabb()
			if child is MultiMeshInstance3D and child.multimesh and child.multimesh.instance_count:
				box = child.global_transform * child.multimesh.get_instance_transform(0) * child.multimesh.mesh.get_aabb()
			if child is MeshInstance3D and child.mesh and child.skin:
				# GLB AABBs computed by the renderer may include rest-pose animation bounds.
				box = child.global_transform * child.mesh.get_aabb()
			if box.size.length() > .001:
				top = maxf(top,box.end.y)
				bottom = minf(bottom,box.position.y)
		measures[id] = [bottom,top]
		var expected := 2.08 if id == "hero_robert" else 1.82 # Robert's staff extends above the head.
		if not is_finite(top) or absf(top-bottom-expected) > .02:
			failed.append(id)
		pl.free()
	print("BODY_HEIGHTS ",JSON.stringify(measures))
	print("AVATAR_QA ",measures.size()," failed=",failed)
	get_tree().quit(0 if failed.is_empty() else 1)
