local ZombieStressTestLevel = {}

local tilemapSystem = require("scripts/tilemaps/defaultSystem")
local Tilemap = require("scripts/tilemap")
local ZombieStressTestSpawner = require("scripts/managers/zombieStressTestSpawner")

ZombieStressTestLevel.id = "zombieStressTest"
ZombieStressTestLevel.name = "Zombie Stress Test"
ZombieStressTestLevel.baseWidth = 1280
ZombieStressTestLevel.baseHeight = 720
ZombieStressTestLevel.worldScaleX = 3
ZombieStressTestLevel.yScale = 2.4
ZombieStressTestLevel.enableWaves = false
ZombieStressTestLevel.enableTrails = false
ZombieStressTestLevel.skipStartRoomSafetyLogic = true
ZombieStressTestLevel.currentFloorIndex = 1
ZombieStressTestLevel.spawnMinDistance = 170
ZombieStressTestLevel.renderDistances = {
    soft = 340,
    hard = 430,
    nearbyEnemy = 520,
    footstepCleanup = 300,
}
ZombieStressTestLevel.window = {
    width = 1280,
    height = 720,
}
ZombieStressTestLevel.lightConfig = {
    generalShadow = {
        minBrightness = 0.75,
        color = {0, 0, 0.45},
    },
}
ZombieStressTestLevel.tilemapConfig = {
    mapImage = "assets/maps/48x48/map.png",
    centerOrigin = true,
}
ZombieStressTestLevel.floorConfig = {
    startRoomId = "stress:0",
    generate = {
        enabled = false,
    },
    rooms = {
        {
            id = "stress:0",
            templateId = "large_48x48",
            gridX = 0,
            gridY = 0,
            distanceFromStart = 0,
            doors = {},
            neighbors = {},
            tilemapConfig = ZombieStressTestLevel.tilemapConfig,
            spawnPoints = {},
            state = {
                visited = true,
                discovered = true,
                cleared = false,
                skipEncounter = true,
                encounterSpawned = false,
                encounterCompleted = false,
                openedDoors = {},
                brokenObjects = {},
                killedEnemies = {},
                drops = {},
            },
        },
    },
}
ZombieStressTestLevel.roomEncounterConfig = {
    enabled = false,
}
ZombieStressTestLevel.objectSpawnChances = {}
ZombieStressTestLevel.objectSpawnChancesByTemplate = {}
ZombieStressTestLevel.grassConfig = {
    nonWalkableChance = 0.14,
    bigGrassChance = 0.05,
    nonWalkableBigGrassChance = 0.05,
}
ZombieStressTestLevel.floorPathTiles = {}
ZombieStressTestLevel.wallVariantTiles = {}
ZombieStressTestLevel.shopConfig = {
    enabled = false,
}
ZombieStressTestLevel.moonbeamConfig = {
    enabled = false,
}
ZombieStressTestLevel.ambientDustConfig = {
    enabled = false,
}
ZombieStressTestLevel.fixedCameraSize = {
    width = 1088,
    height = 612,
}
ZombieStressTestLevel.cameraFocus = {
    x = 0,
    y = 40 / ZombieStressTestLevel.yScale,
}
ZombieStressTestLevel.spawnerConfig = {
    spawnPerSecond = 1,
    maxZombies = 80,
    minPlayerDistance = 170,
    avoidEnemyRadius = 14,
}
ZombieStressTestLevel.playerSpawnConfig = {
    preferredMapX = 24,
    preferredMapY = 24,
    nearestWalkableRadius = 24,
}

local function createRoomState()
    return {
        visited = true,
        discovered = true,
        cleared = false,
        skipEncounter = true,
        encounterSpawned = false,
        encounterCompleted = false,
        openedDoors = {},
        brokenObjects = {},
        killedEnemies = {},
        drops = {},
    }
end

function ZombieStressTestLevel:resetRuntimeState()
    self.spawner = ZombieStressTestSpawner:new(self.spawnerConfig)
    self.floorConfig.rooms[1].state = createRoomState()
end

function ZombieStressTestLevel:getTilemapSystem()
    return tilemapSystem
end

function ZombieStressTestLevel:getPlayerSpawn()
    local config = self.playerSpawnConfig or {}
    local mapX = config.preferredMapX or 24
    local mapY = config.preferredMapY or 24
    local worldX, worldY = Tilemap:mapToWorld(mapX, mapY)

    if Tilemap.getNearestWalkableWorldPosition then
        worldX, worldY = Tilemap:getNearestWalkableWorldPosition(
            worldX,
            worldY,
            config.nearestWalkableRadius or 24
        )
    end

    if not worldX or not worldY then
        worldX, worldY = Tilemap:getRandomSpawnPosition(nil, 0)
    end

    return worldX or 0, worldY or 0
end

function ZombieStressTestLevel:update(game, dt)
    if self.spawner then
        self.spawner:update(game, dt)
    end
end

function ZombieStressTestLevel:updateCamera(camera, target, dt)
    camera:setFixedMode(
        target.x,
        target.y - 20,
        self.fixedCameraSize.width,
        self.fixedCameraSize.height,
        3.5
    )
end

return ZombieStressTestLevel
