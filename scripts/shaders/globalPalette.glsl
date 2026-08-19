extern vec3 u_palette[32];
extern int u_paletteSize;
extern number u_strength;
extern number u_brightness;

float colorDistance(vec3 source, vec3 candidate) {
    vec3 delta = source - candidate;
    float rgbDistance = dot(delta * delta, vec3(0.30, 0.59, 0.11));
    float sourceLuma = dot(source, vec3(0.299, 0.587, 0.114));
    float candidateLuma = dot(candidate, vec3(0.299, 0.587, 0.114));
    float lumaDelta = sourceLuma - candidateLuma;
    return rgbDistance + lumaDelta * lumaDelta * 0.35;
}

vec3 applyBrightness(vec3 rgb) {
    float value = clamp(u_brightness, 0.0, 10.0);
    if (value < 5.0) {
        return mix(rgb * 0.58, rgb, value / 5.0);
    }

    float amount = (value - 5.0) / 5.0;
    vec3 lifted = vec3(1.0) - (vec3(1.0) - rgb) * 0.78;
    return mix(rgb, lifted, amount);
}

vec4 effect(vec4 color, Image texture, vec2 textureCoords, vec2 screenCoords) {
    vec4 pixel = Texel(texture, textureCoords) * color;
    vec3 nearestColor = u_palette[0];
    float nearestDistance = colorDistance(pixel.rgb, nearestColor);

    for (int i = 1; i < 32; i++) {
        if (i >= u_paletteSize) {
            break;
        }

        float distanceToColor = colorDistance(pixel.rgb, u_palette[i]);
        if (distanceToColor < nearestDistance) {
            nearestDistance = distanceToColor;
            nearestColor = u_palette[i];
        }
    }

    vec3 paletteColor = applyBrightness(nearestColor);
    pixel.rgb = mix(pixel.rgb, paletteColor, clamp(u_strength, 0.0, 1.0));
    return pixel;
}
