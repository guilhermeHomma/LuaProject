local BloodPixel = {}
BloodPixel.__index = BloodPixel
BloodPixel.castsShadow = false

local bloodPixelScale = 1.35
local maxBloodPixels = 72
local bloodUpdateInterval = 1 / 30
local nextDrawOrder = 0

local palette = {
    {0.46, 0.12, 0.10, 1},
    {0.36, 0.07, 0.08, 1},
    {0.58, 0.20, 0.16, 1},
    {0.28, 0.05, 0.06, 1},
    {0.50, 0.15, 0.13, 1},
}

function BloodPixel:new(x, y, dx, dy, customPalette, scaleMultiplier, options)
    options = options or {}
    local particle = setmetatable({}, BloodPixel)
    local activePalette = customPalette or palette
    local angle = math.atan2(dy or 0, dx or 0)
    local hasDirection = math.abs(dx or 0) + math.abs(dy or 0) > 0.001
    local spread = (math.random() - 0.5) * 1.7

    if not hasDirection then
        angle = math.random() * math.pi * 2
    end

    angle = angle + math.pi + spread

    local speed = 10 + math.random() * 24
    particle.x = x + math.random(-3, 3)
    particle.y = y + math.random(-3, 3)
    particle.height = 4 + math.random() * 7
    particle.vx = math.cos(angle) * speed
    particle.vy = math.sin(angle) * speed * 0.65
    particle.heightVelocity = 18 + math.random() * 18
    particle.gravity = 128 + math.random() * 30
    particle.timer = 0
    local lifeTimeMin = options.lifeTimeMin or 3
    local lifeTimeMax = options.lifeTimeMax or 6
    particle.lifeTime = lifeTimeMin + math.random() * (lifeTimeMax - lifeTimeMin)
    particle.fadeDuration = math.min(options.fadeDuration or 2, particle.lifeTime)
    particle.grounded = false
    particle.groundedTimer = 0
    particle.colorFreezeDelay = 0.16
    particle.palette = activePalette
    particle.colorOffset = math.random(0, #activePalette - 1)
    particle.frozenColor = nil
    particle.isAlive = true
    particle.particleType = "bloodPixel"
    nextDrawOrder = nextDrawOrder + 1
    particle.groundDrawOrder = nextDrawOrder
    particle.pixelScale = bloodPixelScale * (scaleMultiplier or 1)
    particle.parallelKind = "bloodPixel"
    particle.updateInterval = bloodUpdateInterval
    particle.maxUpdateDt = bloodUpdateInterval * 2
    particle.updateAccumulator = bloodUpdateInterval
    return particle
end

function BloodPixel:queueDraw()
    if self.grounded and Game and Game.groundDecalQueue then
        Game.groundDecalQueue[#Game.groundDecalQueue + 1] = self
    else
        addToDrawQueue(self.y + 8, self)
    end
end

function BloodPixel:update(dt)
    self.timer = self.timer + dt
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt

    if not self.grounded then
        self.height = self.height + self.heightVelocity * dt
        self.heightVelocity = self.heightVelocity - self.gravity * dt

        if self.height <= 0 then
            self.height = 0
            self.grounded = true
            self.groundedTimer = 0
            self.vx = self.vx * 0.35
            self.vy = self.vy * 0.35
        end
    else
        self.groundedTimer = (self.groundedTimer or 0) + dt
        if not self.frozenColor and self.groundedTimer >= (self.colorFreezeDelay or 0.16) then
            local activePalette = self.palette or palette
            local colorIndex = (math.floor(self.timer * 12 + self.colorOffset) % #activePalette) + 1
            self.frozenColor = activePalette[colorIndex]
        end

        local friction = math.max(0, 1 - 7 * dt)
        self.vx = self.vx * friction
        self.vy = self.vy * friction
    end

    if self.timer >= self.lifeTime then
        self.isAlive = false
    end
end

function BloodPixel:drawShadow()
end

function BloodPixel:draw()
    local x, y, size, r, g, b, alpha = self:getBatchDrawInfo()
    love.graphics.setColor(r, g, b, alpha)
    love.graphics.rectangle("fill", x, y, size, size)
    love.graphics.setColor(1, 1, 1, 1)
end

function BloodPixel:getBatchDrawInfo()
    local color = self.frozenColor
    local activePalette = self.palette or palette
    if not color then
        local colorIndex = (math.floor(self.timer * 12 + self.colorOffset) % #activePalette) + 1
        color = activePalette[colorIndex]
    end

    local fadeStart = self.lifeTime - self.fadeDuration
    local progress = math.max(0, math.min(1, (self.timer - fadeStart) / self.fadeDuration))
    local alpha = 1 - progress * progress * (3 - 2 * progress)

    return
        math.floor(self.x + 0.5),
        math.floor(self.y - self.height + 0.5),
        self.pixelScale or bloodPixelScale,
        color[1],
        color[2],
        color[3],
        alpha
end

function BloodPixel.spawnBurst(x, y, dx, dy, minCount, maxCount, customPalette, scaleMultiplier, options)
    if not (Game and Game.particles) then
        return
    end

    local count = math.random(minCount or 4, maxCount or minCount or 4)
    local activeCount = 0
    for _, particle in ipairs(Game.particles) do
        if particle.particleType == "bloodPixel" and particle.isAlive then
            activeCount = activeCount + 1
        end
    end

    -- Let existing blood finish fading instead of removing visible particles at the cap.
    count = math.min(count, math.max(0, maxBloodPixels - activeCount))

    for _ = 1, count do
        table.insert(Game.particles, BloodPixel:new(x, y, dx, dy, customPalette, scaleMultiplier, options))
    end
end

function BloodPixel.spawnRadial(x, y, count, customPalette, scaleMultiplier, options)
    if not (Game and Game.particles) then return end
    options = options or {}
    local activeCount = 0
    local bloodIndexes = {}
    for index, particle in ipairs(Game.particles) do
        if particle.particleType == "bloodPixel" and particle.isAlive then
            activeCount = activeCount + 1
            bloodIndexes[#bloodIndexes + 1] = index
        end
    end
    count = math.min(count or 16, maxBloodPixels)
    local overflow = math.max(0, activeCount + count - maxBloodPixels)
    for index = math.min(overflow, #bloodIndexes), 1, -1 do
        table.remove(Game.particles, bloodIndexes[index])
    end
    local startAngle = math.random() * math.pi * 2
    for index = 1, count do
        local angle = startAngle + (index - 1) * math.pi * 2 / count
            + (math.random() - 0.5) * (options.angleJitter or 0.16)
        local speedMin = options.speedMin or 24
        local speedMax = options.speedMax or 48
        local speed = speedMin + math.random() * (speedMax - speedMin)
        local particle = BloodPixel:new(x, y, 0, 0, customPalette, scaleMultiplier, options)
        particle.vx = math.cos(angle) * speed
        particle.vy = math.sin(angle) * speed * 0.65
        particle.heightVelocity = (options.heightVelocityMin or 22)
            + math.random() * ((options.heightVelocityMax or 42) - (options.heightVelocityMin or 22))
        Game.particles[#Game.particles + 1] = particle
    end
end

return BloodPixel
