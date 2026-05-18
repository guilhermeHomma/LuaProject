extern vec2 u_sourceResolution;
extern vec2 u_viewportOffset;
extern number u_scale;
extern number u_spotlightEnabled;
extern vec2 u_center;
extern number u_radius;
extern number u_feather;
extern number u_shockwaveCount;
extern vec2 u_shockwaveCenters[8];
extern vec4 u_shockwaveParams[8];

vec2 applyShockwaves(vec2 sourceCoord) {
    vec2 coord = sourceCoord;

    for (int i = 0; i < 8; i++) {
        if (float(i) >= u_shockwaveCount) {
            break;
        }

        vec4 params = u_shockwaveParams[i];
        float progress = clamp(params.x, 0.0, 1.0);
        float radius = params.y * progress;
        float width = max(params.z, 0.001);
        float intensity = params.w;
        vec2 delta = coord - u_shockwaveCenters[i];
        float dist = length(delta);
        float ring = 1.0 - smoothstep(0.0, width, abs(dist - radius));
        float fade = 1.0 - smoothstep(0.15, 1.0, progress);

        if (dist > 0.001) {
            coord -= normalize(delta) * ring * intensity * fade;
        }
    }

    return coord;
}

vec4 effect(vec4 color, Image tex, vec2 texCoord, vec2 screenCoord) {
    vec2 localCoord = screenCoord - u_viewportOffset;

    if (localCoord.x < 0.0 || localCoord.y < 0.0) {
        discard;
    }

    vec2 viewportSize = u_sourceResolution * u_scale;
    if (localCoord.x >= viewportSize.x || localCoord.y >= viewportSize.y) {
        discard;
    }

    vec2 sourceCoord = applyShockwaves(localCoord / u_scale);
    vec2 sourcePixel = floor(sourceCoord);
    sourcePixel = clamp(sourcePixel, vec2(0.0), u_sourceResolution - vec2(1.0));

    vec2 snappedUv = (sourcePixel + vec2(0.5)) / u_sourceResolution;
    vec4 sampled = Texel(tex, snappedUv) * color;

    if (u_spotlightEnabled > 0.5) {
        float d = distance(screenCoord, u_center);
        float alpha = smoothstep(u_radius - u_feather, u_radius, d);
        sampled.rgb = mix(sampled.rgb, vec3(0.0), alpha);
    }

    return sampled;
}
