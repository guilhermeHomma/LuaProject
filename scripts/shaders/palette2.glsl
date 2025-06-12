extern vec3 oldColors[9];
extern vec3 newColors[9];
extern vec3 altColors[9];

extern number threshold;
extern number saturation;
extern number brightness;

extern vec2 light_positions[10];
extern float light_radii[10];
extern int light_count;

vec3 adjustSaturation(vec3 color, float sat) {
    float luma = dot(color, vec3(0.299, 0.587, 0.114));
    return mix(vec3(luma), color, sat);
}

vec3 adjustBrightness(vec3 color, float b) {
    return clamp(color * b, 0.0, 1.0);
}

float computeLightInfluence(vec2 pixel_pos) {
    float influence = 0.0;

    for (int i = 0; i < light_count; i++) {
        vec2 light_pos = light_positions[i];
        float radius = light_radii[i];
        float dist = distance(pixel_pos, light_pos);

        if (dist < radius) {
            float localInfluence = 1.0 - (dist / radius);
            influence = max(influence, localInfluence);  // pegar a mais forte
        }
    }

    return clamp(influence, 0.0, 1.0);
}

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec4 pixel = Texel(texture, texture_coords) * color;

    float minDist1 = 10000.0;
    float minDist2 = 10000.0;
    int index1 = -1;
    int index2 = -1;

    for (int i = 0; i < 9; i++) {
        float d = distance(pixel.rgb, oldColors[i]);
        if (d < minDist1) {
            minDist2 = minDist1;
            index2 = index1;

            minDist1 = d;
            index1 = i;
        } else if (d < minDist2) {
            minDist2 = d;
            index2 = i;
        }
    }

    vec3 baseColor = pixel.rgb;

    if (index1 >= 0) {
        vec3 lightColor, darkColor;

        if (threshold <= 0.0 || minDist1 < threshold) {
            lightColor = newColors[index1];
            darkColor = altColors[index1];
        } else {
            float t = minDist1 / (minDist1 + minDist2 + 0.00001);
            vec3 c1_light = newColors[index1];
            vec3 c2_light = (index2 >= 0) ? newColors[index2] : c1_light;

            vec3 c1_dark = altColors[index1];
            vec3 c2_dark = (index2 >= 0) ? altColors[index2] : c1_dark;

            lightColor = mix(c1_light, c2_light, t);
            darkColor = mix(c1_dark, c2_dark, t);
        }

        float influence = computeLightInfluence(screen_coords);

        //influence = floor(influence * 6.0) / 6.0;
        baseColor = mix(darkColor, lightColor, influence);
    }

    baseColor = adjustSaturation(baseColor, saturation);
    baseColor = adjustBrightness(baseColor, brightness);

    return vec4(baseColor, pixel.a);
}
