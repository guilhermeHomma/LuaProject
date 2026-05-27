local Particle = require("scripts/particles/particle")
local GunStarDraw = require("scripts/effects/gunStarDraw")

local GunStarParticle = setmetatable({}, {__index = Particle})
GunStarParticle.__index = GunStarParticle
GunStarParticle.castsShadow = false

function GunStarParticle:new(x, y, height, scale, spritePath)
    local particle = Particle.new(self, x, y, height or 0, scale or 1, GunStarDraw.getAnimationDuration())
    particle.scale = scale or 1
    particle.spritePath = spritePath
    return particle
end

function GunStarParticle:update(dt)
    addToDrawQueue(self.y + 6, self)

    self.timer = self.timer + dt
    if self.timer >= self.lifeTime then
        self.isAlive = false
    end
end

function GunStarParticle:drawShadow()
end

function GunStarParticle:draw()
    local frameIndex = math.floor(self.timer / GunStarDraw.getFrameDuration())
    local alpha = 1 - math.min(1, self.timer / self.lifeTime) /2
    GunStarDraw.draw(self.x, self.y - self.height, frameIndex, alpha, self.scale, self.spritePath)
end

return GunStarParticle
