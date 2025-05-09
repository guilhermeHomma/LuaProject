local Tilemap = {}
local tileSize = 16

require "scripts.utils"
require "scripts.objects.tile"
require "scripts.objects.door"
require "scripts.objects.tree"

tileSet = require("scripts.objects.tileset")

local tilemapWorldX = -40 * tileSize
local tilemapWorldY = -40 * tileSize

local Grid = require("jumper.grid")
local Pathfinder = require("jumper.pathfinder")

function loadTilemapFromImage()
    local imageData = love.image.newImageData("assets/sprites/map3.png")
    local width, height = imageData:getDimensions()
    local tilemap = {}

    for y = 1, height do
        tilemap[y] = {}
        for x = 1, width do
            local r, g, b, a = imageData:getPixel(x - 1, y - 1) -- pixel color
            local found = false

            local tileDefinitions = {
                {r = 1,   g = 1,   b = 1,   tile = 1}, -- White wall
                {r = 0,   g = 0,   b = 0,   tile = 0}, -- black defaultground
                {r = 1,   g = 0,   b = 0,   tile = 2}, -- Red box
                {r = 0,   g = 1,   b = 0,   tile = 3}, -- Green tree
                {r = 1,   g = 1,   b = 0,   tile = 4}, -- Yellow grass
                {r = 0,   g = 0,   b = 1,   tile = 5}, -- Blue door south
                {r = 1,   g = 0,   b = 1,   tile = 6}, -- Pink door north
            }

            for _, def in ipairs(tileDefinitions) do
                if isColorMatch(r, g, b, def) then
                    tilemap[y][x] = def.tile
                    found = true
                    break
                end
            end
    
            if not found then
                tilemap[y][x] = 0 -- Vazio
            end
    
        end
    end

    return tilemap
end

local tilemap = loadTilemapFromImage()

function Tilemap:getTilemap()
    return tilemap
end

function Tilemap:mapToWorld(x,y)

    local xWorld = tilemapWorldX + (x - 1) * tileSize
    local yWorld = tilemapWorldY + (y - 1) * tileSize
    return xWorld, yWorld + tileSize/2
end

function Tilemap:worldToMap(x, y)
    local xMap = math.floor((x - tilemapWorldX) / tileSize + 0.5 ) + 1
    local yMap = math.floor((y - tilemapWorldY) / tileSize + 0.5) + 1
    return xMap, yMap
end

function Tilemap:hasTileClose(x, y, tileIndex)
    if x -1  <= 1 or y - 1 <= 1 then return false end
    
    if y + 1 > #tilemap then return false end

    if x + 1 > #tilemap[y] then return false end
 
    return 
        tilemap[y][x + 1] == tileIndex or
        tilemap[y][x - 1] == tileIndex or
        tilemap[y + 1][x] == tileIndex or
        tilemap[y - 1][x] == tileIndex
end

local function isNotSolid(y, x)
    local v = tilemap[y] and tilemap[y][x]
    return v ~= 1 and v ~= 3
end

local function isSolid(y, x)
    local v = tilemap[y] and tilemap[y][x]
    return v == 1 or v == 3
end

function Tilemap:autoTile(x, y)
    if x == 1 or y == 1 or x == #tilemap[y] or y == #tilemap then 
        return 5
    end

    local top = isNotSolid(y - 1, x)
    local bottom = isNotSolid(y + 1, x)
    local left = isNotSolid(y, x - 1)
    local right = isNotSolid(y, x + 1)
    
    local topLeft = isNotSolid(y - 1, x - 1)
    local topRight = isNotSolid(y - 1, x + 1)
    local bottomLeft = isNotSolid(y + 1, x - 1)
    local bottomRight = isNotSolid(y + 1, x + 1)

    local leftNoBottom = left and isSolid(y+1, x-1)
    local rightNoBottom = right and isSolid(y+1, x+1)

    if top and left then return 1 end
    if top and right then return 3 end
    if bottom and left then return 7 end
    if bottom and right then return 9 end

    if leftNoBottom then return 13 end
    if rightNoBottom then return 12 end

    if top then return 2 end
    if bottom then return 8 end
    if left then return 4 end
    if right then return 6 end

    if topLeft then return 5 end --13
    if topRight then return 5 end --12
    if bottomLeft then return 11 end
    if bottomRight then return 10 end

    return 5

end


function Tilemap:loadfinders()
    self.sharedGrid = Grid(tilemap)

    self.finder = Pathfinder(self.sharedGrid, 'JPS', 0)
    self.finderAstar = Pathfinder(self.sharedGrid, 'ASTAR', 0)
    self.finder:setMode("DIAGONAL") -- ORTHOGONAL
    self.finderAstar:setMode("DIAGONAL")


end

function Tilemap:load()
    tilemap = loadTilemapFromImage()
    tileSet:createTileSet()
    Tile:setTilemap(self)
    self:loadfinders()

    self.tiles = {}
    for y = 1, #tilemap do
        for x = 1, #tilemap[y] do
            local tile = tilemap[y][x]
            local collider = false
            if self:hasTileClose(x, y, 0) or 
                self:hasTileClose(x, y, 5) or 
                self:hasTileClose(x, y, 6) then 
                collider = true
            end       

            if tile == 3 then -- three
                local indexes = {16, 17, 19}
                local t = TreeTile:new(x, y, indexes[math.random(#indexes)], collider)
                table.insert(self.tiles, t)

            elseif tile == 5 or tile == 6 then --door
                local index = 20
                
                if tile == 6 then index = 22 end

                if self:hasTileClose(x, y, 0) then index = index + 1 end

                local t = DoorTile:new(x, y, index, collider)
                table.insert(self.tiles, t)

            elseif tile > 0 then --tileset
                local index = 5

                if tile == 1 then 
                    index = self:autoTile(x, y)
                elseif tile == 2 then
                    index = 14
                end

                if index == 5 and math.random(15) == 1 then
                    index = 15
                end

                local t = Tile:new(x, y, index, collider)
                table.insert(self.tiles, t)
                
            end
        end
    end
end

function Tilemap:update()
    for _, tile in ipairs(self.tiles) do
        if tile.quadIndex == 16 or tile.quadIndex == 17 or tile.quadIndex == 19 then
            addToDrawQueue(tile.yWorld+1, tile)

        else
            addToDrawQueue(tile.yWorld, tile)
        end
    end
end


return Tilemap