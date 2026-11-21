shader_type spatial;
// Груз на ленте: движение считает видеокарта; процессор сообщает только момент въезда.
// curve: 0 прямо, +1 вход слева (-Z), -1 вход справа (+Z). Груз едет по дуге.
// Цвет предмета — INSTANCE_CUSTOM.rgb, момент въезда — INSTANCE_CUSTOM.a.
// Альфа цвета вершины — вид детали: 1.0 красится в цвет предмета, 0.9 — и светится,
// 0.8 — свой цвет, 0.7 — свой цвет и светится. Альфа экземпляра 0 — груза нет.
#include "res://shaders/fov.gdshaderinc"
uniform float now = 0.0;
uniform float speed = 2.0;
uniform float curve = 0.0;
varying vec3 tint;
varying float glow;

void vertex() {
	float p = clamp((now - INSTANCE_CUSTOM.a) * speed, 0.0, 1.0);
	vec3 off;
	if (curve == 0.0) {
		off = vec3((p - 0.5) * 2.0, 0.0, 0.0);
	} else {
		float a = p * 1.5708;
		off = vec3(1.0 - cos(a), 0.0, curve * (-1.0 + sin(a)));
		float r = -curve * a;
		VERTEX.xz = vec2(cos(r) * VERTEX.x - sin(r) * VERTEX.z, sin(r) * VERTEX.x + cos(r) * VERTEX.z);
		NORMAL.xz = vec2(cos(r) * NORMAL.x - sin(r) * NORMAL.z, sin(r) * NORMAL.x + cos(r) * NORMAL.z);
	}
	float kind = COLOR.a;
	vec3 lc = mix(COLOR.rgb / 12.92, pow((COLOR.rgb + 0.055) / 1.055, vec3(2.4)), step(0.04045, COLOR.rgb));
	tint = kind > 0.85 ? lc * INSTANCE_CUSTOM.rgb : lc;
	glow = (kind > 0.85 && kind < 0.95) || (kind > 0.65 && kind < 0.75) ? 1.0 : 0.0;
	if (kind < 0.5) {
		VERTEX = vec3(0.0);
	} else {
		VERTEX += off;
		VERTEX.y += sin(p * 3.14159) * 0.03;
	}
}

void fragment() {
	ALBEDO = tint;
	ROUGHNESS = 0.45;
	METALLIC = 0.3;
	EMISSION = tint * glow * 2.0;
}
