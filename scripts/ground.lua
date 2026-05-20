local LightConfig = require("scripts/config/lightConfig")
local Tilemap = require("scripts/tilemap")
local unpackValues = table.unpack or unpack
local MAX_GROUND_LIGHTS = 32
local MAX_GROUND_LIGHT_OCCLUDERS = 96

local Ground = {}

local function getScreenLightCenter(source)
    return {
        (source.x * WORLD_SCALE_X - camera.x) * camera.zoomX,
        (source.y * YSCALE - camera.y) * camera.zoomY,
    }
end

local function getDistanceToScreenCenter(center)
    local dx = center[1] - baseWidth / 2
    local dy = center[2] - baseHeight / 2
    return dx * dx + dy * dy
end

local function getScreenTileRect(tile)
    local left = ((tile.xWorld - tile.size / 2) * WORLD_SCALE_X - camera.x) * camera.zoomX
    local top = ((tile.yWorld - tile.size) * YSCALE - camera.y) * camera.zoomY
    local width = tile.size * WORLD_SCALE_X * camera.zoomX
    local height = tile.size * YSCALE * camera.zoomY

    return {left, top, left + width, top + height}
end

local function getRectDistanceToPoint(rect, point)
    local centerX = (rect[1] + rect[3]) / 2
    local centerY = (rect[2] + rect[4]) / 2
    local dx = centerX - point[1]
    local dy = centerY - point[2]
    return dx * dx + dy * dy
end

local function getRectSortDistance(rect, lightCenters)
    local bestDistance = math.huge

    for i = 1, #lightCenters do
        bestDistance = math.min(bestDistance, getRectDistanceToPoint(rect, lightCenters[i]))
    end

    return bestDistance
end

local function getOccluderSearchBounds(lightCenters, margin)
    local minX = -margin
    local minY = -margin
    local maxX = baseWidth + margin
    local maxY = baseHeight + margin

    for i = 1, #lightCenters do
        local center = lightCenters[i]
        minX = math.min(minX, center[1] - margin)
        minY = math.min(minY, center[2] - margin)
        maxX = math.max(maxX, center[1] + margin)
        maxY = math.max(maxY, center[2] + margin)
    end

    return minX, minY, maxX, maxY
end

local function collectGroundLightOccluders(maxOccluders, lightCenters)
    local occlusionConfig = LightConfig:getGroundLightOcclusion()
    if not (camera and occlusionConfig.enabled ~= false and maxOccluders > 0 and #lightCenters > 0) then
        local emptyRects = {}
        for i = 1, math.max(maxOccluders, 1) do
            emptyRects[i] = {0, 0, 0, 0}
        end
        return emptyRects, 0
    end

    local margin = occlusionConfig.margin or 64
    local minX, minY, maxX, maxY = getOccluderSearchBounds(lightCenters, margin)
    local candidates = {}
    local rects = {}
    local occluderCount = 0

    local occluderTiles = Tilemap.groundOccluderTiles or Tilemap.tiles or {}
    for _, tile in ipairs(occluderTiles) do
        local isFlashingBox = (tile.quadIndex == 14 or tile.quadIndex == 18)
            and tile.hitFlashTimer and tile.hitFlashTimer > 0

        if tile.isAlive and tile.collider and not tile.isWater and not isFlashingBox
            and tile.size and tile.xWorld and tile.yWorld then
            local rect = getScreenTileRect(tile)
            if rect[3] >= minX and rect[1] <= maxX
                and rect[4] >= minY and rect[2] <= maxY then
                candidates[#candidates + 1] = {
                    rect = rect,
                    sortDistance = getRectSortDistance(rect, lightCenters),
                }
            end
        end
    end

    table.sort(candidates, function(a, b)
        return a.sortDistance < b.sortDistance
    end)

    for i = 1, math.min(#candidates, maxOccluders) do
        occluderCount = occluderCount + 1
        rects[occluderCount] = candidates[i].rect
    end

    for i = occluderCount + 1, maxOccluders do
        rects[i] = {0, 0, 0, 0}
    end

    return rects, occluderCount
end

function Ground:load(target)
    self.image = love.graphics.newImage("assets/sprites/florest/ground.png")
    self.image:setFilter("nearest", "nearest")
    self.width = self.image:getWidth()
    self.height = self.image:getHeight()
    self.lightShader = love.graphics.newShader("scripts/shaders/groundLight.glsl")
end

function Ground:draw(player)
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()

    local startX = math.floor(player.x / self.width) * self.width
    local startY = math.floor(player.y / self.height) * self.height

    local tilesX = math.ceil(screenWidth / self.width) + 2
    local tilesY = math.ceil(screenHeight / self.height) + 2

    local maxLights = math.min(LightConfig:getMaxWorldLights(), MAX_GROUND_LIGHTS)
    local maxOccluders = math.min(LightConfig:getMaxGroundLightOccluders(), MAX_GROUND_LIGHT_OCCLUDERS)
    local generalShadow = LightConfig:getGeneralShadow()
    local occlusionConfig = LightConfig:getGroundLightOcclusion()
    local lightManager = ACTIVE_LIGHT_MANAGER or Game
    local lightSources = lightManager and lightManager.getLightSources and lightManager:getLightSources() or {}
    local centers = {}
    local innerRadii = {}
    local outerRadii = {}
    local maxBrightnesses = {}
    local lightCount = 0

    if camera and self.lightShader then
        local groundLightSources = {}

        for _, source in ipairs(lightSources) do
            local groundLight = source.config and source.config.groundLight
            if groundLight and groundLight.enabled ~= false then
                local center = getScreenLightCenter(source)
                groundLightSources[#groundLightSources + 1] = {
                    center = center,
                    groundLight = groundLight,
                    type = source.type,
                    sortDistance = getDistanceToScreenCenter(center),
                }
            end
        end

        table.sort(groundLightSources, function(a, b)
            return a.sortDistance < b.sortDistance
        end)

        for _, source in ipairs(groundLightSources) do
            if lightCount >= maxLights then
                break
            end

            local groundLight = source.groundLight
            lightCount = lightCount + 1
            centers[lightCount] = source.center
            innerRadii[lightCount] = groundLight.innerRadius or 95
            outerRadii[lightCount] = groundLight.outerRadius or 360
            maxBrightnesses[lightCount] = groundLight.maxBrightness or 1
        end

        for i = lightCount + 1, maxLights do
            centers[i] = {0, 0}
            innerRadii[i] = 0
            outerRadii[i] = 1
            maxBrightnesses[i] = 1
        end

        self.lightShader:send("u_lightCount", lightCount)
        self.lightShader:send("u_lightCenters", unpackValues(centers, 1, maxLights))
        self.lightShader:send("u_innerRadii", unpackValues(innerRadii, 1, maxLights))
        self.lightShader:send("u_outerRadii", unpackValues(outerRadii, 1, maxLights))
        self.lightShader:send("u_maxBrightnesses", unpackValues(maxBrightnesses, 1, maxLights))
        self.lightShader:send("u_generalShadowMinBrightness", generalShadow.minBrightness or 1)
        self.lightShader:send("u_generalShadowColor", generalShadow.color or {0, 0, 0})
        local lightCenters = {}
        for i = 1, lightCount do
            if groundLightSources[i] and groundLightSources[i].type == "player" then
                lightCenters[#lightCenters + 1] = centers[i]
            end
        end

        local occluders, occluderCount = collectGroundLightOccluders(maxOccluders, lightCenters)
        self.lightShader:send("u_occluderCount", occluderCount)
        self.lightShader:send("u_occluderRects", unpackValues(occluders, 1, math.max(maxOccluders, 1)))
        self.lightShader:send("u_occlusionStrength", occlusionConfig.strength or 0.7)
        love.graphics.setShader(self.lightShader)
    end

    for i = -1, tilesX do
        for j = -1, tilesY do
            love.graphics.draw(self.image, startX + i * self.width, startY + j * self.height)
        end
    end

    love.graphics.setShader()
end

return Ground
