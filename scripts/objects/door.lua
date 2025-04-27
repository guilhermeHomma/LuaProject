




DoorTile = setmetatable({}, {__index = Tile})
DoorTile.__index = DoorTile

local sheetImage = love.graphics.newImage("assets/sprites/objects/door.png")
sheetImage:setFilter("nearest", "nearest")
local sheetWidth, sheetHeight = sheetImage:getDimensions()
local size = 16
function DoorTile:new(x, y, quadIndex)
    local tile = Tile.new(self, x, y, quadIndex)
    setmetatable(tile, DoorTile)
    tile.frame = 0
    tile:loadQuad()
    return tile
end

function DoorTile:loadQuad()
    self.quad = love.graphics.newQuad(size * self.frame, 0, sheetHeight, sheetHeight, sheetWidth, sheetHeight)

end

function DoorTile:draw()
    if self.quadIndex == 20 or self.quadIndex == 22 then return end
    local size = 16
    love.graphics.draw(sheetImage, self.quad, self.xWorld, self.yWorld - 4, 0, 1 ,1.3, size/2, size)
end


function DoorTile:openDoor()

    self.collider = false
end