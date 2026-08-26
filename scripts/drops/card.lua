local Life = require("scripts/drops/life")
local CardDrop = setmetatable({}, {__index = Life})

CardDrop.__index = CardDrop

local Ball = require("scripts/particles/ballParticle")
local BulletColorParticle = require("scripts/particles/bulletColorParticle")
local sheetImage = love.graphics.newImage("assets/sprites/objects/card-drop.png")
local cardTintShader = love.graphics.newShader([[
    extern vec3 tintColor;

    vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screenCoord)
    {
        vec4 base = Texel(tex, uv) * color;
        float greenKey = step(0.88, base.g) * step(base.r, 0.08) * step(base.b, 0.08);
        base.rgb = mix(base.rgb, tintColor, greenKey);
        return base;
    }
]])
local greenRainbowShader = love.graphics.newShader("scripts/shaders/greenRainbow.glsl")
sheetImage:setFilter("nearest", "nearest")

local cardTintPalette = {
    {0.62, 0.45, 0.50, 1},
    {0.43, 0.58, 0.60, 1},
    {0.63, 0.55, 0.40, 1},
    {0.45, 0.60, 0.49, 1},
    {0.54, 0.46, 0.62, 1},
}
local cardParticleOptions = {
    speedMin = 4,
    speedMax = 14,
    lifeTime = 0.62,
    size = 1,
}

local quads = {
    love.graphics.newQuad(0, 0, 16, 16, sheetImage:getDimensions()),
}

function CardDrop:new(x, y, options)
    options = options or {}
    local drop = Life.new(self, x, y)
    setmetatable(drop, CardDrop)
    drop.spriteIndex = 1
    drop.sprite = quads[1]
    drop.drawScaleX = 1
    drop.drawScaleY = 1.35
    drop.baseHeight = 4
    drop.hoverHeight = drop.baseHeight
    drop.hoverAmplitude = 0.35
    drop.height = drop.hoverHeight + (drop.popHeight or 0)
    drop.cardParticleTimer = math.random() * 0.12
    drop.priceRevealTimer = 0
    drop.purchasePrice = options.price or 5
    drop.isCardDrop = true
    drop.allowWeaponCards = options.allowWeaponCards == true
    drop.badCardChance = options.badCardChance
    drop.allBadChance = options.allBadChance
    drop.useRainbowShader = options.useRainbowShader == true
    drop.neverExpires = true
    drop.requirePickupKey = false
    drop.disableAttraction = true
    drop.pickupDistance = options.pickupDistance or 8
    drop.cardTint = options.tint or cardTintPalette[math.random(#cardTintPalette)]
    drop.onPurchased = options.onPurchased
    return drop
end

function CardDrop:checkCatch()
    local isOverlapping = self.isAlive and not self.isCollecting and self:isPlayerInPickupRange()
    if not isOverlapping then
        self.insufficientOverlap = false
        return
    end

    if Game and Game.cardPurchaseLocked and Game.cardPurchaseLocked ~= self then
        return
    end

    local price = self.purchasePrice or 5
    if not (Game and Game.getPlayerPoints and Game:getPlayerPoints() >= price) then
        if not self.insufficientOverlap and PointsManager and PointsManager.triggerNegativeFeedback then
            PointsManager:triggerNegativeFeedback()
        end
        self.insufficientOverlap = true
        return
    end

    self.insufficientOverlap = false
    Game.cardPurchaseLocked = self
    Game:decreasePlayerPoints(price)
    if self.onPurchased then
        self.onPurchased(self)
    end
    self:markPersistentCollected()
    self:startCollectAnimation()
end

function CardDrop:updatePickupTutorial(dt)
end

function CardDrop:onCatch()
    if Game and Game.centerCurrentRoomCardDrops then
        Game:centerCurrentRoomCardDrops()
    end

    for _ = 1, 12 do
        local angle = math.random() * math.pi * 2
        local speed = 0.35 + math.random() * 0.55
        local particle = Ball:new(
            self.x,
            self.y,
            self.height,
            math.cos(angle) * speed,
            math.sin(angle) * speed,
            math.random(18, 30) / 100,
            math.random(4, 7) / 10,
            { rgbShift = { duration = 0.22, shift = 1.1 } }
        )
        table.insert(Game.particles, particle)
    end

    if Game and Game.startCardChoice then
        Game:startCardChoice(self.x, self.y - 16, {
            allowRare = self.allowWeaponCards == true,
            allowWeaponCards = self.allowWeaponCards == true,
            badCardChance = self.badCardChance or ((self.purchasePrice or 5) <= 5 and 0.30 or 0.05),
            allBadChance = self.allBadChance or ((self.purchasePrice or 5) <= 5 and 0.05 or 0),
        })
    end
end

function CardDrop:animation(dt)
    self.animationTimer = self.animationTimer + dt
    self.priceRevealTimer = (self.priceRevealTimer or 0) + dt

    if not self.isCollecting then
        self.cardParticleTimer = (self.cardParticleTimer or 0) + dt
        if self.cardParticleTimer >= 0.13 then
            self.cardParticleTimer = self.cardParticleTimer - 0.13
            BulletColorParticle.spawnBurst(
                self.x + math.random(-5, 5),
                self.y + math.random(-4, 4),
                self.height,
                {self.cardTint},
                1,
                cardParticleOptions
            )
        end
    end
end

function CardDrop:draw()
    if not self.isAlive then
        return
    end

    local scaleX, scaleY = self:getDrawScale()
    local drawY = self.y - self.height
    if self.isCollecting then
        drawY = drawY + 4 * ((self.drawScaleY or 1.35) - scaleY)
    end

    local tint = self.cardTint or cardTintPalette[1]
    if self.useRainbowShader then
        greenRainbowShader:send("u_time", love.timer.getTime())
        love.graphics.setShader(greenRainbowShader)
    else
        cardTintShader:send("tintColor", {tint[1], tint[2], tint[3]})
        love.graphics.setShader(cardTintShader)
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(sheetImage, self.sprite, self.x, drawY, 0, scaleX, scaleY, 8, 16)
    love.graphics.setShader()

    love.graphics.setColor(1, 1, 1, 1)
end

function CardDrop:drawHudPrice()
    if not self.isAlive or self.isCollecting or not camera or not PointsManager or not PointsManager.font then
        return
    end

    local zoomX = camera.zoomX or 1
    local zoomY = camera.zoomY or 1
    local snappedCameraX = math.floor(((camera.x or 0) + (camera.shakeOffsetX or 0)) * zoomX + 0.5) / zoomX
    local snappedCameraY = math.floor(((camera.y or 0) + (camera.shakeOffsetY or 0)) * zoomY + 0.5) / zoomY
    local screenX = (self.x * (WORLD_SCALE_X or 1) - snappedCameraX) * zoomX
    local labelWorldY = self.y - (self.height or self.baseHeight or 0) + 0.5
    local screenY = (labelWorldY * (YSCALE or WORLD_SCALE_Y or 1) - snappedCameraY) * zoomY
    local priceText = tostring(self.purchasePrice or 5) .. "$"
    local font = PointsManager.font
    local textX = math.floor(screenX - font:getWidth(priceText) / 2 + 0.5)
    local textY = math.floor(screenY + 0.5)
    local canAfford = Game and Game.getPlayerPoints and Game:getPlayerPoints() >= (self.purchasePrice or 5)
    local priceAlpha = math.min(math.max(((self.priceRevealTimer or 0) - 0.5) / 0.2, 0), 1)
    if priceAlpha <= 0 then
        return
    end

    love.graphics.setFont(font)
    if canAfford then
        love.graphics.setColor(0.05, 0, 0.05, priceAlpha)
        love.graphics.print(priceText, textX + 2, textY + 2)
        love.graphics.setColor(1, 1, 1, priceAlpha)
    else
        love.graphics.setColor(0.045, 0.035, 0.028, 0.60 * priceAlpha)
    end
    love.graphics.print(priceText, textX, textY)
    love.graphics.setColor(1, 1, 1, 1)
end

function CardDrop:drawXray()
    if not self.isAlive then
        return
    end

    local scaleX, scaleY = self:getDrawScale()
    local drawY = self.y - self.height
    if self.isCollecting then
        drawY = drawY + 4 * ((self.drawScaleY or 1.35) - scaleY)
    end

    local tint = self.cardTint or cardTintPalette[1]
    if self.useRainbowShader then
        greenRainbowShader:send("u_time", love.timer.getTime())
        love.graphics.setShader(greenRainbowShader)
    else
        cardTintShader:send("tintColor", {tint[1], tint[2], tint[3]})
        love.graphics.setShader(cardTintShader)
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(sheetImage, self.sprite, self.x, drawY, 0, scaleX, scaleY, 8, 16)
    love.graphics.setShader()
end

return CardDrop
