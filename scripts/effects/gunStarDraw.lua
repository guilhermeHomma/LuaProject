local GunStarDraw = {}

local defaultSpritePath = "assets/sprites/particles/gunStar.png"
local sheetCache = {}
local quadCache = {}

local frameSize = 16
local frameCount = 5
local frameDuration = 0.03

local function getSheet(spritePath)
    spritePath = spritePath or defaultSpritePath

    if not sheetCache[spritePath] then
        sheetCache[spritePath] = love.graphics.newImage(spritePath)
        sheetCache[spritePath]:setFilter("nearest", "nearest")
    end

    return sheetCache[spritePath]
end

local function getQuad(spritePath, frameIndex)
    spritePath = spritePath or defaultSpritePath
    quadCache[spritePath] = quadCache[spritePath] or {}

    if not quadCache[spritePath][frameIndex] then
        local sheet = getSheet(spritePath)
        quadCache[spritePath][frameIndex] = love.graphics.newQuad(
            frameIndex * frameSize,
            0,
            frameSize,
            frameSize,
            sheet:getDimensions()
        )
    end

    return quadCache[spritePath][frameIndex]
end

function GunStarDraw.getFrameDuration()
    return frameDuration
end

function GunStarDraw.getFrameCount()
    return frameCount
end

function GunStarDraw.getAnimationDuration()
    return frameDuration * frameCount
end

function GunStarDraw.draw(x, y, frameIndex, alpha, scale, spritePath)
    alpha = alpha or 1
    scale = scale or 1
    frameIndex = math.max(0, math.min(frameCount - 1, frameIndex or 0))

    local sheet = getSheet(spritePath)
    local quad = getQuad(spritePath, frameIndex)

    love.graphics.setBlendMode("add")
    love.graphics.setColor(1, 1, 1, 0.025 * alpha)
    love.graphics.circle("fill", x, y, 10 * scale)
    love.graphics.setColor(1, 1, 1, 0.04 * alpha)
    love.graphics.circle("fill", x, y, 6 * scale)
    love.graphics.setBlendMode("alpha")

    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.draw(sheet, quad, x, y, 0, scale, scale, frameSize / 2, frameSize / 2)
    love.graphics.setColor(1, 1, 1, 1)
end

return GunStarDraw
