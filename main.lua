local Levels = require("scripts/config/levels")
local GameConfig = require("scripts/config/gameConfig")
GameConfig:applyLevel(Levels:getDefault())

require "scripts/utils"

Game = require("scripts.managers.gameManager")
local GameIntro = require("scripts.managers.gameIntro")
love.graphics.setDefaultFilter("nearest", "nearest")
local presentationShader = love.graphics.newShader("scripts/shaders/presentation.glsl")
local menuDistortionShader = love.graphics.newShader("scripts/shaders/hudWater.glsl")
local unpackValues = table.unpack or unpack
local MAX_PRESENTATION_SHOCKWAVES = 8

local AmbienceSound = require("scripts/managers/ambienceSound")
local Music = require("scripts/managers/music")
local Settings = require("scripts/managers/settings")
local PauseMenu = require("scripts/managers/menu/pauseMenu")
local GameoverMenu = require("scripts/managers/menu/gameoverMenu")
local MainMenu = require("scripts/managers/menu/mainMenu")
local SettingsMenu = require("scripts/managers/menu/settingsMenu")
local ConfirmMenu = require("scripts/managers/menu/confirmMenu")
local LogoIntro = require("scripts/managers/menu/logoIntro")
local TransitionManager = require("scripts.managers.transitionManager")

canvas = nil
local menuCanvas = nil
STATES = {mainMenu = 1, game = 2, gamePause = 3, gameDead = 4, gameIntro = 5, startLogo = 6, settings = 7, confirm = 8}
state = STATES.startLogo

DEBUG = false
FPS = false

MUSIC_VOLUME = 0.6
GAME_VOLUME = 0.95
SOUND_VOLUME = 1
GAME_PITCH = 1
SCAPE_INTRO = GAME_FLAGS and GAME_FLAGS.skipIntro or false
local settingsReturnState = STATES.mainMenu
local confirmReturnState = STATES.mainMenu

local function rebuildCanvas()
    canvas = love.graphics.newCanvas(baseWidth, baseHeight)
    canvas:setFilter("nearest", "nearest")
    menuCanvas = love.graphics.newCanvas(baseWidth, baseHeight)
    menuCanvas:setFilter("nearest", "nearest")
end

local function refreshScreenScale()
    GameConfig:updateWindowScale(love.graphics.getWidth(), love.graphics.getHeight())
end

function updateWindowLayout(width, height)
    local windowWidth = width or love.graphics.getWidth()
    local windowHeight = height or love.graphics.getHeight()

    if camera then
        camera:resize(windowWidth, windowHeight)
    end

    GameConfig:updateWindowScale(windowWidth, windowHeight)
end

local function setLevel(levelId)
    local level = Levels:get(levelId)
    GameConfig:applyLevel(level)
    rebuildCanvas()
    updateWindowLayout()
end

local function updateCurrentState(dt)
    if state == STATES.game then
        Game:update(dt)
    elseif state == STATES.mainMenu then
        MainMenu:update(dt)
    elseif state == STATES.gameIntro then
        GameIntro:update(dt)
    elseif state == STATES.startLogo then
        LogoIntro:update(dt)
    elseif state == STATES.gamePause then
        PauseMenu:update(dt)
    elseif state == STATES.gameDead then
        Game:update(dt)
        GameoverMenu:update(dt)
    elseif state == STATES.settings then
        SettingsMenu:update(dt)
    elseif state == STATES.confirm then
        ConfirmMenu:update(dt)
    end
end

local function drawCurrentState()
    if state == STATES.game or state == STATES.gamePause or state == STATES.gameDead then
        Game:draw()
    end
end

local function isGameplayState()
    return state == STATES.game or state == STATES.gamePause or state == STATES.gameDead
end

local function shouldDrawHUD()
    return isGameplayState()
        and CURRENT_LEVEL ~= nil
        and CURRENT_LEVEL.id == "default"
        and Player ~= nil
        and Player.isAlive ~= nil
end

local function isMenuState()
    return state == STATES.mainMenu
        or state == STATES.gamePause
        or state == STATES.gameDead
        or state == STATES.settings
        or state == STATES.confirm
end

local function drawScaledState()
    if state == STATES.startLogo then
        LogoIntro:draw()
    elseif state == STATES.mainMenu then
        MainMenu:draw()
    elseif state == STATES.gameIntro then
        GameIntro:draw()
    elseif state == STATES.settings then
        SettingsMenu:draw()
    elseif state == STATES.gamePause then
        PauseMenu:draw()
    elseif state == STATES.gameDead then
        GameoverMenu:draw()
    elseif state == STATES.confirm then
        ConfirmMenu:draw()
    end
end

local function drawMenuWithDistortion()
    love.graphics.setCanvas(menuCanvas)
    love.graphics.clear(0, 0, 0, 0)
    drawScaledState()

    love.graphics.setCanvas(canvas)
    menuDistortionShader:send("u_time", love.timer.getTime())
    menuDistortionShader:send("u_strength", 0.00055)
    love.graphics.setShader(menuDistortionShader)
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(menuCanvas, 0, 0)
    love.graphics.setShader()
end

local function presentCanvas()
    presentationShader:send("u_sourceResolution", {baseWidth, baseHeight})
    presentationShader:send("u_viewportOffset", {viewportOffsetX, viewportOffsetY})
    presentationShader:send("u_scale", scale)

    local spotlightEnabled = 0
    if state == STATES.game and Game.spot and Game.spot.enabled and camera then
        local px, py = camera:getTargetScreenPosition()
        presentationShader:send("u_center", {px, py - 38 * scale})
        presentationShader:send("u_radius", Game.spot.radius * scale)
        presentationShader:send("u_feather", Game.spot.feather)
        spotlightEnabled = 1
    else
        presentationShader:send("u_center", {0, 0})
        presentationShader:send("u_radius", 0)
        presentationShader:send("u_feather", 0)
    end

    presentationShader:send("u_spotlightEnabled", spotlightEnabled)

    local shockwaveCenters = {}
    local shockwaveParams = {}
    local shockwaveCount = 0

    if isGameplayState() and Game and Game.getWeaponShockwaves and camera then
        for _, wave in ipairs(Game:getWeaponShockwaves()) do
            if shockwaveCount >= MAX_PRESENTATION_SHOCKWAVES then
                break
            end

            local duration = math.max(wave.duration or 0.28, 0.001)
            local progress = math.min(math.max((wave.timer or 0) / duration, 0), 1)
            local screenX, screenY = camera:worldToScreen(wave.x, wave.y)

            shockwaveCount = shockwaveCount + 1
            shockwaveCenters[shockwaveCount] = {
                (screenX - viewportOffsetX) / scale,
                (screenY - viewportOffsetY) / scale,
            }
            shockwaveParams[shockwaveCount] = {
                progress,
                wave.radius or 34,
                wave.width or 7,
                wave.intensity or 2.2,
            }
        end
    end

    for i = shockwaveCount + 1, MAX_PRESENTATION_SHOCKWAVES do
        shockwaveCenters[i] = {0, 0}
        shockwaveParams[i] = {1, 0, 1, 0}
    end

    presentationShader:send("u_shockwaveCount", shockwaveCount)
    presentationShader:send("u_shockwaveCenters", unpackValues(shockwaveCenters, 1, MAX_PRESENTATION_SHOCKWAVES))
    presentationShader:send("u_shockwaveParams", unpackValues(shockwaveParams, 1, MAX_PRESENTATION_SHOCKWAVES))

    love.graphics.setShader(presentationShader)
    love.graphics.draw(canvas, viewportOffsetX, viewportOffsetY, 0, scale, scale)
    love.graphics.setShader()
end

function love.load()
    rebuildCanvas()
    refreshScreenScale()

    local icon = love.image.newImageData("assets/sprites/icon.png")
    love.window.setIcon(icon)
    Settings:load()
    LogoIntro:load()
    MainMenu:load()

    AmbienceSound:load()
    PauseMenu:load()
    Music:load()
    GameoverMenu:load()
    SettingsMenu:load()
    ConfirmMenu:load()
    AmbienceSound:startGame()
    TransitionManager:load()
    
    if SCAPE_INTRO then
        setLevel("default")
        state = STATES.game
        Game:load()
        Music:startGame()
    end
    --loadIntro()
end

function loadIntro(levelId)
    local function callback()
        setLevel(levelId or "intro")
        state = STATES.gameIntro
        GameIntro:load()
    end

    TransitionManager:startTransition(function() callback() end)
end


function loadGame(levelId)
    local function callback()
        setLevel(levelId or "default")
        state = STATES.game
        Game:load()
        Music:startGame()
    end

    TransitionManager:startTransition(function() callback() end)
end

function openSettings(returnState)
    settingsReturnState = returnState or STATES.mainMenu
    SettingsMenu.selectedOption = 1
    SettingsMenu.mouseNeedsSync = true
    state = STATES.settings
end

function closeSettings()
    state = settingsReturnState or STATES.mainMenu
end

function openReturnToMenuConfirm(returnState)
    confirmReturnState = returnState or STATES.gamePause
    ConfirmMenu:open("MAIN MENU", "return to main menu?", function()
        quitToMenu()
    end)
    state = STATES.confirm
end

function openQuitGameConfirm(returnState)
    confirmReturnState = returnState or STATES.mainMenu
    ConfirmMenu:open("EXIT GAME", "quit the game?", function()
        quitGame()
    end)
    state = STATES.confirm
end

function closeConfirmMenu()
    state = confirmReturnState or STATES.mainMenu
end

function playerDeath()
    Music:death()
    state=STATES.gameDead
end

local function pauseGameOnBackground()
    if state ~= STATES.game then
        return
    end

    state = STATES.gamePause
    Music:changePause(true)
end

function quitToMenu()
    local function callback()
        setLevel("menu")
        Music:closeGame()
        Game:close()
        state = STATES.mainMenu
    end
    TransitionManager:startTransition(function() callback() end, 14, 3)
end

function quitGame()
    local function callback()
        love.event.quit()
    end

    local cb = function() callback() end
    TransitionManager:startTransition(cb, 10, 1.4)
end

function fullscreen()
    Settings:toggleFullscreen()
end

function addToDrawQueue(priority, object, checkDistance)
    if checkDistance == nil then
        checkDistance = true
    end

    if checkDistance == false then
        if STATES.gameIntro == state then
            table.insert(GameIntro.drawQueue, {priority = priority, object = object})
        else
            table.insert(Game.drawQueue, {priority = priority, object = object})
        end
        return
    end

    local cameraDistance = distance(camera:objectPosition(), object)

    if cameraDistance > RENDER_DISTANCE then
        return
    end

    if cameraDistance > HARD_RENDER_DISTANCE then
        return
    end

    if STATES.gameIntro == state then
        table.insert(GameIntro.drawQueue, {priority = priority, object = object})
    else
        table.insert(Game.drawQueue, {priority = priority, object = object})
    end
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

    if (key == "escape" or key == "p") and (state == STATES.game or state == STATES.gamePause) then
        changePause()
        return
    end 

    if key == "f11" then
        --fullscreen()
    end

    if state == STATES.mainMenu then
        MainMenu:keypressed(key)
    elseif state == STATES.game then
        Game:keypressed(key)
    elseif state == STATES.gamePause then
        PauseMenu:keypressed(key)
    elseif state == STATES.gameDead then
        GameoverMenu:keypressed(key)
    elseif state == STATES.settings then
        SettingsMenu:keypressed(key)
    elseif state == STATES.confirm then
        ConfirmMenu:keypressed(key)
    end
    if key == "f5" then
        FPS = not FPS
    end
end

function love.mousepressed(x, y, button)
    if TransitionManager.isTransiting then return end

    local scaledX = (x - viewportOffsetX) / scale
    local scaledY = (y - viewportOffsetY) / scale

    if state == STATES.mainMenu then
        MainMenu:mousepressed(scaledX, scaledY, button)
    elseif state == STATES.game then
        Game:mousepressed(scaledX, scaledY, button)
    elseif state == STATES.gamePause then
        PauseMenu:mousepressed(scaledX, scaledY, button)
    elseif state == STATES.gameDead then
        GameoverMenu:mousepressed(scaledX, scaledY, button)
    elseif state == STATES.settings then
        SettingsMenu:mousepressed(scaledX, scaledY, button)
    elseif state == STATES.confirm then
        ConfirmMenu:mousepressed(scaledX, scaledY, button)
    end
end

function love.resize(w, h)
    updateWindowLayout(w, h)
end

function love.focus(focused)
    if not focused then
        pauseGameOnBackground()
    end
end

function love.visible(visible)
    if not visible then
        pauseGameOnBackground()
    end
end

function love.update(dt)
    updateCurrentState(dt)
    TransitionManager:update(dt)
    AmbienceSound:update(dt)
    Music:update(dt)
end 


function love.draw()
    love.graphics.clear(0, 0, 0)

    love.graphics.setCanvas(canvas)
    love.graphics.clear(0.2, 0.3, 0.3)
    drawCurrentState()
    if isGameplayState() then
        Game:drawHUD()
    end
    if isMenuState() then
        drawMenuWithDistortion()
    else
        drawScaledState()
    end
    love.graphics.setCanvas()

    presentCanvas()

    if (FPS or DEBUG) and state == STATES.game then
        love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 295)
    end

    TransitionManager:drawFullscreen()
end
