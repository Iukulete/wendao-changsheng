shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D grass_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_rough : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_rough : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_rough : filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 p;
varying vec3 n;
void vertex(){ p=VERTEX; n=NORMAL; }
float segment_distance(vec2 q,vec2 a,vec2 b){vec2 d=b-a;return length(q-a-d*clamp(dot(q-a,d)/dot(d,d),0.,1.));}
float trail(vec2 q){
 float d=segment_distance(q,vec2(0.,-8.),vec2(-2.,-6.));
 d=min(d,segment_distance(q,vec2(-2.,-6.),vec2(-4.4,-5.)));
 d=min(d,segment_distance(q,vec2(-4.4,-5.),vec2(-6.,-2.6)));
 d=min(d,segment_distance(q,vec2(-6.,-2.6),vec2(-6.,.1)));
 d=min(d,segment_distance(q,vec2(-6.,.1),vec2(-4.,2.)));
 return 1.-smoothstep(.4,.85,d);
}
void fragment(){
 vec2 uv=p.xz/2.;
 float slope=1.-normalize(n).y;
 float turf=smoothstep(-.02,.22,p.y)*(1.-smoothstep(.22,.48,slope))*(1.-trail(p.xz)*.93);
 vec3 sand=texture(sand_diff,uv).rgb*vec3(1.18,1.19,1.16);
 vec3 grass=mix(texture(grass_diff,uv).rgb,textureLod(grass_diff,uv,3.).rgb,.65)*vec3(1.28,1.52,1.38);
 vec3 rock=texture(rock_diff,p.xz/1.8).rgb*vec3(.72,.75,.74);
 ALBEDO=mix(mix(sand,grass,turf),rock,smoothstep(.19,.46,slope)*.8);
 ROUGHNESS=mix(texture(sand_rough,uv).r,texture(grass_rough,uv).r,turf);
 SPECULAR=.25;
 NORMAL_MAP=mix(texture(sand_normal,uv).rgb,texture(grass_normal,uv).rgb,turf);
 NORMAL_MAP_DEPTH=.22;
}
