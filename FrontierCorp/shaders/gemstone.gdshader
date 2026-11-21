shader_type spatial;
uniform vec4 body : source_color;
uniform vec4 light_tip : source_color;
uniform float facet = 0.5;
varying vec3 local_p;
void vertex(){
	local_p=VERTEX;
}
float hash3(vec3 p){return fract(sin(dot(p, vec3(12.13,93.7,47.3)))*42758.81);}
float grain(vec3 p){
	vec3 i=floor(p),u=fract(p);u=u*u*(3.0-2.0*u);
	return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),u.x),mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),u.x),u.y),
	mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),u.x),mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1,1,1)),u.x),u.y),u.z);
}
void fragment(){
	float inclusions=grain(local_p*vec3(19.0,6.0,18.0));
	float layers=grain(local_p*7.0);
	float edge=pow(1.0-clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0),2.5);
	float hairline=1.0-smoothstep(0.0,0.055,abs(fract(local_p.y*4.7+local_p.x*2.5+layers*1.6)-0.5));
	float dust=smoothstep(0.78,0.93,inclusions)*smoothstep(0.1,0.45,local_p.y);
	float t=clamp(0.07+0.23*facet+0.19*layers+0.28*edge+hairline*0.13+dust*0.26,0.0,0.9);
	vec3 color=mix(body.rgb,light_tip.rgb,t*t);
	ALBEDO=color*(0.52+inclusions*0.5);
	EMISSION=color*(0.16+facet*0.19+edge*0.38+hairline*0.20);
	METALLIC=0.22;
	ROUGHNESS=0.24+0.20*layers;
	SPECULAR=0.55;
}
