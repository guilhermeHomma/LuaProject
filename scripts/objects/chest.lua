local Chest = {}
Chest.__index = Chest

local DamageStretch = require("scripts/effects/damageStretch")
local Localization = require("scripts/managers/localization")
local DropTemplates = require("scripts/drops/dropTemplates")
local Ball = require("scripts/particles/ballParticle")
local TileSet = require("scripts.objects.tileset")
local BulletColorParticle = require("scripts/particles/bulletColorParticle")

require("scripts/utils")

local sprite = love.graphics.newImage("assets/sprites/chest/woodchest.png")
local cardSprite = love.graphics.newImage("assets/sprites/chest/simplecardchest.png")
local whiteShader = love.graphics.newShader("scripts/shaders/whiteShader.glsl")
local openSoundBase = love.audio.newSource("assets/sfx/particles/break-box.mp3", "static")
local shadowQuad = nil
local frameWidth = 16
local frameHeight = 32
local cardParticlePalette = {
    {0.52, 0.16, 0.68, 1},
    {0.18, 0.56, 0.60, 1},
    {0.70, 0.22, 0.46, 1},
    {0.62, 0.52, 0.18, 1},
    {0.24, 0.62, 0.34, 1},
}
local cardParticleOptions = {
    speedMin = 4,
    speedMax = 15,
    lifeTime = 0.68,
    size = 1,
}
local quads = {
    closed = love.graphics.newQuad(0, 0, frameWidth, frameHeight, sprite:getDimensions()),
    open = love.graphics.newQuad(frameWidth, 0, frameWidth, frameHeight, sprite:getDimensions()),
}
local cardQuads = {
    closed = love.graphics.newQuad(0, 0, frameWidth, frameHeight, cardSprite:getDimensions()),
    open = love.graphics.newQuad(frameWidth, 0, frameWidth, frameHeight, cardSprite:getDimensions()),
}

sprite:setFilter("nearest", "nearest")
cardSprite:setFilter("nearest", "nearest")

local function playClonedSound(baseSource, volume, pitch)
    local sound = baseSource:clone()
    sound:setVolume(volume)
    sound:setPitch(pitch)
    sound:play()
    return sound
end

local function getChestKey(chest)
    local FloorManager = require("scripts/managers/floorManager")
    local room = FloorManager:getCurrentRoom()
    local roomId = room and room.id or "room"
    return roomId .. ":" .. chest.x .. ":" .. chest.y
end

local function isPersistedOpen(chest)
    local FloorManager = require("scripts/managers/floorManager")
    local state = FloorManager:getCurrentRoomState()
    local key = getChestKey(chest)
    return state and state.openedChests and state.openedChests[key] == true
end

local function markPersistedOpen(chest)
    local FloorManager = require("scripts/managers/floorManager")
    local state = FloorManager:getCurrentRoomState()
    if not state then
        return
    end

    state.openedChests = state.openedChests or {}
    state.openedChests[getChestKey(chest)] = true
end

local function configureChestDrop(drop, kind, key, chest, dropIndex)
    drop.persistRoomDrop = true
    drop.neverExpires = true
    drop.requirePickupKey = true
    drop.pickupDistance = 24
    drop.fromChest = true
    drop.roomDropKey = key
    drop.dropKind = kind
    drop.pickupX = chest.xWorld
    drop.pickupY = chest.yWorld
    drop.drawBaseY = chest.yWorld
    drop.drawPriorityOffset = 0.35 + (dropIndex or 1) * 0.04
    drop.drawSortOrder = dropIndex or 0
    drop.vx = drop.vx or 0
    drop.vy = drop.vy or 0
    return drop
end

local function rememberChestDrop(key, kind, x, y, chest, chestDrop)
    local FloorManager = require("scripts/managers/floorManager")
    local state = FloorManager:getCurrentRoomState()
    if not state then
        return
    end

    state.drops = state.drops or {}
    state.drops[key] = state.drops[key] or {
        kind = kind,
        x = x,
        y = y,
        pickupX = chest.xWorld,
        pickupY = chest.yWorld,
        drawBaseY = chest.yWorld,
        drawPriorityOffset = chestDrop and chestDrop.drawPriorityOffset or nil,
        drawSortOrder = chestDrop and chestDrop.drawSortOrder or nil,
        collected = false,
    }
end

function Chest:new(x, y, chestType)
    local chest = setmetatable({}, Chest)
    chest.x = x
    chest.y = y
    chest.chestType = chestType or "wood"
    chest.sprite = chest.chestType == "card" and cardSprite or sprite
    chest.quads = chest.chestType == "card" and cardQuads or quads
    chest.size = TileSet.tileSize
    chest.xWorld, chest.yWorld = Tile.tilemap:mapToWorld(x, y)
    chest.isAlive = true
    chest.isOpen = isPersistedOpen(chest)
    chest.collider = true
    chest.isXrayOccluder = true
    chest.isXrayBoxOccluder = true
    chest.isOpening = false
    chest.openTimer = 0
    chest.openDuration = 0.42
    chest.dropSpawned = chest.isOpen
    chest.interactionDistance = 22
    chest.flashTimer = 0
    chest.flashDuration = 0.32
    chest.beamTimer = 0
    chest.beamDuration = 1.05
    chest.beamElapsed = 0
    chest.particleTimer = 0
    chest.particleInterval = 0.025
    chest.cardParticleTimer = math.random() * 0.2
    DamageStretch:init(chest, 0.18, 0.12)
    return chest
end

function Chest:isPlayerNear()
    return Player and distance(Player, self) <= self.interactionDistance
end

function Chest:spawnDrop()
    local spawnX = self.xWorld
    local spawnY = self.yWorld
    local baseKey = getChestKey(self) .. ":drop:"
    local config = DropTemplates.getObjectConfig(self.chestType == "card" and "cardChest" or "chest")
    local resolvedDrops = DropTemplates.resolve(config, { player = Player, source = self })
    local dropIndex = 0

    DropTemplates.spawnResolvedDrops(resolvedDrops, spawnX, spawnY, Game.objects, function(drop, kind)
        dropIndex = dropIndex + 1
        local key = baseKey .. kind .. dropIndex
        local spawnBaseHeight = 8
        local idleBaseHeight = 24
        local popGravity = 250
        local popPeakHeight = idleBaseHeight + 3

        drop.baseHeight = spawnBaseHeight
        drop.idleBaseHeight = idleBaseHeight
        drop.raiseBaseHeightAfterPop = true
        drop.baseHeightRiseSpeed = 18
        drop.hoverHeight = drop.baseHeight
        drop.hoverAmplitude = kind == "life" and 2.6 or 2.2
        drop.hoverSpeed = kind == "life" and 2.7 or 2.4
        drop.popHeight = 0
        drop.popVelocity = math.sqrt(math.max(0, 2 * popGravity * (popPeakHeight - spawnBaseHeight)))
        drop.popGravity = popGravity
        drop.popMaxBounces = 0
        drop.spawnStretchTimer = math.max(drop.spawnStretchTimer or 0, 0.18)
        drop.spawnStretchDuration = 0.18
        drop.height = (drop.hoverHeight or drop.baseHeight or 0) + (drop.popHeight or 0)
        configureChestDrop(drop, kind, key, self, dropIndex)
        rememberChestDrop(key, kind, spawnX, spawnY, self, drop)
        return drop
    end)
end

function Chest:spawnBeamParticle()
    local x = self.xWorld + math.random(-3, 3)
    local y = self.yWorld - 3 + math.random(-1, 1)
    local particle = Ball:new(x, y, 0, math.random(-3, 3) / 10, -1.6 - math.random() * 0.7, 0.35, 0.45, {
        rgbShift = { duration = 0.22, shift = 1.2 }
    })
    particle.drawPriorityY = self.yWorld + 12
    table.insert(Game.particles, particle)
end

function Chest:spawnCardParticle(count)
    if self.chestType ~= "card" then
        return
    end

    local firstParticleIndex = Game and Game.particles and (#Game.particles + 1) or nil
    BulletColorParticle.spawnBurst(
        self.xWorld + math.random(-6, 6),
        self.yWorld - 14 + math.random(-4, 4),
        1,
        cardParticlePalette,
        count or 1,
        cardParticleOptions
    )

    if firstParticleIndex and Game and Game.particles then
        for index = firstParticleIndex, #Game.particles do
            Game.particles[index].drawPriorityY = self.yWorld + 18
        end
    end
end

function Chest:open()
    if self.isOpen or self.isOpening then
        return
    end

    self.isOpening = true
    self.openTimer = 0
    self.flashTimer = self.flashDuration
    self.beamTimer = self.beamDuration
    self.beamElapsed = 0
    self.particleTimer = 0
    DamageStretch:start(self)
    markPersistedOpen(self)
    self:spawnCardParticle(34)

    local playerDistance = distance(Player, self)
    local volume = getDistanceVolume(playerDistance, 0.35, 220)
    playClonedSound(openSoundBase, volume, (1.05 + math.random() * 0.1) * GAME_PITCH)
end

function Chest:keypressed(key)
    if key == "f" and self:isPlayerNear() then
        self:open()
    end
end

function Chest:update(dt)
    addToDrawQueue(self.yWorld, self)

    if not self.isOpen and not self.isOpening and self:isPlayerNear() then
        Game.drawtext = Localization:t("game.press_open")
        Game.textAlphaTarget = 1
    end

    if self.chestType == "card" and not self.isOpen then
        self.cardParticleTimer = (self.cardParticleTimer or 0) + dt
        local interval = self.isOpening and 0.028 or 0.12
        while self.cardParticleTimer >= interval do
            self.cardParticleTimer = self.cardParticleTimer - interval
            self:spawnCardParticle(self.isOpening and 3 or 1)
        end
    end

    if self.flashTimer > 0 then
        self.flashTimer = math.max(0, self.flashTimer - dt)
    end

    if self.isOpening then
        self.openTimer = math.min(self.openDuration, self.openTimer + dt)
        if self.openTimer >= self.openDuration then
            self.isOpening = false
            self.isOpen = true
            self.collider = true
            if not self.dropSpawned then
                self.dropSpawned = true
                self:spawnDrop()
            end
        end
    end

    if self.beamTimer > 0 then
        self.beamTimer = math.max(0, self.beamTimer - dt)
        self.beamElapsed = math.min(self.beamDuration, (self.beamElapsed or 0) + dt)
        self.particleTimer = self.particleTimer + dt
        while self.particleTimer >= self.particleInterval do
            self.particleTimer = self.particleTimer - self.particleInterval
            self:spawnBeamParticle()
        end
    end
end

local function smoothStep(value)
    value = math.max(0, math.min(1, value))
    return value * value * (3 - 2 * value)
end

local function getBeamAlpha(chest)
    local elapsed = chest.beamElapsed or 0
    local remaining = chest.beamTimer or 0
    local fadeIn = 0.16
    local fadeOut = 0.42
    local inAlpha = smoothStep(elapsed / fadeIn)
    local outAlpha = smoothStep(remaining / fadeOut)
    return math.min(inAlpha, outAlpha)
end

local function drawBeamLayer(chest, baseHalfWidth, topHalfWidth, height, color, alpha)
    local segments = 10
    local bottomY = chest.yWorld - 8
    local topY = bottomY - height

    for i = 0, segments - 1 do
        local p1 = i / segments
        local p2 = (i + 1) / segments
        local y1 = bottomY + (topY - bottomY) * p1
        local y2 = bottomY + (topY - bottomY) * p2
        local half1 = baseHalfWidth + (topHalfWidth - baseHalfWidth) * p1
        local half2 = baseHalfWidth + (topHalfWidth - baseHalfWidth) * p2
        local topFade = (1 - p1) ^ 1.7
        love.graphics.setColor(color[1], color[2], color[3], alpha * topFade)
        love.graphics.polygon(
            "fill",
            chest.xWorld - half1, y1,
            chest.xWorld + half1, y1,
            chest.xWorld + half2, y2,
            chest.xWorld - half2, y2
        )
    end
end

function Chest:drawBeam()
    if self.beamTimer <= 0 then
        return
    end

    local alpha = getBeamAlpha(self)
    local previousBlendMode, previousAlphaMode = love.graphics.getBlendMode()
    love.graphics.setBlendMode("add", "alphamultiply")
    drawBeamLayer(self, 3, 11, 88, {0.35, 0.95, 1}, 0.20 * alpha)
    drawBeamLayer(self, 1.2, 5.5, 84, {1, 0.35, 0.95}, 0.13 * alpha)
    love.graphics.setBlendMode(previousBlendMode, previousAlphaMode)
    love.graphics.setColor(1, 1, 1, 1)
end

function Chest:draw()
    local scaleX, scaleY = DamageStretch:getScale(self)
    local activeQuads = self.quads or quads
    local quad = (self.isOpen and not self.isOpening) and activeQuads.open or activeQuads.closed

    if self:isPlayerNear() and not self.isOpen then
        local pulse = math.sin(love.timer.getTime() * 10) * 0.035
        scaleX = scaleX + pulse
        scaleY = scaleY - pulse * 0.7
    end

    self:drawBeam()

    if self.flashTimer > 0 then
        love.graphics.setShader(whiteShader)
        love.graphics.setColor(1, 1, 1, self.flashTimer / self.flashDuration)
    else
        love.graphics.setColor(1, 1, 1, 1)
    end

    love.graphics.draw(self.sprite or sprite, quad, self.xWorld, self.yWorld, 0, scaleX, scaleY, frameWidth / 2, frameHeight)
    love.graphics.setShader()
    love.graphics.setColor(1, 1, 1, 1)
end

function Chest:drawXrayOccluder()
    local activeQuads = self.quads or quads
    local quad = (self.isOpen and not self.isOpening) and activeQuads.open or activeQuads.closed
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.sprite or sprite, quad, self.xWorld, self.yWorld, 0, 1, 1, frameWidth / 2, frameHeight)
end

function Chest:drawShadow()
    if not shadowQuad then
        shadowQuad = love.graphics.newQuad(110, 14, 20, 20, TileSet.sheetWidth, TileSet.sheetHeight)
    end

    love.graphics.draw(TileSet.tilesetImage, shadowQuad, self.xWorld, self.yWorld, 0, 1, 1, 10, 16)
end

return Chest
