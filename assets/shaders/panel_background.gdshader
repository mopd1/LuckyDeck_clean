shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(0.914, 0.29, 0.267, 1.0);

void fragment() {
    // Create dynamic wave patterns
    vec2 uv = UV;
    float time = TIME * 2.0;

    // First wave pattern
    float wave1 = sin(uv.x * 10.0 + time) * 0.5 + 0.5;
    float wave2 = cos(uv.y * 8.0 - time * 1.5) * 0.5 + 0.5;

    // Second overlapping pattern
    float wave3 = sin((uv.x + uv.y) * 6.0 + time * 0.8) * 0.5 + 0.5;

    // Combine waves
    float combined = (wave1 + wave2 + wave3) / 3.0;

    // Mix with base color
    vec4 lighter_color = vec4(min(base_color.r + 0.2, 1.0),
                             min(base_color.g + 0.2, 1.0),
                             min(base_color.b + 0.2, 1.0),
                             base_color.a);

    COLOR = mix(base_color, lighter_color, combined);
}