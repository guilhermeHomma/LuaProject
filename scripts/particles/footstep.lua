Particle = require("scripts/particles/particle")
FootStep = setmetatable({}, {__index = Particle})
FootStep.__index = FootStep
FootStep.castsShadow = false

local sprite1 = love.graphics.newImage("assets/sprites/particles/footsteps1.png")
local sprite2 = love.graphics.newImage("assets/sprites/particles/footsteps2.png")
local sprite3 = love.graphics.newImage("assets/sprites/particles/footsteps3.png")

sprite1:setFilter("nearest", "nearest")
sprite2:setFilter("nearest", "nearest")
sprite3:setFilter("nearest", "nearest")

function FootStep:new(x, y, alpha)
    local size = 32

    local lifetime = math.random(8,10)

    local particle = Particle.new(self, x, y, 1, size, lifetime)
    particle.sprite1 = sprite1
    particle.sprite2 = sprite2
    particle.sprite3 = sprite3

    particle.speedDown = math.random(5, 10)
    particle.rotation = math.random(-10, 10)
    if alpha then 
        particle.alpha = alpha
    else
        particle.alpha = 0.5
    end

    return particle
end

function FootStep:update(dt)
    
    self.timer = self.timer + dt

    self.alpha = self.alpha - 0.1 * dt

    if self.alpha <=0  then
        self:death()
    end
end

local function clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

local function getLightAlpha(alpha, brightness)
    brightness = clamp(brightness or 1, 0, 1)
    return math.max(0, alpha) * brightness * brightness * brightness * brightness * 0.75
end

local function getLightColor(brightness)
    brightness = clamp(brightness or 1, 0, 1)
    return brightness * brightness
end

function FootStep:drawLayer1(brightness)
    local currentSize = (16 * self.radius)

    local lightColor = getLightColor(brightness)
    love.graphics.setColor(lightColor, lightColor, lightColor, getLightAlpha(self.alpha - 0.1, brightness))


    love.graphics.draw(self.sprite1 ,self.x, self.y-2, self.rotation ,1 , 1, 16,16)
    love.graphics.setColor(1, 1, 1, 1)
end

function FootStep:drawLayer2(brightness)
    local currentSize = (16 * self.radius)

    local lightColor = getLightColor(brightness)
    love.graphics.setColor(lightColor, lightColor, lightColor, getLightAlpha(self.alpha - 0.1, brightness))
    love.graphics.draw(self.sprite2 ,self.x, self.y-2, self.rotation ,1 , 1, 16,16)
    love.graphics.setColor(1, 1, 1, 1)
end

function FootStep:drawLayer3(brightness)
    local currentSize = (16 * self.radius)
    
    local lightColor = getLightColor(brightness)
    love.graphics.setColor(lightColor, lightColor, lightColor, getLightAlpha(self.alpha, brightness))
    love.graphics.draw(self.sprite3 ,self.x, self.y-2, self.rotation ,1 , 1, 16,16)
    love.graphics.setColor(1, 1, 1, 1)
end

function FootStep:death()
    self.isAlive = false
end

function FootStep:drawShadow()


end

function FootStep:draw()


end

return FootStep
