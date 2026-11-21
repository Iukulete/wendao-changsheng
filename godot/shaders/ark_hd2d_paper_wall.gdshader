shader_type spatial;
render_mode diffuse_burley;
// Warm lattice inset painted/emitted on the EXISTING opaque cabin wall.
// No extra plane, no hole/collision change, no fake screen-space bloom.
uniform sampler2D boards : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D paper_window : source_color, filter_nearest, repeat_disable;
uniform float window_energy : hint_range(0.0,1.0) = 0.0;
varying vec3 p;
varying vec3 n;
void vertex() { p=VERTEX; n=NORMAL; }
void fragment() {
 vec3 weights=pow(abs(normalize(n)),vec3(5.0));
 weights/=max(weights.x+weights.y+weights.z,.001);
 vec3 timber=texture(boards,p.zy/1.8).rgb*weights.x;
 timber+=texture(boards,p.xz/1.8).rgb*weights.y;
 timber+=texture(boards,p.xy/1.8).rgb*weights.z;
 vec2 window_uv=vec2(p.x,-p.y+.20)/vec2(.82,.82)+.5;
 float face=step(.9,abs(n.z));
 float inside=step(0.0,window_uv.x)*step(window_uv.x,1.0)*step(0.0,window_uv.y)*step(window_uv.y,1.0)*face;
 vec3 paper=texture(paper_window,window_uv).rgb;
 float light_paper=smoothstep(.36,.68,dot(paper,vec3(.2126,.7152,.0722)));
 ALBEDO=mix(timber,paper,inside);
 EMISSION=paper*light_paper*inside*window_energy*.55;
 ROUGHNESS=.90;
 SPECULAR=.18;
}
