shader_type spatial;
render_mode cull_disabled;
uniform sampler2D water : filter_linear, repeat_disable;
uniform vec2 chart_origin;
uniform float world_size;
uniform float wave_time;
uniform vec4 swell_a;
uniform vec4 swell_b;
uniform vec4 swell_c;
varying vec3 wp;
varying vec2 slope;

vec3 sample_wave(vec2 p,vec4 w){
	float phase=dot(p,w.xy)+wave_time*w.z;
	return vec3(sin(phase),cos(phase)*w.xy)*w.w;
}
float sea(vec2 p){
	vec2 uv=(p-chart_origin)/world_size;
	if(any(lessThan(uv,vec2(0.)))||any(greaterThan(uv,vec2(1.)))){return 1.;}
	return texture(water,uv).r;
}
void vertex(){
	// A dense patch near the camera and a continuous low-detail horizon share a single draw.
	vec2 q=abs(VERTEX.xz);
	VERTEX.xz=sign(VERTEX.xz)*(q*38.+q*q*q*q*1900.);
	wp=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
	vec3 w=sample_wave(wp.xz,swell_a)+sample_wave(wp.xz,swell_b)+sample_wave(wp.xz,swell_c);
	VERTEX.y+=w.x;
	wp.y+=w.x;
	slope=w.yz;
}
void fragment(){
	vec2 p=wp.xz;
	float t=wave_time;
	float warp=sin(dot(p,vec2(.48,.31))-t*.57)+.7*sin(dot(p,vec2(-.33,.65))+t*.63);
	vec2 detail=vec2(cos(dot(p,vec2(1.91,3.37))+warp+t*2.2),sin(dot(p,vec2(3.61,-1.67))+warp*1.3-t*2.44));
	float fine=sin(dot(p,vec2(5.91,1.54))+warp*1.65-t*3.11);
	vec3 n=normalize(vec3(-slope.x+.037*detail.x+.016*fine,1.,-slope.y+.036*detail.y-.014*fine));
	vec3 eye=normalize(CAMERA_POSITION_WORLD-wp);
	float fresnel=pow(1.-max(0.,dot(eye,n)),3.5);
	float mask=sea(p);
	float shoal=1.-.25*(sea(p+vec2(2.9,0))+sea(p-vec2(2.9,0))+sea(p+vec2(0,2.9))+sea(p-vec2(0,2.9)));
	float tide=clamp(.48+1.9*(wp.y-.12)+.10*warp,0.,1.);
	vec3 deep=mix(vec3(.013,.165,.25),vec3(.027,.32,.38),tide);
	vec3 col=mix(deep,vec3(.061,.50,.45),min(1.,shoal*1.70));
	float waterline=mask-.5-.08*sin(p.x*2.+p.y*1.3-t*1.45)-.05*warp;
	float lace=1.-smoothstep(.025,.12,abs(waterline));
	float breakers=smoothstep(.77,.96,tide)*smoothstep(.80,1.,detail.x)*smoothstep(.25,.8,detail.y);
	col=mix(col,vec3(.60,.85,.79),clamp(lace*(.76+.17*fine)+breakers*.33,0.,.95));
	col=mix(col,vec3(.30,.58,.69),fresnel*.68);
	NORMAL=normalize((VIEW_MATRIX*vec4(n,0.)).xyz);
	ALBEDO=col;
	EMISSION=col*.22;
	ROUGHNESS=mix(.27,.16,fresnel);
	SPECULAR=.70;
}
