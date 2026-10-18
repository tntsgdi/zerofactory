shader_type canvas_item;
// Pointer-driven button finish (from the player's Skyguard, 2026-10-18): a fill
// that pours in from where the pointer entered and inverts whatever is under it
// (the label included; by brightness, 2026-10-18), a soft light that follows the pointer, and a highlight
// that runs along the border near it.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec2 rect_size = vec2(100.0, 40.0);
uniform vec2 fill_center = vec2(0.0);
uniform float fill_radius = 0.0;
uniform vec2 spot = vec2(-999.0);
uniform float spot_alpha = 0.0;
uniform vec4 tint : source_color = vec4(1.0);

void fragment() {
	vec2 p = UV * rect_size;
	vec3 under = texture(screen_tex, SCREEN_UV).rgb;
	float d = distance(p, fill_center);
	float inside = 1.0 - smoothstep(fill_radius - 1.2, fill_radius + 1.2, d);
	float near = 1.0 - smoothstep(0.0, 170.0, distance(p, spot));
	float glow = spot_alpha * 0.12 * near * near;
	float border = min(min(p.x, rect_size.x - p.x), min(p.y, rect_size.y - p.y));
	float edge = (1.0 - smoothstep(0.0, 1.8, border)) * spot_alpha * (1.0 - smoothstep(0.0, 120.0, distance(p, spot)));
	vec3 lit = min(vec3(1.0), under + vec3(glow + edge * 0.85));
	// inverted by brightness only, so a green lamp doesn't turn magenta
	float l = dot(clamp(under, 0.0, 1.0), vec3(0.2126, 0.7152, 0.0722));
	vec3 inverted = vec3(1.0 - l) * tint.rgb;
	COLOR = vec4(mix(lit, inverted, inside), 1.0);
}
