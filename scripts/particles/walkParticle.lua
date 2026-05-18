Particle = require("scripts/particles/particle")
WalkP = setmetatable({}, {__index = Particle})
WalkP.__index = WalkP

local sprite = love.graphics.newImage("assets/sprites/particles/ball.png")
local starSprite = love.graphics.newImage("assets/sprites/particles/star.png")

sprite:setFilter("nearest", "nearest")

function WalkP:new(x, y, lifetime)
    local size = 0.3

    if not lifetime  then lifetime = math.random(9, 11) / 10 end

    local particle = Particle.new(self, x, y, 1, size, lifetime)
    particle.sprite = math.random() < 0.3 and starSprite or sprite

    particle.speedDown = math.random(5, 10)
    particle.alpha = 0.7
    return particle
end

function WalkP:update(dt)
    addToDrawQueue(self.y + 5, self)

    self.timer = self.timer + dt
    self.radius = self.radius + 0.1 * dt
    self.alpha = self.alpha - 2 * dt
    self.height = self.height + self.speedDown * dt
    if self.timer >= self.lifeTime then
        self:death()
    end
end

function WalkP:drawShadow()
    
end

function WalkP:death()
    self.isAlive = false
end

function WalkP:draw()

    local sheetWidth = self.sprite:getWidth()
    local sheetHeight = self.sprite:getHeight()

    local currentSize = (16 * self.radius)

    love.graphics.setColor(1, 1, 1, self.alpha)
    love.graphics.draw(self.sprite ,self.x, self.y - self.height, 0 ,1 * self.radius, 1.5 * self.radius, 16/2,16/2*1.5 )
    love.graphics.setColor(1, 1, 1, 1)
end

return WalkP
