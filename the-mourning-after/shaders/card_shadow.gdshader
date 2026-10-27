shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, world_vertex_coords;
// Flat sun shadow for a card: its silhouette laid on the ground, pointing away from the sun.
// Sun direction, length and strength come from global uniforms set by the day cycle.

global uniform vec2 sun_shadow_dir;
global uniform float sun_shadow_length;
global uniform float sun_shadow_alpha;

uniform sampler2D card_texture : filter_linear_mipmap;
uniform vec2 card_size = vec2(1.0); // card width and height in metres
uniform float ground_lift = 0.02; // height above the floor, avoids flicker

void vertex() {
	vec2 d = normalize(sun_shadow_dir);
	vec3 along = vec3(d.x, 0.0, d.y);
	vec3 across = vec3(-d.y, 0.0, d.x);
	vec3 base = vec3(NODE_POSITION_WORLD.x, ground_lift, NODE_POSITION_WORLD.z);
	VERTEX = base + across * (UV.x - 0.5) * card_size.x + along * (1.0 - UV.y) * card_size.y * sun_shadow_length;
}

void fragment() {
	ALBEDO = vec3(0.0);
	ALPHA = texture(card_texture, UV).a * sun_shadow_alpha;
}
