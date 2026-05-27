local Particle = require("scripts/particles/particle")

local LeafParticle = setmetatable({}, {__index = Particle})
LeafParticle.__index = LeafParticle
LeafParticle.castsShadow = false

local sprite = love.graphics.newImage("assets/sprites/particles/leaves.png")
sprite:setFilter("nearest", "nearest")

local frameSize = 16
local frameCount = math.floor(sprite:getWidth() / frameSize)
local frameDuration = 0.08
local quads = {}

for i = 0, frameCount - 1 do
    quads[i + 1] = love.graphics.newQuad(i * frameSize, 0, frameSize, frameSize, sprite:getDimensions())
end

function LeafParticle:new(x, y)
    local lifetime = 4.2 + math.random() * 2.8
    if math.random() > 0.72 then
        lifetime = 7.0 + math.random() * 3.5
    end

    local particle = Particle.new(self, x, y, 0, 1, lifetime)
    particle.particleType = "leafParticle"
    particle.frameOffset = math.random(0, frameCount - 1)
    particle.fallSpeed = 7 + math.random() * 5
    particle.driftSpeed = 5 + math.random() * 4
    particle.wobbleOffset = math.random() * math.pi * 2
    particle.wobbleAmount = 1.2 + math.random() * 1.4
    particle.rotation = (math.random() * 2 - 1) * 0.25
    particle.rotationSpeed = (math.random() * 2 - 1) * 0.35
    particle.scale = 0.75 + math.random() * 0.45
    particle.frameDuration = math.random(6, 16) * 0.01
    return particle
end

function LeafParticle:update(dt)
    local FloorManager = package.loaded["scripts/managers/floorManager"]
    local theme = FloorManager
        and FloorManager.getCurrentRoomTheme
        and FloorManager:getCurrentRoomTheme()
    if theme and theme.leafParticles == false then
        self.isAlive = false
        return
    end

    addToDrawQueue(self.y + 17, self)

    self.timer = self.timer + dt
    self.x = self.x - self.driftSpeed * dt + math.sin(self.timer * 4 + self.wobbleOffset) * self.wobbleAmount * dt
    self.y = self.y + self.fallSpeed * dt
    self.rotation = self.rotation + self.rotationSpeed * dt

    if self.timer >= self.lifeTime then
        self.isAlive = false
    end
end

function LeafParticle:drawShadow()
end

function LeafParticle:draw()
    local progress = math.min(1, self.timer / self.lifeTime)
    local frameIndex = (math.floor(self.timer / self.frameDuration) + self.frameOffset) % frameCount + 1
    local alpha = 1

    if progress > 0.72 then
        alpha = 1 - ((progress - 0.72) / 0.28)
    end

    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.draw(sprite, quads[frameIndex], self.x, self.y, self.rotation, self.scale, self.scale, frameSize / 2, frameSize / 2)
    love.graphics.setColor(1, 1, 1, 1)
end

return LeafParticle
