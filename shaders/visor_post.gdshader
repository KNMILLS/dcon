shader_type canvas_item;

uniform int mode : hint_range(0, 2) = 0; // 0 NONE, 1 EDGE, 2 THERMAL
uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float edge_strength : hint_range(0.0, 5.0) = 1.0;

float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

vec3 sobel(vec2 uv) {
    vec2 px = TEXTURE_PIXEL_SIZE;
    float tl = luma(texture(TEXTURE, uv + vec2(-px.x, -px.y)).rgb);
    float tc = luma(texture(TEXTURE, uv + vec2( 0.0 , -px.y)).rgb);
    float tr = luma(texture(TEXTURE, uv + vec2( px.x, -px.y)).rgb);
    float ml = luma(texture(TEXTURE, uv + vec2(-px.x,  0.0  )).rgb);
    float mc = luma(texture(TEXTURE, uv).rgb);
    float mr = luma(texture(TEXTURE, uv + vec2( px.x,  0.0  )).rgb);
    float bl = luma(texture(TEXTURE, uv + vec2(-px.x,  px.y)).rgb);
    float bc = luma(texture(TEXTURE, uv + vec2( 0.0 ,  px.y)).rgb);
    float br = luma(texture(TEXTURE, uv + vec2( px.x,  px.y)).rgb);
    float gx = (tr + 2.0 * mr + br) - (tl + 2.0 * ml + bl);
    float gy = (bl + 2.0 * bc + br) - (tl + 2.0 * tc + tr);
    float g = clamp(length(vec2(gx, gy)) * edge_strength, 0.0, 1.0);
    return vec3(g);
}

vec3 thermal(vec3 src) {
    float t = luma(src);
    vec3 c = mix(vec3(0.05, 0.10, 0.30), vec3(0.40, 0.00, 0.50), smoothstep(0.0, 0.4, t));
    c = mix(c, vec3(0.90, 0.40, 0.00),   smoothstep(0.3, 0.75, t));
    c = mix(c, vec3(1.00, 0.95, 0.60),   smoothstep(0.75, 1.0, t));
    return c;
}

void fragment() {
    vec2 uv = UV;

    if (glitch_intensity > 0.001) {
        float line = fract(UV.y * 360.0 + TIME * 0.25);
        float j = (step(0.48, line) - step(0.52, line)) * (glitch_intensity * 0.02);
        uv.x += j;
    }

    vec3 base = texture(TEXTURE, uv).rgb;
    vec3 outc = base;

    if (mode == 1) {
        outc = sobel(uv);
    } else if (mode == 2) {
        outc = thermal(base);
    }

    if (glitch_intensity > 0.001) {
        vec2 o = vec2(glitch_intensity * 0.003, 0.0);
        float r = texture(TEXTURE, uv + o).r;
        float b = texture(TEXTURE, uv - o).b;
        outc = vec3(r, outc.g, b);
    }

    COLOR = vec4(outc, 1.0);
}


