HouseTile = setmetatable({}, {__index = Tile})
HouseTile.__index = HouseTile
TileSet = require("scripts.objects.tileset")

local sprite = love.graphics.newImage("assets/sprites/objects/house.png")
local spriteWidth, spriteHeight = sprite:getDimensions()

sprite:setFilter("nearest", "nearest")

function HouseTile:new(x, y, quadIndex, collider)
    local tile = Tile.new(self, x, y, quadIndex, collider)
    setmetatable(tile, HouseTile)
    return tile
end

function HouseTile:update(dt)
    addToDrawQueue(self.yWorld + 17, self)
end

function HouseTile:drawShadow()
   
end

function HouseTile:draw()
    local tileSet = TileSet:getTileSet()
    local tileSize = TileSet.tileSize
    local tilesetImage = TileSet.tilesetImage
    love.graphics.draw(tilesetImage, tileSet[5], self.xWorld, self.yWorld + 1, 0, 1, 1, tileSize/2, tileSize)

    love.graphics.draw(sprite, self.xWorld, self.yWorld , 0, 1, 1.5, spriteWidth/2, spriteHeight)
end

return HouseTile