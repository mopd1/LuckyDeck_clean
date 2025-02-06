shader_type canvas_item;

uniform vec4 base_color: source_color = vec4(0.353, 0.647, 0.69, 1.0);  // RGB 90/165/176
uniform vec4 border_color: source_color = vec4(0.98, 0.945, 0.604, 1.0); // RGB 250/241/154
uniform float border_width: hint_range(0.0, 0.1) = 0.02;
uniform float pulse_speed: hint_range(0.1, 5.0) = 1.5;
uniform float pulse_intensity: hint_range(0.0, 1.0) = 0.3;

void fragment() {
    vec2 uv = UV;

    // Create border mask
    float border = 0.0;
    if (uv.x < border_width || uv.x > 1.0 - border_width ||
        uv.y < border_width || uv.y > 1.0 - border_width) {
        border = 1.0;
    }

    // Pulsing effect
    float pulse = (sin(TIME * pulse_speed) * 0.5 + 0.5) * pulse_intensity;

    // Mix colors
    vec4 final_border = mix(border_color, vec4(1.0), pulse);
    vec4 final_base = mix(base_color, vec4(1.0), pulse * 0.5);

    COLOR = mix(final_base, final_border, border);
}