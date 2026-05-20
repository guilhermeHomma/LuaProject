extern vec4 u_onColor;
extern vec4 u_offColor;
extern float u_active;
extern float u_time;
extern vec2 u_texel;
extern float u_rainbow;

vec3 rainbow(float t) {
    vec3 vivid = 0.5 + 0.5 * cos(6.28318 * (vec3(0.0, 0.33, 0.67) + t));
    return vivid * vec3(0.78, 0.62, 0.95) + vec3(0.06, 0.02, 0.10);
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screenCoord) {
    vec4 base = Texel(tex, uv);
    float alpha = base.a;

    float glow = 0.0;
    glow += Texel(tex, uv + vec2( u_texel.x, 0.0)).a;
    glow += Texel(tex, uv + vec2(-u_texel.x, 0.0)).a;
    glow += Texel(tex, uv + vec2(0.0,  u_texel.y)).a;
    glow += Texel(tex, uv + vec2(0.0, -u_texel.y)).a;
    glow += Texel(tex, uv + vec2( u_texel.x,  u_texel.y)).a;
    glow += Texel(tex, uv + vec2(-u_texel.x,  u_texel.y)).a;
    glow += Texel(tex, uv + vec2( u_texel.x, -u_texel.y)).a;
    glow += Texel(tex, uv + vec2(-u_texel.x, -u_texel.y)).a;
    glow = clamp(glow / 8.0, 0.0, 1.0);

    float pulse = 0.82 + sin(u_time * 4.0) * 0.18;
    float redPulse = 0.5 + sin(u_time * 2.7 + 1.4) * 0.5;
    vec3 warmShift = vec3(0.10, -0.025, -0.055) * redPulse;
    vec3 rainbowColor = rainbow(uv.x * 0.85 + uv.y * 0.45 + u_time * 0.52);
    vec3 normalColor = clamp(u_onColor.rgb * (0.95 + pulse * 0.25) + warmShift, 0.0, 1.0);
    vec3 litColor = mix(normalColor, rainbowColor, u_rainbow);
    vec4 lit = vec4(litColor, u_onColor.a);
    vec4 off = u_offColor;
    vec4 signColor = mix(off, lit, u_active);
    float glowAlpha = glow * (1.0 - alpha) * u_active * 0.65 * pulse;

    vec3 glowColor = mix(u_onColor.rgb, litColor, 0.65);
    return vec4(signColor.rgb, alpha * signColor.a) + vec4(glowColor, glowAlpha);
}
