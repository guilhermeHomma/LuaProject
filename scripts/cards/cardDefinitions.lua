local CardDefinitions = {}

CardDefinitions.rarities = {
    common = {
        label = "common",
        weight = 1,
        color = {0.18, 0.13, 0.18, 1},
    },
    rare = {
        label = "rare",
        weight = 0,
        color = {0.05, 0.18, 0.34, 1},
    },
    epic = {
        label = "epic",
        weight = 0,
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
        description = "Primary weapon damage.",
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
        description = "Primary weapon range.",
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
        description = "Fill secondary weapon.",
        requiresSecondary = true,
        apply = function()
            return Player and Player.gun and Player.gun:applyCardUpgrade("secondary_fill")
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

return CardDefinitions
