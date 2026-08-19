extern number u_time;
extern vec2 u_frameXBounds;

vec4 effect(vec4 color, Image texture, vec2 textureCoords, vec2 screenCoords)
{
    vec2 uv = textureCoords;
    float horizontalWave = sin(screenCoords.y * 0.075 + u_time * 2.1) * 0.0008;
    float verticalWave = sin(screenCoords.x * 0.045 - u_time * 1.35) * 0.0015;

    uv.x = clamp(uv.x + horizontalWave, u_frameXBounds.x, u_frameXBounds.y);
    uv.y = clamp(uv.y + verticalWave, 0.0, 1.0);
    return Texel(texture, uv) * color;
}
