shader_type spatial;
render_mode diffuse_burley;
// Existing small cloth patch geometry only. Never repeat the authored repair.
uniform sampler2D cloth : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D repair : source_color, filter_nearest_mipmap, repeat_disable;
uniform vec3 bounds = vec3(.56,.035,.48);
varying vec3 p;
varying vec3 n;
void vertex() { p=VERTEX; n=NORMAL; }
void fragment() {
 vec3 weights=pow(abs(normalize(n)),vec3(5.0));
 weights/=max(weights.x+weights.y+weights.z,.001);
 vec3 plain=texture(cloth,p.zy/.8).rgb*weights.x;
 plain+=texture(cloth,p.xz/.8).rgb*weights.y;
 plain+=texture(cloth,p.xy/.8).rgb*weights.z;
 vec2 repair_uv=vec2(p.x/bounds.x,-p.z/bounds.z)+.5;
 ALBEDO=mix(plain,texture(repair,clamp(repair_uv,vec2(0.0),vec2(1.0))).rgb,step(.9,n.y));
 ROUGHNESS=.98;
 SPECULAR=.08;
}
