shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
// FarReef land and its two named continuous low ridges. No vertex displacement/alpha holes.
uniform sampler2D sand_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 sample_offset = vec3(0.0);
uniform bool use_outcrop_mask = false;
varying vec3 local_p;
varying float outcrop;
void vertex() { local_p = VERTEX + sample_offset; outcrop = COLOR.r; }
void fragment() {
 vec3 sand = texture(sand_map, local_p.xz / 2.8).rgb;
 vec3 rock = texture(rock_map, local_p.xz / 1.8).rgb;
 float macro = 0.075 * sin(local_p.x * 0.42 + local_p.z * 0.19)
             + 0.075 * cos(local_p.z * 0.31 - local_p.x * 0.17);
 // One continuous terrain palette for ground, shore and the visible support skirt.
 float shore_blend = smoothstep(0.68, 0.92, length(local_p.xz / vec2(7.5, 6.0)));
 float mixture = clamp(mix(0.65, 0.20, shore_blend) + macro, 0.0, 1.0);
 // Restrained authored texture detail, not directional hatching or a route.
 float sand_value = dot(sand, vec3(0.2126, 0.7152, 0.0722));
 float rock_value = dot(rock, vec3(0.2126, 0.7152, 0.0722));
 vec3 sand_tone = mix(vec3(0.41, 0.37, 0.28), vec3(0.66, 0.59, 0.43), clamp(sand_value, 0.0, 1.0));
 vec3 rock_tone = mix(vec3(0.27, 0.29, 0.27), vec3(0.49, 0.48, 0.40), clamp(rock_value, 0.0, 1.0));
 float wet_edge = mix(0.78, 1.0, smoothstep(-0.45, 0.04, local_p.y));
 vec3 ground_tone = mix(sand_tone, rock_tone, mixture);
 // Authored irregular exposure inside the visible, collidable low sand/gravel skirt.
 // At every perimeter vertex this weight is zero and coordinates match the reef ground.
 float exposed = use_outcrop_mask ? smoothstep(0.05, 0.85, outcrop) : 0.0;
 ALBEDO = mix(ground_tone, rock_tone * vec3(1.08, 1.06, 1.03), exposed) * wet_edge;
 ROUGHNESS = 1.0;
 SPECULAR = 0.12;
}
