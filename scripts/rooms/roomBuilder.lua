local RoomBuilder = {}

local TILE_DOOR = 4
local TILE_DOOR_BACK = 9
local TILE_FLOOR = 0
local EXTENDED_BACK_TILE_COUNT = 3
local DOOR_FRONT_CLEAR_TILE_COUNT = 3

local function toMapPosition(position)
    local x = position and position.x and position.x + 1
    local y = position and position.y and position.y + 1
    return x, y
end

local function setTileAt(tilemap, x, y, tile)
    if not x or not y or not tilemap[y] or tilemap[y][x] == nil then
        return
    end

    tilemap[y][x] = tile
end

local function setTile(tilemap, position, tile)
    local x, y = toMapPosition(position)
    setTileAt(tilemap, x, y, tile)
end

local function addTransitionTile(transitions, x, y, direction)
    if x and y then
        transitions[#transitions + 1] = {
            x = x,
            y = y,
            direction = direction,
        }
    end
end

local function getStepDirection(slot)
    local door = slot.doorTiles and slot.doorTiles[1]
    local back = slot.backTiles and slot.backTiles[1]

    if not door or not back then
        return 0, 0
    end

    local dx = back.x - door.x
    local dy = back.y - door.y

    if dx ~= 0 then
        dx = dx > 0 and 1 or -1
    end

    if dy ~= 0 then
        dy = dy > 0 and 1 or -1
    end

    return dx, dy
end

local function extendBackTiles(tilemap, slot, transitions, direction)
    local dx, dy = getStepDirection(slot)
    if dx == 0 and dy == 0 then
        return
    end

    for _, position in ipairs(slot.backTiles or {}) do
        local x, y = toMapPosition(position)
        addTransitionTile(transitions, x, y, direction)
        for step = 1, EXTENDED_BACK_TILE_COUNT do
            local extendedX = x + dx * step
            local extendedY = y + dy * step
            setTileAt(tilemap, extendedX, extendedY, TILE_DOOR_BACK)
            addTransitionTile(transitions, extendedX, extendedY, direction)
        end
    end
end

local function clearDoorFrontTiles(tilemap, slot)
    local dx, dy = getStepDirection(slot)
    if dx == 0 and dy == 0 then
        return
    end

    local frontDx = -dx
    local frontDy = -dy
    for _, position in ipairs(slot.doorTiles or {}) do
        local x, y = toMapPosition(position)
        for step = 1, DOOR_FRONT_CLEAR_TILE_COUNT do
            setTileAt(tilemap, x + frontDx * step, y + frontDy * step, TILE_FLOOR)
        end
    end
end

local function applyDoorSlot(tilemap, slot, transitions, direction)
    for _, position in ipairs(slot.backTiles or {}) do
        setTile(tilemap, position, TILE_DOOR_BACK)
    end

    extendBackTiles(tilemap, slot, transitions, direction)
    clearDoorFrontTiles(tilemap, slot)

    for _, position in ipairs(slot.doorTiles or {}) do
        local x, y = toMapPosition(position)
        addTransitionTile(transitions, x, y, direction)
        setTile(tilemap, position, TILE_DOOR)
    end
end

local function resolveDoorSlot(room, direction)
    local slot = room.doorSlots and room.doorSlots[direction]
    local slotId = room.doorSlotIds and room.doorSlotIds[direction]

    if slot and slotId and slot[slotId] then
        return slot[slotId]
    end

    return slot
end

function RoomBuilder:getDoorSlot(room, direction)
    return resolveDoorSlot(room, direction)
end

function RoomBuilder:toMapPosition(position)
    return toMapPosition(position)
end

function RoomBuilder:applyDoors(tilemap, room)
    local transitions = {}

    if not tilemap or not room then
        return transitions
    end

    for direction, enabled in pairs(room.doors or {}) do
        local slot = resolveDoorSlot(room, direction)
        if enabled and slot then
            applyDoorSlot(tilemap, slot, transitions, direction)
        end
    end

    return transitions
end

function RoomBuilder:build(tilemap, room)
    return self:applyDoors(tilemap, room)
end

return RoomBuilder
