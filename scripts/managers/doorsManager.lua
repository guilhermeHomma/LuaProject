
local doorsManager = {}

require "scripts/utils"

local Tilemap = require("scripts/tilemap")

function doorsManager:load()
    self.southOpen = false
    self.northOpen = false

    self.southFrameAnimation = 0
    
    self.southOpening = false 
end

function doorsManager:update(dt)

end

function doorsManager:openTiles()
    local tilemap = Tilemap.getTilemap()
    for _, tile in ipairs(Tilemap.tiles) do
        if tile.quadIndex == 20 or tile.quadIndex == 21 then 
            tile:openDoor()
            tile.frame = self.southFrameAnimation
            tile:loadQuad()
            tilemap[tile.y][tile.x] = 0
        end
    end
    Tilemap:loadfinders()
end

function doorsManager:openSouth()
    self.southFrameAnimation = 7
    doorsManager:openTiles()
    self.southOpen = true
end

return doorsManager