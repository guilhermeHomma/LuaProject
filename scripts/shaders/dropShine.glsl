extern float u_time;
extern vec2 u_uvMin;
extern vec2 u_uvMax;

const float SHINE_INTERVAL = 2.0;
const float SHINE_DURATION = 0.55;
const float SHINE_WIDTH = 0.10;

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screenCoord) {
    vec4 base = Texel(tex, uv) * color;

    if (base.a <= 0.0) {
        return base;
    }

    float cycleTime = mod(u_time, SHINE_INTERVAL);
    if (cycleTime > SHINE_DURATION) {
        return base;
    }

    vec2 localUv = (uv - u_uvMin) / (u_uvMax - u_uvMin);
    float progress = cycleTime / SHINE_DURATION;
    float position = mix(-0.35, 2.35, progress);
    float lineDistance = abs((localUv.x + localUv.y) - position);
    float shine = 1.0 - smoothstep(0.0, SHINE_WIDTH, lineDistance);

    base.rgb = mix(base.rgb, vec3(1.0), shine);
    base.rgb += vec3(0.32) * shine;
    base.rgb = min(base.rgb, vec3(1.0));
    return base;
}
