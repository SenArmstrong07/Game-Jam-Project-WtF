shader_type canvas_item;

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float dist = length(uv);

	// Approximate one pixel in the 192px minimap
	float pixel = 1.0 / 192.0;
	// Shrink radius slightly to avoid leaving a 1px fringe
	float radius = 0.5 - pixel;

	// Soft anti-alias band to avoid hard edge artifacts
	float aa = pixel * 1.5;
	float alpha_mask = clamp(1.0 - smoothstep(radius - aa, radius + aa, dist), 0.0, 1.0);

	// Multiply both color and alpha by mask so outer pixels become fully transparent black (no white fringe)
	COLOR.rgb *= alpha_mask;
	COLOR.a *= alpha_mask;
}
