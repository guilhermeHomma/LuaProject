TreeTile = setmetatable({}, {__index = Tile})
TreeTile.__index = TreeTile
TileSet = require("scripts.objects.tileset")

local threeImage1 = love.graphics.newImage("assets/sprites/objects/three1.png")
local threeImage2 = love.graphics.newImage("assets/sprites/objects/three2.png")
local threeImage3 = love.graphics.newImage("assets/sprites/objects/three3.png")

threeImage1:setFilter("nearest", "nearest")
threeImage2:setFilter("nearest", "nearest")
threeImage3:setFilter("nearest", "nearest")

function TreeTile:new(x, y, quadIndex, collider)
    local tile = Tile.new(self, x, y, quadIndex, collider)
    setmetatable(tile, TreeTile)
    return tile
end

function TreeTile:draw()

    local tileSet = TileSet:getTileSet()
    local tileSize = TileSet.tileSize
    local tilesetImage = TileSet.tilesetImage

    love.graphics.draw(tilesetImage, tileSet[5], self.xWorld, self.yWorld, 0, 1, 1, tileSize/2, tileSize)
    local targetAlpha = 1
    local image = threeImage1

    if self.quadIndex == 17 then image = threeImage2 end 
    if self.quadIndex == 19 then image = threeImage3 end

    local box = {x = self.xWorld - 20, y = self.yWorld - 100, width = 40, height = 60}
    if checkCollision(box, Player:getCollisionBox()) then 
        targetAlpha = 0.5
    end

    self.alpha = self.alpha + (targetAlpha - self.alpha) * 0.1
    
    love.graphics.setColor(1, 1, 1, self.alpha)
    love.graphics.draw(image, self.xWorld, self.yWorld, 0, 1, 1.6, 32, 93)
    love.graphics.setColor(1, 1, 1)

    self:drawDebug()
end