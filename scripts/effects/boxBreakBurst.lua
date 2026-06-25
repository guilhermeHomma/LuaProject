local BoxBreakBurst = {}

local Ball = require("scripts/particles/ballParticle")
local BoxParticle = require("scripts/particles/boxParticle")
local FootStep = require("scripts/particles/footstep")
local BloodPixel = require("scripts/particles/bloodPixel")

local boxPixelPalette = {
    {0.62, 0.60, 0.54, 1},
    {0.50, 0.49, 0.44, 1},
    {0.42, 0.41, 0.37, 1},
    {0.70, 0.66, 0.56, 1},
    {0.36, 0.35, 0.32, 1},
}

local mortarBallOptions = {
    sizeMultiplier = 1.15,
    speedMultiplier = 1.4,
    speedDownMultiplier = 1.4,
}

local function addParticle(particle)
    if Game and Game.particles then
        table.insert(Game.particles, particle)
    end
end

function BoxBreakBurst.spawn(x, y, options)
    if not (Game and Game.particles and x and y) then
        return
    end

    options = options or {}
    BloodPixel.spawnBurst(
        x,
        y + (options.pixelOffsetY or -5),
        options.pixelDx or 0,
        options.pixelDy or -1,
        options.pixelMinCount or 10,
        options.pixelMaxCount or 16,
        options.pixelPalette or boxPixelPalette
    )

    local pairCount = options.ballPairCount or 3
    for _ = 1, pairCount do
        local angle = math.random() * 2 * math.pi
        local dx = math.cos(angle)
        local dy = math.sin(angle)
        local lifetime = math.random(40, 50) / 100
        local size = math.random(8, 10) / 10

        addParticle(Ball:new(x, y, options.ballHeight or 1, dx, dy, lifetime, size, options.ballOptions or mortarBallOptions))
        addParticle(Ball:new(x, y, options.ballHeight or 1, -dx, -dy, lifetime, size, options.ballOptions or mortarBallOptions))
    end

    if options.footstep ~= false and Game.footsteps then
        table.insert(Game.footsteps, FootStep:new(x, y + (options.footstepOffsetY or -8)))
    end

    if options.boxParticle ~= false then
        addParticle(BoxParticle:new(x, y + (options.boxParticleOffsetY or 0)))
    end
end

return BoxBreakBurst
