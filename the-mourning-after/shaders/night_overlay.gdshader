shader_type canvas_item;
// Darkens and cools the scene beneath it for night time.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float amount : hint_range(0.0, 1.0) = 0.0; // 0 = day, 1 = full night
uniform vec3 night_tint : source_color = vec3(0.45, 0.52, 0.8); // TUNE: colour cast at night
uniform float night_brightness = 0.45; // TUNE: brightness at full night (1 = no darkening)
uniform float night_desaturation = 0.4; // TUNE: colour loss at full night (0 = none, 1 = grayscale)

void fragment() {
	vec3 color = texture(screen_texture, SCREEN_UV).rgb;
	float gray = dot(color, vec3(0.299, 0.587, 0.114));
	vec3 night = mix(color, vec3(gray), night_desaturation) * night_tint * night_brightness;
	COLOR = vec4(mix(color, night, amount), 1.0);
}
