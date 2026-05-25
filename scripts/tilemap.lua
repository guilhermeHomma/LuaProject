local Tilemap = {}

local GameConfig = require("scripts/config/gameConfig")

local function getSystem()
    return GameConfig:getTilemapSystem()
end

function Tilemap:getTilemap()
    return getSystem():getTilemap()
end

function Tilemap:mapToWorld(x, y)
    return getSystem():mapToWorld(x, y)
end

function Tilemap:worldToMap(x, y)
    return getSystem():worldToMap(x, y)
end

function Tilemap:getNearbyTiles(worldX, worldY)
    return getSystem():getNearbyTiles(worldX, worldY)
end

function Tilemap:getRoomTransitionAt(worldX, worldY)
    local system = getSystem()
    if system.getRoomTransitionAt then
        return system:getRoomTransitionAt(worldX, worldY)
    end
    return nil
end

function Tilemap:hasTileClose(x, y, tileIndex)
    return getSystem():hasTileClose(x, y, tileIndex)
end

function Tilemap:load()
    return getSystem():load()
end

function Tilemap:update(dt)
    return getSystem():update(dt)
end

function Tilemap:keypressed(key)
    return getSystem():keypressed(key)
end

function Tilemap:setDoorOpen(direction, open, animate, options)
    local system = getSystem()
    if system.setDoorOpen then
        return system:setDoorOpen(direction, open, animate, options)
    end
end

function Tilemap:setAllRoomDoorsOpen(open, animate, options)
    local system = getSystem()
    if system.setAllRoomDoorsOpen then
        return system:setAllRoomDoorsOpen(open, animate, options)
    end
end

function Tilemap:getRandomSpawnPosition(reference, minDistance, avoidPoints)
    return getSystem():getRandomSpawnPosition(reference, minDistance, avoidPoints)
end

function Tilemap:getRandomReachableSpawnPosition(reference, minDistance, avoidPoints)
    local system = getSystem()
    if system.getRandomReachableSpawnPosition then
        return system:getRandomReachableSpawnPosition(reference, minDistance, avoidPoints)
    end

    return system:getRandomSpawnPosition(reference, minDistance, avoidPoints)
end

function Tilemap:getPathBetweenWorldPoints(startX, startY, endX, endY)
    local system = getSystem()
    if system.getPathBetweenWorldPoints then
        return system:getPathBetweenWorldPoints(startX, startY, endX, endY)
    end

    return nil
end

function Tilemap:__index(key)
    local system = getSystem()
    local value = system[key]
    if value ~= nil then
        return value
    end
    return rawget(Tilemap, key)
end

setmetatable(Tilemap, Tilemap)

return Tilemap
