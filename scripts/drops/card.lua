local Life = require("scripts/drops/life")
local CardDrop = setmetatable({}, {__index = Life})

CardDrop.__index = CardDrop

local Ball = require("scripts/particles/ballParticle")
local BulletColorParticle = require("scripts/particles/bulletColorParticle")

local sheetImage = love.graphics.newImage("assets/sprites/objects/card-drop.png")
local greenRainbowShader = love.graphics.newShader("scripts/shaders/greenRainbow.glsl")
sheetImage:setFilter("nearest", "nearest")

local cardParticlePalette = {
    {0.52, 0.16, 0.68, 1},
    {0.18, 0.56, 0.60, 1},
    {0.70, 0.22, 0.46, 1},
    {0.62, 0.52, 0.18, 1},
    {0.24, 0.62, 0.34, 1},
}
local cardParticleOptions = {
    speedMin = 4,
    speedMax = 14,
    lifeTime = 0.62,
    size = 1,
}

local quads = {
    love.graphics.newQuad(0, 0, 16, 16, sheetImage:getDimensions()),
}

function CardDrop:new(x, y)
    local drop = Life.new(self, x, y)
    setmetatable(drop, CardDrop)
    drop.spriteIndex = 1
    drop.sprite = quads[1]
    drop.drawScaleX = 1
    drop.drawScaleY = 1.35
    drop.baseHeight = 16
    drop.hoverHeight = drop.baseHeight
    drop.height = drop.hoverHeight + (drop.popHeight or 0)
    drop.cardParticleTimer = math.random() * 0.12
    return drop
end

function CardDrop:onCatch()
    for _ = 1, 12 do
        local angle = math.random() * math.pi * 2
        local speed = 0.35 + math.random() * 0.55
        local particle = Ball:new(
            self.x,
            self.y,
            self.height,
            math.cos(angle) * speed,
            math.sin(angle) * speed,
            math.random(18, 30) / 100,
            math.random(4, 7) / 10,
            { rgbShift = { duration = 0.22, shift = 1.1 } }
        )
        table.insert(Game.particles, particle)
    end

    if Game and Game.startCardChoice then
        Game:startCardChoice(self.x, self.y - 16, { allowRare = false })
    end
end

function CardDrop:animation(dt)
    self.animationTimer = self.animationTimer + dt

    if not self.isCollecting then
        self.cardParticleTimer = (self.cardParticleTimer or 0) + dt
        if self.cardParticleTimer >= 0.13 then
            self.cardParticleTimer = self.cardParticleTimer - 0.13
            BulletColorParticle.spawnBurst(
                self.x + math.random(-5, 5),
                self.y + math.random(-4, 4),
                self.height,
                cardParticlePalette,
                1,
                cardParticleOptions
            )
        end
    end
end

function CardDrop:draw()
    if not self.isAlive then
        return
    end

    local scaleX, scaleY = self:getDrawScale()
    local drawY = self.y - self.height
    if self.isCollecting then
        drawY = drawY + 4 * ((self.drawScaleY or 1.35) - scaleY)
    end

    greenRainbowShader:send("u_time", love.timer.getTime())
    love.graphics.setShader(greenRainbowShader)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(sheetImage, self.sprite, self.x, drawY, 0, scaleX, scaleY, 8, 16)
    love.graphics.setShader()
    love.graphics.setColor(1, 1, 1, 1)
end

function CardDrop:drawXray()
    if not self.isAlive then
        return
    end

    local scaleX, scaleY = self:getDrawScale()
    local drawY = self.y - self.height
    if self.isCollecting then
        drawY = drawY + 4 * ((self.drawScaleY or 1.35) - scaleY)
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(sheetImage, self.sprite, self.x, drawY, 0, scaleX, scaleY, 8, 16)
end

return CardDrop
