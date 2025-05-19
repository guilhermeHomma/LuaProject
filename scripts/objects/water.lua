Water = setmetatable({}, {__index = Tile})
Water.__index = Water


local waterShader = love.graphics.newShader("scripts/shaders/waterShader.glsl")
local sheetImage = love.graphics.newImage("assets/sprites/objects/water-tileset.png")
local sheetWidth, sheetHeight = sheetImage:getDimensions()
sheetImage:setFilter("nearest", "nearest")

local function getQuadList()
    local quadList = {}

    for x = 1, 3 do
        for y = 1, 3 do
            local tileX = (x - 1) * 16 
            local tileY = (y - 1) * 16 
            local index = (y - 1) * 3 + x

            quadList[index] = love.graphics.newQuad(tileX + 16, tileY + 16, 16, 16, sheetWidth, sheetHeight)
        end
    end
    quadList[10] = love.graphics.newQuad(80, 16, 16, 16, sheetWidth, sheetHeight)
    quadList[11] = love.graphics.newQuad(96, 16, 16, 16, sheetWidth, sheetHeight)
    quadList[12] = love.graphics.newQuad(80, 32, 16, 16, sheetWidth, sheetHeight)
    quadList[13] = love.graphics.newQuad(96, 32, 16, 16, sheetWidth, sheetHeight)

    return quadList
end


function Water:new(x, y, quadIndex, collider)
    local tile = Tile.new(self, x, y, quadIndex, collider)

    tile.isWater = true
    tile.quad = getQuadList()[quadIndex]
    setmetatable(tile, Water)
    return tile
end

function Water:update(dt) 

end


function Water:draw()
    --love.graphics.setShader(waterShader)
    waterShader:send("time", love.timer.getTime())
    love.graphics.draw(sheetImage, self.quad, self.xWorld, self.yWorld + 16, 0, 1, 1, 16/2, 16*2)
    love.graphics.setShader()
    self:drawDebug()
end


function Water:drawShadow()
   
end


return Water