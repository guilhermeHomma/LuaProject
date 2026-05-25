extern number u_time;
extern number u_alpha;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
    vec4 pixel = Texel(texture, texture_coords) * color;
    if (pixel.a <= 0.01) {
        discard;
    }

    number waveA = sin(screen_coords.x * 0.045 + screen_coords.y * 0.018 + u_time * 2.2);
    number waveB = sin((screen_coords.x - screen_coords.y) * 0.026 - u_time * 1.6);
    number blend = (waveA + waveB) * 0.25 + 0.5;

    vec3 deepBlue = vec3(0.05, 0.09, 0.18);
    vec3 coldBlue = vec3(0.12, 0.20, 0.34);
    vec3 tint = mix(deepBlue, coldBlue, blend);

    return vec4(tint, pixel.a * u_alpha);
}
