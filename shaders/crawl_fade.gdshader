shader_type canvas_item;

// Star Wars Crawl Fade Shader
// Applied to the SubViewportContainer to fade text out as it recedes into the top vanishing point,
// and softly fade in at the bottom edge. Leaves the starry background fully visible.

uniform float top_fade_start : hint_range(0.0, 1.0) = 0.38;
uniform float top_fade_end : hint_range(0.0, 1.0) = 0.08;
uniform float bottom_fade_start : hint_range(0.0, 1.0) = 0.88;
uniform float bottom_fade_end : hint_range(0.0, 1.0) = 0.98;

void fragment() {
    vec4 col = texture(TEXTURE, UV);
    
    // Top dissolve into space
    float top_alpha = smoothstep(top_fade_end, top_fade_start, UV.y);
    
    // Bottom entrance smooth fade
    float bottom_alpha = smoothstep(bottom_fade_end, bottom_fade_start, UV.y);
    
    col.a *= top_alpha * bottom_alpha;
    COLOR = col;
}
