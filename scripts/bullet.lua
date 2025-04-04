local Bullet = {}
Bullet.__index = Bullet

local Particle = require("scripts/particle")

function Bullet:new(x, y, angle, height, speed)
    local angle = angle
    local bullet = setmetatable({}, Bullet)
    local bulletSound = love.audio.newSource("assets/sfx/bullet.wav", "static")

    bullet.height = height
    bullet.x = x
    bullet.y = y
    bullet.dx = math.cos(angle) * speed
    bullet.dy = math.sin(angle) * speed
    bullet.radius = 1.3
    bullet.isAlive = true
    bullet.timer = 0
    bulletSound:setVolume(0.9)
    bulletSound:setPitch(0.9 + math.random() * 0.3)
    bulletSound:play()
    return bullet
end

function Bullet:checkCollisionWithEnemy(enemy)
    local dx = self.x - enemy.x
    local dy = self.y - enemy.y
    local distance = math.sqrt(dx * dx + dy * dy)

    return distance < (self.radius + 4)
end


function Bullet:update(dt)
    self.x = self.x + self.dx * dt
    self.y = self.y + self.dy * dt

    addToDrawQueue(self.y, self)

    self.timer = self.timer + dt

    if self.timer >= 2 then
        self.isAlive = false
    end

    local particle = Particle:new(self.x, self.y, 15, 1.2, 0.07)
    table.insert(particles, particle)

    for _, enemy in ipairs(enemies) do
        if self:checkCollisionWithEnemy(enemy) and self.isAlive and enemy.isAlive then
            self.isAlive = false 
            enemy:takeDamage(10, self.dx, self.dy)
        end
    end


end

function Bullet:drawShadow()

    love.graphics.setColor(0.70, 0.63, 0.52)
    love.graphics.circle("fill", self.x, self.y, self.radius * 1.2)

    love.graphics.setColor(1, 1, 1)
end

function Bullet:draw()
    self:drawSquare(self.x, self.y -self.height, 90, self.radius*1.2)

    --love.graphics.setColor(0.70, 0.63, 0.52)

    love.graphics.rectangle("fill", self.x, self.y -self.height, self.radius, self.radius)
    love.graphics.setColor(1, 1, 1)

    --love.graphics.circle("fill", self.x, self.y -self.height, self.radius)
end

function Bullet:drawSquare(x, y, angle, halfSize)
    local cx, cy = x, y
    local cosA, sinA = math.cos(angle), math.sin(angle)

    local x1 = cx + (-halfSize * cosA - (-halfSize) * sinA)
    local y1 = cy + (-halfSize * sinA + (-halfSize) * cosA)

    local x2 = cx + (halfSize * cosA - (-halfSize) * sinA)
    local y2 = cy + (halfSize * sinA + (-halfSize) * cosA)

    local x3 = cx + (halfSize * cosA - halfSize * sinA)
    local y3 = cy + (halfSize * sinA + halfSize * cosA)

    local x4 = cx + (-halfSize * cosA - halfSize * sinA)
    local y4 = cy + (-halfSize * sinA + halfSize * cosA)

    love.graphics.setLineWidth(0.8)
    love.graphics.setColor(1, 1, 1)

    love.graphics.line(x1, y1, x2, y2)
    love.graphics.line(x2, y2, x3, y3)
    love.graphics.line(x3, y3, x4, y4)
    love.graphics.line(x4, y4, x1, y1)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setLineWidth(1)
end


return Bullet