local GameHud = {}

local PointsManager = require("scripts/managers/pointsManager")
local Tutorial = require("scripts/managers/tutorial")
local WaveManager = require("scripts/managers/waves")
local FloorManager = require("scripts/managers/floorManager")
local FloorIntroManager = require("scripts/managers/floorIntroManager")
local CardChoice = require("scripts/managers/cardChoice")
local Minimap = require("scripts/ui/minimap")
local Tilemap = require("scripts/tilemap")
local Fonts = require("scripts/ui/fonts")

local font = Fonts:translated("hudMessage")
local hudDistortionShader = love.graphics.newShader("scripts/shaders/hudWater.glsl")
local vignetteShader = love.graphics.newShader("scripts/shaders/vignette.glsl")

local hudCanvas = nil
local hudDirty = true
local hudFrame = 0

local function drawLowHealthVignette()
    local intensity = Player and Player.damageAlha or 0
    if intensity <= 0 then
        return
    end

    vignetteShader:send("u_resolution", {baseWidth, baseHeight})
    vignetteShader:send("u_intensity", math.min(math.max(intensity, 0), 1.65))
    vignetteShader:send("u_edgeBrightness", 0.32)

    love.graphics.setShader(vignetteShader)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, baseWidth, baseHeight)
    love.graphics.setShader()
end

local function drawMinimap(game)
    Minimap.draw({
        game = game,
        floorManager = FloorManager,
        tilemap = Tilemap,
        player = Player,
    })
end

local function drawContent(game)
    drawLowHealthVignette()

    love.graphics.setFont(font)
    font:setLineHeight(1)
    love.graphics.setColor(1, 1, 1, game.textAlpha)

    if not Dialog.visible then
        love.graphics.printf(game.drawtext, 0, getScreenHeight() - 80, getScreenWidth(), "center")
    end
    love.graphics.setColor(1, 1, 1, 1)

    PointsManager:draw()
    Player:drawLife()
    if Player and Player.isAlive then
        Player.gun:drawUI()
        Tutorial:draw()
    end
    WaveManager:draw()
    drawMinimap(game)

    game:drawRoomFade()
    game:drawFloorOverlay()
    game:drawFloorIntro()
    game:drawThanksScreen()
end

function GameHud.markDirty()
    hudDirty = true
end

function GameHud.draw(game)
    if not hudCanvas or hudCanvas:getWidth() ~= baseWidth or hudCanvas:getHeight() ~= baseHeight then
        hudCanvas = love.graphics.newCanvas(baseWidth, baseHeight)
        hudCanvas:setFilter("nearest", "nearest")
        hudDirty = true
        hudFrame = 0
    end

    hudFrame = hudFrame + 1
    if hudDirty or hudFrame >= 2 then
        local previousCanvas = love.graphics.getCanvas()
        love.graphics.setCanvas(hudCanvas)
        love.graphics.clear(0, 0, 0, 0)
        drawContent(game)
        love.graphics.setCanvas(previousCanvas)
        hudDirty = false
        hudFrame = 0
    end

    hudDistortionShader:send("u_time", love.timer.getTime() / 2)
    hudDistortionShader:send("u_strength", 0.00055)
    love.graphics.setShader(hudDistortionShader)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(hudCanvas, 0, 0)
    love.graphics.setShader()

    CardChoice:draw()
end

return GameHud
