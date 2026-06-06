local Bullet = {}
Bullet.__index = Bullet

require("scripts/utils")

local Particle = require("scripts/particles/particle")
local Ball = require("scripts/particles/ballParticle")
local GunStarParticle = require("scripts/particles/gunStarParticle")
local BulletSpriteParticle = require("scripts/particles/bulletSpriteParticle")
local BulletColorParticle = require("scripts/particles/bulletColorParticle")
local Tilemap = require("scripts/tilemap")
local DamageNumber = require("scripts/effects/damageNumber")
local wallImpactSoundBase = love.audio.newSource("assets/sfx/gun/empty.mp3", "static")

local defaultGlow = {
    enabled = true,
    outerColor = {0.15, 1, 0.28, 0.12},
    midColor = {1, 0.08, 0.08, 0.16},
    innerColor = {1, 0.96, 0.82, 0.35},
    outerScale = 4,
    midScale = 0.65,
    innerScale = 2.2,
    pulseSpeed = 42,
    pulseAmount = 0.15
}

local defaultShadow = {
    enabled = true,
    alpha = 0.12,
    scaleX = 1.8,
    scaleY = 0.7,
    minRadius = 2.2
}

local defaultColorParticles = {
    enabled = true,
    count = 1,
    trailCount = 1,
    spawnInterval = 0.1,
    lifeTime = 0.35,
    size = 1.1,
}

local GRASS_MARK_INTERVAL = 0.055

local function playWallImpactSound(x, y, volume)
    local sound = wallImpactSoundBase:clone()
    sound:setVolume(volume or 0.12)
    sound:setPitch((1.05 + math.random() * 0.18) * (GAME_PITCH or 1))
    sound:play()
end

local function copyTable(source)
    local result = {}
    for key, value in pairs(source) do
        if type(value) == "table" then
            result[key] = copyTable(value)
        else
            result[key] = value
        end
    end
    return result
end

local function mergeTables(base, overrides)
    local result = copyTable(base)
    if not overrides then
        return result
    end

    for key, value in pairs(overrides) do
        if type(value) == "table" and type(result[key]) == "table" then
            result[key] = mergeTables(result[key], value)
        else
            result[key] = value
        end
    end

    return result
end

local function setGlowColor(color)
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
end

local function isPointInCircleSq(px, py, cx, cy, radius)
    local dx = px - cx
    local dy = py - cy
    return dx * dx + dy * dy < radius * radius
end

local function getTileCollisionNormal(x, y, tile)
    local tileLeft = tile.xWorld - tile.size / 2
    local tileTop = tile.yWorld - tile.size
    local tileRight = tileLeft + tile.size
    local tileBottom = tileTop + tile.size
    local overlapLeft = x - tileLeft
    local overlapRight = tileRight - x
    local overlapTop = y - tileTop
    local overlapBottom = tileBottom - y
    local minOverlap = math.min(overlapLeft, overlapRight, overlapTop, overlapBottom)

    if minOverlap == overlapLeft then
        return -1, 0
    elseif minOverlap == overlapRight then
        return 1, 0
    elseif minOverlap == overlapTop then
        return 0, -1
    end

    return 0, 1
end

function Bullet:new(x, y, angle, height, speed, damage, options)
    if type(options) ~= "table" then
        options = { level = options }
    end

    options = options or {}

    local bullet = setmetatable({}, Bullet)
    bullet.level = options.level or 1
    bullet.height = height
    bullet.damage = damage + (bullet.level - 1) * 5
    bullet.x = x
    bullet.y = y
    bullet.dx = math.cos(angle) * speed
    bullet.dy = math.sin(angle) * speed
    bullet.angle = angle
    bullet.radius = options.radius or 1.1
    bullet.isAlive = true
    bullet.isProjectile = true
    bullet.timer = 0
    bullet.lastParticle = 0
    bullet.lifeTime = options.lifeTime or (0.3 + math.random() * 0.1)
    bullet.glow = mergeTables(defaultGlow, options.glow)
    bullet.shadow = mergeTables(defaultShadow, options.shadow)
    bullet.projectileSprite = options.projectileSprite
    bullet.spriteTrailDistance = math.max(options.spriteTrailDistance or 8, 8)
    bullet.spriteTrailLifetime = options.spriteTrailLifetime or 0.13
    bullet.spriteTrailScale = options.spriteTrailScale or 0.75
    bullet.spriteTrailRemainder = 0
    bullet.spriteTrailMaxPerUpdate = math.min(options.spriteTrailMaxPerUpdate or 3, 3)
    bullet.impactFlashSprite = options.impactFlashSprite
    bullet.impactShockwave = options.impactShockwave
    bullet.colorParticles = mergeTables(defaultColorParticles, options.colorParticles)
    bullet.colorParticles.count = options.colorParticleCount or bullet.colorParticles.count
    bullet.colorParticleTimer = 0
    bullet.colorParticlePalette = BulletColorParticle.getPalette(bullet.projectileSprite, {
        bullet.glow.innerColor,
        bullet.glow.midColor,
        bullet.glow.outerColor,
    })
    bullet.arcPeak = options.arcPeak or 1
    bullet.arcDrop = options.arcDrop or 6
    bullet.isXrayVisible = false
    bullet.isXrayProjectile = false
    bullet.ricochetCount = options.ricochetCount or 0
    bullet.deathSpawnCount = options.deathSpawnCount or 0
    bullet.onDeathSpawn = options.onDeathSpawn
    bullet.ignoredEnemies = options.ignoredEnemies or {}
    bullet.grassMarkTimer = GRASS_MARK_INTERVAL

    if bullet.colorParticles.enabled ~= false then
        bullet:spawnColorParticles(bullet.colorParticles.count)
    end

    return bullet
end

function Bullet:spawnColorParticles(count)
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

function Bullet:spawnSpriteTrailPoint(x, y)
    if Game then
        local currentCount = Game.bulletSpriteParticleCount or 0
        if currentCount >= 32 then
            return
        end
        Game.bulletSpriteParticleCount = currentCount + 1
    end

    table.insert(Game.particles, BulletSpriteParticle:new(
        x,
        y - (self.arcOffset or 0),
        self.height,
        self.projectileSprite,
        self.angle,
        self.spriteTrailLifetime,
        self.spriteTrailScale
    ))
end

function Bullet:spawnSpriteTrail(previousX, previousY)
    if not self.projectileSprite then
        return
    end

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

function Bullet:checkCollisionWithEnemy(enemy)
    if enemy.checkShotCollision then
        return enemy:checkShotCollision(self)
    end

    if enemy.getShotCollisionCircles then
        for _, circle in ipairs(enemy:getShotCollisionCircles()) do
            if isPointInCircleSq(self.x, self.y, circle.x, circle.y, self.radius + (circle.radius or 6)) then
                return true
            end
        end

        return false
    end

    return isPointInCircleSq(self.x, self.y, enemy.x, enemy.y, self.radius + 6)
        or isPointInCircleSq(self.x, self.y, enemy.x, enemy.y - 6, self.radius + 6)
        or isPointInCircleSq(self.x, self.y, enemy.x, enemy.y - 12, self.radius + 8)
end

function Bullet:getEnemyRicochetCollision(enemy)
    local normalX = self.x - (enemy.x or self.x)
    local normalY = self.y - (enemy.y or self.y)
    local length = math.sqrt(normalX * normalX + normalY * normalY)

    if length <= 0.001 then
        normalX = -self.dx
        normalY = -self.dy
        length = math.sqrt(normalX * normalX + normalY * normalY)
    end
    if length <= 0.001 then
        return { normalX = -1, normalY = 0, quiet = true }
    end

    return {
        normalX = normalX / length,
        normalY = normalY / length,
        quiet = true,
    }
end

function Bullet:isColliding(size)
    size = size or 4
    local halfSize = size / 2
    local left = self.x - halfSize
    local right = self.x + halfSize
    local top = self.y - halfSize
    local bottom = self.y + halfSize

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
            self.hitTileOnDeath = true
            local normalX, normalY = getTileCollisionNormal(self.x, self.y, tile)
            local damaged = false
            if type(tile.onshoot) == "function" then
                damaged = tile:onshoot(self.damage) == true
            end
            if damaged then
                DamageNumber.spawn(self.x, self.y, self.height, self.damage)
            end
            return { normalX = normalX, normalY = normalY }
        end
    end

    return false
end

function Bullet:tryRicochet(collision, previousX, previousY)
    if (self.ricochetCount or 0) <= 0 or not collision then
        return false
    end

    local normalX = collision.normalX or 0
    local normalY = collision.normalY or 0
    local normalLength = math.sqrt(normalX * normalX + normalY * normalY)
    if normalLength <= 0.001 then
        return false
    end

    normalX = normalX / normalLength
    normalY = normalY / normalLength
    local dot = self.dx * normalX + self.dy * normalY
    self.dx = self.dx - 2 * dot * normalX
    self.dy = self.dy - 2 * dot * normalY
    self.angle = math.atan2(self.dy, self.dx)
    self.x = previousX
    self.y = previousY
    self.ricochetCount = self.ricochetCount - 1
    self.lifeTime = (self.lifeTime or 0) * 1.1
    self.hitTileOnDeath = false
    if not collision.quiet then
        playWallImpactSound(self.x, self.y, 0.08)
    end
    self:spawnColorParticles(1)
    return true
end

function Bullet:markGrass(dt)
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

function Bullet:update(dt)
    if not self.isAlive then return end

    local previousX = self.x
    local previousY = self.y

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
        Game:addLightSource("projectile", self.x, self.y - self.height)
    end

    self.timer = self.timer + dt
    if self.timer >= self.lifeTime then
        self.isAlive = false
        self:death(nil, nil, "expired")
        return
    end

    local collision = self:isColliding()
    if collision then
        if not self:tryRicochet(collision, previousX, previousY) then
            self.isAlive = false
            self:death(nil, nil, "wall")
            return
        end
    end

    self.lastParticle = self.lastParticle + dt
    if not self.projectileSprite and self.lastParticle > 0.015 then
        self.lastParticle = 0
        table.insert(Game.particles, Particle:new(self.x, self.y, self.height - 2 + (self.arcOffset or 0), 1.2, 0.07))
    end

    local enemy = nil
    if Game.findEnemyCollidingWithShot then
        enemy = Game:findEnemyCollidingWithShot(self, self.radius + 24)
    else
        local enemies = Game.getEnemiesNearPoint and Game:getEnemiesNearPoint(self.x, self.y, self.radius + 24) or Game.enemies
        for _, candidate in ipairs(enemies) do
            if candidate.isAlive and not self.ignoredEnemies[candidate] and self:checkCollisionWithEnemy(candidate) then
                enemy = candidate
                break
            end
        end
    end

    if enemy and self.isAlive then
        DamageNumber.spawn(self.x, self.y, self.height, self.damage)
        enemy:takeDamage(self.damage, self.dx, self.dy)
        self.ignoredEnemies[enemy] = true
        if not self:tryRicochet(self:getEnemyRicochetCollision(enemy), previousX, previousY) then
            self.isAlive = false
            self:death(0, 0, "enemy")
        end
    end
end

function Bullet:death(dx, dy, reason)
    if self.hitTileOnDeath then
        playWallImpactSound(self.x, self.y)
        self.hitTileOnDeath = false
    end

    if self.impactShockwave and self.impactShockwave.enabled ~= false and Game and Game.addWeaponShockwave then
        Game:addWeaponShockwave(self.x, self.y - self.height, self.impactShockwave)
    end

    table.insert(Game.particles, GunStarParticle:new(self.x, self.y, self.height, 1.1, self.impactFlashSprite))
    self:spawnColorParticles(math.max(self.colorParticles.count, 1))

    if not dy or not dx then
        dx = math.cos(self.angle) / 2
        dy = math.sin(self.angle) / 2
    end

    local lifetime = math.random(15, 23) / 100
    table.insert(Game.particles, Ball:new(self.x, self.y, 5, -dx, -dy, lifetime, 0.6, {
        rgbShift = { duration = 0.1, shift = 1 }
    }))

    if math.random() > 0.5 then
        table.insert(Game.particles, Ball:new(self.x, self.y, 5, -dx + 1, -dy + 1, lifetime, 0.6, {
            rgbShift = { duration = 0.1, shift = 1 }
        }))
    end

    if self.onDeathSpawn and reason == "expired" and (self.deathSpawnCount or 0) > 0 then
        self:onDeathSpawn(reason or "expired")
    end
end

function Bullet:drawShadow()
    if not self.shadow.enabled then
        return
    end

    local radius = math.max(self.radius, self.shadow.minRadius)
    love.graphics.setColor(0, 0, 0, self.shadow.alpha)
    love.graphics.ellipse("fill", self.x, self.y, radius * self.shadow.scaleX, radius * self.shadow.scaleY)
    love.graphics.setColor(1, 1, 1, 1)
end

function Bullet:drawGlow()
    if not self.glow.enabled then
        return
    end

    local arc = self.arcOffset or 0
    local x = self.x
    local y = self.y - self.height - arc
    local pulse = 1 - self.glow.pulseAmount + math.sin(self.timer * self.glow.pulseSpeed) * self.glow.pulseAmount
    local outerRadius = self.radius * self.glow.outerScale * pulse
    local innerRadius = self.radius * self.glow.innerScale * pulse

    love.graphics.setBlendMode("add")
    local drawCount = Game and (Game.projectileDrawCount or 0) or 0
    if drawCount <= 12 then
        setGlowColor(self.glow.outerColor)
        love.graphics.circle("fill", x, y, outerRadius)
        setGlowColor(self.glow.midColor)
        love.graphics.circle("fill", x, y, outerRadius * self.glow.midScale)
    end
    setGlowColor(self.glow.innerColor)
    love.graphics.circle("fill", x, y, innerRadius)
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
end

function Bullet:draw()
    if Game then
        Game.projectileDrawCount = (Game.projectileDrawCount or 0) + 1
    end

    local arc = self.arcOffset or 0
    if self.projectileSprite then
        local progress = (self.timer % self.spriteTrailLifetime) / self.spriteTrailLifetime
        local frameIndex = math.floor(math.min(0.999, progress) * 5)
        BulletSpriteParticle.drawSprite(
            self.projectileSprite,
            self.x,
            self.y - self.height - arc,
            self.angle,
            frameIndex,
            1,
            self.spriteTrailScale
        )
        return
    end

    self:drawGlow()
    self:drawSquare(self.x, self.y - self.height - arc, 90, self.radius * 1.2)

    if self.level >= 2 then return end

    setColor255(0.70, 102, 115)
    local radius = self.radius * 1.4
    love.graphics.rectangle("fill", self.x - radius / 2, self.y - self.height - arc - radius / 2, radius, radius)
    love.graphics.setColor(1, 1, 1, 1)
end

function Bullet:onDestroy()
    self.death = true
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
    love.graphics.setColor(1, 1, 1, 1)
    if self.level == 2 then
        setColor255(0.70, 102, 115)
    end

    love.graphics.line(x1, y1, x2, y2)
    love.graphics.line(x2, y2, x3, y3)
    love.graphics.line(x3, y3, x4, y4)
    love.graphics.line(x4, y4, x1, y1)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

function Bullet:drawXray()
    local arc = self.arcOffset or 0
    local drawX = self.x
    local drawY = self.y - self.height - arc

    if self.projectileSprite then
        local progress = (self.timer % self.spriteTrailLifetime) / self.spriteTrailLifetime
        local frameIndex = math.floor(math.min(0.999, progress) * 5)
        BulletSpriteParticle.drawSprite(
            self.projectileSprite,
            drawX,
            drawY,
            self.angle,
            frameIndex,
            1,
            self.spriteTrailScale
        )
        return
    end

    love.graphics.circle("fill", drawX, drawY, math.max(self.radius * 1.8, 2.2))
end

return Bullet
