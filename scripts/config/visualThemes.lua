local VisualThemes = {}

VisualThemes.defaultThemeId = "florest"

VisualThemes.themes = {
    florest = {
        id = "florest",
        tileset = "assets/sprites/florest/tileset.png",
        ground = "assets/sprites/florest/ground.png",
        hasTrees = true,
        wallGrass = true,
        leafParticles = true,
        clouds = true,
        music = "default",
        lootLightBoost = true,
        ambience = {
            crow = true,
            cricket = true,
            owl = true,
        },
    },
    cave = {
        id = "cave",
        tileset = "assets/sprites/cave/tileset.png",
        ground = "assets/sprites/cave/ground.png",
        hasTrees = false,
        wallGrass = false,
        leafParticles = false,
        clouds = false,
        music = "default",
        lootLightBoost = false,
        ambience = {
            crow = false,
            cricket = true,
            owl = false,
        },
        generalShadow = {
            minBrightnessMultiplier = 0.5,
            color = {0.42, 0.24, 0.12},
        },
        removeSurroundedPoles = true,
    },
}

local function clampChance(chance)
    if chance == nil then
        return 1
    end

    return math.max(0, math.min(chance, 1))
end

local function roomMatchesRule(room, rule)
    if not room or not rule then
        return false
    end

    local x = room.gridX or 0
    local y = room.gridY or 0
    local distance = room.distanceFromStart or (math.abs(x) + math.abs(y))

    if rule.minX and x < rule.minX then
        return false
    end
    if rule.maxX and x > rule.maxX then
        return false
    end
    if rule.minY and y < rule.minY then
        return false
    end
    if rule.maxY and y > rule.maxY then
        return false
    end
    if rule.minAbsX and math.abs(x) < rule.minAbsX then
        return false
    end
    if rule.minAbsY and math.abs(y) < rule.minAbsY then
        return false
    end
    if rule.minDistance and distance < rule.minDistance then
        return false
    end
    if rule.maxDistance and distance > rule.maxDistance then
        return false
    end

    return true
end

function VisualThemes:get(themeId)
    return self.themes[themeId] or self.themes[self.defaultThemeId]
end

function VisualThemes:getDefault()
    return self:get(self.defaultThemeId)
end

function VisualThemes:getDefaultId(themeConfig)
    return themeConfig and themeConfig.default or self.defaultThemeId
end

function VisualThemes:chooseRoomTheme(room, themeConfig)
    local defaultThemeId = self:getDefaultId(themeConfig)

    if not room then
        return defaultThemeId
    end

    if room.isCardRoom and themeConfig and themeConfig.cardRoomTheme then
        return themeConfig.cardRoomTheme
    end

    if themeConfig and themeConfig.specialRoomsUseDefault == true
        and (room.isShopRoom or room.isCardRoom) then
        return defaultThemeId
    end

    if themeConfig and themeConfig.shopRoomsUseDefault == true and room.isShopRoom then
        return defaultThemeId
    end

    if themeConfig and themeConfig.cardRoomsUseDefault == true and room.isCardRoom then
        return defaultThemeId
    end

    if themeConfig and themeConfig.startRoomUseDefault ~= false
        and (room.distanceFromStart or 0) <= 0 then
        return defaultThemeId
    end

    if room.themeId and self.themes[room.themeId] then
        return room.themeId
    end

    for _, rule in ipairs(themeConfig and themeConfig.rules or {}) do
        local themeId = rule.theme or rule.themeId
        if themeId and self.themes[themeId] and roomMatchesRule(room, rule)
            and math.random() <= clampChance(rule.chance) then
            return themeId
        end
    end

    return defaultThemeId
end

return VisualThemes
