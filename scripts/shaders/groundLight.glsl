const int MAX_LIGHTS = 32;
const int MAX_OCCLUDERS = 8;

extern number u_lightCount;
extern vec2 u_lightCenters[MAX_LIGHTS];
extern number u_innerRadii[MAX_LIGHTS];
extern number u_outerRadii[MAX_LIGHTS];
extern number u_maxBrightnesses[MAX_LIGHTS];
extern number u_additiveStrengths[MAX_LIGHTS];
extern number u_generalShadowMinBrightness;
extern vec3 u_generalShadowColor;
extern number u_occluderCount;
extern vec4 u_occluderRects[MAX_OCCLUDERS];
extern number u_occlusionStrength;

float segmentRectIntersection(vec2 startPoint, vec2 endPoint, vec4 rect) {
    vec2 direction = endPoint - startPoint;
    float enter = 0.0;
    float exit = 1.0;

    if (abs(direction.x) < 0.0001) {
        if (startPoint.x < rect.x || startPoint.x > rect.z) {
            return -1.0;
        }
    } else {
        float invX = 1.0 / direction.x;
        float tx1 = (rect.x - startPoint.x) * invX;
        float tx2 = (rect.z - startPoint.x) * invX;
        enter = max(enter, min(tx1, tx2));
        exit = min(exit, max(tx1, tx2));
    }

    if (abs(direction.y) < 0.0001) {
        if (startPoint.y < rect.y || startPoint.y > rect.w) {
            return -1.0;
        }
    } else {
        float invY = 1.0 / direction.y;
        float ty1 = (rect.y - startPoint.y) * invY;
        float ty2 = (rect.w - startPoint.y) * invY;
        enter = max(enter, min(ty1, ty2));
        exit = min(exit, max(ty1, ty2));
    }

    if (exit >= enter) {
        return clamp(enter, 0.0, 1.0);
    }

    return -1.0;
}

float getOcclusion(vec2 lightCenter, vec2 screenCoord) {
    float occlusion = 0.0;

    for (int i = 0; i < MAX_OCCLUDERS; i++) {
        if (float(i) >= u_occluderCount) {
            break;
        }

        float hit = segmentRectIntersection(lightCenter, screenCoord, u_occluderRects[i]);
        if (hit > 0.02) {
            return 1.0;
        }
    }

    return occlusion;
}

vec4 effect(vec4 color, Image tex, vec2 texCoord, vec2 screenCoord) {
    vec4 pixel = Texel(tex, texCoord) * color;
    float brightness = u_generalShadowMinBrightness;
    float additiveBrightness = 0.0;

    if (u_lightCount > 0.0) {
        for (int i = 0; i < MAX_LIGHTS; i++) {
            if (float(i) >= u_lightCount) {
                break;
            }

            float t = smoothstep(u_innerRadii[i], u_outerRadii[i], distance(screenCoord, u_lightCenters[i]));
            float occlusion = 0.0;
            if (i == 0 && u_occluderCount > 0.0) {
                occlusion = getOcclusion(u_lightCenters[i], screenCoord) * u_occlusionStrength;
            }
            float lightBrightness = mix(u_maxBrightnesses[i], u_generalShadowMinBrightness, t);
            lightBrightness = mix(lightBrightness, u_generalShadowMinBrightness, occlusion);
            brightness = max(brightness, lightBrightness);
            additiveBrightness += (1.0 - t) * u_additiveStrengths[i] * (1.0 - occlusion);
        }
    }

    vec3 shadowedColor = pixel.rgb * u_generalShadowColor;
    pixel.rgb = mix(shadowedColor, pixel.rgb, brightness);
    pixel.rgb = min(pixel.rgb + additiveBrightness, vec3(1.0));
    return pixel;
}
