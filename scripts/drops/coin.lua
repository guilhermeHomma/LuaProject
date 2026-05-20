local Life = require("scripts/drops/life")
local Coin = setmetatable({}, {__index = Life})

Coin.__index = Coin
Coin.disableSpawnCollisionPush = true

local DropShine = require("scripts/drops/dropShine")
local PickupNumber = require("scripts/effects/damageNumber")


local sheetImage = love.graphics.newImage("assets/sprites/objects/coin.png")

sheetImage:setFilter("nearest", "nearest")
local quads = {}
local sheetWidth = sheetImage:getWidth()
local sheetHeight = sheetImage:getHeight()

for x = 0, sheetWidth - 8, 8 do
    if x == 0 then 
        table.insert(quads, love.graphics.newQuad(x, 0, 8, 8, sheetWidth, sheetHeight))
        table.insert(quads, love.graphics.newQuad(x, 0, 8, 8, sheetWidth, sheetHeight))
    end
    table.insert(quads, love.graphics.newQuad(x, 0, 8, 8, sheetWidth, sheetHeight))
end

function Coin:new(x, y)
    local coin = Life.new(self, x, y)
    setmetatable(coin, Coin)

    local angle = math.random() * math.pi * 2
    local speed = 60 + math.random() * 10
    coin.vx = math.cos(angle) * speed
    coin.vy = math.sin(angle) * speed

    return coin
end

function Coin:changeHeight()
    self.hoverHeight = 0
end 

function Coin:onCatch()
    if Player then
        Game:increasePlayerPoints(5)
    end

    local coinSound = love.audio.newSource("assets/sfx/drops/catch-coin.mp3", "static")

    coinSound:setVolume(0.1)
    coinSound:setPitch((1) * GAME_PITCH)
    coinSound:play()


    PickupNumber.spawnPickup(self.x, self.y, self.height, "+5", "coin")
end


function Coin:animation(dt)
    self.animationTimer = self.animationTimer + dt

    if self.animationTimer > 0.1 then
        self.animationTimer = 0
        self.spriteIndex = self.spriteIndex + 1
        if self.spriteIndex > #quads then
            self.spriteIndex = 1
        end
        self.sprite = quads[self.spriteIndex]
    end
end

function Coin:draw()
    if not self.isAlive then
        return
    end
    local alpha = 1
    if not self.neverExpires and self.lifeTime - self.lifetimeTimer <= 4 then
        local blink = math.floor(self.lifetimeTimer * 10) % 2
        alpha = blink == 0 and 0.2 or 1
    end

    love.graphics.setColor(1, 1, 1, alpha)
    local scaleX, scaleY = self:getDrawScale()
    local drawY = self.y - self.height
    if self.isCollecting then
        local baseScaleY = self.drawScaleY or 1.25
        drawY = drawY + 4 * (baseScaleY - scaleY)
    end
    DropShine.draw(sheetImage, self.sprite, self.x, drawY, 0, scaleX, scaleY, 4, 8)
    love.graphics.setColor(1, 1, 1, 1)

end

return Coin
