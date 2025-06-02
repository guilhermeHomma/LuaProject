extern vec3 oldColors[9];
extern vec3 newColors[9];
extern number threshold;    // margem de tolerância
extern number saturation;   // controle de saturação
extern number brightness;   // controle de brilho

extern number border_influence = 0.1; // controla quão longe do centro começa a trocar (0.0 a 1.0)

vec3 adjustSaturation(vec3 color, float sat) {
    float luma = dot(color, vec3(0.299, 0.587, 0.114));
    return mix(vec3(luma), color, sat);
}

vec3 adjustBrightness(vec3 color, float b) {
    return clamp(color * b, 0.0, 1.0);
}

float borderFactor(vec2 uv) {
    // Calcula distância até o centro (0.5, 0.5)
    vec2 center = vec2(0.5);
    float dist = distance(uv, center);

    // Define até onde começa o efeito
    float borderStart = border_influence; // 0.0 = começa no centro, 0.5 = metade, 1.0 = só nas bordas
    float factor = smoothstep(borderStart, 0.707, dist); 
    // 0.707 é a distância máxima do centro ao canto (diagonal de 0.5, 0.5)

    return factor; // 0 no centro, 1 nas bordas
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

    vec3 swappedColor = pixel.rgb;

    if (minIndex >= 0 && (threshold <= 0.0 || minDistance < threshold)) {
        swappedColor = newColors[minIndex];
    }

    // Aplicar saturação e brilho
    swappedColor = adjustSaturation(swappedColor, saturation);
    swappedColor = adjustBrightness(swappedColor, brightness);

    // -------- Interpolação entre cor original e nova --------
    float factor = borderFactor(texture_coords);
    pixel.rgb = mix(pixel.rgb, swappedColor, factor);

    return pixel;
}
