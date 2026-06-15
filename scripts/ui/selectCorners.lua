local SelectCorners = {}

local image = love.graphics.newImage("assets/sprites/ui/select.png")
image:setFilter("nearest", "nearest")

local frameSize = image:getWidth() / 2
local quads = {
    topLeft = love.graphics.newQuad(0, 0, frameSize, frameSize, image:getDimensions()),
    topRight = love.graphics.newQuad(frameSize, 0, frameSize, frameSize, image:getDimensions()),
    bottomLeft = love.graphics.newQuad(0, frameSize, frameSize, frameSize, image:getDimensions()),
    bottomRight = love.graphics.newQuad(frameSize, frameSize, frameSize, frameSize, image:getDimensions()),
}

local function clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

local function easeOutBack(t)
    local c1 = 1.70158
    local c3 = c1 + 1
    return 1 + c3 * (t - 1) * (t - 1) * (t - 1) + c1 * (t - 1) * (t - 1)
end

local function drawCorner(quad, x, y, rotation, scale)
    love.graphics.draw(image, quad, math.floor(x + 0.5), math.floor(y + 0.5), rotation, scale, scale, frameSize / 2, frameSize / 2)
end

function SelectCorners.draw(bounds, options)
    if not bounds then
        return
    end

    options = options or {}
    local now = love.timer.getTime()
    local progress = clamp((now - (options.startedAt or now)) / (options.duration or 0.1), 0, 1)
    local appear = easeOutBack(progress)
    local scale = (options.scale or 3) * (0.58 + 0.42 * appear)
    local rotation = (1 - progress) * (options.rotation or 0.65)
    local padding = options.padding or 0
    local arrivePadding = (options.arrivePadding or 0) * (1 - progress)
    local alpha = options.alpha or 1

    if options.exitedAt then
        local exitProgress = clamp((now - options.exitedAt) / (options.exitDuration or 0.1), 0, 1)
        local exitEase = exitProgress * exitProgress
        scale = scale * (1 - exitEase * 0.42)
        rotation = rotation + exitEase * (options.exitRotation or 0.55)
        alpha = alpha * (1 - exitProgress)
    end
    local r, g, b = 1, 1, 1

    if options.color then
        r = options.color[1] or 1
        g = options.color[2] or 1
        b = options.color[3] or 1
        alpha = (options.color[4] or 1) * alpha
    end

    local left = bounds.left or bounds.x or 0
    local top = bounds.top or bounds.y or 0
    local right = left + (bounds.width or bounds.w or 0)
    local bottom = top + (bounds.height or bounds.h or 0)

    love.graphics.setColor(r, g, b, alpha)
    drawCorner(quads.topLeft, left - padding - arrivePadding, top - padding - arrivePadding, -rotation, scale)
    drawCorner(quads.topRight, right + padding + arrivePadding, top - padding - arrivePadding, rotation, scale)
    drawCorner(quads.bottomLeft, left - padding - arrivePadding, bottom + padding + arrivePadding, rotation, scale)
    drawCorner(quads.bottomRight, right + padding + arrivePadding, bottom + padding + arrivePadding, -rotation, scale)
    love.graphics.setColor(1, 1, 1, 1)
end

return SelectCorners
