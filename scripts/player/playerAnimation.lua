local PlayerAnimation = {}

local BloodPixel = require("scripts/particles/bloodPixel")
local impactSoundBase = love.audio.newSource("assets/sfx/effects/impact-hit.mp3", "static")

local fallConfig = {
    sheetPath = "assets/sprites/player/alice/fall.png",
    frameSize = 40,
    frameTime = 0.1,
    startOffsetY = -320,
    fallDuration = 1.38,
    fadeInDuration = 0.7,
    fallingFrames = {1, 2, 3, 4, 5},
    landingFrames = {6, 7, 8, 9},
    landingHoldFrame = 9,
    landingHoldTime = 0.6,
    wakeupFrames = {10, 11, 12, 13, 14},
}

local grayPixelPalette = {
    {0.66, 0.66, 0.62, 1},
    {0.50, 0.50, 0.47, 1},
    {0.40, 0.40, 0.38, 1},
    {0.74, 0.73, 0.68, 1},
    {0.30, 0.30, 0.29, 1},
}

local function clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

local function easeInQuad(value)
    return value * value
end

local function playClonedSound(baseSource, volume, pitch)
    if not baseSource then
        return
    end

    local sound = baseSource:clone()
    setSourceVolume(sound, (volume or 1) * (SOUND_VOLUME or 1))
    sound:setPitch((pitch or 1) * (GAME_PITCH or 1))
    sound:play()
end

function PlayerAnimation.createGridQuads(image, frameSize, rowCount, columnCount)
    local quads = {}
    local sheetWidth = image:getWidth()
    local sheetHeight = image:getHeight()

    for row = 0, rowCount - 1 do
        for column = 0, columnCount - 1 do
            quads[#quads + 1] = love.graphics.newQuad(
                column * frameSize,
                row * frameSize,
                frameSize,
                frameSize,
                sheetWidth,
                sheetHeight
            )
        end
    end

    return quads
end

function PlayerAnimation.createStripQuads(image, frameSize)
    local quads = {}
    local sheetWidth = image:getWidth()
    local sheetHeight = image:getHeight()
    local frameCount = math.floor(sheetWidth / frameSize)

    for frame = 0, frameCount - 1 do
        quads[#quads + 1] = love.graphics.newQuad(
            frame * frameSize,
            0,
            frameSize,
            frameSize,
            sheetWidth,
            sheetHeight
        )
    end

    return quads
end

function PlayerAnimation.load(player)
    player.fallSheet = love.graphics.newImage(fallConfig.sheetPath)
    player.fallSheet:setFilter("nearest", "nearest")
    player.fallQuads = PlayerAnimation.createStripQuads(player.fallSheet, fallConfig.frameSize)
    player.fallIntro = {
        active = false,
        state = "idle",
        timer = 0,
        visualOffsetY = 0,
        currentFrame = 1,
        impactSpawned = false,
        fadeTimer = 0,
    }
end

function PlayerAnimation.startFallIntro(player)
    if not player then
        return
    end

    player.fallIntro = player.fallIntro or {}
    player.fallIntro.active = true
    player.fallIntro.state = "falling"
    player.fallIntro.timer = 0
    player.fallIntro.visualOffsetY = fallConfig.startOffsetY
    player.fallIntro.currentFrame = fallConfig.fallingFrames[1]
    player.fallIntro.impactSpawned = false
    player.fallIntro.shadowAlpha = 0
    player.fallIntro.fadeTimer = fallConfig.fadeInDuration
    player.velocityX = 0
    player.velocityY = 0
    player.moveX = 0
    player.moveY = 1
    player.currentAnimation = "idle"
    player.currentFrame = 1
    player.idleHandFrame = 1
end

function PlayerAnimation.isFallIntroActive(player)
    return player and player.fallIntro and player.fallIntro.active == true
end

function PlayerAnimation.getFallIntroShadowAlpha(player)
    local intro = player and player.fallIntro
    if not intro then
        return 1
    end

    if intro.active then
        return clamp(intro.shadowAlpha or 0, 0, 1)
    end

    return 1
end

function PlayerAnimation.getFallIntroFadeAlpha(player)
    local intro = player and player.fallIntro
    if not intro or (intro.fadeTimer or 0) <= 0 then
        return 0
    end

    return clamp((intro.fadeTimer or 0) / math.max(fallConfig.fadeInDuration, 0.001), 0, 1)
end

local function spawnLandingImpact(player)
    local x = player.x
    local y = player.y

    BloodPixel.spawnBurst(x, y - 4, 0, -1, 36, 50, grayPixelPalette)

    if camera and camera.shake then
        camera:shake(10.0, 0.80)
    end

    playClonedSound(impactSoundBase, 0.8, 1.24 + math.random() * 0.08)
end

local function updateFalling(player, intro, dt)
    local progress = clamp((intro.timer or 0) / fallConfig.fallDuration, 0, 1)
    local frameIndex = (math.floor((intro.timer or 0) / fallConfig.frameTime) % #fallConfig.fallingFrames) + 1

    intro.currentFrame = fallConfig.fallingFrames[frameIndex]
    intro.visualOffsetY = fallConfig.startOffsetY * (1 - easeInQuad(progress))
    intro.shadowAlpha = clamp(progress, 0, 1)

    if progress >= 1 then
        intro.state = "landing"
        intro.timer = 0
        intro.visualOffsetY = 0
        intro.shadowAlpha = 1
        intro.currentFrame = fallConfig.landingFrames[1]
        if not intro.impactSpawned then
            intro.impactSpawned = true
            spawnLandingImpact(player)
        end
    end
end

local function updateLanding(player, intro)
    local timer = intro.timer or 0
    local animatedFrameCount = #fallConfig.landingFrames - 1
    local animatedTime = animatedFrameCount * fallConfig.frameTime

    intro.visualOffsetY = 0
    if timer < animatedTime then
        intro.currentFrame = fallConfig.landingFrames[math.floor(timer / fallConfig.frameTime) + 1]
    else
        intro.currentFrame = fallConfig.landingHoldFrame
    end

    if timer >= animatedTime + fallConfig.landingHoldTime then
        intro.state = "wakeup"
        intro.timer = 0
        intro.currentFrame = fallConfig.wakeupFrames[1]
    end
end

local function updateWakeup(player, intro)
    local frameIndex = math.floor((intro.timer or 0) / fallConfig.frameTime) + 1
    intro.currentFrame = fallConfig.wakeupFrames[math.min(frameIndex, #fallConfig.wakeupFrames)]

    if frameIndex > #fallConfig.wakeupFrames then
        intro.active = false
        intro.state = "idle"
        intro.visualOffsetY = 0
        intro.shadowAlpha = 1
        player.moveX = 0
        player.moveY = 1
        player.currentAnimation = "idle"
        player.currentFrame = 1
        player.idleHandFrame = 1
        player.animationTimer = 0
    end
end

function PlayerAnimation.updateFallIntro(player, dt)
    local intro = player and player.fallIntro
    if not (intro and intro.active) then
        return false
    end

    intro.timer = (intro.timer or 0) + dt
    intro.fadeTimer = math.max(0, (intro.fadeTimer or 0) - dt)
    player.velocityX = 0
    player.velocityY = 0
    player.moveX = 0
    player.moveY = 1

    if intro.state == "falling" then
        updateFalling(player, intro, dt)
    elseif intro.state == "landing" then
        updateLanding(player, intro)
    elseif intro.state == "wakeup" then
        updateWakeup(player, intro)
    else
        intro.active = false
    end

    return intro.active == true
end

function PlayerAnimation.drawFallIntro(player)
    local intro = player and player.fallIntro
    if not (intro and intro.active) then
        return false
    end

    local frame = intro.currentFrame or 1
    local quad = player.fallQuads and player.fallQuads[frame]
    if not quad then
        return true
    end

    local scaleX = player.flipH and -1 or 1
    local scaleY = 1.4
    local originX = player.flipH and (player.spriteSize - player.spriteSize / 2) or (player.spriteSize / 2)
    player:drawPlayerImage(
        player.fallSheet,
        quad,
        player.x,
        player.y + (intro.visualOffsetY or 0),
        0,
        scaleX,
        scaleY,
        originX,
        player.spriteSize
    )

    return true
end

return PlayerAnimation
