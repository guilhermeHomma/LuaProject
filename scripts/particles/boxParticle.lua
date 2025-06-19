local Particle = require("scripts/particles/particle")
local Ball = require("scripts/particles/ballParticle")

local boxParticle = setmetatable({}, {__index = Particle})
boxParticle.__index = boxParticle
local whiteShader = love.graphics.newShader("scripts/shaders/whiteShader.glsl")


function boxParticle:new(x, y)

    local particle = Particle.new(self, x, y, 0, 4, 100)
    particle.sprite = love.graphics.newImage("assets/sprites/particles/box-particles.png")
    particle.sprite:setFilter("nearest", "nearest")
    particle.index = math.random(1, 3)
    return particle
end

function boxParticle:update(dt)
    addToDrawQueue(self.y -3, self)

    self.timer = self.timer + dt

    if self.timer >= self.lifeTime then
        self:death()
    end
end


function boxParticle:drawShadow()


end


function boxParticle:death()
    self.isAlive = false

end

function boxParticle:draw()


    if self.timer < 0.05  then
        love.graphics.setShader(whiteShader)   
    end

    love.graphics.setColor(1, 1, 1, 1)
    local sheetWidth = self.sprite:getWidth()
    local sheetHeight = self.sprite:getHeight()
    local quad = love.graphics.newQuad((self.index-1) * 32, 0, 32, 32, sheetWidth, sheetHeight)

    love.graphics.draw(self.sprite, quad, self.x, self.y + 3, 0, 1, 1.1, 32 / 2, 32)
    love.graphics.setShader()   
    love.graphics.setColor(1, 1, 1)
end

return boxParticle