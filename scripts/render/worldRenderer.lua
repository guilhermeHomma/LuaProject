local WorldRenderer = {}

local Ground = require("scripts/ground")
local Clouds = require("scripts/clouds")
local LightConfig = require("scripts/config/lightConfig")
local Trail = require("scripts.objects.trails")

local MAX_XRAY_TARGETS_PER_FRAME = 10
local MAX_XRAY_OCCLUDERS_PER_TARGET = 8
local XRAY_OCCLUDER_PADDING = 20
local BRIGHTNESS_CACHE_CELL_SIZE = 16
local PIXEL_BATCH_LIMIT = 512

local xraySoftShader = love.graphics.newShader("scripts/shaders/xraySoft.glsl")
local xrayStencilShader = love.graphics.newShader("scripts/shaders/xrayStencilAlpha.glsl")

local playerLightImage = love.graphics.newImage("assets/sprites/effects/light.png")
playerLightImage:setFilter("nearest", "nearest")
local playerLightHalfWidth = playerLightImage:getWidth() / 2
local playerLightHalfHeight = playerLightImage:getHeight() / 2

local pixelImageData = love.image.newImageData(1, 1)
pixelImageData:setPixel(0, 0, 1, 1, 1, 1)
local pixelImage = love.graphics.newImage(pixelImageData)
pixelImage:setFilter("nearest", "nearest")

local pixelBatch = love.graphics.newSpriteBatch(pixelImage, PIXEL_BATCH_LIMIT, "stream")
local pixelBatchCount = 0

local fastSrcX = {}
local fastSrcY = {}
local fastSrcMaxDistSq = {}
local fastSrcMinDist = {}
local fastSrcMaxBrightness = {}
local fastSrcInvRange = {}
local fastSrcFlicker = {}
local fastSrcCount = 0
local brightnessCellCache = {}
local xrayTargetOccluders = {}

local function sortDrawQueue(a, b)
    if a.priority == b.priority then
        local aSort = a.object and a.object.drawSortOrder or 0
        local bSort = b.object and b.object.drawSortOrder or 0
        return aSort < bSort
    end

    return a.priority < b.priority
end

local function getGeneralShadow()
    return LightConfig:getGeneralShadow()
end

local function getPlayerLightBrightness(object, sources, generalShadow)
    generalShadow = generalShadow or getGeneralShadow()
    local minBrightness = generalShadow.minBrightness or 1
    local brightness = minBrightness
    local objectX = object and (object.xWorld or object.x)
    local objectY = object and (object.yWorld or object.y)

    if not (objectX and objectY) then
        return brightness
    end

    for _, source in ipairs(sources or {}) do
        local spriteBrightness = source.spriteBrightness or (source.config and source.config.spriteBrightness)
        if spriteBrightness and spriteBrightness.enabled ~= false then
            local minDist = source.spriteMinDistance or spriteBrightness.minDistance or 35
            local maxDist = source.spriteMaxDistance or spriteBrightness.maxDistance or 230
            local maxBrightness = source.spriteMaxBrightness or spriteBrightness.maxBrightness or 1
            local dx = (source.x or 0) - objectX
            local dy = (source.y or 0) - objectY
            local maxDistSq = source.spriteMaxDistanceSq or (maxDist * maxDist)

            if dx * dx + dy * dy <= maxDistSq then
                local d = math.sqrt(dx * dx + dy * dy)
                local range = math.max(1, maxDist - minDist)
                local t = math.min(math.max((d - minDist) / range, 0), 1)
                local sourceBrightness = maxBrightness + (minBrightness - maxBrightness) * t
                sourceBrightness = math.min(math.max(sourceBrightness * (source.flicker or 1), minBrightness), maxBrightness)
                brightness = math.max(brightness, sourceBrightness)
            end
        end
    end

    return brightness
end

local function clearPixelBatch()
    pixelBatch:clear()
    pixelBatchCount = 0
end

local function canBatchPixelObject(object)
    return object and type(object.getBatchDrawInfo) == "function"
end

local function addPixelBatchObject(object, tintR, tintG, tintB, tintA)
    if pixelBatchCount >= PIXEL_BATCH_LIMIT then
        return false
    end

    local x, y, size, r, g, b, a = object:getBatchDrawInfo()
    pixelBatch:setColor(
        (r or 1) * (tintR or 1),
        (g or 1) * (tintG or 1),
        (b or 1) * (tintB or 1),
        (a or 1) * (tintA or 1)
    )
    pixelBatch:add(x, y, 0, size or 1, size or 1)
    pixelBatchCount = pixelBatchCount + 1
    return true
end

local function flushPixelBatch()
    if pixelBatchCount <= 0 then
        return
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(pixelBatch)
    clearPixelBatch()
end

local function buildFastLightSources(lightSources)
    fastSrcCount = 0
    for key in pairs(brightnessCellCache) do
        brightnessCellCache[key] = nil
    end

    for _, source in ipairs(lightSources) do
        local sp = source.spriteBrightness
        if sp and sp.enabled ~= false then
            local i = fastSrcCount + 1
            fastSrcCount = i
            fastSrcX[i] = source.x or 0
            fastSrcY[i] = source.y or 0
            fastSrcMaxDistSq[i] = source.spriteMaxDistanceSq or 0
            fastSrcMinDist[i] = source.spriteMinDistance or 35
            fastSrcMaxBrightness[i] = source.spriteMaxBrightness or 1
            local rng = math.max(1, (source.spriteMaxDistance or 230) - (source.spriteMinDistance or 35))
            fastSrcInvRange[i] = 1 / rng
            fastSrcFlicker[i] = source.flicker or 1
        end
    end
end

local function calcFastBrightness(objectX, objectY, minBrightness)
    local brightness = minBrightness
    for i = 1, fastSrcCount do
        local dx = fastSrcX[i] - objectX
        local dy = fastSrcY[i] - objectY
        local distSq = dx * dx + dy * dy
        if distSq <= fastSrcMaxDistSq[i] then
            local d = math.sqrt(distSq)
            local t = (d - fastSrcMinDist[i]) * fastSrcInvRange[i]
            if t < 0 then t = 0 elseif t > 1 then t = 1 end
            local mb = fastSrcMaxBrightness[i]
            local sb = mb + (minBrightness - mb) * t
            sb = sb * fastSrcFlicker[i]
            if sb < minBrightness then sb = minBrightness elseif sb > mb then sb = mb end
            if sb > brightness then brightness = sb end
        end
    end
    return brightness
end

local function canCacheBrightness(object)
    if not object then
        return false
    end
    if object == Player or object.enemyTypeId or object.isXrayProjectile then
        return false
    end
    return object.xWorld ~= nil or getmetatable(object) == Grass or getmetatable(object) == BigGrass
end

local function calcCachedBrightness(object, objectX, objectY, minBrightness)
    if fastSrcCount == 0 then
        return minBrightness
    end
    if not canCacheBrightness(object) then
        return calcFastBrightness(objectX, objectY, minBrightness)
    end

    local cellX = math.floor(objectX / BRIGHTNESS_CACHE_CELL_SIZE)
    local cellY = math.floor(objectY / BRIGHTNESS_CACHE_CELL_SIZE)
    local key = cellX * 65536 + cellY
    local cached = brightnessCellCache[key]
    if cached then
        return cached
    end

    local value = calcFastBrightness(
        cellX * BRIGHTNESS_CACHE_CELL_SIZE + BRIGHTNESS_CACHE_CELL_SIZE * 0.5,
        cellY * BRIGHTNESS_CACHE_CELL_SIZE + BRIGHTNESS_CACHE_CELL_SIZE * 0.5,
        minBrightness
    )
    brightnessCellCache[key] = value
    return value
end

local function drawFootsteps(game)
    local brightnessByFootstep = game.footstepBrightnessCache or {}
    game.footstepBrightnessCache = brightnessByFootstep
    for i = #brightnessByFootstep, 1, -1 do
        brightnessByFootstep[i] = nil
    end

    local lightSources = game:getLightSources()
    local generalShadow = getGeneralShadow()

    for index, item in ipairs(game.footsteps) do
        local brightness = getPlayerLightBrightness(item, lightSources, generalShadow)
        brightnessByFootstep[index] = brightness
        item:drawLayer1(brightness)
    end

    for index, item in ipairs(game.footsteps) do
        item:drawLayer2(brightnessByFootstep[index])
    end

    for index, item in ipairs(game.footsteps) do
        item:drawLayer3(brightnessByFootstep[index])
    end
end

local function drawShadows(game)
    Clouds:drawShadow()
    for _, item in ipairs(game.tilesetShadowItems or {}) do
        item.object:drawShadow()
    end
    for _, item in ipairs(game.entityShadowItems or {}) do
        item.object:drawShadow()
    end
end

local function drawGroundQueueObjects(game)
    local lightSources = game:getLightSources()
    local generalShadow = getGeneralShadow()
    local minBrightness = generalShadow.minBrightness or 1
    local items = game.groundDrawItems or game.drawQueue

    if minBrightness >= 1 then
        for _, item in ipairs(items) do
            local obj = item.object
            if canBatchPixelObject(obj) then
                addPixelBatchObject(obj, 1, 1, 1, 1)
            else
                flushPixelBatch()
                obj:draw()
            end
        end
    else
        local color = generalShadow.color or {0, 0, 0}
        local sr, sg, sb = color[1] or 0, color[2] or 0, color[3] or 0
        local ivr, ivg, ivb = 1 - sr, 1 - sg, 1 - sb
        buildFastLightSources(lightSources)
        for _, item in ipairs(items) do
            local obj = item.object
            local ox = obj.xWorld or obj.x
            local oy = obj.yWorld or obj.y
            local brt = ox and oy and calcCachedBrightness(obj, ox, oy, minBrightness) or minBrightness
            local r = sr + ivr * brt
            local g = sg + ivg * brt
            local b = sb + ivb * brt
            if canBatchPixelObject(obj) then
                addPixelBatchObject(obj, r, g, b, 1)
            else
                flushPixelBatch()
                love.graphics.setColor(r, g, b, 1)
                obj:draw()
            end
        end
        love.graphics.setColor(1, 1, 1, 1)
    end

    flushPixelBatch()
    if minBrightness < 1 then
        buildFastLightSources(lightSources)
    end

    table.sort(game.groundDecalQueue or {}, function(a, b) return (a.drawPriority or 0) < (b.drawPriority or 0) end)
    for _, object in ipairs(game.groundDecalQueue or {}) do
        local tintR, tintG, tintB = 1, 1, 1
        if minBrightness < 1 and object.affectedByLight then
            local ox = object.xWorld or object.x
            local oy = object.yWorld or object.y
            local brt = ox and oy and calcCachedBrightness(object, ox, oy, minBrightness) or minBrightness
            local color = generalShadow.color or {0, 0, 0}
            local sr, sg, sb = color[1] or 0, color[2] or 0, color[3] or 0
            tintR = sr + (1 - sr) * brt
            tintG = sg + (1 - sg) * brt
            tintB = sb + (1 - sb) * brt
            object.lightBrightness = brt
            object.lightTintR = tintR
            object.lightTintG = tintG
            object.lightTintB = tintB
        end

        if canBatchPixelObject(object) then
            addPixelBatchObject(object, tintR, tintG, tintB, 1)
        else
            flushPixelBatch()
            object:draw()
        end

        object.lightBrightness = nil
        object.lightTintR = nil
        object.lightTintG = nil
        object.lightTintB = nil
    end
    flushPixelBatch()
end

local function drawQueueObjects(game)
    local lightSources = game:getLightSources()
    local generalShadow = getGeneralShadow()
    local minBrightness = generalShadow.minBrightness or 1
    local items = game.objectDrawItems or game.drawQueue

    if minBrightness >= 1 then
        for _, item in ipairs(items) do
            local obj = item.object
            if canBatchPixelObject(obj) then
                addPixelBatchObject(obj, 1, 1, 1, 1)
            else
                flushPixelBatch()
                obj:draw()
            end
        end
    else
        local color = generalShadow.color or {0, 0, 0}
        local sr, sg, sb = color[1] or 0, color[2] or 0, color[3] or 0
        local ivr, ivg, ivb = 1 - sr, 1 - sg, 1 - sb
        buildFastLightSources(lightSources)
        for _, item in ipairs(items) do
            local obj = item.object
            local ox = obj.xWorld or obj.x
            local oy = obj.yWorld or obj.y
            local brt = ox and oy and calcCachedBrightness(obj, ox, oy, minBrightness) or minBrightness
            local r = sr + ivr * brt
            local g = sg + ivg * brt
            local b = sb + ivb * brt
            obj.lightBrightness = brt
            obj.lightTintR = r
            obj.lightTintG = g
            obj.lightTintB = b
            if canBatchPixelObject(obj) then
                addPixelBatchObject(obj, r, g, b, 1)
            else
                flushPixelBatch()
                love.graphics.setColor(r, g, b, 1)
                obj:draw()
            end
            obj.lightBrightness = nil
            obj.lightTintR = nil
            obj.lightTintG = nil
            obj.lightTintB = nil
        end
        love.graphics.setColor(1, 1, 1, 1)
    end
    flushPixelBatch()
end

local function canDrawXrayTarget(object)
    return object
        and object.isXrayVisible == true
        and type(object.drawXray) == "function"
        and object.isAlive ~= false
end

local function canMaskXrayOccluder(object)
    return object
        and object.isXrayOccluder == true
        and object.isAlive ~= false
end

local function getXrayTargetRank(object)
    if object == Player then
        return 1
    end
    if object and object.isXrayProjectile == true then
        return 2
    end
    if object and object.persistRoomDrop == true then
        return 3
    end
    return 4
end

local function sortXrayTargets(a, b)
    local rankA = getXrayTargetRank(a.object)
    local rankB = getXrayTargetRank(b.object)
    if rankA == rankB then
        return a.priority < b.priority
    end
    return rankA < rankB
end

local function getXrayOccluderBox(object)
    if object and type(object.getXrayOccluderBox) == "function" then
        return object:getXrayOccluderBox()
    end

    local x = object and (object.xWorld or object.x)
    local y = object and (object.yWorld or object.y)
    if not (x and y) then
        return nil
    end

    local width = object.xrayMaskWidth or ((object.size or 16) * 2)
    local height = object.xrayMaskHeight or ((object.size or 16) * 3)
    return {
        x = x - width / 2,
        y = y - height,
        width = width,
        height = height,
    }
end

local function getXrayTargetBox(object)
    if object and type(object.getXrayBox) == "function" then
        return object:getXrayBox()
    end

    local x = object and (object.xWorld or object.x)
    local y = object and (object.yWorld or object.y)
    if not (x and y) then
        return nil
    end

    local width = object.xrayTargetWidth or object.xrayMaskWidth or ((object.size or 16) * 2)
    local height = object.xrayTargetHeight or object.xrayMaskHeight or ((object.size or 16) * 3)
    return {
        x = x - width / 2,
        y = y - height,
        width = width,
        height = height,
    }
end

local function boxesOverlap(a, b, padding)
    if not (a and b) then
        return false
    end

    padding = padding or 0
    return a.x - padding < b.x + b.width
        and a.x + a.width + padding > b.x
        and a.y - padding < b.y + b.height
        and a.y + a.height + padding > b.y
end

local function boxCenter(box)
    return box.x + box.width * 0.5, box.y + box.height * 0.5
end

local function getXraySortY(object)
    if not object then
        return nil
    end

    if object.drawBaseY then
        return object.drawBaseY + (object.drawPriorityOffset or 0)
    end

    return object.xraySortY
        or object.yWorld
        or object.y
end

local function isTargetBehindBoxOccluder(targetObject, occluderObject)
    local targetY = getXraySortY(targetObject)
    local occluderY = getXraySortY(occluderObject)

    if not (targetY and occluderY) then
        return false
    end

    return targetY < occluderY
end

local function shouldUseXrayOccluder(target, item)
    if not (target and item and canMaskXrayOccluder(item.object)) then
        return false
    end

    if item.priority > target.priority then
        return true
    end

    if item.object and item.object.isXrayBoxOccluder == true then
        return isTargetBehindBoxOccluder(target.object, item.object)
    end

    return target.object
        and target.object.isXrayProjectile == true
        and item.object
        and item.object.isXrayTileOccluder == true
end

local function collectXrayOccludersForTarget(target, occluders)
    for i = #xrayTargetOccluders, 1, -1 do
        xrayTargetOccluders[i] = nil
    end

    local targetBox = getXrayTargetBox(target.object)
    if not targetBox then
        return xrayTargetOccluders
    end

    local targetCx, targetCy = boxCenter(targetBox)
    for _, item in ipairs(occluders) do
        if shouldUseXrayOccluder(target, item) then
            local box = getXrayOccluderBox(item.object)
            if boxesOverlap(targetBox, box, XRAY_OCCLUDER_PADDING) then
                local cx, cy = boxCenter(box)
                item.xrayDistanceSq = (cx - targetCx) * (cx - targetCx) + (cy - targetCy) * (cy - targetCy)
                xrayTargetOccluders[#xrayTargetOccluders + 1] = item
            end
        end
    end

    if #xrayTargetOccluders > MAX_XRAY_OCCLUDERS_PER_TARGET then
        table.sort(xrayTargetOccluders, function(a, b)
            return (a.xrayDistanceSq or 0) < (b.xrayDistanceSq or 0)
        end)
        for i = #xrayTargetOccluders, MAX_XRAY_OCCLUDERS_PER_TARGET + 1, -1 do
            xrayTargetOccluders[i] = nil
        end
    end

    return xrayTargetOccluders
end

local function drawXrayTargets(game)
    local targets = game.xrayTargets or {}
    local occluders = game.xrayOccluders or {}
    game.xrayTargets = targets
    game.xrayOccluders = occluders

    if #targets == 0 or #occluders == 0 then
        return
    end

    local previousShader = love.graphics.getShader()
    local previousBlendMode, previousAlphaMode = love.graphics.getBlendMode()
    local previousR, previousG, previousB, previousA = love.graphics.getColor()

    love.graphics.setBlendMode("alpha", "alphamultiply")
    xraySoftShader:send("u_time", love.timer.getTime())
    xraySoftShader:send("u_alpha", 0.72)
    love.graphics.setShader(xraySoftShader)

    for _, target in ipairs(targets) do
        local targetOccluders = collectXrayOccludersForTarget(target, occluders)
        if #targetOccluders > 0 then
            love.graphics.stencil(function()
                love.graphics.setShader()
                for _, item in ipairs(targetOccluders) do
                    if type(item.object.drawXrayOccluder) == "function" then
                        love.graphics.setShader(xrayStencilShader)
                        love.graphics.setColor(1, 1, 1, 1)
                        item.object:drawXrayOccluder()
                        love.graphics.setShader()
                    else
                        local box = getXrayOccluderBox(item.object)
                        if box then
                            love.graphics.setColor(1, 1, 1, 1)
                            love.graphics.rectangle("fill", box.x, box.y, box.width, box.height)
                        end
                    end
                end
            end, "replace", 1, false)

            love.graphics.setShader(xraySoftShader)
            love.graphics.setStencilTest("greater", 0)
            love.graphics.setColor(1, 1, 1, 1)
            target.object:drawXray()
            love.graphics.setStencilTest()
        end
    end

    love.graphics.setBlendMode(previousBlendMode, previousAlphaMode)
    love.graphics.setShader(previousShader)
    love.graphics.setColor(previousR, previousG, previousB, previousA)
end

local function prepareDrawQueues(game)
    local groundItems = game.groundDrawItems or {}
    local objectItems = game.objectDrawItems or {}
    local tilesetShadowItems = game.tilesetShadowItems or {}
    local entityShadowItems = game.entityShadowItems or {}
    local xrayTargets = game.xrayTargets or {}
    local xrayOccluders = game.xrayOccluders or {}

    game.groundDrawItems = groundItems
    game.objectDrawItems = objectItems
    game.tilesetShadowItems = tilesetShadowItems
    game.entityShadowItems = entityShadowItems
    game.xrayTargets = xrayTargets
    game.xrayOccluders = xrayOccluders

    for i = #groundItems, 1, -1 do groundItems[i] = nil end
    for i = #objectItems, 1, -1 do objectItems[i] = nil end
    for i = #tilesetShadowItems, 1, -1 do tilesetShadowItems[i] = nil end
    for i = #entityShadowItems, 1, -1 do entityShadowItems[i] = nil end
    for i = #xrayTargets, 1, -1 do xrayTargets[i] = nil end
    for i = #xrayOccluders, 1, -1 do xrayOccluders[i] = nil end

    for i = 1, #game.drawQueue do
        local item = game.drawQueue[i]
        local object = item.object
        if object.isGroundLayer then
            groundItems[#groundItems + 1] = item
        else
            objectItems[#objectItems + 1] = item
            if object.castsShadow ~= false and type(object.drawShadow) == "function" then
                if object.xWorld then
                    tilesetShadowItems[#tilesetShadowItems + 1] = item
                else
                    entityShadowItems[#entityShadowItems + 1] = item
                end
            end
        end

        if canDrawXrayTarget(object) then
            xrayTargets[#xrayTargets + 1] = item
        elseif canMaskXrayOccluder(object) then
            xrayOccluders[#xrayOccluders + 1] = item
        end
    end

    if #xrayTargets > MAX_XRAY_TARGETS_PER_FRAME then
        table.sort(xrayTargets, sortXrayTargets)
        for i = #xrayTargets, MAX_XRAY_TARGETS_PER_FRAME + 1, -1 do
            xrayTargets[i] = nil
        end
    end
end

local function drawLightSprites(game)
    local previousBlendMode, previousAlphaMode = love.graphics.getBlendMode()
    local sources = game:getLightSources()

    love.graphics.setBlendMode("alpha", "alphamultiply")

    for _, source in ipairs(sources) do
        local visual = source.visual or (source.config and source.config.visual)
        if visual and visual.enabled ~= false then
            local color = visual.color or {1, 1, 1}
            local flicker = source.flicker or 1
            local scale = visual.scale or 0.65
            if visual.flickerScale then
                scale = scale * flicker
            end

            love.graphics.setColor(
                color[1] or 1,
                color[2] or 1,
                color[3] or 1,
                (visual.alpha or 0.18) * flicker
            )
            love.graphics.draw(
                playerLightImage,
                source.x,
                source.y,
                0,
                scale,
                scale,
                playerLightHalfWidth,
                playerLightHalfHeight
            )
        end
    end

    love.graphics.setBlendMode("add", "alphamultiply")
    for _, source in ipairs(sources) do
        local visual = source.visual or (source.config and source.config.visual)
        if visual and visual.enabled ~= false and visual.glowAlpha and visual.glowAlpha > 0 then
            local color = visual.color or {1, 1, 1}
            local flicker = source.flicker or 1
            local scale = visual.glowScale or (visual.scale or 0.65)
            if visual.flickerScale then
                scale = scale * flicker
            end

            love.graphics.setColor(
                color[1] or 1,
                color[2] or 1,
                color[3] or 1,
                (visual.glowAlpha or 0.05) * flicker
            )
            love.graphics.draw(
                playerLightImage,
                source.x,
                source.y,
                0,
                scale,
                scale,
                playerLightHalfWidth,
                playerLightHalfHeight
            )
        end
    end

    love.graphics.setBlendMode(previousBlendMode, previousAlphaMode)
    love.graphics.setColor(1, 1, 1, 1)
end

function WorldRenderer.draw(game)
    camera:attach()
    love.graphics.scale(WORLD_SCALE_X, YSCALE)

    Ground:draw(Player)
    drawLightSprites(game)

    if #game.drawQueue > 1 then
        table.sort(game.drawQueue, sortDrawQueue)
    end
    prepareDrawQueues(game)

    if not (CURRENT_LEVEL and CURRENT_LEVEL.enableTrails == false) then
        Trail:draw()
    end
    drawFootsteps(game)
    drawGroundQueueObjects(game)
    drawShadows(game)
    Player:drawSight()
    drawQueueObjects(game)
    Clouds:draw()
    drawXrayTargets(game)

    love.graphics.scale(1, 1)
    camera:detach()
end

return WorldRenderer
