

local TileSet = {}


function TileSet:createTileSet()
    self.tilesetImage = love.graphics.newImage("assets/sprites/tileset.png")
    self.tileSize = 16
    self.tileSet = {}

    self.tilesetImage:setFilter("nearest", "nearest")

    self.sheetWidth, self.sheetHeight = self.tilesetImage:getDimensions()

    for x = 1, 3 do
        for y = 1, 3 do
            local tileX = (x - 1) * self.tileSize 
            local tileY = (y - 1) * self.tileSize + 16
            local index = (y - 1) * 3 + x

            if y == 1 then 
                self.tileSet[index] = love.graphics.newQuad(tileX, tileY-16, self.tileSize, self.tileSize, self.sheetWidth, self.sheetHeight)
            else
                self.tileSet[index] = love.graphics.newQuad(tileX, tileY, self.tileSize, self.tileSize, self.sheetWidth, self.sheetHeight)
            end
        end
    end

    self.tileSet[10] = love.graphics.newQuad(48 + 16, 0, self.tileSize, self.tileSize, self.sheetWidth, self.sheetHeight)
    self.tileSet[11] = love.graphics.newQuad(64 + 16, 0, self.tileSize, self.tileSize, self.sheetWidth, self.sheetHeight)
    self.tileSet[12] = love.graphics.newQuad(48 + 16, 16, self.tileSize, self.tileSize, self.sheetWidth, self.sheetHeight)
    self.tileSet[13] = love.graphics.newQuad(64 + 16, 16, self.tileSize, self.tileSize, self.sheetWidth, self.sheetHeight)

    self.tileSet[14] = love.graphics.newQuad(16, 64, self.tileSize, self.tileSize*2, self.sheetWidth, self.sheetHeight) --caixa
    self.tileSet[15] = love.graphics.newQuad(64, 32, self.tileSize, self.tileSize, self.sheetWidth, self.sheetHeight) --variacao grama

    self.tileSet[18] = love.graphics.newQuad(48, 64, self.tileSize, self.tileSize*2, self.sheetWidth, self.sheetHeight) --varia caixa
end

function TileSet:getTileSet()
    return self.tileSet
end

return TileSet