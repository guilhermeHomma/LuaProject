local Particle = {}
Particle.__index = Particle

function Particle:new(x, y, height, radius, lifetime)

    local particle = setmetatable({}, {__index = self})
    particle.height = height
    particle.x = x
    particle.y = y

    particle.initialRadius = radius
    particle.radius = particle.initialRadius
    
    particle.isAlive = true
    particle.timer = 0
    particle.lifeTime = lifetime
    return particle
end

function Particle:update(dt)
    addToDrawQueue(self.y, self)

    self.timer = self.timer + dt
    self.radius = self.initialRadius * (1 - (self.timer / self.lifeTime))


    if self.timer >= self.lifeTime then
        self.isAlive = false
    end
end

function Particle:drawShadow()

    love.graphics.setColor(0.70, 0.63, 0.52)
    love.graphics.circle("fill", self.x, self.y, self.radius * 1.2)
    
    love.graphics.setColor(1, 1, 1)
end

function Particle:draw()

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", self.x, self.y -self.height, self.radius)
    love.graphics.setColor(1, 1, 1)

end

return Particle