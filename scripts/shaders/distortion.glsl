extern number saturation;
extern number brightness;
extern number distortion = 1.0;

vec3 adjustSaturation(vec3 color, float sat) {
    float luma = dot(color, vec3(0.299, 0.587, 0.114));
    return mix(vec3(luma), color, sat);
}

vec3 adjustBrightness(vec3 color, float b) {
    return clamp(color * b, 0.0, 1.0);
}

vec4 blur(vec2 uv, Image tex, float amount) {
    vec4 sum = vec4(0.0);
    float total = 0.0;

    vec2 pixel_size = vec2(1) / love_ScreenSize.xy;

    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            vec2 offset = vec2(float(x), float(y)) * amount * pixel_size;
            vec2 offset_uv = floor((uv + offset) / pixel_size) * pixel_size + pixel_size * 0.5;
            sum += Texel(tex, offset_uv);
            total += 1.0;
        }
    }

    return sum / total;
}

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    float blur_strength = distortion * 5;

    vec4 texel = blur(texture_coords, texture, blur_strength);

    texel.b = adjustSaturation(texel.rgb, saturation).b;
    texel.g = adjustSaturation(texel.rgb, saturation/2).g;
    texel.r = adjustSaturation(texel.rgb, saturation/2).r;

    texel.rgb = adjustBrightness(texel.rgb, brightness);

    return texel * color;
}
