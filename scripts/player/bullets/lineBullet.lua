local Bullet = {}
Bullet.__index = Bullet

require("scripts/utils")

local Ball = require("scripts/particles/ballParticle")
local GunStarParticle = require("scripts/particles/gunStarParticle")
local BulletColorParticle = require("scripts/particles/bulletColorParticle")
local Tilemap = require("scripts/tilemap")
local DamageNumber = require("scripts/effects/damageNumber")
local wallImpactSoundBase = love.audio.newSource("assets/sfx/gun/empty.mp3", "static")

local defaultTrail = {
    enabled = true,
    trailMaxPoints = 24,
    sampleDistance = 14,
    spawnInterval = 0.03,
    pointLifetime = 0.75,
    fadeDelay = 0.12,
    headDelay = 0.04,
    lineWidth = 1.4,
    glowLineWidth = 6,
    glowAlpha = 0.08,
    headGlowAlpha = 0.18,
    mainAlpha = 0.28,
    rgbAlpha = 0.18,
    rgbShiftPixels = 1,
    lateralOffset = 2.2,
    directionBias = 0.25,
    turnJitter = 0.7,
    turnInterval = 0.04,
    gapChance = 0.2,
    gapLength = 1,
    lineColor = {0.94, 0.98, 1, 1},
    redColor = {1, 0.08, 0.08, 0.85},
    cyanColor = {0.15, 1, 0.28, 0.85},
    glowColor = {0.68, 0.50, 0.26, 1},
    headOuterColor = {0.15, 1, 0.28, 1},
    headMidColor = {1, 0.08, 0.08, 1},
    headInnerColor = {1, 0.96, 0.82, 1}
}

local function playWallImpactSound(volume)
    local sound = wallImpactSoundBase:clone()
    setSourceVolume(sound, volume or 0.11)
    sound:setPitch((1.05 + math.random() * 0.18) * (GAME_PITCH or 1))
    sound:play()
end

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
    lifeTime = 0.5,
    size = 1.1,
}

local GRASS_MARK_INTERVAL = 0.055

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

local function setDrawColor(color, alphaMultiplier)
    love.graphics.setColor(
        color[1],
        color[2],
        color[3],
        (color[4] or 1) * (alphaMultiplier or 1)
    )
end

local function pointAlpha(point)
    local fadeAge = math.max(0, point.age - point.fadeDelay)
    local fadeDuration = math.max(0.001, point.lifetime - point.fadeDelay)
    return 1 - math.min(1, fadeAge / fadeDuration)
end

local function shouldSkipSegment(index, gapSeed, gapChance)
    local value = math.abs(math.sin((index + gapSeed) * 12.9898) * 43758.5453)
    return (value - math.floor(value)) < gapChance
end

local function addPoint(points, point)
    points[#points + 1] = point
end

local function trimTrailPoints(points, maxPoints)
    while #points > maxPoints do
        table.remove(points, 1)
    end
end

local function updateTrailPointList(points, dt)
    for index = #points, 1, -1 do
        local point = points[index]
        point.age = point.age + dt
        if point.age >= point.lifetime then
            table.remove(points, index)
        end
    end
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
    bullet.isActive = true
    bullet.isProjectile = true
    bullet.bodyVisible = true
    bullet.timer = 0
    bullet.lifeTime = options.lifeTime or (0.3 + math.random() * 0.1)
    bullet.lastParticle = 0
    bullet.trail = mergeTables(defaultTrail, options.trail)
    bullet.trail = mergeTables(bullet.trail, options.glow)
    bullet.shadow = mergeTables(defaultShadow, options.shadow)
    bullet.trailSpawnTimer = 0
    bullet.turnTimer = 0
    bullet.lastTrailX = x
    bullet.lastTrailY = y
    bullet.mainPoints = {}
    bullet.redPoints = {}
    bullet.cyanPoints = {}
    bullet.renderPointsScratch = {}
    bullet.impactPoint = nil
    bullet.redTurn = 0
    bullet.cyanTurn = 0
    bullet.impactShockwave = options.impactShockwave
    bullet.projectileSprite = options.projectileSprite
    bullet.colorParticles = mergeTables(defaultColorParticles, options.colorParticles)
    bullet.colorParticles.count = options.colorParticleCount or bullet.colorParticles.count
    bullet.colorParticleTimer = 0
    bullet.colorParticlePalette = BulletColorParticle.getPalette(bullet.projectileSprite, {
        bullet.trail.headInnerColor,
        bullet.trail.headMidColor,
        bullet.trail.headOuterColor,
        bullet.trail.lineColor,
    })
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
    self.lastTrailX = previousX
    self.lastTrailY = previousY
    self.ricochetCount = self.ricochetCount - 1
    self.lifeTime = (self.lifeTime or 0) * 1.1
    self.hitTileOnDeath = false
    if not collision.quiet then
        playWallImpactSound(0.08)
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

function Bullet:updateTrail(dt)
    self.trailSpawnTimer = self.trailSpawnTimer + dt
    self.turnTimer = self.turnTimer + dt

    if self.turnTimer >= self.trail.turnInterval then
        self.turnTimer = 0
        self.redTurn = (math.random() * 2 - 1) * self.trail.turnJitter
        self.cyanTurn = (math.random() * 2 - 1) * self.trail.turnJitter
    end

    updateTrailPointList(self.mainPoints, dt)
    updateTrailPointList(self.redPoints, dt)
    updateTrailPointList(self.cyanPoints, dt)

    if self.impactPoint then
        self.impactPoint.age = self.impactPoint.age + dt
        if self.impactPoint.age >= self.impactPoint.lifetime then
            self.impactPoint = nil
        end
    end
end

function Bullet:recordTrailPoint()
    local dx = self.x - self.lastTrailX
    local dy = self.y - self.lastTrailY
    if self.trailSpawnTimer < self.trail.spawnInterval or dx * dx + dy * dy < self.trail.sampleDistance * self.trail.sampleDistance then
        return
    end

    local centerX = self.x
    local centerY = self.y - self.height
    local dirX = math.cos(self.angle)
    local dirY = math.sin(self.angle)
    local perpX = -dirY
    local perpY = dirX
    local forwardOffset = self.trail.lateralOffset * self.trail.directionBias

    local lifetime = self.trail.pointLifetime
    local fadeDelay = self.trail.fadeDelay

    addPoint(self.mainPoints, {
        x = centerX,
        y = centerY,
        age = 0,
        lifetime = lifetime,
        fadeDelay = fadeDelay
    })
    addPoint(self.redPoints, {
        x = centerX - perpX * self.trail.lateralOffset - dirX * forwardOffset + self.redTurn,
        y = centerY - perpY * self.trail.lateralOffset - dirY * forwardOffset + self.redTurn * 0.2,
        age = 0,
        lifetime = lifetime,
        fadeDelay = fadeDelay
    })
    addPoint(self.cyanPoints, {
        x = centerX + perpX * self.trail.lateralOffset - dirX * forwardOffset + self.cyanTurn,
        y = centerY + perpY * self.trail.lateralOffset - dirY * forwardOffset - self.cyanTurn * 0.2,
        age = 0,
        lifetime = lifetime,
        fadeDelay = fadeDelay
    })

    self.lastTrailX = self.x
    self.lastTrailY = self.y
    self.trailSpawnTimer = 0

    trimTrailPoints(self.mainPoints, self.trail.trailMaxPoints)
    trimTrailPoints(self.redPoints, self.trail.trailMaxPoints)
    trimTrailPoints(self.cyanPoints, self.trail.trailMaxPoints)
end

function Bullet:getRenderPoints(points)
    local result = self.renderPointsScratch or {}
    self.renderPointsScratch = result
    for index = #result, 1, -1 do
        result[index] = nil
    end

    if self.impactPoint then
        result[#result + 1] = self.impactPoint
    end

    for index = #points, 1, -1 do
        local point = points[index]
        if point.age >= self.trail.headDelay then
            result[#result + 1] = point
        end
    end

    return result
end

function Bullet:deactivate()
    if not self.isActive then
        return
    end

    self.isActive = false
    self.bodyVisible = false
    self.impactPoint = {
        x = self.x,
        y = self.y - self.height,
        age = 0,
        lifetime = self.trail.pointLifetime,
        fadeDelay = self.trail.fadeDelay
    }

    if #self.mainPoints == 0 then
        self.isAlive = false
    end
end

function Bullet:update(dt)
    if not self.isAlive then return end

    addToDrawQueue(self.y, self)
    if self.bodyVisible and Game and Game.addLightSource then
        Game:addLightSource("projectile", self.x, self.y - self.height)
    end
    self:updateTrail(dt)

    if self.isActive then
        local previousX = self.x
        local previousY = self.y
        self.x = self.x + self.dx * dt
        self.y = self.y + self.dy * dt
        self:markGrass(dt)
        self.colorParticleTimer = self.colorParticleTimer + dt
        if self.colorParticleTimer >= self.colorParticles.spawnInterval then
            self.colorParticleTimer = 0
            self:spawnColorParticles(self.colorParticles.trailCount)
        end

        self.timer = self.timer + dt
        if self.timer >= self.lifeTime then
            self:deactivate()
            self:death(nil, nil, "expired")
        end

        local collision = self.isActive and self:isColliding() or nil
        if collision then
            if not self:tryRicochet(collision, previousX, previousY) then
                self:deactivate()
                self:death(nil, nil, "wall")
            end
        end

        self:recordTrailPoint()

        local enemy = nil
        if self.isActive and Game.findEnemyCollidingWithShot then
            enemy = Game:findEnemyCollidingWithShot(self, self.radius + 24)
        elseif self.isActive then
            local enemies = Game.getEnemiesNearPoint and Game:getEnemiesNearPoint(self.x, self.y, self.radius + 24) or Game.enemies
            for _, candidate in ipairs(enemies) do
                if candidate.isAlive and not self.ignoredEnemies[candidate] and self:checkCollisionWithEnemy(candidate) then
                    enemy = candidate
                    break
                end
            end
        end

        if enemy and self.isActive then
            DamageNumber.spawn(self.x, self.y, self.height, self.damage)
            enemy:takeDamage(self.damage, self.dx, self.dy)
            self.ignoredEnemies[enemy] = true
            if not self:tryRicochet(self:getEnemyRicochetCollision(enemy), previousX, previousY) then
                self:deactivate()
                self:death(0, 0, "enemy")
            end
        end
    end

    if not self.isActive and #self.mainPoints == 0 and self.impactPoint == nil then
        self.isAlive = false
    end
end

function Bullet:death(dx, dy, reason)
    if self.hitTileOnDeath then
        playWallImpactSound()
        self.hitTileOnDeath = false
    end

    if self.impactShockwave and self.impactShockwave.enabled ~= false and Game and Game.addWeaponShockwave then
        Game:addWeaponShockwave(self.x, self.y - self.height, self.impactShockwave)
    end

    table.insert(Game.particles, GunStarParticle:new(self.x, self.y, self.height, 1.2))
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
    if not self.shadow.enabled or not self.bodyVisible then
        return
    end

    local radius = math.max(self.radius, self.shadow.minRadius)
    love.graphics.setColor(0, 0, 0, self.shadow.alpha)
    love.graphics.ellipse("fill", self.x, self.y, radius * self.shadow.scaleX, radius * self.shadow.scaleY)
    love.graphics.setColor(1, 1, 1, 1)
end

function Bullet:drawTrailLine(points, color, alphaMultiplier, gapSeed)
    local renderPoints = self:getRenderPoints(points)
    if #renderPoints < 2 then
        return
    end

    for index = 1, #renderPoints - 1 do
        local head = renderPoints[index]
        local tail = renderPoints[index + 1]
        local alpha = math.min(pointAlpha(head), pointAlpha(tail))
        local stackAlpha = 1 - (index - 1) / math.max(#renderPoints - 1, 1)
        local gap = shouldSkipSegment(index, gapSeed, self.trail.gapChance)

        if not gap then
            setDrawColor(color, alpha * stackAlpha * alphaMultiplier)
            love.graphics.line(head.x, head.y, tail.x, tail.y)
        end
    end
end

function Bullet:drawTrailGlow(points, color, alphaMultiplier)
    local renderPoints = self:getRenderPoints(points)
    if #renderPoints < 2 then
        return
    end

    love.graphics.setBlendMode("add")
    love.graphics.setLineWidth(self.trail.glowLineWidth)

    for index = 1, #renderPoints - 1 do
        local head = renderPoints[index]
        local tail = renderPoints[index + 1]
        local alpha = math.min(pointAlpha(head), pointAlpha(tail))
        local stackAlpha = 1 - (index - 1) / math.max(#renderPoints - 1, 1)
        setDrawColor(color, alpha * stackAlpha * alphaMultiplier)
        love.graphics.line(head.x, head.y, tail.x, tail.y)
    end

    love.graphics.setLineWidth(1)
    love.graphics.setBlendMode("alpha")
end

function Bullet:drawHeadGlow()
    if not self.bodyVisible then
        return
    end

    local x = self.x
    local y = self.y - self.height
    local pulse = 0.86 + math.sin(self.timer * 48) * 0.14

    love.graphics.setBlendMode("add")
    setDrawColor(self.trail.headOuterColor, self.trail.headGlowAlpha)
    love.graphics.circle("fill", x, y, self.radius * 10 * pulse)
    setDrawColor(self.trail.headMidColor, self.trail.headGlowAlpha * 0.75)
    love.graphics.circle("fill", x, y, self.radius * 6.5 * pulse)
    setDrawColor(self.trail.headInnerColor, self.trail.headGlowAlpha * 1.6)
    love.graphics.circle("fill", x, y, self.radius * 3 * pulse)
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
end

function Bullet:draw()
    local drawCount = Game and ((Game.projectileDrawCount or 0) + 1) or 1
    if Game then
        Game.projectileDrawCount = drawCount
    end
    local manyProjectiles = drawCount > 12 or (Game and Game.enemies and #Game.enemies > 16 and drawCount > 8)

    if not manyProjectiles then
        self:drawTrailGlow(self.redPoints, self.trail.redColor, self.trail.glowAlpha)
        self:drawTrailGlow(self.cyanPoints, self.trail.cyanColor, self.trail.glowAlpha)
    end
    self:drawTrailGlow(self.mainPoints, self.trail.glowColor, self.trail.glowAlpha * 0.8)

    love.graphics.setLineWidth(self.trail.lineWidth)
    if not manyProjectiles then
        self:drawTrailLine(self.redPoints, self.trail.redColor, self.trail.rgbAlpha, 0)
        self:drawTrailLine(self.cyanPoints, self.trail.cyanColor, self.trail.rgbAlpha, 2)
    end
    self:drawTrailLine(self.mainPoints, self.trail.lineColor, self.trail.mainAlpha, 1)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)

    if not self.bodyVisible then
        return
    end

    if not manyProjectiles then
        self:drawHeadGlow()
    end
    self:drawSquare(self.x, self.y - self.height, 90, self.radius * 1.2)

    if self.level >= 2 then return end

    setColor255(0.70, 102, 115)
    local radius = self.radius * 1.4
    love.graphics.rectangle("fill", self.x - radius / 2, self.y - self.height - radius / 2, radius, radius)
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
    love.graphics.setLineWidth(math.max(self.trail.lineWidth or 1, 2))
    self:drawTrailLine(self.mainPoints, {1, 1, 1, 1}, 0.7, 1)
    love.graphics.setLineWidth(1)

    if self.bodyVisible then
        love.graphics.circle("fill", self.x, self.y - self.height, math.max(self.radius * 2, 2.2))
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return Bullet
