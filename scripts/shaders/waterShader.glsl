// water_shader.glsl
extern number time;

const vec3 water1 = vec3(0.274, 0.4, 0.451); // #466673
const vec3 water2 = vec3(0.227, 0.290, 0.420); // #3a4a6b

// pequena margem de tolerância de cor
const float epsilon = 0.01;

bool isWaterColor(vec3 color, vec3 target) {
    return distance(color, target) < epsilon;
}

vec4 effect(vec4 color, Image texture, vec2 texCoord, vec2 screenCoord) {
    vec4 pixel = Texel(texture, texCoord);

    vec3 base = pixel.rgb;

    // Se o pixel for água, aplicar efeito de variação
    if (isWaterColor(base, water1) || isWaterColor(base, water2)) {
        float wave = sin((texCoord.y + time * 0.5) * 30.0) * 0.02;
        float flicker = sin((texCoord.x * 20.0) + time * 2.0) * 0.05;

        // brilho suave na cor
        base += vec3(wave + flicker);
    }

    return vec4(base, pixel.a) * color;
}