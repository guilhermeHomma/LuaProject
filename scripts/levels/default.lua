local DefaultLevel = {}

local tilemapSystem = require("scripts/tilemaps/defaultSystem")
local FloorManager = require("scripts/managers/floorManager")
local RoomConfig = require("scripts/config/defaultRoomConfig")
local FloorEncounterConfig = require("scripts/config/floorEncounterConfig")

local function copyTable(source)
    if type(source) ~= "table" then
        return source
    end

    local result = {}
    for key, value in pairs(source) do
        result[key] = copyTable(value)
    end
    return result
end

local function mergeTables(base, overrides)
    local result = copyTable(base) or {}
    if type(overrides) ~= "table" then
        return result
    end

    for key, value in pairs(overrides) do
        if type(value) == "table" and type(result[key]) == "table" then
            result[key] = mergeTables(result[key], value)
        else
            result[key] = copyTable(value)
        end
    end

    return result
end

DefaultLevel.id = "default"
DefaultLevel.name = "map test"
DefaultLevel.baseWidth = 1280
DefaultLevel.baseHeight = 720
DefaultLevel.worldScaleX = 3
DefaultLevel.yScale = 2.4
DefaultLevel.enableWaves = false
DefaultLevel.enableTrails = false
DefaultLevel.lightConfig = {
    generalShadow = {
        minBrightness = 0.6,
        color = {0, 0, 0.7},
    },
}
DefaultLevel.renderDistances = {
    soft = 280,
    hard = 350,
    nearbyEnemy = 360,
    footstepCleanup = 250,
}
DefaultLevel.spawnMinDistance = 240
DefaultLevel.currentFloorIndex = RoomConfig.currentFloorIndex
DefaultLevel.floorLevels = copyTable(RoomConfig.floorLevels)
DefaultLevel.baseRoomEncounterConfig = mergeTables(FloorEncounterConfig.base, RoomConfig.roomEncounterConfig)
DefaultLevel.roomEncounterConfig = copyTable(DefaultLevel.baseRoomEncounterConfig)
DefaultLevel.window = {
    width = 1280,
    height = 720,
}
DefaultLevel.tilemapConfig = {
    mapImage = "assets/sprites/maps/maptest.png",
    centerOrigin = true,
}
DefaultLevel.objectSpawnChances = copyTable(RoomConfig.objectSpawnChances)
DefaultLevel.floorPathTiles = copyTable(RoomConfig.floorPathTiles)
DefaultLevel.wallVariantTiles = copyTable(RoomConfig.wallVariantTiles)
DefaultLevel.objectSpawnChancesByTemplate = copyTable(RoomConfig.objectSpawnChancesByTemplate)
DefaultLevel.floorConfig = copyTable(RoomConfig.floorConfig)
DefaultLevel.shopConfig = copyTable(RoomConfig.shopConfig)

DefaultLevel.cameraBounds = {
}

DefaultLevel.followCameraSize = {
    width = 1120,
    height = 630,
}

DefaultLevel.fixedCameraSize = {
    width =  1088,--1120,-- 960,
    height = 612--630, --540,
}

DefaultLevel.playerSpawn = {
    x = 0,
    y = 0,
}

DefaultLevel.cameraFocus = {
    x = 0,
    y = 40 / DefaultLevel.yScale,
}

local function getFloorLevel(level, floorIndex)
    local index = floorIndex or level.currentFloorIndex or 1
    return level.floorLevels and level.floorLevels[index] or nil
end

local function resolveRangeValue(value)
    if type(value) ~= "table" then
        return value
    end

    local minValue = value.min or value[1]
    local maxValue = value.max or value[2] or minValue
    if not minValue then
        return nil
    end

    minValue = math.floor(minValue)
    maxValue = math.floor(maxValue)
    if maxValue < minValue then
        minValue, maxValue = maxValue, minValue
    end

    return math.random(minValue, maxValue)
end

function DefaultLevel:applyFloorLevel(floorIndex)
    local floorLevel = getFloorLevel(self, floorIndex)
    if not floorLevel then
        return nil
    end

    self.currentFloorIndex = floorIndex or self.currentFloorIndex or 1
    local floorEncounter = FloorEncounterConfig.floors[self.currentFloorIndex] or {}
    self.roomEncounterConfig = mergeTables(self.baseRoomEncounterConfig, floorEncounter)
    self.roomEncounterConfig = mergeTables(self.roomEncounterConfig, floorLevel.roomEncounterConfig)

    if floorLevel.difficulty then
        self.roomEncounterConfig.difficulty = floorLevel.difficulty
    end

    local roomCount = resolveRangeValue(floorLevel.roomCount)
    if roomCount then
        self.floorConfig.generate.roomCount = roomCount
    end

    if floorLevel.cardRoomChance ~= nil then
        self.floorConfig.generate.cardRoomChance = floorLevel.cardRoomChance
    end

    if floorLevel.cardRoomCount then
        self.floorConfig.generate.cardRoomCount = copyTable(floorLevel.cardRoomCount)
    end

    if floorLevel.shopProducts then
        self.shopConfig.products = copyTable(floorLevel.shopProducts)
    end

    return floorLevel
end

local function templatePointToWorld(x, y)
    local Tilemap = require("scripts/tilemap")
    return Tilemap:mapToWorld(x + 1, y + 1)
end

local function clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

local function getAxisCenters(length, count)
    local centers = {}
    count = math.max(1, count or 1)

    if count == 1 then
        centers[1] = length / 2 - 0.5
        return centers
    end

    local firstCenter = 32 / 2 - 0.5
    local lastCenter = length - 32 / 2 - 0.5
    for index = 1, count do
        local t = (index - 1) / (count - 1)
        centers[#centers + 1] = firstCenter + (lastCenter - firstCenter) * t
    end

    return centers
end

local function getRoomCameraRange(room)
    local gridWidth = room and room.gridWidth or 1
    local gridHeight = room and room.gridHeight or 1
    local width = room and room.width or 32
    local height = room and room.height or 32
    local axisCentersX = getAxisCenters(width, gridWidth)
    local axisCentersY = getAxisCenters(height, gridHeight)
    local minCenterX = axisCentersX[1]
    local maxCenterX = axisCentersX[#axisCentersX]
    local minCenterY = axisCentersY[1]
    local maxCenterY = axisCentersY[#axisCentersY]

    local minWorldX = templatePointToWorld(minCenterX, height / 2)
    local maxWorldX = templatePointToWorld(maxCenterX, height / 2)
    local _, minWorldY = templatePointToWorld(width / 2, minCenterY)
    local _, maxWorldY = templatePointToWorld(width / 2, maxCenterY)

    return {
        minX = math.min(minWorldX, maxWorldX),
        maxX = math.max(minWorldX, maxWorldX),
        minY = math.min(minWorldY, maxWorldY),
        maxY = math.max(minWorldY, maxWorldY),
    }
end

function DefaultLevel:getCameraBounds()
    return self.cameraBounds
end

function DefaultLevel:setCameraBounds(bounds)
    for key, value in pairs(bounds) do
        self.cameraBounds[key] = value
    end
end

function DefaultLevel:resetRuntimeState()
    self.currentFloorIndex = RoomConfig.currentFloorIndex or 1
    self:applyFloorLevel(self.currentFloorIndex)
    self.cameraBounds = {}
    self.cameraAreas = {}
end

function DefaultLevel:getTilemapSystem()
    return tilemapSystem
end

function DefaultLevel:getPlayerSpawn()
    return self.playerSpawn.x, self.playerSpawn.y
end

function DefaultLevel:updateCamera(camera, target, dt)
    local currentRoom = FloorManager:getCurrentRoom()
    local focusX = self.cameraFocus.x
    local focusY = self.cameraFocus.y

    if currentRoom and (((currentRoom.gridWidth or 1) > 1) or ((currentRoom.gridHeight or 1) > 1)) then
        local range = getRoomCameraRange(currentRoom)
        if (currentRoom.gridWidth or 1) > 1 then
            focusX = clamp(target.x, range.minX, range.maxX)
        end
        if (currentRoom.gridHeight or 1) > 1 then
            focusY = clamp(target.y, range.minY, range.maxY)
        end
    end

    camera:setFixedMode(
        focusX,
        focusY,
        self.fixedCameraSize.width,
        self.fixedCameraSize.height,
        3.5
    )
end

function DefaultLevel:drawDebug()
    if not DEBUG then
        return
    end

    for _, area in ipairs(self.cameraAreas or {}) do
        if area.drawDebug then
            area:drawDebug()
        end
    end
end

DefaultLevel:applyFloorLevel(DefaultLevel.currentFloorIndex)

return DefaultLevel
