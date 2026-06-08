local Levels = require("scripts/config/levels")
local GameConfig = require("scripts/config/gameConfig")
local Fonts = require("scripts/ui/fonts")
GameConfig:applyLevel(Levels:getDefault())

require "scripts/utils"

Game = require("scripts.managers.gameManager")
local GameIntro = require("scripts.managers.gameIntro")
love.graphics.setDefaultFilter("nearest", "nearest")
local presentationShader = love.graphics.newShader("scripts/shaders/presentation.glsl")
local menuDistortionShader = love.graphics.newShader("scripts/shaders/hudWater.glsl")
local fpsFont = Fonts:translated("fps")
local unpackValues = table.unpack or unpack
local MAX_PRESENTATION_SHOCKWAVES = 8
PERF = PERF or {}
local presentationShockwaveCenters = {}
local presentationShockwaveParams = {}
local zeroVec2 = {0, 0}

for i = 1, MAX_PRESENTATION_SHOCKWAVES do
    presentationShockwaveCenters[i] = {0, 0}
    presentationShockwaveParams[i] = {1, 0, 1, 0}
end

fpsFont:setLineHeight(1)

local AmbienceSound = require("scripts/managers/ambienceSound")
local Music = require("scripts/managers/music")
local Settings = require("scripts/managers/settings")
local Localization = require("scripts/managers/localization")
local PauseMenu = require("scripts/managers/menu/pauseMenu")
local GameoverMenu = require("scripts/managers/menu/gameoverMenu")
local MainMenu = require("scripts/managers/menu/mainMenu")
local SettingsMenu = require("scripts/managers/menu/settingsMenu")
local ConfirmMenu = require("scripts/managers/menu/confirmMenu")
local LogoIntro = require("scripts/managers/menu/logoIntro")
local TransitionManager = require("scripts.managers.transitionManager")
local RoomScreenTransition = require("scripts/managers/roomScreenTransition")
local AudioDeviceSync = require("scripts/managers/audioDeviceSync")

canvas = nil
local menuCanvas = nil
local fixedLayerCanvas = nil
STATES = {mainMenu = 1, game = 2, gamePause = 3, gameDead = 4, gameIntro = 5, startLogo = 6, settings = 7, confirm = 8, floorIntro = 9}
state = STATES.startLogo

DEBUG = false
FPS = false
PERF.enabled = false

MUSIC_VOLUME = 0.7
GAME_VOLUME = 1
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
    fixedLayerCanvas = love.graphics.newCanvas(baseWidth, baseHeight)
    fixedLayerCanvas:setFilter("nearest", "nearest")
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

local function getGameplayLevelId()
    if GAME_FLAGS and GAME_FLAGS.experimentalZombieStressTest == true then
        return "zombieStressTest"
    end

    return "default"
end

local function updateCurrentState(dt)
    if state == STATES.game then
        Game:update(dt)
    elseif state == STATES.floorIntro then
        Game:updateFloorIntroState(dt)
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
    elseif state == STATES.floorIntro then
        Game:drawFloorIntro()
        Game:drawThanksScreen()
    end
end

local function drawMenuWithDistortion(targetCanvas)
    love.graphics.setCanvas(menuCanvas)
    love.graphics.clear(0, 0, 0, 0)
    drawScaledState()

    love.graphics.setCanvas({targetCanvas or canvas, stencil = true})
    menuDistortionShader:send("u_time", love.timer.getTime())
    menuDistortionShader:send("u_strength", 0.00055)
    love.graphics.setShader(menuDistortionShader)
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(menuCanvas, 0, 0)
    love.graphics.setShader()
end

local function presentCanvas(sourceCanvas, useRoomTransition)
    sourceCanvas = sourceCanvas or canvas
    if useRoomTransition == nil then
        useRoomTransition = true
    end

    local crtConfig = GAME_FLAGS and GAME_FLAGS.crt or {}
    local crtEnabled = crtConfig.enabled == true
    local brightness = math.min(math.max(tonumber(GAME_FLAGS and GAME_FLAGS.brightness) or 5, 0), 10)
    local brightnessNeutral = math.abs(brightness - 5) < 0.001

    local spotlightEnabled = 0
    if state == STATES.game and Game.spot and Game.spot.enabled and camera then
        local px, py = camera:getTargetScreenPosition()
        zeroVec2[1], zeroVec2[2] = px, py - 38 * scale
        spotlightEnabled = 1
    end

    local shockwaveCenters = presentationShockwaveCenters
    local shockwaveParams = presentationShockwaveParams
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
            local center = shockwaveCenters[shockwaveCount]
            center[1] = (screenX - viewportOffsetX) / scale
            center[2] = (screenY - viewportOffsetY) / scale

            local params = shockwaveParams[shockwaveCount]
            params[1] = progress
            params[2] = wave.radius or 34
            params[3] = wave.width or 7
            params[4] = wave.intensity or 2.2
        end
    end

    for i = shockwaveCount + 1, MAX_PRESENTATION_SHOCKWAVES do
        local center = shockwaveCenters[i]
        center[1], center[2] = 0, 0
        local params = shockwaveParams[i]
        params[1], params[2], params[3], params[4] = 1, 0, 1, 0
    end

    local presentationCanvas = useRoomTransition
        and RoomScreenTransition:getPresentationCanvas(sourceCanvas)
        or sourceCanvas

    if not crtEnabled and spotlightEnabled == 0 and shockwaveCount == 0 and brightnessNeutral then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(presentationCanvas, viewportOffsetX, viewportOffsetY, 0, scale, scale)
        return
    end

    presentationShader:send("u_sourceResolution", {baseWidth, baseHeight})
    presentationShader:send("u_viewportOffset", {viewportOffsetX, viewportOffsetY})
    presentationShader:send("u_scale", scale)
    presentationShader:send("u_crtEnabled", crtEnabled and 1 or 0)
    presentationShader:send("u_crtIntensity", crtConfig.intensity or 0.55)
    presentationShader:send("u_crtScanline", crtConfig.scanline or 0.18)
    presentationShader:send("u_crtCurvature", crtConfig.curvature or 0.055)
    presentationShader:send("u_crtVignette", crtConfig.vignette or 0.22)
    presentationShader:send("u_crtChromatic", crtConfig.chromatic or 0.55)
    presentationShader:send("u_brightness", brightness)
    presentationShader:send("u_center", zeroVec2)
    presentationShader:send("u_radius", spotlightEnabled == 1 and Game.spot.radius * scale or 0)
    presentationShader:send("u_feather", spotlightEnabled == 1 and Game.spot.feather or 0)
    presentationShader:send("u_spotlightEnabled", spotlightEnabled)
    presentationShader:send("u_shockwaveCount", shockwaveCount)
    presentationShader:send("u_shockwaveCenters", unpackValues(shockwaveCenters, 1, MAX_PRESENTATION_SHOCKWAVES))
    presentationShader:send("u_shockwaveParams", unpackValues(shockwaveParams, 1, MAX_PRESENTATION_SHOCKWAVES))

    love.graphics.setShader(presentationShader)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(presentationCanvas, viewportOffsetX, viewportOffsetY, 0, scale, scale)
    love.graphics.setShader()
end

local function drawFixedRoomLayer()
    if not fixedLayerCanvas then
        return
    end

    love.graphics.setCanvas({fixedLayerCanvas, stencil = true})
    love.graphics.clear(0, 0, 0, 0)

    if isGameplayState() then
        Game:drawHUD()
    end

    if isMenuState() then
        drawMenuWithDistortion(fixedLayerCanvas)
    else
        drawScaledState()
    end

    love.graphics.setCanvas()
    presentCanvas(fixedLayerCanvas, false)
end

local function drawRoomTransitionFade()
    local alpha = RoomScreenTransition:getFadeAlpha()
    if alpha <= 0 then
        return
    end

    love.graphics.setShader()
    love.graphics.setColor(0, 0, 0, alpha)
    love.graphics.rectangle("fill", viewportOffsetX, viewportOffsetY, baseWidth * scale, baseHeight * scale)
    love.graphics.setColor(1, 1, 1, 1)
end

function love.load()
    rebuildCanvas()
    refreshScreenScale()

    local icon = love.image.newImageData("assets/sprites/icon.png")
    love.window.setIcon(icon)
    Settings:load()
    AudioDeviceSync:refresh(false)
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
        local levelId = getGameplayLevelId()
        setLevel(levelId)
        if levelId == "zombieStressTest" then
            state = STATES.game
            Game:load({ startFloorIntro = false })
            Music:startGame()
        else
            state = STATES.floorIntro
            Game:load({
                onFloorIntroComplete = function()
                    state = STATES.game
                    Music:startGame()
                end,
            })
        end
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
        local resolvedLevelId = levelId or getGameplayLevelId()
        setLevel(resolvedLevelId)
        if resolvedLevelId == "zombieStressTest" then
            state = STATES.game
            Game:load({ startFloorIntro = false })
            Music:startGame()
        else
            state = STATES.floorIntro
            Game:load({
                onFloorIntroComplete = function()
                    state = STATES.game
                    Music:startGame()
                end,
            })
        end
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
    ConfirmMenu:open("menu.main_menu", "confirm.return_menu", function()
        quitToMenu()
    end)
    state = STATES.confirm
end

function openRestartConfirm(returnState)
    confirmReturnState = returnState or STATES.gamePause
    ConfirmMenu:open("menu.new_run", "confirm.restart", function()
        loadGame()
    end)
    state = STATES.confirm
end

function openQuitGameConfirm(returnState)
    confirmReturnState = returnState or STATES.mainMenu
    ConfirmMenu:open("menu.exit_game", "confirm.quit", function()
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

function quitToMenuImmediate()
    setLevel("menu")
    Music:closeGame()
    Game:close()
    state = STATES.mainMenu
    if TransitionManager then
        TransitionManager.alpha = 0
        TransitionManager.targetAlpha = 0
        TransitionManager.callback = nil
        TransitionManager.isTransiting = false
        TransitionManager.targetDistortion = 0
        TransitionManager.distortion = 0
    end
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
            GameIntro.drawQueuePool = GameIntro.drawQueuePool or {}
            local index = #GameIntro.drawQueue + 1
            local entry = GameIntro.drawQueuePool[index] or {}
            GameIntro.drawQueuePool[index] = entry
            entry.priority = priority
            entry.object = object
            GameIntro.drawQueue[index] = entry
        else
            Game.drawQueuePool = Game.drawQueuePool or {}
            local index = #Game.drawQueue + 1
            local entry = Game.drawQueuePool[index] or {}
            Game.drawQueuePool[index] = entry
            entry.priority = priority
            entry.object = object
            Game.drawQueue[index] = entry
        end
        return
    end

    local cameraPosition = camera:objectPosition()
    local objectX = object and (object.xWorld or object.x)
    local objectY = object and (object.yWorld or object.y)

    if not (cameraPosition and objectX and objectY) then
        return
    end

    local dx = cameraPosition.x - objectX
    local dy = cameraPosition.y - objectY
    local cameraDistanceSq = dx * dx + dy * dy

    if cameraDistanceSq > RENDER_DISTANCE * RENDER_DISTANCE then
        return
    end

    if cameraDistanceSq > HARD_RENDER_DISTANCE * HARD_RENDER_DISTANCE then
        return
    end

    if STATES.gameIntro == state then
        GameIntro.drawQueuePool = GameIntro.drawQueuePool or {}
        local index = #GameIntro.drawQueue + 1
        local entry = GameIntro.drawQueuePool[index] or {}
        GameIntro.drawQueuePool[index] = entry
        entry.priority = priority
        entry.object = object
        GameIntro.drawQueue[index] = entry
    else
        Game.drawQueuePool = Game.drawQueuePool or {}
        local index = #Game.drawQueue + 1
        local entry = Game.drawQueuePool[index] or {}
        Game.drawQueuePool[index] = entry
        entry.priority = priority
        entry.object = object
        Game.drawQueue[index] = entry
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
end

function love.mousepressed(x, y, button)
    if TransitionManager.isTransiting then return end

    local scaledX = (x - viewportOffsetX) / scale
    local scaledY = (y - viewportOffsetY) / scale
    local consumedByMenu = false

    if state == STATES.mainMenu then
        consumedByMenu = MainMenu:mousepressed(scaledX, scaledY, button) == true
    elseif state == STATES.game then
        Game:mousepressed(scaledX, scaledY, button)
    elseif state == STATES.gamePause then
        consumedByMenu = PauseMenu:mousepressed(scaledX, scaledY, button) == true
    elseif state == STATES.gameDead then
        consumedByMenu = GameoverMenu:mousepressed(scaledX, scaledY, button) == true
    elseif state == STATES.settings then
        consumedByMenu = SettingsMenu:mousepressed(scaledX, scaledY, button) == true
    elseif state == STATES.confirm then
        consumedByMenu = ConfirmMenu:mousepressed(scaledX, scaledY, button) == true
    end

    if consumedByMenu and button == 1 then
        INPUT_BLOCK_PRIMARY_FIRE_UNTIL_RELEASE = true
    end
end

function love.wheelmoved(x, y)
    if TransitionManager.isTransiting then return end

    if state == STATES.settings and SettingsMenu.wheelmoved then
        SettingsMenu:wheelmoved(y)
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
    RoomScreenTransition:update(dt)
    AmbienceSound:update(dt)
    Music:update(dt)
    if Game and Game.updateDamageAudioVolumeDuck then
        Game:updateDamageAudioVolumeDuck(dt)
    end
    AudioDeviceSync:update(dt)
end 

local function drawFPS()
    if not FPS then
        return
    end

    local previousFont = love.graphics.getFont()
    local r, g, b, a = love.graphics.getColor()
    local x = 8
    local y = love.graphics.getHeight() - 22

    love.graphics.setFont(fpsFont)
    love.graphics.setColor(0, 0, 0, 0.68)
    love.graphics.rectangle("fill", x - 4, y - 3, 72, 18)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(Localization:t("hud.fps") .. ": " .. love.timer.getFPS(), x, y)
    love.graphics.setFont(previousFont)
    love.graphics.setColor(r, g, b, a)
end

function love.draw()
    local keepRoomUiFixed = RoomScreenTransition:isCapturing() or RoomScreenTransition:isActive()
    love.graphics.clear(0, 0, 0)

    love.graphics.setCanvas({canvas, stencil = true})
    love.graphics.clear(0.2, 0.3, 0.3)
    drawCurrentState()
    if isGameplayState() and not keepRoomUiFixed then
        Game:drawHUD()
    end
    if not keepRoomUiFixed and isMenuState() then
        drawMenuWithDistortion()
    elseif not keepRoomUiFixed then
        drawScaledState()
    end
    love.graphics.setCanvas()
    RoomScreenTransition:captureOldFrame(canvas)

    presentCanvas()
    if keepRoomUiFixed then
        drawFixedRoomLayer()
    end
    if state == STATES.game and Game and Game.drawPlayerDamageFlash then
        Game:drawPlayerDamageFlash(scale or 1)
    end
    drawRoomTransitionFade()

    drawFPS()

    TransitionManager:drawFullscreen()
end
