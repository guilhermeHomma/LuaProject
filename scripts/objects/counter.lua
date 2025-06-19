Counter = setmetatable({}, {__index = Tile})
Counter.__index = Counter
TileSet = require("scripts.objects.tileset")

local sprite = love.graphics.newImage("assets/sprites/objects/counter.png")
local spriteWidth, spriteHeight = sprite:getDimensions()

local font = love.graphics.newFont("assets/fonts/pixelart.ttf", 8)

sprite:setFilter("nearest", "nearest")

function Counter:new(x, y, quadIndex, collider)
    local tile = Tile.new(self, x, y, quadIndex, collider)
    setmetatable(tile, Counter)
    return tile
end

function Counter:update(dt)
    addToDrawQueue(self.yWorld + 2, self)
end

function Counter:drawShadow()
   
end

function Counter:draw()
    local tileSet = TileSet:getTileSet()
    local tileSize = TileSet.tileSize
    local tilesetImage = TileSet.tilesetImage
    if not self.collider then
        love.graphics.draw(tilesetImage, tileSet[5], self.xWorld, self.yWorld, 0, 1, 1, tileSize/2, tileSize)
    end
    love.graphics.draw(sprite, self.xWorld, self.yWorld, 0, 1, 1.3, spriteWidth/2, spriteHeight)
end

return Counter