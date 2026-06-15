local LevelTestConfig = {}

local function getConfig()
    return GAME_FLAGS and GAME_FLAGS.levelTest or nil
end

local function isEnabled()
    local config = getConfig()
    return config and config.enabled == true
end

local function toCount(value)
    if value == nil then
        return nil
    end

    value = tonumber(value)
    if not value then
        return nil
    end

    return math.max(0, math.floor(value))
end

local function readCount(config, names)
    local rooms = config.rooms or config.roomCounts or {}
    for _, name in ipairs(names) do
        local value = rooms[name]
        if value == nil then
            value = config[name]
        end
        local count = toCount(value)
        if count ~= nil then
            return count
        end
    end

    return nil
end

function LevelTestConfig.isEnabled()
    return isEnabled()
end

function LevelTestConfig.resolveFloorIndex(floorIndex)
    if not isEnabled() then
        return floorIndex
    end

    local config = getConfig()
    local configuredFloor = toCount(config.floorId or config.floorIndex or config.id)
    if configuredFloor then
        return math.max(1, configuredFloor)
    end

    return floorIndex
end

function LevelTestConfig.apply(level)
    if not (isEnabled() and level and level.floorConfig and level.floorConfig.generate) then
        return
    end

    local config = getConfig()
    local generate = level.floorConfig.generate
    local floorId = LevelTestConfig.resolveFloorIndex(level.currentFloorIndex or 1)
    local battleCount = readCount(config, {"battle", "battles", "batalha", "batalhas", "battleRooms", "battleRoomCount"})
    local shopCount = readCount(config, {"shops", "shop", "stores", "store", "lojas", "loja", "shopRooms", "shopRoomCount"})
    local cardCount = readCount(config, {"cards", "card", "cardRooms", "cardRoomCount"})
    local endCount = readCount(config, {"endroom", "endrooms", "fim", "final", "end", "endRooms", "endRoomCount"})

    level.currentFloorIndex = floorId

    if battleCount ~= nil then
        generate.battleRoomCount = battleCount
        generate.roomCount = battleCount + 1
        if config.largeRoomOppositeExit == nil then
            generate.largeRoomOppositeExit = false
        end
    end

    if shopCount ~= nil then
        generate.shopRoomCount = shopCount
    end

    if cardCount ~= nil then
        generate.cardRoomChance = cardCount > 0 and 1 or 0
        generate.cardRoomCount = {
            min = cardCount,
            max = cardCount,
        }
    end

    if endCount ~= nil then
        generate.endRoomCount = endCount
    end
end

return LevelTestConfig
