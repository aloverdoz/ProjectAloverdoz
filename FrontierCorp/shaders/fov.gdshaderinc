// Поле зрения героя (как в Project Zomboid). Значения задаёт игра каждый кадр.
global uniform vec3 view_pos;
global uniform vec3 view_dir;
global uniform float view_cos;
global uniform float view_range;
global uniform float view_near;
global uniform float view_on;

float fov_vis(vec3 wp) {
	if (view_on < 0.5) {
		return 1.0;
	}
	vec2 d = wp.xz - view_pos.xz;
	float dist = length(d);
	if (dist < view_near) {
		return 1.0;
	}
	float c = dot(d / dist, normalize(view_dir.xz));
	float cone = smoothstep(view_cos - 0.06, view_cos + 0.02, c);
	float rng = 1.0 - smoothstep(view_range - 8.0, view_range, dist);
	float near_soft = 1.0 - smoothstep(view_near, view_near + 3.0, dist);
	return max(cone * rng, near_soft);
}
