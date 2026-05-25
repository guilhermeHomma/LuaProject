GAME_FLAGS = GAME_FLAGS or {
    skipIntro = true,
    logFloorGeneration = false,
    weaponTestLevel = false,
    cameraShake = true,
    vsync = false,
    crt = {
        enabled = true,
        intensity = 0.7,
        scanline = 0.22,
        curvature = 0.01,
        vignette = 0.35,
        chromatic = 0.8,
    },
}

function love.conf(t)
    local Levels = require("scripts/config/levels")
    local SettingsStorage = require("scripts/managers/settingsStorage")
    local defaultLevel = Levels:getDefault()
    local savedSettings = SettingsStorage:loadSaved()
    local savedWidth = savedSettings and tonumber(savedSettings.w)
    local savedHeight = savedSettings and tonumber(savedSettings.h)

    t.identity = "mobize"
    t.window.title = "mobize"
    t.window.resizable = false
    if savedSettings then
        t.window.vsync = savedSettings.vs == "1" and 1 or 0
        t.window.fullscreen = savedSettings.fs == "1"
    else
        t.window.vsync = GAME_FLAGS.vsync and 1 or 0
        t.window.fullscreen = false
    end
    t.window.fullscreentype = "desktop"
    t.window.width = savedWidth or defaultLevel.window.width
    t.window.height = savedHeight or defaultLevel.window.height
    t.console = GAME_FLAGS.logFloorGeneration

end
