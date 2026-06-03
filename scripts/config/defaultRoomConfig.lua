local DefaultRoomConfig = {}

DefaultRoomConfig.currentFloorIndex = 1

DefaultRoomConfig.floorLevels = {
    {
        id = 1,
        name = "Floor 1",
        difficulty = 1,
        roomCount = {min = 8, max = 12},
        cardRoomChance = 1.0,
        cardRoomCount = {min = 3, max = 3},
        visualThemes = {
            default = "florest",
            startRoomUseDefault = true,
            areas = {},
        },
        enemyDropMultiplier = 1,
        shopProducts = {
            { id = "squaregun", weight = 5 },
            { id = "longshot", weight = 3 },
        },
    },
    {
        id = 2,
        name = "Floor 2",
        difficulty = 2,
        roomCount = {min = 10, max = 14},
        cardRoomChance = 1.0,
        cardRoomCount = {min = 2, max = 3},
        visualThemes = {
            default = "cave",
            startRoomUseDefault = false,
            areas = {},
        },
        enemyDropMultiplier = 1.2,
        shopProducts = {
            --{ id = "squaregun", weight = 10 },
            --{ id = "longshot", weight = 15 },
            { id = "cakegun", weight = 35 },
            { id = "shotgun", weight = 25 },
            { id = "raygun", weight = 3 },
        },
    },
}

DefaultRoomConfig.roomEncounterConfig = {
    templateOverrides = {
        basic_32x32 = {
            emptyChance = 0.02,
            countMultiplier = 0.7,
        },
        wide_48x32 = {
            countMultiplier = 0.85,
            countAdd = 0,
        },
        tall_32x48 = {
            countMultiplier = 0.85,
            countAdd = 0,
        },
        large_48x48 = {
            countMultiplier = 1.1,
            countAdd = 0,
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
    end_32x32 = {
        box = 0,
        chest = 0,
    },
}

DefaultRoomConfig.floorPathTiles = {
    clusterSeedChance = 0.15,
    clusterMin = 6,
    clusterMax = 10,
    spreadRadius = 2,
    looseChance = 0.018,
    templateOverrides = {
        store_32x32 = {
            pathChance = 0.94,
            sideTileChance = 0.54,
            branchChance = 0.34,
            looseChance = 0.07,
            branchMin = 3,
            branchMax = 7,
        },
        cards_32x32 = {
            pathChance = 0.96,
            sideTileChance = 0.62,
            branchChance = 0.42,
            looseChance = 0.09,
            branchMin = 3,
            branchMax = 8,
        },
    },
}

DefaultRoomConfig.wallVariantTiles = {
    coverage = 0.34,
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
        endRoomTemplateId = "end_32x32",
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
            basic_32x32 = 5,
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
    ammoPrice = 150,
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
