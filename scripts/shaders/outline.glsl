extern vec2 u_texel;
extern vec4 u_outlineColor;
extern float u_threshold;
extern vec2 u_uvMin;
extern vec2 u_uvMax;

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screenCoord) {
    vec4 base = Texel(tex, uv) * color;

    if (base.a > u_threshold) {
        return base;
    }

    vec2 offsets[8];
    offsets[0] = vec2(-u_texel.x,  0.0);
    offsets[1] = vec2( u_texel.x,  0.0);
    offsets[2] = vec2( 0.0,       -u_texel.y);
    offsets[3] = vec2( 0.0,        u_texel.y);
    offsets[4] = vec2(-u_texel.x, -u_texel.y);
    offsets[5] = vec2( u_texel.x, -u_texel.y);
    offsets[6] = vec2(-u_texel.x,  u_texel.y);
    offsets[7] = vec2( u_texel.x,  u_texel.y);

    for (int i = 0; i < 8; i++) {
        vec2 sampleUv = clamp(uv + offsets[i], u_uvMin, u_uvMax);
        float alpha = Texel(tex, sampleUv).a;
        if (alpha > u_threshold) {
            return vec4(u_outlineColor.rgb, u_outlineColor.a);
        }
    }

    return base;
}
