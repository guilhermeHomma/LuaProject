// Outline branco de 1 texel em volta da parte opaca da textura/quad
extern vec2 u_texel;           // 1.0 / (largura_textura, altura_textura)
extern vec4 u_outlineColor;    // cor do contorno (ex.: branco)
extern float u_threshold;      // limiar de alfa para considerar “opaco” (0.1 ~ 0.3)

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec4 base = Texel(tex, uv) * color;

    // Se o pixel já é opaco, mantém a arte original:
    if (base.a > u_threshold) {
        return base;
    }

    // Offsets de 8 vizinhos (1 texel)
    vec2 o[8];
    o[0] = vec2(-u_texel.x,  0.0);
    o[1] = vec2( u_texel.x,  0.0);
    o[2] = vec2( 0.0,       -u_texel.y);
    o[3] = vec2( 0.0,        u_texel.y);
    o[4] = vec2(-u_texel.x, -u_texel.y);
    o[5] = vec2( u_texel.x, -u_texel.y);
    o[6] = vec2(-u_texel.x,  u_texel.y);
    o[7] = vec2( u_texel.x,  u_texel.y);

    // Se qualquer vizinho for opaco, pinta contorno:
    for (int i = 0; i < 8; i++) {
        float a = Texel(tex, uv + o[i]).a;
        if (a > u_threshold) {
            return vec4(u_outlineColor.rgb, 1.0);
        }
    }

    // Caso contrário, permanece transparente
    return base;
}
