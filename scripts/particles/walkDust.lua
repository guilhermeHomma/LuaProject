local Particle = require("scripts/particles/particle")
local WalkDust = setmetatable({}, {__index = Particle})
WalkDust.__index = WalkDust
WalkDust.castsShadow = false

local sprite = love.graphics.newImage("assets/sprites/particles/walk-particle.png")
sprite:setFilter("nearest", "nearest")

local frameSize = 8
local frameDuration = 0.10
local sheetWidth, sheetHeight = sprite:getDimensions()
local frames = {}
for y = 0, sheetHeight - frameSize, frameSize do
    for x = 0, sheetWidth - frameSize, frameSize do
        frames[#frames + 1] = love.graphics.newQuad(x, y, frameSize, frameSize, sheetWidth, sheetHeight)
    end
end

function WalkDust:new(x, y)
    local particle = Particle.new(self, x, y, 0, 1, #frames * frameDuration)
    particle.alpha = 1
    return particle
end

function WalkDust:update(dt)
    self.timer = self.timer + dt
    if self.timer >= self.lifeTime then
        self.isAlive = false
        return
    end
    addToDrawQueue(self.y + 5, self)
end

function WalkDust:draw()
    if not self.isAlive then return end
    local frame = math.min(math.floor(self.timer / frameDuration) + 1, #frames)
    local r, g, b, a = love.graphics.getColor()
    love.graphics.setColor(r, g, b, a * self.alpha)
    love.graphics.draw(sprite, frames[frame], self.x, self.y, 0, 1, 1, frameSize / 2, frameSize / 2)
    love.graphics.setColor(r, g, b, a)
end

return WalkDust
