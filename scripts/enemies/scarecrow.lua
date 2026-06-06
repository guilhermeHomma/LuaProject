local Scarecrow = {}
Scarecrow.__index = Scarecrow

local DamageStretch = require("scripts/effects/damageStretch")
local DropTemplates = require("scripts/drops/dropTemplates")
local EnemyDeadDropParticle = require("scripts/particles/enemyDeadDropParticle")
local Ball = require("scripts/particles/ballParticle")
local BloodPixel = require("scripts/particles/bloodPixel")
local FootStep = require("scripts/particles/footstep")
local FloorManager = require("scripts/managers/floorManager")
local DamageImpactParticle = require("scripts/particles/damageImpactParticle")
local EnemyDeathProjectiles = require("scripts/enemies/enemyDeathProjectiles")

require("scripts/utils")

local sprite = love.graphics.newImage("assets/sprites/enemy/scarecrow/scarecrow.png")
local shadowSprite = love.graphics.newImage("assets/sprites/enemy/zombie/enemyShadow.png")
local whiteShader = love.graphics.newShader("scripts/shaders/whiteShader.glsl")
local outlineShader = love.graphics.newShader("scripts/shaders/outlineCardinal.glsl")
local enemyDamageBase = love.audio.newSource("assets/sfx/enemyDamage.mp3", "static")
local breakBoxBase = love.audio.newSource("assets/sfx/particles/break-box.mp3", "static")
local coinDropBase = love.audio.newSource("assets/sfx/drops/coin-drop.mp3", "static")

sprite:setFilter("nearest", "nearest")
shadowSprite:setFilter("nearest", "nearest")
outlineShader:send("u_threshold", 0.1)
outlineShader:send("u_outlineColor", {1, 1, 1, 1})
outlineShader:send("u_texel", {1 / sprite:getWidth(), 1 / sprite:getHeight()})
outlineShader:send("u_uvMin", {0, 0})
outlineShader:send("u_uvMax", {1, 1})

local strawBloodPalette = {
    {0.55, 0.52, 0.43, 1},
    {0.42, 0.40, 0.34, 1},
    {0.66, 0.62, 0.50, 1},
    {0.34, 0.33, 0.30, 1},
    {0.48, 0.46, 0.38, 1},
}
local mortarBallOptions = {
    sizeMultiplier = 1.15,
    speedMultiplier = 1.4,
    speedDownMultiplier = 1.4,
}

local function playClonedSound(baseSource, volume, pitch)
    local sound = baseSource:clone()
    sound:setVolume(volume)
    sound:setPitch(pitch)
    sound:play()
    return sound
end

local function getLightTint(enemy)
    local brightness = enemy and enemy.lightBrightness or 1
    brightness = math.max(brightness, 0.8)
    return brightness, brightness, brightness
end

function Scarecrow:new(x, y)
    local scarecrow = setmetatable({}, Scarecrow)
    scarecrow.x = x
    scarecrow.y = y
    scarecrow.totalLife = 22
    scarecrow.life = scarecrow.totalLife
    scarecrow.size = 12
    scarecrow.dropPoints = 0
    scarecrow.drawPriority = math.random()
    scarecrow.isAlive = true
    scarecrow.isXrayVisible = true
    scarecrow.blocksPlayer = true
    scarecrow.canDamagePlayer = false
    scarecrow.hitFlashTimer = 0
    scarecrow.hitFlashDuration = 0.08
    scarecrow.breakTimer = 0
    scarecrow.breakDuration = 0.1
    scarecrow.isBreaking = false
    scarecrow.hasDropped = false
    scarecrow.tutorialDelay = 10
    scarecrow.tutorialTimer = 0
    scarecrow.tutorialTriggered = false
    scarecrow.showTutorialOutline = false
    DamageStretch:init(scarecrow, 0.12, 0.08)
    return scarecrow
end

function Scarecrow:collisionBox(x, y, size)
    if not x then x = self.x end
    if not y then y = self.y end
    if not size then size = self.size or 12 end

    return {x = x - size/2, y = y - size/2, width = size, height = size}
end

function Scarecrow:getDamageImpactPosition()
    return self.x, self.y - 29
end

function Scarecrow:spawnDamageImpact(dx, dy)
    if Game and Game.particles then
        table.insert(Game.particles, DamageImpactParticle:new(self, dx, dy))
    end
end

function Scarecrow:takeDamage(damage, dx, dy)
    if not self.isAlive or self.isBreaking then
        return
    end

    self:spawnDamageImpact(dx, dy)
    self.hitFlashTimer = self.hitFlashDuration
    DamageStretch:start(self)
    self.life = self.life - (damage or 10)
    BloodPixel.spawnBurst(self.x, self.y - 8, 0, -1, 4, 6, strawBloodPalette)
    playClonedSound(enemyDamageBase, 0.8, (1 + math.random() * 0.1) * GAME_PITCH)

    if self.life <= 0 then
        self.isBreaking = true
        self.breakTimer = 0
        self.blocksPlayer = false
    end
end

function Scarecrow:dropCoins()
    if self.hasDropped then
        return
    end

    self.hasDropped = true
    local playerDistance = distance(Player, self)
    local volume = getDistanceVolume(playerDistance, 0.4, 200)
    playClonedSound(coinDropBase, volume, (1 + math.random() * 0.1) * GAME_PITCH)
    DropTemplates.spawnResolvedDrops({
        { id = "coins", amount = 2 },
    }, self.x, self.y, Game.objects)
end

function Scarecrow:breakApart()
    if not self.isAlive then
        return
    end

    for i = 1, 3 do
        local angle = math.random() * 2 * math.pi
        local dx = math.cos(angle)
        local dy = math.sin(angle)
        local lifetime = math.random(40, 50) / 100
        local size = math.random(8, 10) / 10
        table.insert(Game.particles, Ball:new(self.x, self.y, 1, dx, dy, lifetime, size, mortarBallOptions))
        table.insert(Game.particles, Ball:new(self.x, self.y, 1, -dx, -dy, lifetime, size, mortarBallOptions))
    end
    BloodPixel.spawnBurst(self.x, self.y - 8, 0, -1, 9, 12, strawBloodPalette)

    table.insert(Game.footsteps, FootStep:new(self.x, self.y - 8))
    for _ = 1, 2 do
        table.insert(Game.particles, EnemyDeadDropParticle:new(self.x, self.y))
    end

    local playerDistance = distance(Player, self)
    local volume = getDistanceVolume(playerDistance, 0.3, 200)
    playClonedSound(breakBoxBase, volume, (0.9 + math.random() * 0.1) * GAME_PITCH)
    self:dropCoins()

    local state = FloorManager:getCurrentRoomState()
    if state then
        state.scarecrowDestroyed = true
    end

    EnemyDeathProjectiles.spawn(self)
    self.isAlive = false
end

function Scarecrow:triggerShootTutorial()
    if self.tutorialTriggered then
        return
    end

    self.tutorialTriggered = true
    self.showTutorialOutline = true

    local Tutorial = require("scripts/managers/tutorial")
    Tutorial.drawWalk = false
    Tutorial.drawInteract = false
    Tutorial.drawmouse = true
    Tutorial.tutorialTimer = Tutorial.startTutorialTime or 0
end

function Scarecrow:update(dt)
    addToDrawQueue(self.y + 6 + self.drawPriority, self)

    if self.hitFlashTimer > 0 then
        self.hitFlashTimer = math.max(0, self.hitFlashTimer - dt)
    end

    if self.isBreaking then
        self.breakTimer = self.breakTimer + dt
        if self.breakTimer >= self.breakDuration then
            self:breakApart()
        end
    end

    local state = FloorManager:getCurrentRoomState()
    local canStartShootTutorialTimer = state and state.playerMovedForScarecrowTutorial == true
    if canStartShootTutorialTimer and not self.isBreaking and not self.tutorialTriggered then
        self.tutorialTimer = self.tutorialTimer + dt
        if self.tutorialTimer >= self.tutorialDelay then
            self:triggerShootTutorial()
        end
    end
end

function Scarecrow:drawShadow()
    if not self.isAlive then
        return
    end

    love.graphics.draw(shadowSprite, self.x - 6, self.y - 6, 0, 1, 1)
end

function Scarecrow:draw()
    if not self.isAlive then
        return
    end

    local scaleX = 1
    local scaleY = 1
    local yOffset = 0

    if self.isBreaking then
        local progress = math.min(self.breakTimer / self.breakDuration, 1)
        local squash = progress < 0.45 and progress / 0.45 or 1 - ((progress - 0.45) / 0.55)
        scaleX = 1 + squash * 0.05
        scaleY = 1 - squash * 0.05
        yOffset = squash
    elseif self.hitFlashTimer > 0 then
        scaleX, scaleY = DamageStretch:getScale(self)
    end

    local r, g, b = getLightTint(self)

    if self.isBreaking or self.hitFlashTimer > 0 then
        love.graphics.setShader(whiteShader)
        love.graphics.setColor(1, 1, 1, self.isBreaking and 0.7 or self.hitFlashTimer / self.hitFlashDuration)
    elseif self.showTutorialOutline then
        love.graphics.setShader(outlineShader)
    end
    if not (self.isBreaking or self.hitFlashTimer > 0) then
        love.graphics.setColor(r, g, b, 1)
    end

    love.graphics.draw(sprite, self.x, self.y + yOffset, 0, scaleX, scaleY * 1.2, 16, 48)
    love.graphics.setShader()
    love.graphics.setColor(1, 1, 1, 1)

    if DEBUG then
        local box = self:collisionBox()
        love.graphics.rectangle("line", box.x, box.y, box.width, box.height)
    end
end

function Scarecrow:drawXray()
    if not self.isAlive then
        return
    end

    local scaleX = 1
    local scaleY = 1
    local yOffset = 0

    if self.isBreaking then
        local progress = math.min(self.breakTimer / self.breakDuration, 1)
        local squash = progress < 0.45 and progress / 0.45 or 1 - ((progress - 0.45) / 0.55)
        scaleX = 1 + squash * 0.05
        scaleY = 1 - squash * 0.05
        yOffset = squash
    elseif self.hitFlashTimer > 0 then
        scaleX, scaleY = DamageStretch:getScale(self)
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(sprite, self.x, self.y + yOffset, 0, scaleX, scaleY * 1.2, 16, 48)
end

return Scarecrow
