local RoomTemplates = {}

local defaultObjectBorderCullLayers = {x = 3, top = 7, bottom = 4}

local basicDoorSlots = {
    north = {
        doorTiles = {
            {x = 15, y = 10},
            {x = 16, y = 10},
        },
        backTiles = {
            {x = 15, y = 9},
            {x = 16, y = 9},
        },
        playerSpawn = {x = 15.5, y = 11},
    },
    south = {
        doorTiles = {
            {x = 15, y = 22},
            {x = 16, y = 22},
        },
        backTiles = {
            {x = 15, y = 23},
            {x = 16, y = 23},
        },
        playerSpawn = {x = 15.5, y = 21},
    },
    west = {
        doorTiles = {
            {x = 7, y = 15},
            {x = 7, y = 16},
        },
        backTiles = {
            {x = 6, y = 15},
            {x = 6, y = 16},
        },
        playerSpawn = {x = 8, y = 15.5},
    },
    east = {
        doorTiles = {
            {x = 24, y = 15},
            {x = 24, y = 16},
        },
        backTiles = {
            {x = 25, y = 15},
            {x = 25, y = 16},
        },
        playerSpawn = {x = 24, y = 15.5},
    },
}

local basicSpawnPoints = {
    player = {x = 16.1, y = 16.1},
}

local basicTags = {
    "normal",
    "small",
}

local basicMoonbeamConfig = {
    enabled = true,
    chance = 0.86,
    emptyEncounterChance = 0.98,
    count = {min = 1, max = 2},
    treeDistanceTiles = 3,
    angleDegrees = 75,
    widthMin = 50,
    widthMax = 74,
}

local largeMoonbeamConfig = {
    enabled = true,
    chance = 0.86,
    emptyEncounterChance = 0.98,
    count = {min = 2, max = 4},
    treeDistanceTiles = 3,
    angleDegrees = 75,
    widthMin = 50,
    widthMax = 74,
}

local basicAmbientDustConfig = {
    enabled = true,
    count = 28,
    anchorCount = 34,
}

local largeAmbientDustConfig = {
    enabled = true,
    count = 42,
    anchorCount = 52,
}

local function isPng(filename)
    return type(filename) == "string" and filename:lower():match("%.png$") ~= nil
end

local function mapSortValue(filename)
    local suffix = filename:lower():match("^map(%d*)%.png$")
    if suffix == "" then
        return 1
    end

    return tonumber(suffix) or math.huge
end

local function sortMapFiles(a, b)
    local aValue = mapSortValue(a)
    local bValue = mapSortValue(b)

    if aValue == bValue then
        return a < b
    end

    return aValue < bValue
end

local function buildTilemapConfigsFromFolder(folder, fallbackFiles)
    local configs = {}

    if love and love.filesystem and love.filesystem.getInfo(folder, "directory") then
        local files = love.filesystem.getDirectoryItems(folder)
        table.sort(files, sortMapFiles)

        for _, filename in ipairs(files) do
            if isPng(filename) then
                configs[#configs + 1] = {
                    mapImage = folder .. "/" .. filename,
                    centerOrigin = true,
                    objectBorderCullLayers = defaultObjectBorderCullLayers,
                }
            end
        end
    end

    if #configs == 0 then
        for _, filename in ipairs(fallbackFiles or {}) do
            configs[#configs + 1] = {
                mapImage = folder .. "/" .. filename,
                centerOrigin = true,
                objectBorderCullLayers = defaultObjectBorderCullLayers,
            }
        end
    end

    return configs
end

local wideDoorSlots = {
    north = {
        left = {
            doorTiles = {
                {x = 15, y = 11},
                {x = 16, y = 11},
            },
            backTiles = {
                {x = 15, y = 10},
                {x = 16, y = 10},
            },
            playerSpawn = {x = 15.5, y = 11},
        },
        right = {
            doorTiles = {
                {x = 31, y = 11},
                {x = 32, y = 11},
            },
            backTiles = {
                {x = 31, y = 10},
                {x = 32, y = 10},
            },
            playerSpawn = {x = 31.5, y = 11},
        },
    },
    south = {
        left = {
            doorTiles = {
                {x = 15, y = 21},
                {x = 16, y = 21},
            },
            backTiles = {
                {x = 15, y = 22},
                {x = 16, y = 22},
            },
            playerSpawn = {x = 15.5, y = 21},
        },
        right = {
            doorTiles = {
                {x = 31, y = 21},
                {x = 32, y = 21},
            },
            backTiles = {
                {x = 31, y = 22},
                {x = 32, y = 22},
            },
            playerSpawn = {x = 31.5, y = 21},
        },
    },
    west = {
        doorTiles = {
            {x = 8, y = 15},
            {x = 8, y = 16},
        },
        backTiles = {
            {x = 7, y = 15},
            {x = 7, y = 16},
        },
        playerSpawn = {x = 8, y = 15.5},
    },
    east = {
        doorTiles = {
            {x = 39, y = 15},
            {x = 39, y = 16},
        },
        backTiles = {
            {x = 40, y = 15},
            {x = 40, y = 16},
        },
        playerSpawn = {x = 40, y = 15.5},
    },
}

local tallDoorSlots = {
    north = {
        doorTiles = {
            {x = 15, y = 11},
            {x = 16, y = 11},
        },
        backTiles = {
            {x = 15, y = 10},
            {x = 16, y = 10},
        },
        playerSpawn = {x = 15.5, y = 11},
    },
    south = {
        doorTiles = {
            {x = 15, y = 37},
            {x = 16, y = 37},
        },
        backTiles = {
            {x = 15, y = 38},
            {x = 16, y = 38},
        },
        playerSpawn = {x = 15.5, y = 37},
    },
    west = {
        top = {
            doorTiles = {
                {x = 8, y = 15},
                {x = 8, y = 16},
            },
            backTiles = {
                {x = 7, y = 15},
                {x = 7, y = 16},
            },
            playerSpawn = {x = 8, y = 15.5},
        },
        bottom = {
            doorTiles = {
                {x = 8, y = 31},
                {x = 8, y = 32},
            },
            backTiles = {
                {x = 7, y = 31},
                {x = 7, y = 32},
            },
            playerSpawn = {x = 8, y = 31.5},
        },
    },
    east = {
        top = {
            doorTiles = {
                {x = 23, y = 15},
                {x = 23, y = 16},
            },
            backTiles = {
                {x = 24, y = 15},
                {x = 24, y = 16},
            },
            playerSpawn = {x = 24, y = 15.5},
        },
        bottom = {
            doorTiles = {
                {x = 23, y = 31},
                {x = 23, y = 32},
            },
            backTiles = {
                {x = 24, y = 31},
                {x = 24, y = 32},
            },
            playerSpawn = {x = 24, y = 31.5},
        },
    },
}

local largeDoorSlots = {
    north = {
        left = {
            doorTiles = {
                {x = 15, y = 11},
                {x = 16, y = 11},
            },
            backTiles = {
                {x = 15, y = 10},
                {x = 16, y = 10},
            },
            playerSpawn = {x = 15.5, y = 11},
        },
        right = {
            doorTiles = {
                {x = 31, y = 11},
                {x = 32, y = 11},
            },
            backTiles = {
                {x = 31, y = 10},
                {x = 32, y = 10},
            },
            playerSpawn = {x = 31.5, y = 11},
        },
    },
    south = {
        left = {
            doorTiles = {
                {x = 15, y = 37},
                {x = 16, y = 37},
            },
            backTiles = {
                {x = 15, y = 38},
                {x = 16, y = 38},
            },
            playerSpawn = {x = 15.5, y = 37},
        },
        right = {
            doorTiles = {
                {x = 31, y = 37},
                {x = 32, y = 37},
            },
            backTiles = {
                {x = 31, y = 38},
                {x = 32, y = 38},
            },
            playerSpawn = {x = 31.5, y = 37},
        },
    },
    west = {
        top = {
            doorTiles = {
                {x = 8, y = 15},
                {x = 8, y = 16},
            },
            backTiles = {
                {x = 7, y = 15},
                {x = 7, y = 16},
            },
            playerSpawn = {x = 8, y = 15.5},
        },
        bottom = {
            doorTiles = {
                {x = 8, y = 31},
                {x = 8, y = 32},
            },
            backTiles = {
                {x = 7, y = 31},
                {x = 7, y = 32},
            },
            playerSpawn = {x = 8, y = 31.5},
        },
    },
    east = {
        top = {
            doorTiles = {
                {x = 39, y = 15},
                {x = 39, y = 16},
            },
            backTiles = {
                {x = 40, y = 15},
                {x = 40, y = 16},
            },
            playerSpawn = {x = 40, y = 15.5},
        },
        bottom = {
            doorTiles = {
                {x = 39, y = 31},
                {x = 39, y = 32},
            },
            backTiles = {
                {x = 40, y = 31},
                {x = 40, y = 32},
            },
            playerSpawn = {x = 40, y = 31.5},
        },
    },
}

local largeOccupancyVariants = {
    topLeft = {
        {x = 0, y = 0},
        {x = 1, y = 0},
        {x = 0, y = 1},
        {x = 1, y = 1},
    },
    topRight = {
        {x = -1, y = 0},
        {x = 0, y = 0},
        {x = -1, y = 1},
        {x = 0, y = 1},
    },
    bottomLeft = {
        {x = 0, y = -1},
        {x = 1, y = -1},
        {x = 0, y = 0},
        {x = 1, y = 0},
    },
    bottomRight = {
        {x = -1, y = -1},
        {x = 0, y = -1},
        {x = -1, y = 0},
        {x = 0, y = 0},
    },
}

local tallOccupancyVariants = {
    bottom = {
        {x = 0, y = -1},
        {x = 0, y = 0},
    },
    top = {
        {x = 0, y = 0},
        {x = 0, y = 1},
    },
}

local templates = {
    start_32x32 = {
        id = "start_32x32",
        name = "Start 32x32",
        width = 32,
        height = 32,
        gridWidth = 1,
        gridHeight = 1,
        shape = "rect",
        tilemapConfig = {
            mapImage = "assets/maps/startRoom.png",
            centerOrigin = true,
        },
        doorSlots = basicDoorSlots,
        spawnPoints = basicSpawnPoints,
        tags = {
            "start",
            "small",
        },
        moonbeams = basicMoonbeamConfig,
        ambientDust = basicAmbientDustConfig,
    },
    basic_32x32 = {
        id = "basic_32x32",
        name = "Basic 32x32",
        width = 32,
        height = 32,
        gridWidth = 1,
        gridHeight = 1,
        shape = "rect",
        tilemapConfigs = buildTilemapConfigsFromFolder("assets/maps/32x32", {"map.png", "map2.png", "map3.png"}),
        doorSlots = basicDoorSlots,
        spawnPoints = basicSpawnPoints,
        tags = basicTags,
        moonbeams = basicMoonbeamConfig,
        ambientDust = basicAmbientDustConfig,
    },
    store_32x32 = {
        id = "store_32x32",
        name = "Store 32x32",
        width = 32,
        height = 32,
        gridWidth = 1,
        gridHeight = 1,
        shape = "rect",
        tilemapConfigs = buildTilemapConfigsFromFolder("assets/maps/store", {"map.png"}),
        doorSlots = basicDoorSlots,
        spawnPoints = basicSpawnPoints,
        tags = {
            "shop",
            "small",
        },
        moonbeams = basicMoonbeamConfig,
        ambientDust = basicAmbientDustConfig,
    },
    cards_32x32 = {
        id = "cards_32x32",
        name = "Cards 32x32",
        width = 32,
        height = 32,
        gridWidth = 1,
        gridHeight = 1,
        shape = "rect",
        tilemapConfigs = buildTilemapConfigsFromFolder("assets/maps/cards", {"map.png"}),
        doorSlots = basicDoorSlots,
        spawnPoints = basicSpawnPoints,
        tags = {
            "cards",
            "small",
        },
        moonbeams = basicMoonbeamConfig,
        ambientDust = basicAmbientDustConfig,
    },
    end_32x32 = {
        id = "end_32x32",
        name = "End 32x32",
        width = 32,
        height = 32,
        gridWidth = 1,
        gridHeight = 1,
        shape = "rect",
        tilemapConfig = {
            mapImage = "assets/maps/endRoom.png",
            centerOrigin = true,
        },
        doorSlots = basicDoorSlots,
        spawnPoints = basicSpawnPoints,
        tags = {
            "end",
            "small",
        },
        moonbeams = {
            enabled = false,
        },
        ambientDust = basicAmbientDustConfig,
    },
    wide_48x32 = {
        id = "wide_48x32",
        name = "Wide 48x32",
        width = 48,
        height = 32,
        gridWidth = 2,
        gridHeight = 1,
        occupancyVariants = {
            right = {
                {x = 0, y = 0},
                {x = 1, y = 0},
            },
            left = {
                {x = -1, y = 0},
                {x = 0, y = 0},
            },
        },
        shape = "wide",
        tilemapConfigs = buildTilemapConfigsFromFolder("assets/maps/48x32", {"map.png", "map2.png"}),
        doorSlots = wideDoorSlots,
        spawnPoints = {
            player = {x = 24, y = 16},
        },
        tags = {
            "normal",
            "wide",
        },
        moonbeams = {
            enabled = true,
            chance = 0.78,
            emptyEncounterChance = 0.95,
            count = {min = 1, max = 3},
            treeDistanceTiles = 3,
            angleDegrees = 75,
            widthMin = 50,
            widthMax = 74,
        },
        ambientDust = {
            enabled = true,
            count = 34,
            anchorCount = 42,
        },
    },
    tall_32x48 = {
        id = "tall_32x48",
        name = "Tall 32x48",
        width = 32,
        height = 48,
        gridWidth = 1,
        gridHeight = 2,
        occupancyVariants = tallOccupancyVariants,
        shape = "tall",
        tilemapConfigs = buildTilemapConfigsFromFolder("assets/maps/32x48", {"map.png", "map2.png"}),
        doorSlots = tallDoorSlots,
        spawnPoints = {
            player = {x = 16, y = 24},
        },
        tags = {
            "normal",
            "tall",
        },
        moonbeams = {
            enabled = true,
            chance = 0.78,
            emptyEncounterChance = 0.95,
            count = {min = 1, max = 3},
            treeDistanceTiles = 3,
            angleDegrees = 75,
            widthMin = 50,
            widthMax = 74,
        },
        ambientDust = {
            enabled = true,
            count = 34,
            anchorCount = 42,
        },
    },
    large_48x48 = {
        id = "large_48x48",
        name = "Large 48x48",
        width = 48,
        height = 48,
        gridWidth = 2,
        gridHeight = 2,
        occupancyVariants = largeOccupancyVariants,
        shape = "large",
        tilemapConfigs = buildTilemapConfigsFromFolder("assets/maps/48x48", {"map.png", "map2.png"}),
        doorSlots = largeDoorSlots,
        spawnPoints = {
            player = {x = 24, y = 24},
        },
        tags = {
            "normal",
            "large",
        },
        moonbeams = largeMoonbeamConfig,
        ambientDust = largeAmbientDustConfig,
    },
}

local function appendTemplateIfCompatible(list, template, doors)
    for direction, enabled in pairs(doors or {}) do
        if enabled and not template.doorSlots[direction] then
            return
        end
    end

    list[#list + 1] = template
end

function RoomTemplates:get(templateId)
    return templates[templateId]
end

function RoomTemplates:getAll()
    return templates
end

function RoomTemplates:supportsDoors(templateId, doors)
    local template = self:get(templateId)
    if not template then
        return false
    end

    local compatible = {}
    appendTemplateIfCompatible(compatible, template, doors)
    return #compatible > 0
end

function RoomTemplates:getCompatible(doors, templateIds)
    local compatible = {}

    if templateIds then
        for _, templateId in ipairs(templateIds) do
            local template = self:get(templateId)
            if template then
                appendTemplateIfCompatible(compatible, template, doors)
            end
        end
    else
        for _, template in pairs(templates) do
            appendTemplateIfCompatible(compatible, template, doors)
        end
    end

    return compatible
end

function RoomTemplates:chooseCompatible(doors, templateIds)
    local compatible = self:getCompatible(doors, templateIds)
    if #compatible == 0 then
        return nil
    end

    return compatible[math.random(1, #compatible)]
end

return RoomTemplates
