local EncounterWaves = {
    {
        id = "small_mob",
        minDifficulty = 1,
        chance = 8,
        count = {
            min = 2,
            max = 2,
            perDifficulty = 0.5,
        },
        enemyTypes = {
            { id = "zombie", weight = 12 },
            { id = "babyZombie", weight = 2 },
            { id = "noHead", weight = 4 },
        },
    },
    {
        id = "mixed_mob",
        minDifficulty = 1,
        chance = 7,
        count = {
            min = 2,
            max = 2,
            perDifficulty = 0.5,
        },
        enemyTypes = {
            { id = "zombie", weight = 10 },
            { id = "babyZombie", weight = 3 },
            { id = "noHead", weight = 4 },
        },
    },
    {
        id = "big_pressure",
        minDifficulty = 2,
        chance = 3,
        count = {
            min = 2,
            max = 2,
            perDifficulty = 0.5,
        },
        enemyTypes = {
            { id = "babyZombie", weight = 3 },
            { id = "bigZombie", weight = 2 },
        },
        maxPerWave = {
            bigZombie = 2,
        },
    },
    {
        id = "zombie_horde",
        minDifficulty = 2,
        chance = 2,
        count = {
            min = 4,
            max = 5,
            perDifficulty = 0.5,
        },
        useWaveEnemyTypes = true,
        allowAdditionalWave = false,
        enemyTypes = {
            { id = "zombie", weight = 1 },
        },
    },
}

EncounterWaves.additional = {
    {
        id = "little_spider",
        minDifficulty = 1,
        count = {
            min = 2,
            max = 3,
        },
        enemyTypes = {
            { id = "spider", weight = 1 },
            { id = "fly", weight = 1 },
        },
    },
}

return EncounterWaves
