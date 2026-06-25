local DropTemplates = {}

DropTemplates.enemies = {
    zombie = {
        points = 0,
        drops = {
            { id = "coins", amount = 1, weight = 10 },
            { id = "coins", amount = 2, weight = 4 },
            { id = "coins", amount = 4, weight = 2 },
            { id = "none", weight = 12 },
            { id = "bullets", amount = 1, weight = 1 },
        },
        extraDrops = {
            { id = "life", amount = 1, chance = 0.004 },
        },
    },
    babyZombie = {
        points = 0,
        drops = {
            { id = "coins", amount = 1, weight = 10 },
            { id = "coins", amount = 2, weight = 5 },
            { id = "coins", amount = 4, weight = 3 },
            { id = "none", weight = 5 },
            { id = "bullets", amount = 1, weight = 1 },
        },
        extraDrops = {
            { id = "life", amount = 1, chance = 0.004 },
        },
    },
    bigZombie = {
        points = 0,
        drops = {
            { id = "coins", amount = 2, weight = 12 },
            { id = "coins", amount = 3, weight = 8 },
            { id = "coins", amount = 4, weight = 4 },
            { id = "bullets", amount = 1, weight = 3 },
        },
        extraDrops = {
            { id = "life", amount = 1, chance = 0.008 },
        },
    },
    noHead = {
        points = 0,
        drops = {
            { id = "coins", amount = 2, weight = 10 },
            { id = "coins", amount = 3, weight = 5 },
            { id = "none", weight = 2 },
            { id = "bullets", amount = 1, weight = 1 },
        },
        extraDrops = {
            { id = "life", amount = 1, chance = 0.004 },
        },
    },
    spider = {
        points = 0,
        drops = {
            { id = "coins", amount = 2, weight = 6 },
            { id = "none", weight = 10 },
        },
        extraDrops = {
            { id = "life", amount = 1, chance = 0.002 },
        },
    },
    fly = {
        points = 0,
        drops = {
            { id = "coins", amount = 2, weight = 6 },
            { id = "none", weight = 10 },
        },
        extraDrops = {
            { id = "life", amount = 1, chance = 0.002 },
        },
    },
}

DropTemplates.objects = {
    chest = {
        drops = {
            { id = "coins", amount = 3, weight = 15 },
            { id = "coins", amount = 2, weight = 20 },
            { id = "coins", amount = 4, weight = 10 },
            { id = "life", amount = 1, weight = 2 },
            { id = "bullets", amount = 1, weight = 12 },
        },
    },
    cardChest = {
        drops = {
            { id = "card", amount = 1, weight = 1 },
        },
    },
    box = {
        drops = {
            { id = "coins", amount = 1, weight = 10 },
            { id = "none", weight = 20 },
            { id = "bullets", amount = 1, weight = 1 },
        },
    },
}

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

local function normalizeId(id)
    if id == "coin" or id == "coins3" then
        return "coins"
    end
    if id == "ammo" or id == "municao" then
        return "bullets"
    end
    if id == "heart" or id == "hearts" then
        return "life"
    end
    return id
end

local function resolveRangeValue(value, fallback)
    if type(value) ~= "table" then
        return value or fallback or 0
    end

    local minValue = value.min or value[1] or fallback or 0
    local maxValue = value.max or value[2] or minValue
    minValue = math.floor(minValue)
    maxValue = math.floor(maxValue)
    if maxValue < minValue then
        minValue, maxValue = maxValue, minValue
    end
    return math.random(minValue, maxValue)
end

function DropTemplates.isPlayerFullLife(player)
    return player and player.life and player.totalLife and player.life >= player.totalLife
end

function DropTemplates.hasPlayerHalfHeart(player)
    return player and player.life and player.life % 2 == 1
end

function DropTemplates.canDropBullets(player)
    return player
        and player.gun
        and player.gun.secondary_weapon
        and player.gun.canFillCurrentMagazine
        and player.gun:canFillCurrentMagazine()
end

function DropTemplates.canDrop(dropId, context)
    dropId = normalizeId(dropId)
    local player = context and context.player or Player

    if dropId == "bullets" then
        return DropTemplates.canDropBullets(player)
    elseif dropId == "life" then
        return not DropTemplates.isPlayerFullLife(player)
    end
    return true
end

function DropTemplates.getWeight(entry)
    return entry.weight or entry.chance or 1
end

function DropTemplates.getAmount(entry)
    return math.max(0, math.floor(resolveRangeValue(entry.amount or entry.qty or entry.count, 1)))
end

function DropTemplates.chooseWeighted(entries, context)
    local totalWeight = 0
    for _, entry in ipairs(entries or {}) do
        if DropTemplates.canDrop(entry.id or entry.kind or entry.type, context) then
            totalWeight = totalWeight + DropTemplates.getWeight(entry)
        end
    end

    if totalWeight <= 0 then
        return nil
    end

    local roll = math.random() * totalWeight
    for _, entry in ipairs(entries or {}) do
        if DropTemplates.canDrop(entry.id or entry.kind or entry.type, context) then
            roll = roll - DropTemplates.getWeight(entry)
            if roll <= 0 then
                return entry
            end
        end
    end

    return nil
end

local function getEntryChance(entry, context)
    local chance = entry.chance or 0
    local id = normalizeId(entry.id or entry.kind or entry.type)
    local player = context and context.player or Player

    if id == "life" and DropTemplates.hasPlayerHalfHeart(player) then
        chance = chance * 2
    end

    return chance
end

local function addResolvedDrop(result, entry, context)
    if not entry then
        return
    end

    local id = normalizeId(entry.id or entry.kind or entry.type)
    if not id or id == "none" then
        return
    end

    if not DropTemplates.canDrop(id, context) then
        return
    end

    local amount = DropTemplates.getAmount(entry)
    if amount <= 0 then
        return
    end

    result[#result + 1] = {
        id = id,
        amount = amount,
    }
end

function DropTemplates.resolve(config, context)
    local result = {}
    if not config then
        return result
    end

    addResolvedDrop(result, DropTemplates.chooseWeighted(config.drops or config.dropTemplate, context), context)

    for _, entry in ipairs(config.extraDrops or {}) do
        local chance = getEntryChance(entry, context)
        if chance > 0 and math.random() <= chance and DropTemplates.canDrop(entry.id or entry.kind or entry.type, context) then
            addResolvedDrop(result, entry, context)
        end
    end

    return result
end

function DropTemplates.getEnemyConfig(enemyTypeId, overrides)
    return mergeTables(DropTemplates.enemies[enemyTypeId] or DropTemplates.enemies.zombie, overrides)
end

function DropTemplates.getObjectConfig(objectType, overrides)
    return mergeTables(DropTemplates.objects[objectType], overrides)
end

function DropTemplates.createDrop(dropId, x, y)
    dropId = normalizeId(dropId)
    if dropId == "coins" then
        local Coin = require("scripts/drops/coin")
        return Coin:new(x, y)
    elseif dropId == "life" then
        local Life = require("scripts/drops/life")
        return Life:new(x, y)
    elseif dropId == "bullets" then
        local Bullets = require("scripts/drops/bullets")
        return Bullets:new(x, y)
    elseif dropId == "card" then
        local CardDrop = require("scripts/drops/card")
        return CardDrop:new(x, y)
    end
    return nil
end

function DropTemplates.spawnResolvedDrops(resolvedDrops, x, y, targetList, configureDrop)
    targetList = targetList or (Game and Game.objects)
    if not targetList then
        return
    end

    for _, resolved in ipairs(resolvedDrops or {}) do
        for _ = 1, resolved.amount or 1 do
            local drop = DropTemplates.createDrop(resolved.id, x, y)
            if drop then
                if configureDrop then
                    drop = configureDrop(drop, resolved.id)
                end
                table.insert(targetList, drop)
            end
        end
    end
end

return DropTemplates
