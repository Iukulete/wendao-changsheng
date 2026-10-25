shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
uniform sampler2D timber_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 local_p;
varying vec3 local_n;
void vertex() { local_p=VERTEX; local_n=NORMAL; }
void fragment() {
 vec3 weights=pow(abs(normalize(local_n)),vec3(5.0));
 weights/=max(weights.x+weights.y+weights.z,.001);
 vec3 grain=texture(timber_albedo,local_p.zy*.48).rgb*weights.x;
 grain+=texture(timber_albedo,local_p.xz*.48).rgb*weights.y;
 grain+=texture(timber_albedo,local_p.xy*.48).rgb*weights.z;
 float value=dot(grain,vec3(.2126,.7152,.0722));
 // The image supplies grain, not baked lighting. Compress contrast so broad
 // warm planes read before micro-detail and retain the existing scene lighting.
 ALBEDO=mix(vec3(.22,.135,.080),vec3(.48,.345,.225),smoothstep(.08,.70,value))*COLOR.rgb;
 ROUGHNESS=.84;
 SPECULAR=.24;
}
