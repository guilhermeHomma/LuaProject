local CardDefinitions = {}
local Localization = require("scripts/managers/localization")

CardDefinitions.rarities = {
    common = {
        label = "common",
        weight = 1,
        color = {0.18, 0.13, 0.18, 1},
    },
    rare = {
        label = "rare",
        weight = 0.3,
        color = {0.05, 0.18, 0.34, 1},
    },
    epic = {
        label = "epic",
        weight = 1 / 15,
        color = {0.24, 0.08, 0.32, 1},
    },
    legendary = {
        label = "legendary",
        weight = 0,
        color = {0.40, 0.20, 0.02, 1},
    },
}

CardDefinitions.cards = {
    {
        id = "speed",
        name = "SPEED",
        amount = "+5",
        rarity = "common",
        visualType = "player",
        description = "Move faster.",
        requiresSecondary = false,
        apply = function()
            if Player then
                Player.speed = Player.speed + 5
                return true
            end

            return false
        end,
    },
    {
        id = "speed_rare",
        name = "SPEED",
        amount = "+10",
        rarity = "rare",
        visualType = "player",
        description = "Move much faster.",
        requiresSecondary = false,
        apply = function()
            if Player then
                Player.speed = Player.speed + 10
                return true
            end

            return false
        end,
    },
    {
        id = "primary_damage",
        name = "DAMAGE",
        amount = "+2",
        rarity = "common",
        visualType = "weapon",
        description = "Primary gun damage.",
        requiresSecondary = false,
        apply = function()
            return Player and Player.gun and Player.gun:applyCardUpgrade("primary_damage")
        end,
    },
    {
        id = "primary_damage_epic",
        name = "DAMAGE",
        amount = "+4",
        rarity = "epic",
        visualType = "weapon",
        description = "Primary gun damage.",
        requiresSecondary = false,
        apply = function()
            return Player and Player.gun and Player.gun:applyCardUpgrade("primary_damage_epic")
        end,
    },
    {
        id = "primary_range",
        name = "RANGE",
        amount = "+10%",
        rarity = "common",
        visualType = "weapon",
        description = "Primary gun range.",
        requiresSecondary = false,
        apply = function()
            return Player and Player.gun and Player.gun:applyCardUpgrade("primary_range")
        end,
    },
    {
        id = "primary_reload",
        name = "LOAD",
        amount = "-10%",
        rarity = "common",
        visualType = "weapon",
        description = "Primary gun loadspeed.",
        requiresSecondary = false,
        apply = function()
            return Player and Player.gun and Player.gun:applyCardUpgrade("primary_reload")
        end,
    },
    {
        id = "primary_ricochet",
        name = "BOUNCE",
        amount = "RICOCHET",
        rarity = "rare",
        visualType = "weapon",
        description = "Primary shots bounce from walls and enemies.",
        requiresSecondary = false,
        getStacks = function()
            return Player and Player.gun and Player.gun.primaryUpgradeState and (Player.gun.primaryUpgradeState.ricochetCount or 0) or 0
        end,
        maxStacks = 4,
        apply = function()
            return Player and Player.gun and Player.gun:applyCardUpgrade("primary_ricochet")
        end,
    },
    {
        id = "primary_death_shard",
        name = "SPARK",
        amount = "+2",
        rarity = "rare",
        visualType = "weapon",
        description = "Missed primary shots split into short base-damage shots.",
        requiresSecondary = false,
        getStacks = function()
            return Player and Player.gun and Player.gun.primaryUpgradeState and (Player.gun.primaryUpgradeState.deathSpawnCount or 0) or 0
        end,
        maxStacks = 8,
        apply = function()
            return Player and Player.gun and Player.gun:applyCardUpgrade("primary_death_shard")
        end,
    },
    {
        id = "primary_clean_split",
        name = "SPLIT",
        amount = "+4",
        rarity = "epic",
        visualType = "weapon",
        description = "Missed primary shots split into more short base-damage shots.",
        requiresSecondary = false,
        getStacks = function()
            return Player and Player.gun and Player.gun.primaryUpgradeState and (Player.gun.primaryUpgradeState.deathSpawnCount or 0) or 0
        end,
        maxStacks = 8,
        apply = function()
            return Player and Player.gun and Player.gun:applyCardUpgrade("primary_clean_split")
        end,
    },
    {
        id = "enemy_death_shard",
        name = "BURST",
        amount = "+2",
        rarity = "rare",
        visualType = "weapon",
        description = "Enemies release short base-damage shots when they die.",
        requiresSecondary = false,
        getStacks = function()
            return Player and Player.gun and Player.gun.primaryUpgradeState and (Player.gun.primaryUpgradeState.enemyDeathSpawnCount or 0) or 0
        end,
        maxStacks = 8,
        apply = function()
            return Player and Player.gun and Player.gun:applyCardUpgrade("enemy_death_shard")
        end,
    },
    {
        id = "enemy_death_split",
        name = "BURST",
        amount = "+4",
        rarity = "epic",
        visualType = "weapon",
        description = "Enemies release more short base-damage shots when they die.",
        requiresSecondary = false,
        getStacks = function()
            return Player and Player.gun and Player.gun.primaryUpgradeState and (Player.gun.primaryUpgradeState.enemyDeathSpawnCount or 0) or 0
        end,
        maxStacks = 8,
        apply = function()
            return Player and Player.gun and Player.gun:applyCardUpgrade("enemy_death_split")
        end,
    },
    {
        id = "coins_rare",
        name = "COINS",
        amount = "+10",
        rarity = "common",
        visualType = "player",
        description = "Gain 10 coins.",
        requiresSecondary = false,
        apply = function()
            if Game and Game.increasePlayerPoints then
                Game:increasePlayerPoints(10)
                return true
            end

            return false
        end,
    },
    {
        id = "coins_epic",
        name = "COINS",
        amount = "+40",
        rarity = "epic",
        visualType = "player",
        description = "Gain 40 coins.",
        requiresSecondary = false,
        apply = function()
            if Game and Game.increasePlayerPoints then
                Game:increasePlayerPoints(40)
                return true
            end

            return false
        end,
    },
    {
        id = "half_heart",
        name = "HEART",
        amount = "HEAL 1",
        rarity = "common",
        visualType = "life",
        description = "Restore one lost heart only.",
        requiresSecondary = false,
        apply = function()
            if Player then
                Player.life = math.min(Player.totalLife, Player.life + 2)
                return true
            end

            return false
        end,
    },
    {
        id = "full_heal",
        name = "FULL HEAL",
        amount = "RESTORE",
        rarity = "rare",
        visualType = "life",
        description = "Restore all lost hearts only.",
        requiresSecondary = false,
        apply = function()
            if Player then
                Player.life = Player.totalLife or Player.life
                return true
            end

            return false
        end,
    },
    {
        id = "heart_container",
        name = "HEART SLOT",
        amount = "+1 MAX",
        rarity = "epic",
        visualType = "life",
        description = "Gain one max heart and fully heal.",
        requiresSecondary = false,
        apply = function()
            if Player then
                Player.totalLife = (Player.totalLife or 0) + 2
                Player.life = Player.totalLife
                return true
            end

            return false
        end,
    },
}

local function equipWeaponCard(weaponId)
    return Player
        and Player.gun
        and Player.gun.replacePrimaryWeapon
        and Player.gun:replacePrimaryWeapon(weaponId)
        or false
end

CardDefinitions.weaponCards = {
    {
        id = "weapon_squaregun",
        name = "SQUAREGUN",
        amount = "NEW WEAPON",
        rarity = "common",
        visualType = "weapon",
        cardType = "weapon",
        weaponId = 4,
        description = "Fires 2 projectiles; 10 damage each.",
        apply = function() return equipWeaponCard(4) end,
    },
    {
        id = "weapon_longshot",
        name = "LONGSHOT",
        amount = "NEW WEAPON",
        rarity = "common",
        visualType = "weapon",
        cardType = "weapon",
        weaponId = 5,
        description = "Long-range weapon; 16 damage.",
        apply = function() return equipWeaponCard(5) end,
    },
    {
        id = "weapon_shotgun",
        name = "SHOTGUN",
        amount = "NEW WEAPON",
        rarity = "rare",
        visualType = "weapon",
        cardType = "weapon",
        weaponId = 2,
        description = "Fires 3 projectiles; 15 damage each.",
        apply = function() return equipWeaponCard(2) end,
    },
    {
        id = "weapon_cakegun",
        name = "CAKEGUN",
        amount = "NEW WEAPON",
        rarity = "rare",
        visualType = "weapon",
        cardType = "weapon",
        weaponId = 6,
        description = "Fires 2 projectiles; 12 damage each.",
        apply = function() return equipWeaponCard(6) end,
    },
    {
        id = "weapon_random",
        name = "RANDOM WEAPON",
        amount = "RANDOM",
        rarity = "rare",
        visualType = "weapon",
        cardType = "weapon",
        description = "Receive a random weapon.",
        apply = function()
            local weaponIds = {2, 3, 4, 5, 6}
            return equipWeaponCard(weaponIds[math.random(#weaponIds)])
        end,
    },
    {
        id = "weapon_raygun",
        name = "RAYGUN",
        amount = "NEW WEAPON",
        rarity = "epic",
        visualType = "weapon",
        cardType = "weapon",
        weaponId = 3,
        description = "Fast-firing weapon; 15 damage.",
        apply = function() return equipWeaponCard(3) end,
    },
}

function CardDefinitions:getRarity(card)
    return self.rarities[card.rarity] or self.rarities.common
end

function CardDefinitions:getRarityLabel(rarityId)
    return Localization:t("cards.rarity." .. tostring(rarityId or "common"))
end

function CardDefinitions:getCardName(card)
    local key = "cards." .. card.id .. ".name"
    local value = Localization:t(key)
    return value ~= key and value or card.name
end

function CardDefinitions:getCardAmount(card)
    local key = "cards." .. card.id .. ".amount"
    local value = Localization:t(key)
    return value ~= key and value or card.amount
end

function CardDefinitions:getCardDescription(card)
    local key = "cards." .. card.id .. ".description"
    local value = Localization:t(key)
    return value ~= key and value or card.description
end

function CardDefinitions:getCardStacks(card)
    if card and card.getStacks then
        return card.getStacks() or 0
    end

    return 0
end

function CardDefinitions:isCardEligible(card, hasSecondary)
    if not card then
        return false
    end

    if card.requiresSecondary and not hasSecondary then
        return false
    end

    if card.maxStacks and self:getCardStacks(card) >= card.maxStacks then
        return false
    end

    if card.isAvailable and not card.isAvailable() then
        return false
    end

    return true
end

function CardDefinitions:getEligibleCards()
    local result = {}
    local hasSecondary = Player and Player.gun and Player.gun.secondary_weapon ~= nil

    for _, card in ipairs(self.cards) do
        if self:isCardEligible(card, hasSecondary) then
            result[#result + 1] = card
        end
    end

    return result
end

function CardDefinitions:getEligibleCardsByRarity(rarity)
    local result = {}
    for _, card in ipairs(self:getEligibleCards()) do
        if card.rarity == rarity then
            result[#result + 1] = card
        end
    end
    return result
end

function CardDefinitions:getRandomWeaponCard(excludedId)
    local candidates = {}
    local totalWeight = 0

    for _, card in ipairs(self.weaponCards or {}) do
        if card.id ~= excludedId then
            local rarity = self:getRarity(card)
            local weight = rarity.weight or 0
            if weight > 0 then
                candidates[#candidates + 1] = { card = card, weight = weight }
                totalWeight = totalWeight + weight
            end
        end
    end

    if totalWeight <= 0 then
        return nil
    end

    local roll = math.random() * totalWeight
    for _, candidate in ipairs(candidates) do
        roll = roll - candidate.weight
        if roll <= 0 then
            return candidate.card
        end
    end

    return candidates[#candidates].card
end

function CardDefinitions:getRandomRarity()
    if math.random() < (self.rarities.rare.weight or 0) then
        return "rare"
    end
    return "common"
end

return CardDefinitions
