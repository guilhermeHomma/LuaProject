local DefaultTilemap = {}

local GameConfig = require("scripts/config/gameConfig")
local FloorManager = require("scripts/managers/floorManager")
local RoomBuilder = require("scripts/rooms/roomBuilder")
local RoomTemplates = require("scripts/rooms/roomTemplates")
local Moonbeam = require("scripts/objects/moonbeam")
local AmbientDust = require("scripts/objects/ambientDust")
local VisualThemes = require("scripts/config/visualThemes")
local Grid = require("jumperj.grid")
local Pathfinder = require("jumperj.pathfinder")

local tileSize = 16
local treeFadeCellSize = 64
local tileUpdateCellSize = 128
local tilemap = nil
local tilemapWorldX = -40 * tileSize
local tilemapWorldY = -40 * tileSize
local wallVariantLookup = {}

require "scripts.utils"
require "scripts.objects.tile"
require "scripts.objects.door"
require "scripts.objects.store"
require "scripts.objects.water"
require "scripts.objects.tree"
require "scripts.objects.grass"
require "scripts.objects.bigGrass"
require "scripts.objects.house"
require "scripts.objects.pole"
require "scripts.objects.counter"
require "scripts.objects.container"
local Chest = require("scripts.objects.chest")
local FloorPath = require("scripts.objects.floorPath")

tileSet = require("scripts.objects.tileset")

local tileDefinitions = {
    { r = 1,   g = 1,   b = 1,   tile = 1 },
    { r = 0,   g = 0,   b = 0,   tile = 0 },
    { r = 1,   g = 0,   b = 0,   tile = 2 },
    { r = 0,   g = 1,   b = 0,   tile = 3 },
    { r = 1,   g = 1,   b = 0,   tile = 4 },
    { r = 0,   g = 0,   b = 1,   tile = 5 },
    { r = 1,   g = 0,   b = 1,   tile = 6 },
    { r = 0.5, g = 1,   b = 1,   tile = 7 },
    { r = 0,   g = 0.5, b = 1,   tile = 8 },
    { r = 127/255, g = 127/255, b = 127/255, tile = 9 },
    { r = 0.5, g = 0.5, b = 0,   tile = 10 },
    { r = 0,   g = 0.5, b = 0.5, tile = 11 },
    { r = 1,   g = 0.5, b = 0.5, tile = 12 },
    { r = 0.5, g = 0,   b = 1,   tile = 13 },
    { r = 127/255, g = 1, b = 127/255, tile = 14 },
}

local TILE_FLOOR = 0
local TILE_BOX = 2
local TILE_DOOR = 4
local TILE_STORE = 7
local TILE_DOOR_BACK = 9
local TILE_CONTAINER = 13
local TILE_CHEST = 15
local TILE_CHEST_MARKER = 6
local GRASS_WALKABLE_RADIUS = 4
local TILE_OBJECT_BORDER_CULL_LAYERS = 3

local function isWalkableTile(tile)
    return tile == TILE_FLOOR or tile == TILE_DOOR_BACK
end

local function isTreeTile(tile)
    return tile == 3 or tile == 14
end

local function isPoleTile(tile)
    return tile == 11
end

local function isWalkableOrChestTile(tile)
    return isWalkableTile(tile) or tile == TILE_CHEST or tile == TILE_CHEST_MARKER
end

local function getTreeFadeCell(value)
    return math.floor(value / treeFadeCellSize)
end

local function getTreeFadeCellKey(cellX, cellY)
    return cellX .. ":" .. cellY
end

local function getSpatialCell(value)
    return math.floor(value / tileUpdateCellSize)
end

local function getSpatialCellKey(cellX, cellY)
    return cellX .. ":" .. cellY
end

local function clearArray(list)
    for i = #list, 1, -1 do
        list[i] = nil
    end
end

local function hasAdjacentWalkableOrChest(x, y, sourceMap)
    return (sourceMap[y] and isWalkableOrChestTile(sourceMap[y][x + 1]))
        or (sourceMap[y] and isWalkableOrChestTile(sourceMap[y][x - 1]))
        or (sourceMap[y + 1] and isWalkableOrChestTile(sourceMap[y + 1][x]))
        or (sourceMap[y - 1] and isWalkableOrChestTile(sourceMap[y - 1][x]))
end

local function applyVisualThemeTileRules(theme)
    if not (theme and tilemap) then
        return
    end

    local replacements = {}
    for y = 1, #tilemap do
        replacements[y] = {}
        for x = 1, #tilemap[y] do
            local tile = tilemap[y][x]
            if theme.hasTrees == false and isTreeTile(tile) then
                replacements[y][x] = hasAdjacentWalkableOrChest(x, y, tilemap) and TILE_FLOOR or 1
            elseif theme.removeSurroundedPoles and isPoleTile(tile)
                and not hasAdjacentWalkableOrChest(x, y, tilemap) then
                replacements[y][x] = 1
            end
        end
    end

    for y = 1, #replacements do
        for x, tile in pairs(replacements[y]) do
            tilemap[y][x] = tile
        end
    end
end

local function canDrawFloorPathOnTile(tile)
    return isWalkableTile(tile) or tile == TILE_DOOR
end

local function isWalkableMapPosition(x, y)
    if not (tilemap and tilemap[y]) then
        return false
    end

    local tile = tilemap[y][x]
    return isWalkableTile(tile)
end

local function isSurroundedByNonWalkableTiles(x, y)
    return not (
        isWalkableMapPosition(x + 1, y)
        or isWalkableMapPosition(x - 1, y)
        or isWalkableMapPosition(x, y + 1)
        or isWalkableMapPosition(x, y - 1)
    )
end

local function isWalkableGroundEdgeTile(tile)
    return tile == TILE_FLOOR
        or tile == 5
        or tile == TILE_CHEST_MARKER
        or tile == TILE_DOOR
        or tile == TILE_DOOR_BACK
        or tile == TILE_CHEST
end

local function hasAdjacentWalkableGroundEdge(x, y)
    return (tilemap[y] and isWalkableGroundEdgeTile(tilemap[y][x + 1]))
        or (tilemap[y] and isWalkableGroundEdgeTile(tilemap[y][x - 1]))
        or (tilemap[y + 1] and isWalkableGroundEdgeTile(tilemap[y + 1][x]))
        or (tilemap[y - 1] and isWalkableGroundEdgeTile(tilemap[y - 1][x]))
end

local function isWallTouchingWalkableGround(x, y)
    return tilemap
        and tilemap[y]
        and tilemap[y][x] == 1
        and hasAdjacentWalkableGroundEdge(x, y)
end

local function buildPathfinderMap(sourceMap)
    local pathMap = {}
    for y = 1, #sourceMap do
        pathMap[y] = {}
        for x = 1, #sourceMap[y] do
            local tile = sourceMap[y][x]
            pathMap[y][x] = isWalkableTile(tile) and 0 or 1
        end
    end
    return pathMap
end

local function getDoorOptions(x, y)
    local backTop = tilemap[y - 1] and tilemap[y - 1][x] == TILE_DOOR_BACK
    local backBottom = tilemap[y + 1] and tilemap[y + 1][x] == TILE_DOOR_BACK
    local backLeft = tilemap[y] and tilemap[y][x - 1] == TILE_DOOR_BACK
    local backRight = tilemap[y] and tilemap[y][x + 1] == TILE_DOOR_BACK

    local doorLeft = tilemap[y] and tilemap[y][x - 1] == TILE_DOOR
    local doorRight = tilemap[y] and tilemap[y][x + 1] == TILE_DOOR
    local doorTop = tilemap[y - 1] and tilemap[y - 1][x] == TILE_DOOR
    local doorBottom = tilemap[y + 1] and tilemap[y + 1][x] == TILE_DOOR

    if backTop then
        local pairX = doorLeft and (x - 1) or x
        return {
            pairKey = "h:" .. pairX .. ":" .. y,
            frameSet = "top",
            reverse = false,
            mirrored = doorLeft,
        }
    end

    if backBottom then
        local pairX = doorLeft and (x - 1) or x
        return {
            pairKey = "h:" .. pairX .. ":" .. y,
            frameSet = "bottom",
            reverse = false,
            mirrored = doorLeft,
        }
    end

    if backLeft or backRight then
        local pairY = doorTop and (y - 1) or y
        local isTopDoor = doorBottom
        local isRightSide = backLeft
        return {
            pairKey = "v:" .. x .. ":" .. pairY,
            frameSet = isTopDoor and "sideTop" or "sideBottom",
            closedFrame = isTopDoor and 6 or 3,
            openFrame = isTopDoor and 3 or 1,
            frameSequence = isTopDoor and {6, 5, 4} or {3, 2, 1},
            frameSpeed = 8,
            reverse = false,
            mirrored = isRightSide,
            ySortOffset = isTopDoor and -6 or 0,
        }
    end

    return {
        pairKey = "single:" .. x .. ":" .. y,
        frameSet = "top",
        reverse = false,
        mirrored = doorLeft,
    }
end

local function loadTilemapFromImage(imagePath)
    local imageData = love.image.newImageData(imagePath)
    local width, height = imageData:getDimensions()
    local tilemapLoad = {}

    for y = 1, height do
        tilemapLoad[y] = {}
        for x = 1, width do
            local r, g, b = imageData:getPixel(x - 1, y - 1)
            local found = false

            for _, def in ipairs(tileDefinitions) do
                if isColorMatch(r, g, b, def) then
                    tilemapLoad[y][x] = def.tile
                    found = true
                    break
                end
            end

            if not found then
                tilemapLoad[y][x] = 0
            end
        end
    end

    return tilemapLoad, width, height
end

local function getActiveTilemapConfig()
    return FloorManager:getCurrentTilemapConfig() or GameConfig.tilemapConfig
end

local function currentThemeAllowsWallGrass()
    local theme = FloorManager:getCurrentRoomTheme()
    return not theme or theme.wallGrass ~= false
end

local function isGrassBlockingObjectTile(tile)
    return tile == TILE_CHEST
        or tile == TILE_CHEST_MARKER
        or tile == TILE_STORE
        or tile == TILE_BOX
        or tile == TILE_CONTAINER
end

local function hasWalkableTileWithin(x, y, radius)
    local radiusSq = radius * radius
    for checkY = y - radius, y + radius do
        local row = tilemap[checkY]
        if row then
            for checkX = x - radius, x + radius do
                local dx = checkX - x
                local dy = checkY - y
                if dx * dx + dy * dy <= radiusSq and isWalkableTile(row[checkX]) then
                    return true
                end
            end
        end
    end

    return false
end

local function shouldCreateTileObject(tile, x, y)
    if tile == TILE_FLOOR or tile == TILE_DOOR_BACK then
        return false
    end

    if tile == TILE_DOOR or tile == TILE_STORE or tile == TILE_CHEST then
        return true
    end

    local mapHeight = #tilemap
    local mapWidth = tilemap[1] and #tilemap[1] or 0
    local border = TILE_OBJECT_BORDER_CULL_LAYERS
    if x <= border or y <= border or x > mapWidth - border or y > mapHeight - border then
        return false
    end

    return true
end

local function isNearGrassBlockingObject(x, y)
    local neighbors = {
        {x = x, y = y},
        {x = x + 1, y = y},
        {x = x - 1, y = y},
        {x = x, y = y + 1},
        {x = x, y = y - 1},
    }

    for _, position in ipairs(neighbors) do
        local tile = tilemap[position.y] and tilemap[position.y][position.x]
        if isGrassBlockingObjectTile(tile) then
            return true
        end
    end

    return false
end

local function shouldCreateGrass(tile, collider, x, y)
    if isNearGrassBlockingObject(x, y) then
        return false
    end
    if not hasWalkableTileWithin(x, y, GRASS_WALKABLE_RADIUS) then
        return false
    end

    local canUseTile = tile == 0 or tile == 5 or tile == 6
    if tile == 1 and currentThemeAllowsWallGrass() and not isWallTouchingWalkableGround(x, y) then
        canUseTile = true
    end

    return canUseTile and math.random() > 0.86
end

local function getTileKey(x, y)
    return x .. ":" .. y
end

local function isWeaponTestLevel()
    return GAME_FLAGS and GAME_FLAGS.weaponTestLevel == true
end

local function isStartRoom(room)
    local level = FloorManager.level
    local startRoomId = level and level.floorConfig and level.floorConfig.startRoomId or "0:0"
    return room and room.id == startRoomId
end

local function buildTransitionLookup(transitions)
    local lookup = {}
    for _, transition in ipairs(transitions or {}) do
        lookup[getTileKey(transition.x, transition.y)] = transition
    end
    return lookup
end

local function applyPersistedRoomState()
    local state = FloorManager:getCurrentRoomState()
    if not (state and state.brokenObjects) then
        return
    end

    for y = 1, #tilemap do
        for x = 1, #tilemap[y] do
            if tilemap[y][x] == 2 and state.brokenObjects[getTileKey(x, y)] then
                tilemap[y][x] = TILE_FLOOR
            end
        end
    end
end

local function applyRoomShopState()
    local room = FloorManager:getCurrentRoom()
    local state = FloorManager:getCurrentRoomState()

    if isWeaponTestLevel() and isStartRoom(room) then
        local testStores = {
            {x = 12, y = 13, product = "shotgun"},
            {x = 14, y = 13, product = "raygun"},
            {x = 19, y = 13, product = "squaregun"},
            {x = 23, y = 13, product = "longshot"},
            {x = 21, y = 13, product = "cakegun"},
            {x = 15, y = 15, product = "card_upgrade"},
        }

        if state then
            state.weaponTestShopProducts = {}
        end

        for _, store in ipairs(testStores) do
            if tilemap[store.y] and (tilemap[store.y][store.x] == TILE_FLOOR or tilemap[store.y][store.x] == 2) then
                tilemap[store.y][store.x] = TILE_STORE
                if state then
                    state.weaponTestShopProducts[getTileKey(store.x, store.y)] = store.product
                end
            end
        end

        return
    end

    local storeTiles = {}
    for y = 1, #tilemap do
        for x = 1, #tilemap[y] do
            if tilemap[y][x] == TILE_STORE then
                storeTiles[#storeTiles + 1] = {x = x, y = y}
            end
        end
    end

    if #storeTiles == 0 then
        return
    end

    local products = FloorManager:resolveCurrentRoomShopProducts()

    if not products or #products == 0 then
        for _, storeTile in ipairs(storeTiles) do
            tilemap[storeTile.y][storeTile.x] = TILE_FLOOR
        end
        return
    end

    if state and not state.shopTileProducts then
        state.shopTileProducts = {}
        local availableTiles = {}
        for _, storeTile in ipairs(storeTiles) do
            availableTiles[#availableTiles + 1] = {x = storeTile.x, y = storeTile.y}
        end
        for _, productId in ipairs(products) do
            if #availableTiles == 0 then
                break
            end

            local selectedIndex = math.random(1, #availableTiles)
            local selected = table.remove(availableTiles, selectedIndex)
            state.shopTileProducts[getTileKey(selected.x, selected.y)] = productId
        end
    end

    local selectedProducts = state and state.shopTileProducts or {}

    for _, storeTile in ipairs(storeTiles) do
        if not selectedProducts[getTileKey(storeTile.x, storeTile.y)] then
            tilemap[storeTile.y][storeTile.x] = TILE_FLOOR
        end
    end
end

local function getObjectSpawnChance(objectId)
    local currentRoom = FloorManager:getCurrentRoom()
    local templateId = currentRoom and currentRoom.templateId
    local templateChances = CURRENT_LEVEL and CURRENT_LEVEL.objectSpawnChancesByTemplate
    local templateChance = templateId and templateChances and templateChances[templateId] and templateChances[templateId][objectId]
    if templateChance ~= nil then
        return math.min(math.max(templateChance, 0), 1)
    end

    local chances = CURRENT_LEVEL and CURRENT_LEVEL.objectSpawnChances
    local chance = chances and chances[objectId]

    if chance == nil then
        if objectId == "chest" then
            return 0
        end
        return 1
    end

    return math.min(math.max(chance, 0), 1)
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

local function mergeTables(base, overrides)
    local result = copyTable(base) or {}
    for key, value in pairs(overrides or {}) do
        result[key] = copyTable(value)
    end
    return result
end

local function randomRange(minValue, maxValue)
    return minValue + math.random() * (maxValue - minValue)
end

local function randomRangeInt(range, fallbackMin, fallbackMax)
    if type(range) ~= "table" then
        return range or fallbackMin or 1
    end

    local minValue = math.floor(range.min or range[1] or fallbackMin or 1)
    local maxValue = math.floor(range.max or range[2] or fallbackMax or minValue)
    if maxValue < minValue then
        minValue, maxValue = maxValue, minValue
    end

    return math.random(minValue, maxValue)
end

local function getRoomEncounterOverride(config, room)
    local overrides = config and (config.templateOverrides or config.templateEncounters)
    local templateId = room and room.templateId
    return templateId and overrides and overrides[templateId] or nil
end

local function hasRoomEncounter(room)
    local state = room and room.state
    local encounterConfig = CURRENT_LEVEL and CURRENT_LEVEL.roomEncounterConfig
    if not (room and state and encounterConfig and encounterConfig.enabled) then
        return false
    end

    if room.isShopRoom then
        state.skipEncounter = true
        state.cleared = true
        state.encounterCompleted = true
        return false
    end

    if room.templateId == "start_32x32" and encounterConfig.startRoom == false then
        return false
    end

    if state.cleared and state.encounterCompleted then
        return false
    end

    if state.skipEncounter == nil then
        local override = getRoomEncounterOverride(encounterConfig, room)
        local emptyChance = override and override.emptyChance or 0
        state.skipEncounter = emptyChance > 0 and math.random() < emptyChance
    end

    return state.skipEncounter ~= true
end

local function getMoonbeamConfig(room)
    local template = room and room.templateId and RoomTemplates:get(room.templateId)
    local config = template and template.moonbeams

    if CURRENT_LEVEL and CURRENT_LEVEL.moonbeamConfig then
        config = mergeTables(config, CURRENT_LEVEL.moonbeamConfig)
    end

    local templateOverrides = CURRENT_LEVEL and CURRENT_LEVEL.moonbeamConfigByTemplate
    local templateOverride = room and room.templateId and templateOverrides and templateOverrides[room.templateId]
    if templateOverride then
        config = mergeTables(config, templateOverride)
    end

    return config
end

local function getAmbientDustConfig(room)
    local template = room and room.templateId and RoomTemplates:get(room.templateId)
    local config = template and template.ambientDust

    if CURRENT_LEVEL and CURRENT_LEVEL.ambientDustConfig then
        config = mergeTables(config, CURRENT_LEVEL.ambientDustConfig)
    end

    local templateOverrides = CURRENT_LEVEL and CURRENT_LEVEL.ambientDustConfigByTemplate
    local templateOverride = room and room.templateId and templateOverrides and templateOverrides[room.templateId]
    if templateOverride then
        config = mergeTables(config, templateOverride)
    end

    local theme = FloorManager:getCurrentRoomTheme()
    if theme and theme.ambientDust then
        config = mergeTables(config, theme.ambientDust)
    end

    return config or {
        enabled = true,
        count = 28,
        anchorCount = 34,
    }
end

local function isMoonbeamCandidateTile(x, y)
    return tilemap and tilemap[y] and tilemap[y][x] == TILE_FLOOR
end

local function collectMoonbeamCandidates(tilemapSystem, trees, config)
    local candidates = {}
    local used = {}
    local radiusTiles = math.max(1, math.floor(config.treeDistanceTiles or 3))
    local radiusSq = radiusTiles * radiusTiles

    for _, tree in ipairs(trees or {}) do
        for offsetY = -radiusTiles, radiusTiles do
            for offsetX = -radiusTiles, radiusTiles do
                if offsetX * offsetX + offsetY * offsetY <= radiusSq then
                    local x = tree.x + offsetX
                    local y = tree.y + offsetY
                    local key = getTileKey(x, y)
                    if not used[key] and isMoonbeamCandidateTile(x, y) then
                        local worldX, worldY = tilemapSystem:mapToWorld(x, y)
                        candidates[#candidates + 1] = {
                            x = worldX + randomRange(-5, 5),
                            y = worldY + randomRange(-3, 5),
                        }
                        used[key] = true
                    end
                end
            end
        end
    end

    return candidates
end

local function isFarFromMoonbeams(candidate, moonbeams, minDistance)
    local minDistanceSq = minDistance * minDistance
    for _, beam in ipairs(moonbeams) do
        local dx = candidate.x - beam.x
        local dy = candidate.y - beam.y
        if dx * dx + dy * dy < minDistanceSq then
            return false
        end
    end

    return true
end

local function chooseMoonbeamCandidate(candidates, moonbeams, minDistance)
    if #candidates == 0 then
        return nil
    end

    for _ = 1, 80 do
        local candidate = candidates[math.random(1, #candidates)]
        if isFarFromMoonbeams(candidate, moonbeams, minDistance) then
            return candidate
        end
    end

    return candidates[math.random(1, #candidates)]
end

local function hasMoonbeamTarget(moonbeams, targetKey)
    if not targetKey then
        return false
    end

    for _, beam in ipairs(moonbeams or {}) do
        if beam.targetKey == targetKey then
            return true
        end
    end

    return false
end

local function appendMoonbeamEntry(moonbeams, x, y, config, targetKey)
    moonbeams[#moonbeams + 1] = {
        x = x,
        y = y,
        width = randomRange(config.widthMin or 50, config.widthMax or 74),
        length = randomRange(config.lengthMin or 110, config.lengthMax or 160),
        groundGap = randomRange(config.groundGapMin or 10, config.groundGapMax or 18),
        targetKey = targetKey,
    }
end

local function appendSpecialTargetMoonbeams(moonbeams, specialTargets, config)
    for _, target in ipairs(specialTargets or {}) do
        if not hasMoonbeamTarget(moonbeams, target.key) then
            appendMoonbeamEntry(moonbeams, target.x, target.y, config, target.key)
        end
    end
end

local function getLooseMoonbeamCount(config, specialTargetCount)
    local count = randomRangeInt(config.count, 1, 2)
    local reduction = math.floor((specialTargetCount or 0) / (config.specialTargetReductionEvery or 2))
    return math.max(config.minLooseCount or 0, count - reduction)
end

local function shouldKeepOptionalObject(objectId, x, y)
    local chance = getObjectSpawnChance(objectId)
    if chance >= 1 then
        return true
    end

    if chance <= 0 then
        return false
    end

    local state = FloorManager:getCurrentRoomState()
    if not state then
        return math.random() < chance
    end

    state.optionalObjects = state.optionalObjects or {}
    local key = objectId .. ":" .. getTileKey(x, y)

    if state.optionalObjects[key] == nil then
        state.optionalObjects[key] = math.random() < chance
    end

    return state.optionalObjects[key] == true
end

local function chooseChestType(x, y)
    local room = FloorManager:getCurrentRoom()
    if room and room.isCardRoom then
        local state = FloorManager:getCurrentRoomState()
        if not state then
            return "card"
        end

        state.cardChestTiles = state.cardChestTiles or {}
        if not state.cardChestResolved then
            state.cardChestResolved = true
            local chestMarkers = {}
            for markerY = 1, #tilemap do
                for markerX = 1, #tilemap[markerY] do
                    if tilemap[markerY][markerX] == TILE_CHEST_MARKER then
                        chestMarkers[#chestMarkers + 1] = {x = markerX, y = markerY}
                    end
                end
            end

            local shopConfig = CURRENT_LEVEL and CURRENT_LEVEL.shopConfig or {}
            local chestCount = math.random() < (shopConfig.cardChestSecondChance or 0.10) and 2 or 1
            for _ = 1, math.min(chestCount, #chestMarkers) do
                local selectedIndex = math.random(1, #chestMarkers)
                local selected = table.remove(chestMarkers, selectedIndex)
                state.cardChestTiles[getTileKey(selected.x, selected.y)] = true
            end
        end

        return state.cardChestTiles[getTileKey(x, y)] and "card" or nil
    end

    if not shouldKeepOptionalObject("chest", x, y) then
        return nil
    end

    return "wood"
end

local function applyOptionalObjectSpawnChances()
    for y = 1, #tilemap do
        for x = 1, #tilemap[y] do
            if tilemap[y][x] == 2 then
                if not shouldKeepOptionalObject("box", x, y) then
                    tilemap[y][x] = TILE_FLOOR
                end
            elseif tilemap[y][x] == TILE_CHEST_MARKER then
                local chestType = chooseChestType(x, y)
                if chestType then
                    tilemap[y][x] = TILE_CHEST
                    local state = FloorManager:getCurrentRoomState()
                    if state then
                        state.chestTypes = state.chestTypes or {}
                        state.chestTypes[getTileKey(x, y)] = chestType
                    end
                else
                    tilemap[y][x] = TILE_FLOOR
                end
            end
        end
    end
end

local function hasTileWithin(x, y, tileIndex, radius)
    for checkY = y - radius, y + radius do
        if tilemap[checkY] then
            for checkX = x - radius, x + radius do
                if tilemap[checkY][checkX] == tileIndex then
                    return true
                end
            end
        end
    end

    return false
end

local function hasTreeNearby(x, y)
    return hasTileWithin(x, y, 3, 2) or hasTileWithin(x, y, 14, 2)
end

local function isFloorNearWall(x, y)
    return tilemap[y] and (tilemap[y][x] == 0 or tilemap[y][x] == 5 or tilemap[y][x] == 6) and (
        DefaultTilemap:hasTileClose(x, y, 1) or
        DefaultTilemap:hasTileClose(x, y, 2) or
        DefaultTilemap:hasTileClose(x, y, 3) or
        DefaultTilemap:hasTileClose(x, y, 4) or
        DefaultTilemap:hasTileClose(x, y, 10) or
        DefaultTilemap:hasTileClose(x, y, 11) or
        DefaultTilemap:hasTileClose(x, y, 12) or
        DefaultTilemap:hasTileClose(x, y, 13) or
        DefaultTilemap:hasTileClose(x, y, 14)
    )
end

local function shouldCreateBigGrass(tile, collider, x, y, occupied)
    if isNearGrassBlockingObject(x, y) then
        return false
    end
    if not hasWalkableTileWithin(x, y, GRASS_WALKABLE_RADIUS) then
        return false
    end

    return (tile == 0 or tile == 5 or tile == 6) and isFloorNearWall(x, y) and not occupied[getTileKey(x, y)] and math.random() < 0.05
end

local function shouldCreateDecorativeBigGrass(tile, collider, x, y, occupied)
    if isNearGrassBlockingObject(x, y) then
        return false
    end
    if not hasWalkableTileWithin(x, y, GRASS_WALKABLE_RADIUS) then
        return false
    end

    return tile == 1
        and currentThemeAllowsWallGrass()
        and not collider
        and not isWallTouchingWalkableGround(x, y)
        and hasTreeNearby(x, y)
        and not occupied[getTileKey(x, y)]
        and math.random() < 0.05
end

local function canCreateBigGrassAt(x, y, occupied)
    if not tilemap[y] or not tilemap[y][x] or occupied[getTileKey(x, y)] then
        return false
    end

    return not isNearGrassBlockingObject(x, y) and hasWalkableTileWithin(x, y, GRASS_WALKABLE_RADIUS) and isFloorNearWall(x, y)
end

local function canCreateDecorativeBigGrassAt(x, y, occupied)
    if not tilemap[y] or not tilemap[y][x] or occupied[getTileKey(x, y)] then
        return false
    end

    return currentThemeAllowsWallGrass()
        and not isNearGrassBlockingObject(x, y)
        and hasWalkableTileWithin(x, y, GRASS_WALKABLE_RADIUS)
        and tilemap[y][x] == 1
        and not isWallTouchingWalkableGround(x, y)
        and not (
            DefaultTilemap:hasTileClose(x, y, 0) or
            DefaultTilemap:hasTileClose(x, y, 5) or
            DefaultTilemap:hasTileClose(x, y, 6) or
            DefaultTilemap:hasTileClose(x, y, 8) or
            DefaultTilemap:hasTileClose(x, y, 4) or
            DefaultTilemap:hasTileClose(x, y, 9) or
            DefaultTilemap:hasTileClose(x, y, 2) or
            DefaultTilemap:hasTileClose(x, y, 11)
        )
end

local function randomGrassIndex(tile)
    if tile == 1 then
        if math.random() < 0.1 then return 1 end
        if math.random() < 0.6 then return 3 end
        if math.random() < 0.04 then return 2 end
        return 4
    end

    if math.random() < 0.8 then return 1 end
    if math.random() < 0.4 then return 3 end
    if math.random() < 0.05 then return 2 end
    return 4
end

local function canRenderGrassEntry(entry)
    local tile = tilemap[entry.y] and tilemap[entry.y][entry.x]
    if not tile then
        return false
    end
    if not hasWalkableTileWithin(entry.x, entry.y, GRASS_WALKABLE_RADIUS) then
        return false
    end

    if tile == 1 then
        return currentThemeAllowsWallGrass() and not isWallTouchingWalkableGround(entry.x, entry.y)
    end

    return true
end

local function appendGrassState(entries, x, y, worldX, worldY, tile)
    entries[#entries + 1] = {
        x = x,
        y = y,
        offsetX = 0,
        offsetY = -5,
        tile = tile,
        index = randomGrassIndex(tile),
    }
    if tile ~= 1 and math.random() > 0.3 then
        entries[#entries + 1] = {
            x = x,
            y = y,
            offsetX = 1,
            offsetY = 2,
            tile = tile,
            index = randomGrassIndex(tile),
        }
    end
end

local function randomBigGrassBlades()
    local blades = {}
    local bladeCount = math.random(1, 3)
    local ySlots = {0}
    if bladeCount == 2 then
        ySlots = {-2, 2}
    elseif bladeCount == 3 then
        ySlots = {-4, 0, 4}
    end

    for i = 1, bladeCount do
        local direction = math.random() > 0.5 and 1 or -1
        blades[i] = {
            x = direction * math.random(0, 2),
            y = ySlots[i],
            flipH = math.random() > 0.5,
            directionOffset = (math.random() - 0.5) * 0.25,
        }
    end

    return blades
end

local function appendBigGrassState(entries, x, y, options)
    entries[#entries + 1] = {
        x = x,
        y = y,
        options = mergeTables(options or {}, {
            phase = math.random() * math.pi * 2,
            drawPriority = math.random() * 0.1,
            blades = randomBigGrassBlades(),
        }),
    }
end

local function appendBigGrassCluster(bigGrassList, startX, startY, occupied, canCreate, options, minCount, maxCount)
    local targetCount = math.random(minCount or 2, maxCount or 5)
    local candidates = {
        {x = startX, y = startY},
        {x = startX + 1, y = startY},
        {x = startX - 1, y = startY},
        {x = startX, y = startY + 1},
        {x = startX, y = startY - 1},
        {x = startX + 1, y = startY + 1},
        {x = startX - 1, y = startY - 1},
        {x = startX + 1, y = startY - 1},
        {x = startX - 1, y = startY + 1}
    }
    local created = 0

    while created < targetCount and #candidates > 0 do
        local index = math.random(1, #candidates)
        local candidate = table.remove(candidates, index)
        local x = candidate.x
        local y = candidate.y

        if canCreate(x, y, occupied) then
            occupied[getTileKey(x, y)] = true
            created = created + 1

            appendBigGrassState(bigGrassList, x, y, options)
        end
    end
end

local function buildFloorPathState()
    local room = FloorManager:getCurrentRoom()
    local state = room and room.state
    local floorPathVersion = 5
    if not state then
        return {}
    end

    if state.floorPathTiles and state.floorPathVersion == floorPathVersion then
        return state.floorPathTiles
    end

    state.floorPathTiles = {}
    state.floorPathVersion = floorPathVersion
    local baseConfig = (CURRENT_LEVEL and CURRENT_LEVEL.floorPathTiles) or {}
    local templateOverride = room
        and room.templateId
        and baseConfig.templateOverrides
        and baseConfig.templateOverrides[room.templateId]
        or nil
    local config = mergeTables(baseConfig, templateOverride)
    local pathChance = config.pathChance or 0.78
    local bendChance = config.bendChance or 0.32
    local sideTileChance = config.sideTileChance or 0.28
    local branchChance = config.branchChance or 0.18
    local branchMin = config.branchMin or 2
    local branchMax = config.branchMax or 5
    local looseChance = config.looseChance or 0.006
    local used = {}
    local hollowClearCenterX = room and room.isEndRoom and (#(tilemap[1] or {}) + 1) / 2 or nil
    local hollowClearCenterY = room and room.isEndRoom and (#tilemap + 1) / 2 or nil

    local function addPathTile(x, y)
        local key = getTileKey(x, y)
        if used[key] or not (tilemap[y] and canDrawFloorPathOnTile(tilemap[y][x])) then
            return false
        end
        if hollowClearCenterX
            and math.abs(x - hollowClearCenterX) <= 2
            and math.abs(y - hollowClearCenterY) <= 2 then
            return false
        end

        used[key] = true
        state.floorPathTiles[#state.floorPathTiles + 1] = {
            x = x,
            y = y,
            quadIndex = math.random(19, 22),
        }
        return true
    end

    local function getRoomCenterTile()
        local totalX, totalY, count = 0, 0, 0

        for y = 1, #tilemap do
            for x = 1, #tilemap[y] do
                if tilemap[y][x] == TILE_FLOOR then
                    totalX = totalX + x
                    totalY = totalY + y
                    count = count + 1
                end
            end
        end

        if count == 0 then
            return math.floor(#tilemap[1] / 2), math.floor(#tilemap / 2)
        end

        return math.floor(totalX / count + 0.5), math.floor(totalY / count + 0.5)
    end

    local function getDoorPathPoints()
        local points = {}

        for direction, enabled in pairs(room.doors or {}) do
            if enabled then
                local slot = RoomBuilder:getDoorSlot(room, direction)
                local spawn = slot and slot.playerSpawn
                if spawn then
                    local x, y = RoomBuilder:toMapPosition(spawn)
                    points[#points + 1] = {
                        x = math.floor(x + 0.5),
                        y = math.floor(y + 0.5),
                        direction = direction,
                    }
                end

                for _, position in ipairs(slot.backTiles or {}) do
                    local backX, backY = RoomBuilder:toMapPosition(position)
                    addPathTile(backX, backY)
                end
            end
        end

        return points
    end

    local function addLooseSideTile(x, y, previousX, previousY)
        if math.random() >= sideTileChance then
            return
        end

        local dx = x - previousX
        local dy = y - previousY
        local sideX, sideY

        if math.abs(dx) > math.abs(dy) then
            sideX = x
            sideY = y + (math.random(0, 1) == 0 and -1 or 1)
        else
            sideX = x + (math.random(0, 1) == 0 and -1 or 1)
            sideY = y
        end

        addPathTile(sideX, sideY)
    end

    local function addBranch(x, y, previousX, previousY)
        if math.random() >= branchChance then
            return
        end

        local dx = x - previousX
        local dy = y - previousY
        local branchX = x
        local branchY = y
        local branchDx, branchDy

        if math.abs(dx) > math.abs(dy) then
            branchDx = 0
            branchDy = math.random(0, 1) == 0 and -1 or 1
        else
            branchDx = math.random(0, 1) == 0 and -1 or 1
            branchDy = 0
        end

        for _ = 1, math.random(branchMin, branchMax) do
            branchX = branchX + branchDx
            branchY = branchY + branchDy
            if math.random() < pathChance then
                addPathTile(branchX, branchY)
            end
        end
    end

    local function carvePath(startX, startY, targetX, targetY)
        local x = startX
        local y = startY
        local safety = (#tilemap + #(tilemap[1] or {})) * 3

        if math.random() < pathChance then
            addPathTile(x, y)
        end

        while (x ~= targetX or y ~= targetY) and safety > 0 do
            safety = safety - 1
            local previousX = x
            local previousY = y
            local moveX = x ~= targetX
            local moveY = y ~= targetY

            if moveX and moveY then
                moveX = math.random() < 0.5
                moveY = not moveX
            end

            if math.random() < bendChance then
                if not moveX and x ~= targetX then
                    moveX = true
                    moveY = false
                elseif not moveY and y ~= targetY then
                    moveX = false
                    moveY = true
                end
            end

            if moveX then
                x = x + (targetX > x and 1 or -1)
            elseif moveY then
                y = y + (targetY > y and 1 or -1)
            end

            if math.random() < pathChance then
                addPathTile(x, y)
            end

            addLooseSideTile(x, y, previousX, previousY)
            addBranch(x, y, previousX, previousY)
        end
    end

    local centerX, centerY = getRoomCenterTile()
    local doorPoints = getDoorPathPoints()

    if #doorPoints > 0 then
        for _, point in ipairs(doorPoints) do
            carvePath(point.x, point.y, centerX, centerY)
        end
    end

    for y = 1, #tilemap do
        for x = 1, #tilemap[y] do
            if isWalkableTile(tilemap[y][x]) and math.random() < looseChance then
                addPathTile(x, y)
            end
        end
    end

    return state.floorPathTiles
end

local wallVariantByBaseIndex = {
    [1] = 31,
    [2] = 32,
    [3] = 33,
    [4] = 34,
    [5] = 35,
    [6] = 36,
    [7] = 37,
    [8] = 38,
    [9] = 39,
    [10] = 40,
    [11] = 41,
    [12] = 42,
    [13] = 43,
}

local specialWallByBaseIndex = {
    [1] = 44,
    [2] = 45,
    [3] = 46,
    [4] = 47,
    [5] = 48,
    [6] = 49,
    [7] = 50,
    [8] = 51,
    [9] = 52,
    [10] = 53,
    [11] = 54,
    [12] = 55,
    [13] = 56,
}

local function isSpecialWallNeighborTile(x, y)
    local tile = tilemap[y] and tilemap[y][x]
    if tile == TILE_FLOOR
        or tile == TILE_DOOR_BACK
        or tile == TILE_DOOR
        or tile == 2 then
        return true
    end

    local state = FloorManager:getCurrentRoomState()
    for _, pathTile in ipairs((state and state.floorPathTiles) or {}) do
        if pathTile.x == x and pathTile.y == y then
            return true
        end
    end

    return false
end

local function shouldUseSpecialWallTile(x, y)
    for offsetY = -1, 1 do
        for offsetX = -1, 1 do
            if (offsetX ~= 0 or offsetY ~= 0)
                and isSpecialWallNeighborTile(x + offsetX, y + offsetY) then
                return true
            end
        end
    end

    return false
end

local function buildWallVariantState()
    local room = FloorManager:getCurrentRoom()
    local state = room and room.state
    local wallVariantVersion = 2
    if not state then
        return {}
    end

    if state.wallVariantTiles and state.wallVariantVersion == wallVariantVersion then
        return state.wallVariantTiles
    end

    state.wallVariantTiles = {}
    state.wallVariantVersion = wallVariantVersion

    local config = (CURRENT_LEVEL and CURRENT_LEVEL.wallVariantTiles) or {}
    local coverage = config.coverage or config.chance or 0.18
    local noise = config.noise or 0.12
    local patchMin = config.patchMin or 8
    local patchMax = config.patchMax or 22
    local branchChance = config.branchChance or 0.72
    local maxAttempts = config.maxAttempts or 80
    local used = {}
    local wallTiles = {}

    local function isWallTile(x, y)
        return tilemap[y] and tilemap[y][x] == 1
    end

    for y = 1, #tilemap do
        for x = 1, #tilemap[y] do
            if tilemap[y][x] == 1 then
                wallTiles[#wallTiles + 1] = {x = x, y = y}
            end
        end
    end

    local targetCount = math.floor(#wallTiles * coverage + 0.5)
    local created = 0
    local attempts = 0

    while created < targetCount and attempts < maxAttempts and #wallTiles > 0 do
        attempts = attempts + 1
        local start = wallTiles[math.random(1, #wallTiles)]
        local queue = {{x = start.x, y = start.y}}
        local patchTarget = math.random(patchMin, patchMax)
        local patchCreated = 0

        while #queue > 0 and patchCreated < patchTarget and created < targetCount do
            local current = table.remove(queue, math.random(1, #queue))
            local key = getTileKey(current.x, current.y)

            if isWallTile(current.x, current.y) and not used[key] then
                used[key] = true
                state.wallVariantTiles[key] = true
                patchCreated = patchCreated + 1
                created = created + 1

                local neighbors = {
                    {x = current.x + 1, y = current.y},
                    {x = current.x - 1, y = current.y},
                    {x = current.x, y = current.y + 1},
                    {x = current.x, y = current.y - 1},
                }

                for _, neighbor in ipairs(neighbors) do
                    if math.random() < branchChance
                        and isWallTile(neighbor.x, neighbor.y)
                        and not used[getTileKey(neighbor.x, neighbor.y)] then
                        queue[#queue + 1] = neighbor
                    end
                end
            end
        end
    end

    for _, wall in ipairs(wallTiles) do
        local key = getTileKey(wall.x, wall.y)
        if not used[key] and math.random() < noise then
            state.wallVariantTiles[key] = true
        end
    end

    return state.wallVariantTiles
end

function DefaultTilemap:getTilemap()
    return tilemap
end

function DefaultTilemap:getRoomTransitionAt(worldX, worldY)
    if not self.roomTransitions then
        return nil
    end

    local mapX, mapY = self:worldToMap(worldX, worldY)
    local transition = self.roomTransitions[getTileKey(mapX, mapY)]
    if transition and tilemap[mapY] and tilemap[mapY][mapX] == TILE_DOOR then
        return nil
    end

    return transition
end

local function getSlotDoorPositions(room, direction)
    local slot = RoomBuilder:getDoorSlot(room, direction)
    local positions = {}

    for _, position in ipairs((slot and slot.doorTiles) or {}) do
        local x, y = RoomBuilder:toMapPosition(position)
        positions[getTileKey(x, y)] = {x = x, y = y}
    end

    return positions
end

function DefaultTilemap:setDoorOpen(direction, open, animate, options)
    local room = FloorManager:getCurrentRoom()
    local doorPositions = getSlotDoorPositions(room, direction)
    local changed = false

    for _, tile in ipairs(self.tiles or {}) do
        local key = getTileKey(tile.x, tile.y)
        if doorPositions[key] and tile.openDoor and tile.closeDoor then
            if open then
                tile:openDoor()
                if tilemap[tile.y] then
                    tilemap[tile.y][tile.x] = TILE_FLOOR
                end
            else
                if animate and tile.startClosing then
                    tile:startClosing(options)
                else
                    tile:closeDoor()
                end
                if tilemap[tile.y] then
                    tilemap[tile.y][tile.x] = TILE_DOOR
                end
            end
            self:updatePathfinderTile(tile.x, tile.y)
            changed = true
        end
    end
end

function DefaultTilemap:setAllRoomDoorsOpen(open, animate, options)
    local room = FloorManager:getCurrentRoom()
    local changed = false

    for direction, enabled in pairs((room and room.doors) or {}) do
        if enabled then
            local doorPositions = getSlotDoorPositions(room, direction)
            for _, tile in ipairs(self.tiles or {}) do
                local key = getTileKey(tile.x, tile.y)
                if doorPositions[key] and tile.openDoor and tile.closeDoor then
                    if open then
                        tile:openDoor()
                        if tilemap[tile.y] then
                            tilemap[tile.y][tile.x] = TILE_FLOOR
                        end
                    else
                        if animate and tile.startClosing then
                            tile:startClosing(options)
                        else
                            tile:closeDoor()
                        end
                        if tilemap[tile.y] then
                            tilemap[tile.y][tile.x] = TILE_DOOR
                        end
                    end
                    self:updatePathfinderTile(tile.x, tile.y)
                    changed = true
                end
            end
        end
    end
end

function DefaultTilemap:mapToWorld(x, y)
    local xWorld = tilemapWorldX + (x - 1) * tileSize
    local yWorld = tilemapWorldY + (y - 1) * tileSize
    return xWorld, yWorld + tileSize / 2
end

function DefaultTilemap:worldToMap(x, y)
    local xMap = math.floor((x - tilemapWorldX) / tileSize + 0.5) + 1
    local yMap = math.floor((y - tilemapWorldY) / tileSize + 0.5) + 1
    return xMap, yMap
end

function DefaultTilemap:getTileAtMapPosition(x, y)
    local row = tilemap and tilemap[y]
    if not (row and row[x] ~= nil) then
        return nil
    end

    local lookupRow = self.tileLookupByMap and self.tileLookupByMap[y]
    local tile = lookupRow and lookupRow[x]
    if tile then
        return tile
    end

    local staticRow = self.staticTileInfo and self.staticTileInfo[y]
    return staticRow and staticRow[x] or nil
end

function DefaultTilemap:buildTileQueryCache()
    self.staticTileInfo = {}
    self.nearbyTileCache = {}
    self.nearbyCollidableTileCache = {}
    self.tileLookupByMap = self.tileLookupByMap or {}

    for y = 1, #tilemap do
        self.staticTileInfo[y] = {}
        for x = 1, #tilemap[y] do
            local xWorld, yWorld = self:mapToWorld(x, y)
            self.staticTileInfo[y][x] = {
                mapX = x,
                mapY = y,
                collider = not isWalkableMapPosition(x, y),
                tileIndex = tilemap[y][x],
                xWorld = xWorld,
                yWorld = yWorld,
                size = tileSize,
            }
        end
    end

    for y = 1, #tilemap do
        self.nearbyTileCache[y] = {}
        self.nearbyCollidableTileCache[y] = {}
        for x = 1, #tilemap[y] do
            local nearby = {}
            local collidable = {}
            for nearbyY = y - 1, y + 1 do
                if tilemap[nearbyY] then
                    for nearbyX = x - 1, x + 1 do
                        local tile = self:getTileAtMapPosition(nearbyX, nearbyY)
                        if tile then
                            nearby[#nearby + 1] = tile
                            if tile.collider and not tile.isWater then
                                collidable[#collidable + 1] = tile
                            end
                        end
                    end
                end
            end
            self.nearbyTileCache[y][x] = nearby
            self.nearbyCollidableTileCache[y][x] = collidable
        end
    end
end

function DefaultTilemap:refreshStaticTileInfoAt(x, y)
    if not (tilemap and tilemap[y] and tilemap[y][x] ~= nil) then
        return
    end

    self.staticTileInfo = self.staticTileInfo or {}
    self.staticTileInfo[y] = self.staticTileInfo[y] or {}

    local info = self.staticTileInfo[y][x]
    if not info then
        local xWorld, yWorld = self:mapToWorld(x, y)
        info = {
            mapX = x,
            mapY = y,
            xWorld = xWorld,
            yWorld = yWorld,
            size = tileSize,
        }
        self.staticTileInfo[y][x] = info
    end

    info.collider = not isWalkableMapPosition(x, y)
    info.tileIndex = tilemap[y][x]
end

function DefaultTilemap:rebuildNearbyTileCacheAt(x, y)
    if not (tilemap and tilemap[y] and tilemap[y][x] ~= nil) then
        return
    end

    self.nearbyTileCache = self.nearbyTileCache or {}
    self.nearbyTileCache[y] = self.nearbyTileCache[y] or {}
    self.nearbyCollidableTileCache = self.nearbyCollidableTileCache or {}
    self.nearbyCollidableTileCache[y] = self.nearbyCollidableTileCache[y] or {}
    local nearby = self.nearbyTileCache[y][x] or {}
    local collidable = self.nearbyCollidableTileCache[y][x] or {}
    clearArray(nearby)
    clearArray(collidable)

    for nearbyY = y - 1, y + 1 do
        if tilemap[nearbyY] then
            for nearbyX = x - 1, x + 1 do
                local tile = self:getTileAtMapPosition(nearbyX, nearbyY)
                if tile then
                    nearby[#nearby + 1] = tile
                    if tile.collider and not tile.isWater then
                        collidable[#collidable + 1] = tile
                    end
                end
            end
        end
    end

    self.nearbyTileCache[y][x] = nearby
    self.nearbyCollidableTileCache[y][x] = collidable
end

function DefaultTilemap:updateTileQueryCacheAt(x, y)
    if not (tilemap and tilemap[y] and tilemap[y][x] ~= nil) then
        return
    end

    self:refreshStaticTileInfoAt(x, y)

    for cacheY = y - 1, y + 1 do
        if tilemap[cacheY] then
            for cacheX = x - 1, x + 1 do
                self:rebuildNearbyTileCacheAt(cacheX, cacheY)
            end
        end
    end
end

function DefaultTilemap:getNearbyTiles(worldX, worldY)
    local mapX, mapY = self:worldToMap(worldX, worldY)
    local row = self.nearbyTileCache and self.nearbyTileCache[mapY]
    if row and row[mapX] then
        return row[mapX]
    end

    local tiles = {}
    for y = mapY - 1, mapY + 1 do
        if tilemap[y] then
            for x = mapX - 1, mapX + 1 do
                local tile = self:getTileAtMapPosition(x, y)
                if tile then
                    tiles[#tiles + 1] = tile
                end
            end
        end
    end

    return tiles
end

function DefaultTilemap:getNearbyCollidableTiles(worldX, worldY)
    local mapX, mapY = self:worldToMap(worldX, worldY)
    local row = self.nearbyCollidableTileCache and self.nearbyCollidableTileCache[mapY]
    if row and row[mapX] then
        return row[mapX]
    end

    local tiles = {}
    for y = mapY - 1, mapY + 1 do
        if tilemap[y] then
            for x = mapX - 1, mapX + 1 do
                local tile = self:getTileAtMapPosition(x, y)
                if tile and tile.collider and not tile.isWater then
                    tiles[#tiles + 1] = tile
                end
            end
        end
    end

    return tiles
end

function DefaultTilemap:getTilesInWorldBox(minX, minY, maxX, maxY)
    local tiles = self.tilesInWorldBoxScratch or {}
    clearArray(tiles)
    self.tilesInWorldBoxScratch = tiles
    local minMapX, minMapY = self:worldToMap(minX, minY)
    local maxMapX, maxMapY = self:worldToMap(maxX, maxY)

    if minMapX > maxMapX then
        minMapX, maxMapX = maxMapX, minMapX
    end
    if minMapY > maxMapY then
        minMapY, maxMapY = maxMapY, minMapY
    end

    for y = minMapY - 1, maxMapY + 1 do
        if tilemap[y] then
            for x = minMapX - 1, maxMapX + 1 do
                local tile = self:getTileAtMapPosition(x, y)
                if tile then
                    tiles[#tiles + 1] = tile
                end
            end
        end
    end

    return tiles
end

function DefaultTilemap:buildTreeFadeIndex(trees)
    self.treeFadeGrid = {}
    self.treeFadeCandidates = trees or {}
    self.markedTreeFadeTargets = {}

    for _, tree in ipairs(self.treeFadeCandidates) do
        if tree.getFadeBox then
            local box = tree:getFadeBox()
            local minCellX = getTreeFadeCell(box.x)
            local maxCellX = getTreeFadeCell(box.x + box.width)
            local minCellY = getTreeFadeCell(box.y)
            local maxCellY = getTreeFadeCell(box.y + box.height)

            tree.fadeBox = box
            for cellY = minCellY, maxCellY do
                for cellX = minCellX, maxCellX do
                    local key = getTreeFadeCellKey(cellX, cellY)
                    local bucket = self.treeFadeGrid[key]
                    if not bucket then
                        bucket = {}
                        self.treeFadeGrid[key] = bucket
                    end
                    bucket[#bucket + 1] = tree
                end
            end
        end
    end
end

function DefaultTilemap:markTreesTransparentNearBox(box, padding)
    if not (box and self.treeFadeGrid) then
        return
    end

    padding = padding or 0
    local minX = box.x - padding
    local maxX = box.x + box.width + padding
    local minY = box.y - padding
    local maxY = box.y + box.height + padding
    local minCellX = getTreeFadeCell(minX)
    local maxCellX = getTreeFadeCell(maxX)
    local minCellY = getTreeFadeCell(minY)
    local maxCellY = getTreeFadeCell(maxY)
    local checked = {}

    for cellY = minCellY, maxCellY do
        for cellX = minCellX, maxCellX do
            local bucket = self.treeFadeGrid[getTreeFadeCellKey(cellX, cellY)]
            if bucket then
                for _, tree in ipairs(bucket) do
                    if not checked[tree] then
                        checked[tree] = true
                        local treeBox = tree.fadeBox or (tree.getFadeBox and tree:getFadeBox())
                        if treeBox
                            and minX <= treeBox.x + treeBox.width
                            and maxX >= treeBox.x
                            and minY <= treeBox.y + treeBox.height
                            and maxY >= treeBox.y then
                            if tree.fadeTargetAlpha == nil then
                                self.markedTreeFadeTargets[#self.markedTreeFadeTargets + 1] = tree
                            end
                            tree:markTransparent()
                        end
                    end
                end
            end
        end
    end
end

function DefaultTilemap:clearTreeFadeTargets()
    for _, tree in ipairs(self.markedTreeFadeTargets or {}) do
        tree.fadeTargetAlpha = nil
    end
    self.markedTreeFadeTargets = {}
end

function DefaultTilemap:getNearestWalkableMapPosition(mapX, mapY, maxRadius)
    if isWalkableMapPosition(mapX, mapY) then
        return mapX, mapY
    end

    local radiusLimit = maxRadius or 5
    for radius = 1, radiusLimit do
        for y = mapY - radius, mapY + radius do
            for x = mapX - radius, mapX + radius do
                local isEdge = x == mapX - radius or x == mapX + radius or y == mapY - radius or y == mapY + radius
                if isEdge and isWalkableMapPosition(x, y) then
                    return x, y
                end
            end
        end
    end

    return nil, nil
end

function DefaultTilemap:getNearestWalkableWorldPosition(worldX, worldY, maxRadius)
    local mapX, mapY = self:worldToMap(worldX, worldY)
    mapX, mapY = self:getNearestWalkableMapPosition(mapX, mapY, maxRadius or 3)
    if not mapX then
        return nil, nil
    end

    local x, y = self:mapToWorld(mapX, mapY)
    return x, y - 8
end

function DefaultTilemap:getPathBetweenWorldPoints(startX, startY, endX, endY)
    if not self.finder then
        return nil
    end

    local startMapX, startMapY = self:worldToMap(startX, startY)
    local endMapX, endMapY = self:worldToMap(endX, endY)

    startMapX, startMapY = self:getNearestWalkableMapPosition(startMapX, startMapY, 4)
    endMapX, endMapY = self:getNearestWalkableMapPosition(endMapX, endMapY, 8)
    if not startMapX or not endMapX then
        return nil
    end

    local ok, path = pcall(function()
        return self.finder:getPath(startMapX, startMapY, endMapX, endMapY)
    end)

    if ok and path then
        return path
    end

    if not self.finderAstar then
        return nil
    end

    ok, path = pcall(function()
        return self.finderAstar:getPath(startMapX, startMapY, endMapX, endMapY)
    end)

    return ok and path or nil
end

function DefaultTilemap:hasTileClose(x, y, tileIndex)
    if x - 1 <= 1 or y - 1 <= 1 then return false end
    if y + 1 > #tilemap then return false end
    if x + 1 > #tilemap[y] then return false end

    return
        tilemap[y][x + 1] == tileIndex or
        tilemap[y][x - 1] == tileIndex or
        tilemap[y + 1][x] == tileIndex or
        tilemap[y - 1][x] == tileIndex
end

function DefaultTilemap:loadfinders()
    local needsRebuild = not self.pathfinderMap
        or #self.pathfinderMap ~= #tilemap
        or (tilemap[1] and self.pathfinderMap[1] and #self.pathfinderMap[1] ~= #tilemap[1])

    if needsRebuild then
        self.pathfinderMap = buildPathfinderMap(tilemap)
        self.sharedGrid = Grid(self.pathfinderMap)
        self.finder = Pathfinder(self.sharedGrid, "JPS", 0)
        self.finderAstar = Pathfinder(self.sharedGrid, "ASTAR", 0)
        self.finder:setMode("ORTHOGONAL")
        self.finderAstar:setMode("ORTHOGONAL")
        self.finder:setHeuristicWeight(1.35)
        self.finderAstar:setHeuristicWeight(1.35)
        return
    end

    for y = 1, #tilemap do
        local sourceRow = tilemap[y]
        local pathRow = self.pathfinderMap[y]
        for x = 1, #sourceRow do
            pathRow[x] = isWalkableTile(sourceRow[x]) and 0 or 1
        end
    end
end

function DefaultTilemap:updatePathfinderTile(x, y)
    self:updateTileQueryCacheAt(x, y)

    if not (self.pathfinderMap and self.pathfinderMap[y]) then
        self:loadfinders()
        return
    end

    self.pathfinderMap[y][x] = isWalkableTile(tilemap[y] and tilemap[y][x]) and 0 or 1
end

local function isSpecialStoneWallRoom(room)
    return room and (room.isShopRoom or room.isCardRoom or room.templateId == "store_32x32" or room.templateId == "cards_32x32")
end

function DefaultTilemap:createTile(x, y, tile, collider)
    if tile == TILE_CHEST then
        local state = FloorManager:getCurrentRoomState()
        local chestType = state and state.chestTypes and state.chestTypes[getTileKey(x, y)]
        if not chestType and FloorManager:getCurrentRoom() and FloorManager:getCurrentRoom().isCardRoom then
            chestType = "card"
        end
        return Chest:new(x, y, chestType)
    end

    if tile == TILE_DOOR then
        return DoorTile:new(x, y, tile, true, getDoorOptions(x, y))
    end

    if tile == 8 then
        local c = self:hasTileClose(x, y, 0) or self:hasTileClose(x, y, 5) or self:hasTileClose(x, y, 6) or self:hasTileClose(x, y, 2)
        local index = autoTileWater(x, y, tilemap)
        return Water:new(x, y, index, c)
    end

    if tile == 13 then
        local mustDraw = false
        if tilemap[y - 1][x] ~= 13 and tilemap[y][x - 1] ~= 13 then
            mustDraw = true
        end
        return Container:new(x, y, 30, true, mustDraw)
    end

    if tile == 12 then
        return Counter:new(x, y, 30, collider)
    end

    if tile == 11 then
        return Pole:new(x, y, 30, collider, {
            ySortOffset = isSurroundedByNonWalkableTiles(x, y) and 10 or 0,
        })
    end

    if tile == 10 then
        return HouseTile:new(x, y, 30, collider)
    end

    if tile == 3 then
        return TreeTile:new(x, y, tile, collider, {
            ySortOffset = isSurroundedByNonWalkableTiles(x, y) and 10 or 0,
        })
    end

    if tile == 14 then
        return TreeTile:newBig(x, y, tile, collider, {
            ySortOffset = isSurroundedByNonWalkableTiles(x, y) and 10 or 0,
        })
    end

    if tile == TILE_STORE then
        local index = 24
        local state = FloorManager:getCurrentRoomState()
        local product = state
            and state.weaponTestShopProducts
            and state.weaponTestShopProducts[getTileKey(x, y)]
            or state and state.shopTileProducts and state.shopTileProducts[getTileKey(x, y)]
            or state and state.shopProduct
        if not product then
            return nil
        end
        local store = Store:new(x, y, index, collider, product)
        return store
    end

    if tile > 0 and tile ~= TILE_DOOR_BACK then
        local index = 5
        if tile == 1 then
            index = autoTile(x, y, tilemap)
            if isSpecialStoneWallRoom(FloorManager:getCurrentRoom()) and shouldUseSpecialWallTile(x, y) then
                index = specialWallByBaseIndex[index] or index
            end
        elseif tile == 2 then
            index = 14
        end

        if tile == 1 and not isSpecialStoneWallRoom(FloorManager:getCurrentRoom()) and wallVariantLookup[getTileKey(x, y)] then
            index = wallVariantByBaseIndex[index] or index
        end

        if index == 5 and math.random(10) == 1 then
            index = 15
        end

        return Tile:new(x, y, index, collider)
    end

    return nil
end

function DefaultTilemap:buildMoonbeamState(trees, specialTargets)
    local room = FloorManager:getCurrentRoom()
    local state = room and room.state
    local config = getMoonbeamConfig(room)
    if not (state and config and config.enabled ~= false) then
        return {}
    end

    if state.moonbeams then
        appendSpecialTargetMoonbeams(state.moonbeams, specialTargets, config)
        return state.moonbeams
    end

    state.moonbeams = {}
    local specialTargetCount = #(specialTargets or {})
    local chance = hasRoomEncounter(room) and (config.chance or 0.78) or (config.emptyEncounterChance or 0.95)
    if specialTargetCount > 0 then
        chance = math.max(config.minChanceWithSpecialTargets or 0.35, chance - specialTargetCount * (config.specialTargetChancePenalty or 0.12))
    end

    if math.random() < chance then
        local candidates = collectMoonbeamCandidates(self, trees, config)
        local count = getLooseMoonbeamCount(config, specialTargetCount)
        local minDistance = config.minDistance or 42

        for _ = 1, count do
            local candidate = chooseMoonbeamCandidate(candidates, state.moonbeams, minDistance)
            if candidate then
                appendMoonbeamEntry(state.moonbeams, candidate.x, candidate.y, config)
            end
        end
    end

    appendSpecialTargetMoonbeams(state.moonbeams, specialTargets, config)

    return state.moonbeams
end

function DefaultTilemap:buildAmbientDustAnchors(walkablePositions)
    local room = FloorManager:getCurrentRoom()
    local state = room and room.state
    local config = getAmbientDustConfig(room)
    if not (state and config and config.enabled ~= false and #walkablePositions > 0) then
        return {}
    end

    if state.ambientDustAnchors then
        return state.ambientDustAnchors
    end

    state.ambientDustAnchors = {}
    local anchorCount = math.min(#walkablePositions, config.anchorCount or 34)
    local used = {}

    for _ = 1, anchorCount do
        local candidate = walkablePositions[math.random(1, #walkablePositions)]
        local key = math.floor(candidate.x) .. ":" .. math.floor(candidate.y)
        if not used[key] then
            state.ambientDustAnchors[#state.ambientDustAnchors + 1] = {
                x = candidate.x,
                y = candidate.y,
            }
            used[key] = true
        end
    end

    return state.ambientDustAnchors
end

function DefaultTilemap:loadAmbientDust(walkablePositions)
    self.ambientDust = nil
    local room = FloorManager:getCurrentRoom()
    local config = getAmbientDustConfig(room)
    if not (config and config.enabled ~= false) then
        return
    end

    local anchors = self:buildAmbientDustAnchors(walkablePositions)
    if #anchors > 0 then
        self.ambientDust = AmbientDust:new(anchors, config)
    end
end

function DefaultTilemap:loadMoonbeams(trees, specialTargets)
    self.moonbeams = {}
    local room = FloorManager:getCurrentRoom()
    local config = getMoonbeamConfig(room)
    if not (config and config.enabled ~= false) then
        return
    end

    for _, entry in ipairs(self:buildMoonbeamState(trees, specialTargets)) do
        local beamConfig = mergeTables(config, {
            width = entry.width,
            length = entry.length,
            groundGap = entry.groundGap,
        })
        self.moonbeams[#self.moonbeams + 1] = Moonbeam:new(entry.x, entry.y, beamConfig)
    end
end

function DefaultTilemap:load()
    local tilemapConfig = getActiveTilemapConfig()
    local visualTheme = FloorManager:getCurrentRoomTheme() or VisualThemes:getDefault()
    tilemap, self.mapWidth, self.mapHeight = loadTilemapFromImage(tilemapConfig.mapImage)
    local transitions = RoomBuilder:build(tilemap, FloorManager:getCurrentRoom())
    applyVisualThemeTileRules(visualTheme)
    self.roomTransitions = buildTransitionLookup(transitions)
    applyPersistedRoomState()
    applyOptionalObjectSpawnChances()
    applyRoomShopState()
    if tilemapConfig.centerOrigin then
        tilemapWorldX = -(self.mapWidth * tileSize) / 2 + tileSize / 2
        tilemapWorldY = -(self.mapHeight * tileSize) / 2 + tileSize / 2
    else
        local origin = tilemapConfig.tilemapOrigin or GameConfig.tilemapOrigin
        tilemapWorldX = origin.x
        tilemapWorldY = origin.y
    end

    tileSet:createTileSet(visualTheme.tileset)
    Tile:setTilemap(self)
    self.pathfinderMap = nil
    self.sharedGrid = nil
    self.finder = nil
    self.finderAstar = nil
    self:loadfinders()

    self.grass = {}
    self.bigGrass = {}
    self.floorPaths = {}
    self.tiles = {}
    self.tileLookup = {}
    self.tileLookupByMap = {}
    self.doorTiles = {}
    self.groundOccluderTiles = {}
    self.treeFadeGrid = {}
    self.treeFadeCandidates = {}
    self.markedTreeFadeTargets = {}
    self.spawnPositions = {}
    self.moonbeams = {}
    self.ambientDust = nil
    local bigGrassOccupied = {}
    local trees = {}
    local specialMoonbeamTargets = {}
    local walkablePositions = {}
    local floorPathEntries = buildFloorPathState()
    wallVariantLookup = buildWallVariantState()
    local roomState = FloorManager:getCurrentRoomState()
    local generatingGrassState = roomState and roomState.grassTiles == nil
    local grassState = roomState and roomState.grassTiles or {}
    local bigGrassState = roomState and roomState.bigGrassTiles or {}

    if generatingGrassState then
        grassState = {}
        bigGrassState = {}
        roomState.grassTiles = grassState
        roomState.bigGrassTiles = bigGrassState
    end

    for _, entry in ipairs(floorPathEntries) do
        if tilemap[entry.y] and canDrawFloorPathOnTile(tilemap[entry.y][entry.x]) then
            local worldX, worldY = self:mapToWorld(entry.x, entry.y)
            self.floorPaths[#self.floorPaths + 1] = FloorPath:new(worldX, worldY, entry.quadIndex)
        end
    end

    for y = 1, #tilemap do
        for x = 1, #tilemap[y] do
            local tile = tilemap[y][x]
            local collider =
                self:hasTileClose(x, y, 0) or
                self:hasTileClose(x, y, 5) or
                self:hasTileClose(x, y, 8) or
                self:hasTileClose(x, y, TILE_DOOR) or
                self:hasTileClose(x, y, 2) or
                self:hasTileClose(x, y, TILE_CHEST) or
                self:hasTileClose(x, y, 11) or
                self:hasTileClose(x, y, 6)

            local worldX, worldY = self:mapToWorld(x, y)

            if tile == TILE_CHEST or tile == TILE_STORE then
                specialMoonbeamTargets[#specialMoonbeamTargets + 1] = {
                    key = "target:" .. getTileKey(x, y),
                    x = worldX,
                    y = worldY,
                }
            end

            if tile == 0 then
                local walkablePosition = { x = worldX, y = worldY - 8 }
                self.spawnPositions[#self.spawnPositions + 1] = walkablePosition
                walkablePositions[#walkablePositions + 1] = walkablePosition
            end

            if generatingGrassState then
                if shouldCreateBigGrass(tile, collider, x, y, bigGrassOccupied) then
                    appendBigGrassCluster(bigGrassState, x, y, bigGrassOccupied, canCreateBigGrassAt, {yOffset = 0, ySortOffset = 2, interactive = true}, 2, 4)
                end

                if shouldCreateDecorativeBigGrass(tile, collider, x, y, bigGrassOccupied) then
                    appendBigGrassCluster(bigGrassState, x, y, bigGrassOccupied, canCreateDecorativeBigGrassAt, {yOffset = 16, ySortOffset = 10, interactive = false})
                end

                if not bigGrassOccupied[getTileKey(x, y)] and shouldCreateGrass(tile, collider, x, y) then
                    appendGrassState(grassState, x, y, worldX, worldY, tile)
                end
            end

            if shouldCreateTileObject(tile, x, y) then
                local createdTile = self:createTile(x, y, tile, collider)
                if createdTile then
                    self.tiles[#self.tiles + 1] = createdTile
                    self.tileLookup[getTileKey(x, y)] = createdTile
                    self.tileLookupByMap[y] = self.tileLookupByMap[y] or {}
                    self.tileLookupByMap[y][x] = createdTile
                    if createdTile.collider and not createdTile.isWater then
                        self.groundOccluderTiles[#self.groundOccluderTiles + 1] = createdTile
                    end
                    if createdTile.openDoor and createdTile.closeDoor then
                        self.doorTiles[#self.doorTiles + 1] = createdTile
                    end
                    if createdTile.treeIndex then
                        trees[#trees + 1] = createdTile
                    end
                end
            end
        end
    end

    for _, entry in ipairs(grassState) do
        if canRenderGrassEntry(entry) then
            local worldX, worldY = self:mapToWorld(entry.x, entry.y)
            self.grass[#self.grass + 1] = Grass:new(
                worldX + (entry.offsetX or 0),
                worldY + (entry.offsetY or 0),
                entry.tile,
                {index = entry.index}
            )
        end
    end

    for _, entry in ipairs(bigGrassState) do
        if canRenderGrassEntry(entry) then
            local worldX, worldY = self:mapToWorld(entry.x, entry.y)
            self.bigGrass[#self.bigGrass + 1] = BigGrass:new(worldX, worldY, entry.options)
        end
    end

    self:buildTileQueryCache()
    self:buildTreeFadeIndex(trees)
    self:loadMoonbeams(trees, specialMoonbeamTargets)
    self:loadAmbientDust(walkablePositions)
    self:buildUpdateSpatialIndex()
end

local function isSpawnCandidateAllowed(candidate, reference, targetDistance, avoidPoints)
    if reference and distance(candidate, reference) <= targetDistance then
        return false
    end

    for _, avoidPoint in ipairs(avoidPoints or {}) do
        if avoidPoint.x and avoidPoint.y and distance(candidate, avoidPoint) <= (avoidPoint.radius or targetDistance) then
            return false
        end
    end

    return true
end

function DefaultTilemap:getRandomSpawnPosition(reference, minDistance, avoidPoints)
    if not tilemap then
        return nil, nil
    end

    local targetDistance = minDistance or GameConfig.spawnMinDistance
    local fallback = nil

    for _ = 1, 80 do
        local y = math.random(1, #tilemap)
        local x = math.random(1, #tilemap[y])

        if tilemap[y][x] == 0 then
            local worldX, worldY = self:mapToWorld(x, y)
            local candidate = {x = worldX, y = worldY - 8}

            if isSpawnCandidateAllowed(candidate, reference, targetDistance, avoidPoints) then
                fallback = fallback or candidate
                return candidate.x, candidate.y
            end
        end
    end

    if fallback then
        return fallback.x, fallback.y
    end

    return nil, nil
end

function DefaultTilemap:getRandomReachableSpawnPosition(reference, minDistance, avoidPoints)
    if not tilemap or not self.finder then
        return self:getRandomSpawnPosition(reference, minDistance, avoidPoints)
    end

    local targetDistance = minDistance or GameConfig.spawnMinDistance
    local spawnPositions = self.spawnPositions or {}
    if #spawnPositions == 0 then
        return self:getRandomSpawnPosition(reference, minDistance, avoidPoints)
    end
    local referenceMapX, referenceMapY = nil, nil
    if reference then
        referenceMapX, referenceMapY = self:worldToMap(reference.x, reference.y)
        referenceMapX, referenceMapY = self:getNearestWalkableMapPosition(referenceMapX, referenceMapY, 8)
    end

    for _ = 1, 120 do
        local candidate = spawnPositions[math.random(1, #spawnPositions)]

        if candidate and isSpawnCandidateAllowed(candidate, reference, targetDistance, avoidPoints) then
            if not referenceMapX then
                return candidate.x, candidate.y
            end

            local x, y = self:worldToMap(candidate.x, candidate.y)
            local ok, path = pcall(function()
                return self.finder:getPath(x, y, referenceMapX, referenceMapY)
            end)
            if (not ok or not path) and self.finderAstar then
                ok, path = pcall(function()
                    return self.finderAstar:getPath(x, y, referenceMapX, referenceMapY)
                end)
            end
            if ok and path and #path > 1 then
                return candidate.x, candidate.y
            end
        end
    end

    return nil, nil
end

local function isObjectNearCamera(object, margin)
    if not camera then
        return true
    end

    local x = object and (object.xWorld or object.x)
    local y = object and (object.yWorld or object.y)
    if not (x and y) then
        return true
    end

    margin = margin or 160
    local screenX = (x * WORLD_SCALE_X - camera.x) * camera.zoomX
    local screenY = (y * YSCALE - camera.y) * camera.zoomY

    return screenX >= -margin
        and screenX <= baseWidth + margin
        and screenY >= -margin
        and screenY <= baseHeight + margin
end

local function getCameraWorldBox(margin)
    if not camera then
        return nil
    end

    margin = margin or 160
    local zoomX = math.max(camera.zoomX or 1, 0.001)
    local zoomY = math.max(camera.zoomY or 1, 0.001)
    local scaleX = math.max(WORLD_SCALE_X or 1, 0.001)
    local scaleY = math.max(YSCALE or 1, 0.001)

    return {
        minX = (camera.x - margin / zoomX) / scaleX,
        maxX = (camera.x + (baseWidth + margin) / zoomX) / scaleX,
        minY = (camera.y - margin / zoomY) / scaleY,
        maxY = (camera.y + (baseHeight + margin) / zoomY) / scaleY,
    }
end

local function getObjectSpatialBounds(object)
    local x = object and (object.xWorld or object.x)
    local y = object and (object.yWorld or object.y)
    if not (x and y) then
        return nil
    end

    if object and type(object.getXrayOccluderBox) == "function" then
        local box = object:getXrayOccluderBox()
        if box then
            return box.x, box.y, box.x + box.width, box.y + box.height
        end
    end

    local radius = object.spatialRadius or object.size or 16
    return x - radius, y - radius, x + radius, y + radius
end

local function addObjectToSpatialGrid(grid, object)
    local minX, minY, maxX, maxY = getObjectSpatialBounds(object)
    if not minX then
        return
    end

    local minCellX = getSpatialCell(minX)
    local maxCellX = getSpatialCell(maxX)
    local minCellY = getSpatialCell(minY)
    local maxCellY = getSpatialCell(maxY)

    for cellY = minCellY, maxCellY do
        for cellX = minCellX, maxCellX do
            local key = getSpatialCellKey(cellX, cellY)
            local bucket = grid[key]
            if not bucket then
                bucket = {}
                grid[key] = bucket
            end
            bucket[#bucket + 1] = object
        end
    end
end

function DefaultTilemap:buildUpdateSpatialIndex()
    self.updateSpatialGrids = {
        tiles = {},
        grass = {},
        bigGrass = {},
        grassInteraction = {},
        bigGrassInteraction = {},
        floorPaths = {},
        moonbeams = {},
    }
    self.visibleUpdateScratch = self.visibleUpdateScratch or {}
    self.visibleQueryStamp = 0

    for _, tile in ipairs(self.tiles or {}) do
        addObjectToSpatialGrid(self.updateSpatialGrids.tiles, tile)
    end
    for _, grass in ipairs(self.grass or {}) do
        addObjectToSpatialGrid(self.updateSpatialGrids.grass, grass)
        if grass.tile ~= 1 then
            addObjectToSpatialGrid(self.updateSpatialGrids.grassInteraction, grass)
        end
    end
    for _, grass in ipairs(self.bigGrass or {}) do
        addObjectToSpatialGrid(self.updateSpatialGrids.bigGrass, grass)
        if grass.interactive ~= false then
            addObjectToSpatialGrid(self.updateSpatialGrids.bigGrassInteraction, grass)
        end
    end
    for _, path in ipairs(self.floorPaths or {}) do
        addObjectToSpatialGrid(self.updateSpatialGrids.floorPaths, path)
    end
    for _, beam in ipairs(self.moonbeams or {}) do
        addObjectToSpatialGrid(self.updateSpatialGrids.moonbeams, beam)
    end
end

function DefaultTilemap:getVisibleObjectsFromGrid(gridName, margin)
    local grids = self.updateSpatialGrids
    local grid = grids and grids[gridName]
    if not grid then
        return nil
    end

    local box = getCameraWorldBox(margin)
    if not box then
        return nil
    end

    local result = self.visibleUpdateScratch[gridName]
    if not result then
        result = {}
        self.visibleUpdateScratch[gridName] = result
    else
        clearArray(result)
    end

    self.visibleQueryStamp = (self.visibleQueryStamp or 0) + 1
    local stamp = self.visibleQueryStamp
    local minCellX = getSpatialCell(box.minX)
    local maxCellX = getSpatialCell(box.maxX)
    local minCellY = getSpatialCell(box.minY)
    local maxCellY = getSpatialCell(box.maxY)

    for cellY = minCellY, maxCellY do
        for cellX = minCellX, maxCellX do
            local bucket = grid[getSpatialCellKey(cellX, cellY)]
            if bucket then
                for _, object in ipairs(bucket) do
                    if object.__tilemapVisibleStamp ~= stamp then
                        object.__tilemapVisibleStamp = stamp
                        result[#result + 1] = object
                    end
                end
            end
        end
    end

    return result
end

function DefaultTilemap:markGrassNearPoint(x, y, radius, sourceX)
    local grids = self.updateSpatialGrids
    if not (grids and x and y) then
        return
    end

    radius = radius or 12
    sourceX = sourceX or x
    local radiusSq = radius * radius
    local minCellX = getSpatialCell(x - radius)
    local maxCellX = getSpatialCell(x + radius)
    local minCellY = getSpatialCell(y - radius)
    local maxCellY = getSpatialCell(y + radius)
    self.grassInteractionStamp = (self.grassInteractionStamp or 0) + 1
    local stamp = self.grassInteractionStamp

    local function markGrid(gridName, yField)
        local grid = grids[gridName]
        if not grid then
            return
        end

        for cellY = minCellY, maxCellY do
            for cellX = minCellX, maxCellX do
                local bucket = grid[getSpatialCellKey(cellX, cellY)]
                if bucket then
                    for _, grass in ipairs(bucket) do
                        if grass.__grassInteractionStamp ~= stamp then
                            grass.__grassInteractionStamp = stamp
                            local grassY = grass[yField] or grass.y
                            local dx = grass.x - x
                            local dy = grassY - y
                            if dx * dx + dy * dy <= radiusSq and grass.markInteraction then
                                grass:markInteraction(sourceX)
                            end
                        end
                    end
                end
            end
        end
    end

    markGrid("grassInteraction", "y")
    markGrid("bigGrassInteraction", "interactionY")
end

local function getObjectFadeBox(object, defaultSize)
    if not object then
        return nil
    end

    if type(object.collisionBox) == "function" then
        return object:collisionBox()
    end

    if type(object.getCollisionBox) == "function" then
        return object:getCollisionBox()
    end

    local x = object.x or object.xWorld
    local y = object.y or object.yWorld
    local size = object.size or defaultSize or 10
    if not (x and y) then
        return nil
    end

    return {
        x = x - size / 2,
        y = y - size / 2,
        width = size,
        height = size,
    }
end

local function markActorTreeFadeAreas(tilemapSystem)
    if Player and Player.isAlive then
        tilemapSystem:markTreesTransparentNearBox(getObjectFadeBox(Player, 12), 0)
    end

    for _, enemy in ipairs((Game and Game.nearbyEnemies) or {}) do
        if enemy.isAlive ~= false then
            tilemapSystem:markTreesTransparentNearBox(getObjectFadeBox(enemy, 10), 0)
        end
    end
end

function DefaultTilemap:update(dt)
    self:clearTreeFadeTargets()
    markActorTreeFadeAreas(self)

    if self.ambientDust then
        self.ambientDust:update(dt)
    end

    for _, beam in ipairs(self:getVisibleObjectsFromGrid("moonbeams", 240) or self.moonbeams or {}) do
        beam:update(dt)
    end

    for _, g in ipairs(self:getVisibleObjectsFromGrid("bigGrass", 220) or self.bigGrass) do
        g:update(dt)
    end

    for _, g in ipairs(self:getVisibleObjectsFromGrid("grass", 170) or self.grass) do
        g:update(dt)
    end

    for _, path in ipairs(self:getVisibleObjectsFromGrid("floorPaths", 160) or self.floorPaths or {}) do
        path:update(dt)
    end

    for _, tile in ipairs(self:getVisibleObjectsFromGrid("tiles", 96) or self.tiles) do
        if tile.isAlive then
            local forceUpdate = tile.isBreaking or (tile.hitFlashTimer and tile.hitFlashTimer > 0)
            if forceUpdate or isObjectNearCamera(tile, tile.renderCullMargin or 96) then
                tile:update(dt)
            end
        end
    end
end

function DefaultTilemap:keypressed(key)
    if key ~= "f" then
        return
    end

    for _, tile in ipairs(self.tiles) do
        if type(tile.keypressed) == "function" then
            tile:keypressed(key)
        end
        if type(tile.performBuy) == "function" and not tile.doorPairKey then
            tile:performBuy()
        end
    end
end

return DefaultTilemap
