local LightConfig = {
    activeType = "player",
    maxWorldLights = 32,
    maxGroundLightOccluders = 128,
    groundLightOcclusion = {
        enabled = true,
        strength = 0.15,
    },
    types = {
        player = {
            generalShadow = {
                minBrightness = 0.65,
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
                    calculationDistance = 320,
                    visual = {
                        enabled = true,
                        scale = 0.42,
                        alpha = 0.09,
                        color = {0.9, 0.78, 0.12},
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
                    enabled = true,
                    calculationDistance = 180,
                    visual = {
                        enabled = true,
                        scale = 0.13,
                        alpha = 0.035,
                        color = {0.75, 0.92, 1.0},
                    },
                    spriteBrightness = {
                        enabled = true,
                        minDistance = 4,
                        maxDistance = 34,
                        maxBrightness = 0.70,
                    },
                    groundLight = {
                        enabled = true,
                        innerRadius = 8,
                        outerRadius = 108,
                        maxBrightness = 0.75,
                    },
                },
                enemyProjectile = {
                    enabled = true,
                    calculationDistance = 180,
                    visual = {
                        enabled = true,
                        scale = 0.13,
                        alpha = 0.04,
                        color = {1.0, 0.28, 0.18},
                    },
                    spriteBrightness = {
                        enabled = true,
                        minDistance = 4,
                        maxDistance = 34,
                        maxBrightness = 0.70,
                    },
                    groundLight = {
                        enabled = true,
                        innerRadius = 8,
                        outerRadius = 108,
                        maxBrightness = 0.75,
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
    local levelLightConfig = CURRENT_LEVEL and CURRENT_LEVEL.lightConfig
    if levelLightConfig and levelLightConfig.generalShadow then
        return levelLightConfig.generalShadow
    end

    if CURRENT_LEVEL and CURRENT_LEVEL.generalShadow then
        return CURRENT_LEVEL.generalShadow
    end

    local active = self:getActive()
    return active and active.generalShadow or {}
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
