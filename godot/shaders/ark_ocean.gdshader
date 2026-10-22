shader_type spatial;
uniform float water_time = 0.0;
uniform float mean_height = -1.05;
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


uniform int water_model = 1;
uniform vec4 gerstner_wave_a = vec4(1.0, 0.0, 0.21, 0.12);
uniform vec4 gerstner_wave_b = vec4(0.6, 0.8, 0.16, 0.07);
uniform vec4 gerstner_motion = vec4(1.0, 0.0, 1.0, 0.0);
uniform bool height_probe = false;
uniform bool normal_probe = false;
uniform float height_probe_reference = -1.0;

void add_wave(vec2 q, vec4 wave, float steepness, float phase, inout vec3 p, inout vec3 tx, inout vec3 tz) {
	float theta = wave.z * dot(wave.xy, q) + phase;
	float h = steepness * wave.w;
	p.xz += h * wave.xy * cos(theta);
	p.y += wave.w * sin(theta);
	float slope = -h * wave.z * sin(theta);
	tx += vec3(slope * wave.x * wave.x, wave.w * wave.z * wave.x * cos(theta), slope * wave.x * wave.y);
	tz += vec3(slope * wave.x * wave.y, wave.w * wave.z * wave.y * cos(theta), slope * wave.y * wave.y);
}

void vertex() {
	vec3 rest = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 p = vec3(rest.x, mean_height, rest.z);
	vec3 tx = vec3(1.0, 0.0, 0.0);
	vec3 tz = vec3(0.0, 0.0, 1.0);
	if (water_model == 2) {
		add_wave(rest.xz, gerstner_wave_a, gerstner_motion.x, gerstner_motion.y, p, tx, tz);
		add_wave(rest.xz, gerstner_wave_b, gerstner_motion.z, gerstner_motion.w, p, tx, tz);
	} else {
		float a = rest.x * 0.21 + water_time * 0.42;
		float b = rest.z * 0.16 - water_time * 0.31;
		float c = (rest.x + rest.z) * 0.11 + water_time * 0.23;
		p.y += 0.035 * sin(a) * cos(b) + 0.018 * sin(c);
		tx.y = 0.035 * 0.21 * cos(a) * cos(b) + 0.018 * 0.11 * cos(c);
		tz.y = -0.035 * 0.16 * sin(a) * sin(b) + 0.018 * 0.11 * cos(c);
	}
	VERTEX = (inverse(MODEL_MATRIX) * vec4(p, 1.0)).xyz;
	NORMAL = normalize(transpose(mat3(MODEL_MATRIX)) * normalize(cross(tz, tx)));
	world_position = p;
}


float shore_band(vec2 position, vec2 center, vec2 radii) {
	float edge = length((position - center) / radii) - 1.0;
	return (1.0 - smoothstep(0.015, 0.11, edge)) * smoothstep(-0.08, 0.025, edge);
}


void fragment() {
	vec2 position = world_position.xz;
	float broad_wave = sin(dot(position, vec2(0.085, 0.045)) + water_time * 0.24);
	float cross_wave = cos(dot(position, vec2(-0.035, 0.09)) - water_time * 0.19);
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
	if (height_probe || normal_probe) {
		ALBEDO = vec3(0.0);
		if (normal_probe) {
			EMISSION = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz) * 0.5 + 0.5;
		} else {
			float encoded = height_probe_reference >= 0.0 ? height_probe_reference : world_position.y - mean_height + 0.5;
			EMISSION = vec3(encoded);
		}
	}
	ROUGHNESS = 0.34;
	METALLIC = 0.06;
}
