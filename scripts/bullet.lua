local Bullet = {}
Bullet.__index = Bullet

require("scripts/utils")

local Particle = require("scripts/particles/particle")
local Ball = require("scripts/particles/ballParticle")
local Tilemap = require("scripts/tilemap")

function Bullet:new(x, y, angle, height, speed, damage, level)

    if not level then level = 1 end

    local angle = angle
    local bullet = setmetatable({}, Bullet)
    
    bullet.level = level
    bullet.height = height
    bullet.damage = damage +  (level-1)*5
    bullet.x = x
    bullet.y = y
    bullet.dx = math.cos(angle) * speed
    bullet.dy = math.sin(angle) * speed
    bullet.angle = angle
    bullet.radius = 1.3
    bullet.isAlive = true
    bullet.timer = 0
    bullet.lastParticle = 0
    bullet.lifeTime = 0.3 + math.random() * 0.1

    return bullet
end

function Bullet:checkCollisionWithEnemy(enemy)
    local dx = self.x - enemy.x
    local dy = self.y - enemy.y
    local distance = math.sqrt(dx * dx + dy * dy)

    return distance < (self.radius + 6)
end


function Bullet:isColliding(size)
    if not size then size = 4 end

    local box = { x = self.x - size/2, y = self.y - size/2, width = size, height = size }
    
    for _, tile in ipairs(Tilemap.tiles) do
        if tile.collider and not tile.isWater then
            local tileBox = { x = tile.xWorld - tile.size/2, y = tile.yWorld - tile.size, width = tile.size, height = tile.size }

            if checkCollision(box, tileBox) then
                if type(tile.onshoot) == "function" then
                    tile:onshoot()
                end
                return true
            end
        end
    end

    return false
end

function Bullet:update(dt)
    if not self.isAlive then return end

    self.x = self.x + self.dx * dt
    self.y = self.y + self.dy * dt

    addToDrawQueue(self.y, self)

    self.timer = self.timer + dt

    if self.timer >= self.lifeTime then
        self.isAlive = false
    end

    if self:isColliding() then
        local bulletSound = love.audio.newSource("assets/sfx/bullet.mp3", "static")
        bulletSound:setVolume(0.2)
        bulletSound:setPitch((1.4 + math.random() * 0.1) * GAME_PITCH)
        bulletSound:play()
        self.isAlive = false

        self:death()
    end

    self.lastParticle = self.lastParticle + dt
    if self.lastParticle > 0.005 then
        self.lastParticle = 0
        local particle = Particle:new(self.x, self.y, self.height-2, 1.2, 0.07)
        table.insert(Game.particles, particle)
    end

    for _, enemy in ipairs(Game.enemies) do
        if self:checkCollisionWithEnemy(enemy) and self.isAlive and enemy.isAlive then
            self.isAlive = false 
            enemy:takeDamage(self.damage, self.dx, self.dy)
            self:death(0, 0)
        end
    end
end

function Bullet:death(dx, dy)
    if not dy or not dy then
        dx = math.cos(self.angle) / 2
        dy = math.sin(self.angle) / 2
    end

    local lifetime = math.random(15, 23) / 100
    local particle = Ball:new(self.x, self.y, 5, -dx, -dy, lifetime, 0.6)
    table.insert(Game.particles, particle)

    if math.random() > 0.5 then
        local particle = Ball:new(self.x, self.y, 5, -dx + 1, -dy + 1, lifetime, 0.6)
        table.insert(Game.particles, particle)
    end
end

function Bullet:drawShadow()

    love.graphics.setColor(0.70, 0.63, 0.52)
    love.graphics.circle("fill", self.x, self.y, self.radius * 1.2)

    love.graphics.setColor(1, 1, 1)
end

function Bullet:draw()
    self:drawSquare(self.x, self.y -self.height, 90, self.radius*1.2)

    if self.level >= 2 then return end

    setColor255(0.70, 102, 115)

    local radius = self.radius * 1.4

    love.graphics.rectangle("fill", self.x- radius/2, self.y -self.height - radius/2, radius, radius)
    
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
    if self.level == 2 then
        setColor255(0.70, 102, 115)

    end

    love.graphics.line(x1, y1, x2, y2)
    love.graphics.line(x2, y2, x3, y3)
    love.graphics.line(x3, y3, x4, y4)
    love.graphics.line(x4, y4, x1, y1)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setLineWidth(1)
end


return Bullet