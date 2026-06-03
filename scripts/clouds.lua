local Clouds = {}
local FloorManager = require("scripts/managers/floorManager")

local function currentThemeAllowsClouds()
    local theme = FloorManager.getCurrentRoomTheme and FloorManager:getCurrentRoomTheme() or nil
    return not theme or theme.clouds ~= false
end

local function buildCloudCells(count, spacingX, spacingY, jitterX, jitterY)
    local cells = {}
    for i = 1, count do
        cells[i] = {
            cellOffsetX = i - 1,
            cellOffsetY = (i % 2) - 1,
            x = love.math.random(-jitterX, jitterX),
            y = love.math.random(-jitterY, jitterY),
        }
    end

    return {
        count = count,
        spacingX = spacingX,
        spacingY = spacingY,
        cells = cells,
    }
end

local function clearArray(list)
    for i = #list, 1, -1 do
        list[i] = nil
    end
end

local function removeArrayIndex(list, index)
    for i = index, #list - 1 do
        list[i] = list[i + 1]
    end
    list[#list] = nil
end

local function hasActiveCloud(activeClouds, key)
    for i = 1, #activeClouds do
        if activeClouds[i] == key then
            return true
        end
    end

    return false
end


function Clouds:load(target)
    self.image = love.graphics.newImage("assets/sprites/cloud.png")
    self.image:setFilter("nearest", "nearest")
    self.image:setWrap("repeat", "repeat")
    self.width = self.image:getWidth()
    self.height = self.image:getHeight()
    self.quads = {}
    self.movement = 0
    self.randomSeed = love.math.random(1, 100000)
    self.target = target
    self.layers = {
        {
            alpha = 0.08,
            height = 70,
            parallax = 1.10,
            scale = 1,
            maxVisible = 1,
            movementScale = 0.5,
            offsetX = love.math.random(-140, 140),
            offsetY = love.math.random(-90, 90),
            driftX = love.math.random() * 0.35 + 0.85,
            driftY = love.math.random() * 0.18 - 0.09,
            cloudCells = buildCloudCells(1, 720, 520, 120, 80),
        },
        {
            alpha = 0.04,
            height = 108,
            parallax = 1.24,
            scale = 1.35,
            maxVisible = 1,
            movementScale = 0.75,
            offsetX = love.math.random(-220, 220),
            offsetY = love.math.random(-130, 130),
            driftX = love.math.random() * 0.35 + 0.75,
            driftY = love.math.random() * 0.16 - 0.08,
            cloudCells = buildCloudCells(1, 960, 700, 160, 110),
        },
    }
end

function Clouds:update(dt)
    if not currentThemeAllowsClouds() then
        return
    end

    local speed = (math.sin(love.timer.getTime() * 0.2) + 3 ) / 4
    self.movement = self.movement + 10 * dt * speed
end

function Clouds:drawShadow()
    if not currentThemeAllowsClouds() then
        return
    end

    --self:drawCloud(true)
end


function Clouds:drawCloudLayer(layer, shadow)
    if not (self.image and self.width and self.height) then
        return
    end

    local scale = layer.scale or 1
    local width = self.width * scale
    local height = self.height * scale
    local cloudHeight = layer.height or 70
    local alpha = layer.alpha or 0.08

    love.graphics.setColor(1, 1, 1, alpha)
    if shadow == true then
        love.graphics.setColor(0, 0, 0, 0.04)
        cloudHeight = 0
    end

    local parallax = layer.parallax or 0.8
    local movement = self.movement * (layer.movementScale or 1)
    local cameraX = camera and camera.x and camera.x / WORLD_SCALE_X or 0
    local cameraY = camera and camera.y and camera.y / YSCALE or 0
    local viewWidth = camera and camera.viewWidth or (baseWidth / math.max(camera and camera.zoomX or 1, 0.001))
    local viewHeight = camera and camera.viewHeight or (baseHeight / math.max(camera and camera.zoomY or 1, 0.001))
    local visibleWidth = viewWidth / math.max(WORLD_SCALE_X, 0.001)
    local visibleHeight = viewHeight / math.max(YSCALE, 0.001)
    local parallaxX = cameraX * (1 - parallax)
    local parallaxY = cameraY * (1 - parallax)
    local cloudCells = layer.cloudCells
    if not cloudCells then
        return
    end

    local visibleLeft = cameraX
    local visibleRight = cameraX + visibleWidth
    local visibleTop = cameraY
    local visibleBottom = cameraY + visibleHeight
    local activationMarginX = layer.activationMarginX or width
    local activationMarginY = layer.activationMarginY or height
    local activationLeft = visibleLeft - activationMarginX
    local activationRight = visibleRight + activationMarginX
    local activationTop = visibleTop - activationMarginY
    local activationBottom = visibleBottom + activationMarginY
    local targetX = cameraX + visibleWidth * 0.5 - parallaxX
    local targetY = cameraY + visibleHeight * 0.5 - parallaxY
    local baseCellX = math.floor(targetX / cloudCells.spacingX)
    local baseCellY = math.floor(targetY / cloudCells.spacingY)
    local searchCellsX = math.max(2, math.ceil((visibleWidth + width) / cloudCells.spacingX) + 1)
    local searchCellsY = math.max(2, math.ceil((visibleHeight + height) / cloudCells.spacingY) + 1)
    local centerX = visibleLeft + visibleWidth * 0.5
    local centerY = visibleTop + visibleHeight * 0.5
    local candidates = layer.visibleCloudCandidates or {}
    local visibleByKey = layer.visibleCloudByKey or {}
    local activeClouds = layer.activeClouds or {}
    layer.visibleCloudCandidates = candidates
    layer.visibleCloudByKey = visibleByKey
    layer.activeClouds = activeClouds

    clearArray(candidates)
    for key in pairs(visibleByKey) do
        visibleByKey[key] = nil
    end

    for i = 1, cloudCells.count do
        local cell = cloudCells.cells[i]
        for cellY = baseCellY - searchCellsY, baseCellY + searchCellsY do
            for cellX = baseCellX - searchCellsX, baseCellX + searchCellsX do
                local worldX = (cellX + cell.cellOffsetX) * cloudCells.spacingX
                    + cloudCells.spacingX * 0.5
                    + cell.x
                    + (layer.offsetX or 0)
                local worldY = (cellY + cell.cellOffsetY) * cloudCells.spacingY
                    + cloudCells.spacingY * 0.5
                    + cell.y
                    + (layer.offsetY or 0)
                local x = worldX + parallaxX - movement * (layer.driftX or 1) - width / 2
                local y = worldY + parallaxY + movement * (layer.driftY or 0) - cloudHeight - height / 2

                if x < activationRight
                    and x + width > activationLeft
                    and y < activationBottom
                    and y + height > activationTop then
                    local candidate = {
                        key = i .. ":" .. cellX .. ":" .. cellY,
                        x = x,
                        y = y,
                        distanceSq = (x + width * 0.5 - centerX) * (x + width * 0.5 - centerX)
                            + (y + height * 0.5 - centerY) * (y + height * 0.5 - centerY),
                    }
                    candidates[#candidates + 1] = candidate
                    visibleByKey[candidate.key] = candidate
                end
            end
        end
    end

    for i = #activeClouds, 1, -1 do
        if not visibleByKey[activeClouds[i]] then
            removeArrayIndex(activeClouds, i)
        end
    end

    local maxVisible = layer.maxVisible or #candidates
    while #activeClouds < maxVisible do
        local best, bestDist = nil, math.huge
        for _, c in ipairs(candidates) do
            if not hasActiveCloud(activeClouds, c.key) then
                local offscreen = c.x + width <= visibleLeft or c.x >= visibleRight
                    or c.y + height <= visibleTop or c.y >= visibleBottom
                if offscreen and c.distanceSq < bestDist then
                    best = c
                    bestDist = c.distanceSq
                end
            end
        end
        if not best then break end
        activeClouds[#activeClouds + 1] = best.key
    end

    for i = 1, math.min(#activeClouds, maxVisible) do
        local candidate = visibleByKey[activeClouds[i]]
        if candidate then
            love.graphics.draw(self.image, candidate.x, candidate.y, 0, scale, scale)
        end
    end

    love.graphics.setColor(1, 1, 1)
end

function Clouds:drawCloud(shadow)
    for _, layer in ipairs(self.layers or {}) do
        self:drawCloudLayer(layer, shadow)
    end
end

function Clouds:draw()
    if not currentThemeAllowsClouds() then
        return
    end

    self:drawCloud(false)
end

return Clouds
