shader_type spatial;
render_mode cull_disabled;
// 1.4: объёмная «сочная» трава вокруг героя. Широкие листья пучками, цвет — как у земли под ними
// (крупные плавные пятна), поэтому издалека не рябит. Трава расступается вокруг героев и монстров рядом.
// Не растёт на песке, в воде, под зданиями и на голой земле вокруг залежей.
#include "res://shaders/zone.gdshaderinc"
#include "res://shaders/lush.gdshaderinc"
uniform sampler2D occ : filter_nearest, repeat_enable;
uniform sampler2D splat : filter_linear, repeat_enable;
uniform sampler2D water : filter_linear, repeat_enable;
uniform sampler2D height_map : filter_linear, repeat_enable;
uniform sampler2D ore_map : filter_linear, repeat_enable;
uniform float world_size = 768.0;
uniform bool wrap = false;
uniform float radius = 26.0;
uniform float spacing = 0.26;
uniform vec3 center = vec3(0.0);
uniform float inner = 0.0;            // дальнее кольцо: ближе этого радиуса травы нет (там ближняя)
uniform float tuft_scale = 1.0;       // дальние пучки крупнее и реже
uniform vec4 pushers[4];               // xz — позиция, w — радиус (0 — нет)
uniform float season_snow = 0.0;
uniform vec4 season_tint = vec4(1.0, 1.0, 1.0, 0.0);
varying float hgt;
varying vec3 v_col;
varying float v_tone;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void vertex() {
	vec3 root = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float h1 = hash(root.xz);
	float h2 = hash(root.xz + 17.3);
	vec2 jitter = (vec2(h1, h2) - 0.5) * spacing * 0.9;
	vec2 rp = root.xz + jitter;
	float a = h1 * 6.2831;
	float c = cos(a); float s = sin(a);
	vec3 v = VERTEX * tuft_scale;
	v.xz = vec2(c * v.x - s * v.z, s * v.x + c * v.z);
	vec2 uv = fract(rp / world_size);
	float d = distance(rp, center.xz);
	float fade = 1.0 - smoothstep(radius * 0.7, radius, d);
	if (inner > 0.0) {
		fade *= smoothstep(inner * 0.7, inner, d);
	}
	float blocked = texture(occ, uv).r;
	vec4 sp = texture(splat, uv);
	float bare = max(sp.g * 1.6, texture(water, uv).r * 2.0) + sp.a;
	bare = max(bare, lush_dirt(ore_map, rp, world_size) * 1.3);
	bare = max(bare, lush_puddle(rp).y * 1.2);
	float sc = (0.8 + h2 * 0.4) * fade * (1.0 - step(0.5, blocked)) * (1.0 - smoothstep(0.25, 0.6, bare));
	// у края голой земли и песка трава ниже — плавная кромка, как на газоне
	sc *= 1.0 - smoothstep(0.05, 0.55, bare) * 0.45;
	// крупные пятна чуть выше и ниже
	sc *= 0.85 + 0.3 * lh_fbm(rp * 0.08 + 3.0);
	// слишком маленькие пучки убираем совсем: иначе у кромки остаются тёмные «звёздочки»
	bool gone = sc < 0.22;
	sc = (sc - 0.22) / 0.78 * 0.9 + 0.1;
	v.y *= sc;
	v.xz *= mix(1.0, sc, 0.4);
	// герои и монстры раздвигают траву: листья отклоняются и приминаются
	vec2 push = vec2(0.0);
	float flat_k = 0.0;
	for (int i = 0; i < 4; i++) {
		if (pushers[i].w <= 0.0) continue;
		vec2 dd = rp - pushers[i].xz;
		float l = length(dd);
		float k = 1.0 - smoothstep(pushers[i].w * 0.35, pushers[i].w, l);
		push += (l > 0.001 ? dd / l : vec2(1.0, 0.0)) * k;
		flat_k = max(flat_k, k);
	}
	float t = clamp(v.y / max(0.05, 0.55 * sc * tuft_scale), 0.0, 1.0);
	v.xz += push * v.y * 0.9;
	v.y *= 1.0 - flat_k * 0.45;
	// ветер: плавная волна по полю, соседние пучки качаются вместе
	float wind = sin(TIME * 1.3 + rp.x * 0.11 + rp.y * 0.07) * 0.6 + sin(TIME * 0.7 + rp.y * 0.05) * 0.4;
	v.x += wind * 0.1 * t * t * sc;
	hgt = t;
	v.xz += jitter;
	v.y += textureLod(height_map, uv, 0.0).r;
	VERTEX = v;
	vec3 g = lush_green(rp);
	v_col = g;
	v_tone = h2;
	NORMAL = normalize(vec3(0.0, 1.0, 0.0) + vec3(NORMAL.x, 0.0, NORMAL.z) * 0.25);
	if (gone || zone_hidden(root, CAMERA_POSITION_WORLD)) {
		VERTEX = vec3(0.0);
	}
}

void fragment() {
	// снизу — цвет земли в тени, к кончику светлее и теплее; разница между пучками маленькая (не рябит)
	vec3 base = v_col * 0.62;
	vec3 tip = mix(v_col * 1.25, c_lush_tip, 0.45) * (0.96 + 0.08 * v_tone);
	vec3 col = mix(base, tip, smoothstep(0.0, 0.9, hgt));
	col = mix(col, col * season_tint.rgb * 1.15, season_tint.a);
	col = mix(col, vec3(0.9, 0.93, 0.96), season_snow * clamp(hgt * 1.4, 0.3, 1.0));
	ALBEDO = col;
	ROUGHNESS = 0.8;
	SPECULAR = 0.2;
	BACKLIGHT = vec3(0.18, 0.26, 0.08) * hgt;
}
