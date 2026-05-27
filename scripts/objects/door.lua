DoorTile = setmetatable({}, {__index = Tile})
DoorTile.__index = DoorTile

local sheetImage = love.graphics.newImage("assets/sprites/doors/doorWood.png")
sheetImage:setFilter("nearest", "nearest")
local lockIconImage = love.graphics.newImage("assets/sprites/icons/lock.png")
lockIconImage:setFilter("nearest", "nearest")
local whiteShader = love.graphics.newShader("scripts/shaders/whiteShader.glsl")
local doorHandleSoundBase = love.audio.newSource("assets/sfx/door/doorhandle.mp3", "static")
local doorCloseSoundBase = love.audio.newSource("assets/sfx/door/doorclose.mp3", "static")
local doorOpenSoundBase = love.audio.newSource("assets/sfx/door/dooropen.mp3", "static")
local doorSoundLastPlayed = {}

local sheetWidth, sheetHeight = sheetImage:getDimensions()
local frameWidth = 16
local frameHeight = 48
local lockIconSize = 10
local lockIconScaleY = 1.3
local lockIconYOffset = 24
local lockUnlockDuration = 0.3
local lockUnlockRise = 8
local lockDrawPriorityOffset = 0.1
local lockIconOffsets = {
    top = {x = 0, y = 8},
    bottom = {x = 0, y = -2},
    sideLeft = {x = -6.5, y = 0},
    sideRight = {x = 6.5, y = 0},
}

local function clampFrame(frame, startFrame, endFrame)
    local minFrame = math.min(startFrame, endFrame)
    local maxFrame = math.max(startFrame, endFrame)
    return math.max(minFrame, math.min(maxFrame, frame))
end

function DoorTile:new(x, y, quadIndex, collider, options)
    local tile = Tile.new(self, x, y, quadIndex, collider)
    setmetatable(tile, DoorTile)

    options = options or {}
    tile.frameSet = options.frameSet or "top"
    tile.reverse = options.reverse or false
    tile.mirrored = options.mirrored or false
    tile.frameSequence = options.frameSequence
    tile.closedFrame = options.closedFrame or (tile.frameSet == "bottom" and 4 or 1)
    tile.openFrame = options.openFrame or (tile.frameSet == "bottom" and 6 or 3)
    tile.doorPairKey = options.pairKey or ("single:" .. x .. ":" .. y)
    tile.ySortOffset = (options.ySortOffset or 0) + 2
    tile.frame = tile.frameSequence and 1 or tile.closedFrame
    tile.targetFrame = tile.frame
    tile.frameSpeed = options.frameSpeed or 12
    tile.defaultFrameSpeed = tile.frameSpeed
    tile.opening = false
    tile.openPhase = nil
    tile.open = false
    tile.alpha = 1
    tile.flashTimer = 0
    tile.flashDuration = 0.08
    tile.openDelayTimer = 0
    tile.openDelayDuration = 0.3
    tile.fadeTimer = 0
    tile.fadeDuration = 0.2
    tile.autoCloseTimer = 0
    tile.autoCloseDelay = 0.2
    tile.lockWasLocked = false
    tile.lockUnlockTimer = 0
    tile:loadQuad()

    return tile
end

function DoorTile:getSheetFrame()
    if self.frameSequence then
        local index = clampFrame(math.floor(self.frame + 0.5), 1, #self.frameSequence)
        return self.frameSequence[index]
    end

    local frame = clampFrame(math.floor(self.frame + 0.5), self.closedFrame, self.openFrame)
    if self.reverse then
        frame = self.openFrame - frame + self.closedFrame
    end
    return frame
end

local function getConnectedDoors(pairKey)
    local Tilemap = require("scripts/tilemap")
    local doors = {}

    for _, tile in ipairs(Tilemap.tiles or {}) do
        if tile.doorPairKey == pairKey and tile.openDoor and tile.closeDoor then
            doors[#doors + 1] = tile
        end
    end

    return doors
end

local function isDoorPairAnchor(door, doors)
    for _, other in ipairs(doors) do
        if other ~= door and (other.y > door.y or (other.y == door.y and other.x > door.x)) then
            return false
        end
    end

    return true
end

local function playClonedSound(baseSource, volume, pitch)
    local sound = baseSource:clone()
    sound:setVolume(volume)
    sound:setPitch(pitch)
    sound:play()
    return sound
end

local function playDoorSound(baseSource, door, volume)
    local playerDistance = Player and distance(Player, {x = door.xWorld, y = door.yWorld}) or 0
    local soundVolume = getDistanceVolume(playerDistance, volume or 0.45, 210)
    playClonedSound(baseSource, soundVolume, (0.95 + math.random() * 0.08) * GAME_PITCH)
end

local function playDoorSoundOnce(eventName, baseSource, door, volume, minInterval, global)
    local key = global and ("global:" .. eventName) or ((door.doorPairKey or "single") .. ":" .. eventName)
    local now = love.timer.getTime()

    if doorSoundLastPlayed[key] and now - doorSoundLastPlayed[key] < (minInterval or 0.18) then
        return
    end

    doorSoundLastPlayed[key] = now
    playDoorSound(baseSource, door, volume)
end

local function getDoorPairCenter(doors)
    local minX, maxX = doors[1].xWorld, doors[1].xWorld
    local minY, maxY = doors[1].yWorld, doors[1].yWorld

    for _, door in ipairs(doors) do
        minX = math.min(minX, door.xWorld)
        maxX = math.max(maxX, door.xWorld)
        minY = math.min(minY, door.yWorld)
        maxY = math.max(maxY, door.yWorld)
    end

    local anchor = doors[1]
    local x = (minX + maxX) / 2
    local y = (minY + maxY) / 2 - lockIconYOffset
    local offset = lockIconOffsets.top

    if anchor.frameSet == "bottom" then
        offset = lockIconOffsets.bottom
    elseif anchor.frameSet == "sideTop" or anchor.frameSet == "sideBottom" then
        if anchor.mirrored then
            offset = lockIconOffsets.sideRight
        else
            offset = lockIconOffsets.sideLeft
        end
    end

    x = x + (offset.x or 0)
    y = y + (offset.y or 0)

    return x, y
end

local function getDoorPairMaxPriority(doors)
    local priority = doors[1].yWorld + (doors[1].ySortOffset or 0)

    for _, door in ipairs(doors) do
        priority = math.max(priority, door.yWorld + (door.ySortOffset or 0))
    end

    return priority
end

function DoorTile:loadQuad()
    local sheetFrame = self:getSheetFrame()
    self.quad = love.graphics.newQuad(
        (sheetFrame - 1) * frameWidth,
        0,
        frameWidth,
        frameHeight,
        sheetWidth,
        sheetHeight
    )
end

function DoorTile:isPlayerClose()
    return distance(Player, {x = self.xWorld, y = self.yWorld - 8}) <= 25
end

function DoorTile:startOpening()
    if self.open or self.opening then
        return
    end

    self.opening = true
    self.animationMode = "opening"
    self.openPhase = "flash"
    self.flashTimer = self.flashDuration
    self.alpha = 1
    self.isAlive = true
    self.targetFrame = self.frameSequence and #self.frameSequence or self.openFrame

    local doors = getConnectedDoors(self.doorPairKey)
    if #doors == 0 or isDoorPairAnchor(self, doors) then
        playDoorSound(doorHandleSoundBase, self, 0.42)
    end
end

function DoorTile:startClosing(options)
    if self.opening and self.animationMode == "closing" then
        return
    end

    options = options or {}
    self.opening = true
    self.animationMode = "closing"
    self.openPhase = "animate"
    self.open = false
    self.collider = true
    self.alpha = 1
    self.isAlive = true
    self.targetFrame = self.frameSequence and 1 or self.closedFrame
    self.frameSpeed = options.frameSpeed or options.closeFrameSpeed or self.defaultFrameSpeed or self.frameSpeed
end

function DoorTile:openConnectedDoors()
    local Tilemap = require("scripts/tilemap")
    for _, tile in ipairs(Tilemap.tiles or {}) do
        if tile.doorPairKey == self.doorPairKey and tile.startOpening then
            tile:startOpening()
        end
    end
end

function DoorTile:isAnyConnectedDoorPlayerClose()
    local Tilemap = require("scripts/tilemap")
    for _, tile in ipairs(Tilemap.tiles or {}) do
        if tile.doorPairKey == self.doorPairKey and tile.isPlayerClose and tile:isPlayerClose() then
            return true
        end
    end

    return false
end

function DoorTile:isLocked()
    if not self.collider or self.open or self.opening then
        return false
    end

    local FloorManager = require("scripts/managers/floorManager")
    local currentRoom = FloorManager:getCurrentRoom()
    local state = currentRoom and currentRoom.state

    if not (state and state.visited) then
        return false
    end

    if not state.cleared then
        return true
    end

    if Game and Game.canOpenCurrentRoomDoors and not Game:canOpenCurrentRoomDoors(false) then
        return true
    end

    return false
end

function DoorTile:updateLockState(dt)
    local locked = self:isLocked()

    if self.lockWasLocked and not locked then
        self.lockUnlockTimer = lockUnlockDuration
    end

    self.lockWasLocked = locked
    if self.lockUnlockTimer and self.lockUnlockTimer > 0 then
        self.lockUnlockTimer = math.max(0, self.lockUnlockTimer - dt)
    end
end

function DoorTile:drawLockIcon()
    local locked = self:isLocked()
    local unlockTimer = self.lockUnlockTimer or 0

    if not locked and unlockTimer <= 0 then
        return
    end

    local doors = getConnectedDoors(self.doorPairKey)
    if #doors == 0 or not isDoorPairAnchor(self, doors) then
        return
    end

    local x, y = getDoorPairCenter(doors)
    local width = lockIconImage:getWidth()
    local height = lockIconImage:getHeight()
    local scale = lockIconSize / math.max(width, height)
    local alpha = 1

    if not locked then
        local progress = 1 - unlockTimer / lockUnlockDuration
        y = y - progress * lockUnlockRise
        alpha = unlockTimer / lockUnlockDuration
    end

    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.draw(
        lockIconImage,
        x,
        y,
        0,
        scale,
        scale * lockIconScaleY,
        width / 2,
        height / 2
    )
    love.graphics.setColor(1, 1, 1, 1)
end

function DoorTile:queueLockIcon()
    local locked = self:isLocked()
    local unlockTimer = self.lockUnlockTimer or 0

    if not locked and unlockTimer <= 0 then
        return
    end

    local doors = getConnectedDoors(self.doorPairKey)
    if #doors == 0 or not isDoorPairAnchor(self, doors) then
        return
    end

    addToDrawQueue(getDoorPairMaxPriority(doors) + lockDrawPriorityOffset, {
        x = self.xWorld,
        y = self.yWorld,
        draw = function()
            self:drawLockIcon()
        end,
    }, false)
end

function DoorTile:closeConnectedDoors()
    local Tilemap = require("scripts/tilemap")
    local map = Tilemap:getTilemap()
    local changed = false

    for _, tile in ipairs(Tilemap.tiles or {}) do
        if tile.doorPairKey == self.doorPairKey and tile.startClosing then
            tile:startClosing()
            if map and map[tile.y] then
                map[tile.y][tile.x] = 4
                if Tilemap.updatePathfinderTile then
                    Tilemap:updatePathfinderTile(tile.x, tile.y)
                end
                changed = true
            end
        end
    end

    if changed then
        if not Tilemap.updatePathfinderTile then
            Tilemap:loadfinders()
        end
    end
end

function DoorTile:performBuy()
    if not self.collider or not self:isPlayerClose() then
        return
    end

    local FloorManager = require("scripts/managers/floorManager")
    local currentRoom = FloorManager:getCurrentRoom()
    if not (currentRoom and currentRoom.state and currentRoom.state.cleared) then
        Game.drawtext = "Clear the room first"
        Game.textAlphaTarget = 1
        return
    end

    if Game and Game.canOpenCurrentRoomDoors and not Game:canOpenCurrentRoomDoors(true) then
        return
    end

    self:openConnectedDoors()
end

function DoorTile:update(dt)
    self:updateLockState(dt)
    self.isXrayOccluder = self.collider == true
    addToDrawQueue(self.yWorld + self.ySortOffset, self)
    local Tilemap = require("scripts/tilemap")
    if Tilemap.markTreesTransparentNearBox then
        Tilemap:markTreesTransparentNearBox({
            x = self.xWorld - self.size / 2,
            y = self.yWorld - self.size,
            width = self.size,
            height = self.size,
        }, 0)
    end
    self:queueLockIcon()

    if self.open and not self.opening then
        if Game and (Game.playerRoomExitTransition or Game.playerRoomEntryMove) then
            self.autoCloseTimer = 0
        elseif self:isAnyConnectedDoorPlayerClose() then
            self.autoCloseTimer = 0
        else
            self.autoCloseTimer = self.autoCloseTimer + dt
            if self.autoCloseTimer >= self.autoCloseDelay then
                self.autoCloseTimer = 0
                self:closeConnectedDoors()
            end
        end
    end

    if self.opening then
        if self.openPhase == "flash" then
            self.flashTimer = math.max(0, self.flashTimer - dt)
            if self.flashTimer == 0 then
                self.openPhase = "delay"
                self.openDelayTimer = self.openDelayDuration
            end
        elseif self.openPhase == "delay" then
            self.openDelayTimer = math.max(0, self.openDelayTimer - dt)
            if self.openDelayTimer == 0 then
                self.openPhase = "animate"
            end
        elseif self.openPhase == "animate" then
            if self.frame < self.targetFrame then
                self.frame = math.min(self.targetFrame, self.frame + self.frameSpeed * dt)
            else
                self.frame = math.max(self.targetFrame, self.frame - self.frameSpeed * dt)
            end
            self:loadQuad()

            if math.abs(self.frame - self.targetFrame) < 0.001 then
                self.frame = self.targetFrame
                self:loadQuad()

                if self.animationMode == "closing" then
                    local doors = getConnectedDoors(self.doorPairKey)
                    if #doors == 0 or isDoorPairAnchor(self, doors) then
                        playDoorSoundOnce("close", doorCloseSoundBase, self, 0.5, 0.35, true)
                    end

                    self.opening = false
                    self.openPhase = nil
                    self.animationMode = nil
                    self.open = false
                    self.collider = true
                    self.alpha = 1
                    self.frameSpeed = self.defaultFrameSpeed or self.frameSpeed
                else
                    local doors = getConnectedDoors(self.doorPairKey)
                    if #doors == 0 or isDoorPairAnchor(self, doors) then
                        playDoorSound(doorOpenSoundBase, self, 0.46)
                    end

                    self.open = true
                    self.collider = false
                    self.opening = false
                    self.openPhase = nil
                    self.animationMode = nil
                    self.alpha = 1
                    self.isAlive = true

                    local Tilemap = require("scripts/tilemap")
                    local map = Tilemap:getTilemap()
                    if map and map[self.y] then
                        map[self.y][self.x] = 0
                        if Tilemap.updatePathfinderTile then
                            Tilemap:updatePathfinderTile(self.x, self.y)
                        else
                            Tilemap:loadfinders()
                        end
                    end
                end
            end
        elseif self.openPhase == "fade" then
            self.fadeTimer = math.max(0, self.fadeTimer - dt)
            self.alpha = self.fadeTimer / self.fadeDuration

            if self.fadeTimer == 0 then
                self.opening = false
                self.animationMode = nil
                self.isAlive = true
                self.alpha = 1
            end
        end
    end

    if self.collider and Player.isAlive and self:isPlayerClose() then
        local FloorManager = require("scripts/managers/floorManager")
        local currentRoom = FloorManager:getCurrentRoom()
        if currentRoom and currentRoom.state and currentRoom.state.cleared then
            if Game and Game.canOpenCurrentRoomDoors and not Game:canOpenCurrentRoomDoors(true) then
                return
            end

            self:openConnectedDoors()
            return
        else
            Game.drawtext = "Clear the room first"
        end
        Game.textAlphaTarget = 1
    end
end

function DoorTile:draw()
    local scaleX = self.mirrored and -1 or 1
    local scaleY = 1
    local useFlash = self.openPhase == "flash" and self.flashTimer > 0

    if useFlash then
        scaleY = 1.05
        love.graphics.setShader(whiteShader)
    end

    love.graphics.setColor(1, 1, 1, self.alpha)
    love.graphics.draw(
        sheetImage,
        self.quad,
        self.xWorld,
        self.yWorld,
        0,
        scaleX,
        scaleY,
        frameWidth / 2,
        frameHeight
    )

    love.graphics.setShader()
    love.graphics.setColor(1, 1, 1, 1)
    self:drawDebug()
end

function DoorTile:drawXrayOccluder()
    if not self.collider then
        return
    end

    local scaleX = self.mirrored and -1 or 1
    love.graphics.draw(
        sheetImage,
        self.quad,
        self.xWorld,
        self.yWorld,
        0,
        scaleX,
        1,
        frameWidth / 2,
        frameHeight
    )
end

function DoorTile:openDoor()
    self.collider = false
    self.open = true
    self.opening = false
    self.openPhase = nil
    self.animationMode = nil
    self.autoCloseTimer = 0
    self.alpha = 1
    self.isAlive = true
    self.frameSpeed = self.defaultFrameSpeed or self.frameSpeed
    self.frame = self.frameSequence and #self.frameSequence or self.openFrame
    self:loadQuad()
end

function DoorTile:closeDoor()
    self.collider = true
    self.open = false
    self.opening = false
    self.openPhase = nil
    self.animationMode = nil
    self.autoCloseTimer = 0
    self.alpha = 1
    self.isAlive = true
    self.frameSpeed = self.defaultFrameSpeed or self.frameSpeed
    self.frame = self.frameSequence and 1 or self.closedFrame
    self.targetFrame = self.frame
    self:loadQuad()
end

function DoorTile:drawShadow()
end
