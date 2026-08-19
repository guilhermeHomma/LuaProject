extern number u_time;
extern number u_intensity;

float hash(vec2 point) {
    return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

float band(vec2 uv, float speed, float width, float offset) {
    float position = fract(u_time * speed + offset);
    float distanceToBand = abs(uv.y - position);
    return 1.0 - smoothstep(width, width * 2.4, distanceToBand);
}

vec4 effect(vec4 color, Image texture, vec2 textureCoords, vec2 screenCoords) {
    vec2 uv = textureCoords;
    vec2 centered = uv * 2.0 - 1.0;

    float curve = 0.018 * u_intensity;
    centered *= 1.0 + dot(centered, centered) * curve;
    uv = centered * 0.5 + 0.5;

    float broadWave = sin((uv.y * 7.0 - u_time * 1.35) * 6.2831853);
    float fineWave = sin((uv.y * 31.0 - u_time * 4.2) * 6.2831853);
    float trackingBand = band(uv, 0.18, 0.026, 0.12);
    float tearingBand = band(uv, 0.31, 0.008, 0.63);
    float lineNoise = hash(vec2(floor(uv.y * 360.0), floor(u_time * 28.0))) - 0.5;

    uv.x += broadWave * 0.0025 * u_intensity;
    uv.x += fineWave * 0.0007 * u_intensity;
    uv.x += trackingBand * (0.009 + lineNoise * 0.006) * u_intensity;
    uv.x += tearingBand * lineNoise * 0.025 * u_intensity;

    if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
        return vec4(0.003, 0.004, 0.005, color.a);
    }

    float chromaticOffset = (0.0007 + trackingBand * 0.0012) * u_intensity;
    vec4 base = Texel(texture, uv);
    float red = Texel(texture, clamp(uv + vec2(chromaticOffset, 0.0), 0.0, 1.0)).r;
    float blue = Texel(texture, clamp(uv - vec2(chromaticOffset, 0.0), 0.0, 1.0)).b;
    vec3 image = vec3(red, base.g, blue);

    float scanline = 0.76 + 0.24 * sin(screenCoords.y * 3.14159265);
    float rollingShade = 1.0 - trackingBand * 0.42;
    float grain = hash(screenCoords + vec2(floor(u_time * 45.0), 0.0)) - 0.5;
    float scratchMoment = step(0.91, hash(vec2(floor(u_time * 0.65), 19.7)));
    float scratchSeed = hash(vec2(floor(screenCoords.x / 4.0), floor(u_time * 1.8)));
    float scratch = scratchMoment * step(0.9985, scratchSeed)
        * (0.035 + 0.055 * hash(vec2(screenCoords.x, floor(u_time * 2.0))));

    image *= mix(1.0, scanline, 0.82 * u_intensity);
    image *= rollingShade;
    image += grain * 0.13 * u_intensity;
    image += scratch * u_intensity;
    image *= 0.84;
    image = clamp(image, vec3(0.0), vec3(1.0));
    return vec4(image, base.a) * color;
}
