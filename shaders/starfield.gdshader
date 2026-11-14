shader_type canvas_item;

// Starfield Shader for Godot 4
// Simulates deep space with multi-layered twinkling stars and slow cosmic drift

uniform vec4 background_color : source_color = vec4(0.005, 0.005, 0.015, 1.0);
uniform vec4 star_tint_cool : source_color = vec4(0.75, 0.88, 1.0, 1.0);
uniform vec4 star_tint_warm : source_color = vec4(1.0, 0.92, 0.75, 1.0);
uniform float drift_speed : hint_range(0.0, 0.05) = 0.006;
uniform float twinkle_speed : hint_range(0.5, 8.0) = 2.2;
uniform vec2 camera_offset = vec2(0.0);

// Pseudo-random 2D hash
float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

vec2 hash22(vec2 p) {
    float n = hash21(p);
    return vec2(n, hash21(p + n + 1.23));
}

// Generates a grid-based layer of stars
vec3 render_stars(vec2 uv, float grid_size, float time_val, float seed_offset) {
    vec2 gv = fract(uv * grid_size) - 0.5;
    vec2 id = floor(uv * grid_size);
    vec3 col = vec3(0.0);
    
    // Sample 3x3 surrounding cells to prevent clipping at tile boundaries
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 offset = vec2(float(x), float(y));
            vec2 cell_id = id + offset;
            
            vec2 rnd = hash22(cell_id + seed_offset);
            vec2 star_pos = offset + (rnd - 0.5) * 0.72;
            
            float dist = length(gv - star_pos);
            float star_strength = rnd.x;
            
            // Twinkle effect with random phase
            float twinkle = sin(time_val * twinkle_speed + rnd.y * 6.28318) * 0.35 + 0.65;
            
            // Star core and subtle corona glow
            float core = smoothstep(0.055 * star_strength, 0.0, dist);
            float glow = smoothstep(0.22 * star_strength, 0.0, dist) * 0.25;
            float brightness = (core + glow) * twinkle;
            
            // Color variation between warm and cool stars
            vec3 star_col = mix(star_tint_cool.rgb, star_tint_warm.rgb, rnd.y);
            col += star_col * brightness;
        }
    }
    return col;
}

void fragment() {
    vec2 uv = UV;
    
    // Maintain uniform aspect ratio so stars are round on all screen sizes
    vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
    float aspect = res.x / max(res.y, 1.0);
    vec2 aspect_uv = vec2(uv.x * aspect, uv.y);
    
    // Slow downward drift representing forward motion into space + camera parallax
    vec2 drift = vec2(0.0, TIME * drift_speed);
    vec2 cam = camera_offset * 0.00018;
    
    // Layer 1: Dense, tiny background stars (distant galaxy)
    vec3 layer1 = render_stars(aspect_uv + drift * 0.4 + cam * 0.25, 45.0, TIME, 17.43);
    
    // Layer 2: Medium brightness stars
    vec3 layer2 = render_stars(aspect_uv + drift * 0.7 + cam * 0.55, 24.0, TIME, 53.81);
    
    // Layer 3: Prominent foreground stars with noticeable twinkle
    vec3 layer3 = render_stars(aspect_uv + drift * 1.1 + cam * 1.0, 11.0, TIME, 89.15);
    
    // Very faint cosmic dust nebula in the background
    float nebula = (sin(aspect_uv.x * 2.5 + TIME * 0.02) * cos(aspect_uv.y * 2.0 - TIME * 0.015)) * 0.015;
    vec3 bg = background_color.rgb + vec3(0.01, 0.012, 0.025) * max(0.0, nebula);
    
    vec3 final_color = bg + layer1 * 0.45 + layer2 * 0.85 + layer3 * 1.25;
    COLOR = vec4(final_color, 1.0);
}
