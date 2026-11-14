shader_type canvas_item;

uniform vec2 frame_grid = vec2(32.0, 1.0);
uniform float frame_index = 0.0;
uniform float frame_blend : hint_range(0.0, 1.0) = 0.0;

varying vec4 sprite_color;

void vertex() {
	sprite_color = COLOR;
}

void fragment() {
	vec2 frame_size = vec2(1.0) / frame_grid;
	float frame_count = frame_grid.x * frame_grid.y;
	vec2 current_cell = vec2(mod(frame_index, frame_grid.x), floor(frame_index / frame_grid.x));
	float next_index = mod(frame_index + 1.0, frame_count);
	vec2 next_cell = vec2(mod(next_index, frame_grid.x), floor(next_index / frame_grid.x));
	vec2 half_pixel = TEXTURE_PIXEL_SIZE * 0.5;
	vec2 local_uv = UV - current_cell * frame_size;
	// Keep linear filtering within each frame, including the last-to-first wrap.
	local_uv = clamp(local_uv, half_pixel, frame_size - half_pixel);
	vec2 current_uv = local_uv + current_cell * frame_size;
	vec2 next_uv = local_uv + next_cell * frame_size;
	vec4 current_color = texture(TEXTURE, current_uv);
	vec4 next_color = texture(TEXTURE, next_uv);

	// Blend premultiplied colors so transparent edges retain their brightness.
	float alpha = mix(current_color.a, next_color.a, frame_blend);
	vec3 color = mix(current_color.rgb * current_color.a, next_color.rgb * next_color.a, frame_blend);
	COLOR = vec4(color / max(alpha, 0.00001), alpha) * sprite_color;
}
