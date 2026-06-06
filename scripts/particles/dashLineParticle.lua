local DashLineParticle = {}
DashLineParticle.__index = DashLineParticle
DashLineParticle.castsShadow = false
DashLineParticle.particleType = "dashLineParticle"
DashLineParticle.isGroundLayer = true

local defaultConfig = {
    enabled = true,
    lifeTime = 0.36,
    fadePower = 1.35,
    jitter = 0.35,
    lines = {
        {
            height = 10,
            squareSize = 3,
            sideOffset = 0,
            color = {1, 1, 1, 0.9},
        },
    },
}

local function copyTable(value)
    if type(value) ~= "table" then
        return value
    end

    local result = {}
    for key, child in pairs(value) do
        result[key] = copyTable(child)
    end
    return result
end

local function mergeTables(base, overrides)
    local result = copyTable(base)
    for key, value in pairs(overrides or {}) do
        if type(value) == "table" and type(result[key]) == "table" then
            result[key] = mergeTables(result[key], value)
        else
            result[key] = copyTable(value)
        end
    end
    return result
end

local function normalize(x, y)
    local length = math.sqrt(x * x + y * y)
    if length <= 0.001 then
        return 1, 0
    end
    return x / length, y / length
end

local function getLineValue(line, config, key)
    if line[key] ~= nil then
        return line[key]
    end
    return config[key]
end

function DashLineParticle:new(x, y, dirX, dirY, line, config)
    local particle = setmetatable({}, DashLineParticle)
    local normalizedX, normalizedY = normalize(dirX or 1, dirY or 0)
    local sideX = -normalizedY
    local sideY = normalizedX
    local jitter = config.jitter or 0
    local jitterOffset = jitter > 0 and (math.random() * 2 - 1) * jitter or 0
    local sideOffset = (line.sideOffset or 0) + jitterOffset

    particle.x = x + sideX * sideOffset
    particle.y = y + sideY * sideOffset
    particle.rotation = math.atan2(normalizedY, normalizedX)
    particle.height = line.height or 0
    particle.size = line.squareSize or 2
    particle.color = line.color or {1, 1, 1, 1}
    particle.lifeTime = getLineValue(line, config, "lifeTime") or defaultConfig.lifeTime
    particle.fadePower = getLineValue(line, config, "fadePower") or defaultConfig.fadePower
    particle.timer = 0
    particle.isAlive = true
    particle.isGroundLayer = true
    particle.affectedByLight = false
    particle.drawPriority = y + 0.35
    return particle
end

function DashLineParticle:queueDraw()
    if Game and Game.groundDecalQueue then
        Game.groundDecalQueue[#Game.groundDecalQueue + 1] = self
    else
        addToDrawQueue(self.drawPriority, self, false)
    end
end

function DashLineParticle:update(dt)
    self.timer = self.timer + dt

    if self.timer >= self.lifeTime then
        self.isAlive = false
    end
end

function DashLineParticle:draw()
    local lifeTime = math.max(self.lifeTime or defaultConfig.lifeTime, 0.001)
    local progress = math.min(self.timer / lifeTime, 1)
    local alphaMultiplier = (1 - progress) ^ (self.fadePower or defaultConfig.fadePower)
    local color = self.color or {1, 1, 1, 1}
    local size = self.size or 2
    local halfSize = size / 2

    love.graphics.setColor(
        color[1] or 1,
        color[2] or 1,
        color[3] or 1,
        (color[4] or 1) * alphaMultiplier
    )

    love.graphics.push()
    love.graphics.translate(math.floor(self.x + 0.5), math.floor(self.y - self.height + 0.5))
    love.graphics.rotate(self.rotation or 0)
    love.graphics.rectangle("fill", -halfSize, -halfSize, size, size)
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

function DashLineParticle:drawShadow()
end

function DashLineParticle.spawn(x, y, dirX, dirY, config)
    if not (Game and Game.particles) then
        return
    end

    config = mergeTables(defaultConfig, config)
    if config.enabled == false then
        return
    end

    for _, line in ipairs(config.lines or defaultConfig.lines) do
        local particle = DashLineParticle:new(x, y, dirX, dirY, line, config)
        table.insert(Game.particles, particle)
        particle:queueDraw()
    end
end

DashLineParticle.defaultConfig = defaultConfig

return DashLineParticle
