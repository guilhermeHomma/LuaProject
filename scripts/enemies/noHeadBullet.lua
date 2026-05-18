local NoHeadBullet = {}
NoHeadBullet.__index = NoHeadBullet

local Tilemap = require("scripts/tilemap")
local GunStarParticle = require("scripts/particles/gunStarParticle")
local BallParticle = require("scripts/particles/ballParticle")

require("scripts/utils")

local bulletSprite = love.graphics.newImage("assets/sprites/enemy/nohead/bullet.png")
local bulletFrameSize = 16
local bulletFrameCount = 4
local bulletFrameDuration = 0.035
local bulletAnimationDuration = bulletFrameDuration * bulletFrameCount
local bulletQuads = {}
local defaultImpactShockwave = {
    enabled = true,
    duration = 0.26,
    radius = 42,
    width = 10,
    intensity = 2.6,
}

bulletSprite:setFilter("nearest", "nearest")

local function getBulletQuad(frameIndex)
    if not bulletQuads[frameIndex] then
        bulletQuads[frameIndex] = love.graphics.newQuad(
            frameIndex * bulletFrameSize,
            0,
            bulletFrameSize,
            bulletFrameSize,
            bulletSprite:getDimensions()
        )
    end

    return bulletQuads[frameIndex]
end

function NoHeadBullet:new(x, y, angle, speed, damage, tileDamage)
    local bullet = setmetatable({}, NoHeadBullet)
    bullet.x = x
    bullet.y = y
    bullet.height = 14
    bullet.angle = angle
    bullet.dx = math.cos(angle) * speed
    bullet.dy = math.sin(angle) * speed
    bullet.damage = damage or 1
    bullet.tileDamage = tileDamage or 10
    bullet.radius = 1.4
    bullet.playerHitRadius = 2.2
    bullet.hitboxHeightOffset = 7
    bullet.spriteTrail = {}
    bullet.spriteTrailDistance = 6
    bullet.spriteTrailRemainder = 0
    bullet.spriteTrailMaxPerUpdate = 6
    bullet.timer = 0
    bullet.lifeTime = 2.4
    bullet.impactTimer = 0
    bullet.impactDuration = bulletAnimationDuration
    bullet.impactShockwave = defaultImpactShockwave
    bullet.isDying = false
    bullet.isAlive = true
    return bullet
end

function NoHeadBullet:spawnSpriteTrailPoint(x, y)
    self.spriteTrail[#self.spriteTrail + 1] = {
        x = x,
        y = y - self.height,
        timer = 0,
    }
end

function NoHeadBullet:spawnSpriteTrail(previousX, previousY)
    local dx = self.x - previousX
    local dy = self.y - previousY
    local traveled = math.sqrt(dx * dx + dy * dy)

    if traveled <= 0 then
        return
    end

    local nextDistance = self.spriteTrailDistance - self.spriteTrailRemainder
    local spawned = 0
    while nextDistance <= traveled and spawned < self.spriteTrailMaxPerUpdate do
        local t = nextDistance / traveled
        self:spawnSpriteTrailPoint(previousX + dx * t, previousY + dy * t)
        nextDistance = nextDistance + self.spriteTrailDistance
        spawned = spawned + 1
    end

    self.spriteTrailRemainder = (self.spriteTrailRemainder + traveled) % self.spriteTrailDistance
end

function NoHeadBullet:updateSpriteTrail(dt)
    for i = #self.spriteTrail, 1, -1 do
        local point = self.spriteTrail[i]
        point.timer = point.timer + dt
        if point.timer >= bulletAnimationDuration then
            table.remove(self.spriteTrail, i)
        end
    end
end

function NoHeadBullet:getBox()
    return self:getBoxWithRadius(self.radius)
end

function NoHeadBullet:getPlayerHitBox()
    return self:getBoxWithRadius(self.playerHitRadius or self.radius)
end

function NoHeadBullet:getBoxWithRadius(radius)
    local size = radius * 2
    return {
        x = self.x - size / 2,
        y = self.y - self.height + (self.hitboxHeightOffset or 0) - size / 2,
        width = size,
        height = size,
    }
end

function NoHeadBullet:hitPlayer()
    if not (Player and Player.isAlive) then
        return false
    end

    local playerBox = Player:getCollisionBox()
    return checkCollision(self:getPlayerHitBox(), playerBox)
end

function NoHeadBullet:collidingTile()
    local box = self:getBox()

    for _, tile in ipairs(Tilemap.tiles or {}) do
        if tile.collider and not tile.isWater then
            local tileBox = {
                x = tile.xWorld - tile.size / 2,
                y = tile.yWorld - tile.size,
                width = tile.size,
                height = tile.size,
            }

            if checkCollision(box, tileBox) then
                return tile
            end
        end
    end

    return nil
end

function NoHeadBullet:hitTile()
    local tile = self:collidingTile()
    if not tile then
        return false
    end

    if type(tile.onshoot) == "function" then
        tile:onshoot(self.tileDamage)
    end

    return true
end

function NoHeadBullet:damagePlayer()
    return Player:takeDamage(self.damage)
end

function NoHeadBullet:death()
    if self.isDying then
        return
    end

    self.isDying = true
    self.impactTimer = 0
    if self.impactShockwave and self.impactShockwave.enabled ~= false and Game and Game.addWeaponShockwave then
        Game:addWeaponShockwave(self.x, self.y - self.height, self.impactShockwave)
    end

    table.insert(Game.particles, GunStarParticle:new(self.x, self.y, self.height, 1))

    for _ = 1, 5 do
        local angle = math.random() * math.pi * 2
        local speed = 0.35 + math.random() * 0.45
        local lifetime = 0.18 + math.random() * 0.18
        local size = 0.35 + math.random() * 0.35
        local particle = BallParticle:new(
            self.x,
            self.y,
            self.height,
            math.cos(angle) * speed,
            math.sin(angle) * speed,
            lifetime,
            size
        )
        table.insert(Game.particles, particle)
    end
end

function NoHeadBullet:update(dt)
    if not self.isAlive and not self.isDying then
        return
    end

    self:updateSpriteTrail(dt)

    if self.isDying then
        self.impactTimer = self.impactTimer + dt
        addToDrawQueue(self.y, self)
        if self.impactTimer >= self.impactDuration then
            self.isDying = false
            self.isAlive = false
        end
        return
    end

    if not (Player and Player.isAlive) then
        self.isAlive = false
        return
    end

    local previousX = self.x
    local previousY = self.y

    self.timer = self.timer + dt
    self.x = self.x + self.dx * dt
    self.y = self.y + self.dy * dt
    self:spawnSpriteTrail(previousX, previousY)

    addToDrawQueue(self.y, self)
    if Game and Game.addLightSource then
        Game:addLightSource("enemyProjectile", self.x, self.y - self.height)
    end

    if self.timer >= self.lifeTime or self:hitTile() then
        self:death()
        return
    end

    if self:hitPlayer() then
        if self:damagePlayer() then
            self:death()
        end
    end
end

function NoHeadBullet:drawShadow()
    love.graphics.setColor(0, 0, 0, 0.12)
    love.graphics.circle("fill", self.x, self.y, self.radius * 1.4)
    love.graphics.setColor(1, 1, 1, 1)
end

function NoHeadBullet:draw()
    local drawX = self.x
    local drawY = self.y - self.height
    local frameIndex = math.floor(self.timer / bulletFrameDuration) % bulletFrameCount
    local bodyAlpha = 1
    local bodyScale = 1

    if self.isDying then
        local progress = math.min(self.impactTimer / self.impactDuration, 1)
        frameIndex = math.min(bulletFrameCount - 1, math.floor(progress * bulletFrameCount))
        bodyAlpha = 1 - progress
        bodyScale = 1 + progress * 0.5
    end

    love.graphics.setColor(1, 1, 1, 1)
    for _, point in ipairs(self.spriteTrail) do
        local trailFrame = math.min(bulletFrameCount - 1, math.floor(point.timer / bulletFrameDuration))
        local alpha = 1 - point.timer / bulletAnimationDuration
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.draw(
            bulletSprite,
            getBulletQuad(trailFrame),
            point.x,
            point.y,
            self.angle,
            1,
            1,
            bulletFrameSize / 2,
            bulletFrameSize / 2
        )
    end

    love.graphics.setColor(1, 1, 1, bodyAlpha)
    love.graphics.draw(
        bulletSprite,
        getBulletQuad(frameIndex),
        drawX,
        drawY,
        self.angle,
        bodyScale,
        bodyScale,
        bulletFrameSize / 2,
        bulletFrameSize / 2
    )

    if DEBUG then
        local tileBox = self:getBox()
        local playerBox = self:getPlayerHitBox()
        love.graphics.setColor(1, 0.2, 0.2, 0.85)
        love.graphics.rectangle("line", tileBox.x, tileBox.y, tileBox.width, tileBox.height)
        love.graphics.setColor(1, 0.85, 0.1, 0.85)
        love.graphics.rectangle("line", playerBox.x, playerBox.y, playerBox.width, playerBox.height)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return NoHeadBullet
