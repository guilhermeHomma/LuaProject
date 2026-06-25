local CardPickupEffects = {}

local BoxBreakBurst = require("scripts/effects/boxBreakBurst")

function CardPickupEffects.init(player)
    player.cardPickupFlashDuration = 0.42
    player.cardPickupFlashTimer = 0
end

function CardPickupEffects.update(player, dt)
    player.cardPickupFlashTimer = math.max(0, (player.cardPickupFlashTimer or 0) - dt)
end

function CardPickupEffects.start(player)
    player.cardPickupFlashTimer = player.cardPickupFlashDuration or 0.55
    player.whiteFlashTimer = math.max(player.whiteFlashTimer or 0, player.whiteFlashDuration or 0.12)

    BoxBreakBurst.spawn(player.x, player.y, {
        pixelOffsetY = -14,
        ballHeight = 8,
        footstepOffsetY = -8,
        boxParticleOffsetY = -4,
        pixelMinCount = 5,
        pixelMaxCount = 8
    })
end

function CardPickupEffects.getFlashProgress(player)
    local duration = player.cardPickupFlashDuration or 0.55
    return math.max(0, math.min((player.cardPickupFlashTimer or 0) / duration, 1))
end

return CardPickupEffects
