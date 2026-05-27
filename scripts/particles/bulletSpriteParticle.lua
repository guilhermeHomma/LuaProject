local Particle = require("scripts/particles/particle")

local BulletSpriteParticle = setmetatable({}, {__index = Particle})
BulletSpriteParticle.__index = BulletSpriteParticle
BulletSpriteParticle.castsShadow = false

local imageCache = {}
local quadCache = {}
local frameSize = 16
local frameCount = 5

local function getImage(path)
    if not imageCache[path] then
        imageCache[path] = love.graphics.newImage(path)
        imageCache[path]:setFilter("nearest", "nearest")
    end

    return imageCache[path]
end

local function getQuad(path, frameIndex)
    quadCache[path] = quadCache[path] or {}

    if not quadCache[path][frameIndex] then
        local image = getImage(path)
        quadCache[path][frameIndex] = love.graphics.newQuad(
            frameIndex * frameSize,
            0,
            frameSize,
            frameSize,
            image:getDimensions()
        )
    end

    return quadCache[path][frameIndex]
end

function BulletSpriteParticle:new(x, y, height, spritePath, angle, lifetime, scale)
    local particle = Particle.new(self, x, y, height or 0, scale or 1, lifetime or 0.12)
    particle.spritePath = spritePath
    particle.angle = angle or 0
    particle.scale = scale or 0.75
    return particle
end

function BulletSpriteParticle:update(dt)
    addToDrawQueue(self.y + 4, self)

    self.timer = self.timer + dt
    if self.timer >= self.lifeTime then
        self.isAlive = false
    end
end

function BulletSpriteParticle:drawShadow()
end

function BulletSpriteParticle:draw()
    local progress = math.min(0.999, self.timer / self.lifeTime)
    local frameIndex = math.floor(progress * frameCount)
    local alpha = 1 - progress

    BulletSpriteParticle.drawSprite(
        self.spritePath,
        self.x,
        self.y - self.height,
        self.angle,
        frameIndex,
        alpha,
        self.scale
    )
end

function BulletSpriteParticle.drawSprite(spritePath, x, y, angle, frameIndex, alpha, scale)
    local image = getImage(spritePath)
    local quad = getQuad(spritePath, frameIndex)

    love.graphics.setColor(1, 1, 1, alpha or 1)
    love.graphics.draw(image, quad, x, y, angle or 0, scale or 1, scale or 1, frameSize / 2, frameSize / 2)
    love.graphics.setColor(1, 1, 1, 1)
end

return BulletSpriteParticle
