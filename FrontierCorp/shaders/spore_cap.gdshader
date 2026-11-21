shader_type spatial;
varying vec3 local_p;
void vertex(){local_p=VERTEX;}
float h(vec2 p){return fract(sin(dot(p,vec2(92.61,17.3)))*34567.6);}
void fragment(){
	vec2 p=local_p.xz;
	vec2 c=floor(p*26.0), d=fract(p*26.0)-vec2(h(c),h(c+7.81))*0.61-0.16;
	float spores=(1.0-smoothstep(0.055,0.19,length(d)))*smoothstep(0.43,0.79,h(c+3.4));
	float marbling=0.5+0.5*sin(p.x*17.1+2.4*sin(p.y*9.0)+1.7*cos(local_p.y*12.0));
	float rim=pow(1.0-max(0.0,dot(normalize(NORMAL),normalize(VIEW))),2.3);
	vec3 flesh=mix(vec3(0.082,0.012,0.21),vec3(0.32,0.04,0.40),marbling*0.8+rim*0.2);
	ALBEDO=mix(flesh,vec3(0.75,0.46,0.85),spores);
	EMISSION=flesh*(0.14+0.45*rim)+spores*vec3(0.22,0.095,0.27);
	ROUGHNESS=0.42;
}
