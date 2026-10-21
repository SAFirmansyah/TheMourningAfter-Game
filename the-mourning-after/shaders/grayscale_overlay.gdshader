shader_type canvas_item;
// Desaturates and darkens everything drawn beneath it.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float amount : hint_range(0.0, 1.0) = 0.0; // 0 = off, 1 = full effect
uniform float darken = 0.55; // TUNE: brightness at full effect (1 = no darkening)

void fragment() {
	vec3 color = texture(screen_texture, SCREEN_UV).rgb;
	float gray = dot(color, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(color, vec3(gray), amount) * mix(1.0, darken, amount), 1.0);
}
