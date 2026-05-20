local EncounterWaves = {
    {
        id = "small_mob",
        minDifficulty = 1,
        chance = 8,
        count = {
            min = 2,
            max = 3,
            perDifficulty = 1,
        },
        enemyTypes = {
            { id = "zombie", weight = 6 },
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
            max = 4,
            perDifficulty = 1,
        },
        enemyTypes = {
            { id = "zombie", weight = 5 },
            { id = "babyZombie", weight = 3 },
            { id = "noHead", weight = 4 },
            { id = "bigZombie", weight = 2, minDifficulty = 2 },
        },
    },
    {
        id = "big_pressure",
        minDifficulty = 2,
        chance = 3,
        count = {
            min = 2,
            max = 4,
            perDifficulty = 1,
        },
        enemyTypes = {
            { id = "zombie", weight = 2 },
            { id = "babyZombie", weight = 3 },
            { id = "bigZombie", weight = 4 },
            { id = "noHead", weight = 2 },
        },
        maxPerWave = {
            bigZombie = 2,
        },
    },
}

return EncounterWaves
