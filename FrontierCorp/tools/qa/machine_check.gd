extends Node3D

func _ready() -> void:
	var factory := Factory.new()
	var failures := []
	for group in [["miner","spindle"],["assembler","press"],["drone_workshop","arm"],["research_lab","scanner"],["tech_terminal","scanner"],["drone_port","dockcraft"],["drone_dock","dockcraft"]]:
		var b := Factory.B.new()
		b.type = group[0]
		var r := factory.renderer(b.type)
		r.chunk = 0
		r.add(b, Transform3D.IDENTITY)
		var parts := r.parts_with_role(group[1])
		if parts.size() != 1:
			failures.append(b.type)
			continue
		if group[1] in ["arm","spindle","press"]:
			var index: int = parts[0]
			var mm: MultiMesh = r.parts[index].mm
			var start := mm.get_instance_transform(0)
			factory.sim_time = 0.37
			factory._update_tool(b)
			if mm.get_instance_transform(0).is_equal_approx(start):
				failures.append(group[1])
		print("MACHINE ", b.type, " ", group[1], " batches=",parts.size())
	var drone := ModelLib.make_node("drone_carrier")
	var blades := drone.get_children().filter(func(n): return str(n.get_meta("role","")).begins_with("rotor"))
	if blades.size() != 4:
		failures.append("rotors")
	drone.free()
	factory.free()
	print("MACHINE_QA failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
