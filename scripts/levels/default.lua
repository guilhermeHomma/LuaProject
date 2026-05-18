local DefaultLevel = {}

local tilemapSystem = require("scripts/tilemaps/defaultSystem")
local FloorManager = require("scripts/managers/floorManager")

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
        minBrightness = 0.65,
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
DefaultLevel.currentFloorIndex = 1
DefaultLevel.floorLevels = {
    {
        id = 1,
        name = "Floor 1",
        difficulty = 1,
        roomCount = {min = 10, max = 14},
        enemyDropMultiplier = 1,
        shopProducts = {
            { id = "squaregun", weight = 5 },
            { id = "longshot", weight = 4 },
        },
    },
    {
        id = 2,
        name = "Floor 2",
        difficulty = 2,
        roomCount = {min = 10, max = 14},
        enemyDropMultiplier = 1.2,
        shopProducts = {
            { id = "squaregun", weight = 10 },
            { id = "longshot", weight = 15 },
            { id = "cakegun", weight = 35 },
            { id = "shotgun", weight = 25 },
            { id = "raygun", weight = 3 },
        },
    },
}
DefaultLevel.roomEncounterConfig = {
    enabled = true,
    startRoom = false,
    difficulty = 1,
    spawnMinDistanceTiles = 4,
    templateOverrides = {
        basic_32x32 = {
            emptyChance = 0.20,
            countMultiplier = 0.75,
            enemyTypeWeights = {
                zombie = 8,
                babyZombie = 3,
                noHead = 1,
                bigZombie = 1,
            },
            maxPerWave = {
                noHead = 1,
            },
        },
        wide_48x32 = {
            countMultiplier = 1.25,
            countAdd = 1,
        },
        tall_32x48 = {
            countMultiplier = 1.25,
            countAdd = 1,
        },
        large_48x48 = {
            countMultiplier = 1.75,
            countAdd = 2,
            enemyTypeWeights = {
                zombie = 6,
                babyZombie = 4,
                noHead = 5,
                bigZombie = 3,
            },
        },
    },
    waves = {
        {
            count = {
                min = 2,
                max = 5,
                perDifficulty = 1,
            },
            enemyTypes = {
                { id = "zombie", weight = 7 },
                { id = "babyZombie", weight = 2 },
                { id = "noHead", weight = 5 },
            },
        },
        {
            count = {
                min = 2,
                max = 5,
                perDifficulty = 1,
            },
            enemyTypes = {
                { id = "zombie", weight = 5 },
                { id = "babyZombie", weight = 3 },
                { id = "noHead", weight = 4 },
                { id = "bigZombie", weight = 2, minDifficulty = 2 },
            },
        },
    },
}
DefaultLevel.window = {
    width = 1280,
    height = 720,
}
DefaultLevel.tilemapConfig = {
    mapImage = "assets/sprites/maps/maptest.png",
    centerOrigin = true,
}
DefaultLevel.objectSpawnChances = {
    box = 0.70,
    chest = 0.50,
}
DefaultLevel.objectSpawnChancesByTemplate = {
    basic_32x32 = {
        chest = 0.50,
    },
    wide_48x32 = {
        chest = 0.50,
    },
    tall_32x48 = {
        chest = 0.50,
    },
    large_48x48 = {
        chest = 0.60,
    },
}
DefaultLevel.floorConfig = {
    startRoomId = "0:0",
    generate = {
        enabled = true,
        roomCount = 8,
        startTemplateId = "start_32x32",
        shopRoomTemplateId = "store_32x32",
        templateIds = {
            "basic_32x32",
            "wide_48x32",
            "tall_32x48",
            "large_48x48",
        },
        templateWeights = {
            basic_32x32 = 1,
            wide_48x32 = 3,
            tall_32x48 = 3,
            large_48x48 = 3,
        },
        endRoomChance = 0.35,
        endTemplateWeights = {
            basic_32x32 = 5,
            wide_48x32 = 1,
            tall_32x48 = 1,
            large_48x48 = 1,
        },
        extraConnectionChance = 0.12,
    },
}
DefaultLevel.shopConfig = {
    enabled = true,
    ammoProductId = "full_bullets",
    ammoChance = 0.40,
    ammoPrice = 300,
    products = {
        { id = "squaregun", weight = 40 },
        { id = "longshot", weight = 25 },
        { id = "cakegun", weight = 20 },
        { id = "shotgun", weight = 15 },
        { id = "raygun", weight = 5 },
    },
}

DefaultLevel.cameraBounds = {
}

DefaultLevel.followCameraSize = {
    width = 1120,
    height = 630,
}

DefaultLevel.fixedCameraSize = {
    width = 1120,-- 960,
    height = 630, --540,
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

function DefaultLevel:applyFloorLevel(floorIndex)
    local floorLevel = getFloorLevel(self, floorIndex)
    if not floorLevel then
        return nil
    end

    self.currentFloorIndex = floorIndex or self.currentFloorIndex or 1

    if floorLevel.difficulty then
        self.roomEncounterConfig.difficulty = floorLevel.difficulty
    end

    local roomCount = resolveRangeValue(floorLevel.roomCount)
    if roomCount then
        self.floorConfig.generate.roomCount = roomCount
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
