vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
    vec4 pixel = Texel(texture, texture_coords) * color;
    if (pixel.a <= 0.05) {
        discard;
    }

    return vec4(1.0);
}
