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

local font = love.graphics.newFont("assets/fonts/ThaleahFat.ttf", 32)
local playerLightImage = love.graphics.newImage("assets/sprites/effects/light.png")
playerLightImage:setFilter("nearest", "nearest")
local vignetteShader = love.graphics.newShader("scripts/shaders/vignette.glsl")
local minimapSprites = {
    panel = love.graphics.newImage("assets/sprites/ui/map/map.png"),
    room32x32 = love.graphics.newImage("assets/sprites/ui/map/32x32.png"),
    room32x48 = love.graphics.newImage("assets/sprites/ui/map/32x48.png"),
    room48x32 = love.graphics.newImage("assets/sprites/ui/map/48x32.png"),
    room48x48 = love.graphics.newImage("assets/sprites/ui/map/48x48.png"),
    connection = love.graphics.newImage("assets/sprites/ui/map/connection.png"),
    player = love.graphics.newImage("assets/sprites/ui/map/player.png"),
    store = love.graphics.newImage("assets/sprites/ui/map/store.png"),
    unknown = love.graphics.newImage("assets/sprites/ui/map/unknown.png"),
}

for _, image in pairs(minimapSprites) do
    image:setFilter("nearest", "nearest")
end

local function sortDrawQueue(a, b)
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
    drop.drawPriorityOffset = 12
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
local ENTRY_MOVE_DISTANCE = TILE_WORLD_SIZE * 3
local ENTRY_MOVE_DURATION = 0.62
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

    return result
end

local function getRoomEncounterOverrideValue(config, room, key)
    local override = getRoomEncounterOverride(config, room)
    return override and override[key] or nil
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

local function getEncounterDifficulty(config)
    return math.max(1, config and config.difficulty or 1)
end

local function getEncounterWaves(config)
    if config and config.waves and #config.waves > 0 then
        return config.waves
    end

    return {config or {}}
end

local function getEncounterSpawnMinDistance(config)
    local tileDistance = (config and config.spawnMinDistanceTiles or 4) * TILE_WORLD_SIZE
    local worldDistance = config and config.spawnMinDistance or 0
    return math.max(TILE_WORLD_SIZE * 4, tileDistance, worldDistance)
end

local function getEncounterEnemyCount(config, waveConfig)
    local countConfig = waveConfig.count or config.count or {}
    local difficulty = getEncounterDifficulty(config)
    local perDifficulty = countConfig.perDifficulty or 0
    local bonus = math.max(0, difficulty - 1) * perDifficulty
    local minCount = (countConfig.min or 1) + bonus
    local maxCount = (countConfig.max or minCount) + bonus
    local multiplier = waveConfig.countMultiplier or 1
    local add = waveConfig.countAdd or 0

    minCount = math.max(1, math.floor(minCount * multiplier + add + 0.5))
    maxCount = math.max(minCount, math.floor(maxCount * multiplier + add + 0.5))

    return math.random(minCount, maxCount)
end

local function chooseEnemyType(config, waveConfig, spawnedCounts)
    local difficulty = getEncounterDifficulty(config)
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

local function shouldShowShopIcon(room)
    local state = room and room.state
    return state
        and state.visited == true
        and state.shopProduct ~= nil
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

local function getPlayerLightBrightness(object)
    local generalShadow = getGeneralShadow()
    local minBrightness = generalShadow.minBrightness or 1
    local brightness = minBrightness
    local sources = Game and Game.getLightSources and Game:getLightSources() or {}

    for _, source in ipairs(sources) do
        local spriteBrightness = source.config and source.config.spriteBrightness
        if spriteBrightness and spriteBrightness.enabled ~= false then
            local d = distance(source, object)
            local minDist = spriteBrightness.minDistance or 35
            local maxDist = spriteBrightness.maxDistance or 230
            local maxBrightness = spriteBrightness.maxBrightness or 1
            local range = math.max(1, maxDist - minDist)
            local t = math.min(math.max((d - minDist) / range, 0), 1)
            local sourceBrightness = maxBrightness + (minBrightness - maxBrightness) * t
            sourceBrightness = math.min(math.max(sourceBrightness * (source.flicker or 1), minBrightness), maxBrightness)
            brightness = math.max(brightness, sourceBrightness)
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

function Game:load()
    ACTIVE_LIGHT_MANAGER = self
    math.randomseed(os.time())
    love.graphics.setDefaultFilter("nearest", "nearest")

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
    self.timer = 0
    self.roomTransitionCooldown = 0
    self.playerRoomEntryMove = nil
    self.playerRoomExitTransition = nil
    self.roomFadeAlpha = 0
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
    if not state or state.cleared or state.scarecrowDestroyed then
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

    if currentRoom.isShopRoom then
        state.cleared = true
        state.skipEncounter = true
        state.encounterSpawned = false
        state.encounterCompleted = true
        return
    end

    local encounterConfig = getEncounterConfig()
    if not (encounterConfig and encounterConfig.enabled) or state.cleared then
        return
    end

    if isStartRoom(currentRoom) and self:spawnStartRoomScarecrow(currentRoom) then
        return
    end

    if currentRoom.templateId == "start_32x32" and encounterConfig.startRoom == false then
        state.cleared = true
        state.encounterCompleted = true
        return
    end

    if shouldSkipRoomEncounter(encounterConfig, currentRoom) then
        state.cleared = true
        state.encounterCompleted = true
        return
    end

    state.encounterWaveIndex = (state.encounterWaveIndex or 0) > 0 and state.encounterWaveIndex or 1
    self:spawnCurrentRoomWave(currentRoom, encounterConfig)
end

function Game:spawnCurrentRoomWave(currentRoom, encounterConfig)
    local state = currentRoom and currentRoom.state
    if not state or currentRoom.isShopRoom then
        return
    end

    local waves = getEncounterWaves(encounterConfig)
    local waveIndex = math.max(1, state.encounterWaveIndex or 1)
    local waveConfig = getRoomWaveConfig(encounterConfig, waves[waveIndex] or waves[#waves] or {}, currentRoom)
    local enemyCount = getEncounterEnemyCount(encounterConfig, waveConfig)
    local spawnMinDistance = getEncounterSpawnMinDistance(encounterConfig)
    local spawnedCounts = {}

    state.encounterSpawned = true
    for _ = 1, enemyCount do
        local enemyId = chooseEnemyType(encounterConfig, waveConfig, spawnedCounts)
        local factory = EnemyFactories[enemyId] or EnemyFactories.zombie
        local x, y = Tilemap:getRandomReachableSpawnPosition(Player, spawnMinDistance)

        if x and y then
            self.enemies[#self.enemies + 1] = factory:new(x, y)
            spawnedCounts[enemyId] = (spawnedCounts[enemyId] or 0) + 1
        end
    end

    Game.drawtext = "Wave " .. waveIndex
    Game.textAlphaTarget = 1
end

function Game:checkCurrentRoomClear()
    local currentRoom = FloorManager:getCurrentRoom()
    local state = currentRoom and currentRoom.state
    if not state or state.cleared or not state.encounterSpawned then
        return
    end

    if #self.enemies == 0 then
        if state.startRoomScarecrowEncounter then
            state.cleared = true
            state.encounterCompleted = true
            Game.drawtext = "Room cleared"
            Game.textAlphaTarget = 1
            return
        end

        local encounterConfig = getEncounterConfig()
        local waves = getEncounterWaves(encounterConfig)
        local nextWaveIndex = (state.encounterWaveIndex or 1) + 1

        if encounterConfig and nextWaveIndex <= #waves then
            state.encounterWaveIndex = nextWaveIndex
            self:spawnCurrentRoomWave(currentRoom, encounterConfig)
            return
        end

        state.cleared = true
        state.encounterCompleted = true
        Game.drawtext = "Room cleared"
        Game.textAlphaTarget = 1
    end
end

function Game:startEntryMove(entryDirection)
    local vector = entryMoveVectors[entryDirection] or {x = 0, y = 0}
    self.playerRoomEntryMove = {
        timer = 0,
        duration = ENTRY_MOVE_DURATION,
        vectorX = vector.x,
        vectorY = vector.y,
        startX = Player.x,
        startY = Player.y,
        targetX = Player.x + vector.x * ENTRY_MOVE_DISTANCE,
        targetY = Player.y + vector.y * ENTRY_MOVE_DISTANCE,
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
        self.playerRoomEntryMove = nil
        Tilemap:setAllRoomDoorsOpen(false, true)
        Dialog.breakMovements = false
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
    Tilemap:load()
    Tilemap:setDoorOpen(entryDirection, true)
    local spawnX, spawnY = getEntrySpawn(entryDirection)
    Player.x = spawnX
    Player.y = spawnY
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

function Game:checkRoomTransition(dt)
    if self.playerRoomExitTransition then
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

    self.crowTimer = self.crowTimer - dt
    if self.crowTimer <= 0 then
        self:crowNoise()
    end

    self.cricketTimer = self.cricketTimer - dt
    if self.cricketTimer <= 0 then
        self:cricketNoise()
    end
end

function Game:updatePitch(dt)
    local targetPitch = 1
    if Player.life <= 2 then
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
    if self:updateRoomExitTransition(dt) then
        -- Player is controlled by the room-exit sequence.
    elseif not self:updateEntryMove(dt) then
        Player:update(dt)
    end
    DoorsManager:update(dt)
    HeartSound:update(dt)
    Tilemap:update(dt)
    self:checkRoomTransition(dt)
    PointsManager:update(dt)
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

    self.textAlpha = transitionValue(self.textAlpha, self.textAlphaTarget, 5, dt)
    self.textAlphaTarget = 0

    self:updateEntityList(self.enemies, dt)
    self:checkCurrentRoomClear()
    self:refreshNearbyEnemies()
    PlayerCloseStore = false
    self:updateEntityList(self.objects, dt)
    self:updateEntityList(self.particles, dt)
    self:updateFootsteps(dt)
    self:updateWeaponShockwaves(dt)
    self:updateManagers(dt)
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
    self.crowTimer = math.random(20, 50)
    AmbienceSound:playCrowSound()
end

function Game:cricketNoise()
    if not (Player.isAlive and Player.life > 2) then
        return
    end
    self.cricketTimer = math.random(20, 30)
    AmbienceSound:playCricketSound()
end

function Game:drawFootsteps()
    local brightnessByFootstep = {}

    for index, item in ipairs(self.footsteps) do
        local brightness = getPlayerLightBrightness(item)
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
        if type(item.object.drawShadow) == "function" then
            item.object:drawShadow()
        end
    end
end

function Game:drawQueueObjects()
    for _, item in ipairs(self.drawQueue) do
        local brightness = getPlayerLightBrightness(item.object)
        local r, g, b = getShadowTint(brightness)
        love.graphics.setColor(r, g, b, 1)
        item.object:draw()
        love.graphics.setColor(1, 1, 1, 1)
    end
end

function Game:drawLightSprites()
    local width = playerLightImage:getWidth()
    local height = playerLightImage:getHeight()
    local previousBlendMode, previousAlphaMode = love.graphics.getBlendMode()
    love.graphics.setBlendMode("alpha", "alphamultiply")

    for _, source in ipairs(self:getLightSources()) do
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
        if knownRooms[roomId] and shouldShowShopIcon(room) then
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
                drawShopIconAt(iconX, iconY)
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

    self:drawFootsteps()
    self:drawShadows()
    Player:drawSight()
    if not (CURRENT_LEVEL and CURRENT_LEVEL.enableTrails == false) then
        Trail:draw()
    end
    self:drawQueueObjects()
    if CURRENT_LEVEL and CURRENT_LEVEL.drawDebug then
        CURRENT_LEVEL:drawDebug()
    end
    Clouds:draw()

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
end

function Game:draw()
    self:drawWorld()
end

function Game:drawHUD()
    self:drawUI()
end

function DisableMouseTutorial()
    if Tutorial.drawmouse == false then return end
    Tutorial:playSound()
    Tutorial.drawmouse = false
    Tutorial.tutorialTimer = 0
end

function DisableXTutorial()
    if Tutorial.drawX == false then return end
    Tutorial:playSound()
    Tutorial.drawX = false
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
        Tutorial.drawX = false
        Tutorial.drawmouse = false
        Tutorial.tutorialTimer = 0
        state.playerMovedForScarecrowTutorial = true
        return
    end

    if Tutorial.drawWalk == false then return end
    Tutorial:playSound()
    Tutorial.drawWalk = false
    Tutorial.drawX = true
    Tutorial.tutorialTimer = 0
end

function Game:keypressed(key)
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
    elseif key == "tab" or key == "q" then
        if Player and Player.gun then
            Player.gun:toggleWeaponSlot()
        end
    elseif key == "x" then
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

return Game
