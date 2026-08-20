local FloorIntroManager = {}
local Localization = require("scripts/managers/localization")
local Fonts = require("scripts/ui/fonts")

local floorTitleFont = Fonts:translated("floorTitle")
local thanksFont = Fonts:translated("thanks")
local madeByFont = Fonts:translated("madeBy")
local floorBackgroundShader = love.graphics.newShader("scripts/shaders/oldTvMenuBackground.glsl")
local totemWaveShader = love.graphics.newShader("scripts/shaders/totemWave.glsl")
local introTotemImage = love.graphics.newImage("assets/sprites/menu/intro-totem.png")
local angelIntroSoundBases = {
    love.audio.newSource("assets/sfx/effects/angel-intro.mp3", "static"),
    love.audio.newSource("assets/sfx/effects/angel-intro2.mp3", "static"),
}

local FLOOR_TITLE_DURATION = 3
local FLOOR_MUSIC_FADE_DURATION = 0.65
local FLOOR_FADE_IN_DURATION = 0.6
local FLOOR_FADE_OUT_DURATION = 0.8
local FLOOR_OVERLAY_DURATION = 3
local FLOOR_OVERLAY_FADE_IN_DURATION = 0.6
local FLOOR_OVERLAY_FADE_OUT_DURATION = 0.8
local INTRO_TOTEM_FRAME_COUNT = 6
local INTRO_TOTEM_FRAME_WIDTH = introTotemImage:getWidth() / INTRO_TOTEM_FRAME_COUNT
local INTRO_TOTEM_FRAME_HEIGHT = introTotemImage:getHeight()
local INTRO_TOTEM_SCALE = 3
local INTRO_TOTEM_CENTER_Y_OFFSET = -32
local THANKS_SCREEN_DURATION = 6.6
local THANKS_FADE_IN_DURATION = 0.6
local THANKS_FADE_OUT_DURATION = 0.8

floorTitleFont:setFilter("nearest", "nearest")
thanksFont:setFilter("nearest", "nearest")
madeByFont:setFilter("nearest", "nearest")
introTotemImage:setFilter("nearest", "nearest")

local introTotemFrames = {}
for frameIndex = 0, INTRO_TOTEM_FRAME_COUNT - 1 do
    introTotemFrames[#introTotemFrames + 1] = love.graphics.newQuad(
        frameIndex * INTRO_TOTEM_FRAME_WIDTH,
        0,
        INTRO_TOTEM_FRAME_WIDTH,
        INTRO_TOTEM_FRAME_HEIGHT,
        introTotemImage:getDimensions()
    )
end

local function hexToColor(hex)
    hex = hex:gsub("#", "")
    local r = tonumber(hex:sub(1, 2), 16) or 255
    local g = tonumber(hex:sub(3, 4), 16) or 255
    local b = tonumber(hex:sub(5, 6), 16) or 255
    return r / 255, g / 255, b / 255
end

local function drawWavyText(text, y, font, options)
    options = options or {}
    local time = love.timer.getTime()
    local scale = options.scale or 1
    local textWidth = font:getWidth(text) * scale
    if options.centerY then
        y = options.centerY - font:getHeight() * scale / 2
    end

    local x = baseWidth / 2 - textWidth / 2
    local speedScale = options.speedScale or 1
    local amplitudeScale = options.amplitudeScale or 1
    local alpha = options.alpha or 1
    local color = options.color or "fbfaf7"
    local shadowAlpha = options.shadowAlpha or 0.62
    local pixelGrid = options.pixelGrid or 1

    local function snapToPixelGrid(value)
        if pixelGrid <= 1 then
            return math.floor(value + 0.5)
        end

        return math.floor(value / pixelGrid + 0.5) * pixelGrid
    end

    for i = 1, #text do
        local char = text:sub(i, i)
        local charWidth = font:getWidth(char) * scale
        local phase = time * 2.55 * speedScale + i * 0.42
        local runX = (math.sin(phase) * 0.72
            + math.sin(time * 3.4 * speedScale + i * 1.3) * 0.26) * amplitudeScale
        local runY = (math.cos(time * 2.15 * speedScale + i * 0.58) * 0.52
            + math.sin(time * 3.05 * speedScale + i * 0.9) * 0.18) * amplitudeScale
        local drawX = snapToPixelGrid(x + runX)
        local drawY = snapToPixelGrid(y + runY)

        if char ~= " " then
            love.graphics.setColor(0.02, 0.015, 0.025, shadowAlpha * alpha)
            love.graphics.print(char, drawX + scale, drawY + scale, 0, scale, scale)
            local r, g, b = hexToColor(color)
            love.graphics.setColor(r, g, b, alpha)
            love.graphics.print(char, drawX, drawY, 0, scale, scale)
        end

        x = x + charWidth
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function FloorIntroManager:startFloor(floorIndex, onComplete)
    local angelIntroSoundBase = angelIntroSoundBases[math.random(#angelIntroSoundBases)]
    local angelIntroSound = angelIntroSoundBase:clone()
    setSourceVolume(angelIntroSound, 0.3 * (SOUND_VOLUME or 1))
    local pitchVariation = 0.96 + math.random() * 0.08
    angelIntroSound:setPitch(pitchVariation * (GAME_PITCH or 1))
    angelIntroSound:play()

    self.floorIntro = {
        floorIndex = floorIndex or 1,
        timer = 0,
        duration = FLOOR_TITLE_DURATION,
        musicFadeFinished = false,
        onComplete = onComplete,
    }
    self.thanksScreen = nil
end

function FloorIntroManager:startFloorOverlay(floorIndex)
    self.floorOverlay = {
        floorIndex = floorIndex or 1,
        timer = 0,
        duration = FLOOR_OVERLAY_DURATION,
    }
end

function FloorIntroManager:updateFloorOverlay(dt)
    local overlay = self.floorOverlay
    if not overlay then
        return false
    end

    overlay.timer = overlay.timer + dt
    if overlay.timer >= overlay.duration then
        self.floorOverlay = nil
        return false
    end

    return true
end

function FloorIntroManager:startThanks(onComplete)
    self.floorIntro = nil
    self.thanksScreen = {
        timer = 0,
        duration = THANKS_SCREEN_DURATION,
        onComplete = onComplete,
    }
end

function FloorIntroManager:hasFloorIntro()
    return self.floorIntro ~= nil
end

function FloorIntroManager:hasThanksScreen()
    return self.thanksScreen ~= nil
end

function FloorIntroManager:isActive()
    return self.floorIntro ~= nil or self.thanksScreen ~= nil
end

function FloorIntroManager:updateFloor(dt)
    local intro = self.floorIntro
    if not intro then
        return false
    end

    intro.timer = intro.timer + dt
    if not intro.musicFadeFinished and intro.timer >= FLOOR_MUSIC_FADE_DURATION then
        intro.musicFadeFinished = true
        if Music and Music.finishFloorIntroFade then
            Music:finishFloorIntroFade()
        end
    end

    if intro.timer >= intro.duration then
        local onComplete = intro.onComplete
        self.floorIntro = nil
        if onComplete then
            onComplete()
        end
        return false
    end

    return true
end

function FloorIntroManager:updateThanks(dt)
    local thanks = self.thanksScreen
    if not thanks then
        return false
    end

    thanks.timer = thanks.timer + dt
    if thanks.timer >= thanks.duration then
        local onComplete = thanks.onComplete
        self.thanksScreen = nil
        if onComplete then
            onComplete()
        end
        return false
    end

    return true
end

function FloorIntroManager:update(dt)
    if self.floorIntro then
        return self:updateFloor(dt)
    end

    if self.thanksScreen then
        return self:updateThanks(dt)
    end

    return false
end

function FloorIntroManager:drawFloor()
    local intro = self.floorIntro
    if not intro then
        return
    end

    floorBackgroundShader:send("u_time", love.timer.getTime() * 0.3)
    floorBackgroundShader:send("u_intensity", 0.18)
    love.graphics.setShader(floorBackgroundShader)
    love.graphics.setColor(hexToColor("090909"))
    love.graphics.rectangle("fill", 0, 0, baseWidth, baseHeight)
    love.graphics.setShader()

    local fadeIn = math.min(intro.timer / FLOOR_FADE_IN_DURATION, 1)
    local fadeOut = math.min((intro.duration - intro.timer) / FLOOR_FADE_OUT_DURATION, 1)
    local titleAlpha = math.max(0, math.min(fadeIn, fadeOut))
    local totemFrameIndex = math.max(1, math.min(math.floor(intro.floorIndex or 1), INTRO_TOTEM_FRAME_COUNT))
    local totemDrawWidth = INTRO_TOTEM_FRAME_WIDTH * INTRO_TOTEM_SCALE
    local totemDrawHeight = INTRO_TOTEM_FRAME_HEIGHT * INTRO_TOTEM_SCALE
    local totemX = math.floor(baseWidth / 2 - totemDrawWidth / 2 + 0.5)
    local totemY = math.floor(baseHeight / 2 + INTRO_TOTEM_CENTER_Y_OFFSET - totemDrawHeight / 2 + 0.5)
    local frameMinX = (totemFrameIndex - 1) / INTRO_TOTEM_FRAME_COUNT
    local frameMaxX = totemFrameIndex / INTRO_TOTEM_FRAME_COUNT
    totemWaveShader:send("u_time", love.timer.getTime())
    totemWaveShader:send("u_frameXBounds", {frameMinX, frameMaxX})
    love.graphics.setShader(totemWaveShader)
    love.graphics.setColor(1, 1, 1, titleAlpha)
    love.graphics.draw(
        introTotemImage,
        introTotemFrames[totemFrameIndex],
        totemX,
        totemY,
        0,
        INTRO_TOTEM_SCALE,
        INTRO_TOTEM_SCALE
    )
    love.graphics.setShader()

    love.graphics.setColor(1, 1, 1, 1)
end

function FloorIntroManager:drawFloorOverlay()
    local overlay = self.floorOverlay
    if not overlay then
        return
    end

    local fadeIn = math.min(overlay.timer / FLOOR_OVERLAY_FADE_IN_DURATION, 1)
    local fadeOut = math.min((overlay.duration - overlay.timer) / FLOOR_OVERLAY_FADE_OUT_DURATION, 1)
    local alpha = math.max(0, math.min(fadeIn, fadeOut))
    local text = Localization:t("game.floor", { floor = tostring(overlay.floorIndex or 1) })

    love.graphics.setFont(floorTitleFont)
    drawWavyText(text, 0, floorTitleFont, {
        centerY = baseHeight * 0.3,
        alpha = alpha,
        color = "fbfaf7",
        shadowAlpha = 0.62,
        amplitudeScale = 1.45,
        speedScale = 0.9,
    })
    love.graphics.setColor(1, 1, 1, 1)
end

function FloorIntroManager:drawThanks()
    local thanks = self.thanksScreen
    if not thanks then
        return
    end

    local fadeIn = math.min(thanks.timer / THANKS_FADE_IN_DURATION, 1)
    local fadeOut = math.min((thanks.duration - thanks.timer) / THANKS_FADE_OUT_DURATION, 1)
    local alpha = math.max(0, math.min(fadeIn, fadeOut))

    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 0, baseWidth, baseHeight)
    love.graphics.setFont(thanksFont)
    drawWavyText(Localization:t("game.thanks"), baseHeight / 2 - 42, thanksFont, {
        alpha = alpha,
        speedScale = 0.9,
        amplitudeScale = 0.9,
    })
    love.graphics.setFont(madeByFont)
    drawWavyText(Localization:t("game.made_by"), baseHeight / 2 + 28, madeByFont, {
        alpha = alpha * 0.76,
        speedScale = 0.8,
        amplitudeScale = 0.45,
        shadowAlpha = 0.5,
    })
    love.graphics.setColor(1, 1, 1, 1)
end

return FloorIntroManager
