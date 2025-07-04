DoorTile = setmetatable({}, {__index = Tile})
DoorTile.__index = DoorTile

local sheetImage = love.graphics.newImage("assets/sprites/objects/door.png")
sheetImage:setFilter("nearest", "nearest")
local sheetWidth, sheetHeight = sheetImage:getDimensions()
local size = 16


function DoorTile:new(x, y, quadIndex, collider)
    local tile = Tile.new(self, x, y, quadIndex, collider)
    setmetatable(tile, DoorTile)
    tile.frame = 0
    tile:loadQuad()
    
    return tile
end

function DoorTile:loadQuad()
    self.quad = love.graphics.newQuad(size * self.frame, 0, sheetHeight, sheetHeight, sheetWidth, sheetHeight)
end

function DoorTile:drawOutline()
    if self.quadIndex == 20 or self.quadIndex == 22 or not self.collider then return end
    
    --love.graphics.rectangle("fill", self.xWorld-8, self.yWorld-22 - 4, 16, 24)
    
end

function DoorTile:performBuy()
    if self.quadIndex ~= 21 and self.quadIndex ~= 23 then return end

    if distance(Player, {x = self.xWorld, y = self.yWorld - 7}) > 25 then return end

    if WaveManager.wave >= WaveManager.openNorthWave and self.quadIndex == 23 then
        Game:openNorth()
    end

    if WaveManager.wave >= WaveManager.openSouthWave and self.quadIndex == 21 then
        Game:openSouth()
    end
end


function DoorTile:update(dt)
    if self.quadIndex == 20 or self.quadIndex == 22 or not self.collider then return end

    addToDrawQueue(self.yWorld, self)

    if Player.isAlive then
        if distance(Player, {x = self.xWorld, y = self.yWorld - 7}) < 25 then 
            local DoorManager = require("scripts.managers.doorsManager")
            if self.quadIndex == 23 then
                Game.drawtext = DoorManager:getNorthText()
            else
                Game.drawtext = DoorManager:getSouthText()
            end
            Game.textAlphaTarget = 1
        end
    end
end

function DoorTile:draw()
    if self.quadIndex == 20 or self.quadIndex == 22 or not self.collider then return end
    local size = 16
    
    
    
    love.graphics.draw(sheetImage, self.quad, self.xWorld, self.yWorld - 4, 0, 1 ,1.3, size/2, size)
    self:drawDebug()
end


function DoorTile:openDoor()

    self.collider = false
end

function DoorTile:drawShadow()
    if self.quadIndex == 20 or self.quadIndex == 22 or not self.collider then 
        return
    end
    --Tile.drawShadow(self)

    local tileSet = TileSet:getTileSet()
    local tileSize = TileSet.tileSize
    local tilesetImage = TileSet.tilesetImage
    local sheetWidth = TileSet.sheetWidth
    local sheetHeight = TileSet.sheetHeight
    local shadowSize = 20
    local quadShadow = love.graphics.newQuad(110, 14, shadowSize, shadowSize/2, sheetWidth, sheetHeight)
    love.graphics.draw(tilesetImage, quadShadow, self.xWorld, self.yWorld + 5, 0, 1, 1, shadowSize/2, shadowSize-4)
    
end