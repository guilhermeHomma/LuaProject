TreeTile = setmetatable({}, {__index = Tile})
TreeTile.__index = TreeTile
TreeTile.castsShadow = false
TileSet = require("scripts.objects.tileset")
local LeafParticle = require("scripts/particles/leafParticle")
local FloorManager = require("scripts/managers/floorManager")
local TreeConfig = require("scripts/config/treeConfig")

local treeSheetImage = love.graphics.newImage("assets/sprites/florest/three.png")
local bigThreeImage = love.graphics.newImage("assets/sprites/objects/bigthree.png")
local TilemapModule = nil
local triedLoadingTilemapModule = false

treeSheetImage:setFilter("nearest", "nearest")
bigThreeImage:setFilter("nearest", "nearest")

local TREE_FRAME_WIDTH = 64
local TREE_FRAME_HEIGHT = 96
local TREE_FRAME_COUNT = 5
local treeQuads = {}
local treeFrameUVs = {}
local treeSheetWidth, treeSheetHeight = treeSheetImage:getDimensions()
treeFrameUVs.big = {0, 0, 1, 1}

for i = 1, TREE_FRAME_COUNT do
    local frameX = (i - 1) * TREE_FRAME_WIDTH
    treeQuads[i] = love.graphics.newQuad(
        frameX,
        0,
        TREE_FRAME_WIDTH,
        TREE_FRAME_HEIGHT,
        treeSheetWidth,
        treeSheetHeight
    )
    treeFrameUVs[i] = {
        (frameX + 0.5) / treeSheetWidth,
        0,
        (frameX + TREE_FRAME_WIDTH - 0.5) / treeSheetWidth,
        TREE_FRAME_HEIGHT / treeSheetHeight,
    }
end

local shader = love.graphics.newShader([[
    extern float time;
    extern float invScaleY10;
    extern float camPhaseOffset;
    extern vec2 spriteSize;
    extern vec4 frameUV;

    vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
        float phase = screen_coords.y * invScaleY10 + camPhaseOffset;
        float direction = sin(time * 1.0 + phase);
        vec2 frameSize = max(frameUV.zw - frameUV.xy, vec2(0.0001));
        vec2 localUV = clamp((texture_coords - frameUV.xy) / frameSize, vec2(0.0), vec2(1.0));
        vec2 pixelCoord = localUV * spriteSize;
        float relY = clamp(1.0 - pixelCoord.y / spriteSize.y, 0.0, 1.0);
        float sway = relY * relY * 0.42;
        texture_coords.x = clamp(texture_coords.x + direction / spriteSize.x * sway, frameUV.x, frameUV.z);
        return Texel(tex, texture_coords) * color;
    }
]])

shader:send("time", 0.0)
shader:send("invScaleY10", 1.0 / (2.4 * 18.0))
shader:send("camPhaseOffset", 0.0)
shader:send("spriteSize", {64.0, 96.0})
shader:send("frameUV", {0.0, 0.0, 1.0, 1.0})

local treeShaderSize = {64, 96}
local treeShaderFrameUV = {0, 0, 1, 1}
local lastTreeShaderWidth = 64
local lastTreeShaderHeight = 96
local lastTreeShaderFrameUV = nil
local lastShaderUpdateTime = -1

local function updateTreeShaderGlobals()
    local t = love.timer.getTime()
    if t == lastShaderUpdateTime then return end
    lastShaderUpdateTime = t
    shader:send("time", t)
    if camera and YSCALE then
        local zy = camera.zoomY or 1
        local inv = 1.0 / (YSCALE * zy * 18.0)
        shader:send("invScaleY10", inv)
        shader:send("camPhaseOffset", (camera.y or 0) / (YSCALE * 18.0) - (baseHeight * 0.5) * inv)
    end
end

local function applyTreeShader(width, height, frameUV)
    love.graphics.setShader(shader)
    updateTreeShaderGlobals()
    if width ~= lastTreeShaderWidth or height ~= lastTreeShaderHeight then
        treeShaderSize[1], treeShaderSize[2] = width, height
        shader:send("spriteSize", treeShaderSize)
        lastTreeShaderWidth, lastTreeShaderHeight = width, height
    end
    if frameUV ~= lastTreeShaderFrameUV then
        treeShaderFrameUV[1], treeShaderFrameUV[2] = frameUV[1], frameUV[2]
        treeShaderFrameUV[3], treeShaderFrameUV[4] = frameUV[3], frameUV[4]
        shader:send("frameUV", treeShaderFrameUV)
        lastTreeShaderFrameUV = frameUV
    end
end

local function randomRange(minValue, maxValue)
    return minValue + math.random() * (maxValue - minValue)
end

local function isObjectNearBox(object, box, padding)
    local x = object.x or object.xWorld
    local y = object.y or object.yWorld

    if not x or not y then
        return true
    end

    return x >= box.x - padding
        and x <= box.x + box.width + padding
        and y >= box.y - padding
        and y <= box.y + box.height + padding
end

local function isObjectInsideBox(object, box, padding)
    return isObjectNearBox(object, box, padding or 0)
end

local function doBoxesOverlap(a, b, padding)
    padding = padding or 0
    return a.x < b.x + b.width + padding
        and a.x + a.width > b.x - padding
        and a.y < b.y + b.height + padding
        and a.y + a.height > b.y - padding
end

local function getDoorTiles()
    if not triedLoadingTilemapModule then
        local ok, Tilemap = pcall(require, "scripts/tilemap")
        if ok then
            TilemapModule = Tilemap
        end
        triedLoadingTilemapModule = true
    end

    if not TilemapModule then
        return nil
    end

    return TilemapModule.doorTiles
end

local function getFadeAreaConfig()
    return TreeConfig.fadeArea or {}
end

local function getForegroundDarkenConfig()
    return TreeConfig.foregroundDarken or {}
end

local function smoothStep(value)
    value = math.max(0, math.min(value, 1))
    return value * value * (3 - 2 * value)
end

local function getTreeForegroundBrightness(tree)
    local config = getForegroundDarkenConfig()
    if config.enabled == false or not (camera and YSCALE) then
        return 1
    end

    local minDistance = config.minDistance or 120
    local maxDistance = config.maxDistance or 300
    local range = math.max(1, maxDistance - minDistance)
    local zoomY = camera.zoomY or 1
    local screenY = ((tree.yWorld or 0) * YSCALE - (camera.y or 0)) * zoomY
    local referenceY = (baseHeight or 720) * 0.5 + (config.referenceYOffset or 0)
    local distance = screenY - referenceY
    local progress = smoothStep((distance - minDistance) / range)
    local minBrightness = math.max(0, math.min(config.minBrightness or 0, 1))

    return 1 + (minBrightness - 1) * progress
end

local function hasDoorInsideBox(box, padding)
    local doors = getDoorTiles()
    if not doors then
        return false
    end

    local fadeArea = getFadeAreaConfig()
    local doorBoxWidth = fadeArea.doorBoxWidth or 16
    local doorBoxHeight = fadeArea.doorBoxHeight or 48
    local doorBoxYOffset = fadeArea.doorBoxYOffset or -48

    for _, door in ipairs(doors) do
        local doorBox = {
            x = door.xWorld - doorBoxWidth / 2,
            y = door.yWorld + doorBoxYOffset,
            width = doorBoxWidth,
            height = doorBoxHeight,
        }
        if doBoxesOverlap(box, doorBox, padding) then
            return true
        end
    end

    return false
end

local function getTreeFadeBox(tree, originX, originY, spriteWidth)
    local fadeArea = getFadeAreaConfig()
    local marginX = fadeArea.marginX or 4
    local topOffset = fadeArea.topOffset or 4
    local bottomPadding = fadeArea.bottomPadding or 8

    return {
        x = tree.xWorld - originX + marginX,
        y = tree.yWorld - originY + topOffset,
        width = spriteWidth - marginX * 2,
        height = originY - topOffset + bottomPadding,
    }
end

local function getTreeSpriteMetrics(tree)
    local originX = 32
    local originY = 93
    local spriteWidth = 64
    local spriteHeight = 96

    if tree.treeIndex == 6 then
        originX = 80
        originY = 156
        spriteWidth = 160
        spriteHeight = 160
    end

    return originX, originY, spriteWidth, spriteHeight
end

local function getTreeSprite(tree)
    if tree.treeIndex == 6 then
        return bigThreeImage, nil, treeFrameUVs.big
    end

    return treeSheetImage, treeQuads[tree.treeIndex] or treeQuads[1], treeFrameUVs[tree.treeIndex] or treeFrameUVs[1]
end

function TreeTile:new(x, y, quadIndex, collider, options)
    local tile = Tile.new(self, x, y, quadIndex, collider)
    options = options or {}


    tile.yAdd = 3 + math.random() * 0.25
    tile.ySortOffset = options.ySortOffset or 0
    tile.treeIndex = math.random(3)

    if math.random(30) == 1 and not collider then 
        tile.treeIndex = 4
    end

    if math.random(30) == 1 and not collider then
        tile.treeIndex = 5
    end

    tile.stretch = 1.4
    if tile.treeIndex == 5 then 
        tile.stretch = 1.2
    elseif math.random() > 0.6 then
        tile.stretch = 1.3
    end
    tile.leafTimer = math.random() * 2
    tile.renderCullMargin = 420

    setmetatable(tile, TreeTile)
    return tile
end

function TreeTile:newBig(x, y, quadIndex, collider, options)
    local tile = Tile.new(self, x, y, quadIndex, collider)
    options = options or {}


    tile.yAdd = 18 + math.random() * 0.25
    tile.ySortOffset = options.ySortOffset or 0
    tile.treeIndex = 6
    tile.stretch = 1.4
    tile.alpha = 1
    tile.leafTimer = math.random() * 2
    tile.renderCullMargin = 640

    setmetatable(tile, TreeTile)
    return tile
end

function TreeTile:isCloseToPlayerForLeaves()
    if not Player or not Player.isAlive then
        return false
    end

    local dx = self.xWorld - Player.x
    local dy = self.yWorld - Player.y
    local maxDistance = 200
    return dx * dx + dy * dy <= maxDistance * maxDistance
end

function TreeTile:createLeaf()
    local xSpread = 24
    local yMin = 55
    local yMax = 105

    if self.treeIndex == 6 then
        xSpread = 62
        yMin = 95
        yMax = 205
    end

    local x = self.xWorld + randomRange(-xSpread, xSpread)
    local y = self.yWorld - randomRange(yMin, yMax)
    table.insert(Game.particles, LeafParticle:new(x, y))
end

function TreeTile:updateLeaves(dt)
    local theme = FloorManager.getCurrentRoomTheme and FloorManager:getCurrentRoomTheme() or nil
    if theme and theme.leafParticles == false then
        return
    end

    if not self:isCloseToPlayerForLeaves() then
        self.leafTimer = math.min(self.leafTimer, 0.35)
        return
    end

    self.leafTimer = self.leafTimer - dt
    if self.leafTimer > 0 then
        return
    end

    self:createLeaf()
    self.leafTimer = 1.7 + math.random() * 0.8
end

function TreeTile:update(dt)
    self.isXrayOccluder = true
    if camera and camera.objectPosition then
        local cameraPosition = camera:objectPosition()
        local margin = self.renderCullMargin or 420
        local limit = (HARD_RENDER_DISTANCE or RENDER_DISTANCE or 350) + margin
        local dx = self.xWorld - cameraPosition.x
        local dy = self.yWorld - cameraPosition.y
        if dx * dx + dy * dy > limit * limit then
            return
        end
    end

    addToDrawQueue(self.yWorld + 1 + self.yAdd + (self.ySortOffset or 0), self, false)
    self:updateLeaves(dt)
    --print(self.shaderDirection)
end

function TreeTile:getFadeBox()
    local originX, originY, spriteWidth = getTreeSpriteMetrics(self)
    return getTreeFadeBox(self, originX, originY, spriteWidth)
end

function TreeTile:markTransparent()
    local fadeArea = getFadeAreaConfig()
    self.fadeTargetAlpha = fadeArea.hiddenAlpha or 0
end

function TreeTile:getTargetAlpha(box)
    local fadeArea = getFadeAreaConfig()
    local hiddenAlpha = fadeArea.hiddenAlpha or 0

    if hasDoorInsideBox(box, fadeArea.doorAreaPadding or 0) then
        return hiddenAlpha
    end

    if self.treeIndex == 6 then
        return 1
    end

    if self.treeIndex == 4 or self.treeIndex == 5 then
        return 1
    end

    if self.fadeTargetAlpha ~= nil then
        return self.fadeTargetAlpha
    end

    if not isObjectNearBox(Player, box, fadeArea.playerCalculationPadding or 160) then
        return 1
    end

    if Player.isAlive then
        local playerPadding = fadeArea.playerAreaPadding or 0
        if isObjectInsideBox(Player, box, playerPadding) then
            return hiddenAlpha
        end
    end
    
    return 1
end


function TreeTile:getXrayOccluderBox()
    local originX, originY, spriteWidth, spriteHeight = getTreeSpriteMetrics(self)

    return {
        x = self.xWorld - originX,
        y = self.yWorld - originY * (self.stretch or 1),
        width = spriteWidth,
        height = spriteHeight * (self.stretch or 1),
    }
end

function TreeTile:drawXrayOccluder()
    local originX = 32
    local originY = 93

    local image, quad = getTreeSprite(self)
    if self.treeIndex == 6 then
        originX = 80
        originY = 156
    end

    if quad then
        love.graphics.draw(image, quad, self.xWorld, self.yWorld, 0, 1, self.stretch, originX, originY)
    else
        love.graphics.draw(image, self.xWorld, self.yWorld, 0, 1, self.stretch, originX, originY)
    end
end

function TreeTile:draw()

    local tileSet = TileSet:getTileSet()
    local tileSize = TileSet.tileSize
    local tilesetImage = TileSet.tilesetImage

    local image, quad, frameUV = getTreeSprite(self)
    local originX, originY, spriteWidth, spriteHeight = getTreeSpriteMetrics(self)

    applyTreeShader(spriteWidth, spriteHeight, frameUV)

    if not self.collider then
        love.graphics.draw(tilesetImage, tileSet[5], self.xWorld, self.yWorld , 0, 1, 1, tileSize/2, tileSize)
    end

    local box = getTreeFadeBox(self, originX, originY, spriteWidth)

    local targetAlpha = self:getTargetAlpha(box)

    local fadeArea = getFadeAreaConfig()
    local fadeStep = targetAlpha < self.alpha
        and (fadeArea.fadeOutStep or 0.055)
        or (fadeArea.fadeInStep or 0.075)
    self.alpha = self.alpha + (targetAlpha - self.alpha) * fadeStep
    
    local r, g, b, a = love.graphics.getColor()
    local foregroundBrightness = getTreeForegroundBrightness(self)
    love.graphics.setColor(r * foregroundBrightness, g * foregroundBrightness, b * foregroundBrightness, self.alpha)
    
    if quad then
        love.graphics.draw(image, quad, self.xWorld, self.yWorld, 0, 1, self.stretch, originX, originY)
    else
        love.graphics.draw(image, self.xWorld, self.yWorld, 0, 1, self.stretch, originX, originY)
    end
    love.graphics.setColor(r, g, b, a) 
    love.graphics.setShader()
end

return TreeTile
