Store = setmetatable({}, {__index = Tile})
Store.__index = Store

local sheetImage = love.graphics.newImage("assets/sprites/objects/store.png")
local sheetWidth, sheetHeight = sheetImage:getDimensions()
local sheetGun = love.graphics.newImage("assets/sprites/player/guns.png")
local font = love.graphics.newFont("assets/fonts/pixelart.ttf", 8)

sheetGun:setFilter("nearest", "nearest")
sheetImage:setFilter("nearest", "nearest")
font:setFilter("nearest", "nearest")

local quads = {}
local frameWidth = 32
local frameHeight = sheetHeight
local stretch = 1.5
local gunDict  = {
    {name = "shotgun", price = 400, index = 2},
}

for i = 0, (sheetWidth / frameWidth) - 1 do
    table.insert(quads, love.graphics.newQuad(i * frameWidth, 0, frameWidth, frameHeight, sheetWidth, sheetHeight))
end


function Store:new(x, y, quadIndex, collider)
    local tile = Tile.new(self, x, y, quadIndex, collider)
    setmetatable(tile, Store)
    tile.alpha = 1
    tile.targetAlpha = 1
    tile.product = gunDict[1]
    return tile
end

function Store:update(dt)

    if distance(Player, self) < 20 and Player.isAlive then
        self.targetAlpha = 1
    else
        self.targetAlpha = 0
    end

    self.alpha= self.alpha + (self.targetAlpha - self.alpha) * dt * 10
end

function Store:performBuy()
    if distance(Player, self) > 20 then return end

    if Player.gun.gunIndex == self.product.index then return end

    local playerPoints = Game:getPlayerPoints()

    if playerPoints < self.product.price then return end

    Game:decreasePlayerPoints(self.product.price)
    Player.gun:changeGun(self.product.index)
end

function Store:draw()
    love.graphics.setFont(font)

    local text = "click x to buy"
    local price = self.product.price .. " p"
    local name = self.product.name 
    
    local textWidth = font:getWidth(text)
    local priceWidth = font:getWidth(price)
    local nameWidth = font:getWidth(self.product.name)

    love.graphics.draw(sheetImage, quads[2], self.xWorld - frameWidth/2, self.yWorld - frameHeight * stretch, 0, 1, stretch)
    if Player.gun.gunIndex ~= self.product.index then 
        local quadGun = love.graphics.newQuad(
            (self.product.index - 1) * 16, 
            16,
            16, 16,
            sheetGun:getDimensions()
        )

        love.graphics.draw(
            sheetGun,
            quadGun,
            self.xWorld - 4,
            self.yWorld - 18,
            0,
            1, 1.4,
            0,
            self.size / 2
        )
    end
    love.graphics.setColor(1, 1, 1, self.alpha)
    
    love.graphics.print(name, self.xWorld - nameWidth/2 + 2 , self.yWorld - 95)
    love.graphics.print(price, self.xWorld - priceWidth/2 + 2 , self.yWorld - 80)
    if Game:getPlayerPoints() > self.product.price and Player.gun.gunIndex ~= self.product.index then 
        love.graphics.print(text, self.xWorld - textWidth/2 + 2 , self.yWorld - 65)
    end
    
    
    love.graphics.setColor(1, 1, 1)

    self:drawDebug()
end


return Store