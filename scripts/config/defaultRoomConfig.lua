local DefaultRoomConfig = {}

DefaultRoomConfig.currentFloorIndex = 1

DefaultRoomConfig.roomTemplateSets = {
    florest = {
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
        endTemplateWeights = {
            basic_32x32 = 4,
            wide_48x32 = 1,
            tall_32x48 = 1,
            large_48x48 = 1,
        },
    },
    cave = {
        templateIds = {
            "basic_32x32",
            "wide_48x32",
            "tall_32x48",
            "large_48x48",
        },
        templateWeights = {
            basic_32x32 = 4,
            wide_48x32 = 2,
            tall_32x48 = 2,
            large_48x48 = 2,
        },
        endTemplateWeights = {
            basic_32x32 = 3,
            wide_48x32 = 1,
            tall_32x48 = 1,
            large_48x48 = 2,
        },
    },
}

DefaultRoomConfig.shopProductSets = {
    florestEarly = {
        { id = "squaregun", weight = 5 },
        { id = "longshot", weight = 3 },
    },
    florestLate = {
        { id = "squaregun", weight = 5 },
        { id = "longshot", weight = 5 },
        { id = "cakegun", weight = 2 },
    },
    cave = {
        { id = "cakegun", weight = 35 },
        { id = "shotgun", weight = 25 },
        { id = "raygun", weight = 3 },
    },
}

local function createFloorLevel(options)
    return {
        id = options.id,
        name = options.name or ("Floor " .. tostring(options.id)),
        difficulty = options.difficulty,
        roomCount = options.roomCount,
        cardRoomChance = options.cardRoomChance or 1.0,
        cardRoomCount = options.cardRoomCount or {min = 2, max = 3},
        roomTemplateSet = options.roomTemplateSet or options.theme,
        visualThemes = {
            default = options.theme,
            startRoomUseDefault = options.startRoomUseDefault,
            areas = {},
        },
        grassConfig = options.grassConfig,
        enemyDropMultiplier = options.enemyDropMultiplier or 1,
        shopProducts = DefaultRoomConfig.shopProductSets[options.shopProductSet] or options.shopProducts,
    }
end

DefaultRoomConfig.floorLevels = {
    createFloorLevel({
        id = 1,
        difficulty = 1,
        roomCount = {min = 8, max = 12},
        cardRoomCount = {min = 3, max = 3},
        theme = "florest",
        startRoomUseDefault = true,
        grassConfig = {
            nonWalkableChance = 0.16,
            bigGrassChance = 0.05,
            nonWalkableBigGrassChance = 0.15,
        },
        enemyDropMultiplier = 1,
        shopProductSet = "florestEarly",
    }),
    createFloorLevel({
        id = 2,
        difficulty = 2,
        roomCount = {min = 10, max = 14},
        cardRoomCount = {min = 2, max = 3},
        theme = "florest",
        startRoomUseDefault = true,
        grassConfig = {
            nonWalkableChance = 0.14,
            bigGrassChance = 0.05,
            nonWalkableBigGrassChance = 0.12,
        },
        enemyDropMultiplier = 1.1,
        shopProductSet = "florestEarly",
    }),
    createFloorLevel({
        id = 3,
        difficulty = 3,
        roomCount = {min = 11, max = 15},
        cardRoomCount = {min = 2, max = 3},
        theme = "florest",
        startRoomUseDefault = true,
        grassConfig = {
            nonWalkableChance = 0.12,
            bigGrassChance = 0.05,
            nonWalkableBigGrassChance = 0.10,
        },
        enemyDropMultiplier = 1.2,
        shopProductSet = "florestLate",
    }),
    createFloorLevel({
        id = 4,
        difficulty = 4,
        roomCount = {min = 10, max = 14},
        cardRoomCount = {min = 2, max = 3},
        theme = "cave",
        startRoomUseDefault = false,
        grassConfig = {
            nonWalkableChance = 0,
            bigGrassChance = 0.05,
            nonWalkableBigGrassChance = 0,
        },
        enemyDropMultiplier = 1.3,
        shopProductSet = "cave",
    }),
    createFloorLevel({
        id = 5,
        difficulty = 5,
        roomCount = {min = 11, max = 15},
        cardRoomCount = {min = 2, max = 3},
        theme = "cave",
        startRoomUseDefault = false,
        grassConfig = {
            nonWalkableChance = 0,
            bigGrassChance = 0.04,
            nonWalkableBigGrassChance = 0,
        },
        enemyDropMultiplier = 1.4,
        shopProductSet = "cave",
    }),
    createFloorLevel({
        id = 6,
        difficulty = 6,
        roomCount = {min = 12, max = 16},
        cardRoomCount = {min = 2, max = 3},
        theme = "cave",
        startRoomUseDefault = false,
        grassConfig = {
            nonWalkableChance = 0,
            bigGrassChance = 0.03,
            nonWalkableBigGrassChance = 0,
        },
        enemyDropMultiplier = 1.5,
        shopProductSet = "cave",
    }),
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

DefaultRoomConfig.grassConfig = {
    nonWalkableChance = 0.14,
    bigGrassChance = 0.05,
    nonWalkableBigGrassChance = 0.05,
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
        cardRoomTemplateId = "cards_32x32",
        endRoomTemplateId = "end_32x32",
        cardRoomChance = 1.0,
        cardRoomCount = {min = 2, max = 3},
        largeRoomOppositeExit = true,
        templateIds = DefaultRoomConfig.roomTemplateSets.florest.templateIds,
        templateWeights = DefaultRoomConfig.roomTemplateSets.florest.templateWeights,
        endRoomChance = 0.35,
        endTemplateWeights = DefaultRoomConfig.roomTemplateSets.florest.endTemplateWeights,
        extraConnectionChance = 0.12,
    },
}

DefaultRoomConfig.shopConfig = {
    enabled = true,
    cardProductId = "card_upgrade",
    cardPrice = 50,
    cardRoomDoubleShopChance = 0.05,
    cardChestSecondChance = 0.05,
    products = {
        { id = "squaregun", weight = 40 },
        { id = "longshot", weight = 25 },
        { id = "cakegun", weight = 20 },
        { id = "shotgun", weight = 15 },
        { id = "raygun", weight = 5 },
    },
}

return DefaultRoomConfig
