local Game = {}

Player = require "scripts/player/player"
Camera = require("scripts/camera")
Dialog = require("scripts/dialog/dialog")

local Ground = require("scripts/ground")
local WaveManager = require("scripts/managers/waves")
local Tutorial = require("scripts/managers/tutorial")
local Clouds = require("scripts/clouds")
local Tilemap = require("scripts/tilemap")
local PointsManager = require("scripts/managers/pointsManager")
local DoorsManager = require("scripts/managers/doorsManager")
local FloorManager = require("scripts/managers/floorManager")
local MinimapConfig = require("scripts/config/minimapConfig")
local LightConfig = require("scripts/config/lightConfig")
local HeartSound = require("scripts/player/heartSound")
local CreatorManager = require "scripts.managers.CreatorManager"
local Trail = require("scripts.objects.trails")
local Zombie = require("scripts/enemies/zombie")
local BabyZombie = require("scripts/enemies/babyZombie")
local BigZombie = require("scripts/enemies/bigZombie")
local NoHead = require("scripts/enemies/noHead")
local Scarecrow = require("scripts/enemies/scarecrow")
local CardChoice = require("scripts/managers/cardChoice")
local Hollow = require("scripts/objects/hollow")
local FloorIntroManager = require("scripts/managers/floorIntroManager")

local font = love.graphics.newFont("assets/fonts/ThaleahFat.ttf", 32)
local hudDistortionShader = love.graphics.newShader("scripts/shaders/hudWater.glsl")
local xraySoftShader = love.graphics.newShader("scripts/shaders/xraySoft.glsl")
local xrayStencilShader = love.graphics.newShader("scripts/shaders/xrayStencilAlpha.glsl")
local playerLightImage = love.graphics.newImage("assets/sprites/effects/light.png")
playerLightImage:setFilter("nearest", "nearest")
local vignetteShader = love.graphics.newShader("scripts/shaders/vignette.glsl")
local waveClearFeedbackSound = love.audio.newSource("assets/sfx/ambience/nextWave.mp3", "static")
local minimapSprites = {
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

for _, image in pairs(minimapSprites) do
    image:setFilter("nearest", "nearest")
end

local function sortDrawQueue(a, b)
    if a.priority == b.priority then
        local aSort = a.object and a.object.drawSortOrder or 0
        local bSort = b.object and b.object.drawSortOrder or 0
        return aSort < bSort
    end

    return a.priority < b.priority
end

camera = nil
local oppositeDirections = {
    north = "south",
    south = "north",
    west = "east",
    east = "west",
}

local function configurePersistedRoomDrop(drop, key, entry)
    drop.persistRoomDrop = true
    drop.neverExpires = true
    drop.requirePickupKey = true
    drop.pickupDistance = 24
    drop.roomDropKey = key
    drop.dropKind = entry.kind
    drop.pickupX = entry.pickupX
    drop.pickupY = entry.pickupY
    drop.drawBaseY = entry.drawBaseY
    drop.fromChest = entry.drawBaseY ~= nil
    drop.drawPriorityOffset = entry.drawPriorityOffset or 0.35
    if drop.fromChest and drop.drawPriorityOffset > 2 then
        drop.drawPriorityOffset = 0.35
    end
    drop.drawSortOrder = entry.drawSortOrder or 0
    drop.vx = 0
    drop.vy = 0
    return drop
end

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
local TILE_WORLD_SIZE = 16
local ENTRY_MOVE_DISTANCE = TILE_WORLD_SIZE * 1.5
local ENTRY_MOVE_DURATION = 0.24
local ENTRY_DOOR_CLOSE_WAIT = 0.18
local ENTRY_DOOR_CLOSE_SPEED = 28
local EXIT_RUN_DISTANCE = TILE_WORLD_SIZE * 3
local ROOM_FADE_OUT_DURATION = 0.6
local ROOM_FADE_IN_DURATION = 0.4
local EnemyFactories = {
    zombie = Zombie,
    babyZombie = BabyZombie,
    bigZombie = BigZombie,
    noHead = NoHead,
    scarecrow = Scarecrow,
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

local function getEncounterConfig()
    return CURRENT_LEVEL and CURRENT_LEVEL.roomEncounterConfig or nil
end

local function copyTable(source)
    if type(source) ~= "table" then
        return source
    end

    local result = {}
    for key, value in pairs(source) do
        if type(value) == "table" then
            result[key] = copyTable(value)
        else
            result[key] = value
        end
    end

    return result
end

local function mergeTables(base, overrides)
    local result = copyTable(base) or {}
    if not overrides then
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

local function getRoomEncounterOverride(config, room)
    local templateId = room and room.templateId
    local overrides = config and (config.templateOverrides or config.templateEncounters)
    return templateId and overrides and overrides[templateId] or nil
end

local function getRoomWaveConfig(config, waveConfig, room)
    local override = getRoomEncounterOverride(config, room)
    local result = copyTable(waveConfig) or {}

    if not override then
        return result
    end

    if override.waves then
        local waveIndex = room and room.state and room.state.encounterWaveIndex or 1
        result = mergeTables(result, override.waves[waveIndex] or override.waves[#override.waves])
    end

    if override.count then
        result.count = mergeTables(result.count or {}, override.count)
    end
    if override.enemyTypes then
        result.enemyTypes = copyTable(override.enemyTypes)
    end
    if override.enemyTypeWeights then
        result.enemyTypeWeights = mergeTables(result.enemyTypeWeights or {}, override.enemyTypeWeights)
    end
    if override.maxPerWave then
        result.maxPerWave = mergeTables(result.maxPerWave or {}, override.maxPerWave)
    end
    if override.countMultiplier then
        result.countMultiplier = (result.countMultiplier or 1) * override.countMultiplier
    end
    if override.countAdd then
        result.countAdd = (result.countAdd or 0) + override.countAdd
    end
    if config.enemyTypes then
        result.enemyTypes = copyTable(config.enemyTypes)
    end
    if config.maxPerWave then
        result.maxPerWave = mergeTables(result.maxPerWave or {}, config.maxPerWave)
    end

    return result
end

local function getRoomEncounterOverrideValue(config, room, key)
    local override = getRoomEncounterOverride(config, room)
    return override and override[key] or nil
end

local function resolveRangeValue(value, fallback)
    if type(value) ~= "table" then
        return value or fallback
    end

    local minValue = value.min or value[1] or fallback
    local maxValue = value.max or value[2] or minValue
    if not minValue then
        return fallback
    end

    minValue = math.floor(minValue)
    maxValue = math.floor(maxValue)
    if maxValue < minValue then
        minValue, maxValue = maxValue, minValue
    end

    return math.random(minValue, maxValue)
end

local function shouldSkipRoomEncounter(config, room)
    local state = room and room.state
    if not state then
        return false
    end

    if state.skipEncounter ~= nil then
        return state.skipEncounter == true
    end

    local chance = getRoomEncounterOverrideValue(config, room, "emptyChance") or 0
    state.skipEncounter = chance > 0 and math.random() < chance
    return state.skipEncounter == true
end

local function getEncounterDifficulty(config, room)
    local difficulty = math.max(1, config and config.difficulty or 1)
    local roomDistance = room and room.distanceFromStart or 0

    for _, rule in ipairs((config and config.distanceDifficulty) or {}) do
        if roomDistance >= (rule.minDistance or 0) then
            difficulty = math.max(difficulty, rule.difficulty or difficulty)
        end
    end

    return difficulty
end

local function getDistanceDifficultyRule(config, room)
    local roomDistance = room and room.distanceFromStart or 0
    local selected = nil

    for _, rule in ipairs((config and config.distanceDifficulty) or {}) do
        if roomDistance >= (rule.minDistance or 0)
            and (not selected or (rule.minDistance or 0) >= (selected.minDistance or 0)) then
            selected = rule
        end
    end

    return selected
end

local function getEncounterWaves(config)
    if config and config.waveTemplates and #config.waveTemplates > 0 then
        return config.waveTemplates
    end

    if config and config.waves and #config.waves > 0 then
        return config.waves
    end

    return {config or {}}
end

local function getRoomEncounterRangeValue(config, room, key, fallback)
    local overrideValue = getRoomEncounterOverrideValue(config, room, key)
    if overrideValue ~= nil then
        return resolveRangeValue(overrideValue, fallback)
    end

    local distanceRule = getDistanceDifficultyRule(config, room)
    if distanceRule and distanceRule[key] ~= nil then
        return resolveRangeValue(distanceRule[key], fallback)
    end

    return resolveRangeValue(config and config[key], fallback)
end

local function getRoomEncounterNumberValue(config, room, key, fallback)
    local overrideValue = getRoomEncounterOverrideValue(config, room, key)
    if overrideValue ~= nil then
        return overrideValue
    end

    local distanceRule = getDistanceDifficultyRule(config, room)
    if distanceRule and distanceRule[key] ~= nil then
        return distanceRule[key]
    end

    return config and config[key] or fallback
end

local function getRoomTotalWaves(config, room)
    return math.max(1, getRoomEncounterRangeValue(config, room, "totalWaves", #(getEncounterWaves(config))))
end

local function getRoomSimultaneousWaves(config, room)
    return math.max(1, getRoomEncounterRangeValue(config, room, "simultaneousWaves", 1))
end

local function getWaveChance(config, room, waveConfig)
    local waveId = waveConfig and waveConfig.id
    local override = getRoomEncounterOverride(config, room)
    local waveChances = override and override.waveChances
    local distanceRule = getDistanceDifficultyRule(config, room)
    local distanceWaveChances = distanceRule and distanceRule.waveChances

    if waveId and waveChances and waveChances[waveId] ~= nil then
        if distanceWaveChances and distanceWaveChances[waveId] ~= nil then
            return distanceWaveChances[waveId]
        end

        return waveChances[waveId]
    end

    if waveId and distanceWaveChances and distanceWaveChances[waveId] ~= nil then
        return distanceWaveChances[waveId]
    end

    return waveConfig and (waveConfig.chance or waveConfig.weight) or 1
end

local function chooseEncounterWave(config, room)
    local difficulty = getEncounterDifficulty(config, room)
    local waves = getEncounterWaves(config)
    local candidates = {}
    local totalChance = 0

    for _, waveConfig in ipairs(waves) do
        if difficulty >= (waveConfig.minDifficulty or 1) then
            local chance = getWaveChance(config, room, waveConfig)
            if chance and chance > 0 then
                candidates[#candidates + 1] = waveConfig
                totalChance = totalChance + chance
            end
        end
    end

    if totalChance <= 0 then
        return waves[1] or config or {}
    end

    local roll = math.random() * totalChance
    for _, waveConfig in ipairs(candidates) do
        roll = roll - getWaveChance(config, room, waveConfig)
        if roll <= 0 then
            return waveConfig
        end
    end

    return candidates[#candidates] or waves[1] or config or {}
end

local function getEncounterSpawnMinDistance(config)
    local tileDistance = (config and config.spawnMinDistanceTiles or 4) * TILE_WORLD_SIZE
    local worldDistance = config and config.spawnMinDistance or 0
    return math.max(TILE_WORLD_SIZE * 4, tileDistance, worldDistance)
end

local function getEncounterSpawnMinDistanceForWave(config, waveIndex)
    if waveIndex and waveIndex > 1 then
        return TILE_WORLD_SIZE * 3
    end

    return getEncounterSpawnMinDistance(config)
end

local function getEncounterSpawnAvoidPoints(config, waveIndex, spawnedPositions)
    local avoidPoints = {}
    local currentRoom = FloorManager:getCurrentRoom()
    local state = currentRoom and currentRoom.state
    local entryPoint = state and state.entryDoorAvoidPoint

    if waveIndex == 1 and entryPoint then
        avoidPoints[#avoidPoints + 1] = {
            x = entryPoint.x,
            y = entryPoint.y,
            radius = TILE_WORLD_SIZE * (config and config.spawnEntryAvoidDistanceTiles or 4),
        }
    end

    for _, enemy in ipairs(Game and Game.enemies or {}) do
        if enemy.isAlive ~= false and enemy.x and enemy.y then
            avoidPoints[#avoidPoints + 1] = {
                x = enemy.x,
                y = enemy.y,
                radius = TILE_WORLD_SIZE * 3,
            }
        end
    end

    for _, position in ipairs(spawnedPositions or {}) do
        avoidPoints[#avoidPoints + 1] = {
            x = position.x,
            y = position.y,
            radius = TILE_WORLD_SIZE * 3,
        }
    end

    return avoidPoints
end

local function getEncounterEnemyCount(config, waveConfig)
    local countConfig = waveConfig.count or config.count or {}
    local currentRoom = FloorManager:getCurrentRoom()
    local difficulty = getEncounterDifficulty(config, currentRoom)
    local perDifficulty = countConfig.perDifficulty or 0
    local bonus = math.max(0, difficulty - 1) * perDifficulty
    local minCount = (countConfig.min or 1) + bonus
    local maxCount = (countConfig.max or minCount) + bonus
    local roomMultiplier = getRoomEncounterNumberValue(config, currentRoom, "countMultiplier", 1) or 1
    local roomAdd = getRoomEncounterNumberValue(config, currentRoom, "countAdd", 0) or 0
    local multiplier = (waveConfig.countMultiplier or 1) * roomMultiplier
    local add = (waveConfig.countAdd or 0) + roomAdd

    minCount = math.max(1, math.floor(minCount * multiplier + add + 0.5))
    maxCount = math.max(minCount, math.floor(maxCount * multiplier + add + 0.5))

    return math.random(minCount, maxCount)
end

local function chooseEnemyType(config, waveConfig, spawnedCounts)
    local difficulty = getEncounterDifficulty(config, FloorManager:getCurrentRoom())
    local enemyTypes = waveConfig.enemyTypes or config.enemyTypes or {}
    local enemyTypeWeights = waveConfig.enemyTypeWeights or {}
    local maxPerWave = waveConfig.maxPerWave or {}
    local totalWeight = 0

    for _, enemyConfig in ipairs(enemyTypes) do
        if difficulty >= (enemyConfig.minDifficulty or 1) then
            local enemyId = enemyConfig.id
            local underLimit = not maxPerWave[enemyId] or ((spawnedCounts and spawnedCounts[enemyId]) or 0) < maxPerWave[enemyId]
            local weight = enemyTypeWeights[enemyId] or enemyConfig.weight or 1
            if underLimit and weight > 0 then
                totalWeight = totalWeight + weight
            end
        end
    end

    if totalWeight <= 0 then
        return "zombie"
    end

    local roll = math.random() * totalWeight
    for _, enemyConfig in ipairs(enemyTypes) do
        if difficulty >= (enemyConfig.minDifficulty or 1) then
            local enemyId = enemyConfig.id
            local underLimit = not maxPerWave[enemyId] or ((spawnedCounts and spawnedCounts[enemyId]) or 0) < maxPerWave[enemyId]
            local weight = enemyTypeWeights[enemyId] or enemyConfig.weight or 1
            if underLimit and weight > 0 then
                roll = roll - weight
                if roll <= 0 then
                    return enemyId
                end
            end
        end
    end

    return "zombie"
end

local earlyCombatRoomWaves = {
    {
        { id = "early_room_1", enemies = {"zombie"} },
    },
    {
        { id = "early_room_2_wave_1", enemies = {"zombie", "zombie"} },
        { id = "early_room_2_wave_2", enemies = {"zombie", "babyZombie"} },
    },
}

local function isFirstFloorActive()
    local level = FloorManager and FloorManager.level
    local floorIndex = level and level.currentFloorIndex or 1
    return floorIndex == 1
end

local function getEarlyCombatRoomWave(room, waveIndex)
    if not isFirstFloorActive() then
        return nil
    end

    local order = room and room.state and room.state.playerCombatRoomOrder
    local waves = order and earlyCombatRoomWaves[order]
    return waves and waves[waveIndex] or nil
end

local function getEarlyCombatRoomWaveCount(room)
    if not isFirstFloorActive() then
        return nil
    end

    local order = room and room.state and room.state.playerCombatRoomOrder
    local waves = order and earlyCombatRoomWaves[order]
    return waves and #waves or nil
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

local function isRoomKnown(room, rooms)
    return room.state and room.state.discovered == true
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

local function getMinimapConnectionCells(roomA, roomB, direction)
    local cellA, cellB = findAdjacentCells(roomA, roomB, direction)
    cellA = getRoomEdgeCell(roomA, direction) or cellA
    cellB = getRoomEdgeCell(roomB, getOppositeDirection(direction)) or cellB
    if roomA.state and not roomA.state.visited and roomA.state.minimapPreviewCell then
        cellA = roomA.state.minimapPreviewCell
    end
    if roomB.state and not roomB.state.visited and roomB.state.minimapPreviewCell then
        cellB = roomB.state.minimapPreviewCell
    end

    return cellA, cellB
end

local function pixel(value)
    return math.floor(value + 0.5)
end

local function isStartRoom(room)
    local level = FloorManager.level
    local startRoomId = level and level.floorConfig and level.floorConfig.startRoomId or "0:0"
    return room and room.id == startRoomId
end

local function setBattleMusicActive(active)
    if Music and Music.setBattleActive then
        Music:setBattleActive(active == true)
    end
end

local function playWaveClearFeedback()
    waveClearFeedbackSound:stop()
    waveClearFeedbackSound:setVolume(0.35 * (SOUND_VOLUME or 1))
    waveClearFeedbackSound:setPitch((1.08 + math.random() * 0.12) * GAME_PITCH)
    waveClearFeedbackSound:play()
end

local function shouldShowShopIcon(room)
    local state = room and room.state
    return state
        and state.visited == true
        and state.shopProduct ~= nil
        and not isStartRoom(room)
        and not room.isCardRoom
end

local function shouldShowCardIcon(room)
    local state = room and room.state
    return room
        and room.isCardRoom
        and state
        and state.visited == true
        and not isStartRoom(room)
end

local function getMinimapRoomSprite(rect, room)
    if room and room.state and not room.state.visited then
        return minimapSprites.unknown
    end

    local widthCells = rect.maxX - rect.minX + 1
    local heightCells = rect.maxY - rect.minY + 1

    if widthCells == 2 and heightCells == 2 then
        return minimapSprites.room48x48
    elseif widthCells == 2 then
        return minimapSprites.room48x32
    elseif heightCells == 2 then
        return minimapSprites.room32x48
    end

    return minimapSprites.room32x32
end

local function drawMinimapSprite(image, centerX, centerY, width, height)
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

local function getLightCalculationDistance(config)
    if config.calculationDistance then
        return config.calculationDistance
    end

    local spriteBrightness = config.spriteBrightness or {}
    local groundLight = config.groundLight or {}
    return math.max(spriteBrightness.maxDistance or 0, groundLight.outerRadius or 0)
end

local function isLightNearPlayer(config, x, y)
    if not (Player and Player.x and Player.y) then
        return true
    end

    local maxDistance = getLightCalculationDistance(config)
    if maxDistance <= 0 then
        return true
    end

    local dx = x - Player.x
    local dy = y - Player.y
    return dx * dx + dy * dy <= maxDistance * maxDistance
end

local function isGroundLightNearCamera(config, x, y)
    local groundLight = config and config.groundLight
    if not (camera and groundLight and groundLight.enabled ~= false) then
        return false
    end

    local radius = groundLight.outerRadius or 0
    local screenX = (x * WORLD_SCALE_X - camera.x) * camera.zoomX
    local screenY = (y * YSCALE - camera.y) * camera.zoomY

    return screenX >= -radius
        and screenX <= baseWidth + radius
        and screenY >= -radius
        and screenY <= baseHeight + radius
end

local function getGeneralShadow()
    return LightConfig:getGeneralShadow()
end

local function getPlayerLightBrightness(object, sources)
    local generalShadow = getGeneralShadow()
    local minBrightness = generalShadow.minBrightness or 1
    local brightness = minBrightness
    sources = sources or (Game and Game.getLightSources and Game:getLightSources()) or {}
    local objectX = object and (object.xWorld or object.x)
    local objectY = object and (object.yWorld or object.y)

    if not (objectX and objectY) then
        return brightness
    end

    for _, source in ipairs(sources) do
        local spriteBrightness = source.config and source.config.spriteBrightness
        if spriteBrightness and spriteBrightness.enabled ~= false then
            local minDist = spriteBrightness.minDistance or 35
            local maxDist = spriteBrightness.maxDistance or 230
            local maxBrightness = spriteBrightness.maxBrightness or 1
            local dx = (source.x or 0) - objectX
            local dy = (source.y or 0) - objectY
            local maxDistSq = maxDist * maxDist

            if dx * dx + dy * dy <= maxDistSq then
                local d = math.sqrt(dx * dx + dy * dy)
                local range = math.max(1, maxDist - minDist)
                local t = math.min(math.max((d - minDist) / range, 0), 1)
                local sourceBrightness = maxBrightness + (minBrightness - maxBrightness) * t
                sourceBrightness = math.min(math.max(sourceBrightness * (source.flicker or 1), minBrightness), maxBrightness)
                brightness = math.max(brightness, sourceBrightness)
            end
        end
    end

    return brightness
end

local function getShadowTint(brightness)
    local color = getGeneralShadow().color or {0, 0, 0}
    brightness = math.min(math.max(brightness or 1, 0), 1)

    return
        (color[1] or 0) * (1 - brightness) + brightness,
        (color[2] or 0) * (1 - brightness) + brightness,
        (color[3] or 0) * (1 - brightness) + brightness
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

function Game:load(options)
    options = options or {}
    ACTIVE_LIGHT_MANAGER = self
    setBattleMusicActive(false)
    math.randomseed(os.time())
    love.graphics.setDefaultFilter("nearest", "nearest")
    CardChoice:load()

    FloorManager:load(CURRENT_LEVEL)
    Tilemap:load()

    local spawnX, spawnY = getStartRoomPlayerSpawn()
    Player:load(camera, spawnX, spawnY)
    camera = Camera:new(Player.x - 5, Player.y - 30, Player)
    camera:snapToCurrentMode()

    self.fogShader = love.graphics.newShader("scripts/shaders/fog.glsl")
    self.fogTime = 0
    self.spot = {
        radius = 1,
        feather = 3,
        target = 60,
        speed = 160,
        speedIncrease = 1000,
        enabled = true,
    }

    Tutorial:load()
    if not (CURRENT_LEVEL and CURRENT_LEVEL.enableTrails == false) then
        Trail:load()
    end
    Ground:load()
    WaveManager:load()
    Clouds:load(Player)
    DoorsManager:load()
    PointsManager:load()
    HeartSound:load()
    Dialog:load()

    local cursorImage = love.image.newImageData("assets/sprites/cursor.png")
    local cursor = love.mouse.newCursor(cursorImage, 8, 8)
    love.mouse.setCursor(cursor)

    self:resetRuntimeState()
    self:setupCurrentRoom()
    self:restoreCurrentRoomDrops()
    if options.startFloorIntro ~= false then
        self:startFloorIntro(CURRENT_LEVEL and CURRENT_LEVEL.currentFloorIndex or 1, options.onFloorIntroComplete)
    end
end

function Game:resetRuntimeState()
    self.sPSoundPlayed = false
    self.sPSoundPlayedOutro = false
    self.enemies = {}
    self.drawQueue = {}
    self.lightSources = {}
    self.weaponShockwaves = {}
    self.footsteps = {}
    self.particles = {}
    self.objects = {}
    self.purchasedWeapons = {}
    self.nearbyEnemies = {}
    self.crowTimer = math.random(20, 50)
    self.cricketTimer = math.random(30, 40)
    self.drawtext = "init text\ninit text\nyou shouldnt see this"
    self.textAlpha = 0
    self.textAlphaTarget = 0
    self.bottomMessageText = nil
    self.bottomMessageTimer = 0
    self.timer = 0
    self.roomTransitionCooldown = 0
    self.playerRoomEntryMove = nil
    self.playerRoomExitTransition = nil
    self.currentEntryDoorAvoidPoint = nil
    self.playerCombatRoomsEntered = 0
    self.roomFadeAlpha = 0
    self.floorChanging = false
    Dialog.breakMovements = false
end

function Game:restoreCurrentRoomDrops()
    local state = FloorManager:getCurrentRoomState()
    if not (state and state.drops) then
        return
    end

    local Coin = require("scripts/drops/coin")
    local Life = require("scripts/drops/life")
    local Bullets = require("scripts/drops/bullets")

    for key, entry in pairs(state.drops) do
        if not entry.collected then
            local drop
            if entry.kind == "life" then
                drop = Life:new(entry.x, entry.y)
            elseif entry.kind == "bullets" then
                drop = Bullets:new(entry.x, entry.y)
            else
                drop = Coin:new(entry.x, entry.y)
            end
            table.insert(self.objects, configurePersistedRoomDrop(drop, key, entry))
        end
    end
end

function Game:markWeaponPurchased(weaponName)
    if not weaponName then
        return
    end

    self.purchasedWeapons = self.purchasedWeapons or {}
    self.purchasedWeapons[weaponName] = true
end

function Game:hasPurchasedWeapon(weaponName)
    return self.purchasedWeapons and self.purchasedWeapons[weaponName] == true
end

function Game:canOpenCurrentRoomDoors(showMessage)
    return true
end

function Game:canLeaveCurrentRoom()
    return self:canOpenCurrentRoomDoors(true)
end

local function getCentralStartRoomScarecrowSpawn()
    local map = Tilemap:getTilemap()
    if not (map and #map > 0) then
        return nil, nil
    end

    local mapHeight = #map
    local mapWidth = #(map[1] or {})
    local edgeMargin = 6
    local minDistance = TILE_WORLD_SIZE * 3
    local centerMinX = math.max(edgeMargin + 1, math.floor(mapWidth * 0.35))
    local centerMaxX = math.min(mapWidth - edgeMargin, math.ceil(mapWidth * 0.65))
    local centerMinY = math.max(edgeMargin + 1, math.floor(mapHeight * 0.35))
    local centerMaxY = math.min(mapHeight - edgeMargin, math.ceil(mapHeight * 0.65))
    local candidates = {}
    local fallbackCandidate = nil

    local function hasClearNeighborRing(x, y)
        for checkY = y - 1, y + 1 do
            for checkX = x - 1, x + 1 do
                if not (map[checkY] and map[checkY][checkX] == 0) then
                    return false
                end
            end
        end

        return true
    end

    for y = centerMinY, centerMaxY do
        for x = centerMinX, centerMaxX do
            if map[y] and map[y][x] == 0 and hasClearNeighborRing(x, y) then
                local worldX, worldY = Tilemap:mapToWorld(x, y)
                local candidate = { x = worldX, y = worldY - 8 }
                if distance(candidate, Player) >= minDistance then
                    fallbackCandidate = fallbackCandidate or candidate
                    candidates[#candidates + 1] = candidate
                end
            end
        end
    end

    while #candidates > 0 do
        local index = math.random(1, #candidates)
        local candidate = table.remove(candidates, index)
        local path = Tilemap:getPathBetweenWorldPoints(candidate.x, candidate.y, Player.x, Player.y)
        if path and #path > 1 then
            return candidate.x, candidate.y
        end
    end

    if fallbackCandidate then
        return fallbackCandidate.x, fallbackCandidate.y
    end

    return nil, nil
end

function Game:spawnStartRoomScarecrow(currentRoom)
    local state = currentRoom and currentRoom.state
    if not state or state.scarecrowDestroyed or not isFirstFloorActive() then
        return false
    end

    if not state.scarecrowPosition then
        local x, y = getCentralStartRoomScarecrowSpawn()
        if not x or not y then
            return false
        end

        state.scarecrowPosition = { x = x, y = y }
    end

    local position = state.scarecrowPosition
    self.enemies[#self.enemies + 1] = Scarecrow:new(position.x, position.y)
    state.startRoomScarecrowEncounter = true
    state.encounterSpawned = true
    state.encounterCompleted = false
    return true
end

function Game:spawnEndRoomHollow(currentRoom)
    if not (currentRoom and currentRoom.isEndRoom) then
        return
    end

    local map = Tilemap:getTilemap()
    local centerX = map and #(map[1] or {}) / 2 or 16
    local centerY = map and #map / 2 or 16
    local worldX, worldY = Tilemap:mapToWorld(centerX + 0.5, centerY + 0.5)
    self.objects[#self.objects + 1] = Hollow:new(worldX, worldY)
end

function Game:setupCurrentRoom(options)
    options = options or {}
    self.enemies = {}
    self.nearbyEnemies = {}

    local currentRoom = FloorManager:getCurrentRoom()
    local state = currentRoom and currentRoom.state
    if not state then
        return
    end

    state.visited = true
    state.discovered = true
    revealRoomConnections(currentRoom)
    if not options.keepEntryDoorOpen then
        Tilemap:setAllRoomDoorsOpen(false)
    end

    if currentRoom.templateId == "start_32x32" or isStartRoom(currentRoom) then
        setBattleMusicActive(false)
        self.enemies = {}
        self.nearbyEnemies = {}
        state.skipEncounter = true
        state.activeEncounterWaves = {}
        state.encounterSpawnedWaves = 0

        if self:spawnStartRoomScarecrow(currentRoom) then
            state.cleared = false
            return
        end

        state.cleared = true
        state.encounterSpawned = false
        state.encounterCompleted = true
        return
    end

    if currentRoom.isShopRoom or currentRoom.isCardRoom then
        setBattleMusicActive(false)
        state.cleared = true
        state.skipEncounter = true
        state.encounterSpawned = false
        state.encounterCompleted = true
        return
    end

    if currentRoom.isEndRoom then
        setBattleMusicActive(false)
        state.cleared = true
        state.skipEncounter = true
        state.encounterSpawned = false
        state.encounterCompleted = true
        self.enemies = {}
        self.nearbyEnemies = {}
        self:spawnEndRoomHollow(currentRoom)
        return
    end

    if isFirstFloorActive() and not state.playerCombatRoomOrder then
        self.playerCombatRoomsEntered = (self.playerCombatRoomsEntered or 0) + 1
        state.playerCombatRoomOrder = self.playerCombatRoomsEntered
    end

    local encounterConfig = getEncounterConfig()
    if not (encounterConfig and encounterConfig.enabled) or state.cleared then
        setBattleMusicActive(false)
        return
    end

    local earlyWaveCount = getEarlyCombatRoomWaveCount(currentRoom)
    if not earlyWaveCount and shouldSkipRoomEncounter(encounterConfig, currentRoom) then
        setBattleMusicActive(false)
        state.cleared = true
        state.encounterCompleted = true
        return
    end

    state.encounterTotalWaves = state.encounterTotalWaves
        or earlyWaveCount
        or getRoomTotalWaves(encounterConfig, currentRoom)
    state.encounterSimultaneousWaves = state.encounterSimultaneousWaves
        or (earlyWaveCount and 1)
        or getRoomSimultaneousWaves(encounterConfig, currentRoom)
    state.encounterSpawnedWaves = state.encounterSpawnedWaves or 0
    state.activeEncounterWaves = state.activeEncounterWaves or {}
    self:spawnEncounterWavesUntilFull(currentRoom, encounterConfig)
    self:updateBattleMusicForCurrentRoom()
end

function Game:spawnCurrentRoomWave(currentRoom, encounterConfig)
    local state = currentRoom and currentRoom.state
    if not state or currentRoom.isShopRoom or currentRoom.isCardRoom or currentRoom.isEndRoom then
        return
    end
    if currentRoom.templateId == "start_32x32" or isStartRoom(currentRoom) then
        return false
    end

    state.encounterTotalWaves = state.encounterTotalWaves
        or getEarlyCombatRoomWaveCount(currentRoom)
        or getRoomTotalWaves(encounterConfig, currentRoom)
    state.encounterSpawnedWaves = state.encounterSpawnedWaves or 0
    if state.encounterSpawnedWaves >= state.encounterTotalWaves then
        return false
    end

    local waveIndex = state.encounterSpawnedWaves + 1
    state.encounterWaveIndex = waveIndex
    local fixedWave = getEarlyCombatRoomWave(currentRoom, waveIndex)
    local waveConfig = fixedWave or getRoomWaveConfig(encounterConfig, chooseEncounterWave(encounterConfig, currentRoom), currentRoom)
    local enemyCount = fixedWave and #fixedWave.enemies or getEncounterEnemyCount(encounterConfig, waveConfig)
    local spawnMinDistance = getEncounterSpawnMinDistanceForWave(encounterConfig, waveIndex)
    local spawnedPositions = {}
    local spawnedCounts = {}
    local waveId = (state.encounterWaveSerial or 0) + 1
    local spawnedAny = false

    state.encounterWaveSerial = waveId
    state.encounterSpawnedWaves = waveIndex
    state.activeEncounterWaves = state.activeEncounterWaves or {}
    state.activeEncounterWaves[waveId] = true

    state.encounterSpawned = true
    for spawnIndex = 1, enemyCount do
        local enemyId = fixedWave and fixedWave.enemies[spawnIndex] or chooseEnemyType(encounterConfig, waveConfig, spawnedCounts)
        local factory = EnemyFactories[enemyId] or EnemyFactories.zombie
        local spawnAvoidPoints = getEncounterSpawnAvoidPoints(encounterConfig, waveIndex, spawnedPositions)
        local x, y = Tilemap:getRandomReachableSpawnPosition(Player, spawnMinDistance, spawnAvoidPoints)

        if x and y then
            local enemy = factory:new(x, y)
            enemy.encounterWaveId = waveId
            self.enemies[#self.enemies + 1] = enemy
            spawnedPositions[#spawnedPositions + 1] = { x = x, y = y }
            spawnedCounts[enemyId] = (spawnedCounts[enemyId] or 0) + 1
            spawnedAny = true
        end
    end

    if not spawnedAny then
        state.activeEncounterWaves[waveId] = nil
        return false
    end

    Game.drawtext = "Wave " .. waveIndex
    Game.textAlphaTarget = 1
    return true
end

local function getActiveEncounterWaveCount(state)
    local count = 0
    for _, active in pairs(state and state.activeEncounterWaves or {}) do
        if active then
            count = count + 1
        end
    end
    return count
end

function Game:updateBattleMusicForCurrentRoom()
    local currentRoom = FloorManager:getCurrentRoom()
    local roomState = currentRoom and currentRoom.state
    local battleActive = false

    if roomState
        and roomState.encounterSpawned == true
        and roomState.cleared ~= true
        and not (currentRoom.templateId == "start_32x32" or isStartRoom(currentRoom))
        and not currentRoom.isShopRoom
        and not currentRoom.isCardRoom
        and not currentRoom.isEndRoom then
        battleActive = #self.enemies > 0
            or getActiveEncounterWaveCount(roomState) > 0
            or (roomState.encounterSpawnedWaves or 0) < (roomState.encounterTotalWaves or 0)
    end

    setBattleMusicActive(battleActive)
end

function Game:spawnEncounterWavesUntilFull(currentRoom, encounterConfig)
    local state = currentRoom and currentRoom.state
    if not state then
        return
    end
    if currentRoom.templateId == "start_32x32" or isStartRoom(currentRoom) or currentRoom.isEndRoom then
        return
    end

    state.encounterSimultaneousWaves = state.encounterSimultaneousWaves
        or (getEarlyCombatRoomWaveCount(currentRoom) and 1)
        or getRoomSimultaneousWaves(encounterConfig, currentRoom)

    while getActiveEncounterWaveCount(state) < state.encounterSimultaneousWaves do
        if not self:spawnCurrentRoomWave(currentRoom, encounterConfig) then
            break
        end
    end
end

function Game:checkCurrentRoomClear()
    local currentRoom = FloorManager:getCurrentRoom()
    local state = currentRoom and currentRoom.state
    if not state or state.cleared or not state.encounterSpawned then
        return
    end

    if currentRoom.templateId == "start_32x32" or isStartRoom(currentRoom) then
        state.activeEncounterWaves = {}
        state.encounterSpawnedWaves = 0

        for index = #(self.enemies or {}), 1, -1 do
            local enemy = self.enemies[index]
            if getmetatable(enemy) ~= Scarecrow then
                table.remove(self.enemies, index)
            end
        end

        if #self.enemies == 0 then
            state.cleared = true
            state.encounterCompleted = true
        end
        return
    end

    if state.startRoomScarecrowEncounter and #self.enemies == 0 then
        state.cleared = true
        state.encounterCompleted = true
        Game.drawtext = "Room cleared"
        Game.textAlphaTarget = 1
        return
    end

    local encounterConfig = getEncounterConfig()
    local activeWaves = state.activeEncounterWaves or {}
    for waveId, active in pairs(activeWaves) do
        if active then
            local hasAliveEnemy = false
            for _, enemy in ipairs(self.enemies or {}) do
                if enemy.isAlive ~= false and enemy.encounterWaveId == waveId then
                    hasAliveEnemy = true
                    break
                end
            end

            if not hasAliveEnemy then
                activeWaves[waveId] = nil
            end
        end
    end

    if encounterConfig then
        self:spawnEncounterWavesUntilFull(currentRoom, encounterConfig)
    end

    if #self.enemies == 0 and getActiveEncounterWaveCount(state) == 0 then
        state.cleared = true
        state.encounterCompleted = true
        setBattleMusicActive(false)
        playWaveClearFeedback()
        Game.drawtext = "Room cleared"
        Game.textAlphaTarget = 1
    end
end

function Game:startEntryMove(entryDirection)
    local vector = entryMoveVectors[entryDirection] or {x = 0, y = 0}
    local targetX, targetY = getEntryMoveTarget(entryDirection, Player.x, Player.y)
    self.playerRoomEntryMove = {
        phase = "move",
        timer = 0,
        duration = ENTRY_MOVE_DURATION,
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
    Dialog.breakMovements = true
end

function Game:updateEntryMove(dt)
    local move = self.playerRoomEntryMove
    if not move then
        return false
    end

    if move.phase == "closing" then
        move.closeWaitTimer = math.max(0, (move.closeWaitTimer or ENTRY_DOOR_CLOSE_WAIT) - dt)
        Player.velocityX = 0
        Player.velocityY = 0
        Player.moveX = 0
        Player.moveY = 0
        Player:updateAnimation(dt, true)
        Player.gun:update(dt, Player.x, Player.y)
        addToDrawQueue(Player.y + 6, Player)

        if move.closeWaitTimer == 0 then
            self.playerRoomEntryMove = nil
            Dialog.breakMovements = false
        end

        return true
    end

    move.timer = math.min(move.duration, move.timer + dt)
    local t = move.timer / move.duration
    local eased = 1 - (1 - t) * (1 - t)

    Player.x = move.startX + (move.targetX - move.startX) * eased
    Player.y = move.startY + (move.targetY - move.startY) * eased
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
        Tilemap:setAllRoomDoorsOpen(false, true, { frameSpeed = ENTRY_DOOR_CLOSE_SPEED })
    end

    return true
end

function Game:loadRoomFromDirection(direction)
    local currentRoom = FloorManager:getCurrentRoom()
    local targetRoomId = currentRoom and currentRoom.neighbors and currentRoom.neighbors[direction]

    if not targetRoomId then
        return false
    end

    local entryDirection = oppositeDirections[direction]
    if not FloorManager:enterRoom(targetRoomId) then
        return false
    end

    self.objects = {}
    for index = #(self.particles or {}), 1, -1 do
        local particleType = self.particles[index].particleType
        if particleType == "boxParticle" or particleType == "bloodDecal" or particleType == "leafParticle" then
            table.remove(self.particles, index)
        end
    end

    Tilemap:load()
    Tilemap:setDoorOpen(entryDirection, true)
    local spawnX, spawnY = getEntrySpawn(entryDirection)
    Player.x = spawnX
    Player.y = spawnY
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

    self.roomTransitionCooldown = 0.45
    self:startEntryMove(entryDirection)
    self:setupCurrentRoom({ keepEntryDoorOpen = true })
    self:restoreCurrentRoomDrops()
    return true
end

function Game:startRoomExitTransition(direction)
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

    local vector = getWorldDirectionVector(direction)
    self.playerRoomExitTransition = {
        phase = "fadeOut",
        direction = direction,
        timer = 0,
        duration = ROOM_FADE_OUT_DURATION,
        vectorX = vector.x,
        vectorY = vector.y,
        startX = Player.x,
        startY = Player.y,
        targetX = Player.x + vector.x * EXIT_RUN_DISTANCE,
        targetY = Player.y + vector.y * EXIT_RUN_DISTANCE,
    }
    Player.moveX = vector.x
    Player.moveY = vector.y
    Dialog.breakMovements = true
    return true
end

function Game:updateRoomExitTransition(dt)
    local transition = self.playerRoomExitTransition
    if not transition then
        return false
    end

    if transition.phase == "fadeOut" then
        transition.timer = math.min(transition.duration, transition.timer + dt)
        self.roomFadeAlpha = transition.timer / transition.duration
        local t = transition.timer / transition.duration
        local eased = t * t * (3 - 2 * t)
        Player.x = transition.startX + (transition.targetX - transition.startX) * eased
        Player.y = transition.startY + (transition.targetY - transition.startY) * eased
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
            self.roomFadeAlpha = 1
            self:loadRoomFromDirection(direction)
            self.playerRoomExitTransition = {
                phase = "fadeIn",
                timer = 0,
                duration = ROOM_FADE_IN_DURATION,
            }
        end
    elseif transition.phase == "fadeIn" then
        transition.timer = math.min(transition.duration, transition.timer + dt)
        self.roomFadeAlpha = 1 - transition.timer / transition.duration
        if self.playerRoomEntryMove then
            self:updateEntryMove(dt)
        end

        if transition.timer >= transition.duration then
            self.roomFadeAlpha = 0
            self.playerRoomExitTransition = nil
            Dialog.breakMovements = self.playerRoomEntryMove ~= nil
        end
    end

    return true
end

function Game:enterRoomFrom(direction)
    return self:startRoomExitTransition(direction)
end

function Game:startFloorIntro(floorIndex, onComplete)
    Dialog.breakMovements = true
    setBattleMusicActive(false)
    if Music and Music.closeForFloorIntro then
        Music:closeForFloorIntro()
    elseif Music and Music.closeGame then
        Music:closeGame()
    end
    FloorIntroManager:startFloor(floorIndex, function()
        Dialog.breakMovements = self.playerRoomEntryMove ~= nil
        if onComplete then
            onComplete()
        end
    end)
end

function Game:updateFloorIntro(dt)
    return FloorIntroManager:updateFloor(dt)
end

function Game:updateFloorIntroState(dt)
    FloorIntroManager:update(dt)
end

function Game:loadFloor(floorIndex, onIntroComplete)
    if not (CURRENT_LEVEL and CURRENT_LEVEL.applyFloorLevel and CURRENT_LEVEL:applyFloorLevel(floorIndex)) then
        return false
    end

    FloorManager:load(CURRENT_LEVEL)
    Tilemap:load()

    self.enemies = {}
    self.nearbyEnemies = {}
    self.objects = {}
    self.particles = {}
    self.drawQueue = {}
    self.lightSources = {}
    self.weaponShockwaves = {}
    self.footsteps = {}
    self.roomTransitionCooldown = 0.45
    self.playerRoomEntryMove = nil
    self.playerRoomExitTransition = nil
    self.currentEntryDoorAvoidPoint = nil
    self.playerCombatRoomsEntered = 0
    self.roomFadeAlpha = 0
    self.floorChanging = false
    self.sPSoundPlayed = false
    self.sPSoundPlayedOutro = false
    self.timer = 0
    self.spot = self.spot or {}
    self.spot.radius = 1
    self.spot.feather = 3
    self.spot.target = 60
    self.spot.speed = 160
    self.spot.speedIncrease = 1000
    self.spot.enabled = true

    local spawnX, spawnY = getStartRoomPlayerSpawn()
    Player.x = spawnX
    Player.y = spawnY
    Player.velocityX = 0
    Player.velocityY = 0
    Player.moveX = 0
    Player.moveY = 0

    if camera then
        camera.x = Player.x - 5
        camera.y = Player.y - 30
        camera:snapToCurrentMode()
    end

    self:setupCurrentRoom()
    self:restoreCurrentRoomDrops()
    self:startFloorIntro(floorIndex, onIntroComplete)
    return true
end

function Game:startThanksScreen()
    self.floorChanging = false
    Dialog.breakMovements = true
    setBattleMusicActive(false)
    if Music and Music.closeGame then
        Music:closeGame()
    end
    if STATES and STATES.floorIntro then
        state = STATES.floorIntro
    end
    FloorIntroManager:startThanks(function()
        Dialog.breakMovements = false
        if quitToMenuImmediate then
            quitToMenuImmediate()
        elseif quitToMenu then
            quitToMenu()
        end
    end)
end

function Game:updateThanksScreen(dt)
    return FloorIntroManager:updateThanks(dt)
end

function Game:showBottomMessage(text, duration)
    self.bottomMessageText = text
    self.bottomMessageTimer = duration or 3
    self.drawtext = text
    self.textAlphaTarget = 1
end

function Game:enterFloorHollow()
    if self.floorChanging or FloorIntroManager:hasThanksScreen() then
        return
    end

    self.floorChanging = true
    local floorIndex = CURRENT_LEVEL and CURRENT_LEVEL.currentFloorIndex or 1
    local nextFloorIndex = floorIndex + 1
    if CURRENT_LEVEL and CURRENT_LEVEL.floorLevels and CURRENT_LEVEL.floorLevels[nextFloorIndex] then
        if Music and Music.closeGame then
            Music:closeGame()
        end
        if STATES and STATES.floorIntro then
            state = STATES.floorIntro
        end
        self:loadFloor(nextFloorIndex, function()
            if STATES and STATES.game then
                state = STATES.game
            end
            if Music and Music.startGame then
                Music:startGame()
            end
        end)
    else
        self:startThanksScreen()
    end
end

function Game:checkRoomTransition(dt)
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

function Game:openSouth()
    DoorsManager:openSouth()
end

function Game:openNorth()
    DoorsManager:openNorth()
end

function Game:close()
    HeartSound:stop()
    CardChoice:load()
    self = {}
end

function Game:getPlayerPoints()
    return PointsManager:getPoints()
end

function Game:increasePlayerPoints(qty)
    PointsManager:increasePoints(qty)
end

function Game:decreasePlayerPoints(qty)
    return PointsManager:decreasePoints(qty)
end

function Game:playSLSound()
    if self.sPSoundPlayed then return end
    local sound = love.audio.newSource("assets/sfx/spotlight/spotlight1.mp3", "static")
    self.sPSoundPlayed = true
    sound:setVolume(0.2)
    sound:setPitch(1.3)
    sound:play()
end

function Game:playSLSoundOutro()
    if self.sPSoundPlayedOutro then return end
    local sound = love.audio.newSource("assets/sfx/spotlight/spotlight2.mp3", "static")
    sound:setVolume(0.1)
    sound:setPitch(1.1)
    self.sPSoundPlayedOutro = true
    sound:play()
end

function Game:updateSpotlight(dt)
    if not self.spot.enabled then
        return
    end

    self:playSLSound()
    if self.timer > 1.8 then
        self:playSLSoundOutro()
        self.spot.target = 10000
        self.spot.speed = self.spot.speedIncrease
        self.spot.feather = self.spot.feather + 10 * dt
        self.spot.speedIncrease = self.spot.speedIncrease + 1000 * dt
    end

    if self.spot.radius < self.spot.target then
        self.spot.radius = self.spot.radius + self.spot.speed * dt
    end

    if self.timer > 4 then
        self.spot.enabled = false
    end
end

function Game:updateAmbientTimers(dt)
    self.timer = self.timer + dt
    local theme = FloorManager:getCurrentRoomTheme()
    local ambience = theme and theme.ambience or {}

    if ambience.crow == false then
        self.crowTimer = math.random(20, 50)
    else
        self.crowTimer = self.crowTimer - dt
        if self.crowTimer <= 0 then
            self:crowNoise()
        end
    end

    if ambience.cricket == false then
        self.cricketTimer = math.random(20, 30)
    else
        self.cricketTimer = self.cricketTimer - dt
        if self.cricketTimer <= 0 then
            self:cricketNoise()
        end
    end
end

function Game:updatePitch(dt)
    local targetPitch = 1
    if Player.life <= 1 then
        targetPitch = 0.9
    end
    GAME_PITCH = transitionValue(GAME_PITCH, targetPitch, 1.3, dt)
end

function Game:updateEntityList(list, dt)
    for i = #list, 1, -1 do
        local item = list[i]
        if item.isAlive then
            item:update(dt)
        else
            table.remove(list, i)
        end
    end
end

function Game:refreshNearbyEnemies()
    self.nearbyEnemies = {}
    local cameraPosition = camera:objectPosition()
    local distanceLimitSq = NEARBY_ENEMY_DISTANCE * NEARBY_ENEMY_DISTANCE

    for i = 1, #self.enemies do
        local enemy = self.enemies[i]
        local dx = enemy.x - cameraPosition.x
        local dy = enemy.y - cameraPosition.y
        if dx * dx + dy * dy <= distanceLimitSq then
            self.nearbyEnemies[#self.nearbyEnemies + 1] = enemy
        end
    end
end

function Game:updateFootsteps(dt)
    for i = #self.footsteps, 1, -1 do
        local footstep = self.footsteps[i]
        footstep:update(dt)
        if not footstep.isAlive or distance(Player, footstep) > FOOTSTEP_CLEANUP_DISTANCE then
            table.remove(self.footsteps, i)
        end
    end
end

function Game:addWeaponShockwave(x, y, config)
    if not (x and y) then
        return
    end

    config = config or {}
    self.weaponShockwaves = self.weaponShockwaves or {}
    self.weaponShockwaves[#self.weaponShockwaves + 1] = {
        x = x,
        y = y,
        timer = 0,
        duration = config.duration or 0.28,
        radius = config.radius or 34,
        width = config.width or 7,
        intensity = config.intensity or 2.2,
    }
end

function Game:updateWeaponShockwaves(dt)
    for i = #(self.weaponShockwaves or {}), 1, -1 do
        local wave = self.weaponShockwaves[i]
        wave.timer = wave.timer + dt
        if wave.timer >= wave.duration then
            table.remove(self.weaponShockwaves, i)
        end
    end
end

function Game:getWeaponShockwaves()
    return self.weaponShockwaves or {}
end

function Game:updateManagers(dt)
    Tutorial:update(dt)
    WaveManager:update(dt)
    Clouds:update(dt)
    if CardChoice:isActive() then
        Dialog.breakMovements = true
    end
    if FloorIntroManager:isActive() then
        Dialog.breakMovements = true
        if FloorIntroManager:hasFloorIntro() and Player and Player.isAlive then
            Player.velocityX = 0
            Player.velocityY = 0
            Player:updateAnimation(dt, false)
            Player.gun:update(dt, Player.x, Player.y)
            addToDrawQueue(Player.y + 6, Player)
        end
    elseif self:updateRoomExitTransition(dt) then
        -- Player is controlled by the room-exit sequence.
    elseif not self:updateEntryMove(dt) then
        Player:update(dt)
    end
    DoorsManager:update(dt)
    HeartSound:update(dt)
    Tilemap:update(dt)
    self:checkRoomTransition(dt)
    PointsManager:update(dt)
    CardChoice:update(dt)
    camera:update(dt)
end

function Game:update(dt)
    ACTIVE_LIGHT_MANAGER = self
    self.drawQueue = {}
    self.lightSources = {}
    self.fogTime = self.fogTime + dt

    self:updateSpotlight(dt)
    self:updateAmbientTimers(dt)
    self:updatePitch(dt)
    local showingThanks = FloorIntroManager:hasThanksScreen()

    self.textAlpha = transitionValue(self.textAlpha, self.textAlphaTarget, 5, dt)
    self.textAlphaTarget = 0
    if (self.bottomMessageTimer or 0) > 0 then
        self.bottomMessageTimer = math.max(0, self.bottomMessageTimer - dt)
        self.drawtext = self.bottomMessageText or self.drawtext
        self.textAlphaTarget = 1
    end

    local currentRoom = FloorManager:getCurrentRoom()
    if currentRoom and (currentRoom.templateId == "start_32x32" or isStartRoom(currentRoom)) then
        for index = #(self.enemies or {}), 1, -1 do
            if getmetatable(self.enemies[index]) ~= Scarecrow then
                table.remove(self.enemies, index)
            end
        end
    end

    if not showingThanks then
        self:updateEntityList(self.enemies, dt)
        self:checkCurrentRoomClear()
        self:updateBattleMusicForCurrentRoom()
        self:refreshNearbyEnemies()
        PlayerCloseStore = false
        self:updateEntityList(self.objects, dt)
        self:updateEntityList(self.particles, dt)
        self:updateFootsteps(dt)
        self:updateWeaponShockwaves(dt)
        self:updateManagers(dt)
    end
end

function Game:addLightSource(lightType, x, y, options)
    local config = LightConfig:getWorldLightConfig(lightType)
    if not (config and config.enabled ~= false and x and y) then
        return
    end

    if not isLightNearPlayer(config, x, y) and not isGroundLightNearCamera(config, x, y) then
        return
    end

    options = options or {}
    self.lightSources = self.lightSources or {}
    self.lightSources[#self.lightSources + 1] = {
        type = lightType,
        x = x,
        y = y,
        config = config,
        flicker = options.flicker or 1,
    }
end

function Game:getLightSources()
    local sources = {}
    local playerConfig = LightConfig:getWorldLightConfig("player")

    if Player and Player.isAlive and playerConfig and playerConfig.enabled ~= false then
        sources[#sources + 1] = {
            type = "player",
            x = Player.x,
            y = Player.y,
            config = playerConfig,
            flicker = 1,
        }
    end

    for _, source in ipairs(self.lightSources or {}) do
        sources[#sources + 1] = source
    end

    return sources
end

function Game:crowNoise()
    if not (Player.isAlive and Player.life > 2) then
        return
    end
    local theme = FloorManager:getCurrentRoomTheme()
    if theme and theme.ambience and theme.ambience.crow == false then
        self.crowTimer = math.random(20, 50)
        return
    end
    self.crowTimer = math.random(20, 50)
    AmbienceSound:playCrowSound()
end

function Game:cricketNoise()
    if not (Player.isAlive and Player.life > 2) then
        return
    end
    local theme = FloorManager:getCurrentRoomTheme()
    if theme and theme.ambience and theme.ambience.cricket == false then
        self.cricketTimer = math.random(20, 30)
        return
    end
    self.cricketTimer = math.random(20, 30)
    AmbienceSound:playCricketSound()
end

function Game:drawFootsteps()
    local brightnessByFootstep = {}
    local lightSources = self:getLightSources()

    for index, item in ipairs(self.footsteps) do
        local brightness = getPlayerLightBrightness(item, lightSources)
        brightnessByFootstep[index] = brightness
        item:drawLayer1(brightness)
    end

    for index, item in ipairs(self.footsteps) do
        item:drawLayer2(brightnessByFootstep[index])
    end

    for index, item in ipairs(self.footsteps) do
        item:drawLayer3(brightnessByFootstep[index])
    end
end

function Game:drawShadows()
    Clouds:drawShadow()
    for _, item in ipairs(self.drawQueue) do
        if not item.object.isGroundLayer and type(item.object.drawShadow) == "function" then
            item.object:drawShadow()
        end
    end
end

function Game:drawGroundQueueObjects()
    local lightSources = self:getLightSources()

    for _, item in ipairs(self.drawQueue) do
        if item.object.isGroundLayer then
            local brightness = getPlayerLightBrightness(item.object, lightSources)
            local r, g, b = getShadowTint(brightness)
            love.graphics.setColor(r, g, b, 1)
            item.object:draw()
            love.graphics.setColor(1, 1, 1, 1)
        end
    end
end

function Game:drawQueueObjects()
    local lightSources = self:getLightSources()

    for _, item in ipairs(self.drawQueue) do
        if not item.object.isGroundLayer then
            local brightness = getPlayerLightBrightness(item.object, lightSources)
            local r, g, b = getShadowTint(brightness)
            item.object.lightBrightness = brightness
            item.object.lightTint = {r, g, b}
            love.graphics.setColor(r, g, b, 1)
            item.object:draw()
            item.object.lightBrightness = nil
            item.object.lightTint = nil
            love.graphics.setColor(1, 1, 1, 1)
        end
    end
end

local function canDrawXrayTarget(object)
    return object
        and object.isXrayVisible == true
        and type(object.drawXray) == "function"
        and object.isAlive ~= false
end

local function canMaskXrayOccluder(object)
    return object
        and object.isXrayOccluder == true
        and object.isAlive ~= false
end

local function getXrayOccluderBox(object)
    if object and type(object.getXrayOccluderBox) == "function" then
        return object:getXrayOccluderBox()
    end

    local x = object and (object.xWorld or object.x)
    local y = object and (object.yWorld or object.y)
    if not (x and y) then
        return nil
    end

    local width = object.xrayMaskWidth or ((object.size or 16) * 2)
    local height = object.xrayMaskHeight or ((object.size or 16) * 3)
    return {
        x = x - width / 2,
        y = y - height,
        width = width,
        height = height,
    }
end

local function getXraySortY(object)
    if not object then
        return nil
    end

    if object.drawBaseY then
        return object.drawBaseY + (object.drawPriorityOffset or 0)
    end

    return object.xraySortY
        or object.yWorld
        or object.y
end

local function isTargetBehindBoxOccluder(targetObject, occluderObject)
    local targetY = getXraySortY(targetObject)
    local occluderY = getXraySortY(occluderObject)

    if not (targetY and occluderY) then
        return false
    end

    return targetY < occluderY
end

local function shouldUseXrayOccluder(target, item)
    if not (target and item and canMaskXrayOccluder(item.object)) then
        return false
    end

    if item.priority > target.priority then
        return true
    end

    if item.object and item.object.isXrayBoxOccluder == true then
        return isTargetBehindBoxOccluder(target.object, item.object)
    end

    return target.object
        and target.object.isXrayProjectile == true
        and item.object
        and item.object.isXrayTileOccluder == true
end

function Game:drawXrayTargets()
    local targets = {}
    for _, item in ipairs(self.drawQueue) do
        if canDrawXrayTarget(item.object) then
            targets[#targets + 1] = item
        end
    end

    if #targets == 0 then
        return
    end

    local previousShader = love.graphics.getShader()
    local previousBlendMode, previousAlphaMode = love.graphics.getBlendMode()
    local previousColor = {love.graphics.getColor()}

    love.graphics.setBlendMode("alpha", "alphamultiply")
    xraySoftShader:send("u_time", love.timer.getTime())
    xraySoftShader:send("u_alpha", 0.72)
    love.graphics.setShader(xraySoftShader)

    for _, target in ipairs(targets) do
        love.graphics.stencil(function()
            love.graphics.setShader()
            for _, item in ipairs(self.drawQueue) do
                if shouldUseXrayOccluder(target, item) then
                    if type(item.object.drawXrayOccluder) == "function" then
                        love.graphics.setShader(xrayStencilShader)
                        love.graphics.setColor(1, 1, 1, 1)
                        item.object:drawXrayOccluder()
                        love.graphics.setShader()
                    else
                        local box = getXrayOccluderBox(item.object)
                        if box then
                            love.graphics.setColor(1, 1, 1, 1)
                            love.graphics.rectangle("fill", box.x, box.y, box.width, box.height)
                        end
                    end
                end
            end
        end, "replace", 1, false)

        love.graphics.setShader(xraySoftShader)
        love.graphics.setStencilTest("greater", 0)
        love.graphics.setColor(1, 1, 1, 1)
        target.object:drawXray()
        love.graphics.setStencilTest()
    end

    love.graphics.setBlendMode(previousBlendMode, previousAlphaMode)
    love.graphics.setShader(previousShader)
    love.graphics.setColor(previousColor[1], previousColor[2], previousColor[3], previousColor[4])
end

function Game:drawLightSprites()
    local width = playerLightImage:getWidth()
    local height = playerLightImage:getHeight()
    local previousBlendMode, previousAlphaMode = love.graphics.getBlendMode()
    local sources = self:getLightSources()

    love.graphics.setBlendMode("alpha", "alphamultiply")

    for _, source in ipairs(sources) do
        local visual = source.config and source.config.visual
        if visual and visual.enabled ~= false then
            local color = visual.color or {1, 1, 1}
            local flicker = source.flicker or 1
            local scale = visual.scale or 0.65
            if visual.flickerScale then
                scale = scale * flicker
            end

            love.graphics.setColor(
                color[1] or 1,
                color[2] or 1,
                color[3] or 1,
                (visual.alpha or 0.18) * flicker
            )
            love.graphics.draw(
                playerLightImage,
                source.x,
                source.y,
                0,
                scale,
                scale,
                width / 2,
                height / 2
            )
        end
    end

    love.graphics.setBlendMode("add", "alphamultiply")
    for _, source in ipairs(sources) do
        local visual = source.config and source.config.visual
        if visual and visual.enabled ~= false and visual.glowAlpha and visual.glowAlpha > 0 then
            local color = visual.color or {1, 1, 1}
            local flicker = source.flicker or 1
            local scale = visual.glowScale or (visual.scale or 0.65)
            if visual.flickerScale then
                scale = scale * flicker
            end

            love.graphics.setColor(
                color[1] or 1,
                color[2] or 1,
                color[3] or 1,
                (visual.glowAlpha or 0.05) * flicker
            )
            love.graphics.draw(
                playerLightImage,
                source.x,
                source.y,
                0,
                scale,
                scale,
                width / 2,
                height / 2
            )
        end
    end

    love.graphics.setBlendMode(previousBlendMode, previousAlphaMode)
    love.graphics.setColor(1, 1, 1, 1)
end

function Game:drawMinimap()
    local currentRoom = FloorManager:getCurrentRoom()
    if not currentRoom then
        return
    end

    local rooms = FloorManager:getRooms()
    local config = MinimapConfig
    local mapSize = config.size
    local mapX = pixel(baseWidth - mapSize - config.marginX)
    local mapY = pixel(config.marginY)
    local centerX = pixel(mapX + mapSize / 2)
    local centerY = pixel(mapY + mapSize / 2)
    local step = config.cellSize + config.cellGap
    local minimapSpriteScale = config.spriteScale or (config.cellSize / minimapSprites.room32x32:getWidth())
    local currentCellX, currentCellY = getRoomCenterCell(currentRoom)
    local viewRadius = config.viewRadius
    local previousLineStyle = love.graphics.getLineStyle()

    love.graphics.setLineStyle("rough")

    love.graphics.setColor(1, 1, 1, 1)
    drawMinimapSprite(minimapSprites.panel, centerX, centerY, mapSize, mapSize)

    local previousScissorX, previousScissorY, previousScissorW, previousScissorH = love.graphics.getScissor()
    love.graphics.setScissor(mapX, mapY, mapSize, mapSize)

    local knownRooms = {}
    for roomId, room in pairs(rooms) do
        knownRooms[roomId] = isRoomKnown(room, rooms)
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

    local function drawShopIconAt(x, y)
        local size = config.shopIconSize or (minimapSprites.store:getWidth() * minimapSpriteScale)

        love.graphics.setColor(1, 1, 1, 1)
        drawMinimapSprite(minimapSprites.store, x, y, size, size)
    end

    local function drawCardIconAt(x, y)
        local size = config.shopIconSize or (minimapSprites.cards:getWidth() * minimapSpriteScale)

        love.graphics.setColor(1, 1, 1, 1)
        drawMinimapSprite(minimapSprites.cards, x, y, size, size)
    end

    local function clamp(value, minValue, maxValue)
        return math.max(minValue, math.min(maxValue, value))
    end

    local function getPlayerMinimapPosition(room, playerIconSize)
        local minX, minY, maxX, maxY = getRoomMinimapBounds(room)
        local roomX, roomY = toMinimapPosition((minX + maxX) / 2, (minY + maxY) / 2)
        local roomSprite = getMinimapRoomSprite({
            minX = minX,
            minY = minY,
            maxX = maxX,
            maxY = maxY,
        }, room)
        local roomSpriteWidth = roomSprite:getWidth() * minimapSpriteScale
        local roomSpriteHeight = roomSprite:getHeight() * minimapSpriteScale
        local playerMapX, playerMapY = Tilemap:worldToMap(Player.x, Player.y)
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
                    local cellA, cellB = getMinimapConnectionCells(room, neighbor, direction)
                    if cellA and cellB and (isCellInView(cellA) or isCellInView(cellB)) then
                        local doorKey = roomId .. ":" .. neighborId .. ":" .. direction
                        if not drawnDoors[doorKey] then
                            drawnDoors[doorKey] = true
                            local ax, ay = getCellEdgePosition(cellA, direction)
                            local bx, by = getCellEdgePosition(cellB, getOppositeDirection(direction))
                            local connectionSize = config.connectionIconSize
                                or (minimapSprites.connection:getWidth() * minimapSpriteScale)
                            love.graphics.setColor(1, 1, 1, 1)
                            drawMinimapSprite(
                                minimapSprites.connection,
                                (ax + bx) / 2,
                                (ay + by) / 2,
                                connectionSize,
                                connectionSize
                            )
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
                    local roomX, roomY = toMinimapPosition(
                        (rect.minX + rect.maxX) / 2,
                        (rect.minY + rect.maxY) / 2
                    )
                    local sprite = getMinimapRoomSprite(rect, room)
                    local width = sprite:getWidth() * minimapSpriteScale
                    local height = sprite:getHeight() * minimapSpriteScale

                    love.graphics.setColor(1, 1, 1, 1)
                    drawMinimapSprite(sprite, roomX, roomY, width, height)
                end
            end
        end
    end

    for roomId, room in pairs(rooms) do
        if knownRooms[roomId] and (shouldShowShopIcon(room) or shouldShowCardIcon(room)) then
            local minX, minY, maxX, maxY = getRoomMinimapBounds(room)
            local inView = not (
                maxX < currentCellX - viewRadius or
                minX > currentCellX + viewRadius or
                maxY < currentCellY - viewRadius or
                minY > currentCellY + viewRadius
            )

            if inView then
                local iconCellX = (minX + maxX) / 2
                local iconCellY = (minY + maxY) / 2
                local iconX, iconY = toMinimapPosition(iconCellX, iconCellY)
                if shouldShowCardIcon(room) then
                    drawCardIconAt(iconX, iconY)
                else
                    drawShopIconAt(iconX, iconY)
                end
            end
        end
    end

    local playerIconSize = config.playerIconSize or (minimapSprites.player:getWidth() * minimapSpriteScale)
    local playerIconX, playerIconY = getPlayerMinimapPosition(currentRoom, playerIconSize)
    love.graphics.setColor(1, 1, 1, 1)
    drawMinimapSprite(minimapSprites.player, playerIconX, playerIconY, playerIconSize, playerIconSize)

    if previousScissorX then
        love.graphics.setScissor(previousScissorX, previousScissorY, previousScissorW, previousScissorH)
    else
        love.graphics.setScissor()
    end
    love.graphics.setLineStyle(previousLineStyle)
    love.graphics.setColor(1, 1, 1, 1)
end

function Game:drawRoomFade()
    local alpha = self.roomFadeAlpha or 0
    if alpha <= 0 then
        return
    end

    love.graphics.setColor(0, 0, 0, alpha)
    love.graphics.rectangle("fill", 0, 0, baseWidth, baseHeight)
    love.graphics.setColor(1, 1, 1, 1)
end

function Game:drawFloorIntro()
    FloorIntroManager:drawFloor()
end

function Game:drawThanksScreen()
    FloorIntroManager:drawThanks()
end

function Game:drawLowHealthVignette()
    local intensity = Player and Player.damageAlha or 0
    if intensity <= 0 then
        return
    end

    vignetteShader:send("u_resolution", {baseWidth, baseHeight})
    vignetteShader:send("u_intensity", math.min(math.max(intensity, 0), 1))
    vignetteShader:send("u_edgeBrightness", 0.7)

    love.graphics.setShader(vignetteShader)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, baseWidth, baseHeight)
    love.graphics.setShader()
    love.graphics.setColor(1, 1, 1, 1)
end

function Game:drawWorld()
    camera:attach()
    love.graphics.scale(WORLD_SCALE_X, YSCALE)

    Ground:draw(Player)
    self:drawLightSprites()
    table.sort(self.drawQueue, sortDrawQueue)

    if not (CURRENT_LEVEL and CURRENT_LEVEL.enableTrails == false) then
        Trail:draw()
    end
    self:drawFootsteps()
    self:drawGroundQueueObjects()
    self:drawShadows()
    Player:drawSight()
    self:drawQueueObjects()
    if CURRENT_LEVEL and CURRENT_LEVEL.drawDebug then
        CURRENT_LEVEL:drawDebug()
    end
    Clouds:draw()
    self:drawXrayTargets()

    love.graphics.scale(1, 1)
    camera:detach()
end

function Game:drawUI()
    self:drawLowHealthVignette()

    love.graphics.setFont(font)
    font:setLineHeight(0.65)
    love.graphics.setColor(1, 1, 1, self.textAlpha)

    if not Dialog.visible then
        love.graphics.printf(self.drawtext, 0, getScreenHeight() - 80, getScreenWidth(), "center")
    end
    love.graphics.setColor(1, 1, 1, 1)

    PointsManager:draw()
    Player:drawLife()
    if Player and Player.isAlive then
        Player.gun:drawUI()
        Tutorial:draw()
    end
    WaveManager:draw()
    self:drawMinimap()

    if DEBUG then
        love.graphics.print("enemies qty: " .. #self.enemies, 10, 110)
    end

    self:drawRoomFade()
    self:drawFloorIntro()
    self:drawThanksScreen()
end

function Game:draw()
    self:drawWorld()
end

function Game:drawHUD()
    if not self.hudCanvas or self.hudCanvas:getWidth() ~= baseWidth or self.hudCanvas:getHeight() ~= baseHeight then
        self.hudCanvas = love.graphics.newCanvas(baseWidth, baseHeight)
        self.hudCanvas:setFilter("nearest", "nearest")
    end

    local previousCanvas = love.graphics.getCanvas()
    love.graphics.setCanvas(self.hudCanvas)
    love.graphics.clear(0, 0, 0, 0)
    self:drawUI()
    love.graphics.setCanvas(previousCanvas)

    hudDistortionShader:send("u_time", love.timer.getTime()/2)
    hudDistortionShader:send("u_strength", 0.00055)
    love.graphics.setShader(hudDistortionShader)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.hudCanvas, 0, 0)
    love.graphics.setShader()

    CardChoice:draw()
end

function DisableMouseTutorial()
    if Tutorial.drawmouse == false then return end
    Tutorial:playSound()
    Tutorial.drawmouse = false
    Tutorial.tutorialTimer = 0
end

function DisableInteractTutorial()
    if Tutorial.drawInteract == false then return end
    Tutorial:playSound()
    Tutorial.drawInteract = false
    Tutorial.drawmouse = true
    Tutorial.tutorialTimer = 0
end

function DisableWalkTutorial()
    local state = FloorManager:getCurrentRoomState()
    if state and state.startRoomScarecrowEncounter then
        if Tutorial.drawWalk then
            Tutorial:playSound()
        end
        Tutorial.drawWalk = false
        Tutorial.drawInteract = false
        Tutorial.drawmouse = false
        Tutorial.tutorialTimer = 0
        state.playerMovedForScarecrowTutorial = true
        return
    end

    if Tutorial.drawWalk == false then return end
    Tutorial:playSound()
    Tutorial.drawWalk = false
    Tutorial.drawInteract = true
    Tutorial.tutorialTimer = 0
end

function Game:keypressed(key)
    if CardChoice:isActive() and CardChoice:keypressed(key) then
        return
    end

    if key == "f6" then
        --DEBUG = not DEBUG
    elseif key == "1" then
        if Player and Player.gun then
            Player.gun:selectSlot(1)
        end
    elseif key == "2" then
        if Player and Player.gun then
            Player.gun:selectSlot(2)
        end
    elseif key == "e" then
        if Player and Player.gun then
            Player.gun:toggleWeaponSlot()
        end
    elseif key == "q" then
        if Player and Player.gun then
            Player.gun:reloadSelectedWeapon()
        end
    elseif key == "f" then
        if not Dialog.visible then
            Tilemap:keypressed(key)
            for i = #self.objects, 1, -1 do
                local object = self.objects[i]
                if object.isAlive and type(object.keypressed) == "function" then
                    object:keypressed(key)
                end
            end
        else
            CreatorManager:keypressed(key)
        end
    elseif key == "o" then
        --DoorsManager:openSouth()
    elseif key == "n" then
        --DoorsManager:openNorth()
    elseif tonumber(key) then
        --self:changeShaders(tonumber(key))
    end
end

function Game:mousepressed(x, y, button)
    if CardChoice:isActive() then
        return CardChoice:mousepressed(x, y, button)
    end
    return false
end

function Game:startCardChoice(x, y, options)
    CardChoice:start(x, y, options)
end

return Game
