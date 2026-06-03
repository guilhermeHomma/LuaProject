Pole = setmetatable({}, {__index = Tile})
Pole.__index = Pole
TileSet = require("scripts.objects.tileset")
local LightConfig = require("scripts/config/lightConfig")

local sprite = love.graphics.newImage("assets/sprites/objects/pole.png")
local spriteWidth, spriteHeight = sprite:getDimensions()
local poleLightConfig = LightConfig:getWorldLightConfig("pole") or {}
local animationConfig = poleLightConfig.animation or {}
local frameCount = animationConfig.frameCount or 5
local frameWidth = spriteWidth / frameCount
local frames = {}

sprite:setFilter("nearest", "nearest")

for i = 1, frameCount do
    frames[i] = love.graphics.newQuad((i - 1) * frameWidth, 0, frameWidth, spriteHeight, spriteWidth, spriteHeight)
end

function Pole:new(x, y, quadIndex, collider, options)
    options = options or {}
    local tile = Tile.new(self, x, y, quadIndex, collider)
    setmetatable(tile, Pole)
    tile.animationTimer = math.random() * frameCount * (animationConfig.frameTime or 0.12)
    tile.currentFrame = math.random(frameCount)
    tile.flickerTime = math.random() * 10
    tile.flickerSeed = math.random() * 100
    tile.lightFlicker = 1
    tile.renderCullMargin = 420
    tile.spatialRadius = 260
    tile.isXrayOccluder = true
    tile.ySortOffset = options.ySortOffset or 0
    return tile
end

function Pole:update(dt)
    local config = LightConfig:getWorldLightConfig("pole") or poleLightConfig
    local anim = config.animation or animationConfig
    local visual = config.visual or {}
    local frameTime = anim.frameTime or 0.12

    self.animationTimer = (self.animationTimer or 0) + dt
    self.currentFrame = math.floor(self.animationTimer / frameTime) % frameCount + 1
    self.flickerTime = (self.flickerTime or 0) + dt

    local flickerAmount = visual.flickerAmount or 0.05
    local flickerSpeed = visual.flickerSpeed or 3.7
    local noise = love.math.noise(self.flickerSeed or 0, self.flickerTime * flickerSpeed)
    self.lightFlicker = 1 + (noise * 2 - 1) * flickerAmount

    local lightManager = ACTIVE_LIGHT_MANAGER or Game
    if lightManager and lightManager.addLightSource then
        lightManager:addLightSource(
            "pole",
            self.xWorld + (anim.lightOffsetX or 0),
            self.yWorld + (anim.lightOffsetY or -14),
            {flicker = self.lightFlicker}
        )
    end

    addToDrawQueue(self.yWorld + 2 + (self.ySortOffset or 0), self, false)
end

function Pole:drawShadow()
   
end

function Pole:getXrayOccluderBox()
    local config = LightConfig:getWorldLightConfig("pole") or poleLightConfig
    local anim = config.animation or animationConfig
    local scaleX = anim.scaleX or 1
    local scaleY = anim.scaleY or 1.5

    return {
        x = self.xWorld - (frameWidth * scaleX) / 2,
        y = self.yWorld - spriteHeight * scaleY,
        width = frameWidth * scaleX,
        height = spriteHeight * scaleY,
    }
end

function Pole:drawXrayOccluder()
    local config = LightConfig:getWorldLightConfig("pole") or poleLightConfig
    local anim = config.animation or animationConfig

    love.graphics.draw(
        sprite,
        frames[self.currentFrame or 1],
        self.xWorld,
        self.yWorld,
        0,
        anim.scaleX or 1,
        anim.scaleY or 1.5,
        frameWidth / 2,
        spriteHeight
    )
end

function Pole:draw()
    local tileSet = TileSet:getTileSet()
    local tileSize = TileSet.tileSize
    local tilesetImage = TileSet.tilesetImage
    local config = LightConfig:getWorldLightConfig("pole") or poleLightConfig
    local anim = config.animation or animationConfig

    if not self.collider then
        love.graphics.draw(tilesetImage, tileSet[5], self.xWorld, self.yWorld + 1, 0, 1, 1, tileSize/2, tileSize)
    end
    love.graphics.draw(
        sprite,
        frames[self.currentFrame or 1],
        self.xWorld,
        self.yWorld,
        0,
        anim.scaleX or 1,
        anim.scaleY or 1.5,
        frameWidth / 2,
        spriteHeight
    )
end

return Pole
