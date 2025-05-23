    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
    {
        // Pega o alpha da textura original
        float alpha = Texel(texture, texture_coords).a;
        
        // Retorna branco com o mesmo alpha
        return vec4(0.95, 0.97, 0.96, alpha);
    }