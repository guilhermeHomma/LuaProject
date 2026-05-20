local FloorPath = {}
FloorPath.__index = FloorPath

local TileSet = require("scripts.objects.tileset")

function FloorPath:new(xWorld, yWorld, quadIndex)
    local path = setmetatable({}, FloorPath)
    path.xWorld = xWorld
    path.yWorld = yWorld
    path.x = xWorld
    path.y = yWorld
    path.quadIndex = quadIndex
    path.isAlive = true
    path.isGroundLayer = true
    return path
end

function FloorPath:update()
    addToDrawQueue(self.yWorld - 80, self, false)
end

function FloorPath:drawShadow()
end

function FloorPath:draw()
    local tileSet = TileSet:getTileSet()
    local quad = tileSet[self.quadIndex]
    if not quad then
        return
    end

    love.graphics.draw(TileSet.tilesetImage, quad, self.xWorld, self.yWorld, 0, 1, 1, TileSet.tileSize / 2, TileSet.tileSize)
end

return FloorPath
