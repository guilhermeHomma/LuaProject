local Particle = require("scripts/particles/particle")
local Ball = setmetatable({}, {__index = Particle})
Ball.__index = Ball

function Ball:new(x, y, height, dx, dy, lifetime, size)
    if not size then size = 1 end
    if not dx then dx = 0 end
    if not dy then dy = 0 end
    if not lifetime  then lifetime = math.random(30, 45) / 100 end

    local particle = Particle.new(self, x, y, height, size, lifetime)
    particle.sprite = love.graphics.newImage("assets/sprites/particles/ball.png")
    particle.sprite:setFilter("nearest", "nearest")
    particle.speed = math.random(30, 35)
    particle.speedDown = math.random(45, 55)
    
    particle.dx = dx
    particle.dy = dy
    return particle
end

function Ball:update(dt)
    addToDrawQueue(self.y + 5, self)
    self.x = self.x + self.dx * self.speed * dt
    self.y = self.y + self.dy * self.speed * dt
    self.timer = self.timer + dt
    self.radius = self.initialRadius * (1 - (self.timer / self.lifeTime))
    self.speed = self.speed - 33*dt
    if self.speed <= 0 then self.speed = 0 end

    self.height = self.height + self.speedDown * dt
    if self.timer >= self.lifeTime then
        self:death()
    end
end

function Ball:drawShadow()
    
end

function Ball:death()
    self.isAlive = false
end

function Ball:draw()

    local sheetWidth = self.sprite:getWidth()
    local sheetHeight = self.sprite:getHeight()

    local currentSize = (16 * self.radius)
    love.graphics.setColor(1, 1, 1, 0.8)

    love.graphics.draw(self.sprite ,self.x, self.y - self.height, 0 ,1 * self.radius, 1.5 * self.radius, 16/2,16/2*1.5 )
    love.graphics.setColor(1, 1, 1, 1)

end

return Ball