shader_type spatial;
render_mode unshaded, depth_draw_opaque;
// Card that turns see-through where it covers the player.

global uniform vec3 occlusion_target;

uniform sampler2D card_texture : source_color, filter_linear_mipmap;
uniform vec4 card_modulate : source_color = vec4(1.0);
uniform float target_height = 0.9; // TUNE: cutout centre height above player's feet (m)
uniform float cutout_radius = 0.1; // TUNE: see-through circle radius (fraction of screen height)
uniform float cutout_softness = 0.6; // TUNE: circle edge softness (0 = hard, 1 = fully soft)
uniform float cutout_alpha = 0.25; // TUNE: card opacity at circle centre
uniform float depth_blend = 0.6; // TUNE: depth (m) over which the cutout fades in as the player moves behind

void fragment() {
	vec4 tex = texture(card_texture, UV) * card_modulate;
	if (tex.a < 0.5) {
		discard;
	}

	vec4 feet_view = VIEW_MATRIX * vec4(occlusion_target, 1.0);
	float behind = smoothstep(0.0, depth_blend, NODE_POSITION_VIEW.z - feet_view.z);

	vec4 clip = PROJECTION_MATRIX * VIEW_MATRIX * vec4(occlusion_target + vec3(0.0, target_height, 0.0), 1.0);
	vec2 target_uv = clip.xy / clip.w * 0.5 + 0.5;
	vec2 delta = (SCREEN_UV - target_uv) * VIEWPORT_SIZE / VIEWPORT_SIZE.y;
	float inside = 1.0 - smoothstep(cutout_radius * (1.0 - cutout_softness), cutout_radius, length(delta));

	ALBEDO = tex.rgb;
	ALPHA = mix(1.0, cutout_alpha, inside * behind);
}
