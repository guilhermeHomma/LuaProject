Water = setmetatable({}, {__index = Tile})
Water.__index = Water


local waterShader = love.graphics.newShader("scripts/shaders/waterShader.glsl")
local sheetImage = love.graphics.newImage("assets/sprites/objects/water-tileset.png")
local sheetWidth, sheetHeight = sheetImage:getDimensions()
local frameQty = 3
sheetImage:setFilter("nearest", "nearest")

local function getQuadList(animIndex)
    local quadList = {}
    local realWidth = sheetWidth/frameQty

    local IncrementX = realWidth * animIndex

    for x = 1, 3 do
        for y = 1, 3 do
            local tileX = (x - 1) * 16 
            local tileY = (y - 1) * 16 
            local index = (y - 1) * 3 + x

            quadList[index] = love.graphics.newQuad(tileX + 16 + IncrementX, tileY + 16, 16, 16, sheetWidth, sheetHeight)
        end
    end

    quadList[10] = love.graphics.newQuad(80 + IncrementX, 16, 16, 16, sheetWidth, sheetHeight)
    quadList[11] = love.graphics.newQuad(96 + IncrementX, 16, 16, 16, sheetWidth, sheetHeight)
    quadList[12] = love.graphics.newQuad(80 + IncrementX, 32, 16, 16, sheetWidth, sheetHeight)
    quadList[13] = love.graphics.newQuad(96 + IncrementX, 32, 16, 16, sheetWidth, sheetHeight)

    return quadList
end


function Water:new(x, y, quadIndex, collider)
    local tile = Tile.new(self, x, y, quadIndex, collider)

    tile.isWater = true
    tile.quad = getQuadList(0)[quadIndex]
    tile.quad2 = getQuadList(1)[quadIndex]
    tile.quad3 = getQuadList(2)[quadIndex]

    tile.currentFrame = 0
    tile.timer = 0
    tile.frameDirection = 1
    setmetatable(tile, Water)
    return tile
end

function Water:update(dt)
    addToDrawQueue(self.yWorld - 16, self)

    self.timer = self.timer + dt

    if self.timer >= 0.4 then
        self.timer = self.timer - 0.4

        -- Atualiza o frame
        self.currentFrame = self.currentFrame + self.frameDirection

        -- Verifica se chegou nos limites e inverte a direção
        if self.currentFrame >= 2 then
            self.currentFrame = 2
            self.frameDirection = -1
        elseif self.currentFrame <= 0 then
            self.currentFrame = 0
            self.frameDirection = 1
        end
    end
end


function Water:draw()
    --love.graphics.setShader(waterShader)
    waterShader:send("time", love.timer.getTime())

    local currentQuad = self.quad
    if self.currentFrame == 1 then
        currentQuad = self.quad2
    end
    if self.currentFrame == 2 then
        currentQuad = self.quad3
    end
    love.graphics.draw(sheetImage, currentQuad, self.xWorld, self.yWorld + 16, 0, 1, 1, 16/2, 16*2)
    love.graphics.setShader()
    self:drawDebug()
end


function Water:drawShadow()
   
end


return Water