extern number time;
extern number wave_offset;

const vec3 water1 = vec3(0.274, 0.4, 0.451);
const vec3 water2 = vec3(0.227, 0.290, 0.420);
const vec3 highlight = vec3(0.69, 0.80, 0.83);
const vec3 deep = vec3(0.16, 0.22, 0.31);
const float epsilon = 0.01;

bool isWaterColor(vec3 color, vec3 target) {
    return distance(color, target) < epsilon;
}

vec4 effect(vec4 color, Image texture, vec2 texCoord, vec2 screenCoord) {
    vec4 pixel = Texel(texture, texCoord);
    vec3 base = pixel.rgb;

    if (pixel.a <= 0.0) {
        return pixel * color;
    }

    if (isWaterColor(base, water1) || isWaterColor(base, water2)) {
        vec2 pixelCoord = floor(texCoord * vec2(16.0, 16.0));
        float waveA = sin((pixelCoord.x * 0.85) + (time * 2.4) + wave_offset);
        float waveB = sin((pixelCoord.y * 1.15) - (time * 1.8) + wave_offset * 1.7);
        float shimmer = floor((waveA + waveB + 2.0) * 1.25) / 5.0;

        if (base.r > 0.25) {
            base = mix(base, highlight, 0.08 + shimmer * 0.07);
        } else {
            base = mix(base, deep, 0.10 + shimmer * 0.05);
        }

        if (pixelCoord.y <= 3.0 && waveA > 0.45) {
            base = mix(base, highlight, 0.16);
        }

        if (pixelCoord.y >= 11.0 && waveB < -0.35) {
            base = mix(base, deep, 0.12);
        }
    }

    return vec4(base, pixel.a) * color;
}
