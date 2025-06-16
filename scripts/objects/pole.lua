Pole = setmetatable({}, {__index = Tile})
Pole.__index = Pole
TileSet = require("scripts.objects.tileset")

local sprite = love.graphics.newImage("assets/sprites/objects/pole.png")
local spriteWidth, spriteHeight = sprite:getDimensions()

sprite:setFilter("nearest", "nearest")

function Pole:new(x, y, quadIndex, collider)
    local tile = Tile.new(self, x, y, quadIndex, collider)
    setmetatable(tile, Pole)
    return tile
end

function Pole:update(dt)
    addToDrawQueue(self.yWorld + 2, self)
end

function Pole:drawShadow()
   
end

function Pole:draw()
    local tileSet = TileSet:getTileSet()
    local tileSize = TileSet.tileSize
    local tilesetImage = TileSet.tilesetImage
    if not self.collider then
        love.graphics.draw(tilesetImage, tileSet[5], self.xWorld, self.yWorld + 1, 0, 1, 1, tileSize/2, tileSize)
    end
    love.graphics.draw(sprite, self.xWorld, self.yWorld, 0, 1, 1.5, spriteWidth/2, spriteHeight)
end

return Pole