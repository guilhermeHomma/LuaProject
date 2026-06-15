local DamageStretch = {}

local defaultDuration = 0.1
local defaultAmount = 0.1

function DamageStretch:init(target, duration, amount)
    target.damageStretchDuration = duration or defaultDuration
    target.damageStretchAmount = amount or defaultAmount
    target.damageStretchStartTime = -math.huge
end

function DamageStretch:start(target)
    if not target then return end

    if not target.damageStretchDuration then
        DamageStretch:init(target)
    end

    target.damageStretchStartTime = love.timer.getTime()
end

function DamageStretch:getScale(target)
    if not target or not target.damageStretchStartTime then
        return 1, 1
    end

    if target.damageStretchStartTime == -math.huge then
        return 1, 1
    end

    local duration = target.damageStretchDuration or defaultDuration
    local elapsed = love.timer.getTime() - target.damageStretchStartTime

    if elapsed < 0 or elapsed >= duration then
        target.damageStretchStartTime = -math.huge
        return 1, 1
    end

    local progress = elapsed / duration
    local stretch = math.sin(progress * math.pi) * (target.damageStretchAmount or defaultAmount)

    return 1 + stretch, 1 - stretch
end

return DamageStretch
