extern number u_time;

vec3 zombieColor(float t)
{
    vec3 wave = vec3(
        0.64 + cos(t + 0.2) * 0.09,
        0.66 + cos(t + 2.1) * 0.08,
        0.62 + cos(t + 4.0) * 0.10
    );
    vec3 gray = vec3(0.68, 0.68, 0.64);
    return mix(gray, wave, 0.58);
}

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
{
    vec4 pixel = Texel(tex, texture_coords) * color;
    if (pixel.a <= 0.01) {
        return pixel;
    }

    float luma = dot(pixel.rgb, vec3(0.299, 0.587, 0.114));
    float band = screen_coords.x * 0.018 + screen_coords.y * 0.006 + u_time * 1.25;
    vec3 tint = zombieColor(band);
    float strength = 0.42 * smoothstep(0.08, 0.95, luma);

    pixel.rgb = mix(pixel.rgb, tint, strength);
    return pixel;
}
