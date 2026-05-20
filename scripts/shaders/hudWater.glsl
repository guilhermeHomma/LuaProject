extern number u_time;
extern number u_strength;

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
{
    vec2 uv = texture_coords;
    vec2 center = vec2(0.5, 0.5);
    vec2 centered = uv - center;

    float rotation = sin(u_time * 0.23) * u_strength * 0.85;
    float c = cos(rotation);
    float s = sin(rotation);
    vec2 rotated = vec2(
        centered.x * c - centered.y * s,
        centered.x * s + centered.y * c
    ) + center;

    vec2 dir = vec2(cos(u_time * 0.11), sin(u_time * 0.11));
    vec2 perp = vec2(-dir.y, dir.x);
    float waveA = sin(dot(screen_coords, dir) * 0.035 + u_time * 0.75);
    float waveB = sin(dot(screen_coords, perp) * 0.026 - u_time * 0.48);
    vec2 ripple = (dir * waveA + perp * waveB * 0.65) * u_strength;

    return Texel(tex, rotated + ripple) * color;
}
