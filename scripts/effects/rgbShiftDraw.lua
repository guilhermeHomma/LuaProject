local RgbShiftDraw = {}

local defaultConfig = {
    enabled = true,
    duration = 0.1,
    shift = 1,
    redColor = {1, 0.08, 0.08, 0.85},
    cyanColor = {0.15, 1, 0.28, 0.85}
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

function RgbShiftDraw.createConfig(overrides)
    local config = copyTable(defaultConfig)
    if not overrides then
        return config
    end

    for key, value in pairs(overrides) do
        if type(value) == "table" then
            config[key] = copyTable(value)
        else
            config[key] = value
        end
    end

    return config
end

local function setColor(color, alpha, tint)
    tint = tint or {1, 1, 1, 1}
    love.graphics.setColor(
        color[1] * (tint[1] or 1),
        color[2] * (tint[2] or 1),
        color[3] * (tint[3] or 1),
        (color[4] or 1) * alpha * (tint[4] or 1)
    )
end

function RgbShiftDraw.getAlpha(timer, config)
    if not config or not config.enabled then
        return 0
    end

    if timer >= config.duration then
        return 0
    end

    return 1 - (timer / config.duration)
end

function RgbShiftDraw.drawSprite(image, quad, x, y, rotation, scaleX, scaleY, originX, originY, timer, config, baseAlpha, tint)
    local alpha = RgbShiftDraw.getAlpha(timer or 0, config) * (baseAlpha or 1)
    local shift = config and config.shift or 1

    if alpha <= 0 then
        return false
    end

    local function drawWithOffset(offsetX, color)
        setColor(color, alpha, tint)
        if quad then
            love.graphics.draw(image, quad, x + offsetX, y, rotation, scaleX, scaleY, originX, originY)
        else
            love.graphics.draw(image, x + offsetX, y, rotation, scaleX, scaleY, originX, originY)
        end
    end

    drawWithOffset(-shift, config.redColor)
    drawWithOffset(shift, config.cyanColor)
    return true
end

return RgbShiftDraw
