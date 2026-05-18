local AmbientDust = {}
AmbientDust.__index = AmbientDust

local function randomRange(minValue, maxValue)
    return minValue + math.random() * (maxValue - minValue)
end

local function chooseAnchor(anchors)
    if not anchors or #anchors == 0 then
        return {x = 0, y = 0}
    end

    return anchors[math.random(1, #anchors)]
end

local function makeParticle(dust)
    local config = dust.config
    local anchor = chooseAnchor(dust.anchors)
    local bright = math.random() < (config.whiteChance or 0.10)
    local color = bright and (config.brightColor or {0.86, 0.9, 0.98})
        or (config.color or {0.50, 0.54, 0.60})

    return {
        x = anchor.x + randomRange(-(config.spreadX or 12), config.spreadX or 12),
        y = anchor.y + randomRange(-(config.spreadY or 8), config.spreadY or 8),
        startX = anchor.x,
        startY = anchor.y,
        vx = randomRange(config.driftMinX or -2.2, config.driftMaxX or -0.45),
        vy = randomRange(config.driftMinY or -0.15, config.driftMaxY or 0.25),
        size = randomRange(config.sizeMin or 0.6, config.sizeMax or 1.2),
        alpha = randomRange(config.alphaMin or 0.08, config.alphaMax or 0.20),
        life = randomRange(config.lifeMin or 2.8, config.lifeMax or 5.8),
        timer = math.random() * (config.lifeMax or 5.8),
        color = color,
    }
end

function AmbientDust:new(anchors, config)
    local dust = setmetatable({}, AmbientDust)
    dust.anchors = anchors or {}
    dust.config = config or {}
    dust.isAlive = true
    dust.particles = {}
    dust.x = 0
    dust.y = 0
    dust.drawPriority = dust.config.drawPriority or -100000

    local count = math.min(#dust.anchors, dust.config.count or 24)
    for _ = 1, count do
        dust.particles[#dust.particles + 1] = makeParticle(dust)
    end

    return dust
end

function AmbientDust:update(dt)
    if #self.anchors == 0 then
        return
    end

    if Player then
        self.x = Player.x
        self.y = Player.y
    end

    for index, particle in ipairs(self.particles) do
        particle.timer = particle.timer + dt
        particle.x = particle.x + particle.vx * dt
        particle.y = particle.y + particle.vy * dt

        local dx = particle.x - particle.startX
        local dy = particle.y - particle.startY
        local driftLimit = self.config.driftDistance or 22
        if particle.timer >= particle.life or dx * dx + dy * dy > driftLimit * driftLimit then
            self.particles[index] = makeParticle(self)
        end
    end

    addToDrawQueue(self.drawPriority, self, false)
end

function AmbientDust:draw()
    local previousBlendMode, previousAlphaMode = love.graphics.getBlendMode()
    love.graphics.setBlendMode("add", "alphamultiply")

    for _, particle in ipairs(self.particles) do
        local progress = math.min(particle.timer / particle.life, 1)
        local alpha = particle.alpha * math.sin(progress * math.pi)
        local size = math.max(1, particle.size)
        love.graphics.setColor(particle.color[1], particle.color[2], particle.color[3], alpha)
        love.graphics.rectangle("fill", math.floor(particle.x + 0.5), math.floor(particle.y + 0.5), size, size)
    end

    love.graphics.setBlendMode(previousBlendMode, previousAlphaMode)
    love.graphics.setColor(1, 1, 1, 1)
end

function AmbientDust:drawShadow()
end

return AmbientDust
