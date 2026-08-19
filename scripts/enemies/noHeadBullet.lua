local NoHeadBullet = {}
NoHeadBullet.__index = NoHeadBullet

local Tilemap = require("scripts/tilemap")
local GunStarParticle = require("scripts/particles/gunStarParticle")
local BallParticle = require("scripts/particles/ballParticle")
local BulletColorParticle = require("scripts/particles/bulletColorParticle")
local wallImpactSoundBase = love.audio.newSource("assets/sfx/gun/empty.mp3", "static")

require("scripts/utils")

local bulletSprite = love.graphics.newImage("assets/sprites/enemy/nohead/bullet.png")
local bulletSpritePath = "assets/sprites/enemy/nohead/bullet.png"
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
local defaultColorParticles = {
    enabled = true,
    count = 2,
    trailCount = 1,
    spawnInterval = 0.08,
    lifeTime = 0.5,
    size = 1,
}

local GRASS_MARK_INTERVAL = 0.055

bulletSprite:setFilter("nearest", "nearest")

local function playWallImpactSound()
    local sound = wallImpactSoundBase:clone()
    setSourceVolume(sound, 0.12)
    sound:setPitch((1.05 + math.random() * 0.18) * (GAME_PITCH or 1))
    sound:play()
end

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

local function drawBulletSprite(frameIndex, x, y, angle, scale, alpha)
    love.graphics.setColor(1, 1, 1, alpha or 1)
    love.graphics.draw(
        bulletSprite,
        getBulletQuad(frameIndex),
        x,
        y,
        angle,
        scale,
        scale,
        bulletFrameSize / 2,
        bulletFrameSize / 2
    )

    for overlayFrame = frameIndex - 1, 0, -1 do
        love.graphics.draw(
            bulletSprite,
            getBulletQuad(overlayFrame),
            x,
            y,
            angle,
            scale,
            scale,
            bulletFrameSize / 2,
            bulletFrameSize / 2
        )
    end
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
    bullet.spriteTrailDistance = 8
    bullet.spriteTrailRemainder = 0
    bullet.spriteTrailMaxPerUpdate = 3
    bullet.timer = 0
    bullet.lifeTime = 1.1
    bullet.impactTimer = 0
    bullet.impactDuration = bulletAnimationDuration
    bullet.impactShockwave = defaultImpactShockwave
    bullet.colorParticles = defaultColorParticles
    bullet.colorParticleTimer = 0
    bullet.colorParticlePalette = BulletColorParticle.getPalette(bulletSpritePath)
    bullet.arcPeak = 1
    bullet.arcDrop = 6
    bullet.isDying = false
    bullet.isAlive = true
    bullet.isProjectile = true
    bullet.isXrayVisible = true
    bullet.isXrayProjectile = true
    bullet.grassMarkTimer = GRASS_MARK_INTERVAL
    bullet:spawnColorParticles(bullet.colorParticles.count)
    return bullet
end

function NoHeadBullet:spawnColorParticles(count)
    if not (self.colorParticles and self.colorParticles.enabled ~= false) then
        return
    end

    BulletColorParticle.spawnBurst(
        self.x,
        self.y,
        self.height,
        self.colorParticlePalette,
        count or self.colorParticles.count,
        self.colorParticles
    )
end

function NoHeadBullet:markGrass(dt)
    if not Tilemap.markGrassNearPoint then
        return
    end

    self.grassMarkTimer = (self.grassMarkTimer or 0) + dt
    if self.grassMarkTimer < GRASS_MARK_INTERVAL then
        return
    end

    self.grassMarkTimer = 0
    Tilemap:markGrassNearPoint(self.x, self.y, 12, self.x)
end

function NoHeadBullet:spawnSpriteTrailPoint(x, y)
    self.spriteTrail[#self.spriteTrail + 1] = {
        x = x,
        y = y - self.height - (self.arcOffset or 0),
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
    local radius = self.playerHitRadius or self.radius
    local size = radius * 2
    local left = self.x - radius
    local right = self.x + radius
    local top = self.y - self.height + (self.hitboxHeightOffset or 0) - radius
    local bottom = top + size

    return left < playerBox.x + playerBox.width
        and right > playerBox.x
        and top < playerBox.y + playerBox.height
        and bottom > playerBox.y
end

function NoHeadBullet:collidingTile()
    local radius = self.radius
    local size = radius * 2
    local left = self.x - radius
    local right = self.x + radius
    local top = self.y - self.height + (self.hitboxHeightOffset or 0) - radius
    local bottom = top + size

    local nearbyTiles = Tilemap.getNearbyCollidableTiles and Tilemap:getNearbyCollidableTiles(self.x, self.y)
        or Tilemap.getNearbyTiles and Tilemap:getNearbyTiles(self.x, self.y)
        or Tilemap.tiles
    for _, tile in ipairs(nearbyTiles or {}) do
        local tileLeft = tile.xWorld - tile.size / 2
        local tileTop = tile.yWorld - tile.size
        if left < tileLeft + tile.size
            and right > tileLeft
            and top < tileTop + tile.size
            and bottom > tileTop then
            return tile
        end
    end

    return nil
end

function NoHeadBullet:hitTile()
    local tile = self:collidingTile()
    if not tile then
        return false
    end

    self.hitTileOnDeath = true
    if type(tile.onshoot) == "function" then
        tile:onshoot(self.tileDamage or self.damage, { source = "enemyShot" })
    end

    return true
end

function NoHeadBullet:damagePlayer()
    local hitY = self.y - (self.height or 0) + (self.hitboxHeightOffset or 0)
    return Player:takeDamage(self.damage, self.dx or 0, self.dy or 0, self.x, hitY)
end

function NoHeadBullet:death()
    if self.isDying then
        return
    end

    self.isDying = true
    self.impactTimer = 0
    if self.hitTileOnDeath then
        playWallImpactSound()
        self.hitTileOnDeath = false
    end
    if self.impactShockwave and self.impactShockwave.enabled ~= false and Game and Game.addWeaponShockwave then
        Game:addWeaponShockwave(self.x, self.y - self.height, self.impactShockwave)
    end

    table.insert(Game.particles, GunStarParticle:new(self.x, self.y, self.height, 1.2))
    self:spawnColorParticles(math.max(self.colorParticles.count, 1))

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
    local _at = math.min(self.timer / self.lifeTime, 1)
    self.arcOffset = math.sin(_at * math.pi) * (self.arcPeak + self.arcDrop * 0.5) - _at * self.arcDrop
    self:markGrass(dt)
    self:spawnSpriteTrail(previousX, previousY)
    self.colorParticleTimer = self.colorParticleTimer + dt
    if self.colorParticleTimer >= self.colorParticles.spawnInterval then
        self.colorParticleTimer = 0
        self:spawnColorParticles(self.colorParticles.trailCount)
    end

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
    local arc = self.arcOffset or 0
    local drawX = self.x
    local drawY = self.y - self.height - arc
    local frameIndex = math.floor(self.timer / bulletFrameDuration) % bulletFrameCount
    local vs = self.visualScale or 1.2
    local bodyAlpha = 1
    local bodyScale = vs

    if self.isDying then
        local progress = math.min(self.impactTimer / self.impactDuration, 1)
        frameIndex = math.min(bulletFrameCount - 1, math.floor(progress * bulletFrameCount))
        bodyAlpha = 1 - progress
        bodyScale = vs + progress * 0.5
    end

    love.graphics.setColor(1, 1, 1, 1)
    for _, point in ipairs(self.spriteTrail) do
        local trailFrame = math.min(bulletFrameCount - 1, math.floor(point.timer / bulletFrameDuration))
        local alpha = 1 - point.timer / bulletAnimationDuration
        drawBulletSprite(
            trailFrame,
            point.x,
            point.y,
            self.angle,
            vs,
            alpha
        )
    end

    drawBulletSprite(
        frameIndex,
        drawX,
        drawY,
        self.angle,
        bodyScale,
        bodyAlpha
    )

    love.graphics.setColor(1, 1, 1, 1)
end

function NoHeadBullet:drawXray()
    local arc = self.arcOffset or 0
    local frameIndex = math.floor(self.timer / bulletFrameDuration) % bulletFrameCount
    drawBulletSprite(
        frameIndex,
        self.x,
        self.y - self.height - arc,
        self.angle,
        0.8,
        1
    )
end

return NoHeadBullet
