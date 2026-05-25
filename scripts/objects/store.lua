Store = setmetatable({}, {__index = Tile})
Store.__index = Store

local sheetImage = love.graphics.newImage("assets/sprites/objects/store.png")
local sheetWidth, sheetHeight = sheetImage:getDimensions()
local shopLetterImage = love.graphics.newImage("assets/sprites/objects/shop-letter.png")
local sheetGun = love.graphics.newImage("assets/sprites/player/guns.png")
local bulletsDropImage = love.graphics.newImage("assets/sprites/objects/bulletsDrop.png")
local cardDropImage = love.graphics.newImage("assets/sprites/objects/card-drop.png")
local DropShine = require("scripts/drops/dropShine")
local WeaponDefinitions = require("scripts/player/weapons/init")
local FloorManager = require("scripts/managers/floorManager")
local BulletColorParticle = require("scripts/particles/bulletColorParticle")
local font = love.graphics.newFont("assets/fonts/pixelart.ttf", 8)
local errorSoundBase = love.audio.newSource("assets/sfx/error/error.mp3", "static")
local softDenySoundBase = love.audio.newSource("assets/sfx/gun/empty.mp3", "static")

local outlineShader = love.graphics.newShader("scripts/shaders/outline.glsl")
outlineShader:send("u_threshold", 0.1)
outlineShader:send("u_outlineColor", {1, 1, 1, 1})
local shopSignShader = love.graphics.newShader("scripts/shaders/shopSign.glsl")
shopSignShader:send("u_onColor", {0.8, 0.62, 0.14, 0.9})
shopSignShader:send("u_offColor", {0.02, 0.01, 0.002, 0.45})
shopSignShader:send("u_texel", {1 / shopLetterImage:getWidth(), 1 / shopLetterImage:getHeight()})
shopSignShader:send("u_rainbow", 0)
local greenRainbowShader = love.graphics.newShader("scripts/shaders/greenRainbow.glsl")
sheetGun:setFilter("nearest", "nearest")
bulletsDropImage:setFilter("nearest", "nearest")
cardDropImage:setFilter("nearest", "nearest")
sheetImage:setFilter("nearest", "nearest")
shopLetterImage:setFilter("nearest", "nearest")
font:setFilter("nearest", "nearest")

local sheetW, sheetH = sheetImage:getDimensions()
local gunW, gunH = sheetGun:getDimensions()
local bulletDropQuad = love.graphics.newQuad(0, 0, 8, 8, bulletsDropImage:getDimensions())
local cardDropQuad = love.graphics.newQuad(0, 0, 16, 16, cardDropImage:getDimensions())
local cardParticlePalette = {
    {0.52, 0.16, 0.68, 1},
    {0.18, 0.56, 0.60, 1},
    {0.70, 0.22, 0.46, 1},
    {0.62, 0.52, 0.18, 1},
    {0.24, 0.62, 0.34, 1},
}
local cardParticleOptions = {
    speedMin = 4,
    speedMax = 14,
    lifeTime = 0.68,
    size = 1,
}

PlayerCloseStore = false

local quads = {}
local frameWidth = 32
local frameHeight = sheetHeight
local stretch = 1.5

local shopProductOrder = {
    "raygun",
    "squaregun",
    "longshot",
    "cakegun",
    "shotgun",
}

local weaponsByName = {}
local weaponsById = {}
for index, weapon in ipairs(WeaponDefinitions or {}) do
    local weaponId = weapon.id or index
    weapon.index = weapon.index or weaponId
    weaponsByName[weapon.name] = weapon
    weaponsById[weaponId] = weapon
end

local function getAmmoProduct()
    local shopConfig = CURRENT_LEVEL and CURRENT_LEVEL.shopConfig or {}
    return {
        id = shopConfig.ammoProductId or "full_bullets",
        name = "full bullets",
        price = shopConfig.ammoPrice or 300,
        kind = "ammo",
    }
end

local function getCardProduct()
    local shopConfig = CURRENT_LEVEL and CURRENT_LEVEL.shopConfig or {}
    return {
        id = shopConfig.cardProductId or "card_upgrade",
        name = "card",
        price = shopConfig.cardPrice or 200,
        kind = "card",
    }
end

local function getProduct(productKey)
    if type(productKey) == "string" then
        if productKey == getAmmoProduct().id then
            return getAmmoProduct()
        end
        if productKey == getCardProduct().id then
            return getCardProduct()
        end
        return weaponsByName[productKey] or weaponsByName.raygun
    end

    local productName = shopProductOrder[productKey]
    return productName and weaponsByName[productName] or weaponsById[productKey] or weaponsByName.raygun
end

local function playErrorSound(volume, pitch)
    local sound = errorSoundBase:clone()
    sound:setVolume(volume)
    sound:setPitch((pitch or 1) * GAME_PITCH)
    sound:play()
end

local function playSoftDenySound()
    local sound = softDenySoundBase:clone()
    sound:setVolume(0.08)
    sound:setPitch((1.18 + math.random() * 0.08) * GAME_PITCH)
    sound:play()
end

for i = 0, (sheetWidth / frameWidth) - 1 do
    table.insert(quads, love.graphics.newQuad(i * frameWidth, 0, frameWidth, frameHeight, sheetWidth, sheetHeight))
end


function Store:new(x, y, quadIndex, collider, productIndex)
    local tile = Tile.new(self, x, y, quadIndex, collider)
    setmetatable(tile, Store)
    tile.alpha = 1
    tile.targetAlpha = 1
    tile.product = getProduct(productIndex)
    tile.playerIsClose = false
    tile.noMoneyErrorLocked = false
    tile.noMoneyAwayTimer = 2
    tile.noMoneyErrorCooldown = 4
    tile.lastNoMoneyErrorTime = -math.huge
    tile.renderCullMargin = 360
    tile.cardParticleTimer = math.random() * 0.2
    return tile
end

function Store:getPurchaseKey()
    return (self.product and (self.product.id or self.product.name) or "unknown") .. ":" .. self.x .. ":" .. self.y
end

function Store:isPurchased()
    if self.product and (self.product.kind == "ammo" or self.product.kind == "card") then
        local state = FloorManager:getCurrentRoomState()
        return state
            and state.shopPurchases
            and state.shopPurchases[self:getPurchaseKey()] == true
    end

    local productName = self.product and self.product.name
    local productIndex = self.product and self.product.index
    local gamePurchased = Game and Game.hasPurchasedWeapon and Game:hasPurchasedWeapon(productName)
    local playerHasWeapon = Player
        and Player.gun
        and Player.gun.secondary_weapon
        and Player.gun.secondary_weapon.index == productIndex

    return gamePurchased or playerHasWeapon
end

function Store:update(dt)
    addToDrawQueue(self.yWorld+0.1, self)
    if self.product and self.product.kind == "card" and not self:isPurchased() then
        self.cardParticleTimer = (self.cardParticleTimer or 0) + dt
        if self.cardParticleTimer >= 0.13 then
            self.cardParticleTimer = self.cardParticleTimer - 0.13
            BulletColorParticle.spawnBurst(
                self.xWorld + math.random(-7, 7),
                self.yWorld - 18 + math.random(-4, 4),
                2,
                cardParticlePalette,
                1,
                cardParticleOptions
            )
            local particle = Game and Game.particles and Game.particles[#Game.particles]
            if particle then
                particle.drawPriorityY = self.yWorld + 18
            end
        end
    end

    self.playerIsClose = false
    if Player.isAlive and not self:isPurchased() then
        if distance(Player, self) < 20 and Player.isAlive then
            self.targetAlpha = 1
            self.noMoneyAwayTimer = 0
            Game.textAlphaTarget = 1
            Game.drawtext = self:getText()
            self.playerIsClose = true
            PlayerCloseStore = true
        else
            self.targetAlpha = 0
            self.noMoneyAwayTimer = (self.noMoneyAwayTimer or 0) + dt
        end
        
    else
        self.targetAlpha = 0
        self.noMoneyAwayTimer = (self.noMoneyAwayTimer or 0) + dt
    end

    if (self.noMoneyAwayTimer or 0) >= 2 then
        self.noMoneyErrorLocked = false
    end
    self.alpha= self.alpha + (self.targetAlpha - self.alpha) * dt * 10
end

function Store:performBuy()
    if self:isPurchased() then return end
    if distance(Player, self) > 20 then return end

    local currentPrice = self.product.price
    local playerPoints = Game:getPlayerPoints()

    if playerPoints < currentPrice then
        if PointsManager and PointsManager.triggerNegativeFeedback then
            PointsManager:triggerNegativeFeedback()
        end

        local now = love.timer.getTime()
        if now - (self.lastNoMoneyErrorTime or -math.huge) < (self.noMoneyErrorCooldown or 4) then
            playSoftDenySound()
        else
            playErrorSound(0.38, 0.96)
            self.lastNoMoneyErrorTime = now
            self.noMoneyErrorLocked = true
        end
        return
    end
    if self.product.kind == "ammo" and not (Player.gun and Player.gun.secondary_weapon) then return end
    if self.product.kind ~= "card" and self.product.index == 1 then return end

    local sound = love.audio.newSource("assets/sfx/store/buy-item.mp3", "static")
    if self.product.kind == "card" then
        sound:setVolume(0.5)
        sound:setPitch((1.15 + math.random() * 0.1) * GAME_PITCH)
    else
        sound:setVolume(1)
        sound:setPitch((0.95 + math.random() * 0.1) * GAME_PITCH)
    end
    sound:play()

    Game:decreasePlayerPoints(currentPrice)
    if self.product.kind == "ammo" then
        Player.gun:fillSecondaryWeaponToMax()
        local state = FloorManager:getCurrentRoomState()
        if state then
            state.shopPurchases = state.shopPurchases or {}
            state.shopPurchases[self:getPurchaseKey()] = true
        end
    elseif self.product.kind == "card" then
        local state = FloorManager:getCurrentRoomState()
        if state then
            state.shopPurchases = state.shopPurchases or {}
            state.shopPurchases[self:getPurchaseKey()] = true
        end
        if Game and Game.startCardChoice then
            Game:startCardChoice(self.xWorld, self.yWorld - 16, { allowRare = true })
        end
    else
        Player.gun:changeGun(self.product.index)
        if Game.markWeaponPurchased then
            Game:markWeaponPurchased(self.product.name)
        end
        if Game and Game.showBottomMessage then
            Game:showBottomMessage("press e to switch weapon\npress q to reload", 6)
        end
    end
    self.playerIsClose = false
    PlayerCloseStore = false
end


function Store:drawGun()
    if self:isPurchased() then
        return
    end

    local image = sheetGun
    local quadGun = love.graphics.newQuad(
        ((self.product.index or 1) - 1) * 16,
        16,
        16, 16,
        sheetGun:getDimensions()
    )

    local originX = 0
    local originY = self.size / 2
    local drawX = self.xWorld - 4
    local drawY = self.yWorld - 18
    if self.product.kind == "ammo" then
        image = bulletsDropImage
        quadGun = bulletDropQuad
        originX = 4
        originY = 8
        drawX = self.xWorld
        drawY = self.yWorld - 16
    elseif self.product.kind == "card" then
        image = cardDropImage
        quadGun = cardDropQuad
        originX = 8
        originY = 16
        drawX = self.xWorld
        drawY = self.yWorld - 16
    end

    local time = love.timer.getTime()
    local floatY = math.sin(time * 2.8 + self.xWorld * 0.03) * 2.2
    local scaleX = 1
    local scaleY = 1.5

    if self.playerIsClose then
        local stretch = math.sin(time * 5.5) * 0.025 + 0.025
        scaleX = 1 + stretch
        scaleY = 1.5 * (1 - stretch * 0.5)
    end

    if self.product.kind == "card" then
        greenRainbowShader:send("u_time", love.timer.getTime())
        love.graphics.setShader(greenRainbowShader)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(image, quadGun, drawX, drawY + floatY, 0, scaleX, scaleY, originX, originY)
        love.graphics.setShader()
        return
    end

    DropShine.draw(image, quadGun, drawX, drawY + floatY, 0, scaleX, scaleY, originX, originY)
end

function Store:drawShopSign()
    local purchased = self:isPurchased()
    shopSignShader:send("u_active", purchased and 0 or 1)
    shopSignShader:send("u_time", love.timer.getTime())
    shopSignShader:send("u_rainbow", self.product and self.product.kind == "card" and not purchased and 1 or 0)

    love.graphics.setShader(shopSignShader)
    love.graphics.draw(
        shopLetterImage,
        self.xWorld,
        self.yWorld,
        0,
        1,
        1,
        shopLetterImage:getWidth() / 2,
        shopLetterImage:getHeight()
    )
    love.graphics.setShader()
    love.graphics.setColor(1, 1, 1, 1)
end

function Store:draw()
    love.graphics.setFont(font)
    local activeQuad = quads[2]
    local quadX, quadY, quadW, quadH = activeQuad:getViewport()
    outlineShader:send("u_texel", {1 / sheetW, 1 / sheetH})
    outlineShader:send("u_uvMin", {quadX / sheetW, quadY / sheetH})
    outlineShader:send("u_uvMax", {(quadX + quadW) / sheetW, (quadY + quadH) / sheetH})

    if self.playerIsClose and not self:isPurchased() then
        love.graphics.setShader(outlineShader)
    end
    love.graphics.draw(sheetImage, activeQuad, self.xWorld - frameWidth/2, self.yWorld - frameHeight * stretch, 0, 1, stretch)
    love.graphics.setShader()
    self:drawShopSign()
    self:drawGun()
    love.graphics.setColor(0, 0, 0, self.alpha)
    if Player.isAlive then 
        for i = 0, 1 do
            if i == 1 then love.graphics.setColor(1, 1, 1, self.alpha) end
            
            local t = self:getText()

        end
    end
    love.graphics.setColor(1, 1, 1)

    self:drawDebug()
end

function Store:getText()

    love.graphics.setFont(font)

    local currentPrice = self.product.price

    local name = self.product.name 

    local buyT = "click F to buy"
    local price = currentPrice .. " C"

    if not Player.isAlive or self:isPurchased() then
        return ""
    end

    local text = name .. "\n" .. price

    if Game:getPlayerPoints() >= currentPrice then
        text = text .. "\n" .. buyT
    end

    return text
end

return Store
