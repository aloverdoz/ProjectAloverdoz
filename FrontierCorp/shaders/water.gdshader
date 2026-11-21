shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_always;
// Вода (1.4, рисованный стиль): ровные полосы глубины от берега к середине, светлые пятна ряби,
// чёткая полоса пены у кромки и редкие блики. Без экранных текстур и отражений — дёшево.
#include "res://shaders/fov.gdshaderinc"
#include "res://shaders/zone.gdshaderinc"
uniform sampler2D water : filter_linear, repeat_enable;
uniform float world_size = 768.0;
uniform bool wrap = false;
uniform vec3 c_deep : source_color = vec3(0.12, 0.31, 0.36);
uniform vec3 c_shallow : source_color = vec3(0.31, 0.6, 0.57);
uniform vec3 c_foam : source_color = vec3(0.95, 0.9, 0.78);
varying vec3 wp;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
vec2 hash2(vec2 p) { return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
// расстояние до границы ячеек (рябь «сеточкой», как на рисованной воде)
float cells(vec2 p, float t) {
	vec2 i = floor(p); vec2 f = fract(p);
	float d1 = 8.0; float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = hash2(i + g);
			o = 0.5 + 0.4 * sin(t + 6.2831 * o);
			float d = length(g + o - f);
			if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
		}
	}
	return d2 - d1;
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = wp.xz / world_size;
	if (!wrap && (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0)) {
		discard;
	}
	uv = fract(uv);
	if (zone_hidden(wp, CAMERA_POSITION_WORLD)) {
		discard;
	}
	vec2 p = wp.xz;
	float t = TIME;
	// кромка чуть колышется, чтобы берег не был идеально гладким
	float m = texture(water, uv).r + (noise(p * 0.7 + t * 0.15) - 0.5) * 0.06;
	if (m < 0.5) {
		discard;
	}
	float depth = smoothstep(0.5, 0.95, m);
	// три ровные полосы цвета: мелководье, середина, глубина
	float band = smoothstep(0.0,1.0,depth)*0.69 + noise(p*0.17)*0.22;
	vec3 col = mix(c_shallow, c_deep, band);
	// светлые пятна ряби — границы ячеек, медленно плывут
	vec2 q = p * 0.3 + vec2(t * 0.05, t * 0.03);
	float r = cells(q, t * 0.6);
	float rip = 1.0 - smoothstep(0.015, 0.045, r);
	rip *= smoothstep(0.45, 0.75, noise(p * 0.08 + t * 0.03)) * (1.0 - depth * 0.5);
	col = mix(col, mix(c_shallow, c_foam, 0.3), rip * 0.22);
	col *= 0.94 + 0.1 * noise(p * 0.2 - t * 0.05);
	// пена: чёткая полоса у самой кромки и вторая, прерывистая, чуть дальше
	float foam1 = 1.0 - smoothstep(0.035, 0.05, m - 0.5);
	float wave = 0.5 + 0.5 * sin((m - 0.5) * 90.0 - t * 1.6);
	float foam2 = smoothstep(0.75, 0.85, wave) * (1.0 - smoothstep(0.06, 0.14, m - 0.5)) * step(0.45, noise(p * 0.9 + t * 0.2));
	float foam = max(foam1, foam2 * 0.8);
	vec2 current=p*0.56+vec2(t*0.085,-t*0.035);
	float filament=cells(current+0.19*sin(current.yx*2.3+t*0.24),t*0.23);
	float caustic=(1.0-smoothstep(0.012,0.072,filament))*smoothstep(0.19,0.78,noise(p*0.29));
	col*=0.72+0.4*noise(p*0.41+vec2(t*0.014));
	col+=vec3(0.029,0.13,0.11)*caustic;
	col = mix(col, c_foam, foam*0.45);
	// редкие блики солнца
	float sp = step(0.985, noise(p * 3.0 + vec2(t * 0.8, -t * 0.6))) * (1.0 - foam);
	col += vec3(1.0, 0.92, 0.75) * sp * 0.6;
	float vis = fov_vis(wp);
	col = mix(col * 0.65, col, vis);
	vec3 rippled=normalize(vec3(0.064*cos(p.x*3.6+p.y*1.4+t*1.5)+0.034*sin(p.y*6.4-t),1.0,0.067*sin(p.y*2.63+p.x*1.4+t)));
	NORMAL = normalize((VIEW_MATRIX * vec4(rippled,0.0)).xyz);
	EMISSION=vec3(0.004,0.015,0.014)*(1.0+caustic);
	ALBEDO = col;
	ROUGHNESS = 0.23;
	METALLIC = 0.0;
	SPECULAR = 0.35;
	ALPHA = clamp(mix(0.82, 0.95, depth) + foam * 0.1, 0.0, 1.0);
}
