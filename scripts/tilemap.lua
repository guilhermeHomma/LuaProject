local Tilemap = {}
local tileSize = 16
local tilesetImage
local tileSet = {}

local tilesetImage = love.graphics.newImage("assets/sprites/tileset.png")
tilesetImage:setFilter("nearest", "nearest")
local sheetWidth, sheetHeight = tilesetImage:getDimensions()
local tilemapWorldX = -40 * tileSize
local tilemapWorldY = -40 * tileSize



function loadTilemapFromImage()
    local imageData = love.image.newImageData("assets/sprites/map.png")
    local width, height = imageData:getDimensions()
    local tilemap = {}

    for y = 1, height do
        tilemap[y] = {}
        for x = 1, width do
            local r, g, b, a = imageData:getPixel(x - 1, y - 1) -- Pega a cor do pixel

            -- Se for branco (255, 255, 255) -> tile sólido (1), senão vazio (0)
            if r == 1 and g == 1 and b == 1 then  
                tilemap[y][x] = 1
            else
                tilemap[y][x] = 0
            end
        end
    end

    return tilemap
end

local tilemap = loadTilemapFromImage()

Tile = {}
Tile.__index = Tile

function Tile:new(x, y, quadIndex)
    local tile = setmetatable({}, Tile)
    tile.quad = tileSet[quadIndex]
    tile.quadIndex = quadIndex
    tile.x = x
    tile.y = y
    tile.size = tileSize
    tile.xWorld = tilemapWorldX + (x - 1) * tileSize
    tile.yWorld = tilemapWorldY + (y - 1) * tileSize
    return tile
end

function Tile:draw()
    
    --love.graphics.rectangle("fill", self.xWorld, self.yWorld, tileSize, tileSize)
    love.graphics.draw(tilesetImage, self.quad, self.xWorld, self.yWorld, 0, 1, 1, tileSize/2, tileSize)
    
    if self.quadIndex ~= 5 and showCollision then
        love.graphics.rectangle("line", self.xWorld-8, self.yWorld-16, 16, 16)
    end
end

function Tile:drawShadow()
    if self.quadIndex == 5 then 
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
    --if y > #tilemap or y < 1 then return 0, 0 end
    --if x > #tilemap[y] or x < 1 then return 0, 0 end

    local xWorld = tilemapWorldX + (x - 1) * tileSize
    local yWorld = tilemapWorldY + (y - 1) * tileSize
    return xWorld, yWorld- tileSize/2
end

function Tilemap:createTileSet()
    for x = 1, 3 do
        for y = 1, 3 do
            local tileX = (x - 1) * 16
            local tileY = (y - 1) * 16

            local index = (y - 1) * 3 + x
            tileSet[index] = love.graphics.newQuad(tileX, tileY, tileSize, tileSize, sheetWidth, sheetHeight)
        end
    end

    tileSet[10] = love.graphics.newQuad(48 + 16, 0, tileSize, tileSize, sheetWidth, sheetHeight)
    tileSet[11] = love.graphics.newQuad(64 + 16, 0, tileSize, tileSize, sheetWidth, sheetHeight)
    tileSet[12] = love.graphics.newQuad(48 + 16, 16, tileSize, tileSize, sheetWidth, sheetHeight)
    tileSet[13] = love.graphics.newQuad(64 + 16, 16, tileSize, tileSize, sheetWidth, sheetHeight)


end

function Tilemap:autoTile(x, y)
    if x == 1 or y == 1 or x == #tilemap[y] or y == #tilemap then 
        return 5
    end

    local top = tilemap[y - 1][x] ~= 1
    local bottom = tilemap[y + 1][x] ~= 1
    local left = tilemap[y][x - 1] ~= 1
    local right = tilemap[y][x + 1] ~= 1

    local topLeft = tilemap[y - 1][x - 1] ~= 1
    local topRight = tilemap[y - 1][x + 1] ~= 1
    local bottomLeft = tilemap[y + 1][x - 1] ~= 1
    local bottomRight = tilemap[y + 1][x + 1] ~= 1

    if top and left then return 1 end
    if top and right then return 3 end
    if bottom and left then return 7 end
    if bottom and right then return 9 end

    if top then return 2 end
    if bottom then return 8 end
    if left then return 4 end
    if right then return 6 end

    if topLeft then return 13 end
    if topRight then return 12 end
    if bottomLeft then return 11 end
    if bottomRight then return 10 end

    return 5

end

function Tilemap:load()
    self:createTileSet()
    self.tiles = {}
    for y = 1, #tilemap do
        for x = 1, #tilemap[y] do
            local tile = tilemap[y][x]
            if tileSet[tile] then
                
                local t = Tile:new(x, y, self:autoTile(x, y))
                table.insert(self.tiles, t)
                
            end
        end
    end
end

function Tilemap:update()
    for _, tile in ipairs(self.tiles) do
        addToDrawQueue(tile.yWorld, tile)
    end
end


return Tilemap