extends Node3D

func _ready() -> void:
	var factory := Factory.new()
	var b := Factory.B.new()
	b.type = "turret"
	var r := factory.renderer(b.type)
	r.chunk = 0
	r.add(b, Transform3D.IDENTITY)
	var failure := false
	for role in ["base", "head", "pitch", "slide"]:
		var ids := r.parts_with_role(role)
		print(role, " batches=", ids.size())
		failure = failure or ids.is_empty()
	if not failure:
		b.aim = 0.36
		b.pitch = 0.18
		factory._aim_head(b)
		var before := {}
		for i in r.parts.size():
			before[i] = r.parts[i].mm.get_instance_transform(0)
		b.recoil = 1.0
		factory._aim_head(b)
		for i in r.parts.size():
			var part: Dictionary = r.parts[i]
			var current: Transform3D = part.mm.get_instance_transform(0)
			if (part.role == "slide") != (not current.is_equal_approx(before[i])):
				failure = true
			if (part.role == "base") != current.is_equal_approx(part.local):
				failure = true
	print("TURRET_QA ", "FAIL" if failure else "PASS")
	factory.free()
	get_tree().quit(1 if failure else 0)
