shader_type spatial;
render_mode diffuse_burley;
// Original pixel clusters on unchanged three-dimensional terrain geometry.
uniform sampler2D grass : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D sand : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D rock : source_color, filter_nearest_mipmap, repeat_enable;
varying vec3 p;
varying vec3 n;
void vertex() { p = VERTEX; n = NORMAL; }
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
 float slope = 1.0 - normalize(n).y;
 float variation = .10*sin(p.x*.48+p.z*.25)+.06*cos(p.z*.61);
 float turf = smoothstep(-.04,.23,p.y+variation)*(1.0-smoothstep(.27,.52,slope));
 turf *= 1.0-ridge_trail(p.xz+vec2(11.0,-14.0))*.94;
 float scarp = smoothstep(.21,.48,slope)*smoothstep(.15,.70,p.y);
 vec3 color = mix(texture(sand,p.xz/2.0).rgb,texture(grass,p.xz/2.0).rgb,turf);
 color = mix(color,texture(rock,p.xz/1.8).rgb,scarp);
 ALBEDO = color*mix(.77,1.0,smoothstep(-1.05,-.40,p.y));
 ROUGHNESS = .92;
 SPECULAR = .18;
}
