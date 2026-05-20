local Bullet = {}
Bullet.__index = Bullet

require("scripts/utils")

local Ball = require("scripts/particles/ballParticle")
local GunStarParticle = require("scripts/particles/gunStarParticle")
local BulletColorParticle = require("scripts/particles/bulletColorParticle")
local Tilemap = require("scripts/tilemap")
local DamageNumber = require("scripts/effects/damageNumber")

local defaultTrail = {
    enabled = true,
    trailMaxPoints = 36,
    sampleDistance = 10,
    spawnInterval = 0.02,
    pointLifetime = 1.0,
    fadeDelay = 0.12,
    headDelay = 0.04,
    lineWidth = 1.4,
    glowLineWidth = 8,
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

local defaultShadow = {
    enabled = true,
    alpha = 0.12,
    scaleX = 1.8,
    scaleY = 0.7,
    minRadius = 2.2
}

local defaultColorParticles = {
    enabled = true,
    count = 2,
    trailCount = 1,
    spawnInterval = 0.07,
    lifeTime = 0.5,
    size = 1,
}

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
    table.insert(points, 1, point)
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
    local dist = distance(self, enemy)
    local dist2 = distance({x = enemy.x, y = enemy.y - 6}, self)
    local dist3 = distance({x = enemy.x, y = enemy.y - 12}, self)

    return dist < (self.radius + 6)
        or dist2 < (self.radius + 6)
        or dist3 < (self.radius + 8)
end

function Bullet:isColliding(size)
    size = size or 4
    local box = { x = self.x - size / 2, y = self.y - size / 2, width = size, height = size }

    local nearbyTiles = Tilemap.getNearbyTiles and Tilemap:getNearbyTiles(self.x, self.y) or Tilemap.tiles
    for _, tile in ipairs(nearbyTiles or {}) do
        if tile.collider and not tile.isWater then
            local tileBox = {
                x = tile.xWorld - tile.size / 2,
                y = tile.yWorld - tile.size,
                width = tile.size,
                height = tile.size
            }

            if checkCollision(box, tileBox) then
                local damaged = false
                if type(tile.onshoot) == "function" then
                    damaged = tile:onshoot(self.damage) == true
                end
                if damaged then
                    DamageNumber.spawn(self.x, self.y, self.height, self.damage)
                end
                return true
            end
        end
    end

    return false
end

function Bullet:updateTrail(dt)
    self.trailSpawnTimer = self.trailSpawnTimer + dt
    self.turnTimer = self.turnTimer + dt

    if self.turnTimer >= self.trail.turnInterval then
        self.turnTimer = 0
        self.redTurn = (math.random() * 2 - 1) * self.trail.turnJitter
        self.cyanTurn = (math.random() * 2 - 1) * self.trail.turnJitter
    end

    for _, list in ipairs({self.mainPoints, self.redPoints, self.cyanPoints}) do
        for index = #list, 1, -1 do
            local point = list[index]
            point.age = point.age + dt
            if point.age >= point.lifetime then
                table.remove(list, index)
            end
        end
    end

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
    if self.trailSpawnTimer < self.trail.spawnInterval or math.sqrt(dx * dx + dy * dy) < self.trail.sampleDistance then
        return
    end

    local pointBase = {
        age = 0,
        lifetime = self.trail.pointLifetime,
        fadeDelay = self.trail.fadeDelay
    }

    local centerX = self.x
    local centerY = self.y - self.height
    local dirX = math.cos(self.angle)
    local dirY = math.sin(self.angle)
    local perpX = -dirY
    local perpY = dirX
    local forwardOffset = self.trail.lateralOffset * self.trail.directionBias

    addPoint(self.mainPoints, mergeTables(pointBase, { x = centerX, y = centerY }))
    addPoint(self.redPoints, mergeTables(pointBase, {
        x = centerX - perpX * self.trail.lateralOffset - dirX * forwardOffset + self.redTurn,
        y = centerY - perpY * self.trail.lateralOffset - dirY * forwardOffset + self.redTurn * 0.2
    }))
    addPoint(self.cyanPoints, mergeTables(pointBase, {
        x = centerX + perpX * self.trail.lateralOffset - dirX * forwardOffset + self.cyanTurn,
        y = centerY + perpY * self.trail.lateralOffset - dirY * forwardOffset - self.cyanTurn * 0.2
    }))

    self.lastTrailX = self.x
    self.lastTrailY = self.y
    self.trailSpawnTimer = 0

    while #self.mainPoints > self.trail.trailMaxPoints do table.remove(self.mainPoints) end
    while #self.redPoints > self.trail.trailMaxPoints do table.remove(self.redPoints) end
    while #self.cyanPoints > self.trail.trailMaxPoints do table.remove(self.cyanPoints) end
end

function Bullet:getRenderPoints(points)
    local result = {}
    if self.impactPoint then
        result[#result + 1] = self.impactPoint
    end

    for _, point in ipairs(points) do
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
        self.x = self.x + self.dx * dt
        self.y = self.y + self.dy * dt
        self.colorParticleTimer = self.colorParticleTimer + dt
        if self.colorParticleTimer >= self.colorParticles.spawnInterval then
            self.colorParticleTimer = 0
            self:spawnColorParticles(self.colorParticles.trailCount)
        end

        self.timer = self.timer + dt
        if self.timer >= self.lifeTime then
            self:deactivate()
            self:death()
        end

        if self.isActive and self:isColliding() then
            self:deactivate()
            self:death()
        end

        self:recordTrailPoint()

        for _, enemy in ipairs(Game.enemies) do
            if self:checkCollisionWithEnemy(enemy) and self.isActive and enemy.isAlive then
                self:deactivate()
                DamageNumber.spawn(self.x, self.y, self.height, self.damage)
                enemy:takeDamage(self.damage, self.dx, self.dy)
                self:death(0, 0)
                break
            end
        end
    end

    if not self.isActive and #self.mainPoints == 0 and self.impactPoint == nil then
        self.isAlive = false
    end
end

function Bullet:death(dx, dy)
    if self.impactShockwave and self.impactShockwave.enabled ~= false and Game and Game.addWeaponShockwave then
        Game:addWeaponShockwave(self.x, self.y - self.height, self.impactShockwave)
    end

    table.insert(Game.particles, GunStarParticle:new(self.x, self.y, self.height, 1))
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
    self:drawTrailGlow(self.redPoints, self.trail.redColor, self.trail.glowAlpha)
    self:drawTrailGlow(self.cyanPoints, self.trail.cyanColor, self.trail.glowAlpha)
    self:drawTrailGlow(self.mainPoints, self.trail.glowColor, self.trail.glowAlpha * 0.8)

    love.graphics.setLineWidth(self.trail.lineWidth)
    self:drawTrailLine(self.redPoints, self.trail.redColor, self.trail.rgbAlpha, 0)
    self:drawTrailLine(self.cyanPoints, self.trail.cyanColor, self.trail.rgbAlpha, 2)
    self:drawTrailLine(self.mainPoints, self.trail.lineColor, self.trail.mainAlpha, 1)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)

    if not self.bodyVisible then
        return
    end

    self:drawHeadGlow()
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

return Bullet
