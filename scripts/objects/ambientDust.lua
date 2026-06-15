local AmbientDust = {}
AmbientDust.__index = AmbientDust

local DEFAULT_DRIFT_MIN_X = -18
local DEFAULT_DRIFT_MAX_X = -12
local DEFAULT_DRIFT_MIN_Y = -5
local DEFAULT_DRIFT_MAX_Y = 4
local DEFAULT_DRIFT_DISTANCE = 220
local DEFAULT_BOB_AMOUNT_MIN = 4
local DEFAULT_BOB_AMOUNT_MAX = 8

local DEFAULT_BOB_SPEED_MIN = 1
local DEFAULT_BOB_SPEED_MAX = 2
local DEFAULT_LIFE_MIN = 3.4
local DEFAULT_LIFE_MAX = 6.4
local DEFAULT_SPREAD_X = 22
local DEFAULT_SPREAD_Y = 15
local DEFAULT_ALPHA_MIN = 0.12
local DEFAULT_ALPHA_MAX = 0.34
local DEFAULT_SIZE_MIN = 0.8
local DEFAULT_SIZE_MAX = 1.8
local DEFAULT_FOREGROUND_RATIO = 0.34
local DEFAULT_FOREGROUND_SPEED_MULTIPLIER = 1.35
local DEFAULT_FOREGROUND_SIZE_MULTIPLIER = 1.45
local DEFAULT_FOREGROUND_ALPHA_MULTIPLIER = 0.9
local DEFAULT_WHITE_CHANCE = 0.08
local DEFAULT_DRAW_PRIORITY = 100000
local DEFAULT_COLOR = {0.50, 0.54, 0.60}
local DEFAULT_BRIGHT_COLOR = {0.86, 0.90, 0.98}

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
    local bright = math.random() < (config.whiteChance or DEFAULT_WHITE_CHANCE)
    local color = bright and (config.brightColor or DEFAULT_BRIGHT_COLOR)
        or (config.color or DEFAULT_COLOR)
    local bobPhase = math.random() * math.pi * 2
    local bobAmount = randomRange(config.bobAmountMin or DEFAULT_BOB_AMOUNT_MIN, config.bobAmountMax or DEFAULT_BOB_AMOUNT_MAX)
    local lifeMax = config.lifeMax or DEFAULT_LIFE_MAX
    local foreground = math.random() < (config.foregroundRatio or DEFAULT_FOREGROUND_RATIO)
    local speedMultiplier = foreground and (config.foregroundSpeedMultiplier or DEFAULT_FOREGROUND_SPEED_MULTIPLIER) or 1
    local sizeMultiplier = foreground and (config.foregroundSizeMultiplier or DEFAULT_FOREGROUND_SIZE_MULTIPLIER) or 1
    local alphaMultiplier = foreground and (config.foregroundAlphaMultiplier or DEFAULT_FOREGROUND_ALPHA_MULTIPLIER) or 1
    local scaledBobAmount = bobAmount * sizeMultiplier

    return {
        x = anchor.x + randomRange(-(config.spreadX or DEFAULT_SPREAD_X), config.spreadX or DEFAULT_SPREAD_X),
        y = anchor.y + randomRange(-(config.spreadY or DEFAULT_SPREAD_Y), config.spreadY or DEFAULT_SPREAD_Y),
        startX = anchor.x,
        startY = anchor.y,
        vx = randomRange(config.driftMinX or DEFAULT_DRIFT_MIN_X, config.driftMaxX or DEFAULT_DRIFT_MAX_X) * speedMultiplier,
        vy = randomRange(config.driftMinY or DEFAULT_DRIFT_MIN_Y, config.driftMaxY or DEFAULT_DRIFT_MAX_Y) * speedMultiplier,
        bobPhase = bobPhase,
        bobSpeed = randomRange(config.bobSpeedMin or DEFAULT_BOB_SPEED_MIN, config.bobSpeedMax or DEFAULT_BOB_SPEED_MAX) * speedMultiplier,
        bobAmount = scaledBobAmount,
        bobOffset = math.sin(bobPhase) * scaledBobAmount,
        size = randomRange(config.sizeMin or DEFAULT_SIZE_MIN, config.sizeMax or DEFAULT_SIZE_MAX) * sizeMultiplier,
        alpha = randomRange(config.alphaMin or DEFAULT_ALPHA_MIN, config.alphaMax or DEFAULT_ALPHA_MAX) * alphaMultiplier,
        life = randomRange(config.lifeMin or DEFAULT_LIFE_MIN, lifeMax),
        timer = math.random() * lifeMax,
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
    dust.drawPriority = dust.config.drawPriority or DEFAULT_DRAW_PRIORITY

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

    local windMultiplier = WIND_AMBIENCE_MULTIPLIER or 1
    local windIntensity = WIND_AMBIENCE_INTENSITY or 1
    local motionDt = dt * windMultiplier

    if Player then
        self.x = Player.x
        self.y = Player.y
    end

    for index, particle in ipairs(self.particles) do
        particle.timer = particle.timer + motionDt
        local bobOffset = math.sin(particle.timer * particle.bobSpeed + particle.bobPhase) * particle.bobAmount * windIntensity
        particle.x = particle.x + particle.vx * motionDt * windIntensity
        particle.y = particle.y + particle.vy * motionDt * windIntensity + (bobOffset - particle.bobOffset)
        particle.bobOffset = bobOffset

        local dx = particle.x - particle.startX
        local dy = particle.y - particle.startY
        local driftLimit = self.config.driftDistance or DEFAULT_DRIFT_DISTANCE
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
        local size = math.max(1, math.floor(particle.size + 0.5))
        local width = size / math.max(WORLD_SCALE_X or 1, 0.001)
        local height = size / math.max(YSCALE or 1, 0.001)
        love.graphics.setColor(particle.color[1], particle.color[2], particle.color[3], alpha)
        love.graphics.rectangle("fill", math.floor(particle.x + 0.5), math.floor(particle.y + 0.5), width, height)
    end

    love.graphics.setBlendMode(previousBlendMode, previousAlphaMode)
    love.graphics.setColor(1, 1, 1, 1)
end

function AmbientDust:drawShadow()
end

return AmbientDust
