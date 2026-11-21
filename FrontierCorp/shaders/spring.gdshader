shader_type spatial;
render_mode cull_disabled, blend_mix, depth_prepass_alpha;
void fragment(){
	float lane = sin(UV.x*113.0+sin(UV.y*9.0-TIME*3.0)*1.5)*0.5+0.5;
	float water = sin(20.0*UV.y-TIME*7.0+UV.x*35.0)*0.5+0.5;
	float foam = smoothstep(0.72,0.99,lane)*(0.40+0.60*water);
	vec3 tint=mix(vec3(0.018,0.28,0.32),vec3(0.59,0.92,0.89),foam+0.22*UV.y);
	ALBEDO=tint;
	EMISSION=tint*(0.19+0.27*foam);
	ROUGHNESS=0.23;
	ALPHA=(0.58+0.35*foam)*smoothstep(0.0,0.09,UV.x)*(1.0-smoothstep(0.91,1.0,UV.x));
}
