local RoomSelector = {}

local RoomTemplates = require("scripts/rooms/roomTemplates")

local function copyTable(source)
    if not source then
        return nil
    end

    local copied = {}
    for key, value in pairs(source) do
        if type(value) == "table" then
            copied[key] = copyTable(value)
        else
            copied[key] = value
        end
    end
    return copied
end

local function getWeightedValue(item, weights)
    local id = type(item) == "table" and item.id or item
    if weights and id and weights[id] ~= nil then
        return weights[id]
    end

    if type(item) == "table" then
        return item.weight or item.chance or 1
    end

    return 1
end

local function chooseWeighted(list, weights)
    local totalWeight = 0

    for _, item in ipairs(list or {}) do
        local weight = getWeightedValue(item, weights)
        if weight > 0 then
            totalWeight = totalWeight + weight
        end
    end

    if totalWeight <= 0 then
        return nil
    end

    local roll = math.random() * totalWeight
    for _, item in ipairs(list or {}) do
        local weight = getWeightedValue(item, weights)
        if weight > 0 then
            roll = roll - weight
            if roll <= 0 then
                return item
            end
        end
    end

    return list[#list]
end

local function getTemplateCandidates(generateConfig)
    if generateConfig.templateIds then
        return generateConfig.templateIds
    end

    if generateConfig.templateId then
        return {generateConfig.templateId}
    end

    return nil
end

local function getTemplateOccupancyOptions(template)
    local options = {}

    if template.occupancyVariants then
        for variantId, offsets in pairs(template.occupancyVariants) do
            options[#options + 1] = {
                variantId = variantId,
                offsets = offsets,
            }
        end
    else
        options[#options + 1] = {
            variantId = nil,
            offsets = template.occupiedOffsets or {
                {x = 0, y = 0},
            },
        }
    end

    return options
end

local function canPlaceOccupancy(x, y, offsets, occupiedCells)
    for _, offset in ipairs(offsets) do
        local cellId = (x + offset.x) .. ":" .. (y + offset.y)
        if occupiedCells[cellId] then
            return false
        end
    end

    return true
end

function RoomSelector.copyTable(source)
    return copyTable(source)
end

function RoomSelector.chooseWeighted(list, weights)
    return chooseWeighted(list, weights)
end

function RoomSelector.chooseTemplateTilemapConfig(template)
    if template and template.tilemapConfigs then
        return copyTable(chooseWeighted(template.tilemapConfigs))
    end

    return copyTable(template and template.tilemapConfig)
end

function RoomSelector.chooseTemplatePlacement(doors, generateConfig, x, y, occupiedCells)
    local templateWeights = generateConfig and generateConfig.templateWeights
    local templateIds = getTemplateCandidates(generateConfig or {})
    local compatibleTemplates = RoomTemplates:getCompatible(doors, templateIds)
    local candidates = {}

    if generateConfig and generateConfig.useEndTemplateWeights then
        templateWeights = generateConfig.endTemplateWeights or templateWeights
    end

    for _, template in ipairs(compatibleTemplates) do
        local placements = {}
        for _, option in ipairs(getTemplateOccupancyOptions(template)) do
            if canPlaceOccupancy(x, y, option.offsets, occupiedCells) then
                placements[#placements + 1] = {
                    template = template,
                    variantId = option.variantId,
                    offsets = option.offsets,
                }
            end
        end

        if #placements > 0 then
            candidates[#candidates + 1] = {
                id = template.id,
                template = template,
                placements = placements,
            }
        end
    end

    local selected = chooseWeighted(candidates, templateWeights)
    if not selected then
        return nil
    end

    local placement = selected.placements[math.random(1, #selected.placements)]
    placement.tilemapConfig = RoomSelector.chooseTemplateTilemapConfig(selected.template)
    return placement
end

return RoomSelector
