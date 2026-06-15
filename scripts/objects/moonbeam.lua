local Moonbeam = {}
Moonbeam.__index = Moonbeam

local DEFAULT_DUST_DRIFT_MIN_X = -32
local DEFAULT_DUST_DRIFT_MAX_X = -14
local DEFAULT_DUST_DRIFT_MIN_Y = -5
local DEFAULT_DUST_DRIFT_MAX_Y = 4
local DEFAULT_DUST_DRIFT_DISTANCE = 220
local DEFAULT_DUST_BOB_AMOUNT_MIN = 4
local DEFAULT_DUST_BOB_AMOUNT_MAX = 11
local DEFAULT_DUST_BOB_SPEED_MIN = 2.2
local DEFAULT_DUST_BOB_SPEED_MAX = 4.8
local DEFAULT_DUST_LIFE_MIN = 3.4
local DEFAULT_DUST_LIFE_MAX = 6.4

local function randomRange(minValue, maxValue)
    return minValue + math.random() * (maxValue - minValue)
end

local function copyColor(color, fallback)
    color = color or fallback or {1, 1, 1, 1}
    return {
        color[1] or 1,
        color[2] or 1,
        color[3] or 1,
        color[4] or 1,
    }
end

local function clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

local function smoothstep(edge0, edge1, value)
    local t = clamp((value - edge0) / (edge1 - edge0), 0, 1)
    return t * t * (3 - 2 * t)
end

local function smootherstep(edge0, edge1, value)
    local t = clamp((value - edge0) / (edge1 - edge0), 0, 1)
    return t * t * t * (t * (t * 6 - 15) + 10)
end

local function getScreenFade(worldY, config)
    if not camera then
        return 1
    end

    local fadeStart = (config.screenFadeStart or 0.40) * baseHeight
    local fadeEnd = (config.screenFadeEnd or 0.75) * baseHeight
    local screenY = (worldY * YSCALE - camera.y) * (camera.zoomY or 1)
    return 1 - smoothstep(fadeStart, fadeEnd, screenY)
end

local function makeDustParticle(beam)
    local progress = math.random()
    local widthOffset = randomRange(-beam.width * 0.45, beam.width * 0.45)
    local x = beam.startX + beam.dx * progress + widthOffset
    local y = beam.startY + beam.dy * progress + randomRange(-8, 8)
    local bright = math.random() < (beam.config.dustWhiteChance or 0.18)
    local bobPhase = math.random() * math.pi * 2
    local bobAmount = randomRange(beam.config.dustBobAmountMin or DEFAULT_DUST_BOB_AMOUNT_MIN, beam.config.dustBobAmountMax or DEFAULT_DUST_BOB_AMOUNT_MAX)
    local lifeMax = beam.config.dustLifeMax or DEFAULT_DUST_LIFE_MAX

    return {
        x = x,
        y = y,
        startX = x,
        startY = y,
        vx = randomRange(beam.config.dustDriftMinX or DEFAULT_DUST_DRIFT_MIN_X, beam.config.dustDriftMaxX or DEFAULT_DUST_DRIFT_MAX_X),
        vy = randomRange(beam.config.dustDriftMinY or DEFAULT_DUST_DRIFT_MIN_Y, beam.config.dustDriftMaxY or DEFAULT_DUST_DRIFT_MAX_Y),
        bobPhase = bobPhase,
        bobSpeed = randomRange(beam.config.dustBobSpeedMin or DEFAULT_DUST_BOB_SPEED_MIN, beam.config.dustBobSpeedMax or DEFAULT_DUST_BOB_SPEED_MAX),
        bobAmount = bobAmount,
        bobOffset = math.sin(bobPhase) * bobAmount,
        radius = randomRange(beam.config.dustRadiusMin or 0.45, beam.config.dustRadiusMax or 1.1),
        alpha = randomRange(beam.config.dustAlphaMin or 0.16, beam.config.dustAlphaMax or 0.34),
        color = bright and copyColor(beam.config.dustBrightColor, {0.88, 0.92, 1, 1})
            or copyColor(beam.config.dustColor, {0.58, 0.62, 0.68, 1}),
        life = randomRange(beam.config.dustLifeMin or DEFAULT_DUST_LIFE_MIN, lifeMax),
        timer = math.random() * lifeMax,
    }
end

function Moonbeam:new(x, y, config)
    config = config or {}

    local beam = setmetatable({}, Moonbeam)
    beam.x = x
    beam.y = y
    beam.config = config
    beam.width = (config.width or randomRange(config.widthMin or 50, config.widthMax or 74)) * (config.widthScale or 1)
    beam.length = config.length or randomRange(config.lengthMin or 110, config.lengthMax or 160)
    beam.groundGap = config.groundGap or randomRange(config.groundGapMin or 10, config.groundGapMax or 18)
    beam.angle = math.rad(config.angleDegrees or 75)
    beam.dy = beam.length * math.sin(beam.angle)
    beam.dx = beam.length * math.cos(beam.angle)
    beam.endX = x
    beam.endY = y - beam.groundGap
    beam.startX = beam.endX - beam.dx
    beam.startY = beam.endY - beam.dy
    beam.drawPriority = beam.y + (config.ySortOffset or 0)
    beam.isAlive = true
    beam.spatialRadius = math.max(260, beam.length + beam.width)
    beam.flickerTimer = math.random() * 10
    beam.dust = {}
    beam.stripes = {}

    local stripeCount = math.random(config.stripeCountMin or 4, config.stripeCountMax or 7)
    for _ = 1, stripeCount do
        beam.stripes[#beam.stripes + 1] = {
            offsetScale = randomRange(-0.42, 0.42),
            widthScale = randomRange(config.stripeWidthMin or 0.22, config.stripeWidthMax or 0.52),
            alphaScale = randomRange(config.stripeAlphaMin or 0.18, config.stripeAlphaMax or 0.42),
        }
    end

    local dustCount = math.random(config.dustCountMin or 7, config.dustCountMax or 13)
    for _ = 1, dustCount do
        beam.dust[#beam.dust + 1] = makeDustParticle(beam)
    end

    return beam
end

function Moonbeam:updateDust(dt)
    for i, particle in ipairs(self.dust) do
        particle.timer = particle.timer + dt
        local bobOffset = math.sin(particle.timer * particle.bobSpeed + particle.bobPhase) * particle.bobAmount
        particle.x = particle.x + particle.vx * dt
        particle.y = particle.y + particle.vy * dt + (bobOffset - particle.bobOffset)
        particle.bobOffset = bobOffset

        local driftX = particle.x - particle.startX
        local driftY = particle.y - particle.startY
        local driftLimit = self.config.dustDriftDistance or DEFAULT_DUST_DRIFT_DISTANCE
        if particle.timer >= particle.life or driftX * driftX + driftY * driftY > driftLimit * driftLimit then
            self.dust[i] = makeDustParticle(self)
        end
    end
end

function Moonbeam:update(dt)
    self.flickerTimer = self.flickerTimer + dt
    self:updateDust(dt)

    if Game and Game.addLightSource then
        local screenFade = getScreenFade(self.y, self.config)
        Game:addLightSource("moonbeam", self.x, self.y, {
            flicker = (0.92 + math.sin(self.flickerTimer * 0.55) * 0.04) * screenFade,
        })
    end

    addToDrawQueue(self.drawPriority, self, false)
end

local function getBeamFade(beam, progress)
    local config = beam.config
    local topFadeStart = config.topFadeStart or 0.02
    local topFadeEnd = config.topFadeEnd or config.topFade or 0.52
    local bottomFadeStart = config.bottomFadeStart or 0.48
    local topAlpha = smootherstep(topFadeStart, topFadeEnd, progress)
    local bottomAlpha = 1 - smoothstep(bottomFadeStart, 1, progress)

    return topAlpha * bottomAlpha
end

local function drawBeamRibbon(beam, offsetScale, widthScale, alphaScale)
    local config = beam.config
    local normalX = -math.sin(beam.angle)
    local normalY = math.cos(beam.angle)
    local halfWidth = beam.width * widthScale * 0.5
    local offset = beam.width * offsetScale
    local color = config.color or {0.72, 0.82, 0.94, 1}
    local baseAlpha = (config.alpha or 0.095) * alphaScale
    local segments = config.fadeSegments or 28

    for index = 1, segments do
        local t0 = (index - 1) / segments
        local t1 = index / segments
        local tm = (t0 + t1) * 0.5
        local midY = beam.startY + beam.dy * tm + normalY * offset
        local alpha = baseAlpha * getBeamFade(beam, tm) * getScreenFade(midY, config)

        if alpha > 0.002 then
            local x0 = beam.startX + beam.dx * t0 + normalX * offset
            local y0 = beam.startY + beam.dy * t0 + normalY * offset
            local x1 = beam.startX + beam.dx * t1 + normalX * offset
            local y1 = beam.startY + beam.dy * t1 + normalY * offset

            love.graphics.setColor(color[1] or 1, color[2] or 1, color[3] or 1, alpha)
            love.graphics.polygon(
                "fill",
                x0 + normalX * halfWidth,
                y0 + normalY * halfWidth,
                x0 - normalX * halfWidth,
                y0 - normalY * halfWidth,
                x1 - normalX * halfWidth,
                y1 - normalY * halfWidth,
                x1 + normalX * halfWidth,
                y1 + normalY * halfWidth
            )
        end
    end
end

function Moonbeam:drawDust()
    for _, particle in ipairs(self.dust) do
        local lifeProgress = math.min(particle.timer / particle.life, 1)
        local alpha = particle.alpha * (1 - lifeProgress) * getScreenFade(particle.y, self.config)
        local size = math.max(1, math.floor(particle.radius + 0.5))
        local width = size / math.max(WORLD_SCALE_X or 1, 0.001)
        local height = size / math.max(YSCALE or 1, 0.001)
        if alpha > 0.002 then
            love.graphics.setColor(particle.color[1], particle.color[2], particle.color[3], alpha)
            love.graphics.rectangle("fill", math.floor(particle.x + 0.5), math.floor(particle.y + 0.5), width, height)
        end
    end
end

function Moonbeam:draw()
    local previousBlendMode, previousAlphaMode = love.graphics.getBlendMode()
    local flicker = 0.96 + math.sin(self.flickerTimer * 0.55) * 0.04

    love.graphics.setBlendMode("add", "alphamultiply")
    drawBeamRibbon(self, 0, 2.1, 0.10 * flicker)
    for _, stripe in ipairs(self.stripes) do
        drawBeamRibbon(self, stripe.offsetScale, stripe.widthScale, stripe.alphaScale * flicker)
    end
    self:drawDust()

    love.graphics.setBlendMode(previousBlendMode, previousAlphaMode)
    love.graphics.setColor(1, 1, 1, 1)
end

function Moonbeam:drawShadow()
end

return Moonbeam
