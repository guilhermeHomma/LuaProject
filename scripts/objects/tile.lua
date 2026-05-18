Tile = {}
Tile.__index = Tile
TileSet = require("scripts.objects.tileset")
local Ball = require("scripts/particles/ballParticle")
local BoxParticle = require("scripts/particles/boxParticle")
local FootStep = require("scripts/particles/footstep")
local DamageStretch = require("scripts/effects/damageStretch")
local DropTemplates = require("scripts/drops/dropTemplates")
local breakBoxBase = love.audio.newSource("assets/sfx/particles/break-box.mp3", "static")
local coinDropBase = love.audio.newSource("assets/sfx/drops/coin-drop.mp3", "static")
local shadowQuad = nil
local whiteShader = love.graphics.newShader("scripts/shaders/whiteShader.glsl")

local function getBoxParticleDropKey(tile)
    local FloorManager = require("scripts/managers/floorManager")
    local room = FloorManager:getCurrentRoom()
    local roomId = room and room.id or "room"
    return roomId .. ":" .. tile.x .. ":" .. tile.y
end

local function hasDroppedBoxParticle(tile)
    local FloorManager = require("scripts/managers/floorManager")
    local state = FloorManager:getCurrentRoomState()
    local key = getBoxParticleDropKey(tile)
    return state
        and state.boxParticlesDropped
        and state.boxParticlesDropped[key] == true
end

local function markBoxParticleDropped(tile)
    local FloorManager = require("scripts/managers/floorManager")
    local state = FloorManager:getCurrentRoomState()
    if not state then
        return
    end

    state.boxParticlesDropped = state.boxParticlesDropped or {}
    state.boxParticlesDropped[getBoxParticleDropKey(tile)] = true
end

local function hasNearbyBoxParticle(tile)
    local maxDistanceSq = 14 * 14

    for _, particle in ipairs((Game and Game.particles) or {}) do
        if particle.particleType == "boxParticle" and particle.isAlive then
            local dx = particle.x - tile.xWorld
            local dy = particle.y - tile.yWorld
            if dx * dx + dy * dy <= maxDistanceSq then
                return true
            end
        end
    end

    return false
end

local function playClonedSound(baseSource, volume, pitch)
    local sound = baseSource:clone()
    sound:setVolume(volume)
    sound:setPitch(pitch)
    sound:play()
    return sound
end


function Tile:setTilemap(tilemap)
    Tile.tilemap = tilemap
end

function Tile:new(x, y, quadIndex, collider)
    if quadIndex == 14 and math.random() > 0.4 then
        quadIndex = 18
    end

    if collider == nil then collider = true end

    local tile = setmetatable({}, Tile)
    local tileSet = TileSet:getTileSet()
    local tileSize = TileSet.tileSize

    tile.quad = tileSet[quadIndex]
    tile.quad2 = tileSet[quadIndex]
    tile.quadIndex = quadIndex
    if tile.quadIndex == 1 or tile.quadIndex == 2 or tile.quadIndex == 3 then
        tile.quad2 = tileSet[quadIndex + 3]
    end

    
    tile.x = x
    tile.y = y
    tile.size = tileSize
    tile.alpha = 1
    tile.collider = collider
    tile.xWorld, tile.yWorld = Tile.tilemap:mapToWorld(x,y)
    tile.distance = 0
    tile.isAlive = true
    tile.isBreaking = false
    tile.hasExploded = false
    tile.hasDroppedBoxParticle = false
    tile.breakTimer = 0
    tile.breakDuration = 0.1
    if tile.quadIndex == 14 or tile.quadIndex == 18 then
        tile.life = 20
        tile.hitFlashTimer = 0
        tile.hitFlashDuration = 0.08
        DamageStretch:init(tile, 0.12, 0.08)
    end
    return tile
end

function Tile:update(dt)
    if self.isAlive then
        addToDrawQueue(self.yWorld, self)
    end

    if self.isBreaking then
        self.breakTimer = self.breakTimer + dt
        if self.breakTimer >= self.breakDuration and self.life <= 0 then
            self:explodeBox()
        end
    end

    if self.hitFlashTimer and self.hitFlashTimer > 0 then
        self.hitFlashTimer = math.max(0, self.hitFlashTimer - dt)
    end
end

function Tile:onshoot(damage)
    if not self.isAlive or self.isBreaking then return end
    if self.quadIndex == 14 or self.quadIndex == 18 then --box
        self.hitFlashTimer = self.hitFlashDuration or 0.08
        DamageStretch:start(self)
        self.life = (self.life or 30) - (damage or 10)
        if self.life > 0 then
            return
        end

        self.collider = false
        local FloorManager = require("scripts/managers/floorManager")
        FloorManager:markCurrentRoomObjectBroken(self.x, self.y)
        Tile.tilemap.getTilemap()[self.y][self.x] = 0
        Tile.tilemap:loadfinders()
        self.isBreaking = true
        self.breakTimer = 0
    end
end


function Tile:explodeBox()
    if not self.isAlive or self.hasExploded then return end

    self.hasExploded = true
    self.isBreaking = false
    self.isAlive = false

    for i = 1, 3 do
        local angle = math.random() * 2 * math.pi

        local dx = math.cos(angle)
        local dy = math.sin(angle)
        
        local lifetime = math.random(40, 50) / 100
        local size = math.random(8, 10) / 10
        local particle = Ball:new(self.xWorld, self.yWorld, 1,dx, dy, lifetime, size )
        table.insert(Game.particles, particle)
        local particle = Ball:new(self.xWorld, self.yWorld, 1,-dx, -dy, lifetime, size )
        table.insert(Game.particles, particle)
    end

    local footstep = FootStep:new(self.xWorld, self.yWorld-8)
    table.insert(Game.footsteps, footstep)

    if not self.hasDroppedBoxParticle and not hasDroppedBoxParticle(self) and not hasNearbyBoxParticle(self) then
        self.hasDroppedBoxParticle = true
        markBoxParticleDropped(self)
        local bp = BoxParticle:new(self.xWorld, self.yWorld)
        table.insert(Game.particles, bp)
    else
        self.hasDroppedBoxParticle = true
        markBoxParticleDropped(self)
    end

    local playerDistance = distance(Player, self)
    
    local volume = getDistanceVolume(playerDistance, 0.3, 200)
    playClonedSound(breakBoxBase, volume, (0.9 + math.random() * 0.1) * GAME_PITCH)

    playerDistance = distance(Player, self)
    volume = getDistanceVolume(playerDistance, 0.4, 200)

    local resolvedDrops = DropTemplates.resolve(
        DropTemplates.getObjectConfig("box"),
        { player = Player, source = self }
    )

    if #resolvedDrops > 0 then
        playClonedSound(coinDropBase, volume, (1 + math.random() * 0.1) * GAME_PITCH)
        DropTemplates.spawnResolvedDrops(resolvedDrops, self.xWorld, self.yWorld, Game.objects)
    end
end

function Tile:draw()
    if not self.isAlive then
        return
    end

    local tileSet = TileSet:getTileSet()
    local tileSize = TileSet.tileSize
    local tilesetImage = TileSet.tilesetImage

    if self.quadIndex == 14 or self.quadIndex == 18 then --box
        local scaleX = 1
        local scaleY = 1
        local yOffset = 0
        if self.isBreaking then
            local progress = math.min(self.breakTimer / self.breakDuration, 1)
            local squash = 0

            if progress < 0.45 then
                squash = progress / 0.45
            else
                squash = 1 - ((progress - 0.45) / 0.55)
            end

            scaleX = 1 + squash * 0.05
            scaleY = 1 - squash * 0.05
            yOffset = squash 
        elseif self.hitFlashTimer and self.hitFlashTimer > 0 then
            scaleX, scaleY = DamageStretch:getScale(self)
        end

        if self.isBreaking or (self.hitFlashTimer and self.hitFlashTimer > 0) then
            local alpha = self.isBreaking and 0.7 or (self.hitFlashTimer / (self.hitFlashDuration or 0.08))
            love.graphics.setColor(1, 1, 1, alpha)
            love.graphics.setShader(whiteShader)
        end
        love.graphics.draw(tilesetImage, self.quad, self.xWorld, self.yWorld + yOffset, 0, scaleX, scaleY, tileSize/2, tileSize*2)
        love.graphics.setShader()
        love.graphics.setColor(1, 1, 1, 1)

    elseif self.quadIndex == 1 or self.quadIndex == 2 or self.quadIndex == 3  then
        love.graphics.draw(tilesetImage, self.quad, self.xWorld, self.yWorld - 16, 0, 1, 1, tileSize/2, tileSize)
        love.graphics.draw(tilesetImage, self.quad2, self.xWorld, self.yWorld, 0, 1, 1, tileSize/2, tileSize)
    else
       love.graphics.draw(tilesetImage, self.quad, self.xWorld, self.yWorld, 0, 1, 1, tileSize/2, tileSize)
    end

    self:drawDebug()
end

function Tile:drawDebug()
    if self.collider and DEBUG then
        playerX, playerY = Tile.tilemap:worldToMap(Player.x, Player.y)
        if playerX == self.x and playerY == self.y then
            love.graphics.setColor(1, 0.5, 0.5, 1)
        end
        love.graphics.rectangle("line", self.xWorld-8, self.yWorld-16, 16, 16)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

function Tile:drawShadow()
    if self.quadIndex == 5 or self.quadIndex == 15 then 
        return
    end

    local tilesetImage = TileSet.tilesetImage
    if not shadowQuad then
        shadowQuad = love.graphics.newQuad(110, 14, 20, 20, TileSet.sheetWidth, TileSet.sheetHeight)
    end
    love.graphics.draw(tilesetImage, shadowQuad, self.xWorld, self.yWorld, 0, 1, 1, 10, 16)
end


return Tile
