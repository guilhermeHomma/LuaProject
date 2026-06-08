local RoomFlowManager = {}

local Tilemap = require("scripts/tilemap")
local FloorManager = require("scripts/managers/floorManager")
local RoomScreenTransition = require("scripts/managers/roomScreenTransition")

local TILE_WORLD_SIZE = 16
local ENTRY_MOVE_DISTANCE = TILE_WORLD_SIZE * 2.25
local ENTRY_START_BACK_DISTANCE = TILE_WORLD_SIZE * 0.55
local ENTRY_ANIMATION_LEAD_TIME = 0.08
local ENTRY_DOOR_CLOSE_WAIT = 0.1
local ENTRY_DOOR_CLOSE_SPEED = 42
local EXIT_RUN_DISTANCE = TILE_WORLD_SIZE * 2.75
local EXIT_PRE_SLIDE_DISTANCE = TILE_WORLD_SIZE * 1.15
local ROOM_FADE_OUT_DURATION = 0.38
local ROOM_FADE_IN_DURATION = 0.24

local oppositeDirections = {
    north = "south",
    south = "north",
    west = "east",
    east = "west",
}
local entryMoveVectors = {
    north = {x = 0, y = 1},
    south = {x = 0, y = -1},
    west = {x = 1, y = 0},
    east = {x = -1, y = 0},
}
local gridDirectionVectors = {
    north = {x = 0, y = -1},
    south = {x = 0, y = 1},
    west = {x = -1, y = 0},
    east = {x = 1, y = 0},
}
local function resolveDoorSlot(room, direction)
    local slot = room and room.doorSlots and room.doorSlots[direction]
    local slotId = room and room.doorSlotIds and room.doorSlotIds[direction]

    if slot and slotId and slot[slotId] then
        return slot[slotId]
    end

    return slot
end

local function mapTemplatePointToWorld(point)
    local worldX, worldY = Tilemap:mapToWorld(point.x + 1, point.y + 1)
    return worldX, worldY - 8
end

local function getStartRoomPlayerSpawn()
    local currentRoom = FloorManager:getCurrentRoom()
    local spawnPoint = currentRoom and currentRoom.spawnPoints and currentRoom.spawnPoints.player

    if spawnPoint then
        return mapTemplatePointToWorld(spawnPoint)
    end

    if CURRENT_LEVEL and CURRENT_LEVEL.getPlayerSpawn then
        return CURRENT_LEVEL:getPlayerSpawn()
    end

    return 30, 340
end

local function getEntrySpawn(direction)
    local currentRoom = FloorManager:getCurrentRoom()
    local slot = resolveDoorSlot(currentRoom, direction)
    local spawnPoint = slot and slot.playerSpawn
        or currentRoom and currentRoom.spawnPoints and currentRoom.spawnPoints.player

    if spawnPoint then
        return mapTemplatePointToWorld(spawnPoint)
    end

    return getStartRoomPlayerSpawn()
end

local function getEntryDoorAvoidPoint(direction)
    local currentRoom = FloorManager:getCurrentRoom()
    local slot = resolveDoorSlot(currentRoom, direction)
    local doorTiles = slot and slot.doorTiles

    if not (doorTiles and #doorTiles > 0) then
        return nil
    end

    local x, y = 0, 0
    for _, point in ipairs(doorTiles) do
        local worldX, worldY = mapTemplatePointToWorld(point)
        x = x + worldX
        y = y + worldY
    end

    return {
        x = x / #doorTiles,
        y = y / #doorTiles,
    }
end

local function getEntryMoveTarget(entryDirection, fallbackX, fallbackY)
    local currentRoom = FloorManager:getCurrentRoom()
    local slot = resolveDoorSlot(currentRoom, entryDirection)
    local doorTiles = slot and slot.doorTiles
    local vector = entryMoveVectors[entryDirection] or {x = 0, y = 0}

    if not (doorTiles and #doorTiles > 0) then
        return fallbackX + vector.x * ENTRY_MOVE_DISTANCE, fallbackY + vector.y * ENTRY_MOVE_DISTANCE
    end

    local x, y = 0, 0
    for _, point in ipairs(doorTiles) do
        local worldX, worldY = mapTemplatePointToWorld(point)
        x = x + worldX
        y = y + worldY
    end

    local doorX = x / #doorTiles
    local doorY = y / #doorTiles
    return doorX + vector.x * ENTRY_MOVE_DISTANCE, doorY + vector.y * ENTRY_MOVE_DISTANCE
end

local function getWorldDirectionVector(direction)
    return gridDirectionVectors[direction] or {x = 0, y = 0}
end

local function primePlayerWalkAnimation(vector)
    if not (Player and Player.animations and Player.animations.walk) then
        return
    end

    Player.currentAnimation = "walk"
    Player.currentFrame = 2
    Player.animationTimer = ENTRY_ANIMATION_LEAD_TIME
    Player.idleHandFrame = Player.currentFrame
    Player.idleHandTimer = 0
    Player.footStepTimer = 0
    Player.moveX = vector.x
    Player.moveY = vector.y
    if vector.x ~= 0 then
        Player.flipH = vector.x > 0
    end
end

local function queuePlayerTransitionFrame(vector, moving)
    if not (Player and Player.isAlive) then
        return
    end

    vector = vector or { x = 0, y = 0 }
    local moveX = vector.x or 0
    local moveY = vector.y or 0
    if moving == nil then
        moving = moveX ~= 0 or moveY ~= 0
    end

    Player.velocityX = 0
    Player.velocityY = 0
    Player.moveX = moveX
    Player.moveY = moveY
    if Player.moveX ~= 0 then
        Player.flipH = Player.moveX > 0
    end
    Player:updateAnimation(0, moving)
    if Player.gun then
        Player.gun:update(0, Player.x, Player.y)
    end
    addToDrawQueue(Player.y + 6, Player, false)
end

local function getRoomCells(room)
    local cells = {}
    for _, offset in ipairs(room.occupiedOffsets or {{x = 0, y = 0}}) do
        cells[#cells + 1] = {
            x = room.gridX + offset.x,
            y = room.gridY + offset.y,
        }
    end
    return cells
end

local function getOppositeDirection(direction)
    return oppositeDirections[direction]
end

local function getRoomEdgeCell(room, direction)
    local cells = getRoomCells(room)
    local selected = cells[1]
    local slotId = room and room.doorSlotIds and room.doorSlotIds[direction]

    if not selected then
        return nil
    end

    for _, cell in ipairs(cells) do
        if direction == "north" then
            local betterEdge = cell.y < selected.y
            local betterSlot = cell.y == selected.y
                and ((slotId == "right" and cell.x > selected.x) or (slotId ~= "right" and cell.x < selected.x))
            if betterEdge or betterSlot then
                selected = cell
            end
        elseif direction == "south" then
            local betterEdge = cell.y > selected.y
            local betterSlot = cell.y == selected.y
                and ((slotId == "right" and cell.x > selected.x) or (slotId ~= "right" and cell.x < selected.x))
            if betterEdge or betterSlot then
                selected = cell
            end
        elseif direction == "west" then
            local betterEdge = cell.x < selected.x
            local betterSlot = cell.x == selected.x
                and ((slotId == "bottom" and cell.y > selected.y) or (slotId ~= "bottom" and cell.y < selected.y))
            if betterEdge or betterSlot then
                selected = cell
            end
        elseif direction == "east" then
            local betterEdge = cell.x > selected.x
            local betterSlot = cell.x == selected.x
                and ((slotId == "bottom" and cell.y > selected.y) or (slotId ~= "bottom" and cell.y < selected.y))
            if betterEdge or betterSlot then
                selected = cell
            end
        end
    end

    return selected
end

local function isStartRoom(room)
    local level = FloorManager.level
    local startRoomId = level and level.floorConfig and level.floorConfig.startRoomId or "0:0"
    return room and room.id == startRoomId
end

local function revealRoomConnections(room)
    if not room then
        return
    end

    room.state = room.state or {}
    room.state.discovered = true

    local rooms = FloorManager:getRooms()
    for direction, neighborId in pairs(room.neighbors or {}) do
        local neighbor = rooms[neighborId]
        if neighbor and neighbor.state then
            neighbor.state.discovered = true
            if not neighbor.state.visited then
                local neighborCell = getRoomEdgeCell(neighbor, getOppositeDirection(direction))
                if neighborCell then
                    neighbor.state.minimapPreviewCell = {
                        x = neighborCell.x,
                        y = neighborCell.y,
                    }
                end
            end
        end
    end
end

function RoomFlowManager:startEntryMove(entryDirection)
    if Player and Player.cancelDash then
        Player:cancelDash()
    end

    local vector = entryMoveVectors[entryDirection] or {x = 0, y = 0}
    local targetX, targetY = getEntryMoveTarget(entryDirection, Player.x, Player.y)
    local dx = targetX - Player.x
    local dy = targetY - Player.y
    local moveDistance = math.sqrt(dx * dx + dy * dy)
    local moveSpeed = math.max(Player.speed or Player.baseSpeed or 1, 1)
    self.playerRoomEntryMove = {
        phase = "move",
        timer = 0,
        duration = math.max(moveDistance / moveSpeed, 0.001),
        closeWaitTimer = 0,
        vectorX = vector.x,
        vectorY = vector.y,
        startX = Player.x,
        startY = Player.y,
        targetX = targetX,
        targetY = targetY,
    }
    Player.moveX = vector.x
    Player.moveY = vector.y
    primePlayerWalkAnimation(vector)
    Dialog.breakMovements = true
end

function RoomFlowManager:updateEntryMove(dt)
    local move = self.playerRoomEntryMove
    if not move then
        return false
    end

    if move.phase == "closing" then
        move.closeWaitTimer = math.max(0, (move.closeWaitTimer or ENTRY_DOOR_CLOSE_WAIT) - dt)
        Player.velocityX = 0
        Player.velocityY = 0
        Player.moveX = move.vectorX
        Player.moveY = move.vectorY
        if move.vectorX ~= 0 then
            Player.flipH = move.vectorX > 0
        end
        Player:updateAnimation(dt, true)
        Player.gun:update(dt, Player.x, Player.y)
        addToDrawQueue(Player.y + 6, Player)

        if move.closeWaitTimer == 0 then
            Player.moveX = move.vectorX
            Player.moveY = move.vectorY
            if move.vectorX ~= 0 then
                Player.flipH = move.vectorX > 0
            end
            Player.sideChangeTimer = 0
            self.playerRoomEntryMove = nil
            if not self.playerRoomExitTransition then
                Dialog.breakMovements = false
            end
        end

        return true
    end

    move.timer = math.min(move.duration, move.timer + dt)
    local t = move.timer / move.duration

    Player.x = move.startX + (move.targetX - move.startX) * t
    Player.y = move.startY + (move.targetY - move.startY) * t
    Player.velocityX = 0
    Player.velocityY = 0
    Player.moveX = move.vectorX
    Player.moveY = move.vectorY
    if move.vectorX ~= 0 then
        Player.flipH = move.vectorX > 0
    end
    Player:updateAnimation(dt, true)
    Player.gun:update(dt, Player.x, Player.y)
    addToDrawQueue(Player.y + 6, Player)

    if move.timer >= move.duration then
        move.phase = "closing"
        move.closeWaitTimer = ENTRY_DOOR_CLOSE_WAIT
        Tilemap:setAllRoomDoorsOpen(false, true, {
            frameSpeed = ENTRY_DOOR_CLOSE_SPEED,
            playCloseSoundOnStart = true,
        })
    end

    return true
end

function RoomFlowManager:loadRoomFromDirection(direction)
    if Player and Player.cancelDash then
        Player:cancelDash()
    end

    local currentRoom = FloorManager:getCurrentRoom()
    local targetRoomId = currentRoom and currentRoom.neighbors and currentRoom.neighbors[direction]

    if not targetRoomId then
        return false
    end

    local entryDirection = oppositeDirections[direction]
    if not FloorManager:enterRoom(targetRoomId, { deferReveal = true }) then
        return false
    end

    self.objects = {}
    for index = #(self.particles or {}), 1, -1 do
        local particleType = self.particles[index].particleType
        if particleType == "boxParticle"
            or particleType == "bloodDecal"
            or particleType == "leafParticle"
            or particleType == "spiderWeb" then
            table.remove(self.particles, index)
        end
    end

    Tilemap:load()
    Tilemap:setDoorOpen(entryDirection, true)
    local spawnX, spawnY = getEntrySpawn(entryDirection)
    local entryVector = entryMoveVectors[entryDirection] or { x = 0, y = 0 }
    Player.x = spawnX - entryVector.x * ENTRY_START_BACK_DISTANCE
    Player.y = spawnY - entryVector.y * ENTRY_START_BACK_DISTANCE
    self.currentEntryDoorAvoidPoint = getEntryDoorAvoidPoint(entryDirection) or { x = spawnX, y = spawnY }
    local state = FloorManager:getCurrentRoomState()
    if state then
        state.entryDoorAvoidPoint = self.currentEntryDoorAvoidPoint
    end
    Player.velocityX = 0
    Player.velocityY = 0

    if camera then
        camera.x = Player.x - 5
        camera.y = Player.y - 30
        camera:snapToCurrentMode()
    end

    self.roomTransitionCooldown = 0.28
    self.pendingRoomRevealId = targetRoomId
    self:startEntryMove(entryDirection)
    queuePlayerTransitionFrame(entryVector)
    self:setupCurrentRoom({
        keepEntryDoorOpen = true,
        deferMinimapReveal = true,
    })
    self:restoreCurrentRoomDrops()
    return true
end

function RoomFlowManager:startRoomExitTransition(direction)
    if self.playerRoomExitTransition or self.playerRoomEntryMove then
        return false
    end

    local currentRoom = FloorManager:getCurrentRoom()
    if not (currentRoom and currentRoom.state and currentRoom.state.cleared) then
        return false
    end

    if not self:canLeaveCurrentRoom() then
        return false
    end

    if not (currentRoom.neighbors and currentRoom.neighbors[direction]) then
        return false
    end

    if Player and Player.cancelDash then
        Player:cancelDash()
    end

    local vector = getWorldDirectionVector(direction)
    local exitMoveDistance = math.min(EXIT_PRE_SLIDE_DISTANCE, EXIT_RUN_DISTANCE)
    self.playerRoomExitTransition = {
        phase = "exitMove",
        direction = direction,
        timer = 0,
        duration = math.max(exitMoveDistance / math.max(Player.speed or Player.baseSpeed or 1, 1), 0.001),
        vectorX = vector.x,
        vectorY = vector.y,
        startX = Player.x,
        startY = Player.y,
        targetX = Player.x + vector.x * exitMoveDistance,
        targetY = Player.y + vector.y * exitMoveDistance,
    }
    self.minimapRoomOverrideId = currentRoom.id
    self.minimapForcePlayerIconRefresh = false
    Player.moveX = vector.x
    Player.moveY = vector.y
    primePlayerWalkAnimation(vector)
    Dialog.breakMovements = true
    return true
end

function RoomFlowManager:updateRoomExitTransition(dt)
    local transition = self.playerRoomExitTransition
    if not transition then
        return false
    end

    if transition.phase == "exitMove" then
        transition.timer = math.min(transition.duration, transition.timer + dt)
        self.roomFadeAlpha = 0
        local t = transition.timer / transition.duration
        Player.x = transition.startX + (transition.targetX - transition.startX) * t
        Player.y = transition.startY + (transition.targetY - transition.startY) * t
        Player.velocityX = 0
        Player.velocityY = 0
        Player.moveX = transition.vectorX
        Player.moveY = transition.vectorY
        if transition.vectorX ~= 0 then
            Player.flipH = transition.vectorX > 0
        end
        Player:updateAnimation(dt, true)
        Player.gun:update(dt, Player.x, Player.y)
        addToDrawQueue(Player.y + 6, Player)

        if transition.timer >= transition.duration then
            transition.phase = "captureOldRoom"
            transition.timer = 0
            transition.duration = RoomScreenTransition:getDuration()
            RoomScreenTransition:beginCapture({
                x = transition.vectorX,
                y = transition.vectorY,
            })
        end
    elseif transition.phase == "fadeOut" then
        transition.timer = math.min(transition.duration, transition.timer + dt)
        self.roomFadeAlpha = 0
        local t = transition.timer / transition.duration
        Player.x = transition.startX + (transition.targetX - transition.startX) * t
        Player.y = transition.startY + (transition.targetY - transition.startY) * t
        Player.velocityX = 0
        Player.velocityY = 0
        Player.moveX = transition.vectorX
        Player.moveY = transition.vectorY
        Player:updateAnimation(dt, true)
        Player.gun:update(dt, Player.x, Player.y)
        addToDrawQueue(Player.y + 6, Player)

        if transition.timer >= transition.duration then
            local direction = transition.direction
            self.playerRoomExitTransition = nil
            self.roomFadeAlpha = 0
            RoomScreenTransition:startSlide({
                x = transition.vectorX,
                y = transition.vectorY,
            })
            self:loadRoomFromDirection(direction)
            self.playerRoomExitTransition = {
                phase = "screenSlide",
                timer = 0,
                duration = RoomScreenTransition:getDuration(),
            }
        end
    elseif transition.phase == "captureOldRoom" then
        self.roomFadeAlpha = 0
        Player.velocityX = 0
        Player.velocityY = 0
        Player.moveX = transition.vectorX
        Player.moveY = transition.vectorY
        Player:updateAnimation(dt, true)
        Player.gun:update(dt, Player.x, Player.y)
        addToDrawQueue(Player.y + 6, Player)

        if RoomScreenTransition:hasCaptured() then
            local direction = transition.direction
            self.playerRoomExitTransition = nil
            RoomScreenTransition:startSlide({
                x = transition.vectorX,
                y = transition.vectorY,
            })
            self:loadRoomFromDirection(direction)
            self.playerRoomExitTransition = {
                phase = "screenSlide",
                timer = 0,
                duration = RoomScreenTransition:getDuration(),
            }
        end
    elseif transition.phase == "screenSlide" then
        transition.timer = math.min(transition.duration, transition.timer + dt)
        self.roomFadeAlpha = 0
        if self.playerRoomEntryMove then
            self:updateEntryMove(dt)
        end

        if not transition.minimapRevealed
            and transition.timer >= transition.duration * 0.5 then
            transition.minimapRevealed = true
            self:commitPendingMinimapRoomReveal()
        end

        if transition.timer >= transition.duration then
            self.roomFadeAlpha = 0
            self.playerRoomExitTransition = nil
            if self.pendingRoomRevealId or self.minimapRoomOverrideId then
                self:commitPendingMinimapRoomReveal()
            end
            Dialog.breakMovements = self.playerRoomEntryMove ~= nil
            if self.playerRoomEntryMove then
                primePlayerWalkAnimation({
                    x = self.playerRoomEntryMove.vectorX,
                    y = self.playerRoomEntryMove.vectorY,
                })
            end
        end
    end

    return true
end

function RoomFlowManager:commitPendingMinimapRoomReveal()
    if self.pendingRoomRevealId then
        FloorManager:revealRoom(self.pendingRoomRevealId)
        revealRoomConnections(FloorManager:getRoom(self.pendingRoomRevealId))
        self.pendingRoomRevealId = nil
    end

    self.minimapRoomOverrideId = nil
    self.minimapForcePlayerIconRefresh = true
    self.minimapPlayerIconX = nil
    self.minimapPlayerIconY = nil
end

function RoomFlowManager:enterRoomFrom(direction)
    return self:startRoomExitTransition(direction)
end
function RoomFlowManager:checkRoomTransition(dt)
    if self.playerRoomExitTransition or self.playerRoomEntryMove then
        return
    end

    self.roomTransitionCooldown = math.max(0, (self.roomTransitionCooldown or 0) - dt)
    if self.roomTransitionCooldown > 0 then
        return
    end

    local transition = Tilemap:getRoomTransitionAt(Player.x, Player.y)
    if transition then
        self:enterRoomFrom(transition.direction)
    end
end

function RoomFlowManager.getStartRoomPlayerSpawn()
    return getStartRoomPlayerSpawn()
end

function RoomFlowManager.queuePlayerTransitionFrame(vector, moving)
    queuePlayerTransitionFrame(vector, moving)
end

function RoomFlowManager.attach(game)
    game.startEntryMove = RoomFlowManager.startEntryMove
    game.updateEntryMove = RoomFlowManager.updateEntryMove
    game.loadRoomFromDirection = RoomFlowManager.loadRoomFromDirection
    game.startRoomExitTransition = RoomFlowManager.startRoomExitTransition
    game.updateRoomExitTransition = RoomFlowManager.updateRoomExitTransition
    game.commitPendingMinimapRoomReveal = RoomFlowManager.commitPendingMinimapRoomReveal
    game.enterRoomFrom = RoomFlowManager.enterRoomFrom
    game.checkRoomTransition = RoomFlowManager.checkRoomTransition
end

return RoomFlowManager
