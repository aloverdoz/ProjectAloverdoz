shader_type spatial;
// Земля: смесь слоёв (трава, грунт, песок, камень, снег), пятна руды, дно водоёмов,
// тени облаков, сетка стройки и затемнение вне поля зрения героя.
#include "res://shaders/fov.gdshaderinc"
#include "res://shaders/zone.gdshaderinc"
uniform sampler2D slate : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D basalt : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D regolith : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D moss : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D yard : repeat_enable, filter_linear;
uniform sampler2D splat : filter_linear, repeat_enable;
uniform sampler2D water : filter_linear, repeat_enable;
uniform sampler2D ore_map : filter_linear, repeat_enable;
uniform sampler2D height_map : filter_linear_mipmap, repeat_enable;
instance uniform float height_lod = 0.0;
instance uniform vec4 hole = vec4(0.0);   // дальняя сетка не рисует там, где есть ближняя
uniform float world_size = 768.0;
uniform vec3 cursor = vec3(0.0);
uniform float grid_on = 0.0;
uniform float cell = 2.0;
uniform float brush_r = 0.0;
uniform bool wrap = false;
varying vec3 wp;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; }
	return v;
}

float hgt(vec2 p) {
	vec2 uv = p / world_size;
	if (!wrap && (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0)) return 0.0;
	float border = max(abs(p.x-hole.x),abs(p.y-hole.y)) - hole.z;
	float lod = height_lod * smoothstep(0.0,cell*exp2(height_lod)*3.0,border);
	return textureLod(height_map, uv, lod).r;
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = hgt(wp.xz);
	float hx = hgt(wp.xz + vec2(cell, 0.0)) - hgt(wp.xz - vec2(cell, 0.0));
	float hz = hgt(wp.xz + vec2(0.0, cell)) - hgt(wp.xz - vec2(0.0, cell));
	VERTEX.y += h;
	wp.y += h;
	NORMAL = normalize(vec3(-hx, 2.0 * cell, -hz));
}

uniform vec3 c_grass_a : source_color = vec3(0.25, 0.48, 0.15);
uniform vec3 c_grass_b : source_color = vec3(0.44, 0.62, 0.18);
uniform vec3 c_grass_dry : source_color = vec3(0.64, 0.63, 0.27);
uniform vec3 c_clover : source_color = vec3(0.18, 0.43, 0.16);
uniform vec3 c_dirt : source_color = vec3(0.48, 0.33, 0.2);
uniform vec3 c_mud : source_color = vec3(0.29, 0.21, 0.14);
uniform vec3 c_sand : source_color = vec3(0.85, 0.77, 0.54);
uniform vec3 c_rock : source_color = vec3(0.54, 0.52, 0.49);
uniform vec3 c_snow : source_color = vec3(0.93, 0.95, 0.97);
uniform float detail = 1.0;
uniform float season_snow = 0.0;          // сезоны (climate.gd): снег зимой
uniform vec4 season_tint = vec4(1.0, 1.0, 1.0, 0.0);   // цвет травы по сезону, a — сила

// пятнышки-камешки: клетки со случайной точкой внутри
float pebbles(vec2 p, float dens) {
	vec2 i = floor(p); vec2 f = fract(p);
	float h = hash(i);
	vec2 c = vec2(hash(i + 3.1), hash(i + 7.7)) * 0.6 + 0.2;
	float r = 0.08 + 0.12 * hash(i + 1.3);
	return step(1.0 - dens, h) * (1.0 - smoothstep(r * 0.6, r, distance(f, c)));
}

// 17.10: рельеф поверхности для света — травяные кочки, камешки, слои камня (нормаль по разнице высот)
float bumpf(vec2 p, vec4 sp) {
	float g = noise(p * 1.9) * 0.55 + noise(p * 5.3 + 3.0) * 0.3 + noise(vec2(p.x * 9.0 + p.y * 2.0, p.y * 9.0 - p.x * 2.0)) * 0.15;
	float d = pebbles(p * 3.0, 0.35) * 0.8 + noise(p * 3.1) * 0.4;
	float r = fbm(p * 0.8) * 0.9 + (1.0 - smoothstep(0.0, 0.05, abs(noise(p * 0.9) - 0.5))) * -0.6;
	return g * 0.35 + d * sp.r * 0.6 + r * sp.b * 1.2 + noise(p * 0.7) * sp.g * 0.4;
}

void fragment() {
	if (hole.w > 0.5 && max(abs(wp.x - hole.x), abs(wp.z - hole.y)) < hole.z) discard;
	vec2 p = wp.xz;
	vec2 uv = p / world_size;
	bool inside = wrap || (uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0);
	uv = fract(uv);
	float n1 = fbm(p * 0.015);
	float n2 = fbm(p * 0.12 + 7.0);
	float n3 = noise(p * 1.7);
	float dist_cam = length(VERTEX);
	float near = (1.0 - smoothstep(30.0, 90.0, dist_cam)) * detail;
	vec4 sp = inside ? texture(splat, uv) : vec4(0.0);
	// песок: рябь от ветра
	float rip = 0.5 + 0.5 * sin(p.x * 2.4 + p.y * 0.8 + noise(p * 0.4) * 6.0);
	vec3 sand = c_sand * (0.9 + 0.12 * n3) * mix(1.0, 0.94 + 0.08 * rip, near);
	vec3 snow = c_snow * (0.93 + 0.08 * n3) + vec3(step(0.995, hash(floor(p * 12.0)))) * 0.25 * near;
	// у воды — влажная грязь, под водой — тёмное дно
	float wet = inside ? texture(water, uv).r : 0.0;
	float o = 2.0 / world_size;
	float wet_near = inside ? (texture(water, uv + vec2(o, 0)).r + texture(water, uv - vec2(o, 0)).r + texture(water, uv + vec2(0, o)).r + texture(water, uv - vec2(0, o)).r) * 0.25 : 0.0;
	float mud = clamp(max(wet, wet_near) * 2.2, 0.0, 1.0) * (1.0 - sp.g * 0.7);
	// Terraces follow the colony footprint. World-space projections keep the cliff grain vertical.
	vec2 grid_uv = p / world_size;
	float pad = texture(yard, grid_uv).r;
	float fringe = cell * 0.74 / world_size;
	pad = max(pad, max(max(texture(yard,grid_uv+vec2(fringe,0)).r,texture(yard,grid_uv-vec2(fringe,0)).r),
	                    max(texture(yard,grid_uv+vec2(0,fringe)).r,texture(yard,grid_uv-vec2(0,fringe)).r))) * float(inside);
	float apron = smoothstep(0.12,0.46,pad + (n3-0.5)*0.18) * (1.0-smoothstep(0.1,0.55,wet));
	vec3 world_n = normalize((INV_VIEW_MATRIX * vec4(NORMAL,0.0)).xyz);
	vec3 slope_n = normalize(cross(dFdx(wp),dFdy(wp)));
	vec3 weights = pow(abs(slope_n),vec3(4.0));
	weights /= max(0.001,weights.x+weights.y+weights.z);
	float cliff = smoothstep(0.12,0.63,sp.b + (1.0-abs(slope_n.y))*1.55);
	vec3 escarpment = vec3(0.0);
	if (cliff > 0.0) {
		if (weights.x > 0.001) escarpment += texture(basalt,wp.zy*0.10).rgb*weights.x;
		if (weights.y > 0.001) escarpment += texture(basalt,p*0.12).rgb*weights.y;
		if (weights.z > 0.001) escarpment += texture(basalt,wp.xy*0.10).rgb*weights.z;
	}
	vec3 earth = texture(regolith,p*0.088).rgb;
	vec3 litter = texture(moss,p*0.115).rgb;
	float cover = smoothstep(0.34,0.66,n2*0.72+n1*0.28) * (1.0-sp.r) * (1.0-sp.b);
	vec3 wild = mix(earth,litter,cover*0.91) * (0.91+0.24*n1);
		wild = mix(wild,sand*0.65,smoothstep(0.18,0.88,sp.g)*0.74);
	wild = mix(wild,snow,smoothstep(0.2,0.78,sp.a));
	wild = mix(wild,escarpment,cliff);
	wild = mix(wild,wild*0.35+vec3(0.007,0.013,0.015),mud*0.75);
	vec3 tile = texture(slate,p*0.12).rgb;
	vec3 col = mix(wild, tile*(1.12+0.23*n2), apron);
	// сезоны: трава желтеет осенью, зимой ложится снег (кроме воды)
	col = mix(col, col * season_tint.rgb * 1.15, season_tint.a * (1.0 - sp.b));
	float ssn = season_snow * smoothstep(0.2, 0.5, n3 * 0.45 + season_snow * 0.55) * (1.0 - smoothstep(0.1, 0.5, wet));
	col = mix(col, snow, ssn);
	vec4 ore = inside ? texture(ore_map, uv) : vec4(0.0);
	float om = ore.a * (0.65 + 0.35 * n2);
	col = mix(col, col * mix(vec3(1.0),ore.rgb*1.3,0.44), om);
	float cloud = smoothstep(0.5, 0.72, fbm(p * 0.005 + vec2(TIME * 0.012, TIME * 0.007)));
	col *= 1.0 - cloud * 0.25;
	vec2 g = abs(fract(p / cell) - 0.5);
	float line = smoothstep(0.47, 0.5, max(g.x, g.y));
	float fade = 1.0 - smoothstep(4.0, 14.0, distance(p, cursor.xz));
	col = mix(col, vec3(0.6, 0.9, 1.0), line * fade * grid_on * 0.35);
	if (brush_r > 0.0) {
		float d = distance(p, cursor.xz);
		float ring = smoothstep(brush_r - 0.6, brush_r - 0.2, d) * (1.0 - smoothstep(brush_r, brush_r + 0.4, d));
		col = mix(col, vec3(1.0, 0.85, 0.3), ring * 0.8);
	}
	// поле зрения: за его пределами земля видна, но темнее и бледнее
	float vis = fov_vis(wp);
	float lum = dot(col, vec3(0.3, 0.59, 0.11));
	col = mix(mix(vec3(lum), col, 0.6) * 0.62, col, vis);
	// 13.10: за границей зоны земля закрыта тучами — сквозь них ничего не видно
	float cov = distance(CAMERA_POSITION_WORLD, zone_cam) < 1.0 ? zone_cover(wp.xz, TIME) : 0.0;
	vec3 cc = cov > 0.0 ? zone_cloud_col(wp.xz, TIME, 0.0) : vec3(0.0);
	// рельеф: только вблизи камеры (дальше его не видно, а считать дорого)
	if (near > 0.01 && cov < 0.99) {
		float e = 0.06;
		float gx = bumpf(p + vec2(e, 0.0), sp) - bumpf(p - vec2(e, 0.0), sp);
		float gz = bumpf(p + vec2(0.0, e), sp) - bumpf(p - vec2(0.0, e), sp);
		vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
		vec2 st = p*0.12;
		float se = 0.0014;
		vec3 lum_weights = vec3(0.23,0.63,0.14);
		if (apron > 0.001) {
		float relief_x = dot(texture(slate,st+vec2(se,0)).rgb-texture(slate,st-vec2(se,0)).rgb,lum_weights);
		float relief_z = dot(texture(slate,st+vec2(0,se)).rgb-texture(slate,st-vec2(0,se)).rgb,lum_weights);
		gx = mix(gx,relief_x*2.8,apron);
		gz = mix(gz,relief_z*2.8,apron);
		}
		wn = normalize(wn - vec3(gx, 0.0, gz) / (2.0 * e) * 0.22 * near * (1.0 - cov));
		NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	}
	SPECULAR = mix(0.28, 0.5, max(mud, sp.b));
	ALBEDO = mix(col, cc * 0.35, cov);
	ROUGHNESS = mix(0.92 - om * 0.3 - mud * 0.35 - apron*0.23, 1.0, cov);
	EMISSION = vec3(0.3, 0.7, 1.0) * line * fade * grid_on * 0.15 * (1.0 - cov) + cc * cov * 0.75;
}
