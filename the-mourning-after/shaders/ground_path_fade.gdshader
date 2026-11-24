shader_type spatial;
render_mode unshaded, depth_draw_never;
// Ground that fades out along its UV.x, for path exits.

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform float world_uv_scale = 0.25; // TUNE: texture repeats per metre (match ground)
uniform float stone_strength : hint_range(0.0, 1.0) = 1.0; // copied from the room's floor
uniform float fade_start = 0.1; // TUNE: fade begins (0 = room edge, 1 = path end)
uniform float fade_end = 0.85; // TUNE: fully faded
instance uniform vec4 tint : source_color = vec4(1.0);

varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec3 stone = texture(albedo_texture, world_xz * world_uv_scale).rgb;
	ALBEDO = mix(vec3(1.0), stone, stone_strength) * tint.rgb;
	ALPHA = 1.0 - smoothstep(fade_start, fade_end, UV.x);
}
