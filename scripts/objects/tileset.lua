

local TileSet = {}


function TileSet:createTileSet()
    self.tilesetImage = love.graphics.newImage("assets/sprites/florest/tileset.png")
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
    self.tileSet[19] = love.graphics.newQuad(144, 0, self.tileSize, self.tileSize, self.sheetWidth, self.sheetHeight) --caminho chao
    self.tileSet[20] = love.graphics.newQuad(160, 0, self.tileSize, self.tileSize, self.sheetWidth, self.sheetHeight) --caminho chao
    self.tileSet[21] = love.graphics.newQuad(144, 16, self.tileSize, self.tileSize, self.sheetWidth, self.sheetHeight) --caminho chao
    self.tileSet[22] = love.graphics.newQuad(160, 16, self.tileSize, self.tileSize, self.sheetWidth, self.sheetHeight) --caminho chao

    for x = 0, 2 do
        self.tileSet[31 + x] = love.graphics.newQuad(80 + x * self.tileSize, 64, self.tileSize, self.tileSize, self.sheetWidth, self.sheetHeight)
        self.tileSet[34 + x] = love.graphics.newQuad(80 + x * self.tileSize, 96, self.tileSize, self.tileSize, self.sheetWidth, self.sheetHeight)
        self.tileSet[37 + x] = love.graphics.newQuad(80 + x * self.tileSize, 112, self.tileSize, self.tileSize, self.sheetWidth, self.sheetHeight)
    end

    self.tileSet[40] = love.graphics.newQuad(144, 64, self.tileSize, self.tileSize, self.sheetWidth, self.sheetHeight) --quina interna parede
    self.tileSet[41] = love.graphics.newQuad(160, 64, self.tileSize, self.tileSize, self.sheetWidth, self.sheetHeight) --quina interna parede
    self.tileSet[42] = love.graphics.newQuad(144, 80, self.tileSize, self.tileSize, self.sheetWidth, self.sheetHeight) --quina interna parede
    self.tileSet[43] = love.graphics.newQuad(160, 80, self.tileSize, self.tileSize, self.sheetWidth, self.sheetHeight) --quina interna parede

    for x = 0, 2 do
        self.tileSet[44 + x] = love.graphics.newQuad(208 + x * self.tileSize, 0, self.tileSize, self.tileSize, self.sheetWidth, self.sheetHeight)
        self.tileSet[47 + x] = love.graphics.newQuad(208 + x * self.tileSize, 32, self.tileSize, self.tileSize, self.sheetWidth, self.sheetHeight)
        self.tileSet[50 + x] = love.graphics.newQuad(208 + x * self.tileSize, 48, self.tileSize, self.tileSize, self.sheetWidth, self.sheetHeight)
    end

    self.tileSet[53] = love.graphics.newQuad(256, 0, self.tileSize, self.tileSize, self.sheetWidth, self.sheetHeight) --quina interna parede pedra
    self.tileSet[54] = love.graphics.newQuad(272, 0, self.tileSize, self.tileSize, self.sheetWidth, self.sheetHeight) --quina interna parede pedra
    self.tileSet[55] = love.graphics.newQuad(256, 16, self.tileSize, self.tileSize, self.sheetWidth, self.sheetHeight) --quina interna parede pedra
    self.tileSet[56] = love.graphics.newQuad(272, 16, self.tileSize, self.tileSize, self.sheetWidth, self.sheetHeight) --quina interna parede pedra

end

function TileSet:getTileSet()
    return self.tileSet
end

return TileSet
