local config = require("scripts.config.colorWheelPalette")

local ColorWheelPalette = {
    enabled = (GAME_FLAGS == nil or GAME_FLAGS.globalPalette ~= false) and config.enabled ~= false,
    strength = config.strength or 1,
}

local shader = love.graphics.newShader("scripts/shaders/colorWheelPalette.glsl")
local outputCanvas = nil
local shaderColors = {}

local function parseHex(hex)
    local value = tostring(hex):gsub("#", "")
    assert(value:match("^%x%x%x%x%x%x$"), "Invalid color wheel palette color: " .. tostring(hex))
    return {
        tonumber(value:sub(1, 2), 16) / 255,
        tonumber(value:sub(3, 4), 16) / 255,
        tonumber(value:sub(5, 6), 16) / 255,
    }
end

local function hsvToRgb(hue, saturation, value)
    local sector = math.floor(hue * 6)
    local fraction = hue * 6 - sector
    local p = value * (1 - saturation)
    local q = value * (1 - fraction * saturation)
    local t = value * (1 - (1 - fraction) * saturation)
    local index = sector % 6

    if index == 0 then return {value, t, p} end
    if index == 1 then return {q, value, p} end
    if index == 2 then return {p, value, t} end
    if index == 3 then return {p, q, value} end
    if index == 4 then return {t, p, value} end
    return {value, p, q}
end

local function ensureCanvas()
    local width, height = love.graphics.getDimensions()
    if outputCanvas and outputCanvas:getWidth() == width and outputCanvas:getHeight() == height then
        return
    end

    outputCanvas = love.graphics.newCanvas(width, height)
    outputCanvas:setFilter("nearest", "nearest")
end

function ColorWheelPalette:beginFrame()
    ensureCanvas()
    love.graphics.setCanvas(outputCanvas)
    love.graphics.clear(0, 0, 0, 1)
end

function ColorWheelPalette:resumeFrame()
    love.graphics.setCanvas(outputCanvas)
end

function ColorWheelPalette:getCanvas()
    return outputCanvas
end

function ColorWheelPalette:isEnabled()
    return self.enabled
end

function ColorWheelPalette:present()
    love.graphics.setCanvas()
    love.graphics.setColor(1, 1, 1, 1)

    if self.enabled then
        shader:send("u_strength", self.strength)
        shader:send("u_brightness", tonumber(GAME_FLAGS and GAME_FLAGS.brightness) or 5)
        love.graphics.setShader(shader)
    end

    love.graphics.draw(outputCanvas, 0, 0)
    love.graphics.setShader()
end

local hueCount = config.hueCount or 7
local variants = config.variants or {}
assert(hueCount == 7 and #variants == 6, "Color wheel palette expects 7 hues with 6 variants each")

local colorIndex = 1
for hueIndex = 1, hueCount do
    local hue = (hueIndex - 1) / hueCount
    for variantIndex = 1, #variants do
        local variant = variants[variantIndex]
        shaderColors[colorIndex] = hsvToRgb(hue, variant.saturation, variant.value)
        colorIndex = colorIndex + 1
    end
end
shaderColors[43] = parseHex(config.blackColor)
shaderColors[44] = parseHex(config.whiteColor)
shader:send("u_palette", unpack(shaderColors, 1, 44))
shader:send("u_paletteSize", 44)

return ColorWheelPalette
