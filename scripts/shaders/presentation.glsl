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
extern number u_crtEnabled;
extern number u_crtIntensity;
extern number u_crtScanline;
extern number u_crtCurvature;
extern number u_crtVignette;
extern number u_crtChromatic;

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

vec2 applyCrtCurve(vec2 uv) {
    vec2 centered = uv * 2.0 - 1.0;
    float amount = u_crtCurvature * u_crtIntensity;
    vec2 offset = centered.yx * centered.yx * amount;
    centered += centered * offset;
    return centered * 0.5 + 0.5;
}

vec4 samplePixel(Image tex, vec2 sourceCoord, vec4 color) {
    vec2 sourcePixel = floor(sourceCoord);
    sourcePixel = clamp(sourcePixel, vec2(0.0), u_sourceResolution - vec2(1.0));
    vec2 snappedUv = (sourcePixel + vec2(0.5)) / u_sourceResolution;
    return Texel(tex, snappedUv) * color;
}

vec4 applyCrtLook(Image tex, vec2 sourceCoord, vec2 localCoord, vec4 color) {
    float chroma = u_crtChromatic * u_crtIntensity;
    vec4 base = samplePixel(tex, sourceCoord, color);
    vec4 shiftedR = samplePixel(tex, sourceCoord + vec2(chroma, 0.0), color);
    vec4 shiftedB = samplePixel(tex, sourceCoord - vec2(chroma, 0.0), color);
    vec4 sampled = vec4(shiftedR.r, base.g, shiftedB.b, base.a);

    float scan = 0.5 + 0.5 * sin(localCoord.y * 3.14159265);
    float scanDarken = 1.0 - u_crtScanline * u_crtIntensity * (1.0 - scan);
    sampled.rgb *= scanDarken;

    vec2 uv = localCoord / (u_sourceResolution * u_scale);
    float dist = distance(uv, vec2(0.5));
    float vignette = 1.0 - smoothstep(0.36, 0.78, dist) * u_crtVignette * u_crtIntensity;
    sampled.rgb *= vignette;

    sampled.rgb *= 1.0 + 0.035 * u_crtIntensity;
    return sampled;
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

    vec2 crtLocalCoord = localCoord;
    if (u_crtEnabled > 0.5) {
        vec2 curvedUv = applyCrtCurve(localCoord / viewportSize);
        if (curvedUv.x < 0.0 || curvedUv.y < 0.0 || curvedUv.x > 1.0 || curvedUv.y > 1.0) {
            discard;
        }
        crtLocalCoord = curvedUv * viewportSize;
    }

    vec2 sourceCoord = applyShockwaves(crtLocalCoord / u_scale);
    vec4 sampled = u_crtEnabled > 0.5
        ? applyCrtLook(tex, sourceCoord, localCoord, color)
        : samplePixel(tex, sourceCoord, color);

    if (u_spotlightEnabled > 0.5) {
        float d = distance(screenCoord, u_center);
        float alpha = smoothstep(u_radius - u_feather, u_radius, d);
        sampled.rgb = mix(sampled.rgb, vec3(0.0), alpha);
    }

    return sampled;
}
