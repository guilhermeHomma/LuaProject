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
    {name = "raygun", price = 600, index = 3, bulletPrice = 250},
    {name = "squaregun", price = 200, index = 4, bulletPrice = 100},
    {name = "shotgun", price = 400, index = 2, bulletPrice = 200},
}

for i = 0, (sheetWidth / frameWidth) - 1 do
    table.insert(quads, love.graphics.newQuad(i * frameWidth, 0, frameWidth, frameHeight, sheetWidth, sheetHeight))
end


function Store:new(x, y, quadIndex, collider, productIndex)
    local tile = Tile.new(self, x, y, quadIndex, collider)
    setmetatable(tile, Store)
    tile.alpha = 1
    tile.targetAlpha = 1
    tile.product = gunDict[productIndex]

    return tile
end

function Store:update(dt)
    addToDrawQueue(self.yWorld, self)

    if distance(Player, self) < 20 and Player.isAlive then
        self.targetAlpha = 1
    else
        self.targetAlpha = 0
    end

    self.alpha= self.alpha + (self.targetAlpha - self.alpha) * dt * 10
end

function Store:performBuy()
    if distance(Player, self) > 20 then return end


    local currentPrice = self.product.price
    if Player.gun.gunIndex == self.product.index then 
        currentPrice = self.product.bulletPrice 
    end

    local playerPoints = Game:getPlayerPoints()

    if playerPoints < currentPrice then return end

    local sound = love.audio.newSource("assets/sfx/store/buy-item.mp3", "static")
    sound:setVolume(1)
    sound:setPitch((0.95 + math.random() * 0.1) * GAME_PITCH)
    sound:play()

    Game:decreasePlayerPoints(currentPrice)
    Player.gun:changeGun(self.product.index)
end


function Store:drawGun()
    --if Player.gun.gunIndex ~= self.product.index then 
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
            1, 1.5,
            0,
            self.size / 2
        )
    --end
end

function Store:draw()
    love.graphics.setFont(font)

    local currentPrice = self.product.price
    local name = self.product.name 

    if Player.gun.gunIndex == self.product.index then 
        currentPrice = self.product.bulletPrice 
        name = name .. " bullets"
    end

    local text = "click X to buy"
    local price = currentPrice .. " p"
    
    
    local textWidth = font:getWidth(text)
    local priceWidth = font:getWidth(price)
    local nameWidth = font:getWidth(name)

    love.graphics.draw(sheetImage, quads[2], self.xWorld - frameWidth/2, self.yWorld - frameHeight * stretch, 0, 1, stretch)

    self:drawGun()
    love.graphics.setColor(0, 0, 0, self.alpha)
    for i = 0, 1 do
        if i == 1 then love.graphics.setColor(1, 1, 1, self.alpha) end
        love.graphics.print(name, math.ceil(self.xWorld - nameWidth/2 + 2 + i) + 0.5 , self.yWorld - 95 + i)
        love.graphics.print(price, self.xWorld - priceWidth/2 + 2 + i, self.yWorld - 80 + i)
        if Game:getPlayerPoints() > currentPrice then 
            love.graphics.print(text, self.xWorld - textWidth/2 + 2 + i , self.yWorld - 65 + i)
        end
    end
    
    love.graphics.setColor(1, 1, 1)

    self:drawDebug()
end


return Store