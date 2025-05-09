
require "scripts/utils"

Game = require("scripts.managers.gameManager")
love.graphics.setDefaultFilter("nearest", "nearest")

local AmbienceSound = require("scripts/managers/ambienceSound")
local Music = require("scripts/managers/music")
local menuPause = require("scripts/managers/menuPause")
local MainMenu = require("scripts/managers/mainMenu")


canvas = love.graphics.newCanvas(baseWidth, baseHeight)
STATES = {mainMenu = 1, game = 2, gamePause = 3, gameDead = 4}
state = STATES.mainMenu

baseWidth = 1120
baseHeight = 630

DEBUG = false
FPS = false

scale = 1

function love.load()
    --

    local scaleX = love.graphics.getWidth() / baseWidth
    local scaleY = love.graphics.getHeight() / baseHeight

    scale = math.max(scaleX, scaleY)

    
    MainMenu:load()
    AmbienceSound:load()
    menuPause:load()
    Music:load()
end

function loadGame()
    state=STATES.game
    Game:load()
    AmbienceSound:startGame()
    Music:startGame()
    
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
        menuPause:keypressed(key)
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
        menuPause:update(dt)
    end

    AmbienceSound:update(dt)
    Music:update(dt)
    

end 


function love.draw()

    love.graphics.scale(1, 1)
    love.graphics.clear(0, 0, 0)
    
    love.graphics.setCanvas(canvas)
    
    love.graphics.clear(0.2, 0.3, 0.3)
    

    if state == STATES.game or state == STATES.gamePause then
        Game:draw()
    end

    if state == STATES.gamePause then
        menuPause:draw()
    elseif state == STATES.mainMenu then
        MainMenu:draw()
    end

    if FPS or DEBUG then 
        love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 60)
    end

    love.graphics.setCanvas()
    love.graphics.draw(canvas, 0, 0, 0, scale, scale)
end

