shader_type canvas_item;
// Миникарта и большая карта: рисует землю, воду, холмы, руду и лес прямо из карт мира.
uniform sampler2D splat : filter_linear, repeat_enable;
uniform sampler2D water : filter_linear, repeat_enable;
uniform sampler2D height_map : filter_linear, repeat_enable;
uniform sampler2D ore_map : filter_linear, repeat_enable;
uniform sampler2D occ : filter_nearest, repeat_enable;
uniform vec2 center = vec2(0.0);
uniform float view_m = 200.0;
uniform float rot = 0.0;
uniform float world_size = 768.0;
uniform float cell = 2.0;
uniform bool wrap = false;
uniform bool round_mask = true;
uniform float aspect = 1.0;
uniform vec3 c_grass : source_color = vec3(0.30, 0.52, 0.2);
uniform vec3 c_dirt : source_color = vec3(0.5, 0.36, 0.22);
uniform vec3 c_sand : source_color = vec3(0.85, 0.77, 0.54);
uniform vec3 c_rock : source_color = vec3(0.55, 0.53, 0.5);
uniform vec3 c_snow : source_color = vec3(0.93, 0.95, 0.97);
uniform vec3 c_water : source_color = vec3(0.16, 0.45, 0.68);
uniform vec3 c_tree : source_color = vec3(0.12, 0.3, 0.12);
uniform sampler2D fog_tex : filter_linear, repeat_enable;
uniform bool fog_on = false;
// 13.10: открытая зона — снаружи буря (тёмно-фиолетовая рябь)
#include "res://shaders/zone.gdshaderinc"

float hgt(vec2 p) { return texture(height_map, fract(p / world_size)).r; }

void fragment() {
	vec2 u = UV - 0.5;
	float r = length(u);
	u.y *= aspect;
	if (round_mask && r > 0.5) discard;
	float c = cos(rot);
	float s = sin(rot);
	vec2 d = vec2(c * u.x + s * u.y, -s * u.x + c * u.y) * view_m;
	vec2 p = center + d;
	vec2 wuv = p / world_size;
	if (!wrap && (wuv.x < 0.0 || wuv.y < 0.0 || wuv.x > 1.0 || wuv.y > 1.0)) {
		COLOR = vec4(0.06, 0.07, 0.09, 1.0);
	} else {
		wuv = fract(wuv);
		vec4 sp = texture(splat, wuv);
		vec3 col = c_grass;
		col = mix(col, c_dirt, smoothstep(0.1, 0.6, sp.r));
		col = mix(col, c_sand, smoothstep(0.1, 0.6, sp.g));
		col = mix(col, c_rock, smoothstep(0.1, 0.6, sp.b));
		col = mix(col, c_snow, smoothstep(0.1, 0.6, sp.a));
		vec4 ore = texture(ore_map, wuv);
		col = mix(col, ore.rgb, ore.a * 0.85);
		if (texture(occ, wuv).r > 0.5) col = mix(col, c_tree, 0.75);
		// холмы: светлее к вершине, тень на склонах
		float h = hgt(p);
		float hx = hgt(p + vec2(cell, 0.0)) - hgt(p - vec2(cell, 0.0));
		float hz = hgt(p + vec2(0.0, cell)) - hgt(p - vec2(0.0, cell));
		col *= clamp(1.0 + (-hx - hz) * 0.35, 0.6, 1.35) * (0.92 + h * 0.025);
		float w = texture(water, wuv).r;
		col = mix(col, c_water, smoothstep(0.35, 0.6, w));
		if (fog_on) {
			// туман войны: неоткрытое тёмное, с лёгкой рябью облаков
			float f = texture(fog_tex, wuv).r;
			float n = fract(sin(dot(floor(p / 6.0), vec2(12.9898, 78.233))) * 43758.5453);
			vec3 fogc = vec3(0.07, 0.08, 0.1) + n * 0.025;
			col = mix(fogc, col, smoothstep(0.15, 0.85, f));
		}
		if (zone_on > 0.5) {
			float out_d = zone_sd(p);
			float n2 = fract(sin(dot(floor(p / 5.0), vec2(12.9898, 78.233))) * 43758.5453);
			vec3 stormc = vec3(0.09, 0.08, 0.13) + n2 * 0.035;
			col = mix(col, stormc, smoothstep(-0.5, 1.5, out_d));
			col = mix(col, vec3(0.6, 0.7, 1.0), (1.0 - smoothstep(0.0, 1.2, abs(out_d))) * 0.6);
		}
		COLOR = vec4(col, 1.0);
	}
	if (round_mask) {
		COLOR.rgb = mix(COLOR.rgb, vec3(0.08, 0.09, 0.11), smoothstep(0.47, 0.49, r));
	}
}
