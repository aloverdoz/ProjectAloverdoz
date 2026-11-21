shader_type spatial;
render_mode cull_disabled;
// Трава вокруг героя: патч двигается за героем, травинки «прибиты» к миру.
// Не растёт на песке, камне, снегу, в воде и под зданиями.
#include "res://shaders/zone.gdshaderinc"
uniform sampler2D occ : filter_nearest, repeat_enable;
uniform sampler2D splat : filter_linear, repeat_enable;
uniform sampler2D water : filter_linear, repeat_enable;
uniform sampler2D height_map : filter_linear, repeat_enable;
uniform sampler2D ore_map : filter_linear, repeat_enable;
uniform float world_size = 768.0;
uniform bool wrap = false;
uniform float radius = 30.0;
uniform vec3 center = vec3(0.0);
uniform vec3 c_base : source_color = vec3(0.18, 0.37, 0.11);
uniform vec3 c_tip : source_color = vec3(0.61, 0.79, 0.29);
uniform float season_snow = 0.0;          // сезоны (climate.gd): трава под снегом
uniform vec4 season_tint = vec4(1.0, 1.0, 1.0, 0.0);
uniform vec3 c_dry : source_color = vec3(0.64, 0.63, 0.27);
varying float hgt;
varying float v_tone;
varying float v_dry;
varying float v_big;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void vertex() {
	vec3 root = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float h1 = hash(root.xz);
	float h2 = hash(root.xz + 17.3);
	vec2 jitter = (vec2(h1, h2) - 0.5) * 0.45;
	float a = h1 * 6.2831;
	float c = cos(a); float s = sin(a);
	vec3 v = VERTEX;
	v.xz = vec2(c * v.x - s * v.z, s * v.x + c * v.z);
	vec2 uv = fract((root.xz + jitter) / world_size);
	float d = distance(root.xz + jitter, center.xz);
	float fade = 1.0 - smoothstep(radius * 0.6, radius, d);
	float blocked = texture(occ, uv).r;
	vec4 sp = texture(splat, uv);
	float bare = max(max(sp.g, sp.b), max(sp.a, texture(water, uv).r)) + sp.r * 0.6 + texture(ore_map, uv).a * 1.2;
	float patch = sin(root.x * 0.11 + sin(root.z * 0.07) * 2.0) * 0.5 + 0.5;
	v_tone = h2;
	v_big = sin(root.x * 0.045 + sin(root.z * 0.031) * 3.0) * 0.5 + 0.5;
	v_dry = smoothstep(0.55, 1.0, sp.r + patch * 0.3) * 0.8;
	float sc = (0.45 + h2 * 0.75 + patch * 0.35) * fade * (1.0 - step(0.5, blocked)) * (1.0 - smoothstep(0.25, 0.5, bare));
	v.y *= sc;
	v.xz *= mix(1.0, sc, 0.5);
	float wind = sin(TIME * 1.8 + root.x * 0.15 + root.z * 0.1) + 0.5 * sin(TIME * 3.1 + root.x * 0.5);
	v.x += wind * 0.12 * v.y * v.y;
	v.xz += jitter;
	hgt = v.y;
	v.y += textureLod(height_map, uv, 0.0).r;
	VERTEX = v;
	NORMAL = vec3(0.0, 1.0, 0.0);
	if (zone_hidden(root, CAMERA_POSITION_WORLD)) {
		VERTEX = vec3(0.0);
	}
}

void fragment() {
	// 17.10: крупные пятна (сочная тёмная трава ↔ выгоревшая светлая), тёмное основание пучка
	vec3 tip = mix(c_tip, c_dry, clamp(v_dry + v_big * 0.35, 0.0, 1.0)) * (0.8 + 0.35 * v_tone) * mix(0.82, 1.08, v_big);
	vec3 base = c_base * (0.55 + 0.2 * v_tone);
	tip = mix(vec3(dot(tip, vec3(0.3, 0.59, 0.11))), tip, 0.82);
	ALBEDO = mix(base, tip, smoothstep(0.0, 0.5, hgt));
	ALBEDO = mix(ALBEDO, ALBEDO * season_tint.rgb * 1.2, season_tint.a);
	ALBEDO = mix(ALBEDO, vec3(0.9, 0.93, 0.96), season_snow * clamp(hgt * 1.4, 0.3, 1.0));
	ROUGHNESS = 0.85;
	BACKLIGHT = vec3(0.25, 0.35, 0.1);
}
