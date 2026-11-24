shader_type spatial;
render_mode unshaded, depth_prepass_alpha;
// Card material: optional see-through cutout over the player, optional foliage sway.
// Sway adapted from an open-source canvas_item foliage shader, ported to 3D cards.

global uniform vec3 occlusion_target;

uniform sampler2D card_texture : source_color, filter_linear_mipmap;
uniform sampler2D card_texture_pixel : source_color, filter_nearest; // same texture, for pixel art
uniform bool pixel_art = false;
uniform vec4 card_modulate : source_color = vec4(1.0);

group_uniforms occlusion;
uniform bool occlusion_enabled = false;
uniform float target_height = 0.9; // TUNE: cutout centre height above player's feet (m)
uniform float cutout_radius = 0.1; // TUNE: see-through circle radius (fraction of screen height)
uniform float cutout_softness = 0.6; // TUNE: circle edge softness (0 = hard, 1 = fully soft)
uniform float cutout_alpha = 0.25; // TUNE: card opacity at circle centre
uniform float depth_blend = 0.6; // TUNE: depth (m) over which the cutout fades in as the player moves behind

group_uniforms sway;
uniform bool sway_enabled = false;
uniform sampler2D wind_noise : repeat_enable, filter_linear;
uniform float sway_amplitude = 0.2; // TUNE: lean strength (radians at strongest wind)
uniform float sway_speed = 0.06; // TUNE: how fast the wind pattern drifts
uniform float sway_noise_scale = 0.05; // TUNE: wind pattern size per metre (smaller = nearby objects sway more alike)
uniform float sway_bend = 1.0; // TUNE: how much the top bends relative to the base
uniform vec2 sway_pivot = vec2(0.5, 1.0); // card UV the sway pivots on (bottom centre)
group_uniforms;

vec2 rotate_around(vec2 v, vec2 pivot, float angle) {
	float c = cos(angle);
	float s = sin(angle);
	v -= pivot;
	return vec2(c * v.x - s * v.y, c * v.y + s * v.x) + pivot;
}

void fragment() {
	vec2 uv = UV;
	if (sway_enabled) {
		vec2 sample_pos = NODE_POSITION_WORLD.xz * sway_noise_scale + vec2(TIME * sway_speed);
		float angle = sway_amplitude * (texture(wind_noise, sample_pos).r - 0.5);
		vec2 size = vec2(textureSize(card_texture, 0));
		vec2 aspect = vec2(size.x / size.y, 1.0);
		vec2 rotated = rotate_around(UV * aspect, sway_pivot * aspect, angle) / aspect;
		uv = mix(UV, rotated, clamp(distance(UV, sway_pivot) * sway_bend, 0.0, 1.0));
	}

	vec4 tex = (pixel_art ? texture(card_texture_pixel, uv) : texture(card_texture, uv)) * card_modulate;
	if (tex.a < 0.5) {
		discard;
	}

	float alpha = 1.0;
	if (occlusion_enabled) {
		vec4 feet_view = VIEW_MATRIX * vec4(occlusion_target, 1.0);
		float behind = smoothstep(0.0, depth_blend, NODE_POSITION_VIEW.z - feet_view.z);
		vec4 clip = PROJECTION_MATRIX * VIEW_MATRIX * vec4(occlusion_target + vec3(0.0, target_height, 0.0), 1.0);
		vec2 target_uv = clip.xy / clip.w * 0.5 + 0.5;
		vec2 delta = (SCREEN_UV - target_uv) * VIEWPORT_SIZE / VIEWPORT_SIZE.y;
		float inside = 1.0 - smoothstep(cutout_radius * (1.0 - cutout_softness), cutout_radius, length(delta));
		alpha = mix(1.0, cutout_alpha, inside * behind);
	}

	ALBEDO = tex.rgb;
	ALPHA = alpha;
}
