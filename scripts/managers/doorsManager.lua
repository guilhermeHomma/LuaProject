
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
    if self.southOpening then
        self.southFrameAnimation = self.southFrameAnimation + 15 * dt -- velocidade da animação (10 fps)

        for _, tile in ipairs(Tilemap.tiles) do
            if tile.quadIndex == 20 or tile.quadIndex == 21 then
                tile.frame = math.floor(self.southFrameAnimation)
                tile:loadQuad()
            end
        end

        if self.southFrameAnimation >= 7 then
            self.southFrameAnimation = 7
            self.southOpening = false
            self:openTiles()
            self.southOpen = true
        end
    end
end

function doorsManager:openTiles()
    local tilemap = Tilemap.getTilemap()
    for _, tile in ipairs(Tilemap.tiles) do
        if tile.quadIndex == 20 or tile.quadIndex == 21 then 
            tile:openDoor()
            tilemap[tile.y][tile.x] = 0
        end
    end
    Tilemap:loadfinders()
end

function doorsManager:openSouth()
    self.southFrameAnimation = 0
    self.southOpening = true
end

return doorsManager