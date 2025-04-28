
local doorsManager = {}

require "scripts/utils"

local Tilemap = require("scripts/tilemap")

local southTiles = {20, 21}
local northTiles = {22, 23}

function doorsManager:load()
    self.southOpen = false
    self.northOpen = false

    self.southFrameAnimation = 0
    self.northFrameAnimation = 0
    
    self.southOpening = false 
    self.northOpening = false 
end

function doorsManager:update(dt)
    self:updateDoor("south", southTiles, dt)
    self:updateDoor("north", northTiles, dt)
end

function doorsManager:updateDoor(direction, tileIndices, dt)
    local openingKey = direction .. "Opening"
    local frameKey = direction .. "FrameAnimation"
    local openKey = direction .. "Open"

    if not self[openingKey] then
        return
    end
    

    self[frameKey] = self[frameKey] + 15 * dt

    for _, tile in ipairs(Tilemap.tiles) do
        for _, index in ipairs(tileIndices) do
            if tile.quadIndex == index then
                tile.frame = math.floor(self[frameKey])
                tile:loadQuad()
            end
        end
    end

    if self[frameKey] >= 7 then
        self[frameKey] = 7
        self[openingKey] = false
        self:openTiles(tileIndices)
        self[openKey] = true
    end
end


function doorsManager:openTiles(tileIndices)
    local tilemap = Tilemap.getTilemap()
    for _, tile in ipairs(Tilemap.tiles) do
        for _, index in ipairs(tileIndices) do
            if tile.quadIndex == index then
                tile:openDoor()
                tilemap[tile.y][tile.x] = 0
            end
        end
    end
    Tilemap:loadfinders()
end

function doorsManager:openSouth()
    self.southFrameAnimation = 0
    self.southOpening = true
end

function doorsManager:openNorth()
    self.northFrameAnimation = 0
    self.northOpening = true
end


return doorsManager