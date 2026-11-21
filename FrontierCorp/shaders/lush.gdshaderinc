// 1.4: «сочная» трава — общие функции земли (ground.gdshader) и объёмной травы (grass_lush.gdshader),
// чтобы трава и земля под ней были одного цвета и не рябили.
uniform vec3 c_lush_a : source_color = vec3(0.2, 0.47, 0.11);
uniform vec3 c_lush_b : source_color = vec3(0.33, 0.6, 0.15);
uniform vec3 c_lush_tip : source_color = vec3(0.62, 0.84, 0.27);
uniform vec3 c_path : source_color = vec3(0.55, 0.36, 0.22);
uniform float dirt_r = 3.5;          // метров голой земли вокруг залежи

float lh_hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float lh_noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(lh_hash(i), lh_hash(i + vec2(1, 0)), u.x), mix(lh_hash(i + vec2(0, 1)), lh_hash(i + vec2(1, 1)), u.x), u.y);
}
float lh_fbm(vec2 p) {
	return lh_noise(p) * 0.6 + lh_noise(p * 2.07 + 5.0) * 0.28 + lh_noise(p * 4.1 + 9.0) * 0.12;
}

// цвет травы на этом месте: крупные плавные пятна (тёмнее/светлее), без мелкой пестроты
vec3 lush_green(vec2 p) {
	float n = lh_fbm(p * 0.035);
	return mix(c_lush_a, c_lush_b, smoothstep(0.3, 0.75, n));
}

// голая земля вокруг залежей: доля 0..1 с неровным краем (трава на месторождении не растёт)
float lush_dirt(sampler2D ore, vec2 p, float world) {
	float best = 0.0;
	float r = dirt_r;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.785398;
		vec2 q = p + vec2(cos(a), sin(a)) * r;
		best = max(best, texture(ore, fract(q / world)).a);
		vec2 q2 = p + vec2(cos(a + 0.39), sin(a + 0.39)) * r * 0.5;
		best = max(best, texture(ore, fract(q2 / world)).a);
	}
	best = max(best, texture(ore, fract(p / world)).a);
	float edge = (lh_noise(p * 0.45) - 0.5) * 0.7;
	return smoothstep(0.3, 0.55, best + edge);
}

// 1.4: декоративные лужи — без моделей и данных: в каждой клетке 22×22 м с долей puddle_k лужа 1–2.6 м.
// Земля рисует воду и грязь вокруг, трава в этом месте не растёт (функция одна — совпадает точно).
uniform float puddle_k = 0.0;
vec2 lush_puddle(vec2 p) {
	if (puddle_k <= 0.0) return vec2(0.0);
	vec2 i = floor(p / 22.0);
	if (lh_hash(i + 0.7) > puddle_k) return vec2(0.0);
	vec2 c = (i + 0.25 + 0.5 * vec2(lh_hash(i + 3.1), lh_hash(i + 5.7))) * 22.0;
	float r = 0.7 + 1.1 * lh_hash(i + 9.3);
	float a = lh_hash(i + 1.9) * 3.14159;
	vec2 d = p - c;
	d = vec2(cos(a) * d.x + sin(a) * d.y, -sin(a) * d.x + cos(a) * d.y) * vec2(1.0, 1.45);
	float l = length(d) + (lh_noise(p * 0.9) - 0.5) * 0.9 + (lh_noise(p * 2.3) - 0.5) * 0.25;
	return vec2(1.0 - smoothstep(r - 0.12, r + 0.12, l), 1.0 - smoothstep(r, r + 0.9, l));
}
