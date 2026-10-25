shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
// Original code-native fabric, no image or invented normal/roughness map.
uniform vec3 fabric_tone = vec3(.46,.55,.48);
uniform float weave_scale = 135.0;
varying vec3 local_p;
varying vec3 local_n;
void vertex() { local_p=VERTEX; local_n=NORMAL; }
void fragment() {
 vec3 n=abs(normalize(local_n));
 vec2 p=n.y>max(n.x,n.z)?local_p.xz:(n.x>n.z?local_p.zy:local_p.xy);
 // Subpixel threads converge to their average; broad dye variation stays calm.
 vec2 detail=vec2(1.0)-smoothstep(vec2(.25),vec2(1.0),fwidth(p*weave_scale));
 vec2 threads=sin(p*weave_scale*6.2831853)*detail;
 float weave=1.0+.018*(threads.x+threads.y);
 float dye=.98+.025*sin(p.x*3.1+p.y*1.6)*cos(p.y*2.3);
 ALBEDO=fabric_tone*weave*dye*COLOR.rgb;
 ROUGHNESS=.94;
 SPECULAR=.16;
}
