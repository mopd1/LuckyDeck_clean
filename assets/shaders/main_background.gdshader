shader_type canvas_item;

uniform vec3 dark_color = vec3(0.102, 0.078, 0.137);  // RGB 26/20/35 normalized
uniform vec3 light_color = vec3(0.157, 0.118, 0.196); // Slightly lighter version

void fragment() {
    vec2 uv = UV;
    float vignette = 1.0 - length((uv - vec2(0.5)) * 1.5);
    vec3 color = mix(dark_color, light_color, vignette);
    COLOR = vec4(color, 1.0);
}