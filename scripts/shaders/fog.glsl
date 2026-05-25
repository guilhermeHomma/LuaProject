extern number time;
extern vec2 resolution;
extern number intensity;
extern vec3 fogColor;
extern number scale;
extern number speed;
extern number verticalStrength;
extern number alpha;
extern vec2 drift;

float rand(vec2 co) {
    return fract(sin(dot(co.xy, vec2(12.9898,78.233))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);

    float a = rand(i);
    float b = rand(i + vec2(1.0, 0.0));
    float c = rand(i + vec2(0.0, 1.0));
    float d = rand(i + vec2(1.0, 1.0));

    vec2 u = f * f * (3.0 - 2.0 * f);

    return mix(a, b, u.x)
         + (c - a) * u.y * (1.0 - u.x)
         + (d - b) * u.x * u.y;
}

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec2 uv = screen_coords / resolution;

    float fogScale = max(scale, 0.001);
    float fogSpeed = speed;
    vec2 flow = drift * time * fogSpeed;
    float n1 = noise(uv * fogScale + flow + vec2(time * 0.05 * fogSpeed, 0.0));
    float n2 = noise(uv * fogScale * 2.1 + flow * 1.7 + vec2(time * 0.08 * fogSpeed, time * 0.03 * fogSpeed));
    float n3 = noise(vec2(uv.x * fogScale * 0.65 - time * 0.025 * fogSpeed, uv.y * fogScale * 1.3) + flow * 0.8);
    float n = (n1 * 0.7 + n2 * 0.3);

    float bands = smoothstep(0.18, 0.88, n3);
    float verticalFade = mix(1.0, smoothstep(0.02, 0.95, uv.y), verticalStrength);
    float fog = smoothstep(0.34, 0.86, n) * bands * verticalFade * intensity;

    return vec4(fogColor, fog * alpha) * color;
}
