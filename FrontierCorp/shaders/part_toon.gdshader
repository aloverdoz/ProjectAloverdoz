shader_type spatial;
// Детали героя и монстров в мультяшном стиле: свет ступеньками (cel-shading), светлый край (rim) и блик.
// Всё остальное (цвет, анимации, поле зрения, свечение) — как у обычных деталей.
#include "res://shaders/part_core.gdshaderinc"

uniform int toon_steps = 3;            // сколько ступенек света (2 — резко, 4 — мягче)
uniform float toon_shade = 0.38;       // насколько светлая тень (0 — чёрная, 1 — без тени)
uniform float toon_rim = 0.35;         // светлая кромка по контуру
uniform float toon_spec = 0.45;        // яркость блика

void light() {
	float nd = dot(NORMAL, LIGHT);
	float lit = clamp(nd, 0.0, 1.0) * min(ATTENUATION, 1.0);
	float st = float(max(toon_steps, 2) - 1);
	// ступеньки с узкими мягкими краями, чтобы не рябило
	float q = floor(lit * st + 0.5) / st;
	float edge = smoothstep(0.0, 0.08, abs(fract(lit * st + 0.5) - 0.5));
	q = mix(q, lit, (1.0 - edge) * 0.25);
	float band = mix(toon_shade, 1.0, q);
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * band;
	vec3 h = normalize(LIGHT + VIEW);
	float sp = smoothstep(0.955, 0.97, dot(NORMAL, h)) * lit;
	SPECULAR_LIGHT += LIGHT_COLOR / PI * sp * toon_spec * (1.0 - ROUGHNESS * 0.6);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	SPECULAR_LIGHT += LIGHT_COLOR / PI * smoothstep(0.45, 0.55, rim * (0.4 + 0.6 * lit)) * toon_rim;
}
