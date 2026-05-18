extern vec2 u_resolution;
extern number u_intensity;
extern number u_edgeBrightness;

vec4 effect(vec4 color, Image tex, vec2 texCoord, vec2 screenCoord) {
    vec2 uv = screenCoord / u_resolution;
    vec2 centered = uv - vec2(0.5);
    centered.x *= u_resolution.x / u_resolution.y;

    float radius = length(centered);
    float t = smoothstep(0.25, 0.72, radius);
    float brightness = mix(1.0, u_edgeBrightness, t);
    float alpha = (1.0 - brightness) * u_intensity;

    return vec4(0.18, 0.055, 0.055, alpha) * color;
}
