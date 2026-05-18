local GameIntro = {}

local Camera = require("scripts/camera")
local Ground = require("scripts/ground")
local Clouds = require("scripts/clouds")
local Tilemap = require("scripts/tilemap")
local FloorManager = require("scripts/managers/floorManager")
local LightConfig = require("scripts/config/lightConfig")
local font = love.graphics.newFont("assets/fonts/ThaleahFat.ttf", 80)
font:setFilter("nearest", "nearest")
local playerLightImage = love.graphics.newImage("assets/sprites/effects/light.png")
playerLightImage:setFilter("nearest", "nearest")


camera = nil
local target = {x = -330, y = 330}
function GameIntro:load()
    
    math.randomseed(os.time())
    love.graphics.setDefaultFilter("nearest", "nearest")
    camera = Camera:new(target.x, target.y-10, target)

    Ground:load()
    Clouds:load(target)
    FloorManager:load(CURRENT_LEVEL)
    Tilemap:load()

    self.drawQueue = {}
    self.lightSources = {}
    ACTIVE_LIGHT_MANAGER = self

    self.timer = 0
    self.changed = false
    self.playedCrowSound = false
    AmbienceSound:playCricketSound()
end


function GameIntro:close()
    self = {}
end

function GameIntro:update(dt)
    ACTIVE_LIGHT_MANAGER = self
    self.drawQueue = {}
    self.lightSources = {}
    self.timer = self.timer + dt
    local targetPitch = 1

    target.x = target.x + 0.7 * dt
    target.y = target.y - 1 * dt

    Clouds:update(dt)

    Tilemap:update(dt)

    camera:update(dt)

    if self.timer > 2 and not self.playedCrowSound then
        AmbienceSound:playCrowSound()
        self.playedCrowSound = true
    end

    if self.timer > 7 and not self.changed then
        
        quitToMenu()
        self:close()
        self.changed = true
    end
end

local function isGroundLightNearCamera(config, x, y)
    local groundLight = config and config.groundLight
    if not (camera and groundLight and groundLight.enabled ~= false) then
        return false
    end

    local radius = groundLight.outerRadius or 0
    local screenX = (x * WORLD_SCALE_X - camera.x) * camera.zoomX
    local screenY = (y * YSCALE - camera.y) * camera.zoomY

    return screenX >= -radius
        and screenX <= baseWidth + radius
        and screenY >= -radius
        and screenY <= baseHeight + radius
end

local function getShadowTint(brightness)
    local color = LightConfig:getGeneralShadow().color or {0, 0, 0}
    brightness = math.min(math.max(brightness or 1, 0), 1)

    return
        (color[1] or 0) * (1 - brightness) + brightness,
        (color[2] or 0) * (1 - brightness) + brightness,
        (color[3] or 0) * (1 - brightness) + brightness
end

function GameIntro:addLightSource(lightType, x, y, options)
    local config = LightConfig:getWorldLightConfig(lightType)
    if not (config and config.enabled ~= false and x and y) then
        return
    end

    if not isGroundLightNearCamera(config, x, y) then
        return
    end

    options = options or {}
    self.lightSources = self.lightSources or {}
    self.lightSources[#self.lightSources + 1] = {
        type = lightType,
        x = x,
        y = y,
        config = config,
        flicker = options.flicker or 1,
    }
end

function GameIntro:getLightSources()
    return self.lightSources or {}
end

local function getIntroObjectBrightness(object)
    local generalShadow = LightConfig:getGeneralShadow()
    local minBrightness = generalShadow.minBrightness or 1
    local brightness = minBrightness

    for _, source in ipairs(GameIntro:getLightSources()) do
        local spriteBrightness = source.config and source.config.spriteBrightness
        if spriteBrightness and spriteBrightness.enabled ~= false then
            local d = distance(source, object)
            local minDist = spriteBrightness.minDistance or 35
            local maxDist = spriteBrightness.maxDistance or 230
            local maxBrightness = spriteBrightness.maxBrightness or 1
            local range = math.max(1, maxDist - minDist)
            local t = math.min(math.max((d - minDist) / range, 0), 1)
            local sourceBrightness = maxBrightness + (minBrightness - maxBrightness) * t
            sourceBrightness = math.min(math.max(sourceBrightness * (source.flicker or 1), minBrightness), maxBrightness)
            brightness = math.max(brightness, sourceBrightness)
        end
    end

    return brightness
end

function GameIntro:drawLightSprites()
    local width = playerLightImage:getWidth()
    local height = playerLightImage:getHeight()
    local previousBlendMode, previousAlphaMode = love.graphics.getBlendMode()
    love.graphics.setBlendMode("alpha", "alphamultiply")

    for _, source in ipairs(self:getLightSources()) do
        local visual = source.config and source.config.visual
        if visual and visual.enabled ~= false then
            local color = visual.color or {1, 1, 1}
            local flicker = source.flicker or 1
            local scale = visual.scale or 0.65
            if visual.flickerScale then
                scale = scale * flicker
            end

            love.graphics.setColor(
                color[1] or 1,
                color[2] or 1,
                color[3] or 1,
                (visual.alpha or 0.18) * flicker
            )
            love.graphics.draw(
                playerLightImage,
                source.x,
                source.y,
                0,
                scale,
                scale,
                width / 2,
                height / 2
            )
        end
    end

    love.graphics.setBlendMode(previousBlendMode, previousAlphaMode)
    love.graphics.setColor(1, 1, 1, 1)
end

function GameIntro:draw()
    ACTIVE_LIGHT_MANAGER = self
    camera:attach()

    love.graphics.scale(WORLD_SCALE_X, YSCALE) 

    Ground:draw(target)
    self:drawLightSprites()
    
    table.sort(self.drawQueue, function(a, b) return a.priority < b.priority end)
    Clouds:drawShadow()

    for _, item in ipairs(self.drawQueue) do
        if type(item.object.drawShadow) == "function" then
            item.object:drawShadow()
        end
    end

    for _, item in ipairs(self.drawQueue) do
        local brightness = getIntroObjectBrightness(item.object)
        local r, g, b = getShadowTint(brightness)
        love.graphics.setColor(r, g, b, 1)
        item.object:draw()
        love.graphics.setColor(1, 1, 1, 1)
    end
    local text = "Mobize"

    love.graphics.setFont(font)
    local textWidth = font:getWidth(text)
    love.graphics.print(text, target.x - textWidth/2, target.y -50)
    Clouds:draw()
    
    love.graphics.scale(1, 1)
    
    camera:detach()
    
end

return GameIntro
