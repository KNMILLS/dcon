shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform float memory_pressure : hint_range(0.0, 1.0) = 0.0;
uniform float jitter_intensity : hint_range(0.0, 5.0) = 1.0;
uniform float scanline_density : hint_range(100.0, 2000.0) = 900.0;
uniform float chroma_shift : hint_range(0.0, 5.0) = 0.8;

void fragment() {
    float p = clamp(memory_pressure, 0.0, 1.0);

    // Horizontal jitter based on time and row index
    float row = floor(SCREEN_UV.y * scanline_density);
    float rnd = fract(sin(row * 12.9898 + TIME * 78.233) * 43758.5453);
    float jitter = (rnd - 0.5) * 0.003 * jitter_intensity * (0.2 + 0.8 * p);

    // Chromatic aberration increases with pressure
    vec2 jitter_uv = vec2(jitter, 0.0);
    vec2 uv_r = SCREEN_UV + jitter_uv * (0.5 + 1.5 * p) + vec2( 0.0015 * chroma_shift * p, 0.0);
    vec2 uv_g = SCREEN_UV + jitter_uv * (0.5 + 1.5 * p);
    vec2 uv_b = SCREEN_UV + jitter_uv * (0.5 + 1.5 * p) + vec2(-0.0015 * chroma_shift * p, 0.0);

    float mask = texture(SCREEN_TEXTURE, SCREEN_UV).a;
    vec3 col;
    col.r = texture(SCREEN_TEXTURE, uv_r).r;
    col.g = texture(SCREEN_TEXTURE, uv_g).g;
    col.b = texture(SCREEN_TEXTURE, uv_b).b;

    // Faint scanlines overlay that intensifies with pressure
    float lines = 0.5 + 0.5 * sin(SCREEN_UV.y * scanline_density * 3.14159);
    float scan_strength = mix(0.04, 0.22, p);
    col *= 1.0 - lines * scan_strength;

    COLOR = vec4(col, mask);
}