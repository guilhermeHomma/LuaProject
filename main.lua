
require "scripts/utils"

Game = require("scripts.managers.gameManager")
love.graphics.setDefaultFilter("nearest", "nearest")

local AmbienceSound = require("scripts/managers/ambienceSound")
local Music = require("scripts/managers/music")
local PauseMenu = require("scripts/managers/menu/pauseMenu")
local GameoverMenu = require("scripts/managers/menu/gameoverMenu")
local MainMenu = require("scripts/managers/menu/mainMenu")


canvas = love.graphics.newCanvas(baseWidth, baseHeight)
STATES = {mainMenu = 1, game = 2, gamePause = 3, gameDead = 4}
state = STATES.mainMenu

--baseWidth = 1120
--baseHeight = 630

baseWidth = 960
baseHeight = 540

baseWidth = 1280
baseHeight = 720

DEBUG = false
FPS = false

scale = 1

MUSIC_VOLUME = 0.9
GAME_VOLUME = 0.9

function love.load()
    --love.window.setMode(0, 0, { fullscreen = true })
    local scaleX = love.graphics.getWidth() / baseWidth
    local scaleY = love.graphics.getHeight() / baseHeight

    scale = math.max(scaleX, scaleY)
    love.audio.setVolume(GAME_VOLUME)
    MainMenu:load()
    AmbienceSound:load()
    PauseMenu:load()
    Music:load()
    GameoverMenu:load()
    AmbienceSound:startGame()
end

function loadGame()
    state=STATES.game
    Game:load()
    
    Music:startGame()
    
end

function playerDeath()
    Music:death()
    state=STATES.gameDead
end

function quitToMenu()
    Music:closeGame()
    Game:close()
    state=STATES.mainMenu
end

function changePause()
    if state == STATES.game or state == STATES.gamePause then
        state = (state == STATES.gamePause) and STATES.game or STATES.gamePause

        local isPaused = state == STATES.gamePause
        Music:changePause(isPaused)

    end
end

function love.keypressed(key)
    
    if key == "escape" then
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

    if FPS or DEBUG then 
        love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 95)
    end

    love.graphics.setCanvas()
    love.graphics.draw(canvas, 0, 0, 0, scale, scale)
end

