shader_type spatial;
// Слой туч, стелющийся по земле за границей открытой зоны (13.10). Несколько тонких слоёв друг над другом
// дают объём; у края зоны тучи рваные и редеют. Цвета и скорость — «Настройки» → «Зона и буря».
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
#include "res://shaders/zone.gdshaderinc"

uniform float layer = 0.0;        // номер слоя: 0 — нижний, плотный
uniform float density = 0.9;      // непрозрачность слоя вдали от края

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// лёгкое колыхание верха туч
	float t = TIME * zone_speed;
	VERTEX.y += (zn_noise(wp.xz * 0.08 + vec2(t * 0.1, layer)) - 0.5) * (0.6 + layer * 0.4);
}

void fragment() {
	float t = TIME;
	float sd = zone_sd(wp.xz);
	float n = zn_fbm(wp.xz * (0.05 + layer * 0.02) + vec2(t * 0.05 * zone_speed, layer * 7.0 - t * 0.03 * zone_speed));
	// край: рваные клочья, которые чуть заходят в зону и уходят обратно
	float edge = smoothstep(-zone_soft * 0.6, zone_soft * 0.8, sd + (n - 0.5) * zone_soft * 1.6 - layer * zone_soft * 0.25);
	float puff = mix(0.55, 1.0, smoothstep(0.25, 0.7, n));
	float a = edge * puff * density;
	if (a < 0.01) {
		discard;
	}
	vec3 col = zone_cloud_col(wp.xz, t, layer);
	// верхние слои светлее — объём
	col *= 0.75 + layer * 0.22 + n * 0.25;
	ALBEDO = col;
	ALPHA = clamp(a, 0.0, 1.0);
}
