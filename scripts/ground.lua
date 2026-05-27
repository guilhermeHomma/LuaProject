local LightConfig = require("scripts/config/lightConfig")
local Tilemap = require("scripts/tilemap")
local FloorManager = require("scripts/managers/floorManager")
local VisualThemes = require("scripts/config/visualThemes")
local unpackValues = table.unpack or unpack
local MAX_GROUND_LIGHTS = 32
local MAX_GROUND_LIGHT_OCCLUDERS = 8

local Ground = {}
local DEFAULT_GROUND = "assets/sprites/florest/ground.png"
local emptyOccluderRects = {}
local OCCLUDER_MOVE_THRESHOLD_SQ = 4
local occluderFrameCache = { rects = nil, count = 0, camX = nil, camY = nil, camZoomX = nil, camZoomY = nil, lightKey = nil, version = 0 }

local function clearArray(list)
    for i = #list, 1, -1 do
        list[i] = nil
    end
end

local function getScreenLightCenter(source)
    local center = source.__screenLightCenter or {}
    source.__screenLightCenter = center
    if source.__cachedCamX ~= camera.x or source.__cachedCamY ~= camera.y
       or source.__cachedSrcX ~= source.x or source.__cachedSrcY ~= source.y then
        center[1] = (source.x * WORLD_SCALE_X - camera.x) * camera.zoomX
        center[2] = (source.y * YSCALE - camera.y) * camera.zoomY
        source.__cachedCamX = camera.x
        source.__cachedCamY = camera.y
        source.__cachedSrcX = source.x
        source.__cachedSrcY = source.y
    end
    return center
end

local function getDistanceToScreenCenter(center)
    local dx = center[1] - baseWidth / 2
    local dy = center[2] - baseHeight / 2
    return dx * dx + dy * dy
end

local function getGroundLightPriority(source)
    if source.type == "player" then
        return 0
    end

    if source.type == "projectile" or source.type == "enemyProjectile" then
        return 2
    end

    return 1
end

local function isProjectileLight(source)
    return source.type == "projectile" or source.type == "enemyProjectile"
end

local function setScreenTileRect(rect, tile)
    local left = ((tile.xWorld - tile.size / 2) * WORLD_SCALE_X - camera.x) * camera.zoomX
    local top = ((tile.yWorld - tile.size) * YSCALE - camera.y) * camera.zoomY
    local width = tile.size * WORLD_SCALE_X * camera.zoomX
    local height = tile.size * YSCALE * camera.zoomY

    rect[1] = left
    rect[2] = top
    rect[3] = left + width
    rect[4] = top + height
    return rect
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
        for i = 1, math.max(maxOccluders, 1) do
            emptyOccluderRects[i] = emptyOccluderRects[i] or {0, 0, 0, 0}
        end
        return emptyOccluderRects, 0
    end

    -- lightCenters is always player-only (1 entry); key by camera + player screen pos
    local cx, cy = camera.x, camera.y
    local czx, czy = camera.zoomX, camera.zoomY
    local pc = lightCenters[1]
    local lkey = math.floor(pc[1]) * 100003 + math.floor(pc[2])
    local fc = occluderFrameCache
    if not Ground.occludersDirty and fc.rects then
        local dx = cx - fc.camX
        local dy = cy - fc.camY
        if dx * dx + dy * dy < OCCLUDER_MOVE_THRESHOLD_SQ
           and czx == fc.camZoomX and czy == fc.camZoomY
           and lkey == fc.lightKey then
            return fc.rects, fc.count
        end
    end
    Ground.occludersDirty = false

    local margin = occlusionConfig.margin or 64
    local minX, minY, maxX, maxY = getOccluderSearchBounds(lightCenters, margin)
    local candidates = Ground.occluderCandidates or {}
    local rects = Ground.occluderRects or {}
    local occluderCount = 0
    clearArray(candidates)

    local occluderTiles = Tilemap.getVisibleObjectsFromGrid and Tilemap:getVisibleObjectsFromGrid("tiles", margin + 80)
        or Tilemap.groundOccluderTiles
        or Tilemap.tiles
        or {}
    local candidatePool = Ground.occluderCandidatePool or {}
    Ground.occluderCandidatePool = candidatePool
    local candidateIndex = 0

    for _, tile in ipairs(occluderTiles) do
        local isFlashingBox = (tile.quadIndex == 14 or tile.quadIndex == 18)
            and tile.hitFlashTimer and tile.hitFlashTimer > 0

        if tile.isAlive and tile.collider and not tile.isWater and not isFlashingBox
            and tile.size and tile.xWorld and tile.yWorld then
            candidateIndex = candidateIndex + 1
            local candidate = candidatePool[candidateIndex] or {}
            local rect = candidate.rect or {}
            candidatePool[candidateIndex] = candidate
            candidate.rect = setScreenTileRect(rect, tile)
            if rect[3] >= minX and rect[1] <= maxX
                and rect[4] >= minY and rect[2] <= maxY then
                candidate.sortDistance = getRectSortDistance(rect, lightCenters)
                candidates[#candidates + 1] = candidate
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
        rects[i] = rects[i] or {0, 0, 0, 0}
        rects[i][1], rects[i][2], rects[i][3], rects[i][4] = 0, 0, 0, 0
    end

    Ground.occluderCandidates = candidates
    Ground.occluderRects = rects
    fc.rects = rects
    fc.count = occluderCount
    fc.camX, fc.camY = cx, cy
    fc.camZoomX, fc.camZoomY = czx, czy
    fc.lightKey = lkey
    fc.version = fc.version + 1
    return rects, occluderCount
end

function Ground:setTheme(theme)
    local imagePath = theme and theme.ground or DEFAULT_GROUND
    if self.image and self.imagePath == imagePath then
        return
    end

    self.imagePath = imagePath
    self.image = love.graphics.newImage(imagePath)
    self.image:setFilter("nearest", "nearest")
    self.image:setWrap("repeat", "repeat")
    self.width = self.image:getWidth()
    self.height = self.image:getHeight()
    self.quad = love.graphics.newQuad(0, 0, self.width, self.height, self.width, self.height)
end

function Ground:load(target)
    self:setTheme(VisualThemes:getDefault())
    self.lightShader = love.graphics.newShader("scripts/shaders/groundLight.glsl")
    self.lastSentLightCount = nil
    self.lastSentLMVersion = nil
    self.lastSentGeneralShadow = nil
    self.lastSentOccluderVersion = nil
    self.occludersDirty = true
end

function Ground:draw(player)
    self:setTheme(FloorManager:getCurrentRoomTheme())

    local maxLights = math.min(LightConfig:getMaxWorldLights(), MAX_GROUND_LIGHTS)
    local maxOccluders = math.min(LightConfig:getMaxGroundLightOccluders(), MAX_GROUND_LIGHT_OCCLUDERS)
    local generalShadow = LightConfig:getGeneralShadow()
    local occlusionConfig = LightConfig:getGroundLightOcclusion()
    local lightManager = ACTIVE_LIGHT_MANAGER or Game
    local lightSources = lightManager and lightManager.getLightSources and lightManager:getLightSources() or {}
    local centers = self.lightCenters or {}
    local innerRadii = self.innerRadii or {}
    local outerRadii = self.outerRadii or {}
    local maxBrightnesses = self.maxBrightnesses or {}
    local additiveStrengths = self.additiveStrengths or {}
    local lightCount = 0

    if camera and self.lightShader then
        local groundLightSources = self.groundLightSources or {}
        clearArray(groundLightSources)

        for _, source in ipairs(lightSources) do
            local groundLight = source.config and source.config.groundLight
            if groundLight and groundLight.enabled ~= false then
                local center = getScreenLightCenter(source)
                local entry = self.groundLightSourcePool and self.groundLightSourcePool[#groundLightSources + 1] or nil
                if not self.groundLightSourcePool then
                    self.groundLightSourcePool = {}
                end
                entry = entry or {}
                self.groundLightSourcePool[#groundLightSources + 1] = entry
                entry.center = center
                entry.groundLight = groundLight
                entry.type = source.type
                entry.isPlayer = source.type == "player"
                entry.priority = getGroundLightPriority(source)
                entry.sortDistance = getDistanceToScreenCenter(center)
                groundLightSources[#groundLightSources + 1] = entry
            end
        end

        table.sort(groundLightSources, function(a, b)
            if a.priority ~= b.priority then
                return a.priority < b.priority
            end
            return a.sortDistance < b.sortDistance
        end)

        for _, source in ipairs(groundLightSources) do
            if lightCount >= maxLights then
                break
            end

            if isProjectileLight(source) and #groundLightSources > maxLights and lightCount >= maxLights - 2 then
                -- Keep stable room lights from being displaced by short-lived shots.
                break
            end

            local groundLight = source.groundLight
            lightCount = lightCount + 1
            centers[lightCount] = source.center
            innerRadii[lightCount] = groundLight.innerRadius or 95
            outerRadii[lightCount] = groundLight.outerRadius or 360
            maxBrightnesses[lightCount] = groundLight.maxBrightness or 1
            additiveStrengths[lightCount] = groundLight.additive and (groundLight.additiveStrength or 0.12) or 0
        end

        if PERF and PERF.enabled then
            PERF.groundLightCount = lightCount
            PERF.groundLightCandidates = #groundLightSources
        end

        for i = lightCount + 1, maxLights do
            centers[i] = centers[i] or {0, 0}
            centers[i][1], centers[i][2] = 0, 0
            innerRadii[i] = 0
            outerRadii[i] = 1
            maxBrightnesses[i] = 1
            additiveStrengths[i] = 0
        end

        -- skip shader entirely when scene is fully lit and no lights active
        local needsShader = lightCount > 0 or (generalShadow.minBrightness or 1) < 1
        if needsShader then
            local lmVersion = lightManager.lightSourcesVersion or 0
            if lightCount ~= (self.lastSentLightCount or -1) or lmVersion ~= (self.lastSentLMVersion or -1) then
                self.lightShader:send("u_lightCount", lightCount)
                self.lightShader:send("u_innerRadii", unpackValues(innerRadii, 1, maxLights))
                self.lightShader:send("u_outerRadii", unpackValues(outerRadii, 1, maxLights))
                self.lightShader:send("u_maxBrightnesses", unpackValues(maxBrightnesses, 1, maxLights))
                self.lightShader:send("u_additiveStrengths", unpackValues(additiveStrengths, 1, maxLights))
                self.lastSentLightCount = lightCount
                self.lastSentLMVersion = lmVersion
            end
            self.lightShader:send("u_lightCenters", unpackValues(centers, 1, maxLights))
            if generalShadow ~= self.lastSentGeneralShadow then
                self.lightShader:send("u_generalShadowMinBrightness", generalShadow.minBrightness or 1)
                self.lightShader:send("u_generalShadowColor", generalShadow.color or {0, 0, 0})
                self.lightShader:send("u_occlusionStrength", occlusionConfig.strength or 0.7)
                self.lastSentGeneralShadow = generalShadow
            end

            local lightCenters = self.playerLightCenters or {}
            clearArray(lightCenters)
            for i = 1, lightCount do
                if groundLightSources[i] and groundLightSources[i].type == "player" then
                    lightCenters[#lightCenters + 1] = centers[i]
                end
            end

            local occluders, occluderCount = collectGroundLightOccluders(maxOccluders, lightCenters)
            local occluderVer = occluderFrameCache.version
            if occluderVer ~= (self.lastSentOccluderVersion or -1) then
                self.lightShader:send("u_occluderCount", occluderCount)
                self.lightShader:send("u_occluderRects", unpackValues(occluders, 1, math.max(maxOccluders, 1)))
                self.lastSentOccluderVersion = occluderVer
            end
            self.playerLightCenters = lightCenters
            love.graphics.setShader(self.lightShader)
        end
        self.groundLightSources = groundLightSources
        self.lightCenters = centers
        self.innerRadii = innerRadii
        self.outerRadii = outerRadii
        self.maxBrightnesses = maxBrightnesses
        self.additiveStrengths = additiveStrengths
    end

    local zoomX = camera and math.max(camera.zoomX or 1, 0.001) or 1
    local zoomY = camera and math.max(camera.zoomY or 1, 0.001) or 1
    local cameraX = camera and camera.x or ((player and player.x or 0) * WORLD_SCALE_X - baseWidth / 2)
    local cameraY = camera and camera.y or ((player and player.y or 0) * YSCALE - baseHeight / 2)
    local visibleWidth = (baseWidth / zoomX) / math.max(WORLD_SCALE_X or 1, 0.001)
    local visibleHeight = (baseHeight / zoomY) / math.max(YSCALE or 1, 0.001)
    local visibleLeft = cameraX / math.max(WORLD_SCALE_X or 1, 0.001)
    local visibleTop = cameraY / math.max(YSCALE or 1, 0.001)
    local tileStartX = math.floor(visibleLeft / self.width)
    local tileStartY = math.floor(visibleTop / self.height)
    local repeatX = math.ceil((visibleLeft + visibleWidth - tileStartX * self.width) / self.width)
    local repeatY = math.ceil((visibleTop + visibleHeight - tileStartY * self.height) / self.height)
    local drawLeft = tileStartX * self.width
    local drawTop = tileStartY * self.height
    local drawWidth = math.max(self.width, repeatX * self.width)
    local drawHeight = math.max(self.height, repeatY * self.height)

    if PERF and PERF.enabled then
        PERF.groundRepeatX = repeatX
        PERF.groundRepeatY = repeatY
        PERF.groundRepeats = repeatX * repeatY
    end

    self.quad:setViewport(0, 0, drawWidth, drawHeight, self.width, self.height)
    love.graphics.draw(self.image, self.quad, drawLeft, drawTop)

    love.graphics.setShader()
end

return Ground
