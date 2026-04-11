extern number time;
extern vec2 resolution;
extern number intensity;

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

    float n1 = noise(uv * 3.0 + vec2(time * 0.05, 0.0));
    float n2 = noise(uv * 6.0 + vec2(time * 0.08, time * 0.03));
    float n = (n1 * 0.7 + n2 * 0.3);

    float fog = smoothstep(0.35, 0.85, n) * intensity;

    vec3 fogColor = vec3(0.75, 0.78, 0.82);

    return vec4(fogColor, fog * 0.35);
}