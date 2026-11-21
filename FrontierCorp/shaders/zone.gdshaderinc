// Граница открытой зоны (13.10): за ней — слой туч, стелющийся по земле. Всё, что за границей (земля, деревья,
// камни, роботы), прячется под тучами. Значения задаёт игра (zone.gd); форма — скруглённый квадрат с волнистым краем.
// Скрывается только в главной камере (zone_cam), чтобы иконки и превью моделей не пропадали.
global uniform float zone_on;
global uniform vec2 zone_center;
global uniform float zone_half;
global uniform float zone_corner;
global uniform float zone_wobble;
global uniform vec3 zone_seed;
global uniform float zone_world;
global uniform vec3 zone_cam;
global uniform float zone_soft;
global uniform float zone_flash;
global uniform vec3 zone_flash_pos;
global uniform float zone_speed;
global uniform float zone_flicker;
global uniform vec4 zone_dark : source_color;
global uniform vec4 zone_cloud : source_color;
global uniform vec4 zone_flash_col : source_color;
global uniform sampler2D zone_rects;   // 15.5: участки, открытые игроком: (центр x, z, половины сторон)
global uniform float zone_nrect;
// 1.5: расстояние до края зоны заранее посчитано в текстуру (zone.gd _bake) — одна выборка вместо цикла по участкам
global uniform sampler2D zone_sdf : filter_linear, repeat_disable;
global uniform vec4 zone_sdf_box;      // x — сторона квадрата текстуры (м, центр — центр зоны), y — что за краем, w > 0.5 — включено
global uniform float zone_lq;          // 1.5: тучи попроще (слабая видеокарта)

float zn_hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float zn_noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(zn_hash(i), zn_hash(i + vec2(1, 0)), u.x), mix(zn_hash(i + vec2(0, 1)), zn_hash(i + vec2(1, 1)), u.x), u.y);
}
float zn_fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * zn_noise(p); p = p * 2.03 + vec2(1.7, 9.2); a *= 0.5; }
	return v;
}

// Расстояние до края зоны: < 0 — внутри, > 0 — под тучами (как zone.gd sd()).
float zone_sd(vec2 xz) {
	if (zone_on < 0.5) {
		return -100000.0;
	}
	vec2 d = xz - zone_center;
	if (zone_world > 0.0) {
		d = mod(d + 0.5 * zone_world, zone_world) - 0.5 * zone_world;
	}
	if (zone_sdf_box.w > 0.5) {
		vec2 uv = d / zone_sdf_box.x + vec2(0.5);
		if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
			return zone_sdf_box.y;
		}
		return texture(zone_sdf, uv).r;
	}
	float r = clamp(zone_corner, 0.0, 1.0) * zone_half;
	vec2 q = abs(d) - vec2(zone_half - r);
	float base = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
	float th = atan(d.y, d.x);
	float w = zone_wobble * (0.5 * sin(3.0 * th + zone_seed.x) + 0.3 * sin(5.0 * th + zone_seed.y) + 0.2 * sin(11.0 * th + zone_seed.z));
	float o = base + w;
	int nr = int(zone_nrect + 0.5);
	for (int i = 0; i < 64; i++) {
		if (i >= nr) { break; }
		vec4 rr = texelFetch(zone_rects, ivec2(i, 0), 0);
		vec2 q2 = abs(d - rr.xy) - rr.zw + vec2(2.0);
		float bd = length(max(q2, vec2(0.0))) + min(max(q2.x, q2.y), 0.0) - 2.0;
		o = min(o, bd + w * 0.35);
	}
	return o;
}


// Цвет туч в точке: клубы, светлые края, мерцание молний внутри и вспышка от удара.
vec3 zone_cloud_col(vec2 xz, float t, float layer) {
	t *= zone_speed;
	if (zone_lq > 0.5) {
		// 1.5: попроще — одна волна шума вместо трёх
		float n1 = zn_fbm(xz * 0.035 + vec2(layer * 3.7 + t * 0.05, layer * 1.3 - t * 0.03));
		return mix(zone_dark.rgb, zone_cloud.rgb, smoothstep(0.3, 0.75, n1)) + zone_flash_col.rgb * zone_flash * exp(-distance(xz, zone_flash_pos.xz) * 0.04);
	}
	vec2 uv = xz * 0.035 + vec2(layer * 3.7, layer * 1.3);
	vec2 q = vec2(zn_fbm(uv + vec2(t * 0.05, -t * 0.03)), zn_fbm(uv + vec2(-t * 0.04, t * 0.06) + 3.1));
	float n = zn_fbm(uv * 1.4 + q * 2.2 + vec2(t * 0.08, 0.0));
	vec3 col = mix(zone_dark.rgb, zone_cloud.rgb, smoothstep(0.3, 0.75, n));
	col += zone_cloud.rgb * 0.3 * smoothstep(0.6, 0.8, n);
	vec2 zcell = floor(uv * 1.5);
	float slot = floor(t * 1.3 * zone_flicker);
	float blink = step(0.985, zn_hash(zcell + slot * 0.37)) * (1.0 - fract(t * 1.3 * zone_flicker)) * smoothstep(0.4, 0.9, n);
	col += zone_flash_col.rgb * blink * 1.2;
	col += zone_flash_col.rgb * zone_flash * exp(-distance(xz, zone_flash_pos.xz) * 0.04) * (0.5 + n);
	return col;
}

// Насколько точка земли закрыта тучами (0 — открыто, 1 — под тучами), с рваным краем.
float zone_cover(vec2 xz, float t) {
	float sd = zone_sd(xz);
	if (sd < -zone_soft * 1.5) {
		return 0.0;
	}
	float n = zn_fbm(xz * 0.12 + vec2(t * 0.06 * zone_speed, -t * 0.04 * zone_speed));
	return smoothstep(-zone_soft * 0.5, zone_soft * 0.5, sd + (n - 0.5) * zone_soft * 1.2);
}

// Объект с опорой в точке zp спрятан под тучами (только в главной камере): там, где тучи уже гуще половины.
bool zone_hidden(vec3 zp, vec3 cam) {
	if (zone_on < 0.5 || distance(cam, zone_cam) >= 1.0) {
		return false;
	}
	return zone_cover(zp.xz, TIME) > 0.2;
}
