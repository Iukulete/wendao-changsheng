shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Candidate reuses the nine provenance-checked coast maps. Softer broad values
// and a restrained sea-green / linen palette complement the warm timber home.
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
void fragment() {
 vec2 uv=p.xz/2.0;
 vec3 grass=mix(texture(grass_diff,uv).rgb,textureLod(grass_diff,uv,3.4).rgb,.78)*vec3(1.36,1.55,1.47);
 float lum=dot(grass,vec3(.2126,.7152,.0722));
 grass=mix(grass,vec3(lum),.34);
 vec3 sand=mix(texture(sand_diff,uv).rgb,textureLod(sand_diff,uv,2.5).rgb,.48)*vec3(1.28,1.23,1.15);
 float broad=.10*sin(p.x*.48+p.z*.25)+.06*cos(p.z*.61);
 float slope=1.0-normalize(terrain_normal).y;
 float turf=smoothstep(-.04,.23,p.y+broad)*(1.0-smoothstep(.27,.52,slope));
 float scarp=smoothstep(.21,.48,slope)*smoothstep(.15,.70,p.y);
 vec3 stone=texture(rock_diff,p.xz/1.8).rgb*vec3(.69,.73,.72);
 float wet=1.0-smoothstep(-1.05,-.40,p.y);
 ALBEDO=mix(mix(sand,grass,turf),stone,scarp*.72)*mix(1.0,.76,wet);
 ROUGHNESS=mix(texture(sand_rough,uv).r,texture(grass_rough,uv).r,turf)*mix(1.0,.88,wet);
 SPECULAR=.24;
 NORMAL_MAP=mix(texture(sand_normal,uv).rgb,texture(grass_normal,uv).rgb,turf);
 NORMAL_MAP_DEPTH=mix(.20,.14,turf);
}
