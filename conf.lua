GAME_FLAGS = GAME_FLAGS or {
    skipIntro = true,
    logFloorGeneration = false,
    weaponTestLevel = true,
}

function love.conf(t)
    local Levels = require("scripts/config/levels")
    local defaultLevel = Levels:getDefault()

    t.window.title = "mobize"
    t.window.resizable = false
    t.window.vsync = 0
    t.window.width = defaultLevel.window.width
    t.window.height = defaultLevel.window.height
    t.console = GAME_FLAGS.logFloorGeneration

end
