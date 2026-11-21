extends RefCounted
## 1.1.15: режим «Стратегия» — игра без героя (галочка при создании мира или сервера, settings/strategy).
##  • героя не видно: его узел остаётся невидимой «точкой обзора» — камера летает над картой (WASD, край экрана);
##  • щелчок по зданию открывает его окно, щелчок по камню, дереву или руде — добыча лучшим инструментом из рюкзака;
##  • монстры героя не видят и сразу идут на здания, герой их не бьёт — оборона только турелями, стенами и щитами;
##  • нет здоровья, голода, жажды, смерти; в навыках и характеристиках — только то, что не про героя;
##  • погода видна на экране: мороз — иней по краям и камера вязнет, зной — края горят и воздух дрожит,
##    кислотный дождь — ядовитая плёнка, буря — пыль, радиация — зелёное зерно, затмение — темнота, туман — серая пелена.

var game
var layer: CanvasLayer
var rect: ColorRect
var mat: ShaderMaterial
var ghost: Ghost
## Сила эффектов на экране 0..1 (плавно).
var fx := {"frost": 0.0, "burn": 0.0, "toxic": 0.0, "dust": 0.0, "glare": 0.0, "dark": 0.0, "rad": 0.0, "fog": 0.0}
var _want := {}
var _t := 0.0

## Стоит вместо героя для монстров: «мёртвый» (его не видят и не бьют), но с местом — где сейчас камера.
class Ghost extends RefCounted:
	var alive := false
	var position := Vector3.ZERO
	var hp := 0.0
	var maxhp := 1.0
	var inv = null
	var food := 100.0
	var water := 100.0
	var visible := false
	func damage(_x: float) -> void:
		pass
	func selected_item() -> String:
		return ""


## Статы героя: навыки и характеристики только из них в стратегии не показываются.
const HERO_STATS := ["move", "max_hp", "regen", "hunger", "attack_speed", "jump", "armor", "warmth", "cooling"]


static func on() -> bool:
	return bool(DB.setting("strategy", false))


func _init(g) -> void:
	game = g
	ghost = Ghost.new()
	for k in fx:
		_want[k] = 0.0


## Навык или характеристика только про героя (Атлетика, Живучесть…) — в стратегии их нет.
static func hero_only(bonus: Dictionary) -> bool:
	if bonus.is_empty():
		return false
	for k in bonus:
		if not str(k) in HERO_STATS:
			return false
	return true


func make_overlay() -> void:
	layer = CanvasLayer.new()
	layer.layer = -1   # под интерфейсом, поверх картинки
	game.add_child(layer)
	rect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SHADER
	mat = ShaderMaterial.new()
	mat.shader = sh
	rect.material = mat
	layer.add_child(rect)
	rect.visible = false


## Куда смотрит камера (точка обзора).
func view_pos() -> Vector3:
	return game.player.position


## Во сколько раз медленнее летит камера: мороз и буря вязнут.
func pan_k() -> float:
	return clampf(1.0 - 0.6 * fx.frost - 0.25 * fx.dust, 0.3, 1.0)


## Камера-«герой»: полёт над картой без столкновений, на высоте земли или крыш под ней.
func move(pl, delta: float, cam_yaw: float) -> void:
	pl.alive = true
	pl.hp = pl.maxhp
	pl.visible = false
	var input := Vector2.ZERO
	if pl.ctl != null:
		input = pl.ctl.move
	elif not game.typing() and not (game.photo_mode and game.photo.free_cam):
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var fast: bool = (pl.ctl.sprint_on if pl.ctl != null else Input.is_action_pressed("sprint")) and not game.typing()
	# 1.1.16: два ползунка в настройках (Управление): обычная скорость и с зажатым Shift
	var k: float = float(Prefs.get_value("strat_pan_fast", 2.0)) if fast else float(Prefs.get_value("strat_pan", 1.0))
	var speed: float = float(DB.setting("strategy_pan", 1.1)) * clampf(float(game.cam_dist), 14.0, 140.0) * clampf(k, 0.05, 10.0) * pan_k()
	var want := Vector3.ZERO
	if input != Vector2.ZERO:
		input = input.normalized()
		var fwd := Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
		var right := Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
		want = (right * input.x - fwd * input.y) * speed
	pl.move_dir = pl.move_dir.lerp(want, minf(1.0, delta * 10.0))
	pl.position += Vector3(pl.move_dir.x, 0, pl.move_dir.z) * delta
	if game.world.wrap:
		pl.position = World.wrap_pos(pl.position)
	else:
		var lim: float = game.world.W * World.C - 1.0
		pl.position.x = clampf(pl.position.x, 1.0, lim)
		pl.position.z = clampf(pl.position.z, 1.0, lim)
	pl.position.y = lerpf(pl.position.y, game.factory.support_at(pl.position), minf(1.0, delta * 8.0))
	ghost.position = pl.position


## Эффекты погоды на экране.
func update(delta: float) -> void:
	if rect == null:
		return
	_t -= delta
	if _t <= 0.0:
		_t = 0.25
		_targets()
	var any := false
	for k in fx:
		fx[k] = move_toward(float(fx[k]), float(_want[k]), delta * 0.6)
		if fx[k] > 0.005:
			any = true
	# 1.1.17: погоду на экране убрали совсем (игрок попросил); fx остаётся только для вязкой камеры в мороз и бурю
	var on: bool = false and any
	rect.visible = on
	if on:
		for k in fx:
			mat.set_shader_parameter(k, float(fx[k]))


func _targets() -> void:
	for k in _want:
		_want[k] = 0.0
	var ev = game.events
	var act: Dictionary = ev.active if ev != null else {}
	var p := view_pos()
	var safe: bool = ev != null and ev.protected(p)
	var wk := func(id: String) -> float:
		# событие набирает силу и спадает плавно (последние 10 с — на убыль)
		if not act.has(id):
			return 0.0
		return clampf(float(act[id]) / 10.0, 0.0, 1.0)
	var cl = game.climate
	var cold := 0.0
	var hot := 0.0
	if cl != null and cl.enabled():
		var c: Dictionary = cl.cfg()
		var air: float = cl.air_now() + cl.heat_at(p)
		cold = clampf((float(c.get("comfort_min", 8)) - air) / 25.0, 0.0, 1.0)
		hot = clampf((air - float(c.get("comfort_max", 30))) / 25.0, 0.0, 0.8)
		hot = maxf(hot, clampf(cl.magma_heat_at(p) / 60.0, 0.0, 0.8))
	_want.frost = maxf(cold, wk.call("frost"))
	_want.burn = maxf(hot, wk.call("heatwave") * 0.6)   # 1.1.16: жара слабее — экран не заливает оранжевым
	_want.toxic = wk.call("acid_rain")
	if game.hazards != null and game.hazards.enabled():
		_want.rad = clampf(float(game.hazards.rad_at(p, false)) / 3.0, 0.0, 1.0)
		for pd in game.hazards.puddles:
			if World.dist(pd.p, p) < 12.0:
				_want.toxic = maxf(_want.toxic, 0.5)
	if ev != null:
		_want.dust = clampf(float(ev.storm), 0.0, 1.0)
		_want.glare = wk.call("solar_flare")
		_want.dark = wk.call("eclipse") * 0.8
		_want.fog = wk.call("dense_fog") * 0.7
	if safe:
		# под навесом штаба, в бункере или под щитом погода слабее
		for k in ["frost", "burn", "toxic", "dust"]:
			_want[k] = float(_want[k]) * 0.35


const SHADER := """shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float frost = 0.0;
uniform float burn = 0.0;
uniform float toxic = 0.0;
uniform float dust = 0.0;
uniform float glare = 0.0;
uniform float dark = 0.0;
uniform float rad = 0.0;
uniform float fog = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; }
	return v;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = UV - 0.5;
	d.x *= 1.6;
	float r = length(d);
	float t = TIME;
	// зной: воздух дрожит (сильнее к краям)
	vec2 wob = vec2(sin(uv.y * 60.0 + t * 7.0), cos(uv.x * 50.0 + t * 6.0)) * 0.0018 * burn * (0.4 + r);
	// мороз: картинка чуть «стекленеет» у краёв
	wob += (vec2(noise(uv * 40.0), noise(uv * 40.0 + 7.0)) - 0.5) * 0.006 * frost * smoothstep(0.25, 0.8, r);
	vec3 col = textureLod(screen_tex, uv + wob, 0.0).rgb;
	float a = 1.0;
	// мороз: иней растёт от краёв, голубой холод, картинка бледнеет
	float fr = fbm(UV * vec2(9.0, 6.0)) * 0.45 + fbm(UV * 34.0) * 0.25;
	float edge = smoothstep(0.75 - frost * 0.45, 0.95, r + fr * 0.55);
	vec3 ice = vec3(0.82, 0.92, 1.0) + (fbm(UV * 90.0) - 0.5) * 0.25;
	col = mix(col, dot(col, vec3(0.33)) * vec3(0.8, 0.9, 1.1), frost * 0.45);
	col = mix(col, ice, edge * frost * 0.92);
	// зной: края горят — языки пламени снизу и по бокам, оранжевый жар
	float fl = fbm(vec2(UV.x * 7.0, UV.y * 4.0 + t * 1.6)) ;
	float fire = smoothstep(0.78 - burn * 0.12, 1.05, r + fl * 0.35 + (UV.y - 0.5) * 0.25);
	vec3 flame = mix(vec3(1.0, 0.25, 0.02), vec3(1.0, 0.85, 0.25), fbm(UV * 12.0 + vec2(0.0, -t * 2.5)));
	col = mix(col, col * vec3(1.08, 0.97, 0.9), burn * 0.3);
	col = mix(col, flame, fire * burn * 0.4);
	// кислотный дождь: ядовитая плёнка, разводы и капли
	float tx = fbm(UV * 5.0 + vec2(t * 0.15, t * 0.1));
	float drops = smoothstep(0.82, 0.9, noise(UV * vec2(60.0, 30.0) + vec2(0.0, t * 3.0)));
	vec3 acid = vec3(0.45, 0.95, 0.15);
	col = mix(col, col * vec3(0.75, 1.05, 0.55), toxic * 0.55);
	col = mix(col, acid, toxic * (smoothstep(0.35, 0.95, r + tx * 0.4) * 0.65 + drops * 0.35));
	// буря: пыль несёт поперёк экрана
	float sd = fbm(vec2(UV.x * 3.0 - t * 1.8, UV.y * 9.0));
	col = mix(col, vec3(0.62, 0.52, 0.38), dust * (0.25 + sd * 0.45));
	// радиация: зелёное зерно и тусклые края
	float gr = hash(UV * 900.0 + fract(t * 13.0));
	col = mix(col, vec3(0.5, 1.0, 0.35), rad * (step(0.985, gr) * 0.9 + smoothstep(0.5, 0.95, r) * 0.25));
	// солнечный выброс: белые вспышки
	col = mix(col, vec3(1.0, 0.97, 0.85), glare * (0.18 + 0.22 * max(0.0, sin(t * 2.3))) * (1.0 - r * 0.5));
	// затмение: темнота к краям
	col *= 1.0 - dark * (0.35 + smoothstep(0.2, 0.9, r) * 0.55);
	// туман: серая пелена
	col = mix(col, vec3(0.72, 0.75, 0.78), fog * (0.35 + fbm(UV * 3.0 + t * 0.05) * 0.4));
	COLOR = vec4(col, a);
}"""
