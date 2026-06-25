
local Drop = require("scripts/drops/drop")
local Life = setmetatable({}, {__index = Drop})
local Tilemap = require("scripts/tilemap")
local Ball = require("scripts/particles/ballParticle")
local DropShine = require("scripts/drops/dropShine")
local PickupNumber = require("scripts/effects/damageNumber")

Life.__index = Life

local sheetImage = love.graphics.newImage("assets/sprites/objects/life-drop.png")

sheetImage:setFilter("nearest", "nearest")
local quads = {}
local sheetWidth = sheetImage:getWidth()
local sheetHeight = sheetImage:getHeight()
local maxAttractDistance = 35
local baseAttractForce = 430
local spawnCollisionAvoidRadius = 28
local spawnCollisionAvoidForce = 58

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
    life.baseHeight = 10
    life.hoverHeight = life.baseHeight
    life.popHeight = math.random(7, 12)
    life.popVelocity = 55 + math.random() * 25
    life.popGravity = 260
    life.popBounces = 0
    life.popMaxBounces = 1
    life.spawnStretchTimer = 0.22
    life.spawnStretchDuration = 0.22
    life.drawScaleX = 1
    life.drawScaleY = 1.25
    life.collectDuration = 0.16
    life.height = life.hoverHeight + life.popHeight
    if not self.disableSpawnCollisionPush then
        life:pushAwayFromSpawnCollisions()
    end
    return life
end

function Life:pushAwayFromSpawnCollisions(force)
    force = force or spawnCollisionAvoidForce

    if not (Tilemap and Tilemap.getNearbyTiles) then
        return
    end

    local pushX = 0
    local pushY = 0
    local nearbyTiles = Tilemap:getNearbyTiles(self.x, self.y)

    for _, tile in ipairs(nearbyTiles) do
        if tile.collider then
            local dx = self.x - tile.xWorld
            local dy = self.y - tile.yWorld
            local distanceSq = dx * dx + dy * dy

            if distanceSq > 0.001 and distanceSq < spawnCollisionAvoidRadius * spawnCollisionAvoidRadius then
                local dist = math.sqrt(distanceSq)
                local weight = 1 - dist / spawnCollisionAvoidRadius
                pushX = pushX + (dx / dist) * weight
                pushY = pushY + (dy / dist) * weight
            end
        end
    end

    local length = math.sqrt(pushX * pushX + pushY * pushY)
    if length <= 0 then
        return
    end

    self.vx = (self.vx or 0) + (pushX / length) * force
    self.vy = (self.vy or 0) + (pushY / length) * force
end

function Life:changeHeight(dt)
    local speed = self.hoverSpeed or 4
    local amplitude = self.hoverAmplitude or 2.5
    self.oscillator = self.oscillator + dt * speed
    self.hoverHeight = (self.baseHeight or 10) + math.sin(self.oscillator) * amplitude
end 

function Life:updateBaseHeight(dt)
    if not self.targetBaseHeight then
        return
    end

    local current = self.baseHeight or self.targetBaseHeight
    local target = self.targetBaseHeight
    local speed = self.baseHeightRiseSpeed or 18
    local step = speed * dt

    if math.abs(target - current) <= step then
        self.baseHeight = target
        self.targetBaseHeight = nil
        return
    end

    self.baseHeight = current + (target > current and step or -step)
end

function Life:updateSpawnMotion(dt)
    if self.spawnStretchTimer and self.spawnStretchTimer > 0 then
        self.spawnStretchTimer = math.max(0, self.spawnStretchTimer - dt)
    end

    if (self.popHeight or 0) > 0 or (self.popVelocity or 0) ~= 0 then
        self.popHeight = (self.popHeight or 0) + (self.popVelocity or 0) * dt
        self.popVelocity = (self.popVelocity or 0) - (self.popGravity or 260) * dt

        if self.popHeight <= 0 then
            self.popHeight = 0
            if (self.popBounces or 0) < (self.popMaxBounces or 0) and math.abs(self.popVelocity or 0) > 45 then
                self.popBounces = (self.popBounces or 0) + 1
                self.popVelocity = math.abs(self.popVelocity or 0) * 0.34
                self.spawnStretchTimer = math.max(self.spawnStretchTimer or 0, 0.12)
            else
                self.popVelocity = 0
                if self.raiseBaseHeightAfterPop and self.idleBaseHeight then
                    self.targetBaseHeight = self.idleBaseHeight
                    self.raiseBaseHeightAfterPop = false
                end
            end
        end
    end

    self.height = (self.hoverHeight or self.baseHeight or 0) + (self.popHeight or 0)
end

function Life:getDrawScale()
    local scaleX = self.drawScaleX or 1
    local scaleY = self.drawScaleY or 1.25

    if self.isCollecting then
        local progress = math.min((self.collectTimer or 0) / (self.collectDuration or 0.16), 1)
        local stretch = math.sin(progress * math.pi)
        local shrink = 1 - progress
        scaleX = scaleX * (0.28 + shrink * 0.72) * (1 + stretch * 0.22)
        scaleY = scaleY * (0.26 + shrink * 0.74) * (1 - stretch * 0.14)
        return scaleX, scaleY
    end

    if self.spawnStretchTimer and self.spawnStretchTimer > 0 then
        local progress = 1 - self.spawnStretchTimer / (self.spawnStretchDuration or 0.22)
        local wave = math.sin(progress * math.pi)
        scaleX = scaleX * (1 + wave * 0.16)
        scaleY = scaleY * (1 - wave * 0.12)
    end

    return scaleX, scaleY
end

function Life:update(dt)
    if Drop.update(self, dt) then
        return
    end


    self:updateBaseHeight(dt)
    self:changeHeight(dt)
    self:updateSpawnMotion(dt)


    local playerDistance = distance(self, Player)

    if not self.requirePickupKey and playerDistance < maxAttractDistance then
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

function Life:startCollectAnimation()
    self.isCollecting = true
    self.collectTimer = 0
    self.vx = 0
    self.vy = 0
end

function Life:updateCollectAnimation(dt)
    self.collectTimer = (self.collectTimer or 0) + dt
    self.height = (self.hoverHeight or self.baseHeight or 0) + (self.popHeight or 0)

    if self.collectTimer >= (self.collectDuration or 0.16) then
        self.isAlive = false
        self.isCollecting = false
        self:onCatch()
    end
end


function Life:isColliding(moveX, moveY)
    local futureX = self.x + moveX
    local futureY = self.y + moveY

    local selfBoxX = {x = futureX - 2, y = self.y - 2, width = 4, height = 4}
    local selfBoxY = {x = self.x - 2, y = futureY - 2, width = 4, height = 4}

    local collidedX = false
    local collidedY = false

    local closeTiles = Tilemap:getNearbyTiles(self.x, self.y)
    for _, tile in ipairs(closeTiles) do
        if tile.collider then
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
    local recoveredLife = 0
    if Player then
        recoveredLife = Player:catchLife() or 0
    end

    local coinSound = love.audio.newSource("assets/sfx/drops/life-catch.mp3", "static")
    setSourceVolume(coinSound, 0.8)
    coinSound:setPitch((1) * GAME_PITCH)
    coinSound:play()
    if recoveredLife > 0 then
        local recoveredHearts = recoveredLife / 2
        PickupNumber.spawnPickup(self.x, self.y, self.height, nil, "life", {
            value = recoveredHearts,
            decimals = 1,
        })
    end

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
    if not self.neverExpires and self.lifeTime - self.lifetimeTimer <= 4 then
        local blink = math.floor(self.lifetimeTimer * 10) % 2
        alpha = blink == 0 and 0.2 or 1
    end

    love.graphics.setColor(1, 1, 1, alpha)
    local scaleX, scaleY = self:getDrawScale()
    local drawY = self.y - self.height
    if self.isCollecting then
        local baseScaleY = self.drawScaleY or 1.25
        drawY = drawY + 4 * (baseScaleY - scaleY)
    end
    DropShine.draw(sheetImage, self.sprite, self.x, drawY, 0, scaleX, scaleY, 4, 8)
    love.graphics.setColor(1, 1, 1, 1)

end

function Life:drawXray()
    if not self.isAlive then
        return
    end

    local scaleX, scaleY = self:getDrawScale()
    local drawY = self.y - self.height
    if self.isCollecting then
        local baseScaleY = self.drawScaleY or 1.25
        drawY = drawY + 4 * (baseScaleY - scaleY)
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(sheetImage, self.sprite, self.x, drawY, 0, scaleX, scaleY, 4, 8)
end

return Life
