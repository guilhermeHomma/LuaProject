Tile = {}
Tile.__index = Tile
TileSet = require("scripts.objects.tileset")

function Tile:setTilemap(tilemap)
    Tile.tilemap = tilemap
end

function Tile:new(x, y, quadIndex, collider)
    if quadIndex == 14 and math.random() > 0.2 then
        quadIndex = 18
    end

    if collider == nil then collider = true end

    local tile = setmetatable({}, Tile)
    local tileSet = TileSet:getTileSet()
    local tileSize = TileSet.tileSize

    tile.quad = tileSet[quadIndex]
    tile.quadIndex = quadIndex
    tile.x = x
    tile.y = y
    tile.size = tileSize
    tile.alpha = 1
    tile.collider = collider
    tile.xWorld, tile.yWorld = Tile.tilemap:mapToWorld(x,y)
    tile.distance = 0
    return tile
end

function Tile:update(dt) 
    addToDrawQueue(self.yWorld, self)
end


function Tile:draw()
    local tileSet = TileSet:getTileSet()
    local tileSize = TileSet.tileSize
    local tilesetImage = TileSet.tilesetImage

    if self.quadIndex == 14 or self.quadIndex == 18 then --box
        love.graphics.draw(tilesetImage, self.quad, self.xWorld, self.yWorld, 0, 1, 1, tileSize/2, tileSize*2)
    elseif self.quadIndex == 1 or self.quadIndex == 2 or self.quadIndex == 3  then
        love.graphics.draw(tilesetImage, self.quad, self.xWorld, self.yWorld, 0, 1, 1, tileSize/2, tileSize+10)
    else
       love.graphics.draw(tilesetImage, self.quad, self.xWorld, self.yWorld, 0, 1, 1, tileSize/2, tileSize)
    end

    self:drawDebug()
end

function Tile:drawDebug()
    if self.collider and DEBUG then
        playerX, playerY = Tile.tilemap:worldToMap(Player.x, Player.y)
        if playerX == self.x and playerY == self.y then
            love.graphics.setColor(1, 0.5, 0.5, 1)
        end
        love.graphics.rectangle("line", self.xWorld-8, self.yWorld-16, 16, 16)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

function Tile:drawShadow()
    if self.quadIndex == 5 or self.quadIndex == 15 then 
        return
    end

    local tileSet = TileSet:getTileSet()
    local tileSize = TileSet.tileSize
    local tilesetImage = TileSet.tilesetImage
    local sheetWidth = TileSet.sheetWidth
    local sheetHeight = TileSet.sheetHeight
    local shadowSize = 20
    local quadShadow = love.graphics.newQuad(110, 14, shadowSize, shadowSize, sheetWidth, sheetHeight)

    love.graphics.draw(tilesetImage, quadShadow, self.xWorld, self.yWorld, 0, 1, 1, shadowSize/2, shadowSize-4)
end


return Tile