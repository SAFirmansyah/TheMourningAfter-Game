shader_type canvas_item;
// Constance's side atmosphere, over the scene beneath it: night darkening and cooling, a warm light
// (the campfire) keeping a pool lit, golden light at dawn and dusk, a soft vignette and faint paper grain.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float amount : hint_range(0.0, 1.0) = 0.0; // 0 = day, 1 = full night
uniform vec3 night_tint : source_color = vec3(0.45, 0.52, 0.8); // TUNE: colour cast at night
uniform float night_brightness = 0.45; // TUNE: brightness at full night (1 = no darkening)
uniform float night_desaturation = 0.4; // TUNE: colour loss at full night (0 = none, 1 = grayscale)

group_uniforms mood;
uniform vec3 room_tint = vec3(1.0); // set by the room (eerie places)
uniform float room_brightness = 1.0; // set by the room
uniform float warmth = 0.0; // 0-1, set by the day cycle: golden hour at dawn and dusk
uniform vec3 warm_tint : source_color = vec3(1.0, 0.8, 0.58); // TUNE: golden-hour colour
uniform float warm_strength = 0.22; // TUNE: how strong golden hour gets
uniform float vignette = 0.3; // TUNE: edge darkening (0 = none)
uniform float vignette_softness = 0.75; // TUNE: how far in the vignette reaches (higher = gentler)
uniform float grain = 0.025; // TUNE: paper grain strength (0 = none)
group_uniforms;

group_uniforms light;
uniform vec2 light_uv = vec2(0.5); // light centre on screen (0-1)
uniform float light_radius = 0.0; // light reach, as a share of the screen height
uniform float light_strength = 0.0; // 0 = off; set each frame by the light (flicker included)
uniform vec3 light_color : source_color = vec3(1.0, 0.62, 0.3); // TUNE: firelight colour
uniform float light_squash = 1.6; // TUNE: flattens the pool vertically, so it lies on the ground
uniform float light_warmth = 0.45; // TUNE: how much the light tints what it reaches
group_uniforms;

void fragment() {
	vec3 color = texture(screen_texture, SCREEN_UV).rgb;
	float gray = dot(color, vec3(0.299, 0.587, 0.114));
	vec3 night = mix(color, vec3(gray), night_desaturation) * night_tint * night_brightness;

	float lit = 0.0;
	if (light_strength > 0.0 && light_radius > 0.0) {
		vec2 delta = (SCREEN_UV - light_uv) * vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, light_squash);
		float falloff = 1.0 - smoothstep(0.0, light_radius, length(delta));
		lit = falloff * falloff * light_strength;
	}
	vec3 dark = mix(color, night, amount * (1.0 - clamp(lit, 0.0, 0.9)));
	vec3 result = dark * mix(vec3(1.0), light_color * 1.6, light_warmth * lit * amount);
	result *= mix(vec3(1.0), warm_tint, warmth * warm_strength * (1.0 - amount));

	result *= room_tint * room_brightness;

	vec2 centred = (SCREEN_UV - 0.5) * vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	result *= 1.0 - vignette * smoothstep(vignette_softness * 0.4, vignette_softness, length(centred) * 1.2);

	float noise = fract(sin(dot(floor(FRAGCOORD.xy * 0.5) + floor(TIME * 12.0) * vec2(17.0, 31.0), vec2(12.9898, 78.233))) * 43758.5453);
	result += (noise - 0.5) * grain;
	COLOR = vec4(result, 1.0);
}
