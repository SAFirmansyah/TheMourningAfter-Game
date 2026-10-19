shader_type spatial;
render_mode unshaded;
// Ground with world-space UVs so separate floor pieces tile seamlessly.

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform float world_uv_scale = 0.25; // TUNE: texture repeats per metre
instance uniform vec4 tint : source_color = vec4(1.0);

varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	ALBEDO = texture(albedo_texture, world_xz * world_uv_scale).rgb * tint.rgb;
}
