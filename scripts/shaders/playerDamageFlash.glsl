extern number u_alpha;
extern vec2 u_textureSize;
extern number u_pixelSize;

vec4 effect(vec4 color, Image tex, vec2 texCoord, vec2 screenCoord) {
    vec2 pixelCoord = floor(texCoord * u_textureSize / u_pixelSize + 0.5) * u_pixelSize;
    vec2 snappedUv = clamp(pixelCoord / u_textureSize, vec2(0.0), vec2(1.0));
    vec4 pixel = Texel(tex, snappedUv) * color;
    pixel.a *= u_alpha;
    return pixel;
}
