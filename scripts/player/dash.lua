local Dash = {}
Dash.__index = Dash

local BulletColorParticle = require("scripts/particles/bulletColorParticle")
local DashLineParticle = require("scripts/particles/dashLineParticle")

local tintShader = love.graphics.newShader([[
    extern number tintStrength;

    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
    {
        vec4 tex = Texel(texture, texture_coords);
        vec3 tinted = mix(tex.rgb, color.rgb, tintStrength);
        return vec4(tinted, tex.a * color.a);
    }
]])

local defaultConfig = {
    key = "space",
    duration = 0.22,
    cooldown = 1.2,
    speed = 160,
    visualLift = 6,
    visualStretch = -0.22,
    followAccentColor = true,
    accentColor = {0.92, 0.8, 0.5, 1},
    afterimageInterval = 0.055,
    afterimageLifeTime = 0.28,
    afterimageStartColor = {1, 0.96, 0.65, 0.8},
    afterimageEndColor = {0.92, 0.8, 0.1, 0},
    afterimageTintStrengthStart = 0.62,
    afterimageTintStrengthEnd = 0.28,
    playerTintColor = {0.92, 0.8, 0.1, 1},
    playerTintStrength = 0.14,
    particlePalette = {
        {1, 1, 1, 1},
        {0.92, 0.8, 0.15, 1},
        {0.92, 0.90, 0.9, 1},
    },
    particleOptions = {
        speedMin = 12,
        speedMax = 32,
        lifeTime = 0.58,
        size = 1.2,
        fadeOut = true,
        alpha = 0.95,
    },
    particleInterval = 0.026,
    particleCount = 1,
    lineParticles = {
        enabled = true,
        spacing = 1,
        lifeTime = 0.3,
        fadePower = 1.4,
        jitter = 0,
        lines = {
            {
                height = 16,
                squareSize = 5,
                sideOffset = 0,
                color = {1, 1, 1, 0.6},
            },
        },
    },
    shockwave = {
        enabled = true,
        duration = 0.48,
        radius = 90,
        width = 19,
        intensity = 2.4,
        offsetY = -4,
    },
    soundPath = "assets/sfx/effects/whoosh.mp3",
    soundVolume = 0.1,
    soundPitchMin = 1.02,
    soundPitchMax = 1.13,
}

local function copyTable(value)
    if type(value) ~= "table" then
        return value
    end

    local result = {}
    for key, child in pairs(value) do
        result[key] = copyTable(child)
    end
    return result
end

local function colorTowardWhite(color, amount, alpha)
    amount = amount or 0.5
    return {
        (color[1] or 1) + (1 - (color[1] or 1)) * amount,
        (color[2] or 1) + (1 - (color[2] or 1)) * amount,
        (color[3] or 1) + (1 - (color[3] or 1)) * amount,
        alpha ~= nil and alpha or (color[4] or 1),
    }
end

local function applyAccentColor(config)
    if config.followAccentColor == false then
        return config
    end

    local accent = config.accentColor or {1, 1, 1, 1}
    config.playerTintColor = {accent[1] or 1, accent[2] or 1, accent[3] or 1, 1}
    config.afterimageStartColor = colorTowardWhite(accent, 0.78, config.afterimageStartColor and config.afterimageStartColor[4] or 0.8)
    config.afterimageEndColor = {accent[1] or 1, accent[2] or 1, accent[3] or 1, 0}
    config.particlePalette = {
        {1, 1, 1, 1},
        colorTowardWhite(accent, 0.62, 1),
        {accent[1] or 1, accent[2] or 1, accent[3] or 1, 1},
    }
    return config
end

local function copyConfig(config)
    local result = {}
    for key, value in pairs(defaultConfig) do
        if type(value) == "table" then
            result[key] = copyTable(value)
        else
            result[key] = value
        end
    end

    for key, value in pairs(config or {}) do
        result[key] = value
    end

    return applyAccentColor(result)
end

local function normalize(x, y)
    local length = math.sqrt(x * x + y * y)
    if length <= 0.001 then
        return nil, nil
    end

    return x / length, y / length
end

local function quantizeToEightDirections(x, y)
    local angle = math.atan2(y, x)
    local step = math.pi / 4
    local snapped = math.floor((angle / step) + 0.5) * step
    return math.cos(snapped), math.sin(snapped)
end

local function colorAt(startColor, endColor, t)
    return {
        (startColor[1] or 1) + ((endColor[1] or 1) - (startColor[1] or 1)) * t,
        (startColor[2] or 1) + ((endColor[2] or 1) - (startColor[2] or 1)) * t,
        (startColor[3] or 1) + ((endColor[3] or 1) - (startColor[3] or 1)) * t,
        (startColor[4] or 1) + ((endColor[4] or 0) - (startColor[4] or 1)) * t,
    }
end

local function playSound(config)
    if not love.filesystem.getInfo(config.soundPath) then
        return
    end

    local source = love.audio.newSource(config.soundPath, "static")
    source:setVolume((config.soundVolume) * (SOUND_VOLUME or 1))
    source:setPitch(((config.soundPitchMin or 1.1) + math.random() * ((config.soundPitchMax or 1.3) - (config.soundPitchMin or 1.2))) * (GAME_PITCH or 1))
    source:play()
end

function Dash:new(player, config)
    local dash = setmetatable({}, Dash)
    dash.player = player
    dash.config = copyConfig(config)
    dash.timer = 0
    dash.cooldownTimer = 0
    dash.afterimageTimer = 0
    dash.particleTimer = 0
    dash.lineParticleRemainder = 0
    dash.afterimages = {}
    dash.dirX = 0
    dash.dirY = 0
    return dash
end

function Dash:isActive()
    return self.timer > 0
end

function Dash:getVisualOffsetY()
    if not self:isActive() then
        return 0
    end

    local duration = math.max(self.config.duration or 0.001, 0.001)
    local progress = 1 - math.max(0, math.min(self.timer / duration, 1))
    return -math.sin(progress * math.pi) * (self.config.visualLift or 5)
end

function Dash:getVisualStretch()
    if not self:isActive() then
        return 0
    end

    local duration = math.max(self.config.duration or 0.001, 0.001)
    local progress = 1 - math.max(0, math.min(self.timer / duration, 1))
    return math.sin(progress * math.pi) * (self.config.visualStretch or 0.10)
end

function Dash:canStart()
    return self.cooldownTimer <= 0 and not self:isActive()
end

function Dash:getInputDirection()
    if Dialog and Dialog.breakMovements then
        return nil, nil
    end

    local x, y = 0, 0
    if love.keyboard.isDown("w") then y = y - 1 end
    if love.keyboard.isDown("s") then y = y + 1 end
    if love.keyboard.isDown("a") then x = x - 1 end
    if love.keyboard.isDown("d") then x = x + 1 end

    if x == 0 and y == 0 then
        local player = self.player
        x = player.moveX or player.velocityX or 0
        y = player.moveY or player.velocityY or 0
    end

    x, y = normalize(x, y)
    if not x then
        return nil, nil
    end

    return quantizeToEightDirections(x, y)
end

function Dash:captureAfterimage()
    local player = self.player
    if not (player and player.getCurrentDrawQuads) then
        return
    end

    local quad, handQuad = player:getCurrentDrawQuads()
    self.afterimages[#self.afterimages + 1] = {
        x = player.x,
        y = player.y + self:getVisualOffsetY(),
        quad = quad,
        handQuad = handQuad,
        flipH = player.flipH,
        stretch = self:getVisualStretch(),
        timer = 0,
        lifeTime = self.config.afterimageLifeTime,
    }
end

function Dash:start()
    if not self:canStart() then
        return false
    end

    local dirX, dirY = self:getInputDirection()
    if not dirX then
        return false
    end

    self.dirX = dirX
    self.dirY = dirY
    self.timer = self.config.duration
    self.cooldownTimer = self.config.cooldown
    self.afterimageTimer = 0
    self.particleTimer = 0
    self.lineParticleRemainder = 0
    self.player.velocityX = 0
    self.player.velocityY = 0
    self.player.damageKnockbackTimer = 0
    if self.player.gun and self.player.gun.cancelReload then
        self.player.gun:cancelReload()
    end
    self:captureAfterimage()
    self:spawnParticles()
    self:spawnLineParticles()
    self:spawnShockwave()
    playSound(self.config)
    return true
end

function Dash:spawnParticles()
    local player = self.player
    local config = self.config
    BulletColorParticle.spawnBurst(
        player.x - self.dirX * 5,
        player.y - self.dirY * 5,
        12,
        config.particlePalette,
        config.particleCount,
        config.particleOptions
    )
end

function Dash:spawnLineParticles()
    DashLineParticle.spawn(
        self.player.x,
        self.player.y,
        self.dirX,
        self.dirY,
        self.config.lineParticles
    )
end

function Dash:spawnLineParticlesAt(x, y)
    DashLineParticle.spawn(
        x,
        y,
        self.dirX,
        self.dirY,
        self.config.lineParticles
    )
end

function Dash:spawnLineSegment(fromX, fromY, toX, toY)
    local lineParticles = self.config.lineParticles or {}
    if lineParticles.enabled == false then
        return
    end

    local dx = toX - fromX
    local dy = toY - fromY
    local distance = math.sqrt(dx * dx + dy * dy)
    if distance <= 0.001 then
        return
    end

    local spacing = math.max(lineParticles.spacing or 2.2, 0.5)
    local ux = dx / distance
    local uy = dy / distance
    local traveled = spacing - (self.lineParticleRemainder or 0)

    while traveled <= distance do
        self:spawnLineParticlesAt(fromX + ux * traveled, fromY + uy * traveled)
        traveled = traveled + spacing
    end

    self.lineParticleRemainder = (self.lineParticleRemainder or 0) + distance
    self.lineParticleRemainder = self.lineParticleRemainder % spacing
end

function Dash:spawnShockwave()
    local shockwave = self.config.shockwave
    if not (shockwave and shockwave.enabled ~= false and Game and Game.addWeaponShockwave) then
        return
    end

    Game:addWeaponShockwave(
        self.player.x,
        self.player.y + (shockwave.offsetY or -4),
        shockwave
    )
end

function Dash:updateAfterimages(dt)
    for i = #self.afterimages, 1, -1 do
        local image = self.afterimages[i]
        image.timer = image.timer + dt
        if image.timer >= image.lifeTime then
            table.remove(self.afterimages, i)
        end
    end
end

function Dash:update(dt)
    self.cooldownTimer = math.max(0, self.cooldownTimer - dt)
    self:updateAfterimages(dt)

    if not self:isActive() then
        return 0, 0, false
    end

    self.timer = math.max(0, self.timer - dt)
    self.afterimageTimer = self.afterimageTimer + dt
    while self.afterimageTimer >= self.config.afterimageInterval do
        self.afterimageTimer = self.afterimageTimer - self.config.afterimageInterval
        self:captureAfterimage()
    end
    self.particleTimer = self.particleTimer + dt
    while self.particleTimer >= self.config.particleInterval do
        self.particleTimer = self.particleTimer - self.config.particleInterval
        self:spawnParticles()
    end

    local moveX = self.dirX * self.config.speed * dt
    local moveY = self.dirY * self.config.speed * dt
    return moveX, moveY, true
end

function Dash:stop()
    self.timer = 0
end

function Dash:cancel()
    self.timer = 0
    self.afterimageTimer = 0
    self.particleTimer = 0
    self.lineParticleRemainder = 0
    for i = #self.afterimages, 1, -1 do
        self.afterimages[i] = nil
    end
end

function Dash:reset()
    self:cancel()
    self.cooldownTimer = 0
    self.dirX = 0
    self.dirY = 0
end

function Dash:restartCooldown()
    self.cooldownTimer = self.config.cooldown or 0
end

function Dash:beginTint(color, strength)
    tintShader:send("tintStrength", strength or 0.5)
    love.graphics.setShader(tintShader)
    love.graphics.setColor(color[1], color[2], color[3], color[4])
end

function Dash:endTint()
    love.graphics.setShader()
    love.graphics.setColor(1, 1, 1, 1)
end

function Dash:beginPlayerTint()
    self:beginTint(self.config.playerTintColor, self.config.playerTintStrength)
end

function Dash:drawAfterimages(player)
    if #self.afterimages == 0 then
        return
    end

    local config = self.config
    for _, image in ipairs(self.afterimages) do
        local progress = math.max(0, math.min(image.timer / math.max(image.lifeTime, 0.001), 1))
        local color = colorAt(config.afterimageStartColor, config.afterimageEndColor, progress)
        local tintStrength = (config.afterimageTintStrengthStart or 0.62)
            + ((config.afterimageTintStrengthEnd or 0.28) - (config.afterimageTintStrengthStart or 0.62)) * progress
        if color[4] > 0.01 then
            local stretch = image.stretch or 0
            local scaleX = (image.flipH and -1 or 1) * (1 - stretch * 0.5)
            local scaleY = 1.5 * (1 + stretch)
            local originX = image.flipH and (player.spriteSize - player.spriteSize / 2) or (player.spriteSize / 2)
            self:beginTint(color, tintStrength)
            love.graphics.draw(player.playerSheet, image.quad, image.x, image.y, 0, scaleX, scaleY, originX, player.spriteSize)
            if image.handQuad and (not player.gun or not player.gun.showGun) then
                love.graphics.draw(player.idleHandSheet, image.handQuad, image.x, image.y, 0, scaleX, scaleY, originX, player.spriteSize)
            end
            self:endTint()
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return Dash
