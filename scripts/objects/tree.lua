TreeTile = setmetatable({}, {__index = Tile})
TreeTile.__index = TreeTile
TileSet = require("scripts.objects.tileset")
local LeafParticle = require("scripts/particles/leafParticle")
local TreeConfig = require("scripts/config/treeConfig")

local threeImage1 = love.graphics.newImage("assets/sprites/objects/three1.png")
local threeImage2 = love.graphics.newImage("assets/sprites/objects/three2.png")
local threeImage3 = love.graphics.newImage("assets/sprites/objects/three3.png")
local threeImage4 = love.graphics.newImage("assets/sprites/objects/three4.png")
local threeImage5 = love.graphics.newImage("assets/sprites/objects/three5.png")
local bigThreeImage = love.graphics.newImage("assets/sprites/objects/bigthree.png")

threeImage1:setFilter("nearest", "nearest")
threeImage2:setFilter("nearest", "nearest")
threeImage3:setFilter("nearest", "nearest")
threeImage4:setFilter("nearest", "nearest")
threeImage5:setFilter("nearest", "nearest")
bigThreeImage:setFilter("nearest", "nearest")

local shader = love.graphics.newShader([[
    extern number direction;
    extern vec2 spriteSize;

    vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
        vec2 pixelCoord = texture_coords * spriteSize;
        if (pixelCoord.y < spriteSize.y - 30.0) {
            texture_coords.x += direction / spriteSize.x;
        }
        if (pixelCoord.y < spriteSize.y - 56.0) {
            texture_coords.x += direction / spriteSize.x;
        }    
        return Texel(tex, texture_coords) * color;
    }
]])

shader:send("direction", 1.0) 
shader:send("spriteSize", {64.0, 96.0})

local function applyTreeShader(direction, width, height)
    love.graphics.setShader(shader)
    shader:send("direction", direction)
    shader:send("spriteSize", {width, height})
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

local function getFadeAreaConfig()
    return TreeConfig.fadeArea or {}
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

local function drawTreeDebugFadeArea(box)
    if not DEBUG then
        return
    end

    local debugConfig = TreeConfig.debug or {}
    local fillColor = debugConfig.fadeAreaFillColor or {0.25, 0.8, 1, 0.12}
    local lineColor = debugConfig.fadeAreaLineColor or {0.25, 0.8, 1, 0.85}
    local r, g, b, a = love.graphics.getColor()
    local previousLineWidth = love.graphics.getLineWidth()

    love.graphics.setLineWidth(1)
    love.graphics.setColor(fillColor)
    love.graphics.rectangle("fill", box.x, box.y, box.width, box.height)
    love.graphics.setColor(lineColor)
    love.graphics.rectangle("line", box.x, box.y, box.width, box.height)
    love.graphics.setLineWidth(previousLineWidth)
    love.graphics.setColor(r, g, b, a)
end

function TreeTile:new(x, y, quadIndex, collider)
    local tile = Tile.new(self, x, y, quadIndex, collider)

    tile.shaderDirection = 0
    tile.yAdd = 3 + math.random() * 0.25
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

    setmetatable(tile, TreeTile)
    return tile
end

function TreeTile:newBig(x, y, quadIndex, collider)
    local tile = Tile.new(self, x, y, quadIndex, collider)

    tile.shaderDirection = 0
    tile.yAdd = 18 + math.random() * 0.25
    tile.treeIndex = 6
    tile.stretch = 1.4
    tile.alpha = 1
    tile.leafTimer = math.random() * 2

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
    addToDrawQueue(self.yWorld+1 + self.yAdd, self, false)
    self.shaderDirection = math.sin(love.timer.getTime() + (self.yWorld/10)) * 0.45 + 1
    self:updateLeaves(dt)
    --print(self.shaderDirection)
end

function TreeTile:getTargetAlpha(box)
    local fadeArea = getFadeAreaConfig()

    if self.treeIndex == 6 then
        return 1
    end

    if self.treeIndex == 4 or self.treeIndex == 5 then
        return 1
    end

    if not isObjectNearBox(Player, box, fadeArea.playerCalculationPadding or 160) then
        return 1
    end

    local hiddenAlpha = fadeArea.hiddenAlpha or 0

    if Player.isAlive then
        local playerPadding = fadeArea.playerAreaPadding or 0
        if isObjectInsideBox(Player, box, playerPadding) then
            return hiddenAlpha
        end
    end
    
    local enemies = Game.nearbyEnemies or Game.enemies
    if enemies then
        local padding = fadeArea.enemyAreaPadding or 0
        for _, enemy in ipairs(enemies) do
            if enemy.isAlive ~= false and isObjectInsideBox(enemy, box, padding) then
                return hiddenAlpha
            end 
        end
    end
    return 1
end

function TreeTile:drawShadow()
   
end

function TreeTile:draw()

    local tileSet = TileSet:getTileSet()
    local tileSize = TileSet.tileSize
    local tilesetImage = TileSet.tilesetImage

    local image = threeImage1
    local originX = 32
    local originY = 93
    local spriteWidth = 64
    local spriteHeight = 96

    if self.treeIndex == 2 then image = threeImage2 end 
    if self.treeIndex == 3 then image = threeImage3 end
    if self.treeIndex == 4 then image = threeImage4 end
    if self.treeIndex == 5 then image = threeImage5 end
    if self.treeIndex == 6 then
        image = bigThreeImage
        originX = 80
        originY = 156
        spriteWidth = 160
        spriteHeight = 160
    end

    applyTreeShader(self.shaderDirection, spriteWidth, spriteHeight)

    if not self.collider then
        love.graphics.draw(tilesetImage, tileSet[5], self.xWorld, self.yWorld , 0, 1, 1, tileSize/2, tileSize)
    end

    local box = getTreeFadeBox(self, originX, originY, spriteWidth)

    local targetAlpha = self:getTargetAlpha(box)

    self.alpha = self.alpha + (targetAlpha - self.alpha) * 0.1
    
    local r, g, b, a = love.graphics.getColor()
    love.graphics.setColor(r, g, b, self.alpha)
    
    love.graphics.draw(image, self.xWorld, self.yWorld, 0, 1, self.stretch, originX, originY)
    love.graphics.setColor(r, g, b, a) 
    love.graphics.setShader()
    drawTreeDebugFadeArea(box)
    self:drawDebug()    
end

return TreeTile
