local DoorsManager = {}
require "scripts/utils"

local Tilemap = require("scripts/tilemap")

local southTiles = {20, 21}
local northTiles = {22, 23}

function DoorsManager:load()
    self.southOpen = false
    self.northOpen = false

    self.southFrameAnimation = 0
    self.northFrameAnimation = 0
    
    self.southOpening = false 
    self.northOpening = false 
end

function DoorsManager:update(dt)
    self:updateDoor("south", southTiles, dt)
    self:updateDoor("north", northTiles, dt)
end

function DoorsManager:getSouthText()
    if self.southOpening or self.southOpen then 
        return ""
    end

    if WaveManager.wave >= WaveManager.openSouthWave then
        return "Click X to open this passage"
    end

    local waveNumber = tostring(WaveManager.openSouthWave)

    return "You need to reach wave " .. waveNumber .. " to open this passage"
end

function DoorsManager:getNorthText()
    if self.northOpening or self.northOpen then 
        return ""
    end

    if WaveManager.wave >= WaveManager.openNorthWave then
        return "Click X to open this passage"
    end

    return "You need to reach wave " .. WaveManager.openNorthWave .. " to open this passage"
end


function DoorsManager:updateDoor(direction, tileIndices, dt)
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


function DoorsManager:openTiles(tileIndices)
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

function DoorsManager:openSouth()
    if self.southOpening or self.southOpen then return end

    self.southFrameAnimation = 0
    self.southOpening = true

    self:openSound()
end

function DoorsManager:openSound()
    local sound = love.audio.newSource("assets/sfx/ambience/opendoor.mp3", "static")
    sound:setVolume(1)
    sound:setPitch((0.95 + math.random() * 0.1) * GAME_PITCH)
    sound:play()
end

function DoorsManager:openNorth()
    if self.northOpening or self.northOpen then return end

    self.northFrameAnimation = 0
    self.northOpening = true

    self:openSound()
end


return DoorsManager