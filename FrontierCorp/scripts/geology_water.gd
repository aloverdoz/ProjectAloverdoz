extends RefCounted

static func falls(parent: Node3D, lip: Vector3, foot: Vector3, width: float) -> void:
	var side := Vector3(foot.z-lip.z,0,lip.x-foot.x).normalized()
	if side.length_squared() < .1:
		side = Vector3.RIGHT
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in 12:
		for column in 8:
			for corner: Vector2i in [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.ONE,Vector2i.ZERO,Vector2i.ONE,Vector2i.DOWN]:
				var u := (column+corner.x)/8.0
				var v := (row+corner.y)/12.0
				var at := lip.lerp(foot,v)
				at.y = lerpf(lip.y,foot.y,v*v)
				at += side*(u-.5)*width*(.73+.27*v)
				at.y += sin(u*37.)*.047
				st.set_uv(Vector2(u,v))
				st.add_vertex(at)
	st.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.mesh = st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/spring.gdshader")
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
