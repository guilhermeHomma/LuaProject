local function mergeDefaults(defaults, overrides)
    local result = {}

    for key, value in pairs(defaults or {}) do
        if type(value) == "table" then
            result[key] = mergeDefaults(value, nil)
        else
            result[key] = value
        end
    end

    for key, value in pairs(overrides or {}) do
        if type(value) == "table" and type(result[key]) == "table" then
            result[key] = mergeDefaults(result[key], value)
        else
            result[key] = value
        end
    end

    return result
end

local DEFAULT_GAME_FLAGS = {
    skipIntro = false,
    log = false,
    logFloorGeneration = false,
    weaponTestLevel = false,
    experimentalZombieStressTest = false,
    cameraShake = true,
    brightness = 5,
    vsync = false,
    performanceOverlay = false,
    crt = {
        enabled = true,
        intensity = 0.9,
        scanline = 0.45,
        curvature = 0.005,
        vignette = 0.5,
        chromatic = 0.86,
        fast = true,
    },
    levelTest = {
        enabled = false,
        floorId = 1,
        rooms = {
            batalha = 0,
            endroom = 1,
            lojas = 0,
            cards = 0,
        },
    },
}

GAME_FLAGS = mergeDefaults(DEFAULT_GAME_FLAGS, GAME_FLAGS)
GAME_FLAGS.logFloorGeneration = GAME_FLAGS.logFloorGeneration or GAME_FLAGS.log == true

GAME_VERSION = "0.1.16a"

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
        t.window.fullscreen = true
    end
    t.window.fullscreentype = "desktop"
    t.window.width = savedWidth or defaultLevel.window.width
    t.window.height = savedHeight or defaultLevel.window.height
    t.console = GAME_FLAGS.logFloorGeneration

end
