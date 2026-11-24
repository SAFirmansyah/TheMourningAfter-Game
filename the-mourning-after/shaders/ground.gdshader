shader_type spatial;
render_mode unshaded;
// Ground with world-space UVs so separate floor pieces tile seamlessly.

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform float world_uv_scale = 0.25; // TUNE: texture repeats per metre
uniform float stone_strength : hint_range(0.0, 1.0) = 1.0; // TUNE: how much the stone shows over the plain tint (1 = full)
uniform float carpet : hint_range(0.0, 1.0) = 0.0; // carpet pile: fine fibre noise and soft mottling
instance uniform vec4 tint : source_color = vec4(1.0);

varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec3 stone = texture(albedo_texture, world_xz * world_uv_scale).rgb;
	vec3 base = mix(vec3(1.0), stone, stone_strength);
	if (carpet > 0.0) {
		vec2 p = world_xz * 40.0; // fibres
		float fibre = fract(sin(dot(floor(p), vec2(12.9898, 78.233))) * 43758.5453);
		vec2 q = world_xz * 1.3; // soft wear patches
		float patch = 0.5 + 0.5 * sin(q.x * 1.7 + sin(q.y * 2.3)) * sin(q.y * 1.9 + sin(q.x * 1.1));
		base *= mix(1.0, (0.74 + 0.26 * fibre) * (0.8 + 0.2 * patch), carpet);
	}
	ALBEDO = base * tint.rgb;
}
