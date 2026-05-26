local FloorIntroManager = {}

local floorTitleFont = love.graphics.newFont("assets/fonts/ThaleahFat.ttf", 78)
local thanksFont = love.graphics.newFont("assets/fonts/ThaleahFat.ttf", 54)
local madeByFont = love.graphics.newFont("assets/fonts/ThaleahFat.ttf", 18)
local riserSoundBase = love.audio.newSource("assets/sfx/effects/riser.mp3", "static")
local impactSoundBase = love.audio.newSource("assets/sfx/effects/impact-hit.mp3", "static")

local FLOOR_RISER_DURATION = 2.3
local FLOOR_TITLE_DURATION = 2.75
local FLOOR_MUSIC_FADE_DURATION = 1
local FLOOR_START_BREATH_DURATION = 0.3
local FLOOR_TITLE_GROW_DURATION = 0.12
local FLOOR_TITLE_Y_OFFSET = -58
local THANKS_SCREEN_DURATION = 6.6
local THANKS_FADE_IN_DURATION = 0.6
local THANKS_FADE_OUT_DURATION = 0.8

floorTitleFont:setFilter("nearest", "nearest")
thanksFont:setFilter("nearest", "nearest")
madeByFont:setFilter("nearest", "nearest")

local function hexToColor(hex)
    hex = hex:gsub("#", "")
    local r = tonumber(hex:sub(1, 2), 16) or 255
    local g = tonumber(hex:sub(3, 4), 16) or 255
    local b = tonumber(hex:sub(5, 6), 16) or 255
    return r / 255, g / 255, b / 255
end

local function easeOutExpo(value)
    value = math.max(0, math.min(value, 1))
    if value >= 1 then
        return 1
    end

    return 1 - 2 ^ (-10 * value)
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

local function playClonedSound(baseSource, volume, pitch)
    local sound = baseSource:clone()
    sound:setVolume((volume or 1) * (SOUND_VOLUME or 1))
    sound:setPitch((pitch or 1) * (GAME_PITCH or 1))
    sound:play()
    return sound
end

function FloorIntroManager:startFloor(floorIndex, onComplete)
    self.floorIntro = {
        floorIndex = floorIndex or 1,
        timer = 0,
        phase = "musicFade",
        musicFadeDuration = FLOOR_MUSIC_FADE_DURATION,
        riserDuration = FLOOR_RISER_DURATION,
        titleDuration = FLOOR_TITLE_DURATION,
        breathDuration = FLOOR_START_BREATH_DURATION,
        impactPlayed = false,
        riserPlayed = false,
        onComplete = onComplete,
    }
    self.thanksScreen = nil
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
    if intro.phase == "musicFade" and intro.timer >= intro.musicFadeDuration then
        intro.phase = "riser"
        intro.timer = 0
        intro.riserPlayed = true
        if Music and Music.finishFloorIntroFade then
            Music:finishFloorIntroFade()
        end
        playClonedSound(riserSoundBase, 0.5, 1)
    elseif intro.phase == "riser" and intro.timer >= intro.riserDuration then
        intro.phase = "title"
        intro.timer = 0
        if not intro.impactPlayed then
            intro.impactPlayed = true
            playClonedSound(impactSoundBase, 0.58, 0.92)
            if camera then
                camera:shake(3.0, 0.72)
            end
        end
    elseif intro.phase == "title" and intro.timer >= intro.titleDuration then
        intro.phase = "breath"
        intro.timer = 0
    elseif intro.phase == "breath" and intro.timer >= intro.breathDuration then
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

    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 0, baseWidth, baseHeight)

    local drawFloorTitle = intro.phase == "title"
    local growProgress = 1
    if intro.phase == "riser" then
        local remaining = math.max(0, (intro.riserDuration or FLOOR_RISER_DURATION) - (intro.timer or 0))
        if remaining <= FLOOR_TITLE_GROW_DURATION then
            drawFloorTitle = true
            growProgress = 1 - remaining / FLOOR_TITLE_GROW_DURATION
        end
    end

    if drawFloorTitle then
        local text = "floor " .. tostring(intro.floorIndex or 1)
        local titleY = baseHeight / 2 + FLOOR_TITLE_Y_OFFSET
        growProgress = intro.phase == "title" and 1 or math.min(growProgress, 1)
        local rawScale = 0.46 + (1 - 0.46) * easeOutExpo(growProgress)
        local scaleStep = growProgress < 1 and 0.16 or 0.01
        local scale = math.floor(rawScale / scaleStep + 0.5) * scaleStep
        local pixelGrid = growProgress < 1 and math.max(1, math.floor(8 - growProgress * 7 + 0.5)) or 1
        local titleAlpha = intro.phase == "title" and 1 or (0.18 + 0.82 * easeOutExpo(growProgress))
        local titleCenterY = titleY + floorTitleFont:getHeight() / 2
        love.graphics.setFont(floorTitleFont)
        drawWavyText(text, titleY, floorTitleFont, {
            scale = scale,
            pixelGrid = pixelGrid,
            alpha = titleAlpha,
            centerY = titleCenterY,
            amplitudeScale = 1.22,
            speedScale = 1.05,
        })
    end

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
    drawWavyText("thanks for playing", baseHeight / 2 - 42, thanksFont, {
        alpha = alpha,
        speedScale = 0.9,
        amplitudeScale = 0.9,
    })
    love.graphics.setFont(madeByFont)
    drawWavyText("made by homma", baseHeight / 2 + 28, madeByFont, {
        alpha = alpha * 0.76,
        speedScale = 0.8,
        amplitudeScale = 0.45,
        shadowAlpha = 0.5,
    })
    love.graphics.setColor(1, 1, 1, 1)
end

return FloorIntroManager
