local Life = require("scripts/drops/life")
local Bullets = setmetatable({}, {__index = Life})

Bullets.__index = Bullets

local DropShine = require("scripts/drops/dropShine")
local Ball = require("scripts/particles/ballParticle")

local sheetImage = love.graphics.newImage("assets/sprites/objects/bulletsDrop.png")

sheetImage:setFilter("nearest", "nearest")
local quads = {}
local sheetWidth = sheetImage:getWidth()
local sheetHeight = sheetImage:getHeight()

for x = 0, sheetWidth - 8, 8 do
    if x == 0 then
        table.insert(quads, love.graphics.newQuad(x, 0, 8, 8, sheetWidth, sheetHeight))
        table.insert(quads, love.graphics.newQuad(x, 0, 8, 8, sheetWidth, sheetHeight))
    end

    table.insert(quads, love.graphics.newQuad(x, 0, 8, 8, sheetWidth, sheetHeight))
end

function Bullets:new(x, y)
    local drop = Life.new(self, x, y)
    setmetatable(drop, Bullets)
    drop.spriteIndex = 1
    drop.sprite = quads[drop.spriteIndex]
    drop.drawScaleX = 1
    drop.drawScaleY = 1.25
    return drop
end

function Bullets:canCatch()
    if not (Player and Player.gun) then
        return false
    end

    if not Player.gun.secondary_weapon then
        return true
    end

    return Player.gun.canFillCurrentMagazine
        and Player.gun:canFillCurrentMagazine()
end

function Bullets:checkCatch()
    if not self:canCatch() then
        return
    end

    Life.checkCatch(self)
end

function Bullets:keypressed(key)
    if not self:canCatch() then
        return
    end

    Life.keypressed(self, key)
end

function Bullets:startCollectAnimation()
    self.isAlive = false
    self:onCatch()
end

function Bullets:onCatch()
    if Player and Player.gun and Player.gun.fillCurrentMagazine then
        Player.gun:fillCurrentMagazine()
    end

    self:catchParticles()
end

function Bullets:catchParticles()
    for i = 1, 3 do
        local angle = math.random() * 2 * math.pi
        local dx = math.cos(angle) / 2
        local dy = math.sin(angle) / 2
        local lifetime = math.random(18, 28) / 100
        local size = math.random(5, 7) / 10
        table.insert(Game.particles, Ball:new(self.x, self.y, self.height, dx, dy, lifetime, size))
    end
end

function Bullets:animation(dt)
    self.animationTimer = self.animationTimer + dt

    if self.animationTimer > 0.1 then
        self.animationTimer = 0
        self.spriteIndex = self.spriteIndex + 1
        if self.spriteIndex > #quads then
            self.spriteIndex = 1
        end
        self.sprite = quads[self.spriteIndex]
    end
end

function Bullets:draw()
    if not self.isAlive then
        return
    end

    local alpha = 1
    if not self.neverExpires and self.lifeTime - self.lifetimeTimer <= 4 then
        local blink = math.floor(self.lifetimeTimer * 10) % 2
        alpha = blink == 0 and 0.2 or 1
    end

    love.graphics.setColor(1, 1, 1, alpha)
    local scaleX, scaleY = self:getDrawScale()
    DropShine.draw(sheetImage, self.sprite, self.x, self.y - self.height, 0, scaleX, scaleY, 4, 8)
    love.graphics.setColor(1, 1, 1, 1)
end

return Bullets
