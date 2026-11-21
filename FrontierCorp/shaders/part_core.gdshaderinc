// Общая часть шейдера деталей (part.gdshader и part_toon.gdshader).
// Универсальный шейдер деталей моделей: цвет экземпляра, текстура, анимации и поле зрения.
// INSTANCE_CUSTOM.x = активность (машина работает), .y = фаза анимации.
#include "res://shaders/fov.gdshaderinc"
#include "res://shaders/zone.gdshaderinc"

uniform int anim = 0;          // 0 нет, 1 вращение, 2 пульс, 3 огонь, 4 ветер, 5 флаг, 6 качание, 7 ноги, 8 дыхание, 9 маятник, 10 тряска, 11 шаг, 12 шаг (колено)
uniform float speed = 1.0;
uniform float amount = 1.0;
uniform bool always = false;
uniform float offset = 0.0;    // сдвиг фазы (0..1): левая и правая ноги ходят по очереди
uniform float metallic = 0.2;
uniform float roughness = 0.5;
uniform float emission = 0.0;
uniform float alpha_cut = 0.0;
uniform bool use_tex = false;
uniform float tex_scale = 1.0;
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;
uniform bool fov_cull = true;
// Рисунок поверхности без картинок: 0 гладкая, 1 дерево, 2 камень, 3 металл, 4 бетон, 5 листва, 6 краска, 7 ткань
uniform int surf = 0;
uniform float surf_amount = 1.0;
uniform float ground_ao = 1.0;
// мелкие детали склеенных моделей (альфа цвета вершины < 1) пропадают дальше этого расстояния — экономия на большом заводе
global uniform float detail_dist;
// 1.4: осень — зелёная листва (листья деревьев, кусты) уходит в жёлтый, оранжевый и красный, у каждого дерева свой
global uniform float autumn;
varying vec3 v_org;

varying float v_glow;
varying float v_vis;
varying vec3 v_lp;
varying vec3 v_wn;
varying float v_wy;

float h3(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float n3(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1, 0, 0)), u.x), mix(h3(i + vec3(0, 1, 0)), h3(i + vec3(1, 1, 0)), u.x), u.y),
		mix(mix(h3(i + vec3(0, 0, 1)), h3(i + vec3(1, 0, 1)), u.x), mix(h3(i + vec3(0, 1, 1)), h3(i + vec3(1, 1, 1)), u.x), u.y), u.z);
}
vec3 to_linear(vec3 c) { return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c)); }
float fbm3(vec3 p) { return n3(p) * 0.5 + n3(p * 2.1) * 0.3 + n3(p * 4.3) * 0.2; }

void vertex() {
	v_lp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz - MODEL_MATRIX[3].xyz;
	v_wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_wy = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
	v_org = MODEL_MATRIX[3].xyz;
	float act = always ? 1.0 : INSTANCE_CUSTOM.x;
	float ph = INSTANCE_CUSTOM.y * 6.2831 + MODEL_MATRIX[3].x * 0.13 + MODEL_MATRIX[3].z * 0.07;
	float t = TIME * speed;
	v_glow = 1.0;
	if (anim == 1) {
		float a = t * act + ph;
		float c = cos(a); float s = sin(a);
		VERTEX.xz = vec2(c * VERTEX.x - s * VERTEX.z, s * VERTEX.x + c * VERTEX.z);
		NORMAL.xz = vec2(c * NORMAL.x - s * NORMAL.z, s * NORMAL.x + c * NORMAL.z);
	} else if (anim == 2) {
		v_glow = mix(1.0, 0.55 + 0.45 * sin(t + ph), amount * max(act, always ? 1.0 : 0.3));
	} else if (anim == 3) {
		float f = 0.6 + 0.25 * sin(t + ph) + 0.15 * sin(t * 2.7 + ph * 3.0);
		v_glow = mix(1.0, f, amount);
	} else if (anim == 4) {
		float wy = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
		VERTEX.x += sin(t + ph) * amount * wy * 0.25;
		VERTEX.z += cos(t * 0.8 + ph) * amount * wy * 0.12;
	} else if (anim == 5) {
		VERTEX.z += sin(t + VERTEX.x * 4.0 + ph) * amount * (VERTEX.x + 0.5);
	} else if (anim == 6) {
		VERTEX.y += sin(t + ph) * amount * act;
	} else if (anim == 7) {
		VERTEX.y += sin(t * act + ph + VERTEX.x * 4.0) * amount * act * abs(VERTEX.z);
		VERTEX.x += cos(t * act + ph + VERTEX.z * 3.0) * amount * act * abs(VERTEX.z);
	} else if (anim == 8) {
		VERTEX *= 1.0 + sin(t + ph) * amount;
	} else if (anim == 9) {
		float a = sin(t + ph) * amount * act;
		VERTEX.xy = vec2(cos(a) * VERTEX.x - sin(a) * VERTEX.y, sin(a) * VERTEX.x + cos(a) * VERTEX.y);
	} else if (anim == 10) {
		VERTEX += vec3(sin(t * 1.3 + ph), sin(t * 1.7), sin(t * 1.1)) * amount * act;
	} else if (anim == 11 || anim == 12) {
		// шаг: деталь качается вокруг своей верхней точки (бедро) вперёд-назад; 12 — сгибается только назад (колено)
		float ph2 = INSTANCE_CUSTOM.y * 6.2831 + offset * 6.2831;
		float w = sin(t + ph2);
		if (anim == 12) { w = -max(0.0, w) * 1.4; }
		float a = w * amount * act;
		vec2 q = VERTEX.xy - vec2(0.0, 0.5);
		float c = cos(a); float s = sin(a);
		VERTEX.xy = vec2(c * q.x - s * q.y, s * q.x + c * q.y) + vec2(0.0, 0.5);
		NORMAL.xy = vec2(c * NORMAL.x - s * NORMAL.y, s * NORMAL.x + c * NORMAL.y);
	}
	if (COLOR.a < 0.99 && detail_dist > 0.0) {
		vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		if (distance(wp, CAMERA_POSITION_WORLD) > detail_dist) {
			VERTEX = vec3(0.0);
		}
	}
	// без поля зрения (иконки, превью, герой) — всегда полный цвет
	v_vis = fov_cull ? fov_vis(MODEL_MATRIX[3].xyz) : 1.0;
	if (fov_cull) {
		VERTEX *= v_vis;
	}
	// за границей зоны деталь спрятана под тучами
	if (zone_hidden(MODEL_MATRIX[3].xyz, CAMERA_POSITION_WORLD)) {
		VERTEX = vec3(0.0);
	}
}

void fragment() {
	// цвета деталей заданы в редакторе как обычные (sRGB) — переводим в линейные для освещения
	vec3 col = to_linear(COLOR.rgb);
	if (use_tex) {
		col *= texture(tex, UV * tex_scale).rgb;
	}
#ifdef FOLIAGE
	bool leafy = true;
#else
	bool leafy = surf == 5;
#endif
	if (autumn > 0.0 && leafy) {
		float gd = col.g - max(col.r, col.b);
		float gk = smoothstep(0.0, 0.03, gd) * autumn;
		float pick = h3(floor(v_org * 0.37) + 3.1);
		float lum = dot(col, vec3(0.3, 0.59, 0.11));
		// линейные цвета: жёлтый, оранжевый, красный; каждое пятое дерево ещё зелёное
		vec3 pal = pick < 0.35 ? vec3(0.78, 0.46, 0.04) : (pick < 0.7 ? vec3(0.72, 0.2, 0.025) : (pick < 0.82 ? vec3(0.45, 0.06, 0.03) : col / max(lum, 0.001) * 0.3));
		pal = mix(pal, pal * vec3(1.1, 1.25, 1.0), n3(v_lp * 2.5 + v_org) * 0.6);
		col = mix(col, pal * clamp(lum * 3.2, 0.25, 1.4), gk);
	}
	float rough = roughness;
	if (surf > 0 && surf_amount > 0.0) {
		vec3 p = v_lp;
		float k = 1.0;
		if (surf == 1) {
			// дерево: волокна вдоль высоты и сучки
			float g = n3(p * vec3(9.0, 0.7, 9.0));
			float rings = 0.5 + 0.5 * sin((p.x + p.z) * 22.0 + g * 7.0);
			k = 0.82 + 0.16 * rings + 0.1 * (g - 0.5);
			k *= 1.0 - 0.3 * smoothstep(0.78, 0.9, n3(p * 3.0 + 4.0));
		} else if (surf == 2) {
			// камень: пятна и тёмные трещины
			float f = fbm3(p * 2.6);
			float crack = 1.0 - smoothstep(0.0, 0.05, abs(n3(p * 3.4 + 9.0) - 0.5));
			k = 0.74 + 0.42 * f - crack * 0.28;
			rough = clamp(roughness + 0.1 * (f - 0.5), 0.0, 1.0);
		} else if (surf == 3) {
			// металл: шлифовка и швы панелей
			float br = n3(p * vec3(60.0, 1.5, 60.0));
			vec3 g = abs(fract(p * 1.6) - 0.5);
			float seam = smoothstep(0.47, 0.495, max(max(g.x * step(0.5, 1.0 - abs(v_wn.x)), g.z * step(0.5, 1.0 - abs(v_wn.z))), g.y * step(0.5, 1.0 - abs(v_wn.y))));
			k = 0.9 + 0.12 * br - seam * 0.3;
			rough = clamp(roughness + 0.15 * (br - 0.5), 0.0, 1.0);
		} else if (surf == 4) {
			// бетон: крапинки и разводы
			float sp = step(0.86, h3(floor(p * 40.0)));
			k = 0.86 + 0.18 * fbm3(p * 1.5) - sp * 0.12;
		} else if (surf == 5) {
			// листва: светлые и тёмные пятна, жёлтые кончики
			float f = fbm3(p * 3.2);
			k = 0.72 + 0.5 * f;
			col = mix(col, col * vec3(1.25, 1.15, 0.7), smoothstep(0.62, 0.85, f) * 0.6);
		} else if (surf == 6) {
			// краска: лёгкая неровность и потёртости
			float f = n3(p * 7.0);
			k = 0.94 + 0.1 * f;
			col = mix(col, col * 0.75 + vec3(0.05), smoothstep(0.82, 0.95, fbm3(p * 5.0)) * 0.5);
		} else if (surf == 7) {
			// ткань: мелкое плетение
			float w = sin(p.x * 120.0) * sin(p.y * 120.0 + p.z * 120.0);
			k = 0.9 + 0.08 * w + 0.08 * (n3(p * 4.0) - 0.5);
		}
		col *= mix(1.0, k, surf_amount);
	}
	// у земли детали чуть темнее — так здания и деревья «стоят», а не висят
	if (fov_cull && ground_ao > 0.0) {
		col *= mix(1.0, mix(0.62, 1.0, smoothstep(0.0, 0.9, v_wy)), ground_ao);
	}
	// вне поля зрения постройки и деревья видны, но темнее и бледнее
	float lum = dot(col, vec3(0.3, 0.59, 0.11));
	col = mix(mix(vec3(lum), col, 0.6) * 0.62, col, v_vis);
	// защита от NaN: одна «битая» точка готового меша размазывается SSAO/SSIL в чёрный квадрат
	if (any(isnan(col)) || any(isinf(col))) { col = vec3(0.5); }
	if (any(isnan(NORMAL))) { NORMAL = vec3(0.0, 0.0, 1.0); }
	ALBEDO = col;
	METALLIC = metallic;
	ROUGHNESS = rough;
	// 17.10: мягкий контровой свет по краю силуэта (здания и роботы читаются на фоне земли) и лак на краске
	RIM = 0.22;
	RIM_TINT = 0.55;
	if (surf == 6) {
		CLEARCOAT = 0.35;
		CLEARCOAT_ROUGHNESS = 0.35;
	}
	EMISSION = col * emission * v_glow;
}
