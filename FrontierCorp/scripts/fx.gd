class_name Fx
extends Node3D
## Визуальные эффекты: трассеры выстрелов, взрывы, искры ремонта, вспышки света.
## Всё переиспользуется из пулов — новых узлов во время боя не создаётся.

var tracer_mm: MultiMesh
var tracers: Array = []   # [from, to, life, color]
var pools := {}           # имя -> {nodes, i}
var orbital_pulses: Array = []
var lights: Array = []
var light_i := 0
var on_blast := Callable()   # 21: физика взрыва (physics21.gd)
var game = null              # 1.3: для тряски камеры от взрывов рядом с героем

const PARTICLE_SHADER := """
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;
uniform float glow = 3.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0, 0, 0), vec4(0, length(MODEL_MATRIX[1].xyz), 0, 0), vec4(0, 0, length(MODEL_MATRIX[2].xyz), 0), vec4(0, 0, 0, 1));
}
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float a = smoothstep(1.0, 0.0, d);
	ALBEDO = COLOR.rgb * glow * a * COLOR.a;
}
"""

const SMOKE_SHADER := """
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, unshaded;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0, 0, 0), vec4(0, length(MODEL_MATRIX[1].xyz), 0, 0), vec4(0, 0, length(MODEL_MATRIX[2].xyz), 0), vec4(0, 0, 0, 1));
}
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	ALBEDO = COLOR.rgb;
	ALPHA = smoothstep(1.0, 0.2, d) * COLOR.a;
}
"""


func setup() -> void:
	tracer_mm = MultiMesh.new()
	tracer_mm.transform_format = MultiMesh.TRANSFORM_3D
	tracer_mm.use_colors = true
	tracer_mm.use_custom_data = true
	tracer_mm.mesh = ModelLib.unit_mesh("box")
	tracer_mm.instance_count = 512
	tracer_mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = tracer_mm
	mmi.material_override = ModelLib.material({"mat": "glow"}, false)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-10000, -10, -10000), Vector3(20000, 200, 20000))
	add_child(mmi)

	_make_pool("fire", 10, 48, 1.0, Gradient.new(), [Color(1, 0.95, 0.7), Color(1, 0.55, 0.1), Color(0.6, 0.15, 0.02, 0)], 9.0, false)
	_make_pool("goo", 14, 30, 0.8, Gradient.new(), [Color(0.9, 0.5, 1.0), Color(0.6, 0.1, 0.8), Color(0.2, 0.0, 0.3, 0)], 7.0, false)
	_make_pool("smoke", 10, 16, 2.2, Gradient.new(), [Color(0.25, 0.22, 0.2, 0.75), Color(0.15, 0.14, 0.13, 0.5), Color(0.1, 0.1, 0.1, 0)], 2.5, true)
	_make_pool("spark", 8, 14, 0.4, Gradient.new(), [Color(0.7, 1, 1), Color(0.2, 0.7, 1), Color(0, 0.3, 1, 0)], 5.0, false)
	_make_pool("dirt", 6, 40, 1.2, Gradient.new(), [Color(0.45, 0.35, 0.25, 0.9), Color(0.3, 0.24, 0.18, 0.6), Color(0.2, 0.15, 0.1, 0)], 6.0, true)
	_make_pool("chips", 8, 14, 0.9, Gradient.new(), [Color(1, 1, 1), Color(0.9, 0.9, 0.9), Color(0.8, 0.8, 0.8, 0)], 6.0, false, true)
	_make_pool("puff", 28, 5, 2.6, Gradient.new(), [Color(0.35, 0.33, 0.32, 0.55), Color(0.3, 0.29, 0.28, 0.35), Color(0.3, 0.3, 0.3, 0)], 1.2, true)
	_make_pool("steam", 16, 5, 1.8, Gradient.new(), [Color(0.95, 0.97, 1.0, 0.5), Color(0.9, 0.92, 0.95, 0.3), Color(1, 1, 1, 0)], 1.6, true)
	_make_pool("dust", 12, 8, 1.2, Gradient.new(), [Color(0.55, 0.45, 0.35, 0.6), Color(0.45, 0.38, 0.3, 0.3), Color(0.4, 0.35, 0.3, 0)], 2.0, true)
	for i in 6:
		var l := OmniLight3D.new()
		l.light_energy = 0.0
		l.omni_range = 10.0
		l.shadow_enabled = false
		add_child(l)
		lights.append(l)


func _make_pool(name: String, count: int, amount: int, life: float, g: Gradient, cols: Array, speed: float, smoke: bool, tinted := false) -> void:
	g.colors = PackedColorArray(cols)
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0 if not smoke else 60.0
	pm.initial_velocity_min = speed * 0.3
	pm.initial_velocity_max = speed
	pm.gravity = Vector3(0, -9.0, 0) if not smoke else Vector3(0, 1.5, 0)
	pm.damping_min = 1.0
	pm.damping_max = 3.0 if not smoke else 4.0
	pm.scale_min = 0.5
	pm.scale_max = 1.3
	var curve := Curve.new()
	if smoke:
		curve.add_point(Vector2(0, 0.4))
		curve.add_point(Vector2(1, 1.6))
	else:
		curve.add_point(Vector2(0, 1.0))
		curve.add_point(Vector2(1, 0.1))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	pm.color_ramp = gt
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.5) if not smoke else Vector2(1.6, 1.6)
	var sm := Shader.new()
	sm.code = SMOKE_SHADER if smoke else PARTICLE_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sm
	quad.material = mat
	var nodes := []
	for i in count:
		var p := GPUParticles3D.new()
		p.amount = amount
		p.lifetime = life
		p.one_shot = true
		p.explosiveness = 0.95
		p.emitting = false
		p.process_material = pm.duplicate() if tinted else pm
		p.draw_pass_1 = quad
		p.local_coords = false
		p.visibility_aabb = AABB(Vector3(-8, -4, -8), Vector3(16, 16, 16))
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(p)
		nodes.append(p)
	pools[name] = {"nodes": nodes, "i": 0}


func _emit(pool: String, pos: Vector3, size: float) -> void:
	var p: Dictionary = pools[pool]
	var node: GPUParticles3D = p.nodes[p.i]
	p.i = (p.i + 1) % p.nodes.size()
	node.global_position = pos
	node.speed_scale = 1.0
	node.scale = Vector3.ONE * size
	node.restart()
	node.emitting = true


func _flash(pos: Vector3, col: Color, energy: float, rng: float) -> void:
	var l: OmniLight3D = lights[light_i]
	light_i = (light_i + 1) % lights.size()
	l.global_position = pos + Vector3(0, 1.5, 0)
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng


## Щепки и осколки цвета объекта (удар по дереву, камню).
func chips(pos: Vector3, col: Color) -> void:
	var p: Dictionary = pools["chips"]
	var node: GPUParticles3D = p.nodes[p.i]
	(node.process_material as ParticleProcessMaterial).color = col
	_emit("chips", pos, 1.0)


## Небольшой клуб дыма, пара или пыли (работающие здания).
func puff(pos: Vector3, kind: String, size := 1.0) -> void:
	if pools.has(kind):
		_emit(kind, pos, size)
	elif kind == "sparks":
		_emit("spark", pos, size * 0.6)


func explosion(pos: Vector3, size: float, col: Color) -> void:
	if on_blast.is_valid():
		on_blast.call(pos, size)
	_emit("fire", pos, size)
	_emit("smoke", pos, size)
	_flash(pos, col, 6.0, 8.0 * size)
	if game != null and game.player != null:
		var d: float = World.dist(pos, game.player.position)
		game.add_trauma(clampf(size * 0.5 * (1.0 - d / (18.0 * maxf(0.5, size))), 0.0, 0.7))


## Вспышка умения монстра (телепорт, лечение, призыв): искры своего цвета и свет.
func magic(pos: Vector3, col: Color, size := 1.0) -> void:
	chips(pos + Vector3(0, 0.8, 0), col)
	_emit("spark", pos + Vector3(0, 0.8, 0), size)
	_flash(pos, col, 4.0, 6.0 * size)


func goo(pos: Vector3, size: float) -> void:
	_emit("goo", pos, size)
	_flash(pos, Color(0.8, 0.3, 1.0), 2.5, 6.0 * size)


func dirt(pos: Vector3, size: float) -> void:
	_emit("dirt", pos, size)


func spark(pos: Vector3) -> void:
	_emit("spark", pos, 1.0)


## 1.3: всплывающая цифра над целью (урон, добыча): поднимается, чуть увеличивается и гаснет.
var _nums: Array = []
var _num_i := 0


func number(pos: Vector3, text: String, col: Color, big := false) -> void:
	if not bool(Prefs.get_value("float_numbers", true)):
		return
	if _nums.is_empty():
		for i in 24:
			var l := Label3D.new()
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			l.no_depth_test = true
			l.fixed_size = true
			l.pixel_size = 0.0011
			l.font_size = 30
			l.outline_size = 10
			l.outline_modulate = Color(0, 0, 0, 0.85)
			l.render_priority = 10
			l.visible = false
			add_child(l)
			_nums.append(l)
	var l: Label3D = _nums[_num_i]
	_num_i = (_num_i + 1) % _nums.size()
	var old = l.get_meta("tw") if l.has_meta("tw") else null
	if old is Tween and old.is_valid():
		old.kill()
	l.text = text
	l.modulate = col
	l.font_size = 40 if big else 30
	l.global_position = pos + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
	l.scale = Vector3.ONE * 0.6
	l.visible = true
	var t := l.create_tween()
	l.set_meta("tw", t)
	t.set_parallel(true)
	t.tween_property(l, "scale", Vector3.ONE * (1.25 if big else 1.0), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "global_position", l.global_position + Vector3(0, 1.4, 0), 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.45)
	t.chain().tween_callback(func(): l.visible = false)


func tracer(a: Vector3, b: Vector3, col: Color, life := 0.06) -> void:
	if tracers.size() >= tracer_mm.instance_count:
		return
	tracers.append([a, b, life, col])


func orbital_strike(pos: Vector3, radius: float, impact: Callable) -> void:
	orbital_pulses.append({"pos": pos, "r": radius, "impact": impact, "age": 0.0, "tick": 0.0, "hit": false})


func _orbital_step(delta: float) -> void:
	for pulse in orbital_pulses.duplicate():
		pulse.age += delta
		pulse.tick -= delta
		var pos: Vector3 = pulse.pos
		if pulse.age < 0.78 and pulse.tick <= 0.0:
			pulse.tick = 0.065
			var radius: float = pulse.r * (1.65 - 0.6 * float(pulse.age))
			for i in 16:
				var a := TAU * i / 16.0
				var b := a + PI / 14.0
				var start := pos + Vector3(cos(a), 0.12, sin(a)) * radius
				var end := pos + Vector3(cos(b), 0.12, sin(b)) * radius
				tracer(start, end, Color(1, 0.65, 0.19), 0.10)
			_flash(pos + Vector3.UP, Color(0.55, 0.8, 1), 1.8, 5.0)
		if pulse.age >= 0.78 and not pulse.hit:
			pulse.hit = true
			if pulse.impact.is_valid():
				pulse.impact.call()
			for i in 7:
				var a := TAU * i / 7.0
				var offset := Vector3(cos(a), 0, sin(a)) * 0.22
				tracer(pos + Vector3.UP * 70.0 + offset * 2.3, pos + offset, Color(0.45, 0.83, 1), 0.27)
			_flash(pos + Vector3.UP, Color(0.75, 0.9, 1), 5.5, 15.0)
			_emit("spark", pos + Vector3.UP * 0.4, 1.8)
			_emit("dirt", pos + Vector3.UP * 0.1, 1.45)
			game.add_trauma(0.26)
		if pulse.age >= 1.05:
			_emit("dust", pos, 1.7)
			orbital_pulses.erase(pulse)


func _process(delta: float) -> void:
	if not orbital_pulses.is_empty():
		_orbital_step(delta)
	for l in lights:
		if l.light_energy > 0.0:
			l.light_energy = max(0.0, l.light_energy - delta * 18.0)
	var n := 0
	var keep := []
	for t in tracers:
		t[2] -= delta
		if t[2] <= 0.0:
			continue
		keep.append(t)
		var a: Vector3 = t[0]
		var b: Vector3 = t[1]
		var d := b - a
		var len := d.length()
		if len < 0.01:
			continue
		var up := Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.RIGHT
		var basis := Basis.looking_at(d / len, up)
		basis.x *= 0.07
		basis.y *= 0.07
		basis.z *= len
		tracer_mm.set_instance_transform(n, Transform3D(basis, (a + b) * 0.5))
		tracer_mm.set_instance_color(n, t[3])
		tracer_mm.set_instance_custom_data(n, Color(0, 0, 0, 0))
		n += 1
	tracers = keep
	tracer_mm.visible_instance_count = n
