Container = setmetatable({}, {__index = Tile})
Container.__index = Container
TileSet = require("scripts.objects.tileset")

local sprite = love.graphics.newImage("assets/sprites/objects/container/container.png")
local spriteWidth, spriteHeight = sprite:getDimensions()

sprite:setFilter("nearest", "nearest")

function Container:new(x, y, quadIndex, collider, draw)
    local tile = Tile.new(self, x, y, quadIndex, collider)
    setmetatable(tile, Container)
    tile.mustDraw = draw
    return tile
end

function Container:update(dt)

    addToDrawQueue(self.yWorld + 2, self)
end

function Container:drawShadow()
   
end

function Container:draw()
    if self.mustDraw then
        love.graphics.draw(sprite, self.xWorld- 10, self.yWorld - 45)
        
    end
    self:drawDebug()
end

return Container