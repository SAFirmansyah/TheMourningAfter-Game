shader_type spatial;
render_mode unshaded;
// Ground with world-space UVs so separate floor pieces tile seamlessly.

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform float world_uv_scale = 0.25; // TUNE: texture repeats per metre
uniform float stone_strength : hint_range(0.0, 1.0) = 1.0; // TUNE: how much the stone shows over the plain tint (1 = full)
instance uniform vec4 tint : source_color = vec4(1.0);

varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec3 stone = texture(albedo_texture, world_xz * world_uv_scale).rgb;
	ALBEDO = mix(vec3(1.0), stone, stone_strength) * tint.rgb;
}
