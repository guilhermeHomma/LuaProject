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

    float minDist1 = 10000.0;
    float minDist2 = 10000.0;
    int index1 = -1;
    int index2 = -1;

    // Encontrar as duas cores mais próximas
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

    if (index1 >= 0) {
        if (threshold <= 0.0 || minDist1 < threshold) {
            // 👉 Se estiver dentro do threshold → substitui direto
            pixel.rgb = newColors[index1];
        } else {
            // 👉 Fora do threshold → interpola entre as duas cores mais próximas
            float t = minDist1 / (minDist1 + minDist2 + 0.00001);  // Peso da interpolação

            vec3 color1 = newColors[index1];
            vec3 color2 = (index2 >= 0) ? newColors[index2] : color1;

            pixel.rgb = mix(color1, color2, t);
        }
    }

    // Aplicar saturação e brilho
    pixel.rgb = adjustSaturation(pixel.rgb, saturation);
    pixel.rgb = adjustBrightness(pixel.rgb, brightness);

    return pixel;
}
