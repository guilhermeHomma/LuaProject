
require "scripts/utils"

Game = require("scripts.managers.gameManager")
love.graphics.setDefaultFilter("nearest", "nearest")

local AmbienceSound = require("scripts/managers/ambienceSound")
local Music = require("scripts/managers/music")
local PauseMenu = require("scripts/managers/menu/pauseMenu")
local GameoverMenu = require("scripts/managers/menu/gameoverMenu")
local MainMenu = require("scripts/managers/menu/mainMenu")
local TransitionManager = require("scripts.managers.transitionManager")

baseWidth = 960
baseHeight = 540
canvas = love.graphics.newCanvas(baseWidth, baseHeight)
STATES = {mainMenu = 1, game = 2, gamePause = 3, gameDead = 4}
state = STATES.mainMenu

--baseWidth = 1120
--baseHeight = 630



DEBUG = false
FPS = false

scale = 1

MUSIC_VOLUME = 0.9
GAME_VOLUME = 1

function love.load()
    --love.window.setMode(0, 0, { fullscreen = true })
    local scaleX = love.graphics.getWidth() / baseWidth
    local scaleY = love.graphics.getHeight() / baseHeight

    local icon = love.image.newImageData("assets/sprites/icon.png")
    --icon:setFilter("nearest", "nearest")
    love.window.setIcon(icon)

    scale = math.max(scaleX, scaleY)
    love.audio.setVolume(GAME_VOLUME)
    MainMenu:load()
    AmbienceSound:load()
    PauseMenu:load()
    Music:load()
    GameoverMenu:load()
    AmbienceSound:startGame()
    TransitionManager:load()
end

function loadGame()
    local function callback()
        state=STATES.game
        Game:load()
        Music:startGame()
    end

    TransitionManager:startTransition(function() callback() end)
end

function playerDeath()
    Music:death()
    state=STATES.gameDead
end

function quitToMenu()
    local function callback()
        Music:closeGame()
        Game:close()
        state=STATES.mainMenu
    end
    TransitionManager:startTransition(function() callback() end, 10, 5)
end

function quitGame()
    local function callback()
        love.event.quit()
    end

    local cb = function() callback() end
    TransitionManager:startTransition(cb, 10, 1.4)
end

function changePause()
    if state == STATES.game or state == STATES.gamePause then
        state = (state == STATES.gamePause) and STATES.game or STATES.gamePause

        local isPaused = state == STATES.gamePause
        Music:changePause(isPaused)

    end
end

function love.keypressed(key)
    
    if TransitionManager.isTransiting then return end

    if key == "escape" or key == "p" then
        changePause()
    end 

    if state == STATES.mainMenu then
        MainMenu:keypressed(key)
    elseif state == STATES.game then
        Game:keypressed(key)
    elseif state == STATES.gamePause then
        PauseMenu:keypressed(key)
    elseif state == STATES.gameDead then
        GameoverMenu:keypressed(key)
    end
    if key == "f5" then
        FPS = not FPS
    end
end

function love.resize(w, h)

    if camera then 
        camera:resize(w, h)
    end

    local scaleX = w / baseWidth
    local scaleY = h / baseHeight

    scale = math.max(scaleX, scaleY)

end

function love.update(dt)

    if state == STATES.game then
        Game:update(dt)
    elseif state == STATES.mainMenu then
        MainMenu:update(dt)
    elseif state == STATES.gamePause then
        PauseMenu:update(dt)
    end

    if state == STATES.gameDead then
        Game:update(dt)
        GameoverMenu:update(dt)

    end
    TransitionManager:update(dt)

    AmbienceSound:update(dt)
    Music:update(dt)
    

end 


function love.draw()

    love.graphics.scale(1, 1)
    love.graphics.clear(0, 0, 0)
    
    love.graphics.setCanvas(canvas)
    
    love.graphics.clear(0.2, 0.3, 0.3)
    

    if state == STATES.game or state == STATES.gamePause or state == STATES.gameDead then
        
        Game:draw()
    end

    if state == STATES.gamePause then
        PauseMenu:draw()
    elseif state == STATES.mainMenu then
        MainMenu:draw()
    elseif state == STATES.gameDead then
        GameoverMenu:draw()

    end

    TransitionManager:draw()

    if FPS or DEBUG then 
        love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 95)
    end

    love.graphics.setCanvas()

    local shader = love.graphics.newShader("scripts/shaders/palette.glsl")

    local paletteList = require("scripts/shaders/paletteList")
    local oldColors = paletteList[1]
    local newColors = paletteList[2]
    shader:send("oldColors", unpack(oldColors))
    shader:send("newColors", unpack(newColors))
    shader:send("threshold", 0.8)
    shader:send("saturation", 1)
    shader:send("brightness", 1.2)

    love.graphics.setShader(shader)
    love.graphics.draw(canvas, 0, 0, 0, scale, scale)
    love.graphics.setShader()
end

