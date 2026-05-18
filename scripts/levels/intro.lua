local IntroLevel = {}

local tilemapSystem = require("scripts/tilemaps/defaultSystem")

IntroLevel.id = "intro"
IntroLevel.name = "Intro"
IntroLevel.baseWidth = 960
IntroLevel.baseHeight = 540
IntroLevel.worldScaleX = 3
IntroLevel.yScale = 2.4
IntroLevel.enableTrails = false
IntroLevel.renderDistances = {
    soft = 280,
    hard = 350,
    nearbyEnemy = 360,
    footstepCleanup = 250,
}
IntroLevel.lightConfig = {
    generalShadow = {
        minBrightness = 0.65,
        color = {0, 0, 0.7},
    },
}
IntroLevel.spawnMinDistance = 240
IntroLevel.window = {
    width = 960,
    height = 540,
}
IntroLevel.tilemapConfig = {
    mapImage = "assets/sprites/map4.png",
    tilemapOrigin = {
        x = -40 * 16,
        y = -40 * 16,
    },
}

IntroLevel.cameraBounds = {
    minLeft = -1740,
    maxRight = 838,
    minDown = 10060,
    maxTop = -1620,
}

IntroLevel.playerSpawn = {
    x = 30,
    y = 340,
}

function IntroLevel:getCameraBounds()
    return self.cameraBounds
end

function IntroLevel:setCameraBounds(bounds)
    for key, value in pairs(bounds) do
        self.cameraBounds[key] = value
    end
end

function IntroLevel:resetRuntimeState()
    self.cameraBounds = {
        minLeft = -1740,
        maxRight = 838,
        minDown = 10060,
        maxTop = -1620,
    }
end

function IntroLevel:getTilemapSystem()
    return tilemapSystem
end

function IntroLevel:getPlayerSpawn()
    return self.playerSpawn.x, self.playerSpawn.y
end

return IntroLevel
