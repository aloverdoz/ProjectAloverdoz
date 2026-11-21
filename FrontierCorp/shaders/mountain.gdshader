shader_type spatial;
// Горы за краем карты: неровные склоны, трава внизу, слои камня, снег на вершинах.
uniform vec3 c_rock : source_color = vec3(0.52, 0.48, 0.42);
uniform vec3 c_grass : source_color = vec3(0.33, 0.46, 0.18);
uniform vec3 c_snow : source_color = vec3(0.93, 0.95, 0.97);
uniform sampler2D basalt : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
instance uniform float height = 100.0;
instance uniform float seed = 0.0;
varying vec3 wp;
varying float rel;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * noise(p); p *= 2.07; a *= 0.5; }
	return v;
}

#include "res://shaders/zone.gdshaderinc"

void vertex() {
	// склоны неровные: вершины сдвигаются наружу и внутрь по шуму
	float ang = atan(VERTEX.z, VERTEX.x);
	float k = fbm(vec2(ang * 3.0 + seed, VERTEX.y * 4.0 + seed));
	float side = step(-0.49, VERTEX.y) * step(VERTEX.y, 0.49);
	float bench = floor((VERTEX.y+0.5)*8.0)*0.125;
	VERTEX.xz *= 1.0 + (k - 0.5) * 0.85 * side + (fract((VERTEX.y+0.5)*8.0)-0.5)*0.09;
	VERTEX.y = mix(VERTEX.y, bench-0.5, 0.22*side);
	VERTEX.y += (k - 0.5) * 0.12 * step(0.49, VERTEX.y);
	rel = VERTEX.y + 0.5;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (zone_hidden(wp, CAMERA_POSITION_WORLD)) {
		discard;
	}
	float n = fbm(wp.xz * 0.02 + seed);
	float strata = 0.5 + 0.5 * sin(wp.y * 0.35 + n * 5.0);
	vec3 col = c_rock * (0.75 + 0.3 * n) * (0.9 + 0.15 * strata);
	float grass = 1.0 - smoothstep(0.12, 0.3, rel + (n - 0.5) * 0.25);
	col = mix(col, c_grass * (0.8 + 0.3 * n), grass);
	float slope = 1.0 - abs(normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz).y);
	float snow = smoothstep(0.68, 0.76, rel + (n - 0.5) * 0.2 - slope * 0.05);
	vec3 nrm = abs(normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz));
	vec3 facets = mix(texture(basalt,wp.zy*0.039).rgb,texture(basalt,wp.xy*0.039).rgb,nrm.z/(nrm.x+nrm.z+0.001));
	col = mix(facets*(0.93+0.18*strata),col,grass*0.54);
	col = mix(col,c_snow,snow*0.48);
	ALBEDO = col;
	ROUGHNESS = mix(0.95, 0.6, snow);
}
