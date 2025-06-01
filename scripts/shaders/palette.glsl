extern vec3 oldColors[9];
extern vec3 newColors[9];
extern number threshold;    // margem de tolerância
extern number saturation;   // controle de saturação
extern number brightness;   // controle de brilho

vec3 adjustSaturation(vec3 color, float sat) {
    float luma = dot(color, vec3(0.299, 0.587, 0.114));
    return mix(vec3(luma), color, sat);
}

vec3 adjustBrightness(vec3 color, float b) {
    return clamp(color * b, 0.0, 1.0);
}

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec4 pixel = Texel(texture, texture_coords) * color;

    float minDistance = 10000.0;
    int minIndex = -1;

    for (int i = 0; i < 9; i++) {
        float d = distance(pixel.rgb, oldColors[i]);
        if (d < minDistance) {
            minDistance = d;
            minIndex = i;
        }
    }

    if (minIndex >= 0 && (threshold <= 0.0 || minDistance < threshold)) {
        pixel.rgb = newColors[minIndex];
    }

    // Aplicar saturação e brilho
    pixel.rgb = adjustSaturation(pixel.rgb, saturation);
    pixel.rgb = adjustBrightness(pixel.rgb, brightness);

    return pixel;
}