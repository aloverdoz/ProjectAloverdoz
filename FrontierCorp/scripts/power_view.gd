
extends Node3D
## 21: режим энергии (клавиша V): круги покрытия станций, какие здания питаются, кому не хватило мощности
## и где станции нет вовсе. Сам включается, пока ставите станцию или машину, которой нужна энергия.

var game
var on := false
var mi := MeshInstance3D.new()
var labels: Array = []
var t := 0.0
var shown := false

const SEG := 56


func _init(g) -> void:
	game = g
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.no_depth_test = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.render_priority = 2
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Цвета: ok — питается, short — станция рядом, но мощности не хватило, none — станции рядом нет.
static func col(kind: String) -> Color:
	match kind:
		"ok": return Color(0.35, 1.0, 0.5)
		"short": return Color(1.0, 0.62, 0.15)
		"none": return Color(1.0, 0.3, 0.25)
		"ring": return Color(0.35, 0.8, 1.0)
		"full": return Color(1.0, 0.85, 0.25)
	return Color.WHITE


## Показывать ли сейчас: режим включён или ставим станцию / машину с энергией.
func wanted() -> bool:
	if on:
		return true
	var bt: String = game.build_type
	if bt == "" or not game.factory.stations_mode():
		return false
	var d: Dictionary = DB.building(bt)
	var pr: Dictionary = d.get("params", {})
	return float(pr.get("transfer", 0)) > 0.0 or float(pr.get("power", 0)) > 0.0


func update(dt: float) -> void:
	var w := wanted()
	if not w:
		if shown:
			mi.mesh = null
			for l in labels:
				l.visible = false
			shown = false
		return
	t -= dt
	if t > 0.0 and shown:
		return
	t = 0.25
	shown = true
	_rebuild()


func _rebuild() -> void:
	var f = game.factory
	var im := ImmediateMesh.new()
	var any := false
	var li := 0
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	# круги станций
	for n in f.power_nodes:
		var cap: float = f.station_cap(n)
		if cap <= 0.0 or n.dead:
			continue
		any = true
		var load := float(n.bstate.get("st_load", 0.0))
		var short := int(n.bstate.get("st_short", 0))
		var c := col("ring")
		if short > 0:
			c = col("short")
		elif load >= cap * 0.85:
			c = col("full")
		var r: float = (f.station_radius(n) + (n.size - 1) * 0.5) * World.C
		_ring(im, n.center(), r, c)
		if on:
			var lb := _label(li)
			li += 1
			lb.text = "%s\n%d / %d" % [DB.building(n.type).get("name", n.type), roundi(load), roundi(cap)] + (("\n" + DB.tx("pv_short", "не хватило: %d") % short) if short > 0 else "")
			lb.modulate = c
			lb.position = n.center() + Vector3(0, 4.6, 0)
			lb.visible = true
	# здания, которым нужна энергия
	for b in f.consumers:
		if b.dead or b.host != null:
			continue
		var kind := "ok" if b.pw_state == 1 else ("short" if b.pw_state == 2 else "none")
		if kind == "ok" and not on:
			continue
		any = true
		var c2 := col(kind)
		_square(im, b, c2)
		if kind == "ok" and b.feeder != null and not b.feeder.dead:
			_line(im, b.center(), b.feeder.center(), Color(c2.r, c2.g, c2.b, 0.35))
	# куда встанет новая станция
	var bt: String = game.build_type
	if bt != "":
		var pr: Dictionary = DB.building(bt).get("params", {})
		if float(pr.get("transfer", 0)) > 0.0:
			var sz := int(DB.building(bt).get("size", 1))
			var pos: Vector3 = World.cell_to_world(game.hover_cell) + Vector3((sz - 1) * World.C * 0.5, 0, (sz - 1) * World.C * 0.5)
			_ring(im, pos, (float(pr.get("radius", 3)) + (sz - 1) * 0.5) * World.C, Color(1, 1, 1))
			any = true
	im.surface_end()
	mi.mesh = im if any else null
	for i in range(li, labels.size()):
		labels[i].visible = false


func _y(p: Vector3) -> float:
	return game.world.height_at(p) + 0.18


func _ring(im: ImmediateMesh, c: Vector3, r: float, colr: Color) -> void:
	var w := 0.14
	var fill := Color(colr.r, colr.g, colr.b, 0.07)
	var edge := Color(colr.r, colr.g, colr.b, 0.85)
	for i in SEG:
		var a0 := TAU * i / SEG
		var a1 := TAU * (i + 1) / SEG
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var p0 := c + d0 * r
		var p1 := c + d1 * r
		var q0 := c + d0 * (r - w)
		var q1 := c + d1 * (r - w)
		p0.y = _y(p0); p1.y = _y(p1); q0.y = p0.y; q1.y = p1.y
		var cc := c
		cc.y = _y(c)
		_tri(im, q0, p0, p1, edge)
		_tri(im, q0, p1, q1, edge)
		_tri(im, cc, q0, q1, fill)


func _square(im: ImmediateMesh, b, colr: Color) -> void:
	var h: float = b.size * World.C * 0.5 - 0.15
	var c: Vector3 = b.center()
	var y := _y(c) + 0.05
	var pts := [Vector3(-h, 0, -h), Vector3(h, 0, -h), Vector3(h, 0, h), Vector3(-h, 0, h)]
	var w := 0.18
	var e := Color(colr.r, colr.g, colr.b, 0.9)
	for i in 4:
		var a: Vector3 = c + pts[i]
		var z: Vector3 = c + pts[(i + 1) % 4]
		a.y = y; z.y = y
		var inn := (c - a).normalized() * w
		var inz := (c - z).normalized() * w
		_tri(im, a, z, z + inz, e)
		_tri(im, a, z + inz, a + inn, e)
	var cc := c
	cc.y = y
	var f := Color(colr.r, colr.g, colr.b, 0.18)
	_tri(im, cc + pts[0], cc + pts[1], cc + pts[2], f)
	_tri(im, cc + pts[0], cc + pts[2], cc + pts[3], f)


func _line(im: ImmediateMesh, a: Vector3, z: Vector3, colr: Color) -> void:
	z = a + World.delta(a, z)
	a.y = _y(a) + 0.02
	z.y = _y(z) + 0.02
	var side := (z - a).cross(Vector3.UP).normalized() * 0.05
	_tri(im, a - side, a + side, z + side, colr)
	_tri(im, a - side, z + side, z - side, colr)


func _tri(im: ImmediateMesh, a: Vector3, b: Vector3, c: Vector3, colr: Color) -> void:
	for v in [a, b, c]:
		im.surface_set_color(colr)
		im.surface_add_vertex(v)


func _label(i: int) -> Label3D:
	while labels.size() <= i:
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.fixed_size = true
		l.pixel_size = 0.0009
		l.font_size = 30
		l.outline_size = 8
		l.render_priority = 3
		add_child(l)
		labels.append(l)
	return labels[i]
