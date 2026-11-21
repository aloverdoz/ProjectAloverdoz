extends Node3D
## 1.3: живой фон главного меню — база версии 1.2 в лесу: крупные здания, станции энергии с кольцами,
## ленты с рудой, дроны, квантовый портал, верстак и костёр у штаба, мехи идут на турели. Камера летает по планам,
## день плавно переходит в вечер и ночь (загораются огни). Настройки → «Живой фон меню» выключает его.

const CreatureRig = preload("res://scripts/creature_rig.gd")

var cam: Camera3D
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var fade: ColorRect
var t := 0.0
var shot_i := 0
var shot_t := 0.0
var rng := RandomNumberGenerator.new()

var heads := []        # [узел-голова турели, позиция турели, кд]
var belts := []        # [от, до, скорость, MultiMesh, фаза]
var drones := []       # [узел, от, до, фаза]
var mechs := []        # [риг, x, z, скорость, масштаб, hp, t_смерти]
var tracers := []      # [узел, жизнь]
var booms := []        # [узел, свет, жизнь]
var rings := []        # [узел, материал, фаза]
var night_lights := [] # [свет, энергия]
var portal_light: OmniLight3D
var portal_swirl: Node3D
var clear_pt := Vector3.ZERO
var clear_r := 0.0
var frozen := false
var fixed_cam := []    # 1.1.20: --menu_cam=x,y,z,x,y,z — неподвижная камера (картинка-заставка)

# 1.1.20: кинематографичные планы — длинные плавные проезды, низкие ракурсы, облёт штаба, волна мехов у стены.
const SHOTS := [
	# [откуда (начало), откуда (конец), куда смотреть (начало), куда (конец), секунд]
	[Vector3(74, 42, -86), Vector3(52, 27, -58), Vector3(6, 2, 6), Vector3(2, 2, 6), 15.0],          # подлёт над лесом
	[Vector3(35, 4.2, 9), Vector3(22, 3.8, 9), Vector3(12, 1.5, 2), Vector3(2, 1.5, 2), 12.0],    # вдоль линии железа (внутри стены)
	[Vector3(-9, 8.5, -12), Vector3(7, 9.0, -13), Vector3(-3, 0.5, -50), Vector3(5, 0.5, -50), 12.0],  # из-за турелей на волну
	[Vector3(16, 1.7, -58), Vector3(9, 1.9, -46), Vector3(0, 3.5, -20), Vector3(1, 3.5, -20), 11.0],   # с поля боя на стену
	[Vector3(0, 9, 0), Vector3(0, 9, 0), Vector3(0, 2.5, 0), Vector3(0, 2.5, 0), 15.0],                # облёт штаба (особый)
	[Vector3(-54, 12, 36), Vector3(-50, 9, 2), Vector3(-26, 3, 16), Vector3(-26, 3, 8), 12.0],         # энергетика
	[Vector3(44, 7, 52), Vector3(22, 6, 50), Vector3(16, 3, 27), Vector3(4, 3, 27), 12.0],             # тяжёлая промышленность
	[Vector3(34, 72, 66), Vector3(-30, 66, 70), Vector3(2, 0, 6), Vector3(2, 0, 6), 15.0],             # над всей базой
]


func _ready() -> void:
	rng.seed = 1303
	_env()
	_ground()
	if "--splash_scene" in OS.get_cmdline_user_args():
		var sc := _splash_cfg()
		clear_pt = Vector3(sc[0], 0, sc[2])
		clear_r = 30.0
	_forest()
	_base()
	_defense()
	cam = Camera3D.new()
	cam.fov = 42
	cam.far = 600
	# 1.1.20: мягкое размытие дали, как у киноплёнки
	var ca := CameraAttributesPractical.new()
	ca.dof_blur_far_enabled = true
	ca.dof_blur_far_distance = 95.0
	ca.dof_blur_far_transition = 70.0
	ca.dof_blur_amount = 0.05
	cam.attributes = ca
	add_child(cam)
	var cl := CanvasLayer.new()
	add_child(cl)
	var vg := ColorRect.new()
	vg.set_anchors_preset(Control.PRESET_FULL_RECT)
	vg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vsh := Shader.new()
	vsh.code = "shader_type canvas_item;\nvoid fragment(){ vec2 d=UV-0.5; float v=smoothstep(0.35,0.85,length(d*vec2(1.3,1.0))); COLOR=vec4(0.02,0.015,0.01,v*0.55); }"
	var vm := ShaderMaterial.new()
	vm.shader = vsh
	vg.material = vm
	cl.add_child(vg)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 1)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(fade)
	RenderingServer.global_shader_parameter_set("view_on", 0.0)
	# для снимков: --menu_shot=N — сразу этот план, --menu_t=секунды — время суток
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--menu_shot="):
			shot_i = int(a.substr(12))
			shot_t = 4.0
			t = 2.0
		elif a.begins_with("--menu_t="):
			t = float(a.substr(9))
		elif a.begins_with("--menu_cam="):
			var v := a.substr(11).split_floats(",")
			if v.size() == 6:
				fixed_cam = [Vector3(v[0], v[1], v[2]), Vector3(v[3], v[4], v[5])]
		elif a.begins_with("--menu_fov="):
			cam.fov = float(a.substr(11))
		elif a.begins_with("--splash_heroes="):
			_heroes(a.substr(16).split_floats(","))
		elif a.begins_with("--menu_warm="):
			for k in int(float(a.substr(12)) * 10.0):
				_animate_mechs(0.1)   # картинка-заставка: мехи уже подошли к стене
				_animate_fx(0.1)
		elif a == "--splash_scene":
			_splash_scene()
		elif a == "--menu_nofx":
			for c in cl.get_children():
				if c != fade:
					c.visible = false
	_place_cam(0.0)


# ---------------------------------------------------------------- окружение

## 1.3: настройки из главного меню применяются к живому фону сразу (Prefs.apply → menu.on_pref_changed).
func apply_pref(key: String) -> void:
	if env == null:
		return
	match key:
		"ssao":
			env.ssao_enabled = bool(Prefs.get_value("ssao", true))
		"glow":
			env.glow_enabled = bool(Prefs.get_value("glow", true))
		"ssil":
			env.ssil_enabled = bool(Prefs.get_value("ssil", true))
		"shadows":
			sun.shadow_enabled = str(Prefs.get_value("shadows", "high")) != "off"


func _env() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_curve = 0.12
	sky_mat.sun_angle_max = 20.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.15
	env.tonemap_white = 6.0
	env.ssao_enabled = bool(Prefs.get_value("ssao", true))
	env.ssao_radius = 1.6
	env.ssao_intensity = 2.0
	env.glow_enabled = bool(Prefs.get_value("glow", true))
	env.glow_intensity = 0.8
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.ssil_enabled = bool(Prefs.get_value("ssil", true))
	env.fog_enabled = true
	env.fog_density = 0.0011
	env.fog_sky_affect = 0.3
	env.fog_aerial_perspective = 0.2
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = str(Prefs.get_value("shadows", "high")) != "off"
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 110.0
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	add_child(sun)
	moon = DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.65, 1.0)
	moon.rotation = Vector3(deg_to_rad(-50), deg_to_rad(140), 0)
	moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(moon)


## Время суток по кругу: золотой час → закат → ночь с огнями → рассвет (период 160 с).
func _sky() -> void:
	var ph := fmod(t / 160.0 + 0.11, 1.0)   # 1.1.20: начинаем с золотого часа
	var h := 0.3 * cos(ph * TAU) + 0.2            # высота солнца: от 0.5 до −0.1 (ночь короткая, лунная)
	var dayk := smoothstep(-0.12, 0.2, h)
	var low := 1.0 - smoothstep(0.0, 0.62, h)   # 1.1.20: дольше тёплый свет
	sun.rotation = Vector3(-clampf(h, 0.04, 1.0) * deg_to_rad(68.0) - 0.08, 2.3 + ph * 0.6, 0)
	sun.light_energy = smoothstep(-0.03, 0.15, h) * 1.7
	sun.light_color = Color(1.0, 0.94, 0.84).lerp(Color(1.0, 0.58, 0.3), low * 0.9)
	sky_mat.sky_top_color = Color(0.04, 0.06, 0.16).lerp(Color(0.25, 0.48, 0.85), dayk)
	sky_mat.sky_horizon_color = Color(0.14, 0.16, 0.3).lerp(Color(0.74, 0.84, 0.95).lerp(Color(1.0, 0.72, 0.45), low * 0.7), dayk)
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
	sky_mat.ground_bottom_color = sky_mat.sky_horizon_color * 0.4
	env.ambient_light_energy = lerpf(0.6, 0.9, dayk)
	moon.light_energy = (1.0 - dayk) * 0.55
	env.fog_light_color = sky_mat.sky_horizon_color
	env.fog_light_energy = lerpf(0.35, 1.0, dayk)
	var night := 1.0 - dayk
	for nl in night_lights:
		nl[0].light_energy = float(nl[1]) * (0.25 + night * 0.95)
	if portal_light:
		portal_light.light_energy = (2.5 + night * 4.0) * (0.85 + 0.15 * sin(t * 3.1))


func _ground() -> void:
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(520, 520)
	pm.subdivide_width = 64
	pm.subdivide_depth = 64
	g.mesh = pm
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode diffuse_burley;
varying vec3 wp;
float h(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float n(vec2 p){vec2 i=floor(p);vec2 f=fract(p);vec2 u=f*f*(3.0-2.0*f);return mix(mix(h(i),h(i+vec2(1,0)),u.x),mix(h(i+vec2(0,1)),h(i+vec2(1,1)),u.x),u.y);}
float fbm(vec2 p){return n(p)*0.5+n(p*2.1)*0.27+n(p*4.3)*0.15+n(p*9.1)*0.08;}
void vertex(){ wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; float r=length(wp.xz); VERTEX.y+=smoothstep(70.0,200.0,r)*fbm(wp.xz*0.02)*26.0; wp.y=VERTEX.y; }
void fragment(){
	vec2 p=wp.xz;
	float g=fbm(p*0.08);
	vec3 grass=mix(vec3(0.16,0.3,0.09),vec3(0.33,0.45,0.15),g);
	grass=mix(grass,vec3(0.42,0.44,0.2),smoothstep(0.62,0.8,fbm(p*0.03+7.0))*0.6);
	// 1.1.20: вся база на бетонной площадке (плиты 2 м со швами), вокруг — утоптанная земля, к воротам — дорога
	vec2 q=abs(p-vec2(2.0,5.0))-vec2(37.5,28.5);
	float dbox=length(max(q,0.0))+min(max(q.x,q.y),0.0);
	float n1=(fbm(p*0.15)-0.5)*6.0;
	float dirt=1.0-smoothstep(2.0,9.0,dbox+n1);
	vec3 soil=mix(vec3(0.3,0.24,0.17),vec3(0.42,0.35,0.25),fbm(p*0.4));
	float road=(1.0-smoothstep(2.2,3.6,abs(p.x-1.0+sin(p.y*0.04)*2.5)))*step(p.y,-22.0)*(1.0-smoothstep(70.0,95.0,-p.y));
	vec3 c=mix(grass,soil,max(dirt,road*0.85));
	float pad=1.0-smoothstep(-1.0,0.0,dbox);
	vec2 g2=abs(fract(p*0.5)-0.5);
	float seam=smoothstep(0.47,0.5,max(g2.x,g2.y));
	vec3 conc=mix(vec3(0.27,0.26,0.24),vec3(0.35,0.34,0.31),fbm(p*0.7))*(1.0-seam*0.35);
	conc=mix(conc,vec3(0.33,0.27,0.2),smoothstep(0.5,0.8,fbm(p*0.12+3.0))*0.6);
	c=mix(c,conc,pad);
	ALBEDO=c;
	ROUGHNESS=0.95;
}"""
	var sm := ShaderMaterial.new()
	sm.shader = sh
	g.material_override = sm
	add_child(g)


## Много копий модели одной сеткой (деревья, трава, камни): по MultiMesh на деталь.
func _scatter(id: String, xfs: Array, tint := Color(1, 1, 1, 0)) -> void:
	if xfs.is_empty() or not DB.data.models.has(id):
		return
	for p in ModelLib.parts_of(id, false):
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = p[0]
		mm.instance_count = xfs.size()
		var col: Color = p[3]
		if tint.a > 0.0 and bool(p[4]):
			col = Color(tint.r, tint.g, tint.b)
		for i in xfs.size():
			mm.set_instance_transform(i, xfs[i] * p[2])
			mm.set_instance_color(i, col)
			mm.set_instance_custom_data(i, Color(1, randf(), 0, 0))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		if p[1]:
			mmi.material_override = p[1]
		add_child(mmi)


func _forest() -> void:
	var kinds := {"tree_pine": [], "tree_fir": [], "tree_oak": [], "tree_birch": []}
	var keys := kinds.keys()
	for i in 1400:
		var a := rng.randf() * TAU
		var r := rng.randf_range(48.0, 180.0)
		var p := Vector3(cos(a) * r, 0, sin(a) * r * 1.1)
		# коридор, по которому идут мехи (с юга), — реже; на базе и у стены деревьев нет
		if p.z < -30.0 and absf(p.x) < 30.0 and rng.randf() < 0.85:
			continue
		if absf(p.x - 2.0) < 62.0 and absf(p.z - 5.0) < 50.0:
			continue
		if clear_r > 0.0 and Vector2(p.x - clear_pt.x, p.z - clear_pt.z).length() < clear_r:
			continue   # картинка-заставка: у камеры и героев деревьев нет
		var s := rng.randf_range(1.4, 2.3) * (1.0 + clampf((r - 60.0) / 200.0, 0.0, 0.5))
		var k: String = keys[0 if rng.randf() < 0.45 else rng.randi() % keys.size()]
		kinds[k].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), p + Vector3(0, -0.1, 0)))
	for k in kinds:
		_scatter(k, kinds[k])
	var grass := []
	var flowers := []
	var rocks := []
	for i in 2600:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 70.0 + 30.0
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		if absf(p.x - 2.0) < 42.0 and absf(p.z - 5.0) < 33.0:
			continue
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(1.0, 1.8)), p)
		if rng.randf() < 0.08:
			flowers.append(xf)
		else:
			grass.append(xf)
	for i in 40:
		var a := rng.randf() * TAU
		var r := rng.randf_range(50.0, 90.0)
		if clear_r > 0.0 and Vector2(cos(a) * r - clear_pt.x, sin(a) * r - clear_pt.z).length() < clear_r:
			continue
		rocks.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 2.2)), Vector3(cos(a) * r, -0.1, sin(a) * r)))
	_scatter("deco_grass", grass)
	_scatter("deco_flower_yellow", flowers)
	_scatter("rock_big", rocks)


# ---------------------------------------------------------------- база

func _put(id: String, pos: Vector3, yaw := 0.0) -> Node3D:
	if not DB.data.models.has(id):
		return null
	var n := ModelLib.make_node(id)
	n.position = pos
	n.rotation.y = yaw
	add_child(n)
	return n


func _bput(bid: String, pos: Vector3, yaw := 0.0) -> Node3D:
	var m := str(DB.building(bid).get("model", bid))
	return _put(m, pos, yaw)


func _lamp(pos: Vector3, col: Color, e: float, rng_m := 14.0) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = col
	l.omni_range = rng_m
	l.shadow_enabled = false
	add_child(l)
	night_lights.append([l, e])


## Здание по правилам игры: центр в метрах, dir — как у Factory (0 = +X, 1 = +Z, 2 = −X, 3 = −Z).
func _b(bid: String, cx: float, cz: float, dir := 0) -> Node3D:
	return _bput(bid, Vector3(cx, 0, cz), -float(dir) * PI * 0.5)


func _base() -> void:
	# 1.3: база собрана по сетке игры (клетка 2 м): машины 2×2 стоят ровно по клеткам,
	# ленты идут от выхода бура к входу плавильни и дальше в штаб, предметы едут вдоль ленты.
	_b("hq", 0, 0)
	_lamp(Vector3(0, 7, 6), Color(1.0, 0.8, 0.55), 2.5, 22.0)
	# линия железа: бур (30,−2) → лента → плавильня (16,−2) → лента → штаб
	# линия меди: бур (30,10) → лента → плавильня (16,10) → лента → сборщик (2,10) → лента → штаб
	# уголь: бур (16,−12) → лента на север → плавильня железа
	for e in [["miner_mk3", "dep_iron_ore", 30.0, -2.0, 2], ["miner_mk4", "dep_copper_ore", 30.0, 10.0, 2], ["miner_mk2", "dep_coal", 16.0, -12.0, 1]]:
		var dp := _put(e[1], Vector3(e[2], 0.06, e[3]))
		if dp:
			dp.scale = Vector3.ONE * 2.0
		_b(e[0], e[2], e[3], e[4])
	for z in [-2.0, 10.0]:
		_b("smelter_mk2", 16, z, 2)
		_smoke(Vector3(16, 6.5, z))
		_lamp(Vector3(16, 3, z + 3.0), Color(1.0, 0.55, 0.25), 1.6, 9.0)
	_b("assembler_mk2", 2, 10, 3)
	_lamp(Vector3(2, 4, 13), Color(0.6, 0.8, 1.0), 1.4, 12.0)
	_belt(Vector3(27, 0, -1), Vector3(19, 0, -1), "iron_ore")
	_belt(Vector3(13, 0, -1), Vector3(5, 0, -1), "iron_ingot")
	_belt(Vector3(15, 0, -9), Vector3(15, 0, -5), "coal")
	_belt(Vector3(27, 0, 11), Vector3(19, 0, 11), "copper_ore")
	_belt(Vector3(13, 0, 11), Vector3(5, 0, 11), "copper_ingot")
	_belt(Vector3(1, 0, 7), Vector3(1, 0, 5), "iron_plate")
	# станции энергии с кольцами радиуса — между линиями, не на лентах
	for e in [["pole_mk3", Vector3(-9, 0, 9), Color(0.45, 0.85, 1.0)], ["pole_mk4", Vector3(9, 0, -7), Color(0.55, 1.0, 0.6)], ["pole_mk5", Vector3(23, 0, 5), Color(1.0, 0.85, 0.4)]]:
		_bput(e[0], e[1])
		_ring(e[1], float(DB.bparam(e[0], "radius", 5)) * 2.0 + 1.0, e[2])
		_lamp(e[1] + Vector3(0, 5, 0), e[2], 1.2, 10.0)
	# дроны между портом и плавильнями
	_b("drone_port", -6, -8)
	for i in 3:
		var d := _put("drone_carrier", Vector3.ZERO)
		if d:
			d.scale = Vector3.ONE * 1.4
			drones.append([d, Vector3(-6, 3, -8), Vector3([16.0, 30.0, 2.0][i], 4.5, [-2.0, 4.0, 10.0][i]), float(i) * 0.33])
	# лагерь: верстак и костёр у западной стены штаба
	_b("workbench", -7, -1, 0)
	var cf := _bput("campfire", Vector3(-9, 0, 4))
	if cf:
		_lamp(Vector3(-9, 1.2, 4), Color(1.0, 0.6, 0.3), 2.2, 9.0)
	# квантовый портал: фиолетовый свет, вихрь осколков, жила в суперпозиции рядом
	_b("quantum_portal", -19, -7)
	portal_light = OmniLight3D.new()
	portal_light.light_color = Color(0.72, 0.45, 1.0)
	portal_light.omni_range = 18.0
	portal_light.position = Vector3(-19, 4, -7)
	add_child(portal_light)
	portal_swirl = Node3D.new()
	portal_swirl.position = Vector3(-19, 3.2, -7)
	add_child(portal_swirl)
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.albedo_color = Color(0.85, 0.6, 1.0)
	gm.emission_enabled = true
	gm.emission = Color(0.75, 0.45, 1.0)
	gm.emission_energy_multiplier = 4.0
	for i in 14:
		var sh := MeshInstance3D.new()
		var bm := PrismMesh.new()
		bm.size = Vector3(0.25, 0.5, 0.25)
		sh.mesh = bm
		sh.material_override = gm
		var a := float(i) / 14.0 * TAU
		sh.position = Vector3(cos(a) * (2.2 + 0.4 * (i % 3)), sin(a * 2.0) * 0.8, sin(a) * (2.2 + 0.4 * (i % 3)))
		portal_swirl.add_child(sh)
	var vein := []
	for i in 7:
		vein.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.45, 0.8)), Vector3(-27 + rng.randf_range(-2.0, 2.0), 0, -14 + rng.randf_range(-2.0, 2.0))))
	_scatter("ore_quartz", vein, Color(0.72, 0.5, 1.0, 1.0))
	# 1.1.20: база целиком, а не кусок: склады, энергетика, тяжёлая промышленность, исследования, фонари вдоль дорог
	# третья линия: бур на камне → дробилка
	var dp3 := _put("dep_stone", Vector3(30, 0.06, -14))
	if dp3:
		dp3.scale = Vector3.ONE * 2.0
	_b("miner_mk2", 30, -14, 2)
	_belt(Vector3(27, 0, -13), Vector3(25, 0, -13), "stone")
	_b("crusher", 22, -14, 2)
	# склады у дороги к воротам
	_b("warehouse", -11, -13)
	_b("container", -17, -13)
	_b("container", 9, 4)
	for e in [[12.5, 5.5], [-21.5, -15.5], [-2.5, 6.5], [7.0, 14.6], [-13.5, -16.5], [25.5, -17.0], [33.0, 4.5]]:
		_bput("crates", Vector3(e[0], 0, e[1]), rng.randf() * TAU)
	for e in [[13.6, 2.2], [-8.6, -15.8], [-14.8, -10.4], [33.5, 13.6], [34.4, 12.7], [24.5, -10.5], [36.0, -6.0]]:
		_bput("barrel", Vector3(e[0], 0, e[1]), rng.randf() * TAU)
	_b("repair_tower", -2, -13)
	_b("research_lab", -14, 0)
	_lamp(Vector3(-14, 4, 3), Color(0.55, 0.85, 1.0), 1.2, 10.0)
	_b("radar_tower", -28, 27)
	# энергетика на западе: реактор, генератор, солнечное поле, батареи, ветряки за стеной
	_b("nuclear_reactor", -26, 14)
	_lamp(Vector3(-26, 6, 19), Color(0.5, 1.0, 0.75), 2.0, 16.0)
	_b("fuel_generator", -27, 0)
	_smoke(Vector3(-27, 6.0, 0))
	for i in 3:
		_b("battery_block", -18, 18 + i * 4)
	for x in range(-13, -3, 2):
		for z in range(19, 31, 2):
			_bput("solar", Vector3(x, 0, z))
	for x in [-30.0, -20.0, -10.0, 0.0, 10.0, 20.0]:
		_b("wind_turbine", x, 44, 0)
	_bput("pole_mk5", Vector3(-21, 0, 5))
	_ring(Vector3(-21, 0, 5), float(DB.bparam("pole_mk5", "radius", 5)) * 2.0 + 1.0, Color(1.0, 0.85, 0.4))
	# тяжёлая промышленность на севере: домна → изготовитель, нефтезавод и химзавод, баки, качалка
	_b("blast_furnace", 4, 27)
	_smoke(Vector3(4, 8.0, 27))
	_lamp(Vector3(4, 3, 31), Color(1.0, 0.5, 0.2), 2.0, 12.0)
	_belt(Vector3(9, 0, 27), Vector3(11, 0, 27), "steel")
	_b("manufacturer", 15, 27)
	_b("refinery", 25, 27)
	_smoke(Vector3(25, 8.0, 27))
	_b("chem_plant", 34, 27)
	_lamp(Vector3(34, 4, 31), Color(0.7, 1.0, 0.5), 1.4, 12.0)
	_b("tank", 21, 20)
	_b("tank", 25, 20)
	_b("oil_pump", 34, 19)
	# фонари вдоль главной дороги (от ворот к штабу) и прожекторы у стены
	for z in [-20.0, -15.0, -9.0]:
		_bput("lamp", Vector3(-1.5, 0, z))
		_bput("lamp", Vector3(3.5, 0, z))
		_lamp(Vector3(1, 3.2, z), Color(1.0, 0.82, 0.55), 1.3, 9.0)
	for x in [-22.0, 26.0]:
		_bput("searchlight", Vector3(x, 0, -21))
		_lamp(Vector3(x, 4, -21), Color(0.9, 0.95, 1.0), 1.5, 12.0)
	for e in [[-4.6, 4.6], [4.6, 4.6]]:
		_bput("flag", Vector3(e[0], 0, e[1]))
	# 1.3: героев в живом фоне нет — только завод (по просьбе игрока)


## Лента по клеткам от a до b (центры клеток, шаг 2 м). Модель ленты длинная по X и везёт к +X
## при повороте 0 — поворот как у здания в игре: yaw = atan2(−dz, dx).
func _belt(a: Vector3, b: Vector3, item: String) -> void:
	var dir := (b - a)
	var n := int(round(dir.length() / 2.0))
	var yaw := atan2(-dir.z, dir.x)
	for i in n + 1:
		var p := a.lerp(b, float(i) / maxf(1.0, n))
		var bn := _bput("belt_mk3", p, yaw)
		if bn:
			for c in bn.get_children():
				if c is MultiMeshInstance3D:
					(c as MultiMeshInstance3D).multimesh.set_instance_custom_data(0, Color(1, 0, 0, 0))
	# предметы на ленте — размера груза, стоят на полотне, едут от входа ленты к выходу
	var model := str(DB.item(item).get("model", "drop_ore"))
	if not DB.data.models.has(model):
		model = "drop_ore"
	var col := DB.color(DB.item(item).get("color", "#aaaaaa"))
	var parts := ModelLib.parts_of(model, false)
	var box := AABB()
	var first := true
	for pt in parts:
		var bb: AABB = (pt[2] as Transform3D) * (pt[0] as Mesh).get_aabb()
		box = bb if first else box.merge(bb)
		first = false
	var sc := 0.62 / maxf(0.05, maxf(maxf(box.size.x, box.size.z), box.size.y * 1.3))
	var fit := Transform3D(Basis.from_scale(Vector3.ONE * sc), Vector3(-box.get_center().x * sc, 0.36 - box.position.y * sc, -box.get_center().z * sc))
	var cnt := maxi(3, (n + 1) * 2)
	var mms := []
	for p in parts:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = p[0]
		mm.instance_count = cnt
		for i in cnt:
			mm.set_instance_color(i, col if bool(p[4]) else p[3])
			mm.set_instance_custom_data(i, Color(1, randf(), 0, 0))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		if p[1]:
			mmi.material_override = p[1]
		add_child(mmi)
		mms.append([mm, fit * (p[2] as Transform3D)])
	# путь предмета — от края первой клетки до края последней
	var u := dir.normalized()
	belts.append([a - u * 1.0, b + u * 1.0, 2.4, mms, cnt, yaw])


func _ring(c: Vector3, r: float, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r - 0.12
	tm.outer_radius = r + 0.12
	tm.rings = 64
	mi.mesh = tm
	mi.scale = Vector3(1, 0.15, 1)
	mi.position = c + Vector3(0, 0.15, 0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(col.r, col.g, col.b, 0.5)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	rings.append([mi, m, rng.randf() * TAU, col])


func _smoke(p: Vector3) -> void:
	var ps := CPUParticles3D.new()
	ps.position = p
	ps.amount = 18
	ps.lifetime = 5.0
	ps.direction = Vector3(0.3, 1, 0)
	ps.spread = 12.0
	ps.initial_velocity_min = 1.0
	ps.initial_velocity_max = 1.8
	ps.gravity = Vector3(0.25, 0.15, 0)
	ps.scale_amount_min = 0.8
	ps.scale_amount_max = 1.6
	var crv := Curve.new()
	crv.add_point(Vector2(0, 0.4))
	crv.add_point(Vector2(1, 2.6))
	ps.scale_amount_curve = crv
	var sm := SphereMesh.new()
	sm.radius = 0.6
	sm.height = 1.2
	sm.radial_segments = 8
	sm.rings = 4
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(0.55, 0.55, 0.58, 0.32)
	sm.material = m
	ps.mesh = sm
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 0.8))
	gr.set_color(1, Color(1, 1, 1, 0.0))
	ps.color_ramp = gr
	add_child(ps)


## 1.1.20: кадр для картинки-заставки (ui/splash.png): герои слева на переднем плане, за ними стена и база,
## справа мехи штурмуют стену, турели стреляют. Снимок: tools/shot.sh … --menu_bg_only --splash_scene.
func _splash_cfg() -> Array:
	var cfg := [40.0, 9.0, -50.0, 2.0, -8.0, -4.0, 50.0, 12.0, 6.6, 0.78]
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a.begins_with("--splash_cfg="):
			var v := a.substr(13).split_floats(",")
			for i in mini(v.size(), cfg.size()):
				cfg[i] = v[i]
	return cfg


func _splash_scene() -> void:
	# по умолчанию: вид сверху-сбоку с юго-востока, герои слева внизу, мехи справа у южной стены
	var cfg := _splash_cfg()
	var from := Vector3(cfg[0], cfg[1], cfg[2])
	var at := Vector3(cfg[3], cfg[4], cfg[5])
	fixed_cam = [from, at]
	cam.fov = cfg[6]
	var d := (at - from)
	d.y = 0.0
	d = d.normalized()
	var right := Vector3(-d.z, 0, d.x)
	var hc := from + d * float(cfg[7]) - right * float(cfg[8])
	var a := atan2(-right.z, right.x)
	_heroes(PackedFloat64Array([hc.x, hc.z, a, atan2(-d.x, -d.z), cfg[9]]))
	# мехи — у южной стены (z<-23), правее героев в кадре
	# мехи: [вперёд от камеры, вправо] — средний план справа, идут к южной стене
	var spots := [[24.0, 7.0], [28.0, 12.0], [21.0, 13.0], [33.0, 9.0], [31.0, 17.0], [37.0, 14.0], [26.0, 19.0], [40.0, 20.0], [35.0, 4.0]]
	for i in mini(mechs.size(), spots.size()):
		var m: Array = mechs[i]
		var sp: Vector3 = from + d * float(spots[i][0]) + right * float(spots[i][1])
		m[1] = sp.x
		m[2] = minf(sp.z, -26.0)
		m[5] = 999
		m[6] = -1.0
		m[3] = 0.4
	for k in 30:
		_animate_mechs(0.1)
	for k in 12:
		_animate_fx(0.05)
	frozen = true   # картинка-заставка: кадр замирает, вспышки и выстрелы остаются
	for p in [from + d * 30.0 + right * 6.0, from + d * 38.0 + right * 13.0, from + d * 27.0 + right * 15.0]:
		p.y = 1.4
		_boom(p)
		booms[-1][2] = 0.22
		booms[-1][0].visible = false   # плоские шары на кадре смотрятся плохо — только отсвет
		booms[-1][1].light_energy = 9.0


## 1.1.20: шестеро героев на картинке-заставке (в живом фоне меню героев нет): x, z, поворот к камере.
func _heroes(v: PackedFloat64Array) -> void:
	if v.size() < 3:
		return
	# [герой, предмет, ход, фаза, удар, смещение x, z, поворот]
	var list := [["hero_valera", "iron_pickaxe", 0.0, 0.0, 0.32, -3.2, 0.6, 0.5], ["hero_lu", "iron_axe", 0.0, 0.3, -1.0, -1.6, -1.0, 0.2],
		["hero_harry", "", 0.0, 0.0, -1.0, 0.0, 0.8, 0.0], ["hero_castiel", "iron_pickaxe", 0.0, 0.7, -1.0, 1.7, -0.7, -0.25],
		["hero_anime", "", 0.0, 0.0, -1.0, 3.3, 0.9, -0.45], ["hero_klara", "iron_axe", 0.0, 0.0, 0.55, 5.0, -0.4, -0.7]]
	var base := Basis(Vector3.UP, float(v[2]))
	for e in list:
		var pl = load("res://scripts/player.gd").new()
		pl.game = {"flags": {}, "profession": ""}
		pl.look = e[0]
		add_child(pl)
		pl.build()
		if str(e[1]) != "":
			pl.inv.slots[0] = {"id": e[1], "n": 1}
		pl.selected = 0
		pl._update_tool_visual()
		for f in 90:
			pl.move_dir = Vector3.ZERO
			pl.aim = Vector3(5, 1.2, 0)
			if float(e[4]) >= 0.0:
				pl.game.flags["pose"] = e[4]
			pl.t = float(e[3]) + f * 0.016
			pl._animate(0.016, false)
		var sp: float = float(v[4]) if v.size() > 4 else 1.0
		pl.position = Vector3(v[0], 0, v[1]) + base * Vector3(float(e[5]) * sp, 0, float(e[6]) * sp)
		pl.rotation = Vector3(0, (float(v[3]) if v.size() > 3 else float(v[2])) + float(e[7]), 0)
		pl.set_process(false)
		pl.set_physics_process(false)


# ---------------------------------------------------------------- оборона и мехи

func _defense() -> void:
	# 1.1.20: стена по всему периметру базы, ворота на юге (оттуда идут мехи), турели в два ряда
	var wx := 0 if _long_x("steel_wall") else 1
	for x in range(-35, 41, 2):
		if x != 1:
			_b("steel_wall", x, -23, wx)
		_b("steel_wall", x, 33, wx)
	for z in range(-21, 33, 2):
		_b("steel_wall", -35, z, 1 - wx)
		_b("steel_wall", 39, z, 1 - wx)
	_b("gate", 1, -23, 0 if _long_x("gate") else 1)
	for e in [["gatling_turret", Vector3(-27, 0, -19)], ["missile_turret", Vector3(-17, 0, -19)], ["laser_turret", Vector3(-9, 0, -19)],
			["cannon_turret", Vector3(-3, 0, -18)], ["laser_turret", Vector3(5, 0, -18)], ["gatling_turret", Vector3(13, 0, -19)],
			["plasma_turret", Vector3(21, 0, -19)], ["missile_turret", Vector3(31, 0, -19)], ["tesla_coil", Vector3(9, 0, -16)],
			["sniper_tower", Vector3(-31, 0, -19)], ["sniper_tower", Vector3(35, 0, -19)], ["missile_turret", Vector3(-31, 0, 29)], ["missile_turret", Vector3(35, 0, 29)]]:
		var n := _bput(e[0], e[1])
		if n == null:
			continue
		var hd := []
		for c in n.get_children():
			if str(c.get_meta("role", "")) == "head":
				hd.append([c, c.transform])
		heads.append([n, hd, e[1], 0.0, DB.color(DB.bparam(e[0], "beam_color", "#ffd060"))])
	_lamp(Vector3(2, 6, -20), Color(1.0, 0.85, 0.6), 2.0, 16.0)
	for i in 9:
		_spawn_mech(i)


## Длинная сторона модели — по X?
func _long_x(bid: String) -> bool:
	var bb := AABB()
	var first := true
	for pt in ModelLib.parts_of(str(DB.building(bid).get("model", bid)), false):
		var b: AABB = (pt[2] as Transform3D) * (pt[0] as Mesh).get_aabb()
		bb = b if first else bb.merge(b)
		first = false
	return bb.size.x >= bb.size.z


func _spawn_mech(i: int) -> void:
	var ids := ["runner_t3", "crawler_t2", "brute_t2", "guard_t3", "runner_t2", "brute_t3", "crawler_t3", "guard_t2", "runner_t1"]
	var eid: String = ids[i % ids.size()]
	if not DB.data.enemies.has(eid):
		eid = ids[i % 5]
	var d: Dictionary = DB.data.enemies.get(eid, {})
	var r := CreatureRig.new()
	if d.is_empty() or not r.build(str(d.get("model", eid))):
		return
	add_child(r)
	mechs.append([r, rng.randf_range(-24.0, 26.0), -36.0 - float(i) * 5.0 - rng.randf_range(0.0, 6.0), float(d.get("speed", 5.0)) * 0.55, float(d.get("scale", 1.0)), 3 + rng.randi() % 4, -1.0, eid])


func _fire(from: Vector3, to: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.07, 0.07, 1.0)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 6.0
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ln := from.distance_to(to)
	mi.position = (from + to) * 0.5
	mi.look_at_from_position(mi.position, to, Vector3.UP)
	mi.scale = Vector3(1, 1, ln)
	add_child(mi)
	tracers.append([mi, 0.08])


func _boom(p: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.7, 0.3, 0.9)
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.emission_enabled = true
	m.emission = Color(1.0, 0.55, 0.2)
	m.emission_energy_multiplier = 5.0
	mi.material_override = m
	mi.position = p
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.3)
	l.omni_range = 14.0
	l.light_energy = 6.0
	l.position = p + Vector3(0, 1, 0)
	add_child(l)
	booms.append([mi, l, 0.0, m])


# ---------------------------------------------------------------- кадр

func _process(delta: float) -> void:
	delta = minf(delta, 0.1)
	if frozen:
		_sky()
		fade.color.a = 0.0
		return
	t += delta
	_sky()
	_shots(delta)
	_animate_belts()
	_animate_drones()
	_animate_mechs(delta)
	_animate_fx(delta)
	for r in rings:
		var k := 0.5 + 0.5 * sin(t * 2.0 + float(r[2]))
		(r[1] as StandardMaterial3D).albedo_color = Color(r[3].r, r[3].g, r[3].b, 0.25 + 0.4 * k)
	if portal_swirl:
		portal_swirl.rotation.y = t * 1.3
		portal_swirl.position.y = 3.2 + sin(t * 1.7) * 0.3


func _place_cam(k: float) -> void:
	if fixed_cam.size() == 2:
		cam.position = fixed_cam[0]
		cam.look_at(fixed_cam[1], Vector3.UP)
		return
	var s: Array = SHOTS[shot_i % SHOTS.size()]
	var e := k * k * (3.0 - 2.0 * k)
	var from: Vector3 = (s[0] as Vector3).lerp(s[1], e)
	var at: Vector3 = (s[2] as Vector3).lerp(s[3], e)
	if shot_i % SHOTS.size() == 4:
		# облёт штаба
		var a := lerpf(-0.4, 1.3, e)
		from = Vector3(0, 0, 0) + Vector3(sin(a) * 28.0, lerpf(15.0, 11.5, e), -cos(a) * 28.0)   # выше вышек и фонарей рядом со штабом
	cam.position = from
	cam.look_at(at, Vector3.UP)


func _shots(delta: float) -> void:
	if fixed_cam.size() == 2:
		_place_cam(0.0)
		fade.color.a = maxf(0.0, 1.0 - t / 0.5) if t < 0.5 else 0.0
		return
	shot_t += delta
	var dur: float = SHOTS[shot_i % SHOTS.size()][4]
	if shot_t >= dur:
		shot_t = 0.0
		shot_i += 1
	_place_cam(shot_t / dur)
	var edge := minf(shot_t, dur - shot_t)
	var a := 1.0 - clampf(edge / 0.9, 0.0, 1.0)
	if t < 1.6:
		a = maxf(a, 1.0 - t / 1.6)
	fade.color.a = a


func _animate_belts() -> void:
	for b in belts:
		var a: Vector3 = b[0]
		var e: Vector3 = b[1]
		var ln := a.distance_to(e)
		var cnt: int = b[4]
		for i in cnt:
			var d := fmod(t * float(b[2]) + float(i) * ln / cnt, ln)
			var p := a.lerp(e, d / ln)
			var xf := Transform3D(Basis(Vector3.UP, float(b[5]) + float(i % 3) * 0.4), p)
			for mm in b[3]:
				(mm[0] as MultiMesh).set_instance_transform(i, xf * mm[1])


func _animate_drones() -> void:
	for d in drones:
		var k := fmod(t * 0.07 + float(d[3]), 1.0)
		var go := k < 0.5
		var u := (k / 0.5) if go else ((k - 0.5) / 0.5)
		var s := u * u * (3.0 - 2.0 * u)
		var a: Vector3 = d[1] if go else d[2]
		var b: Vector3 = d[2] if go else d[1]
		var p := a.lerp(b, s) + Vector3(0, sin(s * PI) * 7.0 + sin(t * 3.0 + float(d[3]) * 9.0) * 0.15, 0)
		var n: Node3D = d[0]
		n.position = p
		n.rotation.y = atan2(b.x - a.x, b.z - a.z)


func _animate_mechs(delta: float) -> void:
	for m in mechs:
		var r = m[0]
		var info := {"speed": float(m[3]) / 0.55}
		if float(m[6]) >= 0.0:
			m[6] = float(m[6]) + delta
			if float(m[6]) > 3.5:
				# убран — пошёл новый из леса
				m[1] = rng.randf_range(-24.0, 26.0)
				m[2] = -60.0 - rng.randf_range(0.0, 20.0)
				m[5] = 3 + rng.randi() % 4
				m[6] = -1.0
				r.dead_t = -1.0
				r.visible = true
		else:
			m[2] = float(m[2]) + float(m[3]) * delta
			if float(m[2]) > -26.5:
				m[2] = -26.5
				info["windup"] = fmod(t, 1.0)
			info["target_dir"] = Vector3(0, 0, 1)
		if float(m[6]) > 3.0:
			r.visible = false
		r.animate(delta, Vector3(m[1], 0, m[2]), -PI * 0.5, float(m[4]), info)   # 1.1.20: лицом к базе (+Z), а не боком
	# турели целятся в ближайшего живого меха в радиусе и стреляют
	for h in heads:
		h[3] = float(h[3]) - delta
		var best = null
		var bd := 34.0
		for m in mechs:
			if float(m[6]) >= 0.0:
				continue
			var mp := Vector3(m[1], 1.0, m[2])
			var d: float = (h[2] as Vector3).distance_to(mp)
			if d < bd:
				bd = d
				best = m
		if best == null:
			continue
		var tp := Vector3(best[1], 1.0 * float(best[4]), best[2])
		var yaw := atan2(-(tp.z - h[2].z), tp.x - h[2].x)
		for hp in h[1]:
			(hp[0] as Node3D).transform = Transform3D(Basis(Vector3.UP, yaw), Vector3.ZERO) * hp[1]
		if float(h[3]) <= 0.0:
			h[3] = rng.randf_range(0.18, 0.5)
			_fire((h[2] as Vector3) + Vector3(cos(yaw) * 1.4, 1.6, -sin(yaw) * 1.4), tp + Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.3, 0.3), 0), h[4])
			best[5] = int(best[5]) - 1
			if int(best[5]) <= 0:
				best[6] = 0.0
				best[0].die(1.0 if rng.randf() < 0.5 else -1.0)
				_boom(tp)


func _animate_fx(delta: float) -> void:
	for i in range(tracers.size() - 1, -1, -1):
		tracers[i][1] = float(tracers[i][1]) - delta
		if float(tracers[i][1]) <= 0.0:
			tracers[i][0].queue_free()
			tracers.remove_at(i)
	for i in range(booms.size() - 1, -1, -1):
		var b: Array = booms[i]
		b[2] = float(b[2]) + delta
		var k: float = float(b[2]) / 0.45
		# вспышка: маленькое яркое ядро, быстро гаснет (раньше — большой полупрозрачный купол)
		(b[0] as Node3D).scale = Vector3.ONE * (0.35 + sqrt(k) * 1.1)
		(b[3] as StandardMaterial3D).albedo_color.a = maxf(0.0, 0.95 * (1.0 - k) * (1.0 - k))
		(b[1] as OmniLight3D).light_energy = maxf(0.0, 6.0 * (1.0 - k))
		if k >= 1.0:
			b[0].queue_free()
			b[1].queue_free()
			booms.remove_at(i)
