local Tilemap = require("scripts/tilemap")

local EnemyDeadDropParticle = {}
EnemyDeadDropParticle.__index = EnemyDeadDropParticle

local sprite = love.graphics.newImage("assets/sprites/enemy/deadparticles/particles.png")
sprite:setFilter("nearest", "nearest")

local frameSize = 8
local quads = {}
do
    local sheetWidth = sprite:getWidth()
    local sheetHeight = sprite:getHeight()
    for x = 0, sheetWidth - frameSize, frameSize do
        quads[#quads + 1] = love.graphics.newQuad(x, 0, frameSize, frameSize, sheetWidth, sheetHeight)
    end
end

local function randomRange(minValue, maxValue)
    return minValue + math.random() * (maxValue - minValue)
end

function EnemyDeadDropParticle:new(x, y)
    local angle = math.random() * math.pi * 2
    local speed = randomRange(45, 88)
    local particle = setmetatable({}, EnemyDeadDropParticle)

    particle.x = x
    particle.y = y
    particle.vx = math.cos(angle) * speed
    particle.vy = math.sin(angle) * speed
    particle.height = randomRange(1, 2)
    particle.zVelocity = randomRange(26, 38)
    particle.gravity = randomRange(230, 310)
    particle.bounce = math.random() < 0.72
    particle.bounced = false
    particle.friction = randomRange(3.2, 4.4)
    particle.lifeTime = randomRange(2.2, 4.8)
    particle.timer = 0
    particle.alpha = 1
    particle.scale = randomRange(1.1, 1.2)
    particle.rotation = 0
    particle.quad = quads[math.random(1, #quads)]
    particle.isAlive = true
    particle.particleType = "enemyDeadDrop"
    particle.squashTimer = 0.16
    particle.squashDuration = 0.16
    return particle
end

function EnemyDeadDropParticle:isColliding(moveX, moveY)
    local futureX = self.x + moveX
    local futureY = self.y + moveY
    local boxSize = 4
    local halfSize = boxSize / 2
    local boxXLeft = futureX - halfSize
    local boxXRight = futureX + halfSize
    local boxXTop = self.y - halfSize
    local boxXBottom = self.y + halfSize
    local boxYLeft = self.x - halfSize
    local boxYRight = self.x + halfSize
    local boxYTop = futureY - halfSize
    local boxYBottom = futureY + halfSize
    local collidedX = false
    local collidedY = false

    local closeTiles = Tilemap.getNearbyCollidableTiles and Tilemap:getNearbyCollidableTiles(self.x, self.y)
        or Tilemap:getNearbyTiles(self.x, self.y)
    for _, tile in ipairs(closeTiles) do
        local tileLeft = tile.xWorld - tile.size / 2
        local tileRight = tileLeft + tile.size
        local tileTop = tile.yWorld - tile.size
        local tileBottom = tileTop + tile.size

        if boxXLeft < tileRight and boxXRight > tileLeft and boxXTop < tileBottom and boxXBottom > tileTop then
            collidedX = true
        end
        if boxYLeft < tileRight and boxYRight > tileLeft and boxYTop < tileBottom and boxYBottom > tileTop then
            collidedY = true
        end
    end

    return collidedX, collidedY
end

function EnemyDeadDropParticle:update(dt)
    addToDrawQueue(self.y + 4, self)

    self.timer = self.timer + dt
    local moveX = self.vx * dt
    local moveY = self.vy * dt
    local isSettled = self.height <= 0
        and math.abs(self.vx) + math.abs(self.vy) < 3
        and math.abs(self.zVelocity) < 1
    local collidedX, collidedY = false, false

    if not isSettled then
        collidedX, collidedY = self:isColliding(moveX, moveY)
    else
        moveX, moveY = 0, 0
    end

    if collidedX then
        self.vx = -self.vx * 0.22
    else
        self.x = self.x + moveX
    end

    if collidedY then
        self.vy = -self.vy * 0.22
    else
        self.y = self.y + moveY
    end

    local drag = math.max(0, 1 - self.friction * dt)
    self.vx = self.vx * drag
    self.vy = self.vy * drag

    self.height = self.height + self.zVelocity * dt
    self.zVelocity = self.zVelocity - self.gravity * dt
    if self.height <= 0 then
        self.height = 0
        if self.bounce and not self.bounced and math.abs(self.zVelocity) > 46 then
            self.bounced = true
            self.zVelocity = math.abs(self.zVelocity) * randomRange(0.26, 0.38)
            self.squashTimer = self.squashDuration
        else
            self.zVelocity = 0
        end
    end

    self.squashTimer = math.max(0, self.squashTimer - dt)
    if self.timer > self.lifeTime * 0.72 then
        self.alpha = math.max(0, 1 - ((self.timer - self.lifeTime * 0.72) / (self.lifeTime * 0.28)))
    end

    if self.timer >= self.lifeTime then
        self.isAlive = false
    end
end

function EnemyDeadDropParticle:drawShadow()
    if not self.isAlive then
        return
    end

    love.graphics.setColor(0, 0, 0, 0.4 * self.alpha)
    love.graphics.ellipse("fill", self.x, self.y, 2.4 * self.scale, 1.1 * self.scale)
    love.graphics.setColor(1, 1, 1, 1)
end

function EnemyDeadDropParticle:draw()
    if not self.isAlive then
        return
    end

    local stretch = 0
    if self.squashTimer > 0 then
        local progress = 1 - self.squashTimer / self.squashDuration
        stretch = math.sin(progress * math.pi) * 0.16
    end

    love.graphics.setColor(1, 1, 1, self.alpha)
    love.graphics.draw(
        sprite,
        self.quad,
        self.x,
        self.y - self.height,
        self.rotation,
        self.scale * (1 + stretch),
        self.scale * (1 - stretch),
        frameSize / 2,
        frameSize / 2
    )
    love.graphics.setColor(1, 1, 1, 1)
end

return EnemyDeadDropParticle
