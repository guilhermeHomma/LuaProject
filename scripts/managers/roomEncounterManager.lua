local RoomEncounterManager = {}

local Tilemap = require("scripts/tilemap")
local FloorManager = require("scripts/managers/floorManager")
local Zombie = require("scripts/enemies/zombie")
local BabyZombie = require("scripts/enemies/babyZombie")
local BigZombie = require("scripts/enemies/bigZombie")
local NoHead = require("scripts/enemies/noHead")
local Spider = require("scripts/enemies/spider")
local Scarecrow = require("scripts/enemies/scarecrow")
local Hollow = require("scripts/objects/hollow")
local SpiderWeb = require("scripts/particles/spiderWeb")
local Localization = require("scripts/managers/localization")

local TILE_WORLD_SIZE = 16

local EnemyFactories = {
    zombie = Zombie,
    babyZombie = BabyZombie,
    bigZombie = BigZombie,
    noHead = NoHead,
    spider = Spider,
    scarecrow = Scarecrow,
}

local waveClearFeedbackSound = love.audio.newSource("assets/sfx/ambience/nextWave.mp3", "static")

local oppositeDirections = {
    north = "south",
    south = "north",
    west = "east",
    east = "west",
}

local function isStartRoom(room)
    local level = FloorManager.level
    local startRoomId = level and level.floorConfig and level.floorConfig.startRoomId or "0:0"
    return room and room.id == startRoomId
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

local function setBattleMusicActive(active)
    if Music and Music.setBattleActive then
        Music:setBattleActive(active == true)
    end
end

local function updateRoomMusicContext(room)
    if Music and Music.setShopOrChestRoomActive then
        local isShopOrChestRoom = room and (room.isShopRoom == true or room.isCardRoom == true)
        Music:setShopOrChestRoomActive(isShopOrChestRoom == true)
    end
end

local function playWaveClearFeedback()
    waveClearFeedbackSound:stop()
    waveClearFeedbackSound:setVolume(0.35 * (SOUND_VOLUME or 1))
    waveClearFeedbackSound:setPitch((1.08 + math.random() * 0.12) * GAME_PITCH)
    waveClearFeedbackSound:play()
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

local function getEncounterSpawnAvoidPoints(config, waveIndex, spawnedPositions, enemies)
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

    for _, enemy in ipairs(enemies or {}) do
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

local function getAdditionalEncounterWaves(config)
    return config and (config.additionalWaveTemplates or config.extraWaveTemplates) or {}
end

local function chooseAdditionalEncounterWave(config, room)
    local waves = getAdditionalEncounterWaves(config)
    local difficulty = getEncounterDifficulty(config, room)
    local candidates = {}
    local totalChance = 0

    for _, waveConfig in ipairs(waves) do
        if difficulty >= (waveConfig.minDifficulty or 1) then
            local chance = waveConfig.chance or waveConfig.weight or 1
            if chance > 0 then
                candidates[#candidates + 1] = waveConfig
                totalChance = totalChance + chance
            end
        end
    end

    if totalChance <= 0 then
        return nil
    end

    local roll = math.random() * totalChance
    for _, waveConfig in ipairs(candidates) do
        roll = roll - (waveConfig.chance or waveConfig.weight or 1)
        if roll <= 0 then
            return waveConfig
        end
    end

    return candidates[#candidates]
end

local function getAdditionalEncounterChance(state, normalEnemyCount)
    local baseChance = (state.encounterTotalWaves or 1) <= 1 and 0.9 or 0.5

    if normalEnemyCount <= 2 then
        baseChance = baseChance + 0.2
    elseif normalEnemyCount <= 3 then
        baseChance = baseChance + 0.1
    end

    return math.min(baseChance, 0.95)
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

function RoomEncounterManager:spawnStartRoomScarecrow(currentRoom)
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

function RoomEncounterManager:spawnEndRoomHollow(currentRoom)
    if not (currentRoom and currentRoom.isEndRoom) then
        return
    end

    local map = Tilemap:getTilemap()
    local centerX = map and #(map[1] or {}) / 2 or 16
    local centerY = map and #map / 2 or 16
    local worldX, worldY = Tilemap:mapToWorld(centerX + 0.5, centerY + 0.5)
    self.objects[#self.objects + 1] = Hollow:new(worldX, worldY)
end

function RoomEncounterManager:setupCurrentRoom(options)
    options = options or {}
    self.enemies = {}
    self.nearbyEnemies = {}

    local currentRoom = FloorManager:getCurrentRoom()
    local state = currentRoom and currentRoom.state
    if not state then
        return
    end

    if not options.deferMinimapReveal then
        state.visited = true
        state.discovered = true
        revealRoomConnections(currentRoom)
    end
    if not options.keepEntryDoorOpen then
        Tilemap:setAllRoomDoorsOpen(false)
    end

    if not (CURRENT_LEVEL and CURRENT_LEVEL.skipStartRoomSafetyLogic)
        and (currentRoom.templateId == "start_32x32" or isStartRoom(currentRoom)) then
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

function RoomEncounterManager:spawnInitialSpiderWebsForRoom(currentRoom)
    local state = currentRoom and currentRoom.state
    if not state or state.initialSpiderWebsSpawned then
        return
    end

    state.initialSpiderWebsSpawned = true
    SpiderWeb.spawnRandomReachable(2, Player, 45)
end

function RoomEncounterManager:spawnCurrentRoomWave(currentRoom, encounterConfig)
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
    local spawnedEnemyCount = 0

    state.encounterWaveSerial = waveId
    state.encounterSpawnedWaves = waveIndex
    state.activeEncounterWaves = state.activeEncounterWaves or {}
    state.activeEncounterWaves[waveId] = true
    state.normalEncounterWaves = state.normalEncounterWaves or {}
    state.normalEncounterWaves[waveId] = true

    state.encounterSpawned = true
    for spawnIndex = 1, enemyCount do
        local enemyId = fixedWave and fixedWave.enemies[spawnIndex] or chooseEnemyType(encounterConfig, waveConfig, spawnedCounts)
        local factory = EnemyFactories[enemyId] or EnemyFactories.zombie
        local spawnAvoidPoints = getEncounterSpawnAvoidPoints(encounterConfig, waveIndex, spawnedPositions, self.enemies)
        local x, y = Tilemap:getRandomReachableSpawnPosition(Player, spawnMinDistance, spawnAvoidPoints)

        if x and y then
            local enemy = factory:new(x, y)
            enemy.encounterWaveId = waveId
            self.enemies[#self.enemies + 1] = enemy
            spawnedPositions[#spawnedPositions + 1] = { x = x, y = y }
            spawnedCounts[enemyId] = (spawnedCounts[enemyId] or 0) + 1
            spawnedAny = true
            spawnedEnemyCount = spawnedEnemyCount + 1
        end
    end

    if not spawnedAny then
        state.activeEncounterWaves[waveId] = nil
        return false
    end

    if (spawnedCounts.spider or 0) > 0 then
        self:spawnInitialSpiderWebsForRoom(currentRoom)
    end

    state.normalEncounterEnemyTotal = (state.normalEncounterEnemyTotal or 0) + spawnedEnemyCount
    self:spawnAdditionalEncounterWave(currentRoom, encounterConfig, spawnedEnemyCount, spawnedPositions)

    self.drawtext = Localization:t("game.wave", { wave = waveIndex })
    self.textAlphaTarget = 1
    return true
end

function RoomEncounterManager:spawnAdditionalEncounterWave(currentRoom, encounterConfig, normalEnemyCount, spawnedPositions)
    local state = currentRoom and currentRoom.state
    if not state or state.additionalEncounterWaveRolled then
        return false
    end

    spawnedPositions = spawnedPositions or {}
    state.additionalEncounterWaveRolled = true
    local waveConfig = chooseAdditionalEncounterWave(encounterConfig, currentRoom)
    if not waveConfig then
        return false
    end

    local chance = getAdditionalEncounterChance(state, normalEnemyCount or 0)
    if math.random() > chance then
        return false
    end

    local enemyCount = getEncounterEnemyCount(encounterConfig, waveConfig)
    local waveId = (state.encounterWaveSerial or 0) + 1
    local spawnMinDistance = getEncounterSpawnMinDistanceForWave(encounterConfig, 1)
    local spawnedCounts = {}
    local spawnedAny = false

    state.encounterWaveSerial = waveId
    state.activeEncounterWaves = state.activeEncounterWaves or {}

    for _ = 1, enemyCount do
        local enemyId = chooseEnemyType(encounterConfig, waveConfig, spawnedCounts)
        local factory = EnemyFactories[enemyId] or EnemyFactories.zombie
        local spawnAvoidPoints = getEncounterSpawnAvoidPoints(encounterConfig, 1, spawnedPositions, self.enemies)
        local x, y = Tilemap:getRandomReachableSpawnPosition(Player, spawnMinDistance, spawnAvoidPoints)

        if x and y then
            local enemy = factory:new(x, y)
            enemy.encounterWaveId = waveId
            enemy.isAdditionalEncounterEnemy = true
            self.enemies[#self.enemies + 1] = enemy
            spawnedPositions[#spawnedPositions + 1] = { x = x, y = y }
            spawnedCounts[enemyId] = (spawnedCounts[enemyId] or 0) + 1
            spawnedAny = true
        end
    end

    if spawnedAny then
        state.activeEncounterWaves[waveId] = true
        if (spawnedCounts.spider or 0) > 0 then
            self:spawnInitialSpiderWebsForRoom(currentRoom)
        end
    end

    return spawnedAny
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

local function getActiveNormalEncounterWaveCount(state)
    local count = 0
    local activeWaves = state and state.activeEncounterWaves or {}

    for waveId, active in pairs(state and state.normalEncounterWaves or {}) do
        if active and activeWaves[waveId] then
            count = count + 1
        end
    end

    return count
end

function RoomEncounterManager:updateBattleMusicForCurrentRoom()
    local currentRoom = FloorManager:getCurrentRoom()
    local roomState = currentRoom and currentRoom.state
    local battleActive = false

    updateRoomMusicContext(currentRoom)

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

function RoomEncounterManager:spawnEncounterWavesUntilFull(currentRoom, encounterConfig)
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

    while getActiveNormalEncounterWaveCount(state) < state.encounterSimultaneousWaves do
        if not self:spawnCurrentRoomWave(currentRoom, encounterConfig) then
            break
        end
    end
end

function RoomEncounterManager:checkCurrentRoomClear()
    local currentRoom = FloorManager:getCurrentRoom()
    local state = currentRoom and currentRoom.state
    if not state or state.cleared or not state.encounterSpawned then
        return
    end

    if not (CURRENT_LEVEL and CURRENT_LEVEL.skipStartRoomSafetyLogic)
        and (currentRoom.templateId == "start_32x32" or isStartRoom(currentRoom)) then
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
        self.drawtext = Localization:t("game.room_cleared")
        self.textAlphaTarget = 1
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
                if state.normalEncounterWaves then
                    state.normalEncounterWaves[waveId] = nil
                end
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
        self.drawtext = Localization:t("game.room_cleared")
        self.textAlphaTarget = 1
    end
end

function RoomEncounterManager.attach(game)
    game.spawnStartRoomScarecrow = RoomEncounterManager.spawnStartRoomScarecrow
    game.spawnEndRoomHollow = RoomEncounterManager.spawnEndRoomHollow
    game.setupCurrentRoom = RoomEncounterManager.setupCurrentRoom
    game.spawnInitialSpiderWebsForRoom = RoomEncounterManager.spawnInitialSpiderWebsForRoom
    game.spawnCurrentRoomWave = RoomEncounterManager.spawnCurrentRoomWave
    game.spawnAdditionalEncounterWave = RoomEncounterManager.spawnAdditionalEncounterWave
    game.updateBattleMusicForCurrentRoom = RoomEncounterManager.updateBattleMusicForCurrentRoom
    game.spawnEncounterWavesUntilFull = RoomEncounterManager.spawnEncounterWavesUntilFull
    game.checkCurrentRoomClear = RoomEncounterManager.checkCurrentRoomClear
end

return RoomEncounterManager
