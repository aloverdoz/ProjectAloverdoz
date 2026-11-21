shader_type spatial;
// Тонкий тёмный контур вокруг детали (рисуется изнанкой чуть раздутой модели).
render_mode unshaded, cull_front, depth_draw_opaque;
#include "res://shaders/fov.gdshaderinc"
#include "res://shaders/zone.gdshaderinc"
uniform float width = 1.6;       // в пикселях
uniform vec4 color : source_color = vec4(0.05, 0.05, 0.07, 1.0);
uniform bool fov_cull = true;

void vertex() {
	if (fov_cull) {
		VERTEX *= fov_vis(MODEL_MATRIX[3].xyz);
	}
	if (zone_hidden(MODEL_MATRIX[3].xyz, CAMERA_POSITION_WORLD)) {
		VERTEX = vec3(0.0);
	}
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 nv = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec2 off = (PROJECTION_MATRIX * vec4(nv, 0.0)).xy;
	if (length(off) > 0.0001) {
		off = normalize(off);
	}
	clip.xy += off * width * 2.0 * clip.w / VIEWPORT_SIZE;
	POSITION = clip;
}

void fragment() {
	ALBEDO = color.rgb;
}
