local Minimap = {}

local MinimapConfig = require("scripts/config/minimapConfig")

local sprites = {
    panel = love.graphics.newImage("assets/sprites/ui/map/map.png"),
    room32x32 = love.graphics.newImage("assets/sprites/ui/map/32x32.png"),
    room32x48 = love.graphics.newImage("assets/sprites/ui/map/32x48.png"),
    room48x32 = love.graphics.newImage("assets/sprites/ui/map/48x32.png"),
    room48x48 = love.graphics.newImage("assets/sprites/ui/map/48x48.png"),
    connection = love.graphics.newImage("assets/sprites/ui/map/connection.png"),
    player = love.graphics.newImage("assets/sprites/ui/map/player.png"),
    store = love.graphics.newImage("assets/sprites/ui/map/store.png"),
    cards = love.graphics.newImage("assets/sprites/ui/map/cards.png"),
    unknown = love.graphics.newImage("assets/sprites/ui/map/unknown.png"),
}

for _, image in pairs(sprites) do
    image:setFilter("nearest", "nearest")
end

local oppositeDirections = {
    north = "south",
    south = "north",
    west = "east",
    east = "west",
}

local gridDirectionVectors = {
    north = {x = 0, y = -1},
    south = {x = 0, y = 1},
    west = {x = -1, y = 0},
    east = {x = 1, y = 0},
}

local function pixel(value)
    return math.floor(value + 0.5)
end

local function clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
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

local function getRoomCenterCell(room)
    local cells = getRoomCells(room)
    local x, y = 0, 0
    for _, cell in ipairs(cells) do
        x = x + cell.x
        y = y + cell.y
    end

    local count = math.max(1, #cells)
    return x / count, y / count
end

local function getRoomMinimapCells(room)
    if room.state and room.state.visited then
        return getRoomCells(room)
    end

    if room.state and room.state.minimapPreviewCell then
        return {
            {
                x = room.state.minimapPreviewCell.x,
                y = room.state.minimapPreviewCell.y,
            },
        }
    end

    local centerX, centerY = getRoomCenterCell(room)
    return {
        {
            x = math.floor(centerX + 0.5),
            y = math.floor(centerY + 0.5),
        },
    }
end

local function getRoomMinimapBounds(room)
    local cells = getRoomMinimapCells(room)
    local minX, maxX = cells[1].x, cells[1].x
    local minY, maxY = cells[1].y, cells[1].y

    for _, cell in ipairs(cells) do
        minX = math.min(minX, cell.x)
        maxX = math.max(maxX, cell.x)
        minY = math.min(minY, cell.y)
        maxY = math.max(maxY, cell.y)
    end

    return minX, minY, maxX, maxY
end

local function getRoomMinimapRects(room)
    local cells = getRoomMinimapCells(room)
    local minX, minY, maxX, maxY = getRoomMinimapBounds(room)
    local expectedRectCells = (maxX - minX + 1) * (maxY - minY + 1)

    if #cells == expectedRectCells then
        return {
            {
                minX = minX,
                minY = minY,
                maxX = maxX,
                maxY = maxY,
            },
        }
    end

    local rects = {}
    for _, cell in ipairs(cells) do
        rects[#rects + 1] = {
            minX = cell.x,
            minY = cell.y,
            maxX = cell.x,
            maxY = cell.y,
        }
    end
    return rects
end

local function isRoomKnown(room)
    return room.state and room.state.discovered == true
end

local function isStartRoom(floorManager, room)
    local level = floorManager.level
    local startRoomId = level and level.floorConfig and level.floorConfig.startRoomId or "0:0"
    return room and room.id == startRoomId
end

local function shouldShowShopIcon(floorManager, room)
    local state = room and room.state
    return state
        and state.visited == true
        and state.shopProduct ~= nil
        and not isStartRoom(floorManager, room)
        and not room.isCardRoom
end

local function shouldShowCardIcon(floorManager, room)
    local state = room and room.state
    return room
        and room.isCardRoom
        and state
        and state.visited == true
        and not isStartRoom(floorManager, room)
end

local function getRoomSprite(rect, room)
    if room and room.state and not room.state.visited then
        return sprites.unknown
    end

    local widthCells = rect.maxX - rect.minX + 1
    local heightCells = rect.maxY - rect.minY + 1

    if widthCells == 2 and heightCells == 2 then
        return sprites.room48x48
    elseif widthCells == 2 then
        return sprites.room48x32
    elseif heightCells == 2 then
        return sprites.room32x48
    end

    return sprites.room32x32
end

local function drawSprite(image, centerX, centerY, width, height)
    if not image then
        return
    end

    love.graphics.draw(
        image,
        pixel(centerX),
        pixel(centerY),
        0,
        width / image:getWidth(),
        height / image:getHeight(),
        image:getWidth() / 2,
        image:getHeight() / 2
    )
end

local function findAdjacentCells(roomA, roomB, direction)
    local vector = gridDirectionVectors[direction]
    if not vector then
        return nil, nil
    end

    for _, cellA in ipairs(getRoomCells(roomA)) do
        for _, cellB in ipairs(getRoomCells(roomB)) do
            if cellB.x == cellA.x + vector.x and cellB.y == cellA.y + vector.y then
                return cellA, cellB
            end
        end
    end

    return nil, nil
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

local function getConnectionCells(roomA, roomB, direction)
    local cellA, cellB = findAdjacentCells(roomA, roomB, direction)
    cellA = getRoomEdgeCell(roomA, direction) or cellA
    cellB = getRoomEdgeCell(roomB, oppositeDirections[direction]) or cellB
    if roomA.state and not roomA.state.visited and roomA.state.minimapPreviewCell then
        cellA = roomA.state.minimapPreviewCell
    end
    if roomB.state and not roomB.state.visited and roomB.state.minimapPreviewCell then
        cellB = roomB.state.minimapPreviewCell
    end

    return cellA, cellB
end

function Minimap.getRoomEdgeCell(room, direction)
    return getRoomEdgeCell(room, direction)
end

function Minimap.draw(context)
    local game = context.game
    local floorManager = context.floorManager
    local tilemap = context.tilemap
    local player = context.player
    local currentRoom = game.minimapRoomOverrideId and floorManager:getRoom(game.minimapRoomOverrideId)
        or floorManager:getCurrentRoom()

    if not currentRoom then
        return
    end

    local rooms = floorManager:getRooms()
    local config = MinimapConfig
    local mapSize = config.size
    local mapX = pixel(baseWidth - mapSize - config.marginX)
    local mapY = pixel(config.marginY)
    local centerX = pixel(mapX + mapSize / 2)
    local centerY = pixel(mapY + mapSize / 2)
    local step = config.cellSize + config.cellGap
    local spriteScale = config.spriteScale or (config.cellSize / sprites.room32x32:getWidth())
    local currentCellX, currentCellY = getRoomCenterCell(currentRoom)
    local viewRadius = config.viewRadius
    local previousLineStyle = love.graphics.getLineStyle()

    love.graphics.setLineStyle("rough")
    love.graphics.setColor(1, 1, 1, 1)
    drawSprite(sprites.panel, centerX, centerY, mapSize, mapSize)

    local previousScissorX, previousScissorY, previousScissorW, previousScissorH = love.graphics.getScissor()
    love.graphics.setScissor(mapX, mapY, mapSize, mapSize)

    local knownRooms = {}
    for roomId, room in pairs(rooms) do
        knownRooms[roomId] = isRoomKnown(room)
    end

    local function toMinimapPosition(cellX, cellY)
        return pixel(centerX + (cellX - currentCellX) * step), pixel(centerY + (cellY - currentCellY) * step)
    end

    local function isCellInView(cell)
        return math.abs(cell.x - currentCellX) <= viewRadius and math.abs(cell.y - currentCellY) <= viewRadius
    end

    local function getCellEdgePosition(cell, direction)
        local x, y = toMinimapPosition(cell.x, cell.y)
        local half = config.cellSize / 2

        if direction == "north" then
            return x, y - half
        elseif direction == "south" then
            return x, y + half
        elseif direction == "west" then
            return x - half, y
        elseif direction == "east" then
            return x + half, y
        end

        return x, y
    end

    local function getPlayerPosition(room, playerIconSize)
        local minX, minY, maxX, maxY = getRoomMinimapBounds(room)
        local roomX, roomY = toMinimapPosition((minX + maxX) / 2, (minY + maxY) / 2)
        local roomSprite = getRoomSprite({
            minX = minX,
            minY = minY,
            maxX = maxX,
            maxY = maxY,
        }, room)
        local roomSpriteWidth = roomSprite:getWidth() * spriteScale
        local roomSpriteHeight = roomSprite:getHeight() * spriteScale
        local playerMapX, playerMapY = tilemap:worldToMap(player.x, player.y)
        local roomWidth = math.max(1, room.width or 32)
        local roomHeight = math.max(1, room.height or 32)
        local relativeX = clamp((playerMapX - 0.5) / roomWidth, 0, 1) - 0.5
        local relativeY = clamp((playerMapY - 0.5) / roomHeight, 0, 1) - 0.5
        local walkableScaleX = config.playerRoomPositionScaleX or config.playerRoomPositionScale or 0.6
        local walkableScaleY = config.playerRoomPositionScaleY or config.playerRoomPositionScale or 0.6
        local edgeOverflow = config.playerRoomEdgeOverflow or 1
        local playerX = roomX + relativeX * roomSpriteWidth * walkableScaleX + (config.playerIconOffsetX or 0)
        local playerY = roomY + relativeY * roomSpriteHeight * walkableScaleY + (config.playerIconOffsetY or 0)
        local minPlayerX = roomX - roomSpriteWidth / 2 + playerIconSize / 2 - edgeOverflow
        local maxPlayerX = roomX + roomSpriteWidth / 2 - playerIconSize / 2 + edgeOverflow
        local minPlayerY = roomY - roomSpriteHeight / 2 + playerIconSize / 2 - edgeOverflow
        local maxPlayerY = roomY + roomSpriteHeight / 2 - playerIconSize / 2 + edgeOverflow

        return clamp(playerX, minPlayerX, maxPlayerX),
            clamp(playerY, minPlayerY, maxPlayerY)
    end

    local drawnDoors = {}
    for roomId, room in pairs(rooms) do
        if knownRooms[roomId] then
            for direction, neighborId in pairs(room.neighbors or {}) do
                local neighbor = rooms[neighborId]
                if neighbor and knownRooms[neighborId] and roomId < neighborId then
                    local cellA, cellB = getConnectionCells(room, neighbor, direction)
                    if cellA and cellB and (isCellInView(cellA) or isCellInView(cellB)) then
                        local doorKey = roomId .. ":" .. neighborId .. ":" .. direction
                        if not drawnDoors[doorKey] then
                            drawnDoors[doorKey] = true
                            local ax, ay = getCellEdgePosition(cellA, direction)
                            local bx, by = getCellEdgePosition(cellB, oppositeDirections[direction])
                            local connectionSize = config.connectionIconSize
                                or (sprites.connection:getWidth() * spriteScale)
                            love.graphics.setColor(1, 1, 1, 1)
                            drawSprite(sprites.connection, (ax + bx) / 2, (ay + by) / 2, connectionSize, connectionSize)
                        end
                    end
                end
            end
        end
    end

    for roomId, room in pairs(rooms) do
        if knownRooms[roomId] then
            for _, rect in ipairs(getRoomMinimapRects(room)) do
                local inView = not (
                    rect.maxX < currentCellX - viewRadius or
                    rect.minX > currentCellX + viewRadius or
                    rect.maxY < currentCellY - viewRadius or
                    rect.minY > currentCellY + viewRadius
                )

                if inView then
                    local roomX, roomY = toMinimapPosition((rect.minX + rect.maxX) / 2, (rect.minY + rect.maxY) / 2)
                    local sprite = getRoomSprite(rect, room)
                    love.graphics.setColor(1, 1, 1, 1)
                    drawSprite(sprite, roomX, roomY, sprite:getWidth() * spriteScale, sprite:getHeight() * spriteScale)
                end
            end
        end
    end

    for roomId, room in pairs(rooms) do
        if knownRooms[roomId] and (shouldShowShopIcon(floorManager, room) or shouldShowCardIcon(floorManager, room)) then
            local minX, minY, maxX, maxY = getRoomMinimapBounds(room)
            local inView = not (
                maxX < currentCellX - viewRadius or
                minX > currentCellX + viewRadius or
                maxY < currentCellY - viewRadius or
                minY > currentCellY + viewRadius
            )

            if inView then
                local iconX, iconY = toMinimapPosition((minX + maxX) / 2, (minY + maxY) / 2)
                local size = config.shopIconSize or (sprites.store:getWidth() * spriteScale)
                love.graphics.setColor(1, 1, 1, 1)
                drawSprite(shouldShowCardIcon(floorManager, room) and sprites.cards or sprites.store, iconX, iconY, size, size)
            end
        end
    end

    local playerIconSize = config.playerIconSize or (sprites.player:getWidth() * spriteScale)
    local inTransition = game.playerRoomExitTransition ~= nil or game.playerRoomEntryMove ~= nil
    if game.minimapForcePlayerIconRefresh or not inTransition or not game.minimapPlayerIconX then
        game.minimapPlayerIconX, game.minimapPlayerIconY = getPlayerPosition(currentRoom, playerIconSize)
        game.minimapForcePlayerIconRefresh = false
    end

    love.graphics.setColor(1, 1, 1, 1)
    drawSprite(sprites.player, game.minimapPlayerIconX, game.minimapPlayerIconY, playerIconSize, playerIconSize)

    if previousScissorX then
        love.graphics.setScissor(previousScissorX, previousScissorY, previousScissorW, previousScissorH)
    else
        love.graphics.setScissor()
    end
    love.graphics.setLineStyle(previousLineStyle)
    love.graphics.setColor(1, 1, 1, 1)
end

return Minimap
