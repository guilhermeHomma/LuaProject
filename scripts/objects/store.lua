Store = setmetatable({}, {__index = Tile})
Store.__index = Store

local sheetImage = love.graphics.newImage("assets/sprites/objects/store.png")
local sheetWidth, sheetHeight = sheetImage:getDimensions()

local quads = {}
local frameWidth = 32
local frameHeight = sheetHeight

local font = love.graphics.newFont("assets/fonts/pixelart.ttf", 8)

local stretch = 1.5
--local Gun = require("scripts/player/gun")


for i = 0, (sheetWidth / frameWidth) - 1 do
    table.insert(quads, love.graphics.newQuad(i * frameWidth, 0, frameWidth, frameHeight, sheetWidth, sheetHeight))
end

sheetImage:setFilter("nearest", "nearest")
font:setFilter("nearest", "nearest")

function Store:new(x, y, quadIndex, collider)
    local tile = Tile.new(self, x, y, quadIndex, collider)
    setmetatable(tile, Store)
    tile.alpha = 1
    tile.targetAlpha = 1
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
    Game:performBuy()
end

function Store:draw()
    local text = "click x to buy shotgun"

    love.graphics.setFont(font)
    local textWidth = font:getWidth(text)

    love.graphics.draw(sheetImage, quads[2], self.xWorld - frameWidth/2, self.yWorld - frameHeight * stretch, 0, 1, stretch)

    love.graphics.setColor(1, 1, 1, self.alpha)

    love.graphics.print(text, self.xWorld - textWidth/2 + 4 , self.yWorld - 65)
    
    love.graphics.setColor(1, 1, 1)

    self:drawDebug()
end


return Store