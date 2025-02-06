shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(1.0, 0.8, 0.0, 1.0); // Golden glow
uniform float glow_intensity : hint_range(0.0, 2.0) = 1.5;
uniform float pulse_speed : hint_range(0.0, 5.0) = 3.0;
uniform float glow_width : hint_range(0.0, 0.5) = 0.2;

void fragment() {
    vec4 current_color = texture(TEXTURE, UV);

    // Create a stronger pulsing effect
    float pulse = (sin(TIME * pulse_speed) + 1.0) * 0.5;
    float glow = glow_intensity * pulse;

    // Create outer glow effect
    float distance_from_edge = min(UV.x, min(1.0 - UV.x, min(UV.y, 1.0 - UV.y)));
    float edge_glow = smoothstep(0.0, glow_width, distance_from_edge);

    // Apply enhanced glow effect
    if (current_color.a > 0.0) {
        vec4 glowing_color = mix(glow_color, current_color, 0.5);
        COLOR = mix(glowing_color, current_color, edge_glow);
        COLOR.rgb *= (1.0 + glow * 0.5); // Boost brightness
        COLOR.a = current_color.a;
    } else {
        COLOR = current_color;
    }
}