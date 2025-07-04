local Tilemap = {}
local tileSize = 16

require "scripts.utils"
require "scripts.objects.tile"
require "scripts.objects.door"
require "scripts.objects.store"
require "scripts.objects.water"
require "scripts.objects.tree"
require "scripts.objects.grass"
require "scripts.objects.house"
require "scripts.objects.pole"
require "scripts.objects.counter"
require "scripts.objects.container"

tileSet = require("scripts.objects.tileset")

local tilemapWorldX = -40 * tileSize
local tilemapWorldY = -40 * tileSize

local Grid = require("jumperj.grid")
local Pathfinder = require("jumperj.pathfinder")
local tilemap = nil

function loadTilemapFromImage()
    --map3 é o melhor
    local imageData = love.image.newImageData("assets/sprites/map4.png")
    local width, height = imageData:getDimensions()
    local tilemapLoad = {}

    for y = 1, height do
        tilemapLoad[y] = {}
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

                {r = 0.5,   g = 1,   b = 1,   tile = 7}, -- store - shotgun
                {r = 0,   g = 0.5,   b = 1,   tile = 8}, -- water
                {r = 0.5,   g = 0.5,   b = 0.5,   tile = 9}, -- sand

                {r = 0.5,   g = 0.5,   b = 0,   tile = 10}, -- house                
                {r = 0,   g = 0.5,   b = 0.5,   tile = 11}, -- pole                
                {r = 1,   g = 0.5,   b = 0.5,   tile = 12}, -- counter                
                {r = 0.5,   g = 0,   b = 1,   tile = 13}, -- container                
            }

            for _, def in ipairs(tileDefinitions) do
                if isColorMatch(r, g, b, def) then
                    tilemapLoad[y][x] = def.tile
                    found = true
                    break
                end
            end
    
            if not found then
                tilemapLoad[y][x] = 0 -- Vazio
            end
    
        end
    end

    return tilemapLoad
end

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
    self.grass = {}
    self.tiles = {}
    
    local itemStoreList = {1, 2, 3, 4}

    for y = 1, #tilemap do
        for x = 1, #tilemap[y] do
            local tile = tilemap[y][x]
            local collider = false
            if self:hasTileClose(x, y, 0) or 
                self:hasTileClose(x, y, 5) or 
                self:hasTileClose(x, y, 8) or 
                self:hasTileClose(x, y, 4) or 
                self:hasTileClose(x, y, 9) or 
                self:hasTileClose(x, y, 2) or 
                self:hasTileClose(x, y, 11) or 
                self:hasTileClose(x, y, 6) then 
                collider = true
            end 

            if (tile == 0 or tile == 5 or tile == 6 or tile == 9 or (tile == 1 and not collider )) and math.random() > 0.45 then
                local gx, gy = self:mapToWorld(x,y)
                local grass = Grass:new(gx, gy - 5, tile)
                table.insert(self.grass, grass)
                if math.random() > 0.3 then
                    local gx, gy = self:mapToWorld(x,y)
                    local grass = Grass:new(gx + 1, gy +2, tile )
                    table.insert(self.grass, grass)
                end
            end
            
            if tile == 8 then 
                local c = self:hasTileClose(x, y, 0) or self:hasTileClose(x, y, 5) or self:hasTileClose(x, y, 6) or self:hasTileClose(x, y, 2)
                index = autoTileWater(x, y, tilemap)
                local t = Water:new(x, y, index, c)
                table.insert(self.tiles, t)
            elseif tile == 9 then
            elseif tile == 13 then --container
                local mustDraw = false
                if tilemap[y-1][x] ~= 13 and tilemap[y][x-1] ~= 13 then
                    mustDraw = true
                end

                local t = Container:new(x, y, 30, true, mustDraw)
                table.insert(self.tiles, t)
            elseif tile == 12 then --car
                local t = Counter:new(x, y, 30, collider)
                table.insert(self.tiles, t)
            elseif tile == 11 then --pole
                local t = Pole:new(x, y, 30, collider)
                table.insert(self.tiles, t)
            elseif tile == 10 then --house

                local t = HouseTile:new(x, y, 30, collider)
                table.insert(self.tiles, t)

            elseif tile == 3 then -- three
                local t = TreeTile:new(x, y, tile, collider)
                table.insert(self.tiles, t)
            
            elseif tile == 7 then --store
                local index = 24

                local t = Store:new(x, y, index, collider, #itemStoreList)
                table.remove(itemStoreList, #itemStoreList)
                table.insert(self.tiles, t)

            elseif tile == 5 or tile == 6 then --door
                local index = 20
                
                if tile == 6 then index = 22 end

                if self:hasTileClose(x, y, 0) and index == 22 then index = index + 1 end
                if self:hasTileClose(x, y, 6) and index == 20 then index = index + 1 end

                local t = DoorTile:new(x, y, index, collider)
                table.insert(self.tiles, t)

            elseif tile > 0 then --tileset
                local index = 5

                if tile == 1 then 
                    index = autoTile(x, y, tilemap)
                elseif tile == 2 then
                    index = 14
                end

                if index == 5 and math.random(10) == 1 then
                    index = 15
                end

                local t = Tile:new(x, y, index, collider)
                table.insert(self.tiles, t)
                
            end
        end
    end
end

function Tilemap:update(dt)
    for _, g in ipairs(self.grass) do
        g:update(dt)
    end

    for _, tile in ipairs(self.tiles) do
        if tile.isAlive then
            tile:update(dt) 
        else
            --table.remove(self.tiles, _)
        end

    end
end

function Tilemap:keypressed(key)
    for _, tile in ipairs(self.tiles) do
        if type(tile.performBuy) == "function" then
            tile:performBuy()
        end
    end
end


return Tilemap