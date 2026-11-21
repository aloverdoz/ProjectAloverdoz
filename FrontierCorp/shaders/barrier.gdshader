shader_type spatial;
// Энергощит (13.10): прозрачный купол с сотами и ярким краем; вспыхивает при попадании, тускнеет при износе.
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(0.35, 0.8, 1.0, 1.0);
uniform float strength = 1.0;   // запас щита 0..1
uniform float flash = 0.0;      // попадание

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float rim = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.5);
	// соты
	vec2 uv = vec2(atan(lp.z, lp.x) * 6.0, lp.y * 2.2);
	vec2 h = abs(fract(uv + vec2(0.5 * mod(floor(uv.y), 2.0), 0.0)) - 0.5);
	float hex = smoothstep(0.42, 0.48, max(h.x * 1.2, h.y + h.x * 0.4));
	float wave = 0.5 + 0.5 * sin(lp.y * 3.0 - TIME * 2.0);
	float a = (0.05 + rim * 0.55 + hex * 0.12 * wave) * (0.35 + 0.65 * strength) + flash * (0.25 + rim * 0.6);
	ALBEDO = color.rgb * a * 1.6;
}
