local DefaultRoomConfig = {}
local EncounterWaves = require("scripts/config/encounterWaves")

DefaultRoomConfig.currentFloorIndex = 1

DefaultRoomConfig.floorLevels = {
    {
        id = 1,
        name = "Floor 1",
        difficulty = 1,
        roomCount = {min = 8, max = 12},
        cardRoomChance = 1.0,
        cardRoomCount = {min = 3, max = 3},
        enemyDropMultiplier = 1,
        shopProducts = {
            { id = "squaregun", weight = 5 },
            { id = "longshot", weight = 4 },
        },
    },
    {
        id = 2,
        name = "Floor 2",
        difficulty = 2,
        roomCount = {min = 10, max = 14},
        cardRoomChance = 1.0,
        cardRoomCount = {min = 2, max = 3},
        enemyDropMultiplier = 1.2,
        shopProducts = {
            { id = "squaregun", weight = 10 },
            { id = "longshot", weight = 15 },
            { id = "cakegun", weight = 35 },
            { id = "shotgun", weight = 25 },
            { id = "raygun", weight = 3 },
        },
    },
}

DefaultRoomConfig.roomEncounterConfig = {
    enabled = true,
    startRoom = false,
    difficulty = 1,
    distanceDifficulty = {
        {
            minDistance = 5,
            difficulty = 2,
            totalWaves = {min = 2, max = 4},
            simultaneousWaves = {min = 2, max = 2},
            countMultiplier = 1.2,
        },
    },
    spawnMinDistanceTiles = 4,
    totalWaves = {min = 1, max = 2},
    simultaneousWaves = {min = 1, max = 1},
    waveTemplates = EncounterWaves,
    templateOverrides = {
        basic_32x32 = {
            emptyChance = 0.02,
            totalWaves = {min = 1, max = 2},
            simultaneousWaves = {min = 1, max = 1},
            waveChances = {
                small_mob = 10,
                mixed_mob = 4,
                big_pressure = 0,
            },
            countMultiplier = 0.75,
            enemyTypeWeights = {
                zombie = 8,
                babyZombie = 3,
                noHead = 1,
                bigZombie = 1,
            },
            maxPerWave = {
                noHead = 1,
            },
        },
        wide_48x32 = {
            totalWaves = {min = 1, max = 2},
            simultaneousWaves = {min = 1, max = 1},
            countMultiplier = 1,
            countAdd = 0,
        },
        tall_32x48 = {
            totalWaves = {min = 1, max = 2},
            simultaneousWaves = {min = 1, max = 1},
            countMultiplier = 1,
            countAdd = 0,
        },
        large_48x48 = {
            totalWaves = {min = 2, max = 3},
            simultaneousWaves = {min = 1, max = 2},
            countMultiplier = 1.05,
            countAdd = 1,
            enemyTypeWeights = {
                zombie = 6,
                babyZombie = 4,
                noHead = 5,
                bigZombie = 3,
            },
        },
    },
}

DefaultRoomConfig.objectSpawnChances = {
    box = 0.70,
    chest = 0.50,
}

DefaultRoomConfig.objectSpawnChancesByTemplate = {
    basic_32x32 = {
        chest = 0.50,
    },
    wide_48x32 = {
        chest = 0.50,
    },
    tall_32x48 = {
        chest = 0.50,
    },
    large_48x48 = {
        chest = 0.70,
    },
}

DefaultRoomConfig.floorPathTiles = {
    clusterSeedChance = 0.15,
    clusterMin = 6,
    clusterMax = 10,
    spreadRadius = 2,
    looseChance = 0.018,
}

DefaultRoomConfig.wallVariantTiles = {
    coverage = 0.24,
    noise = 0.03,
    patchMin = 10,
    patchMax = 17,
    branchChance = 0.84,
}

DefaultRoomConfig.floorConfig = {
    startRoomId = "0:0",
    generate = {
        enabled = true,
        roomCount = 8,
        startTemplateId = "start_32x32",
        shopRoomTemplateId = "store_32x32",
        shopDistanceMin = 2,
        shopDistanceMax = 4,
        cardRoomTemplateId = "cards_32x32",
        cardRoomChance = 1.0,
        cardRoomCount = {min = 2, max = 3},
        largeRoomOppositeExit = true,
        templateIds = {
            "basic_32x32",
            "wide_48x32",
            "tall_32x48",
            "large_48x48",
        },
        templateWeights = {
            basic_32x32 = 3,
            wide_48x32 = 2,
            tall_32x48 = 2,
            large_48x48 = 1,
        },
        endRoomChance = 0.35,
        endTemplateWeights = {
            basic_32x32 = 4,
            wide_48x32 = 1,
            tall_32x48 = 1,
            large_48x48 = 1,
        },
        extraConnectionChance = 0.12,
    },
}

DefaultRoomConfig.shopConfig = {
    enabled = true,
    ammoProductId = "full_bullets",
    ammoChance = 0.40,
    ammoPrice = 300,
    cardProductId = "card_upgrade",
    cardPrice = 200,
    cardRoomDoubleShopChance = 0.10,
    cardChestSecondChance = 0.10,
    products = {
        { id = "squaregun", weight = 40 },
        { id = "longshot", weight = 25 },
        { id = "cakegun", weight = 20 },
        { id = "shotgun", weight = 15 },
        { id = "raygun", weight = 5 },
    },
}

return DefaultRoomConfig
