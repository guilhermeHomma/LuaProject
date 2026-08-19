local config = require("scripts.config.globalPalette")

local GlobalPalette = {
    enabled = (GAME_FLAGS == nil or GAME_FLAGS.globalPalette ~= false) and config.enabled ~= false,
    strength = config.strength or 1,
}

local MAX_COLORS = 32
local shader = love.graphics.newShader("scripts/shaders/globalPalette.glsl")
local outputCanvas = nil
local shaderColors = {}
local paletteSize = 0

local function parseHex(hex)
    local value = tostring(hex):gsub("#", "")
    assert(value:match("^%x%x%x%x%x%x$"), "Invalid global palette color: " .. tostring(hex))
    return {
        tonumber(value:sub(1, 2), 16) / 255,
        tonumber(value:sub(3, 4), 16) / 255,
        tonumber(value:sub(5, 6), 16) / 255,
    }
end

local function ensureCanvas()
    local width, height = love.graphics.getDimensions()
    if outputCanvas and outputCanvas:getWidth() == width and outputCanvas:getHeight() == height then
        return
    end

    outputCanvas = love.graphics.newCanvas(width, height)
    outputCanvas:setFilter("nearest", "nearest")
end

function GlobalPalette:setPalette(colors)
    assert(type(colors) == "table" and #colors > 0, "Global palette must contain at least one color")
    assert(#colors <= MAX_COLORS, "Global palette supports at most " .. MAX_COLORS .. " colors")

    paletteSize = #colors
    for index = 1, MAX_COLORS do
        shaderColors[index] = index <= paletteSize and parseHex(colors[index]) or shaderColors[1]
    end

    shader:send("u_palette", unpack(shaderColors, 1, MAX_COLORS))
    shader:send("u_paletteSize", paletteSize)
end

function GlobalPalette:beginFrame()
    ensureCanvas()
    love.graphics.setCanvas(outputCanvas)
    love.graphics.clear(0, 0, 0, 1)
end

function GlobalPalette:resumeFrame()
    love.graphics.setCanvas(outputCanvas)
end

function GlobalPalette:getCanvas()
    return outputCanvas
end

function GlobalPalette:isEnabled()
    return self.enabled
end

function GlobalPalette:present()
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

GlobalPalette:setPalette(config.colors)

return GlobalPalette
