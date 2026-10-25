shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Reconstructed material expression; requires all nine separately verified maps.
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
varying vec3 terrain_normal;
void vertex() { p=VERTEX; terrain_normal=NORMAL; }
float segment_distance(vec2 point, vec2 a, vec2 b) {
 vec2 line=b-a;
 return length(point-a-line*clamp(dot(point-a,line)/dot(line,line),0.0,1.0));
}
float ridge_trail(vec2 point) {
 float d=segment_distance(point,vec2(7.4,-10.8),vec2(6.2,-13.6));
 d=min(d,segment_distance(point,vec2(6.2,-13.6),vec2(5.9,-16.2)));
 d=min(d,segment_distance(point,vec2(5.9,-16.2),vec2(7.2,-18.7)));
 d=min(d,segment_distance(point,vec2(7.2,-18.7),vec2(9.6,-20.0)));
 d=min(d,segment_distance(point,vec2(9.6,-20.0),vec2(11.4,-19.5)));
 d=min(d,segment_distance(point,vec2(11.4,-19.5),vec2(10.6,-18.5)));
 return 1.0-smoothstep(.32,.67,d);
}
void fragment() {
 vec2 uv=p.xz/2.0;
 vec3 gd=texture(grass_diff,uv).rgb*vec3(1.38,1.62,1.42);
 vec3 gb=textureLod(grass_diff,uv,3.2).rgb*vec3(1.38,1.62,1.42);
 vec3 grass=mix(gd,gb,0.68);
 float lum=dot(grass,vec3(.2126,.7152,.0722));
 grass=mix(grass,vec3(lum),.28);
 vec3 sand=texture(sand_diff,uv).rgb*vec3(1.24,1.20,1.13);
 float broad=.10*sin(p.x*.48+p.z*.25)+.06*cos(p.z*.61);
 float slope=1.0-normalize(terrain_normal).y;
 float turf=smoothstep(-.04,.23,p.y+broad)*(1.0-smoothstep(.27,.52,slope));
 turf*=1.0-ridge_trail(p.xz+vec2(11.0,-14.0))*.94;
 float scarp=smoothstep(.21,.48,slope)*smoothstep(.15,.70,p.y);
 vec3 stone=texture(rock_diff,p.xz/1.8).rgb*vec3(.68,.69,.66);
 float wet=1.0-smoothstep(-1.05,-.40,p.y);
 ALBEDO=mix(mix(sand,grass,turf),stone,scarp*.72)*mix(1.0,.73,wet);
 ROUGHNESS=mix(texture(sand_rough,uv).r,texture(grass_rough,uv).r,turf)*mix(1.0,.85,wet);
 SPECULAR=.28;
 NORMAL_MAP=mix(texture(sand_normal,uv).rgb,texture(grass_normal,uv).rgb,turf);
 NORMAL_MAP_DEPTH=mix(.32,.20,turf);
}
