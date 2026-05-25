local EncounterWaves = require("scripts/config/encounterWaves")

local FloorEncounterConfig = {}

FloorEncounterConfig.base = {
    enabled = true,
    startRoom = false,
    spawnMinDistanceTiles = 4,
    spawnEntryAvoidDistanceTiles = 4,
    waveTemplates = EncounterWaves,
}

FloorEncounterConfig.floors = {
    [1] = {
        difficulty = 1,
        -- Use this file for floor balance: enemy pool and wave rhythm.
        totalWaves = {min = 1, max = 2},
        simultaneousWaves = {min = 1, max = 1},
        enemyTypes = {
            { id = "zombie", weight = 8 },
            { id = "babyZombie", weight = 3 },
            { id = "noHead", weight = 2 },
        },
        maxPerWave = {
            noHead = 2,
            bigZombie = 0,
        },
    },
    [2] = {
        difficulty = 2,
        spawnEntryAvoidDistanceTiles = 6,
        totalWaves = {min = 2, max = 3},
        simultaneousWaves = {min = 1, max = 2},
        enemyTypes = {
            { id = "zombie", weight = 6 },
            { id = "babyZombie", weight = 5 },
            { id = "noHead", weight = 3 },
            { id = "bigZombie", weight = 2 },
        },
        maxPerWave = {
            noHead = 2,
            bigZombie = 2,
        },
    },
}

return FloorEncounterConfig
