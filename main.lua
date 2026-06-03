local Levels = require("scripts/config/levels")
local GameConfig = require("scripts/config/gameConfig")
GameConfig:applyLevel(Levels:getDefault())

require "scripts/utils"

Game = require("scripts.managers.gameManager")
local GameIntro = require("scripts.managers.gameIntro")
love.graphics.setDefaultFilter("nearest", "nearest")
local presentationShader = love.graphics.newShader("scripts/shaders/presentation.glsl")
local menuDistortionShader = love.graphics.newShader("scripts/shaders/hudWater.glsl")
local performanceFont = love.graphics.newFont("assets/fonts/PixelGame.otf", 14)
local unpackValues = table.unpack or unpack
local MAX_PRESENTATION_SHOCKWAVES = 8
PERF = PERF or {
    enabled = false,
    updateMs = 0,
    drawMs = 0,
    stateDrawMs = 0,
    hudDrawMs = 0,
    presentMs = 0,
    canvasMs = 0,
    enemiesMs = 0,
    objectsMs = 0,
    particlesMs = 0,
    tilemapMs = 0,
    lastSpikeMs = 0,
    lastSpikeReason = "none",
    lastSpikeEnemies = 0,
}
local presentationShockwaveCenters = {}
local presentationShockwaveParams = {}
local zeroVec2 = {0, 0}

for i = 1, MAX_PRESENTATION_SHOCKWAVES do
    presentationShockwaveCenters[i] = {0, 0}
    presentationShockwaveParams[i] = {1, 0, 1, 0}
end

performanceFont:setFilter("nearest", "nearest")
performanceFont:setLineHeight(1)

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
local RoomScreenTransition = require("scripts/managers/roomScreenTransition")

canvas = nil
local menuCanvas = nil
local fixedLayerCanvas = nil
STATES = {mainMenu = 1, game = 2, gamePause = 3, gameDead = 4, gameIntro = 5, startLogo = 6, settings = 7, confirm = 8, floorIntro = 9}
state = STATES.startLogo

DEBUG = false
FPS = false
PERF.enabled = false
PERF.overlayAvailable = GAME_FLAGS and GAME_FLAGS.performanceOverlay == true

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

local function presentCanvas(sourceCanvas, useRoomTransition, trackPerf)
    sourceCanvas = sourceCanvas or canvas
    if useRoomTransition == nil then
        useRoomTransition = true
    end
    if trackPerf == nil then
        trackPerf = true
    end

    local presentStart = trackPerf and PERF.enabled and love.timer.getTime() or nil
    local crtConfig = GAME_FLAGS and GAME_FLAGS.crt or {}
    local crtEnabled = crtConfig.enabled == true

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

    if trackPerf and PERF and PERF.enabled then
        PERF.presentPixels = math.floor((baseWidth or 0) * (baseHeight or 0) * (scale or 1) * (scale or 1))
        PERF.presentScale = scale or 1
    end

    local presentationCanvas = useRoomTransition
        and RoomScreenTransition:getPresentationCanvas(sourceCanvas)
        or sourceCanvas

    if not crtEnabled and spotlightEnabled == 0 and shockwaveCount == 0 then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(presentationCanvas, viewportOffsetX, viewportOffsetY, 0, scale, scale)
        if presentStart then
            PERF.presentMs = (love.timer.getTime() - presentStart) * 1000
        end
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

    if presentStart then
        PERF.presentMs = (love.timer.getTime() - presentStart) * 1000
    end
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
    presentCanvas(fixedLayerCanvas, false, false)
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
        state = STATES.floorIntro
        Game:load({
            onFloorIntroComplete = function()
                state = STATES.game
                Music:startGame()
            end,
        })
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
        state = STATES.floorIntro
        Game:load({
            onFloorIntroComplete = function()
                state = STATES.game
                Music:startGame()
            end,
        })
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

function openRestartConfirm(returnState)
    confirmReturnState = returnState or STATES.gamePause
    ConfirmMenu:open("NEW RUN", "start a new run?", function()
        loadGame()
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
    if key == "f5" then
        if PERF.overlayAvailable then
            PERF.enabled = not PERF.enabled
            FPS = false
        else
            PERF.enabled = false
            FPS = not FPS
        end
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
    local updateStart = PERF.enabled and love.timer.getTime() or nil
    updateCurrentState(dt)
    TransitionManager:update(dt)
    RoomScreenTransition:update(dt)
    AmbienceSound:update(dt)
    Music:update(dt)
    if updateStart then
        PERF.updateMs = (love.timer.getTime() - updateStart) * 1000
    end
end 

local function drawPerformanceOverlay()
    if not (PERF.enabled or DEBUG) then
        if FPS then
            local previousFont = love.graphics.getFont()
            local r, g, b, a = love.graphics.getColor()
            local x = 8
            local y = love.graphics.getHeight() - 22

            love.graphics.setFont(performanceFont)
            love.graphics.setColor(0, 0, 0, 0.68)
            love.graphics.rectangle("fill", x - 4, y - 3, 72, 18)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print("FPS: " .. love.timer.getFPS(), x, y)
            love.graphics.setFont(previousFont)
            love.graphics.setColor(r, g, b, a)
        end
        return
    end

    if not (PERF.overlayAvailable or DEBUG) then
        return
    end

    local stats = love.graphics.getStats()
    local previousFont = love.graphics.getFont()
    local lineHeight = 16
    local width = 210
    local height = 432
    local x = 8
    local y = (baseHeight or love.graphics.getHeight()) - height - 8

    love.graphics.setColor(0, 0, 0, 0.68)
    love.graphics.rectangle("fill", x - 4, y - 4, width, height)
    love.graphics.setFont(performanceFont)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("FPS: " .. love.timer.getFPS(), x, y)
    y = y + lineHeight
    love.graphics.print(string.format("update %.2f", PERF.updateMs or 0), x, y)
    y = y + lineHeight
    love.graphics.print(string.format("u enemy %.2f post %.2f", PERF.enemiesUpdateMs or 0, PERF.enemyPostUpdateMs or 0), x, y)
    y = y + lineHeight
    love.graphics.print(string.format("u obj %.2f part %.2f", PERF.objectsUpdateMs or 0, PERF.particlesMs or 0), x, y)
    y = y + lineHeight
    love.graphics.print(string.format("u player %.2f tile %.2f", PERF.playerUpdateMs or 0, PERF.tilemapMs or 0), x, y)
    y = y + lineHeight
    love.graphics.print(string.format("u misc %.2f mgr %.2f", PERF.miscUpdateMs or 0, PERF.managersOtherMs or 0), x, y)
    y = y + lineHeight
    love.graphics.print(string.format("draw %.2f", PERF.drawMs or 0), x, y)
    y = y + lineHeight
    love.graphics.print(string.format("canvas %.2f", PERF.canvasMs or 0), x, y)
    y = y + lineHeight
    love.graphics.print(string.format("world %.2f", PERF.stateDrawMs or 0), x, y)
    y = y + lineHeight
    love.graphics.print(string.format("c setup %.2f other %.2f", PERF.canvasSetupMs or 0, PERF.canvasOtherMs or 0), x, y)
    y = y + lineHeight
    love.graphics.print(string.format("present %.2f", PERF.presentMs or 0), x, y)
    y = y + lineHeight
    love.graphics.print(string.format("overlay %.2f trans %.2f", PERF.overlayMs or 0, PERF.transitionDrawMs or 0), x, y)
    y = y + lineHeight
    love.graphics.print(string.format("draw other %.2f", PERF.drawOtherMs or 0), x, y)
    y = y + lineHeight
    love.graphics.print(string.format("queue %.2f", PERF.worldQueueMs or 0), x, y)
    y = y + lineHeight
    love.graphics.print(string.format("  ground %.2f", PERF.wGroundQueueMs or 0), x, y)
    y = y + lineHeight
    love.graphics.print(string.format("  shadows %.2f", PERF.wShadowsMs or 0), x, y)
    y = y + lineHeight
    love.graphics.print(string.format("  objects %.2f", PERF.wQueueObjMs or 0), x, y)
    y = y + lineHeight
    love.graphics.print(string.format("q static %.2f/%d", PERF.qStaticMs or 0, PERF.qStaticCount or 0), x, y)
    y = y + lineHeight
    love.graphics.print(string.format("q enemies %.2f/%d", PERF.qEnemiesMs or 0, PERF.qEnemiesCount or 0), x, y)
    y = y + lineHeight
    love.graphics.print(string.format("q bullets %.2f/%d", PERF.qProjectilesMs or 0, PERF.qProjectilesCount or 0), x, y)
    y = y + lineHeight
    love.graphics.print(string.format("q parts %.2f/%d", PERF.qParticlesMs or 0, PERF.qParticlesCount or 0), x, y)
    y = y + lineHeight
    love.graphics.print(string.format("q player %.2f/%d", PERF.qPlayerMs or 0, PERF.qPlayerCount or 0), x, y)
    y = y + lineHeight
    love.graphics.print(string.format("q other %.2f/%d", PERF.qOtherMs or 0, PERF.qOtherCount or 0), x, y)
    y = y + lineHeight
    love.graphics.print(string.format("ground %.2f lights %.2f", PERF.worldGroundMs or 0, PERF.worldLightsMs or 0), x, y)
    y = y + lineHeight
    love.graphics.print(string.format("sort %.2f xray %.2f", PERF.worldSortMs or 0, PERF.worldXrayMs or 0), x, y)
    y = y + lineHeight
    love.graphics.print(string.format("hud %.2f clouds %.2f", PERF.hudDrawMs or 0, PERF.worldCloudsMs or 0), x, y)
    y = y + lineHeight
    love.graphics.print(string.format("dc %d cs %d", stats.drawcalls or 0, stats.canvasswitches or 0), x, y)
    y = y + lineHeight
    love.graphics.print(string.format("px batch %d/%d", PERF.pixelBatchDraws or 0, PERF.pixelBatchSprites or 0), x, y)
    y = y + lineHeight
    love.graphics.print(string.format("grass %.2f/%d big %.2f/%d", PERF.qGrassMs or 0, PERF.qGrassCount or 0, PERF.qBigGrassMs or 0, PERF.qBigGrassCount or 0), x, y)
    y = y + lineHeight
    love.graphics.print(string.format("tree %.2f/%d tile %.2f/%d", PERF.qTreesMs or 0, PERF.qTreesCount or 0, PERF.qTilesMs or 0, PERF.qTilesCount or 0), x, y)
    y = y + lineHeight
    love.graphics.print(string.format("water %.2f/%d sother %.2f/%d", PERF.qWaterMs or 0, PERF.qWaterCount or 0, PERF.qStaticOtherMs or 0, PERF.qStaticOtherCount or 0), x, y)
    y = y + lineHeight
    love.graphics.print(string.format(
        "enemies %d prof %s",
        Game and Game.enemies and #Game.enemies or 0,
        PERF.drawProfileActive and "on" or "sample"
    ), x, y)
    love.graphics.setFont(previousFont)
end

local function updatePerformanceSpike(totalMs)
    if not PERF.enabled then
        return
    end

    local threshold = PERF.spikeThresholdMs or 7.5
    if totalMs < threshold and totalMs < (PERF.lastSpikeMs or 0) * 0.92 then
        return
    end

    local reason = "frame"
    local maxPhase = 0
    local phases = {
        update = PERF.updateMs or 0,
        world = PERF.stateDrawMs or 0,
        hud = PERF.hudDrawMs or 0,
        present = PERF.presentMs or 0,
        enemies = PERF.enemiesMs or 0,
        objects = PERF.objectsMs or 0,
        particles = PERF.particlesMs or 0,
        tilemap = PERF.tilemapMs or 0,
        w_ground = PERF.worldGroundMs or 0,
        w_lights = PERF.worldLightsMs or 0,
        w_sort = PERF.worldSortMs or 0,
        w_queue = PERF.worldQueueMs or 0,
        w_xray = PERF.worldXrayMs or 0,
    }

    for name, value in pairs(phases) do
        if value > maxPhase then
            maxPhase = value
            reason = name
        end
    end

    if maxPhase < totalMs * 0.18 then
        reason = "present/driver"
    end

    PERF.lastSpikeMs = totalMs
    PERF.lastSpikeReason = reason
    PERF.lastSpikeEnemies = Game and Game.enemies and #Game.enemies or 0
end


function love.draw()
    local drawStart = PERF.enabled and love.timer.getTime() or nil
    local phaseStart = PERF.enabled and love.timer.getTime() or nil
    local keepRoomUiFixed = RoomScreenTransition:isCapturing() or RoomScreenTransition:isActive()
    love.graphics.clear(0, 0, 0)
    if phaseStart then
        PERF.backClearMs = (love.timer.getTime() - phaseStart) * 1000
        phaseStart = love.timer.getTime()
    end

    local canvasStart = PERF.enabled and love.timer.getTime() or nil
    love.graphics.setCanvas({canvas, stencil = true})
    love.graphics.clear(0.2, 0.3, 0.3)
    if phaseStart then
        PERF.canvasSetupMs = (love.timer.getTime() - phaseStart) * 1000
    end
    local stateDrawStart = PERF.enabled and love.timer.getTime() or nil
    drawCurrentState()
    if stateDrawStart then
        PERF.stateDrawMs = (love.timer.getTime() - stateDrawStart) * 1000
    end
    if isGameplayState() and not keepRoomUiFixed then
        local hudStart = PERF.enabled and love.timer.getTime() or nil
        Game:drawHUD()
        if hudStart then
            PERF.hudDrawMs = (love.timer.getTime() - hudStart) * 1000
        end
    elseif PERF.enabled then
        PERF.hudDrawMs = 0
    end
    if not keepRoomUiFixed and isMenuState() then
        drawMenuWithDistortion()
    elseif not keepRoomUiFixed then
        drawScaledState()
    end
    if PERF.enabled then
        PERF.scaledDrawMs = 0
    end
    if isMenuState() then
        -- drawMenuWithDistortion is intentionally counted in canvas overhead for menus.
    end
    love.graphics.setCanvas()
    RoomScreenTransition:captureOldFrame(canvas)
    if canvasStart then
        PERF.canvasMs = (love.timer.getTime() - canvasStart) * 1000
        PERF.canvasOtherMs = PERF.canvasMs
            - (PERF.canvasSetupMs or 0)
            - (PERF.stateDrawMs or 0)
            - (PERF.hudDrawMs or 0)
    end

    presentCanvas()
    if keepRoomUiFixed then
        drawFixedRoomLayer()
    end
    drawRoomTransitionFade()

    local overlayStart = PERF.enabled and love.timer.getTime() or nil
    drawPerformanceOverlay()
    if overlayStart then
        PERF.overlayMs = (love.timer.getTime() - overlayStart) * 1000
    end

    local transitionStart = PERF.enabled and love.timer.getTime() or nil
    TransitionManager:drawFullscreen()
    if transitionStart then
        PERF.transitionDrawMs = (love.timer.getTime() - transitionStart) * 1000
    end

    if drawStart then
        PERF.drawMs = (love.timer.getTime() - drawStart) * 1000
        PERF.drawOtherMs = PERF.drawMs
            - (PERF.canvasMs or 0)
            - (PERF.presentMs or 0)
            - (PERF.overlayMs or 0)
            - (PERF.transitionDrawMs or 0)
        updatePerformanceSpike(PERF.drawMs)
    end
end
