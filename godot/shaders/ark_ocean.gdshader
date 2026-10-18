shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

// Replaceable first-pass placeholder only; final water art belongs to a later visual polish pass.

uniform vec4 deep_water : source_color = vec4(0.055, 0.18, 0.22, 1.0);
uniform vec4 wave_color : source_color = vec4(0.10, 0.29, 0.32, 1.0);
uniform vec4 shore_color : source_color = vec4(0.27, 0.44, 0.42, 1.0);
uniform vec2 island_center = vec2(11.0, -14.0);
uniform vec2 island_radii = vec2(12.0, 10.0);
uniform vec2 reef_center = vec2(39.0, -29.0);
uniform vec2 reef_radii = vec2(7.5, 6.0);
uniform vec2 moonback_center = vec2(-28.0, 23.0);
uniform vec2 moonback_radii = vec2(14.0, 12.0);
uniform vec2 jade_sail_center = vec2(-53.0, -45.0);
uniform vec2 jade_sail_radii = vec2(10.0, 8.0);
uniform vec2 steam_wreck_center = vec2(92.0, 86.0);
uniform vec2 steam_wreck_radii = vec2(14.0, 11.0);

varying vec3 world_position;


void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float swell_a = sin(VERTEX.x * 0.21 + TIME * 0.42) * cos(VERTEX.z * 0.16 - TIME * 0.31);
	float swell_b = sin((VERTEX.x + VERTEX.z) * 0.11 + TIME * 0.23);
	VERTEX.y += (swell_a * 0.035 + swell_b * 0.018);
}


float shore_band(vec2 position, vec2 center, vec2 radii) {
	float edge = length((position - center) / radii) - 1.0;
	return (1.0 - smoothstep(0.015, 0.11, edge)) * smoothstep(-0.08, 0.025, edge);
}


void fragment() {
	vec2 position = world_position.xz;
	float broad_wave = sin(dot(position, vec2(0.085, 0.045)) + TIME * 0.24);
	float cross_wave = cos(dot(position, vec2(-0.035, 0.09)) - TIME * 0.19);
	float wave = 0.5 + 0.5 * (broad_wave * 0.58 + cross_wave * 0.42);
	float glint = smoothstep(0.84, 0.98, wave) * 0.12;
	float shore = max(
		shore_band(position, island_center, island_radii),
		max(
			shore_band(position, reef_center, reef_radii),
			max(
				shore_band(position, moonback_center, moonback_radii),
				max(
					shore_band(position, jade_sail_center, jade_sail_radii),
					shore_band(position, steam_wreck_center, steam_wreck_radii)
				)
			)
		)
	);
	vec3 color = mix(deep_water.rgb, wave_color.rgb, wave * 0.38);
	color = mix(color, shore_color.rgb, shore * 0.44);
	color += vec3(0.24, 0.38, 0.34) * glint;
	ALBEDO = color;
	ROUGHNESS = 0.34;
	METALLIC = 0.06;
}
