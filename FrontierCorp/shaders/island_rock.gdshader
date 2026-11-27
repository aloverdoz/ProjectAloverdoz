shader_type spatial;
uniform sampler2D stone : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D soil : source_color, repeat_enable, filter_linear_mipmap;
varying vec3 wp;
varying vec3 wn;
void vertex(){
	wp=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
	wn=MODEL_NORMAL_MATRIX*NORMAL;
}
void fragment(){
	vec2 uv=wp.xz*.38;
	vec3 s=texture(stone,uv).rgb;
	vec3 moss=texture(soil,uv*.72).rgb;
	vec2 tile=abs(fract(wp.xz*.5)-.5);
	float rim=smoothstep(.46,.498,max(tile.x,tile.y));
	vec3 top=mix(s*.85,moss*vec3(.87,1.03,.67),.36+.15*sin(wp.z+wp.x*.7));
	vec2 side=vec2(abs(wn.x)>.5?wp.z:wp.x,wp.y)*.7;
	ALBEDO=wn.y>.6?mix(top,top*.62,rim):texture(stone,side).rgb*vec3(.66,.61,.56);
	ROUGHNESS=.88;
}
