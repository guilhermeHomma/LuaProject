
local Drop = require("scripts/drops/drop")
local Life = setmetatable({}, {__index = Drop})
local Tilemap = require("scripts/tilemap")
local Ball = require("scripts/particles/ballParticle")

Life.__index = Life

local sheetImage = love.graphics.newImage("assets/sprites/objects/life-drop.png")

sheetImage:setFilter("nearest", "nearest")
local quads = {}
local sheetWidth = sheetImage:getWidth()
local sheetHeight = sheetImage:getHeight()
local maxAttractDistance = 35
local baseAttractForce = 430

for x = 0, sheetWidth - 8, 8 do
    if x == 0 then 
        table.insert(quads, love.graphics.newQuad(x, 0, 8, 8, sheetWidth, sheetHeight))
        table.insert(quads, love.graphics.newQuad(x, 0, 8, 8, sheetWidth, sheetHeight))
    end

    table.insert(quads, love.graphics.newQuad(x, 0, 8, 8, sheetWidth, sheetHeight))
end

function Life:new(x, y)
    local life = Drop.new(self, x, y)
    setmetatable(life, {__index = self})

    local angle = math.random() * math.pi * 2
    local speed = 35 + math.random() * 0.1
    life.vx = math.cos(angle) * speed
    life.vy = math.sin(angle) * speed
    life.oscillator = math.random() * math.pi * 2
    life.spriteIndex = 1
    life.sprite = quads[life.spriteIndex]
    life.animationTimer = 0
    life.height = 10
    return life
end

function Life:changeHeight(dt)
    self.oscillator = self.oscillator + dt * 4 
    self.height = 10 + math.sin(self.oscillator) * 2.5
end 

function Life:update(dt)
    Drop.update(self, dt)


    self:changeHeight(dt)


    local playerDistance = distance(self, Player)

    if playerDistance < maxAttractDistance then
        local dirX = Player.x - self.x
        local dirY = Player.y - self.y
        local len = math.sqrt(dirX * dirX + dirY * dirY)
        if len > 0 then
            dirX = dirX / len
            dirY = dirY / len
        end

        local factor = 1 - (playerDistance / maxAttractDistance)
        local attractForce = baseAttractForce * factor
        self.vx = self.vx + dirX * attractForce * dt
        self.vy = self.vy + dirY * attractForce * dt
    end

    local moveX = self.vx * dt
    local moveY = self.vy * dt

    local collidedX, collidedY = self:isColliding(moveX,moveY)
    if not collidedX then self.x = self.x + moveX end
    if not collidedY then self.y = self.y + moveY end

    local friction = 5
    self.vx = self.vx - self.vx * friction * dt
    self.vy = self.vy - self.vy * friction * dt

    self:animation(dt)

end


function Life:isColliding(moveX, moveY)
    local futureX = self.x + moveX
    local futureY = self.y + moveY

    local selfBoxX = {x = futureX - 2, y = self.y - 2, width = 4, height = 4}
    local selfBoxY = {x = self.x - 2, y = futureY - 2, width = 4, height = 4}

    local collidedX = false
    local collidedY = false

    for _, tile in ipairs(Tilemap.tiles) do
        if tile.collider and distance(self, tile) < 70 then
            local tileBox = { x = tile.xWorld - tile.size/2, y = tile.yWorld - tile.size, width = tile.size, height = tile.size }

            if checkCollision(selfBoxX, tileBox) then
                collidedX = true
            end
            if checkCollision(selfBoxY, tileBox) then
                collidedY = true
            end
        end
    end

    return collidedX, collidedY
end

function Life:animation(dt)
    self.animationTimer = self.animationTimer + dt

    if self.animationTimer > 0.1 then
        self.animationTimer = 0
        self.spriteIndex = self.spriteIndex + 1
        if self.spriteIndex > #quads then
            self.spriteIndex = 1
        end
        self.sprite = quads[self.spriteIndex]
    end
end

function Life:onCatch()
    if Player then
        Player:catchLife()
    end

    local coinSound = love.audio.newSource("assets/sfx/drops/life-catch.mp3", "static")
    coinSound:setVolume(0.8)
    coinSound:setPitch((1) * GAME_PITCH)
    coinSound:play()
    self:catchParticles()

end

function Life:catchParticles()
    for i = 1, 2 do
        local angle = math.random() * 2 * math.pi

        local dx = math.cos(angle) / 2
        local dy = math.sin(angle) / 2
        
        local lifetime = math.random(20, 30) / 100
        local size = math.random(5, 6) / 10
        local particle = Ball:new(self.x, self.y, self.height,dx, dy, lifetime, size )
        table.insert(Game.particles, particle)
        local particle = Ball:new(self.x, self.y, self.height,-dx, -dy, lifetime, size )
        table.insert(Game.particles, particle)
    end
end

function Life:draw()
    if not self.isAlive then
        return
    end

    local alpha = 1
    if self.lifeTime - self.lifetimeTimer <= 4 then
        local blink = math.floor(self.lifetimeTimer * 10) % 2
        alpha = blink == 0 and 0.2 or 1
    end

    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.draw(sheetImage, self.sprite, self.x, self.y - self.height, 0, 1, 1.4, 4, 8)
    love.graphics.setColor(1, 1, 1, 1)

end

return Life