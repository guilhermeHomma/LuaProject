local EncounterWaves = require("scripts/config/encounterWaves")

local FloorEncounterConfig = {}

FloorEncounterConfig.enemyPools = {
    florestEarly = {
        { id = "zombie", weight = 8 },
        { id = "babyZombie", weight = 3 },
        { id = "noHead", weight = 3 },
    },
    florestMid = {
        { id = "zombie", weight = 6 },
        { id = "babyZombie", weight = 4 },
        { id = "noHead", weight = 3 },
        { id = "bigZombie", weight = 1 },
    },
    florestLate = {
        { id = "zombie", weight = 4 },
        { id = "babyZombie", weight = 5 },
        { id = "noHead", weight = 4 },
        { id = "bigZombie", weight = 2 },
    },
    caveEarly = {
        { id = "zombie", weight = 2 },
        { id = "babyZombie", weight = 5 },
        { id = "noHead", weight = 4 },
        { id = "bigZombie", weight = 2 },
    },
    caveMid = {
        { id = "zombie", weight = 1 },
        { id = "babyZombie", weight = 5 },
        { id = "noHead", weight = 4 },
        { id = "bigZombie", weight = 3 },
    },
    caveLate = {
        { id = "zombie", weight = 1 },
        { id = "babyZombie", weight = 4 },
        { id = "noHead", weight = 5 },
        { id = "bigZombie", weight = 4 },
    },
}

local function createFloorEncounter(options)
    return {
        difficulty = options.difficulty,
        spawnEntryAvoidDistanceTiles = options.spawnEntryAvoidDistanceTiles,
        totalWaves = options.totalWaves,
        simultaneousWaves = options.simultaneousWaves,
        enemyTypes = FloorEncounterConfig.enemyPools[options.enemyPool] or options.enemyTypes,
        maxPerWave = options.maxPerWave,
    }
end

FloorEncounterConfig.base = {
    enabled = true,
    startRoom = false,
    spawnMinDistanceTiles = 5,
    spawnEntryAvoidDistanceTiles = 5,
    spawnPlayerAvoidDistanceTiles = 5,
    waveTemplates = EncounterWaves,
    additionalWaveTemplates = EncounterWaves.additional,
}

FloorEncounterConfig.floors = {
    [1] = createFloorEncounter({
        difficulty = 1,
        totalWaves = {min = 2, max = 3},
        simultaneousWaves = {min = 1, max = 2},
        enemyPool = "florestEarly",
        maxPerWave = {
            noHead = 2,
            bigZombie = 0,
        },
    }),
    [2] = createFloorEncounter({
        difficulty = 2,
        spawnEntryAvoidDistanceTiles = 6,
        totalWaves = {min = 2, max = 4},
        simultaneousWaves = {min = 2, max = 2},
        enemyPool = "florestMid",
        maxPerWave = {
            noHead = 2,
            bigZombie = 1,
        },
    }),
    [3] = createFloorEncounter({
        difficulty = 3,
        spawnEntryAvoidDistanceTiles = 6,
        totalWaves = {min = 3, max = 4},
        simultaneousWaves = {min = 2, max = 2},
        enemyPool = "florestLate",
        maxPerWave = {
            noHead = 2,
            bigZombie = 2,
        },
    }),
    [4] = createFloorEncounter({
        difficulty = 4,
        spawnEntryAvoidDistanceTiles = 6,
        totalWaves = {min = 3, max = 4},
        simultaneousWaves = {min = 2, max = 3},
        enemyPool = "caveEarly",
        maxPerWave = {
            noHead = 3,
            bigZombie = 2,
        },
    }),
    [5] = createFloorEncounter({
        difficulty = 5,
        spawnEntryAvoidDistanceTiles = 7,
        totalWaves = {min = 3, max = 5},
        simultaneousWaves = {min = 2, max = 3},
        enemyPool = "caveMid",
        maxPerWave = {
            noHead = 3,
            bigZombie = 3,
        },
    }),
    [6] = createFloorEncounter({
        difficulty = 6,
        spawnEntryAvoidDistanceTiles = 7,
        totalWaves = {min = 4, max = 5},
        simultaneousWaves = {min = 2, max = 3},
        enemyPool = "caveLate",
        maxPerWave = {
            noHead = 4,
            bigZombie = 3,
        },
    }),
}

return FloorEncounterConfig
