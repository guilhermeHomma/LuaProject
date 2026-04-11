Particle = require("scripts/particles/particle")
FootStep = setmetatable({}, {__index = Particle})
FootStep.__index = FootStep

function FootStep:new(x, y, alpha)
    local size = 32

    local lifetime = math.random(8,10)

    local particle = Particle.new(self, x, y, 1, size, lifetime)
    particle.sprite1 = love.graphics.newImage("assets/sprites/particles/footsteps1.png")
    particle.sprite2 = love.graphics.newImage("assets/sprites/particles/footsteps2.png")
    particle.sprite3 = love.graphics.newImage("assets/sprites/particles/footsteps3.png")
    particle.sprite1:setFilter("nearest", "nearest")
    particle.sprite2:setFilter("nearest", "nearest")
    particle.sprite3:setFilter("nearest", "nearest")

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

function FootStep:drawLayer1()
    local currentSize = (16 * self.radius)

    love.graphics.setColor(1, 1, 1, self.alpha-0.1)


    love.graphics.draw(self.sprite1 ,self.x, self.y-2, self.rotation ,1 , 1, 16,16)
    love.graphics.setColor(1, 1, 1, 1)
end

function FootStep:drawLayer2()
    local currentSize = (16 * self.radius)

    love.graphics.setColor(1, 1, 1, self.alpha-0.1)
    love.graphics.draw(self.sprite2 ,self.x, self.y-2, self.rotation ,1 , 1, 16,16)
    love.graphics.setColor(1, 1, 1, 1)
end

function FootStep:drawLayer3()
    local currentSize = (16 * self.radius)
    
    love.graphics.setColor(1, 1, 1, self.alpha)
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