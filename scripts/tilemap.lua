local Tilemap = {}
local tileSize = 16
local tilesetImage
local tileSet = {}

require "scripts.utils"
require "scripts.objects.door"

local tilesetImage = love.graphics.newImage("assets/sprites/tileset.png")
local threeImage1 = love.graphics.newImage("assets/sprites/objects/three1.png")
local threeImage2 = love.graphics.newImage("assets/sprites/objects/three2.png")
local threeImage3 = love.graphics.newImage("assets/sprites/objects/three3.png")

threeImage1:setFilter("nearest", "nearest")
threeImage2:setFilter("nearest", "nearest")
threeImage3:setFilter("nearest", "nearest")
tilesetImage:setFilter("nearest", "nearest")
local sheetWidth, sheetHeight = tilesetImage:getDimensions()
local tilemapWorldX = -40 * tileSize
local tilemapWorldY = -40 * tileSize

local Grid = require("jumper.grid")
local Pathfinder = require("jumper.pathfinder")

function loadTilemapFromImage()
    local imageData = love.image.newImageData("assets/sprites/map-closed.png")
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

Tile = {}
Tile.__index = Tile

function Tile:new(x, y, quadIndex, collider)
    if quadIndex == 14 and math.random() > 0.2 then
        quadIndex = 18
    end

    if collider == nil then collider = true end

    local tile = setmetatable({}, Tile)
    tile.quad = tileSet[quadIndex]
    tile.quadIndex = quadIndex
    tile.x = x
    tile.y = y
    tile.size = tileSize
    tile.alpha = 1
    tile.collider = collider

    tile.xWorld, tile.yWorld = Tilemap:mapToWorld(x,y)
    return tile
end

function Tile:draw()
    
    --love.graphics.rectangle("fill", self.xWorld, self.yWorld, tileSize, tileSize)
    if self.quadIndex == 14 or self.quadIndex == 18 then
        love.graphics.draw(tilesetImage, self.quad, self.xWorld, self.yWorld, 0, 1, 1, tileSize/2, tileSize*2)

    elseif self.quadIndex == 16 or self.quadIndex == 17 or self.quadIndex == 19 then
        love.graphics.draw(tilesetImage, tileSet[5], self.xWorld, self.yWorld, 0, 1, 1, tileSize/2, tileSize)
        local targetAlpha = 1
        local image = threeImage1
        if self.quadIndex == 17 then image = threeImage2 end 
        if self.quadIndex == 19 then image = threeImage3 end 
        local box = {x = self.xWorld - 20, y = self.yWorld - 100, width = 40, height = 60}
        if checkCollision(box, Player:getCollisionBox()) then 
            targetAlpha = 0.5
            
        end
        self.alpha = self.alpha + (targetAlpha - self.alpha) * 0.1
        love.graphics.setColor(1, 1, 1, self.alpha)
        love.graphics.draw(image, self.xWorld, self.yWorld, 0, 1, 1.6, 32, 93)
        love.graphics.setColor(1, 1, 1)


    elseif self.quadIndex == 1 or self.quadIndex == 2 or self.quadIndex == 3  then
        love.graphics.draw(tilesetImage, self.quad, self.xWorld, self.yWorld, 0, 1, 1, tileSize/2, tileSize+10)

    else
        love.graphics.draw(tilesetImage, self.quad, self.xWorld, self.yWorld, 0, 1, 1, tileSize/2, tileSize)
        
    end
    
    if self.collider ~= 15 and DEBUG then

        playerX, playerY = Tilemap:worldToMap(Player.x, Player.y)
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

    local shadowSize = 20
    local quadShadow = love.graphics.newQuad(110, 14, shadowSize, shadowSize, sheetWidth, sheetHeight)
    love.graphics.draw(tilesetImage, quadShadow, self.xWorld, self.yWorld, 0, 1, 1, shadowSize/2, shadowSize-4)

end

function Tilemap:getTilemap()

    return tilemap
end

function Tilemap:mapToWorld(x,y)

    local xWorld = tilemapWorldX + (x - 1) * tileSize
    local yWorld = tilemapWorldY + (y - 1) * tileSize
    --return xWorld, yWorld- tileSize/2
    return xWorld, yWorld + tileSize/2
end

function Tilemap:worldToMap(x, y)
    local xMap = math.floor((x - tilemapWorldX) / tileSize + 0.5 ) + 1
    local yMap = math.floor((y - tilemapWorldY) / tileSize + 0.5) + 1
    return xMap, yMap
end

function Tilemap:hasTileClose(x, y, tileIndex)

    return 
        tilemap[y][x + 1] == tileIndex or
        tilemap[y][x - 1] == tileIndex or
        tilemap[y + 1][x] == tileIndex or
        tilemap[y - 1][x] == tileIndex
end

function Tilemap:createTileSet()
    for x = 1, 3 do
        for y = 1, 3 do
            local tileX = (x - 1) * tileSize 
            local tileY = (y - 1) * tileSize + 16

            local index = (y - 1) * 3 + x

            if y == 1 then 
                tileSet[index] = love.graphics.newQuad(tileX, tileY-10, tileSize, tileSize+10, sheetWidth, sheetHeight)
            else
                tileSet[index] = love.graphics.newQuad(tileX, tileY, tileSize, tileSize, sheetWidth, sheetHeight)
            end
        end
    end

    tileSet[10] = love.graphics.newQuad(48 + 16, 0, tileSize, tileSize, sheetWidth, sheetHeight)
    tileSet[11] = love.graphics.newQuad(64 + 16, 0, tileSize, tileSize, sheetWidth, sheetHeight)
    tileSet[12] = love.graphics.newQuad(48 + 16, 16, tileSize, tileSize, sheetWidth, sheetHeight)
    tileSet[13] = love.graphics.newQuad(64 + 16, 16, tileSize, tileSize, sheetWidth, sheetHeight)

    tileSet[14] = love.graphics.newQuad(16, 64, tileSize, tileSize*2, sheetWidth, sheetHeight) --caixa
    tileSet[15] = love.graphics.newQuad(64, 32, tileSize, tileSize, sheetWidth, sheetHeight) --variacao grama

    tileSet[18] = love.graphics.newQuad(48, 64, tileSize, tileSize*2, sheetWidth, sheetHeight) --varia caixa


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
    self.finder:setMode("DIAGONAL")
    self.finderAstar:setMode("ORTHOGONAL")
end

function Tilemap:load()
    tilemap = loadTilemapFromImage()
    self:createTileSet()
    self:loadfinders()
    
    self.tiles = {}
    for y = 1, #tilemap do
        for x = 1, #tilemap[y] do
            local tile = tilemap[y][x]

            if tile == 3 then -- three
                local indexes = {16, 17, 19}
                local t = Tile:new(x, y, indexes[math.random(#indexes)])
                
                table.insert(self.tiles, t)

            elseif tile == 5 or tile == 6 then 
                local index = 20
                local collider = false
                if tile == 6 then index = 22 end

                if self:hasTileClose(x, y, 0) then 
                    index = index + 1 
                    collider = true
                end

                local t = DoorTile:new(x, y, index, collider)
                table.insert(self.tiles, t)

            elseif tileSet[tile] then
                local index = 5
                local collider = false

                if tile == 1 then 
                    index = self:autoTile(x, y)
                    collider = true
                elseif tile == 2 then
                    index = 14
                    collider = true
                end

                if index == 5 and math.random(15) == 1 then
                    index = 15
                    collider = false
                end

                local t = Tile:new(x, y, index)
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