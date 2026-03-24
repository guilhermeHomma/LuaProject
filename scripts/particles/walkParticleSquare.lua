Particle = require("scripts/particles/particle")
WalkPSquare = setmetatable({}, {__index = Particle})
WalkPSquare.__index = WalkPSquare

function WalkPSquare:new(x, y, lifetime)
    local size = 0.2

    if not lifetime  then lifetime = math.random(8, 10) / 10 end

    local particle = Particle.new(self, x, y, 1, size, lifetime)
    particle.sprite = love.graphics.newImage("assets/sprites/particles/walkSquare.png")
    particle.sprite:setFilter("nearest", "nearest")

    particle.speedDown = math.random(5, 10)
    particle.alpha = 0.4
    return particle
end

function WalkPSquare:update(dt)
    addToDrawQueue(self.y + 5, self)

    self.timer = self.timer + dt

    self.alpha = self.alpha - 0.4 * dt

    if self.timer >= self.lifeTime then
        self:death()
    end
end

function WalkPSquare:drawShadow()
    local sheetWidth = self.sprite:getWidth()
    local sheetHeight = self.sprite:getHeight()

    local currentSize = (16 * self.radius)

    love.graphics.setColor(1, 1, 1, self.alpha)
    love.graphics.draw(self.sprite ,self.x+8, self.y+8, 0 ,1 , 1, 16,16)
    love.graphics.setColor(1, 1, 1, 1)
end

function WalkPSquare:death()
    self.isAlive = false
end

function WalkPSquare:draw()


end

return WalkPSquare