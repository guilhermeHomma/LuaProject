extern number time = 0.0;
extern number intensity = 0.0;
extern number flash = 0.0;
extern vec2 texturePixelSize = vec2(1.0, 1.0);
extern number displacementPixels = 2.0;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
    float band = floor(texture_coords.y * 34.0 + time * 32.0);
    float mask = step(0.48, fract(sin(band * 17.13 + floor(time * 46.0)) * 43758.5453));
    float horizontalPixels = floor(fract(sin((band + 3.0) * 9.73) * 12741.371) * 2.0) + 1.0;
    float horizontalDirection = fract(sin((band + 11.0) * 5.19) * 3712.114) > 0.5 ? 1.0 : -1.0;
    float horizontalShift = texturePixelSize.x * horizontalPixels * displacementPixels * horizontalDirection * mask * intensity;
    vec2 offset = vec2(horizontalShift, 0.0);

    vec4 base = Texel(texture, texture_coords);
    vec4 shiftedA = Texel(texture, texture_coords + offset);
    vec4 shiftedB = Texel(texture, texture_coords - offset * 0.6);
    vec4 texel = mix(base, shiftedA, 0.42 * intensity);
    texel.rgb = mix(texel.rgb, vec3(shiftedA.r, base.g, shiftedB.b), 0.28 * intensity);

    float blockMask = step(0.82, fract(sin(floor(texture_coords.y * 18.0) * 23.41 + floor(time * 26.0)) * 9187.13)) * intensity;
    texel = mix(texel, shiftedB, blockMask * 0.2);

    float scan = step(0.82, fract(texture_coords.y * 18.0 + time * 20.0));
    texel.rgb = mix(texel.rgb, texel.rgb * 0.7, scan * 0.16 * intensity);
    texel.rgb = mix(texel.rgb, vec3(0.95, 0.97, 0.96), clamp(flash, 0.0, 1.0));

    return texel * color;
}
