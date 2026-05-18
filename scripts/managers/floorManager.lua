local FloorManager = {}

local RoomTemplates = require("scripts/rooms/roomTemplates")
local WeaponDefinitions = require("scripts/player/weapons/init")

local DEFAULT_START_ROOM_ID = "0:0"
local directions = {
    north = {dx = 0, dy = -1, opposite = "south"},
    south = {dx = 0, dy = 1, opposite = "north"},
    west = {dx = -1, dy = 0, opposite = "east"},
    east = {dx = 1, dy = 0, opposite = "west"},
}
local directionOrder = {"north", "south", "west", "east"}

local function copyTable(source)
    if not source then
        return nil
    end

    local copied = {}
    for key, value in pairs(source) do
        if type(value) == "table" then
            copied[key] = copyTable(value)
        else
            copied[key] = value
        end
    end
    return copied
end

local function getWeightedValue(item, weights)
    local id = type(item) == "table" and item.id or item
    if weights and id and weights[id] ~= nil then
        return weights[id]
    end

    if type(item) == "table" then
        return item.weight or item.chance or 1
    end

    return 1
end

local function chooseWeighted(list, weights)
    local totalWeight = 0

    for _, item in ipairs(list or {}) do
        local weight = getWeightedValue(item, weights)
        if weight > 0 then
            totalWeight = totalWeight + weight
        end
    end

    if totalWeight <= 0 then
        return nil
    end

    local roll = math.random() * totalWeight
    for _, item in ipairs(list or {}) do
        local weight = getWeightedValue(item, weights)
        if weight > 0 then
            roll = roll - weight
            if roll <= 0 then
                return item
            end
        end
    end

    return list[#list]
end

local function chooseTemplateTilemapConfig(template)
    if template and template.tilemapConfigs then
        return copyTable(chooseWeighted(template.tilemapConfigs))
    end

    return copyTable(template and template.tilemapConfig)
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
        occupancyVariants = copyTable(roomConfig.occupancyVariants or (template and template.occupancyVariants)),
        occupancyVariant = roomConfig.occupancyVariant,
        occupiedOffsets = copyTable(resolveOccupiedOffsets(roomConfig, template)),
        shape = roomConfig.shape or (template and template.shape) or "rect",
        doors = copyTable(roomConfig.doors) or {},
        doorSlotIds = copyTable(roomConfig.doorSlotIds) or {},
        neighbors = copyTable(roomConfig.neighbors) or {},
        doorSlots = copyTable(roomConfig.doorSlots or (template and template.doorSlots)) or {},
        spawnPoints = copyTable(roomConfig.spawnPoints or (template and template.spawnPoints)) or {},
        tilemapConfig = copyTable(roomConfig.tilemapConfig or chooseTemplateTilemapConfig(template) or level.tilemapConfig),
        isShopRoom = roomConfig.isShopRoom == true or templateId == "store_32x32",
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

local function getTemplateCandidates(generateConfig)
    if generateConfig.templateIds then
        return generateConfig.templateIds
    end

    if generateConfig.templateId then
        return {generateConfig.templateId}
    end

    return nil
end

local function getTemplateOccupancyOptions(template)
    local options = {}

    if template.occupancyVariants then
        for variantId, offsets in pairs(template.occupancyVariants) do
            options[#options + 1] = {
                variantId = variantId,
                offsets = offsets,
            }
        end
    else
        options[#options + 1] = {
            variantId = nil,
            offsets = template.occupiedOffsets or {
                {x = 0, y = 0},
            },
        }
    end

    return options
end

local function canPlaceOccupancy(x, y, offsets, occupiedCells)
    for _, offset in ipairs(offsets) do
        local cellId = getRoomId(x + offset.x, y + offset.y)
        if occupiedCells[cellId] then
            return false
        end
    end

    return true
end

local function reserveRoomCells(room, occupiedCells)
    for _, cell in ipairs(getOccupiedCells(room)) do
        occupiedCells[getRoomId(cell.x, cell.y)] = room
    end
end

local function chooseTemplatePlacement(doors, generateConfig, x, y, occupiedCells)
    local templateWeights = generateConfig and generateConfig.templateWeights
    local templateIds = getTemplateCandidates(generateConfig)
    local compatibleTemplates = RoomTemplates:getCompatible(doors, templateIds)
    local candidates = {}

    if generateConfig and generateConfig.useEndTemplateWeights then
        templateWeights = generateConfig.endTemplateWeights or templateWeights
    end

    for _, template in ipairs(compatibleTemplates) do
        local placements = {}
        for _, option in ipairs(getTemplateOccupancyOptions(template)) do
            if canPlaceOccupancy(x, y, option.offsets, occupiedCells) then
                placements[#placements + 1] = {
                    template = template,
                    variantId = option.variantId,
                    offsets = option.offsets,
                }
            end
        end

        if #placements > 0 then
            candidates[#candidates + 1] = {
                id = template.id,
                template = template,
                placements = placements,
            }
        end
    end

    local selected = chooseWeighted(candidates, templateWeights)
    if not selected then
        return nil
    end

    local placement = selected.placements[math.random(1, #selected.placements)]
    placement.tilemapConfig = chooseTemplateTilemapConfig(selected.template)
    return placement
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

local function createShopRoomNearStart(startRoom, generateConfig, generatedRooms, roomIds, occupiedCells)
    local shopTemplateId = generateConfig and generateConfig.shopRoomTemplateId
    if not shopTemplateId then
        return nil
    end

    local shuffledDirections = copyTable(directionOrder)
    for i = #shuffledDirections, 2, -1 do
        local j = math.random(1, i)
        shuffledDirections[i], shuffledDirections[j] = shuffledDirections[j], shuffledDirections[i]
    end

    for _, direction in ipairs(shuffledDirections) do
        local directionConfig = directions[direction]
        local x = startRoom.gridX + directionConfig.dx
        local y = startRoom.gridY + directionConfig.dy
        if not occupiedCells[getRoomId(x, y)] then
            local placement = chooseTemplatePlacement(
                {[directionConfig.opposite] = true},
                {templateIds = {shopTemplateId}},
                x,
                y,
                occupiedCells
            )

            if placement then
                local room = createGeneratedRoom(x, y, placement)
                room.isShopRoom = true
                room.doors[directionConfig.opposite] = true
                room.doorSlotIds[directionConfig.opposite] = getDoorSlotIdForCell(room, {x = x, y = y}, directionConfig.opposite)
                room.neighbors[directionConfig.opposite] = startRoom.id

                startRoom.doors[direction] = true
                startRoom.doorSlotIds[direction] = getDoorSlotIdForCell(startRoom, {x = startRoom.gridX, y = startRoom.gridY}, direction)
                startRoom.neighbors[direction] = room.id

                appendGeneratedRoom(generatedRooms, roomIds, occupiedCells, room)
                return room
            end
        end
    end

    return nil
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
    local roomCount = generateConfig.roomCount or 8
    local extraConnectionChance = generateConfig.extraConnectionChance or 0
    local generatedRooms = {}
    local roomIds = {}
    local occupiedCells = {}

    local startPlacement = chooseTemplatePlacement({}, getStartGenerateConfig(generateConfig), 0, 0, occupiedCells)
    assert(startPlacement, "No room template can be placed at the start room")
    local startRoom = createGeneratedRoom(0, 0, startPlacement)
    appendGeneratedRoom(generatedRooms, roomIds, occupiedCells, startRoom)
    createShopRoomNearStart(startRoom, generateConfig, generatedRooms, roomIds, occupiedCells)

    local attempts = 0
    while #generatedRooms < roomCount and attempts < roomCount * 80 do
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
                local placement = chooseTemplatePlacement(newRoomDoors, placementConfig, x, y, occupiedCells)

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

    for _, room in ipairs(generatedRooms) do
        local canAddExtraConnections = not (room.pathEnd and getRoomConnectionCount(room) <= 1)

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
            "[floor] %s%s (%d,%d) size=%dx%d grid=%dx%d variant=%s template=%s cells={%s} doors={%s}",
            room.id,
            marker,
            room.gridX,
            room.gridY,
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

function FloorManager:enterRoom(roomId)
    if not self.rooms or not self.rooms[roomId] then
        return false
    end

    self.currentRoomId = roomId
    self.rooms[roomId].state.visited = true
    self.rooms[roomId].state.discovered = true
    return true
end

return FloorManager
