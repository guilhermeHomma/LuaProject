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
    evil = {
        label = "evil",
        weight = 0,
        color = {0.20, 0.08, 0.06, 1},
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
        description = "Increases the damage of your current weapon.",
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
        description = "Increases the damage of your current weapon.",
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
        description = "Increases the range of your current weapon.",
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
        description = "Increases the reload speed of your current weapon.",
        requiresSecondary = false,
        apply = function()
            return Player and Player.gun and Player.gun:applyCardUpgrade("primary_reload")
        end,
    },
    {
        id = "primary_cadence",
        name = "FIRE RATE",
        amount = "+15%",
        rarity = "rare",
        visualType = "weapon",
        description = "Your current weapon fires 15% faster.",
        requiresSecondary = false,
        apply = function()
            return Player and Player.gun and Player.gun:applyCardUpgrade("primary_cadence")
        end,
    },
    {
        id = "primary_ricochet",
        name = "BOUNCE",
        amount = "RICOCHET",
        rarity = "rare",
        visualType = "weapon",
        description = "Shots from your current weapon bounce off walls and enemies.",
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
        description = "Missed shots from your current weapon split into short base-damage shots.",
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
        description = "Missed shots from your current weapon split into more short base-damage shots.",
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
        description = "Fires two projectiles that deal 10 damage each.",
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
        description = "Fires a long-range projectile that deals 16 damage.",
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
        description = "Fires three projectiles that deal 15 damage each.",
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
        description = "Fires two projectiles that deal 12 damage each.",
        apply = function() return equipWeaponCard(6) end,
    },
    {
        id = "weapon_random",
        name = "RANDOM WEAPON",
        amount = "RANDOM",
        rarity = "rare",
        visualType = "weapon",
        cardType = "weapon",
        description = "Replaces your current weapon with a random one.",
        apply = function()
            local currentWeapon = Player and Player.gun and Player.gun.primary_weapon
            local currentWeaponId = currentWeapon and currentWeapon.index
            local weaponIds = {}
            for _, weaponId in ipairs({2, 3, 4, 5, 6, 7}) do
                if weaponId ~= currentWeaponId then
                    weaponIds[#weaponIds + 1] = weaponId
                end
            end
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
        description = "Fires quickly and deals 15 damage per shot.",
        apply = function() return equipWeaponCard(3) end,
    },
    {
        id = "weapon_pistolinha",
        name = "PISTOLINHA",
        amount = "NEW WEAPON",
        rarity = "common",
        visualType = "weapon",
        cardType = "weapon",
        weaponId = 7,
        description = "Fires three inaccurate projectiles that deal 3 damage each.",
        apply = function() return equipWeaponCard(7) end,
    },
}

local function applyGunPenalty(penaltyId)
    return Player and Player.gun and Player.gun.applyBadCardPenalty
        and Player.gun:applyBadCardPenalty(penaltyId) or false
end

local function primaryDamageAboveTen()
    local gun = Player and Player.gun
    local config = gun and gun:getEffectiveWeaponConfig(gun.primary_weapon)
    return config and (config.damage or 0) > 10 or false
end

CardDefinitions.badCards = {
    {
        id = "bad_speed_loss_15", name = "HEAVY LEGS", amount = "-15% SPEED", rarity = "evil",
        visualType = "player", cardType = "bad", description = "Movement speed is reduced by 15%.",
        apply = function()
            if not Player then return false end
            Player.speed = Player.speed * 0.85
            return true
        end,
    },
    {
        id = "bad_speed_loss_30", name = "LEAD BOOTS", amount = "-30% SPEED", rarity = "evil",
        visualType = "player", cardType = "bad", description = "Movement speed is reduced by 30%.",
        apply = function()
            if not Player then return false end
            Player.speed = Player.speed * 0.70
            return true
        end,
    },
    {
        id = "bad_reload_cadence", name = "RUST", amount = "2X SLOWER", rarity = "evil",
        visualType = "weapon", cardType = "bad", description = "Reloading and firing take twice as long.",
        apply = function() return applyGunPenalty("reload_and_cadence") end,
    },
    {
        id = "bad_one_max_heart", name = "GLASS HEART", amount = "1 MAX HEART", rarity = "evil",
        visualType = "life", cardType = "bad", description = "Maximum health is reduced to one heart.",
        apply = function()
            if not Player then return false end
            Player.totalLife = 2
            Player.life = math.min(Player.life or 2, 2)
            return true
        end,
    },
    {
        id = "bad_two_max_hearts", name = "WEAK HEART", amount = "2 MAX HEARTS", rarity = "evil",
        visualType = "life", cardType = "bad", description = "Maximum health is reduced to two hearts.",
        apply = function()
            if not Player then return false end
            Player.totalLife = math.min(Player.totalLife or 4, 4)
            Player.life = math.min(Player.life or Player.totalLife, Player.totalLife)
            return true
        end,
    },
    {
        id = "bad_cadence_third", name = "JAMMED TRIGGER", amount = "1/3 FIRE RATE", rarity = "evil",
        visualType = "weapon", cardType = "bad", description = "Fire rate is reduced to one third.",
        apply = function() return applyGunPenalty("cadence_third") end,
    },
    {
        id = "bad_lose_heart", name = "BROKEN HEART", amount = "-1 HEART", rarity = "evil",
        visualType = "life", cardType = "bad", description = "Lose one current heart.",
        isAvailable = function() return Player and (Player.life or 0) > 2 end,
        apply = function()
            if not Player or (Player.life or 0) <= 2 then return false end
            Player.life = Player.life - 2
            return true
        end,
    },
    {
        id = "bad_lose_coins", name = "BANKRUPT", amount = "LOSE ALL", rarity = "evil",
        visualType = "player", cardType = "bad", description = "Lose all coins.",
        apply = function()
            if not Game or not Game.getPlayerPoints or not Game.decreasePlayerPoints then return false end
            Game:decreasePlayerPoints(Game:getPlayerPoints())
            return true
        end,
    },
    {
        id = "bad_damage_minus_four", name = "BLUNT SHOTS", amount = "-4 DAMAGE", rarity = "evil",
        visualType = "weapon", cardType = "bad", description = "Projectiles lose 4 damage.",
        isAvailable = primaryDamageAboveTen,
        apply = function() return applyGunPenalty("damage_minus_four") end,
    },
    {
        id = "bad_projectile_speed_half", name = "SLOW SHOTS", amount = "-50% SPEED", rarity = "evil",
        visualType = "weapon", cardType = "bad", description = "Projectile speed is reduced by half.",
        apply = function() return applyGunPenalty("projectile_speed_half") end,
    },
    {
        id = "bad_damage_half", name = "HALF POWER", amount = "-50% DAMAGE", rarity = "evil",
        visualType = "weapon", cardType = "bad", description = "Projectile damage is reduced by half.",
        isAvailable = primaryDamageAboveTen,
        apply = function() return applyGunPenalty("damage_half") end,
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

function CardDefinitions:getEligibleBadCards()
    local result = {}
    for _, card in ipairs(self.badCards or {}) do
        if self:isCardEligible(card, false) then
            result[#result + 1] = card
        end
    end
    return result
end

function CardDefinitions:getRandomWeaponCard(excludedId)
    local candidates = {}
    local totalWeight = 0

    local currentWeapon = Player and Player.gun and Player.gun.primary_weapon
    local currentWeaponId = currentWeapon and currentWeapon.index
    for _, card in ipairs(self.weaponCards or {}) do
        if card.id ~= excludedId and card.weaponId ~= currentWeaponId then
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
