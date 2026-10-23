shader_type spatial;
uniform float water_time = 0.0;
uniform float mean_height = -1.05;
render_mode cull_disabled, depth_draw_opaque;

// Replaceable first-pass placeholder only; final water art belongs to a later visual polish pass.

uniform vec4 deep_water : source_color = vec4(0.055, 0.18, 0.22, 1.0);
uniform vec4 wave_color : source_color = vec4(0.10, 0.29, 0.32, 1.0);
uniform vec4 shore_color : source_color = vec4(0.27, 0.44, 0.42, 1.0);
uniform vec2 island_center = vec2(11.0, -14.0);
uniform vec2 island_radii = vec2(12.0, 10.0);
uniform vec2 reef_center = vec2(39.0, -29.0);
uniform vec2 reef_radii = vec2(7.5, 6.0);
uniform vec2 moonback_center = vec2(-28.0, 23.0);
uniform vec2 moonback_radii = vec2(14.0, 12.0);
uniform vec2 jade_sail_center = vec2(-53.0, -45.0);
uniform vec2 jade_sail_radii = vec2(10.0, 8.0);
uniform vec2 steam_wreck_center = vec2(92.0, 86.0);
uniform vec2 steam_wreck_radii = vec2(14.0, 11.0);

varying vec3 world_position;


uniform int water_model = 1;
uniform vec4 gerstner_wave_a = vec4(1.0, 0.0, 0.21, 0.12);
uniform vec4 gerstner_wave_b = vec4(0.6, 0.8, 0.16, 0.07);
uniform vec4 gerstner_motion = vec4(1.0, 0.0, 1.0, 0.0);
uniform bool height_probe = false;
uniform bool normal_probe = false;
uniform float height_probe_reference = -1.0;

void add_wave(vec2 q, vec4 wave, float steepness, float phase, inout vec3 p, inout vec3 tx, inout vec3 tz) {
	float theta = wave.z * dot(wave.xy, q) + phase;
	float h = steepness * wave.w;
	p.xz += h * wave.xy * cos(theta);
	p.y += wave.w * sin(theta);
	float slope = -h * wave.z * sin(theta);
	tx += vec3(slope * wave.x * wave.x, wave.w * wave.z * wave.x * cos(theta), slope * wave.x * wave.y);
	tz += vec3(slope * wave.x * wave.y, wave.w * wave.z * wave.y * cos(theta), slope * wave.y * wave.y);
}

void vertex() {
	vec3 rest = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 p = vec3(rest.x, mean_height, rest.z);
	vec3 tx = vec3(1.0, 0.0, 0.0);
	vec3 tz = vec3(0.0, 0.0, 1.0);
	if (water_model == 2) {
		add_wave(rest.xz, gerstner_wave_a, gerstner_motion.x, gerstner_motion.y, p, tx, tz);
		add_wave(rest.xz, gerstner_wave_b, gerstner_motion.z, gerstner_motion.w, p, tx, tz);
	} else {
		float a = rest.x * 0.21 + water_time * 0.42;
		float b = rest.z * 0.16 - water_time * 0.31;
		float c = (rest.x + rest.z) * 0.11 + water_time * 0.23;
		p.y += 0.035 * sin(a) * cos(b) + 0.018 * sin(c);
		tx.y = 0.035 * 0.21 * cos(a) * cos(b) + 0.018 * 0.11 * cos(c);
		tz.y = -0.035 * 0.16 * sin(a) * sin(b) + 0.018 * 0.11 * cos(c);
	}
	VERTEX = (inverse(MODEL_MATRIX) * vec4(p, 1.0)).xyz;
	NORMAL = normalize(transpose(mat3(MODEL_MATRIX)) * normalize(cross(tz, tx)));
	world_position = p;
}


float shore_band(vec2 position, vec2 center, vec2 radii) {
	float edge = length((position - center) / radii) - 1.0;
	return (1.0 - smoothstep(0.015, 0.11, edge)) * smoothstep(-0.08, 0.025, edge);
}


// Candidate derived from reconstructed suffix; water-only correction run02, 2026-10-23.
// Not retrieved from the lost workspace; not asserted byte-exact to that file.
// run01 compiled/rendered; this correction requires a separate native run02.
// Append to a verified canonical ark_ocean.gdshader prefix before void fragment().
// Preserve original declarations, add_wave(), vertex(), and shore_band().
// Existing vertex displacement must remain byte-exact to the chosen verified base.
// Opaque depth tint, not SSR, refraction, or scene-object reflection.
uniform sampler2D opening_heights : filter_linear, repeat_disable;
uniform vec4 depth_tint : source_color = vec4(0.042,0.19,0.235,1.0);
uniform vec4 shallow_tint : source_color = vec4(0.12,0.265,0.265,1.0);
uniform vec4 foam_tint : source_color = vec4(0.62,0.67,0.61,1.0);
uniform bool ripple_probe = false;

// Smooth derivative-noise normal fields avoid a visibly crossing sine lattice.
float hash12(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
vec3 noise_gradient(vec2 p) {
 vec2 i=floor(p); vec2 f=fract(p);
 float a=hash12(i), b=hash12(i+vec2(1,0));
 float c=hash12(i+vec2(0,1)), d=hash12(i+vec2(1,1));
 vec2 u=f*f*f*(f*(f*6.0-15.0)+10.0);
 vec2 du=30.0*f*f*(f*(f-2.0)+1.0);
 return vec3(mix(mix(a,b,u.x),mix(c,d,u.x),u.y),
   mix(b-a,d-c,u.y)*du.x,mix(c-a,d-b,u.x)*du.y);
}
vec2 ripple_slope(vec2 p,float footprint) {
 float t=water_time;
 vec2 warp=vec2(noise_gradient(p*.17).x,noise_gradient(p*.19+vec2(7.3,4.1)).x)-.5;
 vec2 q=p+warp*1.8;
 vec3 a=noise_gradient(vec2(q.x*.82,q.y*1.14)+vec2(-t*.12,t*.06));
 vec2 r=vec2(.8*q.x-.6*q.y,.6*q.x+.8*q.y);
 vec3 b=noise_gradient(r*3.1+vec2(t*.23,-t*.18)+vec2(9.2,3.7));
 vec2 coarse=a.yz*vec2(.82,1.14)*.085*exp(-18.0*footprint*footprint);
 vec2 fine=vec2(.8*b.y+.6*b.z,-.6*b.y+.8*b.z)*.030*exp(-100.0*footprint*footprint);
 return coarse+fine;
}

void fragment() {
 vec3 simulated_normal=normalize(NORMAL);
 vec3 wn=normalize((INV_VIEW_MATRIX*vec4(simulated_normal,0.0)).xyz);
 vec2 p=world_position.xz;
 float footprint=max(length(dFdx(p)),length(dFdy(p)));
 vec2 slope=-wn.xz/max(wn.y,0.25)+ripple_slope(p,footprint);
 vec3 shading_world=normalize(vec3(-slope.x,1.0,-slope.y));
 NORMAL=normalize((VIEW_MATRIX*vec4(shading_world,0.0)).xyz);

 vec2 q=p-island_center;
 float depth=8.0;
 if(abs(q.x)<16.0&&abs(q.y)<16.0){
   float h=texture(opening_heights,(q+vec2(16.0))/32.0).r;
   if(h>-2.99)depth=max(0.0,world_position.y-h);
 }
 float shallow=exp(-depth*6.5);
 vec3 body=mix(depth_tint.rgb,shallow_tint.rgb,shallow);
 float contact=smoothstep(.008,.028,depth)*(1.0-smoothstep(.045,.13,depth));
 float broken=smoothstep(.62,.88,noise_gradient(q*3.2).x)
             *smoothstep(.40,.70,noise_gradient(q*.73+vec2(4.1,8.7)).x);
 float foam=contact*broken*.14;
 ALBEDO=mix(body,foam_tint.rgb,foam);
 METALLIC=0.0;
 SPECULAR=0.25;
 ROUGHNESS=mix(.235,.52,foam);

 if(height_probe||normal_probe||ripple_probe){
   ALBEDO=vec3(0.0);
   SPECULAR=0.0;
   if(ripple_probe){
     EMISSION=shading_world*.5+.5;
   }else if(normal_probe){
     EMISSION=normalize(
       (INV_VIEW_MATRIX*vec4(simulated_normal,0.0)).xyz)*.5+.5;
   }else{
     float encoded=height_probe_reference>=0.0
       ?height_probe_reference:world_position.y-mean_height+.5;
     EMISSION=vec3(encoded);
   }
 }
}
