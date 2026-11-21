shader_type spatial;
// Лента конвейера: прямая (curve = 0) или поворот (curve = ±1, развёртка по UV).
#include "res://shaders/fov.gdshaderinc"
uniform float speed = 2.0;
uniform float curve = 0.0;
varying vec3 lp;
varying vec2 bu;
varying float up;
varying float v_vis;

void vertex() {
	lp = VERTEX;
	bu = UV;
	up = NORMAL.y;
	v_vis = fov_vis(MODEL_MATRIX[3].xyz);
}

void fragment() {
	float along;
	float across;
	if (curve == 0.0) {
		along = lp.x;
		across = lp.z / 0.65;
	} else {
		along = bu.x * 1.5708;
		across = (bu.y - 0.5) * 2.0;
	}
	float top = step(0.5, up);
	// 1.1.10: остриё шеврона смотрит туда, куда едет лента (раньше было задом наперёд)
	float s = fract((along + abs(across) * 0.52) * 2.0 - TIME * speed * 4.0);
	float chevron = smoothstep(0.0, 0.08, s) * (1.0 - smoothstep(0.32, 0.4, s));
	float edge = smoothstep(0.7, 0.8, abs(across));
	float tread=smoothstep(0.16,0.30,fract(along*13.0-TIME*speed*26.0));
	vec3 rubber = mix(vec3(0.026,0.032,0.038),vec3(0.083,0.091,0.094),tread);
	chevron *= (1.0-smoothstep(0.28,0.45,abs(across)));
	vec3 col = mix(rubber, vec3(0.95, 0.62, 0.12), chevron * 0.52 * top * (1.0 - edge));
	col = mix(col, COLOR.rgb, edge);
	float lum = dot(col, vec3(0.3, 0.59, 0.11));
	col = mix(mix(vec3(lum), col, 0.4) * 0.5, col, v_vis);
	ALBEDO = col;
	ROUGHNESS = mix(0.8, 0.35, edge);
	METALLIC = edge * 0.6;
	EMISSION = vec3(0.9, 0.5, 0.05) * chevron * top * (1.0 - edge) * 0.06 * v_vis;
}
