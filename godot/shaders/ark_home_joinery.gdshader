shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
uniform sampler2D timber_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 dark_tone = vec3(.25,.16,.09);
uniform vec3 light_tone = vec3(.58,.41,.25);
uniform float deck_seams : hint_range(0.0,1.0) = 0.0;
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
 vec3 wood=mix(dark_tone,light_tone,smoothstep(.08,.70,value));
 // Meter-scale joinery on the deck slab, not extra collision geometry.
 // Fine seams converge with distance rather than flickering below a pixel.
 float board=floor((local_p.x+.18)/.36);
 float across=fract((local_p.x+.18)/.36);
 float along=fract(local_p.z/2.2+mod(board,2.0)*.5);
 float dx=min(across,1.0-across)*.36;
 float dz=min(along,1.0-along)*2.2;
 float aa=max(fwidth(local_p.x)*1.2,.001);
 float seam=1.0-smoothstep(.002,.005+aa,min(dx,dz));
 float variation=.94+.10*fract(sin(board*12.9898)*43758.5453);
 float top=smoothstep(.75,.95,abs(local_n.y))*deck_seams;
 wood*=mix(1.0,variation*(1.0-seam*.38),top);
 ALBEDO=wood*COLOR.rgb;
 ROUGHNESS=.84;
 SPECULAR=.24;
}
