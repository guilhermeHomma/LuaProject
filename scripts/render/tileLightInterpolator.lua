local Config = require("scripts/config/tileLightInterpolationConfig")

local TileLightInterpolator = {}

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

function TileLightInterpolator:apply(object, brightness, minBrightness, brightnessSampler)
    if not Config.enabled or not object or object.isTile ~= true then
        return brightness
    end
    if object.tileLightInterpolation == false or not brightnessSampler then
        return brightness
    end

    local x = object.xWorld or object.x
    local y = object.yWorld or object.y
    if not x or not y then
        return brightness
    end

    local offset = Config.sampleOffset or 16
    if offset <= 0 then
        return brightness
    end

    local left = brightnessSampler(object, x - offset, y, minBrightness)
    local right = brightnessSampler(object, x + offset, y, minBrightness)
    local up = brightnessSampler(object, x, y - offset, minBrightness)
    local down = brightnessSampler(object, x, y + offset, minBrightness)
    local neighborAverage = (left + right + up + down) * 0.25
    local delta = (neighborAverage - brightness) * (Config.strength or 0)

    if math.abs(delta) < (Config.minDelta or 0) then
        return brightness
    end

    local maxDelta = Config.maxDelta
    if maxDelta and maxDelta > 0 then
        delta = clamp(delta, -maxDelta, maxDelta)
    end

    return clamp(brightness + delta, minBrightness or 0, 1)
end

return TileLightInterpolator
