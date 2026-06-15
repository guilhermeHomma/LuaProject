local LightConfig = {
    activeType = "player",
    maxWorldLights = 32,
    maxGroundLightOccluders = 32,
    groundLightOcclusion = {
        enabled = true,
        strength = 0.15,
    },
    types = {
        player = {
            generalShadow = {
                minBrightness = 0.62,
                color = {0, 0.1, 0.5},
            },
            worldLights = {
                player = {
                    enabled = true,
                    visual = {
                        enabled = true,
                        scale = 0.65,
                        alpha = 0.18,
                        color = {1, 0.98, 0.82},
                    },
                    spriteBrightness = {
                        enabled = true,
                        minDistance = 35,
                        maxDistance = 90,
                        maxBrightness = 1,
                    },
                    groundLight = {
                        enabled = true,
                        innerRadius = 105,
                        outerRadius = 330,
                        maxBrightness = 0.9,
                    },
                },
                pole = {
                    enabled = true,
                    calculationDistance = 350,
                    visual = {
                        enabled = true,
                        scale = 0.42,
                        alpha = 0.09,
                        color = {0.9, 0.78, 0.12},
                        glowScale = 0.55,
                        glowAlpha = 0.055,
                        flickerAmount = 0.02,
                        flickerSpeed = 1.6,
                        flickerScale = true,
                    },
                    spriteBrightness = {
                        enabled = true,
                        minDistance = 10,
                        maxDistance = 80,
                        maxBrightness = 1,
                    },
                    groundLight = {
                        enabled = true,
                        innerRadius = 68,
                        outerRadius = 200,
                        maxBrightness = 1,
                    },
                    animation = {
                        frameCount = 5,
                        frameTime = 0.12,
                        scaleX = 1,
                        scaleY = 1.5,
                        lightOffsetX = 0,
                        lightOffsetY = -14,
                    },
                },
                moonbeam = {
                    enabled = true,
                    visual = {
                        enabled = true,
                        scale = 0.36,
                        alpha = 0.075,
                        color = {0.54, 0.72, 0.94},
                    },
                    spriteBrightness = {
                        enabled = false,
                    },
                    groundLight = {
                        enabled = true,
                        innerRadius = 55,
                        outerRadius = 230,
                        maxBrightness = 0.86,
                    },
                },
                projectile = {
                    enabled = false,
                    calculationDistance = 180,
                    visual = {
                        enabled = false,
                        scale = 0.13,
                        alpha = 0.04,
                        color = {1.0, 0.28, 0.18},
                        glowScale = 0.1,
                        glowAlpha = 0.055,
                    },
                    spriteBrightness = {
                        enabled = false,
                        minDistance = 4,
                        maxDistance = 34,
                        maxBrightness = 0.70,
                    },
                    groundLight = {
                        enabled = true,
                        innerRadius = 8,
                        outerRadius = 48,
                        maxBrightness = 0.25,
                        additive = true,
                        additiveStrength = 0.1,
                    },
                },
                enemyProjectile = {
                    enabled = false,
                    calculationDistance = 180,
                    visual = {
                        enabled = false,
                        scale = 0.13,
                        alpha = 0.04,
                        color = {1.0, 0.28, 0.18},
                        glowScale = 0.1,
                        glowAlpha = 0.055,
                    },
                    spriteBrightness = {
                        enabled = false,
                        minDistance = 4,
                        maxDistance = 34,
                        maxBrightness = 0.70,
                    },
                    groundLight = {
                        enabled = true,
                        innerRadius = 8,
                        outerRadius = 48,
                        maxBrightness = 0.25,
                        additive = true,
                        additiveStrength = 0.1,
                    },
                },
            },
        },
    },
}

function LightConfig:getActive()
    return self.types[self.activeType] or self.types.player
end

function LightConfig:getWorldLightConfig(lightType)
    local active = self:getActive()
    local worldLights = active and active.worldLights or {}
    return worldLights[lightType]
end

function LightConfig:getGeneralShadow()
    local FloorManager = package.loaded["scripts/managers/floorManager"]
    local theme = FloorManager and FloorManager.getCurrentRoomTheme and FloorManager:getCurrentRoomTheme()
    local room = FloorManager and FloorManager.getCurrentRoom and FloorManager:getCurrentRoom()
    local cacheKey = tostring(theme) .. tostring(room) .. tostring(self.activeType) .. tostring(CURRENT_LEVEL)

    if self._generalShadowCache and self._generalShadowCacheKey == cacheKey then
        return self._generalShadowCache
    end

    local levelLightConfig = CURRENT_LEVEL and CURRENT_LEVEL.lightConfig
    local result = nil

    if levelLightConfig and levelLightConfig.generalShadow then
        result = levelLightConfig.generalShadow
    elseif CURRENT_LEVEL and CURRENT_LEVEL.generalShadow then
        result = CURRENT_LEVEL.generalShadow
    else
        local active = self:getActive()
        result = active and active.generalShadow or {}
    end

    if theme and theme.generalShadow then
        local copy = {}
        for key, value in pairs(result or {}) do
            copy[key] = value
        end

        local shadow = theme.generalShadow
        if shadow.minBrightnessMultiplier then
            copy.minBrightness = (copy.minBrightness or 1) * shadow.minBrightnessMultiplier
        end
        if shadow.minBrightness ~= nil then
            copy.minBrightness = shadow.minBrightness
        end
        if shadow.color then
            copy.color = shadow.color
        end

        result = copy
    end

    if room and (room.isShopRoom or room.isCardRoom) and not (theme and theme.lootLightBoost == false) then
        local copy = {}
        for key, value in pairs(result or {}) do
            copy[key] = value
        end
        copy.minBrightness = math.max(copy.minBrightness or 0, 0.6)
        result = copy
    end

    self._generalShadowCache = result
    self._generalShadowCacheKey = cacheKey
    return result
end

function LightConfig:getMaxWorldLights()
    return self.maxWorldLights or 8
end

function LightConfig:getMaxGroundLightOccluders()
    return self.maxGroundLightOccluders or 0
end

function LightConfig:getGroundLightOcclusion()
    return self.groundLightOcclusion or {}
end

return LightConfig
