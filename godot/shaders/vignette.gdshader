shader_type canvas_item;

uniform vec4 tint : source_color = vec4(0.02, 0.04, 0.07, 0.22);
uniform vec4 accent : source_color = vec4(0.90, 0.74, 0.30, 1.0);
uniform float pulse = 0.0;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

void fragment() {
    vec2 centered = UV * 2.0 - 1.0;
    float edge = smoothstep(0.34, 1.13, length(centered * vec2(0.72, 1.0)));
    float horizon = smoothstep(0.88, 0.18, abs(UV.y - 0.48));
    float grain = (hash21(floor(UV * vec2(780.0, 490.0))) - 0.5) * 0.018;
    float aura = horizon * (0.018 + pulse * 0.018);
    vec3 color = tint.rgb + accent.rgb * aura;
    float alpha = clamp(tint.a + edge * 0.53 + grain, 0.0, 0.84);
    COLOR = vec4(color, alpha);
}
