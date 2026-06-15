local FloorManager = {}

local RoomTemplates = require("scripts/rooms/roomTemplates")
local RoomSelector = require("scripts/rooms/roomSelector")
local WeaponDefinitions = require("scripts/player/weapons/init")
local VisualThemes = require("scripts/config/visualThemes")

local DEFAULT_START_ROOM_ID = "0:0"
local directions = {
    north = {dx = 0, dy = -1, opposite = "south"},
    south = {dx = 0, dy = 1, opposite = "north"},
    west = {dx = -1, dy = 0, opposite = "east"},
    east = {dx = 1, dy = 0, opposite = "west"},
}
local directionOrder = {"north", "south", "west", "east"}

local function copyTable(source)
    return RoomSelector.copyTable(source)
end

local function resolveOccupiedOffsets(roomConfig, template)
    local variants = roomConfig.occupancyVariants or (template and template.occupancyVariants)
    local variantId = roomConfig.occupancyVariant

    if variants and variantId and variants[variantId] then
        return variants[variantId]
    end

    if roomConfig.occupiedOffsets then
        return roomConfig.occupiedOffsets
    end

    if template and template.occupiedOffsets then
        return template.occupiedOffsets
    end

    return {
        {x = 0, y = 0},
    }
end

local function createRoom(roomConfig, level)
    roomConfig = roomConfig or {}
    level = level or {}

    local id = roomConfig.id or DEFAULT_START_ROOM_ID
    local templateId = roomConfig.templateId
    local template = templateId and RoomTemplates:get(templateId) or nil
    assert(not templateId or template, "Unknown room template: " .. tostring(templateId))

    return {
        id = id,
        gridX = roomConfig.gridX or 0,
        gridY = roomConfig.gridY or 0,
        templateId = templateId,
        width = roomConfig.width or (template and template.width),
        height = roomConfig.height or (template and template.height),
        gridWidth = roomConfig.gridWidth or (template and template.gridWidth) or 1,
        gridHeight = roomConfig.gridHeight or (template and template.gridHeight) or 1,
        distanceFromStart = roomConfig.distanceFromStart or 0,
        themeId = roomConfig.themeId,
        occupancyVariants = copyTable(roomConfig.occupancyVariants or (template and template.occupancyVariants)),
        occupancyVariant = roomConfig.occupancyVariant,
        occupiedOffsets = copyTable(resolveOccupiedOffsets(roomConfig, template)),
        shape = roomConfig.shape or (template and template.shape) or "rect",
        doors = copyTable(roomConfig.doors) or {},
        doorSlotIds = copyTable(roomConfig.doorSlotIds) or {},
        neighbors = copyTable(roomConfig.neighbors) or {},
        doorSlots = copyTable(roomConfig.doorSlots or (template and template.doorSlots)) or {},
        spawnPoints = copyTable(roomConfig.spawnPoints or (template and template.spawnPoints)) or {},
        tilemapConfig = copyTable(roomConfig.tilemapConfig or RoomSelector.chooseTemplateTilemapConfig(template) or level.tilemapConfig),
        isShopRoom = roomConfig.isShopRoom == true or templateId == "store_32x32",
        isCardRoom = roomConfig.isCardRoom == true or templateId == "cards_32x32",
        isEndRoom = roomConfig.isEndRoom == true or templateId == "end_32x32",
        state = roomConfig.state or {
            visited = false,
            discovered = false,
            minimapPreviewCell = nil,
            cleared = false,
            openedDoors = {},
            brokenObjects = {},
            killedEnemies = {},
            encounterSpawned = false,
            encounterCompleted = false,
            encounterWaveIndex = 0,
            shopResolved = false,
            shopProduct = nil,
            drops = {},
        },
    }
end

local function getRoomId(x, y)
    return x .. ":" .. y
end

local function getOccupiedCells(room)
    local cells = {}
    for _, offset in ipairs(room.occupiedOffsets or {{x = 0, y = 0}}) do
        cells[#cells + 1] = {
            x = room.gridX + offset.x,
            y = room.gridY + offset.y,
        }
    end
    return cells
end

local function getRandomOccupiedCell(room)
    local cells = getOccupiedCells(room)
    return cells[math.random(1, #cells)]
end

local function getDoorSlotIdForCell(room, cell, direction)
    local offsetX = cell.x - room.gridX
    local offsetY = cell.y - room.gridY

    if direction == "west" or direction == "east" then
        if (room.gridHeight or 1) <= 1 then
            return nil
        end

        local minOffsetY = offsetY
        local maxOffsetY = offsetY
        for _, offset in ipairs(room.occupiedOffsets or {{x = 0, y = 0}}) do
            minOffsetY = math.min(minOffsetY, offset.y)
            maxOffsetY = math.max(maxOffsetY, offset.y)
        end

        if offsetY <= minOffsetY then
            return "top"
        end

        if offsetY >= maxOffsetY then
            return "bottom"
        end

        return "bottom"
    end

    if (room.gridWidth or 1) <= 1 then
        return nil
    end

    local minOffsetX = offsetX
    local maxOffsetX = offsetX
    for _, offset in ipairs(room.occupiedOffsets or {{x = 0, y = 0}}) do
        minOffsetX = math.min(minOffsetX, offset.x)
        maxOffsetX = math.max(maxOffsetX, offset.x)
    end

    if offsetX <= minOffsetX then
        return "left"
    end

    if offsetX >= maxOffsetX then
        return "right"
    end

    return "right"
end

local isRoomStillCompatible

local function connectRooms(roomA, roomB, direction, roomACell, roomBCell)
    local directionConfig = directions[direction]
    local opposite = directionConfig.opposite

    roomA.neighbors[direction] = roomB.id
    roomA.doors[direction] = true
    roomA.doorSlotIds[direction] = getDoorSlotIdForCell(roomA, roomACell or {x = roomA.gridX, y = roomA.gridY}, direction)
    roomB.neighbors[opposite] = roomA.id
    roomB.doors[opposite] = true
    roomB.doorSlotIds[opposite] = getDoorSlotIdForCell(roomB, roomBCell or {x = roomB.gridX, y = roomB.gridY}, opposite)
end

local function tryConnectRooms(roomA, roomB, direction, roomACell, roomBCell)
    local directionConfig = directions[direction]
    local opposite = directionConfig.opposite

    if roomA.neighbors[direction] and roomA.neighbors[direction] ~= roomB.id then
        return false
    end

    if roomB.neighbors[opposite] and roomB.neighbors[opposite] ~= roomA.id then
        return false
    end

    local previousNeighborA = roomA.neighbors[direction]
    local previousDoorA = roomA.doors[direction]
    local previousSlotA = roomA.doorSlotIds[direction]
    local previousNeighborB = roomB.neighbors[opposite]
    local previousDoorB = roomB.doors[opposite]
    local previousSlotB = roomB.doorSlotIds[opposite]

    connectRooms(roomA, roomB, direction, roomACell, roomBCell)

    if isRoomStillCompatible(roomA) and isRoomStillCompatible(roomB) then
        return true
    end

    roomA.neighbors[direction] = previousNeighborA
    roomA.doors[direction] = previousDoorA
    roomA.doorSlotIds[direction] = previousSlotA
    roomB.neighbors[opposite] = previousNeighborB
    roomB.doors[opposite] = previousDoorB
    roomB.doorSlotIds[opposite] = previousSlotB
    return false
end

local function reserveRoomCells(room, occupiedCells)
    for _, cell in ipairs(getOccupiedCells(room)) do
        occupiedCells[getRoomId(cell.x, cell.y)] = room
    end
end

local function getRoomConnectionCount(room)
    local count = 0
    for _, neighborId in pairs(room.neighbors or {}) do
        if neighborId then
            count = count + 1
        end
    end
    return count
end

local function canExpandRoom(room)
    return room and room.pathEnd ~= true
end

local function canAddConnectionToRoom(room)
    return not (room and room.pathEnd == true and getRoomConnectionCount(room) <= 1)
end

local function getExpandableRooms(generatedRooms)
    local rooms = {}

    for _, room in ipairs(generatedRooms or {}) do
        if canExpandRoom(room) then
            rooms[#rooms + 1] = room
        end
    end

    return rooms
end

local function shouldCreatePathEndRoom(generateConfig, generatedRooms, roomCount)
    if not (generateConfig and generateConfig.endTemplateWeights) then
        return false
    end

    local remainingAfterThisRoom = roomCount - (#generatedRooms + 1)
    if remainingAfterThisRoom <= 0 then
        return true
    end

    local chance = generateConfig.endRoomChance or 0
    return chance > 0 and math.random() < chance
end

local function getStartGenerateConfig(generateConfig)
    local startConfig = copyTable(generateConfig) or {}

    if generateConfig.startTemplateIds then
        startConfig.templateIds = generateConfig.startTemplateIds
        startConfig.templateId = nil
    elseif generateConfig.startTemplateId then
        startConfig.templateIds = {generateConfig.startTemplateId}
        startConfig.templateId = nil
    end

    return startConfig
end

local function createGeneratedRoom(x, y, placement)
    return {
        id = getRoomId(x, y),
        gridX = x,
        gridY = y,
        templateId = placement.template.id,
        width = placement.template.width,
        height = placement.template.height,
        gridWidth = placement.template.gridWidth or 1,
        gridHeight = placement.template.gridHeight or 1,
        shape = placement.template.shape,
        tilemapConfig = placement.tilemapConfig,
        occupancyVariant = placement.variantId,
        occupiedOffsets = copyTable(placement.offsets),
        doors = {},
        doorSlotIds = {},
        neighbors = {},
    }
end

local appendGeneratedRoom

local function getRoomDistanceFromStart(room)
    return room and room.distanceFromStart or 0
end

local function shuffledDirectionsList()
    local shuffledDirections = copyTable(directionOrder)
    for i = #shuffledDirections, 2, -1 do
        local j = math.random(1, i)
        shuffledDirections[i], shuffledDirections[j] = shuffledDirections[j], shuffledDirections[i]
    end
    return shuffledDirections
end

local function getDirectionsAwayFromStart(room)
    local ordered = copyTable(directionOrder)
    local tieBreakers = {}
    for index, direction in ipairs(shuffledDirectionsList()) do
        tieBreakers[direction] = index
    end

    table.sort(ordered, function(a, b)
        local dirA = directions[a]
        local dirB = directions[b]
        local scoreA = math.abs((room.gridX or 0) + dirA.dx) + math.abs((room.gridY or 0) + dirA.dy)
        local scoreB = math.abs((room.gridX or 0) + dirB.dx) + math.abs((room.gridY or 0) + dirB.dy)
        if scoreA == scoreB then
            return (tieBreakers[a] or 0) < (tieBreakers[b] or 0)
        end
        return scoreA > scoreB
    end)
    return ordered
end

local function createEndRoomFromAnchor(anchorRoom, generateConfig, generatedRooms, roomIds, occupiedCells)
    local endTemplateId = generateConfig and generateConfig.endRoomTemplateId
    if not (endTemplateId and anchorRoom) then
        return nil
    end

    local anchorCells = getOccupiedCells(anchorRoom)
    for i = #anchorCells, 2, -1 do
        local j = math.random(1, i)
        anchorCells[i], anchorCells[j] = anchorCells[j], anchorCells[i]
    end

    for _, anchorCell in ipairs(anchorCells) do
        for _, direction in ipairs(getDirectionsAwayFromStart(anchorRoom)) do
            local directionConfig = directions[direction]
            local x = anchorCell.x + directionConfig.dx
            local y = anchorCell.y + directionConfig.dy
            if not anchorRoom.neighbors[direction] and not occupiedCells[getRoomId(x, y)] then
                local placement = RoomSelector.chooseTemplatePlacement(
                    {[directionConfig.opposite] = true},
                    {templateIds = {endTemplateId}},
                    x,
                    y,
                    occupiedCells
                )

                if placement then
                    local room = createGeneratedRoom(x, y, placement)
                    room.isEndRoom = true
                    room.pathEnd = true
                    room.distanceFromStart = getRoomDistanceFromStart(anchorRoom) + 1
                    room.doors[directionConfig.opposite] = true
                    room.doorSlotIds[directionConfig.opposite] = getDoorSlotIdForCell(room, {x = x, y = y}, directionConfig.opposite)
                    room.neighbors[directionConfig.opposite] = anchorRoom.id

                    anchorRoom.doors[direction] = true
                    anchorRoom.doorSlotIds[direction] = getDoorSlotIdForCell(anchorRoom, anchorCell, direction)
                    anchorRoom.neighbors[direction] = room.id

                    appendGeneratedRoom(generatedRooms, roomIds, occupiedCells, room)
                    return room
                end
            end
        end
    end

    return nil
end

local function createEndRoom(generateConfig, generatedRooms, roomIds, occupiedCells)
    if not (generateConfig and generateConfig.endRoomTemplateId) then
        return nil
    end

    local candidates = {}
    for _, room in ipairs(generatedRooms or {}) do
        if not room.isShopRoom and not room.isCardRoom and not room.isEndRoom then
            candidates[#candidates + 1] = room
        end
    end
    local candidateTieBreakers = {}
    for index, room in ipairs(candidates) do
        candidateTieBreakers[room.id or tostring(room)] = index
    end
    for i = #candidates, 2, -1 do
        local j = math.random(1, i)
        candidates[i], candidates[j] = candidates[j], candidates[i]
    end
    for index, room in ipairs(candidates) do
        candidateTieBreakers[room.id or tostring(room)] = index
    end

    table.sort(candidates, function(a, b)
        local distanceA = getRoomDistanceFromStart(a)
        local distanceB = getRoomDistanceFromStart(b)
        if distanceA == distanceB then
            local gridDistanceA = math.abs(a.gridX or 0) + math.abs(a.gridY or 0)
            local gridDistanceB = math.abs(b.gridX or 0) + math.abs(b.gridY or 0)
            if gridDistanceA == gridDistanceB then
                return (candidateTieBreakers[a.id or tostring(a)] or 0) < (candidateTieBreakers[b.id or tostring(b)] or 0)
            end
            return gridDistanceA > gridDistanceB
        end
        return distanceA > distanceB
    end)

    for _, room in ipairs(candidates) do
        local endRoom = createEndRoomFromAnchor(room, generateConfig, generatedRooms, roomIds, occupiedCells)
        if endRoom then
            return endRoom
        end
    end

    for _, room in ipairs(generatedRooms or {}) do
        if not room.isEndRoom then
            local endRoom = createEndRoomFromAnchor(room, generateConfig, generatedRooms, roomIds, occupiedCells)
            if endRoom then
                return endRoom
            end
        end
    end

    return nil
end

local function createShopRoomFromAnchor(anchorRoom, generateConfig, generatedRooms, roomIds, occupiedCells)
    local shopTemplateId = generateConfig and generateConfig.shopRoomTemplateId
    if not (shopTemplateId and anchorRoom) then
        return nil
    end

    local anchorCells = getOccupiedCells(anchorRoom)
    for i = #anchorCells, 2, -1 do
        local j = math.random(1, i)
        anchorCells[i], anchorCells[j] = anchorCells[j], anchorCells[i]
    end

    for _, anchorCell in ipairs(anchorCells) do
        for _, direction in ipairs(shuffledDirectionsList()) do
            local directionConfig = directions[direction]
            local x = anchorCell.x + directionConfig.dx
            local y = anchorCell.y + directionConfig.dy
            if not anchorRoom.neighbors[direction] and not occupiedCells[getRoomId(x, y)] then
                local placement = RoomSelector.chooseTemplatePlacement(
                    {[directionConfig.opposite] = true},
                    {templateIds = {shopTemplateId}},
                    x,
                    y,
                    occupiedCells
                )

                if placement then
                    local room = createGeneratedRoom(x, y, placement)
                    room.isShopRoom = true
                    room.distanceFromStart = getRoomDistanceFromStart(anchorRoom) + 1
                    room.doors[directionConfig.opposite] = true
                    room.doorSlotIds[directionConfig.opposite] = getDoorSlotIdForCell(room, {x = x, y = y}, directionConfig.opposite)
                    room.neighbors[directionConfig.opposite] = anchorRoom.id

                    anchorRoom.doors[direction] = true
                    anchorRoom.doorSlotIds[direction] = getDoorSlotIdForCell(anchorRoom, anchorCell, direction)
                    anchorRoom.neighbors[direction] = room.id

                    appendGeneratedRoom(generatedRooms, roomIds, occupiedCells, room)
                    return room
                end
            end
        end
    end

    return nil
end

local function createCardRoomFromAnchor(anchorRoom, generateConfig, generatedRooms, roomIds, occupiedCells)
    local cardTemplateId = generateConfig and generateConfig.cardRoomTemplateId
    if not (cardTemplateId and anchorRoom) then
        return nil
    end

    local anchorCells = getOccupiedCells(anchorRoom)
    for i = #anchorCells, 2, -1 do
        local j = math.random(1, i)
        anchorCells[i], anchorCells[j] = anchorCells[j], anchorCells[i]
    end

    for _, anchorCell in ipairs(anchorCells) do
        for _, direction in ipairs(shuffledDirectionsList()) do
            local directionConfig = directions[direction]
            local x = anchorCell.x + directionConfig.dx
            local y = anchorCell.y + directionConfig.dy
            if not anchorRoom.neighbors[direction] and not occupiedCells[getRoomId(x, y)] then
                local placement = RoomSelector.chooseTemplatePlacement(
                    {[directionConfig.opposite] = true},
                    {templateIds = {cardTemplateId}},
                    x,
                    y,
                    occupiedCells
                )

                if placement then
                    local room = createGeneratedRoom(x, y, placement)
                    room.isCardRoom = true
                    room.pathEnd = true
                    room.distanceFromStart = getRoomDistanceFromStart(anchorRoom) + 1
                    room.doors[directionConfig.opposite] = true
                    room.doorSlotIds[directionConfig.opposite] = getDoorSlotIdForCell(room, {x = x, y = y}, directionConfig.opposite)
                    room.neighbors[directionConfig.opposite] = anchorRoom.id

                    anchorRoom.doors[direction] = true
                    anchorRoom.doorSlotIds[direction] = getDoorSlotIdForCell(anchorRoom, anchorCell, direction)
                    anchorRoom.neighbors[direction] = room.id

                    appendGeneratedRoom(generatedRooms, roomIds, occupiedCells, room)
                    return room
                end
            end
        end
    end

    return nil
end

local function createShopRoomAtDistance(startRoom, generateConfig, generatedRooms, roomIds, occupiedCells)
    local minDistance = (generateConfig and generateConfig.shopDistanceMin) or 2
    local maxDistance = (generateConfig and generateConfig.shopDistanceMax) or 4
    local anchorMin = math.max(1, minDistance - 1)
    local anchorMax = math.max(anchorMin, maxDistance - 1)
    local candidates = {}
    local fallback = {}

    for _, room in ipairs(generatedRooms) do
        if room ~= startRoom and not room.isShopRoom then
            local distance = getRoomDistanceFromStart(room)
            if distance >= anchorMin and distance <= anchorMax then
                candidates[#candidates + 1] = room
            elseif distance >= 1 then
                fallback[#fallback + 1] = room
            end
        end
    end

    for i = #candidates, 2, -1 do
        local j = math.random(1, i)
        candidates[i], candidates[j] = candidates[j], candidates[i]
    end

    for _, room in ipairs(candidates) do
        local shopRoom = createShopRoomFromAnchor(room, generateConfig, generatedRooms, roomIds, occupiedCells)
        if shopRoom then
            return shopRoom
        end
    end

    table.sort(fallback, function(a, b)
        return getRoomDistanceFromStart(a) > getRoomDistanceFromStart(b)
    end)

    for _, room in ipairs(fallback) do
        local shopRoom = createShopRoomFromAnchor(room, generateConfig, generatedRooms, roomIds, occupiedCells)
        if shopRoom then
            return shopRoom
        end
    end

    return nil
end

local function createCardRooms(generateConfig, generatedRooms, roomIds, occupiedCells)
    if not (generateConfig and generateConfig.cardRoomTemplateId) then
        return 0, 0
    end

    local cardRoomChance = generateConfig.cardRoomChance
    if cardRoomChance ~= nil and math.random() > cardRoomChance then
        return 0, 0
    end

    local countConfig = generateConfig.cardRoomCount or {min = 2, max = 3}
    local minCount = countConfig.min or countConfig[1] or countConfig or 2
    local maxCount = countConfig.max or countConfig[2] or minCount
    local targetCount = math.random(math.floor(minCount), math.floor(maxCount))
    local created = 0
    local attempts = 0
    local placedCardRooms = {}

    local function gridDistance(a, b)
        return math.abs((a.gridX or 0) - (b.gridX or 0)) + math.abs((a.gridY or 0) - (b.gridY or 0))
    end

    local function getSpreadScore(room)
        local distanceScore = getRoomDistanceFromStart(room)
        local nearestCardDistance = 12

        for _, cardRoom in ipairs(placedCardRooms) do
            nearestCardDistance = math.min(nearestCardDistance, gridDistance(room, cardRoom))
        end

        return distanceScore * 2 + nearestCardDistance * 4 + math.random()
    end

    local function getSortedCardAnchors()
        local candidates = {}
        for _, room in ipairs(generatedRooms) do
            if not room.isShopRoom and not room.isCardRoom and not room.isEndRoom then
                candidates[#candidates + 1] = {
                    room = room,
                    score = getSpreadScore(room),
                }
            end
        end

        table.sort(candidates, function(a, b)
            return a.score > b.score
        end)

        return candidates
    end

    while created < targetCount and attempts < targetCount * 40 do
        attempts = attempts + 1
        local candidates = getSortedCardAnchors()

        if #candidates == 0 then
            return created, targetCount
        end

        local placedRoom = nil
        for _, candidate in ipairs(candidates) do
            placedRoom = createCardRoomFromAnchor(candidate.room, generateConfig, generatedRooms, roomIds, occupiedCells)
            if placedRoom then
                break
            end
        end

        if placedRoom then
            placedCardRooms[#placedCardRooms + 1] = placedRoom
            created = created + 1
        else
            return created, targetCount
        end
    end

    return created, targetCount
end

local function isLargeGeneratedRoom(room)
    return room
        and not room.isShopRoom
        and not room.isCardRoom
        and ((room.gridWidth or 1) > 1 or (room.gridHeight or 1) > 1)
end

local function getOnlyConnectionDirection(room)
    local result = nil
    local count = 0

    for _, direction in ipairs(directionOrder) do
        if room.neighbors and room.neighbors[direction] then
            result = direction
            count = count + 1
        end
    end

    if count == 1 then
        return result
    end

    return nil
end

local function getEdgeCellForExit(room, exitDirection, entryDirection)
    local cells = getOccupiedCells(room)
    local selected = cells[1]
    local entrySlotId = room.doorSlotIds and room.doorSlotIds[entryDirection]

    for _, cell in ipairs(cells) do
        if exitDirection == "east" then
            local betterEdge = cell.x > selected.x
            local betterSlot = cell.x == selected.x
                and ((entrySlotId == "bottom" and cell.y > selected.y) or (entrySlotId ~= "bottom" and cell.y < selected.y))
            if betterEdge or betterSlot then
                selected = cell
            end
        elseif exitDirection == "west" then
            local betterEdge = cell.x < selected.x
            local betterSlot = cell.x == selected.x
                and ((entrySlotId == "bottom" and cell.y > selected.y) or (entrySlotId ~= "bottom" and cell.y < selected.y))
            if betterEdge or betterSlot then
                selected = cell
            end
        elseif exitDirection == "south" then
            local betterEdge = cell.y > selected.y
            local betterSlot = cell.y == selected.y
                and ((entrySlotId == "right" and cell.x > selected.x) or (entrySlotId ~= "right" and cell.x < selected.x))
            if betterEdge or betterSlot then
                selected = cell
            end
        elseif exitDirection == "north" then
            local betterEdge = cell.y < selected.y
            local betterSlot = cell.y == selected.y
                and ((entrySlotId == "right" and cell.x > selected.x) or (entrySlotId ~= "right" and cell.x < selected.x))
            if betterEdge or betterSlot then
                selected = cell
            end
        end
    end

    return selected
end

local function addOppositeExitFromLargeRoom(room, generateConfig, generatedRooms, roomIds, occupiedCells)
    local entryDirection = getOnlyConnectionDirection(room)
    if not entryDirection then
        return false
    end

    local exitDirection = directions[entryDirection].opposite
    if room.neighbors[exitDirection] then
        return false
    end

    local exitCell = getEdgeCellForExit(room, exitDirection, entryDirection)
    local directionConfig = directions[exitDirection]
    local x = exitCell.x + directionConfig.dx
    local y = exitCell.y + directionConfig.dy
    local targetRoom = occupiedCells[getRoomId(x, y)]

    if targetRoom and targetRoom ~= room and canAddConnectionToRoom(targetRoom) then
        return tryConnectRooms(room, targetRoom, exitDirection, exitCell, {x = x, y = y})
    end

    if targetRoom then
        return false
    end

    local placement = RoomSelector.chooseTemplatePlacement(
        {[directionConfig.opposite] = true},
        generateConfig,
        x,
        y,
        occupiedCells
    )

    if not placement then
        return false
    end

    local newRoom = createGeneratedRoom(x, y, placement)
    newRoom.doors[directionConfig.opposite] = true
    newRoom.doorSlotIds[directionConfig.opposite] = getDoorSlotIdForCell(newRoom, {x = x, y = y}, directionConfig.opposite)
    newRoom.neighbors[directionConfig.opposite] = room.id

    room.doors[exitDirection] = true
    room.doorSlotIds[exitDirection] = getDoorSlotIdForCell(room, exitCell, exitDirection)
    if isRoomStillCompatible(room) then
        room.neighbors[exitDirection] = newRoom.id
        newRoom.distanceFromStart = getRoomDistanceFromStart(room) + 1
        appendGeneratedRoom(generatedRooms, roomIds, occupiedCells, newRoom)
        return true
    end

    room.doors[exitDirection] = nil
    room.doorSlotIds[exitDirection] = nil
    return false
end

local function addOppositeExitsForLargeRooms(generateConfig, generatedRooms, roomIds, occupiedCells)
    if generateConfig.largeRoomOppositeExit == false then
        return
    end

    local snapshot = {}
    for _, room in ipairs(generatedRooms) do
        snapshot[#snapshot + 1] = room
    end
    for _, room in ipairs(snapshot) do
        if isLargeGeneratedRoom(room) and getOnlyConnectionDirection(room) then
            addOppositeExitFromLargeRoom(room, generateConfig, generatedRooms, roomIds, occupiedCells)
        end
    end
end

appendGeneratedRoom = function(generatedRooms, roomIds, occupiedCells, roomConfig)
    generatedRooms[#generatedRooms + 1] = roomConfig
    roomIds[roomConfig.id] = roomConfig
    reserveRoomCells(roomConfig, occupiedCells)
end

isRoomStillCompatible = function(room)
    return RoomTemplates:supportsDoors(room.templateId, room.doors)
end

local function createGraphRooms(generateConfig)
    local battleRoomCount = generateConfig.battleRoomCount
    local roomCount = battleRoomCount and (math.floor(battleRoomCount) + 1) or (generateConfig.roomCount or 8)
    local extraConnectionChance = generateConfig.extraConnectionChance or 0
    local shopRoomCount = generateConfig.shopRoomCount
    local hasMandatoryShop = generateConfig.shopRoomTemplateId ~= nil
    local normalRoomCount = hasMandatoryShop and not shopRoomCount and math.max(1, roomCount - 1) or roomCount
    local endRoomCount = generateConfig.endRoomCount or (generateConfig.endRoomTemplateId and 1 or 0)
    local generatedRooms = {}
    local roomIds = {}
    local occupiedCells = {}

    local startPlacement = RoomSelector.chooseTemplatePlacement({}, getStartGenerateConfig(generateConfig), 0, 0, occupiedCells)
    assert(startPlacement, "No room template can be placed at the start room")
    local startRoom = createGeneratedRoom(0, 0, startPlacement)
    startRoom.distanceFromStart = 0
    appendGeneratedRoom(generatedRooms, roomIds, occupiedCells, startRoom)

    local attempts = 0
    while #generatedRooms < normalRoomCount and attempts < roomCount * 80 do
        attempts = attempts + 1

        local expandableRooms = getExpandableRooms(generatedRooms)
        if #expandableRooms == 0 then
            expandableRooms = generatedRooms
        end

        local sourceRoom = expandableRooms[math.random(1, #expandableRooms)]
        local sourceCell = getRandomOccupiedCell(sourceRoom)
        local direction = directionOrder[math.random(1, #directionOrder)]
        local directionConfig = directions[direction]
        local x = sourceCell.x + directionConfig.dx
        local y = sourceCell.y + directionConfig.dy
        local roomId = getRoomId(x, y)

        if not sourceRoom.neighbors[direction] then
            if not occupiedCells[roomId] then
                local newRoomDoors = {
                    [directionConfig.opposite] = true,
                }
                local useEndTemplateWeights = shouldCreatePathEndRoom(generateConfig, generatedRooms, roomCount)
                local placementConfig = generateConfig
                if useEndTemplateWeights then
                    placementConfig = copyTable(generateConfig)
                    placementConfig.useEndTemplateWeights = true
                end
                local placement = RoomSelector.chooseTemplatePlacement(newRoomDoors, placementConfig, x, y, occupiedCells)

                if placement then
                    local room = createGeneratedRoom(x, y, placement)
                    room.pathEnd = useEndTemplateWeights
                    room.doors[directionConfig.opposite] = true
                    room.doorSlotIds[directionConfig.opposite] = getDoorSlotIdForCell(room, {x = x, y = y}, directionConfig.opposite)
                    room.neighbors[directionConfig.opposite] = sourceRoom.id

                    sourceRoom.doors[direction] = true
                    sourceRoom.doorSlotIds[direction] = getDoorSlotIdForCell(sourceRoom, sourceCell, direction)
                    if isRoomStillCompatible(sourceRoom) then
                        sourceRoom.neighbors[direction] = room.id
                        room.distanceFromStart = getRoomDistanceFromStart(sourceRoom) + 1
                        appendGeneratedRoom(generatedRooms, roomIds, occupiedCells, room)
                    else
                        sourceRoom.doors[direction] = nil
                        sourceRoom.doorSlotIds[direction] = nil
                        sourceRoom.neighbors[direction] = nil
                    end
                end
            elseif occupiedCells[roomId] ~= sourceRoom then
                local neighbor = occupiedCells[roomId]
                if canAddConnectionToRoom(sourceRoom) and canAddConnectionToRoom(neighbor) then
                    tryConnectRooms(sourceRoom, neighbor, direction, sourceCell, {x = x, y = y})
                end
            end
        end
    end

    if battleRoomCount then
        assert(#generatedRooms >= normalRoomCount, "Could not place requested battle rooms")
    end

    addOppositeExitsForLargeRooms(generateConfig, generatedRooms, roomIds, occupiedCells)

    if hasMandatoryShop then
        local targetShopCount = shopRoomCount or 1
        for _ = 1, targetShopCount do
            local shopRoom = createShopRoomAtDistance(startRoom, generateConfig, generatedRooms, roomIds, occupiedCells)
            assert(shopRoom or not shopRoomCount, "Could not place requested shop room")
        end
    end

    for _ = 1, endRoomCount do
        local endRoom = createEndRoom(generateConfig, generatedRooms, roomIds, occupiedCells)
        assert(endRoom, "Could not place requested end room")
    end
    local cardRoomsCreated, cardRoomsRequested = createCardRooms(generateConfig, generatedRooms, roomIds, occupiedCells)
    if generateConfig.cardRoomCount and generateConfig.cardRoomCount.min == generateConfig.cardRoomCount.max then
        assert(cardRoomsCreated >= cardRoomsRequested, "Could not place requested card rooms")
    end

    for _, room in ipairs(generatedRooms) do
        local canAddExtraConnections = not room.isShopRoom
            and not room.isCardRoom
            and not room.isEndRoom
            and not (room.pathEnd and getRoomConnectionCount(room) <= 1)

        if canAddExtraConnections then
            for _, direction in ipairs(directionOrder) do
                if not room.neighbors[direction] and math.random() < extraConnectionChance then
                    local config = directions[direction]
                    local cell = getRandomOccupiedCell(room)
                    local neighbor = occupiedCells[getRoomId(cell.x + config.dx, cell.y + config.dy)]
                    if neighbor and neighbor ~= room and canAddConnectionToRoom(neighbor) then
                        tryConnectRooms(room, neighbor, direction, cell, {x = cell.x + config.dx, y = cell.y + config.dy})
                    end
                end
            end
        end
    end

    return generatedRooms
end

local function shouldLogFloorGeneration()
    return GAME_FLAGS and GAME_FLAGS.logFloorGeneration == true
end

local function sortedRooms(rooms)
    local list = {}
    for _, room in pairs(rooms or {}) do
        list[#list + 1] = room
    end

    table.sort(list, function(a, b)
        if a.gridY == b.gridY then
            return a.gridX < b.gridX
        end
        return a.gridY < b.gridY
    end)

    return list
end

local function logFloor(rooms, currentRoomId)
    if not shouldLogFloorGeneration() then
        return
    end

    print("[floor] generated rooms:")
    for _, room in ipairs(sortedRooms(rooms)) do
        local parts = {}
        for _, direction in ipairs(directionOrder) do
            if room.neighbors[direction] then
                local slotId = room.doorSlotIds and room.doorSlotIds[direction] or "default"
                parts[#parts + 1] = direction .. "=" .. room.neighbors[direction] .. ":" .. slotId
            end
        end
        local cells = {}
        for _, cell in ipairs(getOccupiedCells(room)) do
            cells[#cells + 1] = getRoomId(cell.x, cell.y)
        end

        local marker = room.id == currentRoomId and " *" or ""
        print(string.format(
            "[floor] %s%s (%d,%d) dist=%d size=%dx%d grid=%dx%d variant=%s template=%s cells={%s} doors={%s}",
            room.id,
            marker,
            room.gridX,
            room.gridY,
            room.distanceFromStart or 0,
            room.width or 0,
            room.height or 0,
            room.gridWidth or 1,
            room.gridHeight or 1,
            room.occupancyVariant or "default",
            room.templateId or "none",
            table.concat(cells, ", "),
            table.concat(parts, ", ")
        ))
    end
end

local function getActiveFloorLevel(level)
    local floorIndex = level and level.currentFloorIndex or 1
    return level and level.floorLevels and level.floorLevels[floorIndex] or nil
end

local function roomMatchesThemeArea(room, area)
    if not (room and area) then
        return false
    end

    local distance = room.distanceFromStart or (math.abs(room.gridX or 0) + math.abs(room.gridY or 0))
    if area.minDistance and distance < area.minDistance then
        return false
    end
    if area.maxDistance and distance > area.maxDistance then
        return false
    end

    return true
end

local function applyThemeArea(rooms, themeConfig, area)
    local themeId = area and (area.theme or area.themeId)
    if not (themeId and VisualThemes.themes[themeId]) then
        return
    end

    local eligible = {}
    for _, room in pairs(rooms or {}) do
        local forcedDefault = themeConfig and themeConfig.startRoomUseDefault ~= false
            and (room.distanceFromStart or 0) <= 0
        if not forcedDefault and roomMatchesThemeArea(room, area) then
            eligible[#eligible + 1] = room
        end
    end

    if #eligible == 0 then
        return
    end

    local seeds = {}
    local seedChance = area.seedChance or area.chance or 0.35
    for _, room in ipairs(eligible) do
        if math.random() < seedChance then
            seeds[#seeds + 1] = room
        end
    end
    if #seeds == 0 then
        seeds[1] = eligible[math.random(1, #eligible)]
    end

    local radius = math.max(0, area.radius or 1)
    local fillChance = area.fillChance or 0.85
    for _, seed in ipairs(seeds) do
        local queue = {{room = seed, depth = 0}}
        local visited = {[seed.id] = true}
        local index = 1

        while queue[index] do
            local entry = queue[index]
            index = index + 1

            if entry.depth == 0 or math.random() < fillChance then
                entry.room.themeId = themeId
            end

            if entry.depth < radius then
                for _, neighborId in pairs(entry.room.neighbors or {}) do
                    local neighbor = rooms[neighborId]
                    if neighbor and not visited[neighbor.id] and roomMatchesThemeArea(neighbor, area) then
                        visited[neighbor.id] = true
                        queue[#queue + 1] = {
                            room = neighbor,
                            depth = entry.depth + 1,
                        }
                    end
                end
            end
        end
    end
end

local function assignRoomVisualThemes(rooms, level)
    local floorLevel = getActiveFloorLevel(level)
    local themeConfig = floorLevel and floorLevel.visualThemes
        or level and level.visualThemes
        or nil

    for _, room in pairs(rooms or {}) do
        room.themeId = VisualThemes:chooseRoomTheme(room, themeConfig)
    end

    for _, area in ipairs(themeConfig and themeConfig.areas or {}) do
        applyThemeArea(rooms, themeConfig, area)
    end
end

function FloorManager:load(level)
    self.level = level
    self.rooms = {}
    self.currentRoomId = nil
    self.floorState = {
        usedShopProducts = {},
        shopCount = 0,
    }

    local floorConfig = level and level.floorConfig
    local roomsConfig = floorConfig and floorConfig.rooms
    local generateConfig = floorConfig and floorConfig.generate

    if generateConfig and generateConfig.enabled then
        roomsConfig = createGraphRooms(generateConfig)
    end

    if roomsConfig then
        for _, roomConfig in ipairs(roomsConfig) do
            local room = createRoom(roomConfig, level)
            self.rooms[room.id] = room
        end
        self.currentRoomId = floorConfig.startRoomId or DEFAULT_START_ROOM_ID
        if not self.rooms[self.currentRoomId] then
            self.currentRoomId = next(self.rooms)
        end
    else
        local room = createRoom({
            id = DEFAULT_START_ROOM_ID,
            tilemapConfig = level and level.tilemapConfig,
        }, level or {})
        self.rooms[room.id] = room
        self.currentRoomId = room.id
    end

    local currentRoom = self:getCurrentRoom()
    if currentRoom and currentRoom.state then
        currentRoom.state.visited = true
        currentRoom.state.discovered = true
    end

    assignRoomVisualThemes(self.rooms, level)

    logFloor(self.rooms, self.currentRoomId)
end

local function isProductAlreadyUsed(floorState, productId)
    return floorState and floorState.usedShopProducts and floorState.usedShopProducts[productId] == true
end

local function getWeaponIndexByName(productId)
    for index, weapon in ipairs(WeaponDefinitions or {}) do
        if weapon.name == productId then
            return weapon.id or index
        end
    end

    return nil
end

local function isProductOwned(productId)
    if not productId then
        return false
    end

    if Game and Game.hasPurchasedWeapon and Game:hasPurchasedWeapon(productId) then
        return true
    end

    local weaponIndex = getWeaponIndexByName(productId)
    return weaponIndex ~= nil
        and Player
        and Player.gun
        and Player.gun.secondary_weapon
        and Player.gun.secondary_weapon.index == weaponIndex
end

local function isProductUnavailable(floorState, productId)
    return isProductAlreadyUsed(floorState, productId) or isProductOwned(productId)
end

local function chooseShopProduct(shopConfig, floorState)
    local candidates = {}
    local totalChance = 0
    for _, productConfig in ipairs(shopConfig.products or {}) do
        if productConfig.id and not isProductUnavailable(floorState, productConfig.id) then
            local chance = productConfig.chance or productConfig.weight or 1
            if chance > 0 then
                candidates[#candidates + 1] = productConfig
                totalChance = totalChance + chance
            end
        end
    end

    if totalChance <= 0 then
        return nil
    end

    local roll = math.random() * totalChance
    local cursor = 0
    for _, productConfig in ipairs(candidates) do
        cursor = cursor + (productConfig.chance or productConfig.weight or 1)
        if roll <= cursor then
            return productConfig.id
        end
    end

    return candidates[#candidates] and candidates[#candidates].id or nil
end

local function playerHasSecondaryWeapon()
    return Player
        and Player.gun
        and Player.gun.secondary_weapon ~= nil
end

function FloorManager:resolveCurrentRoomShopProducts()
    local room = self:getCurrentRoom()
    local state = room and room.state
    local shopConfig = self.level and self.level.shopConfig

    if not state then
        return {}
    end

    if state.shopResolved then
        return state.shopProducts or {}
    end

    state.shopResolved = true
    state.shopProduct = nil
    state.shopProducts = {}

    if room and room.isCardRoom then
        local cardProductId = shopConfig and shopConfig.cardProductId or "card_upgrade"
        local doubleChance = shopConfig and shopConfig.cardRoomDoubleShopChance or 0.10
        local count = math.random() < doubleChance and 2 or 1
        for _ = 1, count do
            state.shopProducts[#state.shopProducts + 1] = cardProductId
        end
        state.shopProduct = cardProductId
        return state.shopProducts
    end

    if not (shopConfig and shopConfig.enabled and room and room.isShopRoom) then
        return state.shopProducts
    end

    self.floorState = self.floorState or {usedShopProducts = {}, shopCount = 0}

    local productId = chooseShopProduct(shopConfig, self.floorState)
    if productId then
        state.shopProducts[#state.shopProducts + 1] = productId
        state.shopProduct = productId
        self.floorState.usedShopProducts[productId] = true
    end

    local ammoProductId = shopConfig.ammoProductId or "full_bullets"
    local ammoChance = shopConfig.ammoChance or 0
    if playerHasSecondaryWeapon()
        and not isProductAlreadyUsed(self.floorState, ammoProductId)
        and math.random() < ammoChance then
        state.shopProducts[#state.shopProducts + 1] = ammoProductId
        self.floorState.usedShopProducts[ammoProductId] = true
    end

    return state.shopProducts
end

function FloorManager:resolveCurrentRoomShopProduct()
    local products = self:resolveCurrentRoomShopProducts()
    return products and products[1] or nil
end

function FloorManager:getCurrentRoom()
    if not self.rooms or not self.currentRoomId then
        return nil
    end

    return self.rooms[self.currentRoomId]
end

function FloorManager:getRoom(roomId)
    if not self.rooms then
        return nil
    end

    return self.rooms[roomId]
end

function FloorManager:getRooms()
    return self.rooms or {}
end

function FloorManager:getCurrentTilemapConfig()
    local room = self:getCurrentRoom()
    if room and room.tilemapConfig then
        return room.tilemapConfig
    end

    return self.level and self.level.tilemapConfig or nil
end

function FloorManager:getCurrentRoomTheme()
    local room = self:getCurrentRoom()
    return VisualThemes:get(room and room.themeId)
end

function FloorManager:getCurrentRoomState()
    local room = self:getCurrentRoom()
    return room and room.state or nil
end

function FloorManager:markCurrentRoomObjectBroken(x, y)
    local state = self:getCurrentRoomState()
    if not state then
        return
    end

    state.brokenObjects = state.brokenObjects or {}
    state.brokenObjects[x .. ":" .. y] = true
end

function FloorManager:isCurrentRoomObjectBroken(x, y)
    local state = self:getCurrentRoomState()
    return state and state.brokenObjects and state.brokenObjects[x .. ":" .. y] == true
end

function FloorManager:enterRoom(roomId, options)
    if not self.rooms or not self.rooms[roomId] then
        return false
    end

    self.currentRoomId = roomId
    if not (options and options.deferReveal) then
        self.rooms[roomId].state.visited = true
        self.rooms[roomId].state.discovered = true
    end
    return true
end

function FloorManager:revealRoom(roomId)
    local room = self.rooms and self.rooms[roomId]
    if not (room and room.state) then
        return false
    end

    room.state.visited = true
    room.state.discovered = true
    return true
end

return FloorManager
