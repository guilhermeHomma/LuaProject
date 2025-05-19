extern vec3 oldColors[9];
extern vec3 newColors[9];
extern number threshold; // margem de tolerância

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec4 pixel = Texel(texture, texture_coords) * color;

    for (int i = 0; i < 9; i++) {
        if (distance(pixel.rgb, oldColors[i]) < threshold) {
            pixel.rgb = newColors[i];
            break;
        }
    }

    return pixel;
}