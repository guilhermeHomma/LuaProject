extern float u_time;

vec3 rainbow(float t)
{
    vec3 vivid = 0.5 + 0.5 * cos(6.28318 * (vec3(0.0, 0.33, 0.67) + t));
    return vivid * vec3(0.78, 0.62, 0.95) + vec3(0.06, 0.02, 0.10);
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screenCoord)
{
    vec4 base = Texel(tex, uv) * color;
    if (base.a <= 0.0) {
        return base;
    }

    float greenKey = step(0.88, base.g) * step(base.r, 0.08) * step(base.b, 0.08);
    if (greenKey > 0.0) {
        float stripe = uv.x * 1.8 + uv.y * 1.1 + u_time * 0.52;
        vec3 rb = rainbow(stripe);
        base.rgb = mix(base.rgb, rb, greenKey);
    }

    return base;
}
