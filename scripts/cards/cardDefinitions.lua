local CardDefinitions = {}

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
        amount = "+5%",
        rarity = "common",
        visualType = "player",
        description = "Move faster.",
        requiresSecondary = false,
        apply = function()
            if Player then
                Player.speed = Player.speed * 1.05
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
        id = "secondary_fill",
        name = "CHARGE",
        amount = "FULL",
        rarity = "common",
        visualType = "weapon",
        description = "Fill secondary weapon.",
        requiresSecondary = true,
        apply = function()
            return Player and Player.gun and Player.gun:applyCardUpgrade("secondary_fill")
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

function CardDefinitions:getRarity(card)
    return self.rarities[card.rarity] or self.rarities.common
end

function CardDefinitions:getEligibleCards()
    local result = {}
    local hasSecondary = Player and Player.gun and Player.gun.secondary_weapon ~= nil

    for _, card in ipairs(self.cards) do
        if not card.requiresSecondary or hasSecondary then
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

function CardDefinitions:getRandomRarity()
    if math.random() < (self.rarities.rare.weight or 0) then
        return "rare"
    end
    return "common"
end

return CardDefinitions
