shader_type spatial;
render_mode unshaded, depth_draw_opaque, cull_disabled;
// Mob card: sprite texture and modulate, plus a grey-out (stun) and a flash colour (crit).

uniform sampler2D card_texture : source_color, filter_linear_mipmap;
uniform float grey_amount = 0.0; // 0 = normal colours, 1 = fully greyed
uniform float grey_brightness = 0.75; // TUNE: brightness of the greyed card
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float flash_amount = 0.0; // 0 = no flash, 1 = solid flash colour

void fragment() {
	vec4 tex = texture(card_texture, UV) * COLOR;
	if (tex.a < 0.5) {
		discard;
	}
	vec3 c = tex.rgb;
	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(luma * grey_brightness), grey_amount);
	c = mix(c, flash_color.rgb, flash_amount);
	ALBEDO = c;
}
