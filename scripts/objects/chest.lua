local Chest = {}
Chest.__index = Chest

local DamageStretch = require("scripts/effects/damageStretch")
local DropTemplates = require("scripts/drops/dropTemplates")
local Ball = require("scripts/particles/ballParticle")
local TileSet = require("scripts.objects.tileset")

require("scripts/utils")

local sprite = love.graphics.newImage("assets/sprites/chest/woodchest.png")
local whiteShader = love.graphics.newShader("scripts/shaders/whiteShader.glsl")
local openSoundBase = love.audio.newSource("assets/sfx/particles/break-box.mp3", "static")
local shadowQuad = nil
local frameWidth = 16
local frameHeight = 32
local quads = {
    closed = love.graphics.newQuad(0, 0, frameWidth, frameHeight, sprite:getDimensions()),
    open = love.graphics.newQuad(frameWidth, 0, frameWidth, frameHeight, sprite:getDimensions()),
}

sprite:setFilter("nearest", "nearest")

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

local function configureChestDrop(drop, kind, key, chest)
    drop.persistRoomDrop = true
    drop.neverExpires = true
    drop.requirePickupKey = true
    drop.pickupDistance = 24
    drop.roomDropKey = key
    drop.dropKind = kind
    drop.pickupX = chest.xWorld
    drop.pickupY = chest.yWorld
    drop.drawBaseY = chest.yWorld
    drop.drawPriorityOffset = 12
    drop.vx = drop.vx or 0
    drop.vy = drop.vy or 0
    return drop
end

local function rememberChestDrop(key, kind, x, y, chest)
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
        collected = false,
    }
end

function Chest:new(x, y)
    local chest = setmetatable({}, Chest)
    chest.x = x
    chest.y = y
    chest.size = TileSet.tileSize
    chest.xWorld, chest.yWorld = Tile.tilemap:mapToWorld(x, y)
    chest.isAlive = true
    chest.isOpen = isPersistedOpen(chest)
    chest.collider = true
    chest.isOpening = false
    chest.openTimer = 0
    chest.openDuration = 0.42
    chest.dropSpawned = chest.isOpen
    chest.interactionDistance = 22
    chest.flashTimer = 0
    chest.flashDuration = 0.32
    chest.beamTimer = 0
    chest.beamDuration = 0.75
    chest.particleTimer = 0
    chest.particleInterval = 0.025
    DamageStretch:init(chest, 0.18, 0.12)
    return chest
end

function Chest:isPlayerNear()
    return Player and distance(Player, self) <= self.interactionDistance
end

function Chest:spawnDrop()
    local spawnX = self.xWorld
    local spawnY = self.yWorld - 10
    local baseKey = getChestKey(self) .. ":drop:"
    local config = DropTemplates.getObjectConfig("chest")
    local resolvedDrops = DropTemplates.resolve(config, { player = Player, source = self })
    local dropIndex = 0

    DropTemplates.spawnResolvedDrops(resolvedDrops, spawnX, spawnY, Game.objects, function(drop, kind)
        dropIndex = dropIndex + 1
        local key = baseKey .. kind .. dropIndex
        drop.popHeight = math.min(drop.popHeight or 0, 4)
        drop.popVelocity = math.min(drop.popVelocity or 0, 28)
        drop.popMaxBounces = 0
        drop.spawnStretchTimer = math.min(drop.spawnStretchTimer or 0, 0.12)
        drop.spawnStretchDuration = 0.12
        drop.height = (drop.hoverHeight or drop.baseHeight or 0) + (drop.popHeight or 0)
        rememberChestDrop(key, kind, spawnX, spawnY, self)
        return configureChestDrop(drop, kind, key, self)
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

function Chest:open()
    if self.isOpen or self.isOpening then
        return
    end

    self.isOpening = true
    self.openTimer = 0
    self.flashTimer = self.flashDuration
    self.beamTimer = self.beamDuration
    self.particleTimer = 0
    DamageStretch:start(self)
    markPersistedOpen(self)

    local playerDistance = distance(Player, self)
    local volume = getDistanceVolume(playerDistance, 0.35, 220)
    playClonedSound(openSoundBase, volume, (1.05 + math.random() * 0.1) * GAME_PITCH)
end

function Chest:keypressed(key)
    if key == "x" and self:isPlayerNear() then
        self:open()
    end
end

function Chest:update(dt)
    addToDrawQueue(self.yWorld, self)

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
        self.particleTimer = self.particleTimer + dt
        while self.particleTimer >= self.particleInterval do
            self.particleTimer = self.particleTimer - self.particleInterval
            self:spawnBeamParticle()
        end
    end
end

function Chest:drawBeam()
    if self.beamTimer <= 0 then
        return
    end

    local alpha = self.beamTimer / self.beamDuration
    love.graphics.setBlendMode("add")
    love.graphics.setColor(0.35, 0.95, 1, 0.22 * alpha)
    love.graphics.polygon("fill", self.xWorld - 3, self.yWorld - 8, self.xWorld + 3, self.yWorld - 8, self.xWorld + 10, self.yWorld - 92, self.xWorld - 10, self.yWorld - 92)
    love.graphics.setColor(1, 0.35, 0.95, 0.14 * alpha)
    love.graphics.polygon("fill", self.xWorld - 1, self.yWorld - 8, self.xWorld + 1, self.yWorld - 8, self.xWorld + 5, self.yWorld - 90, self.xWorld - 5, self.yWorld - 90)
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
end

function Chest:draw()
    local scaleX, scaleY = DamageStretch:getScale(self)
    local quad = (self.isOpen and not self.isOpening) and quads.open or quads.closed

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

    love.graphics.draw(sprite, quad, self.xWorld, self.yWorld, 0, scaleX, scaleY, frameWidth / 2, frameHeight)
    love.graphics.setShader()
    love.graphics.setColor(1, 1, 1, 1)
end

function Chest:drawShadow()
    if not shadowQuad then
        shadowQuad = love.graphics.newQuad(110, 14, 20, 20, TileSet.sheetWidth, TileSet.sheetHeight)
    end

    love.graphics.draw(TileSet.tilesetImage, shadowQuad, self.xWorld, self.yWorld, 0, 1, 1, 10, 16)
end

return Chest
