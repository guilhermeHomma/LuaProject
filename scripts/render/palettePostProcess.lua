local mode = GAME_FLAGS and GAME_FLAGS.globalPaletteMode or "list"

if mode == "colorWheel42" then
    return require("scripts.render.colorWheelPalette")
end

return require("scripts.render.globalPalette")
