shader_type spatial;
render_mode cull_disabled;
uniform sampler2D basalt : source_color,repeat_enable,filter_linear_mipmap_anisotropic;
uniform sampler2D paving : source_color,repeat_enable,filter_linear_mipmap_anisotropic;
uniform sampler2D earth : source_color,repeat_enable,filter_linear_mipmap_anisotropic;
uniform bool ruins = false;
varying vec3 p;
varying vec3 face;
void vertex(){
	p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	face=MODEL_NORMAL_MATRIX*NORMAL;
}
void fragment(){
	vec3 w=pow(abs(normalize(face)),vec3(5.0));
	w/=max(0.0001,w.x+w.y+w.z);
	vec3 stone=texture(basalt,p.zy*0.135).rgb*w.x+texture(basalt,p.xy*0.135).rgb*w.z;
	vec3 bed=texture(earth,p.xz*0.15).rgb;
	vec3 slabs=texture(paving,p.xz*0.16).rgb;
	vec3 overhead=texture(basalt,p.xz*0.13).rgb;
	vec3 floor_col=ruins?slabs:mix(bed*0.61,slabs,0.26);
	vec3 col=stone+w.y*(face.y>0.0?floor_col:overhead);
	float damp=0.5+0.5*sin(p.z*0.52+sin(p.x*0.82));
	ALBEDO=col*(0.90+0.15*damp);
	ROUGHNESS=mix(0.79,0.35,damp*w.y);
	SPECULAR=0.47;
}
