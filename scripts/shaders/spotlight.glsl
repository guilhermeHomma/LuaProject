extern vec2 u_center;   // centro do círculo em coordenadas de TELA
extern float u_radius;  // raio atual (px)
extern float u_feather; // suavização da borda (px)

vec4 effect(vec4 color, Image tex, vec2 texCoord, vec2 screenCoord) {
    vec4 c = Texel(tex, texCoord) * color;

    float d = distance(screenCoord, u_center);

    float alpha = smoothstep(u_radius - u_feather, u_radius, d);

    vec3 rgb = mix(c.rgb, vec3(0.0), alpha);
    return vec4(rgb, c.a);
}
