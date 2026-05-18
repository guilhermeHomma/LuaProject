    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
    {
        // Pega o alpha da textura original
        float alpha = Texel(texture, texture_coords).a;
        
        // Retorna branco com o mesmo alpha
        return vec4(1.0, 1.0, 1.0, alpha);
    }
