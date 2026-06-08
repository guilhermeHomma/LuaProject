local CardChoice = {}

local Ball = require("scripts/particles/ballParticle")
local CardDefinitions = require("scripts/cards/cardDefinitions")
local PlayerStatusHud = require("scripts/ui/playerStatusHud")
local Localization = require("scripts/managers/localization")
local Fonts = require("scripts/ui/fonts")

local function loadCardImage(path)
    local image = love.graphics.newImage(path)
    image:setFilter("nearest", "nearest")
    return image
end

local cardBackImages = {
    common = loadCardImage("assets/sprites/ui/cards/common.png"),
    rare = loadCardImage("assets/sprites/ui/cards/rare.png"),
    epic = loadCardImage("assets/sprites/ui/cards/epic.png"),
}
local fallbackCardImage = cardBackImages.common or loadCardImage("assets/sprites/ui/cards/card.png")
local cardArtImages = {
    player = loadCardImage("assets/sprites/ui/cards/player.png"),
    life = loadCardImage("assets/sprites/ui/cards/life.png"),
    weapon = loadCardImage("assets/sprites/ui/cards/gun.png"),
}

local smoothCardSoundBase = love.audio.newSource("assets/sfx/ui/smooth-good-cards.mp3", "static")
local shuffleCardSoundBase = love.audio.newSource("assets/sfx/ui/shuffle-card.mp3", "static")
local singleCardSoundBase = love.audio.newSource("assets/sfx/ui/single-card-sound.mp3", "static")

local titleFont = Fonts:translated("cardTitle")
local cardNameFont = Fonts:translated("cardName")
local cardRarityFont = Fonts:translated("cardRarity")
local cardAmountFont = Fonts:translated("cardAmount")
local cardDescriptionFont = Fonts:translated("cardDescription")

local colors = {
    {0.48, 0.04, 0.18, 1},
    {0.04, 0.32, 0.38, 1},
    {0.46, 0.28, 0.02, 1},
    {0.08, 0.34, 0.16, 1},
    {0.32, 0.08, 0.48, 1},
}

local cardScale = 3.825
local selectedCardScale = 4.2
local cardPadding = 54
local hoverDistance = 58

local function easeOut(t)
    return 1 - (1 - t) * (1 - t) * (1 - t)
end

local function shuffle(list)
    for i = #list, 2, -1 do
        local j = math.random(i)
        list[i], list[j] = list[j], list[i]
    end
end

local function containsCard(cards, candidate)
    for _, card in ipairs(cards) do
        if card.id == candidate.id then
            return true
        end
    end
    return false
end

local function getMouseCanvasPosition()
    local mx, my = love.mouse.getPosition()
    return (mx - viewportOffsetX) / scale, (my - viewportOffsetY) / scale
end

local function approach(value, target, speed, dt)
    return value + (target - value) * math.min(speed * dt, 1)
end

local function round(value)
    if value >= 0 then
        return math.floor(value + 0.5)
    end
    return math.ceil(value - 0.5)
end

local function playSound(baseSource, volume, pitch)
    local sound = baseSource:clone()
    sound:setVolume(volume or 1)
    sound:setPitch((pitch or 1) * (GAME_PITCH or 1))
    sound:play()
end

local function getCardBackImage(cardDef)
    local rarityId = cardDef and cardDef.rarity or "common"
    return cardBackImages[rarityId] or fallbackCardImage
end

local function getCardArtImage(cardDef)
    return cardArtImages[cardDef and cardDef.visualType] or cardArtImages.player
end

function CardChoice:load()
    self.active = false
    self.cards = {}
    self.particles = {}
    self.timer = 0
    self.phase = "idle"
    self.previewCard = nil
    self.selectedCardDef = nil
    self.drawAlpha = 1
    if Dialog then
        Dialog.breakMovements = false
    end
end

function CardChoice:isActive()
    return self.active == true
end

function CardChoice:getEligibleCards()
    return CardDefinitions:getEligibleCards()
end

function CardChoice:chooseCards(count, options)
    options = options or {}
    local chosen = {}
    local fallback = self:getEligibleCards()
    local epicIndex = nil
    shuffle(fallback)

    if options.allowRare ~= false and math.random(15) == 1 then
        epicIndex = math.random(count)
    end

    for _ = 1, count do
        local cardIndex = #chosen + 1
        local rarity = options.allowRare == false and "common" or CardDefinitions:getRandomRarity()
        if epicIndex == cardIndex then
            rarity = "epic"
        end
        local pool = CardDefinitions:getEligibleCardsByRarity(rarity)

        if #pool == 0 then
            pool = CardDefinitions:getEligibleCardsByRarity("common")
        end

        shuffle(pool)
        local picked = nil
        for _, card in ipairs(pool) do
            if not containsCard(chosen, card) then
                picked = card
                break
            end
        end

        if not picked then
            for _, card in ipairs(fallback) do
                if not containsCard(chosen, card) then
                    picked = card
                    break
                end
            end
        end

        if picked then
            chosen[#chosen + 1] = picked
        end
    end

    return chosen
end

function CardChoice:spawnBurst(x, y, count, speed)
    for i = 1, count do
        local angle = math.random() * math.pi * 2
        self.particles[#self.particles + 1] = {
            x = x,
            y = y,
            vx = math.cos(angle) * (speed or 95) * (0.45 + math.random() * 0.75),
            vy = math.sin(angle) * (speed or 95) * (0.45 + math.random() * 0.75),
            timer = 0,
            lifeTime = 0.28 + math.random() * 0.28,
            size = math.random(1, 2),
            color = colors[math.random(#colors)],
        }
    end
end

function CardChoice:start(worldX, worldY, options)
    options = options or {}
    self:load()
    self.active = true
    self.phase = "choosing"
    self.timer = 0
    self.sourceX = baseWidth / 2
    self.sourceY = baseHeight / 2

    if camera and worldX and worldY then
        local screenX, screenY = camera:worldToScreen(worldX, worldY)
        self.sourceX = (screenX - viewportOffsetX) / scale
        self.sourceY = (screenY - viewportOffsetY) / scale
    end

    local count = math.min(3, #self:getEligibleCards())
    local available = self:chooseCards(count, options)
    local cardWidth = fallbackCardImage:getWidth() * cardScale
    local spacing = cardWidth + cardPadding
    local firstX = baseWidth / 2 - (count - 1) * spacing / 2

    for i = 1, count do
        local card = available[i]
        self.cards[#self.cards + 1] = {
            def = card,
            x = self.sourceX,
            y = self.sourceY,
            startX = self.sourceX,
            startY = self.sourceY,
            targetX = firstX + (i - 1) * spacing,
            targetY = baseHeight / 2 - 66,
            timer = 0,
            delay = (i - 1) * 0.045,
            shufflePlayed = false,
            selected = false,
            hover = 0,
            wasHovered = false,
            tiltX = 0,
            tiltY = 0,
        }
    end

    self:spawnBurst(self.sourceX, self.sourceY, 36, 110)
    Dialog.breakMovements = true
end

function CardChoice:updateParticles(dt)
    for i = #self.particles, 1, -1 do
        local p = self.particles[i]
        p.timer = p.timer + dt
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.vx = p.vx * math.max(0, 1 - 3.2 * dt)
        p.vy = p.vy * math.max(0, 1 - 3.2 * dt)

        if p.timer >= p.lifeTime then
            table.remove(self.particles, i)
        end
    end
end

function CardChoice:update(dt)
    if not self.active then
        return
    end

    self.timer = self.timer + dt
    self:updateParticles(dt)
    local mouseX, mouseY = getMouseCanvasPosition()
    local previewCard = nil
    local strongestHover = 0

    for _, card in ipairs(self.cards) do
        card.timer = card.timer + dt
        local t = math.max(0, math.min((card.timer - card.delay) / 0.32, 1))
        if not card.shufflePlayed and t > 0 then
            card.shufflePlayed = true
            playSound(shuffleCardSoundBase, 0.36, 0.94 + math.random() * 0.12)
        end
        local eased = easeOut(t)
        card.x = card.startX + (card.targetX - card.startX) * eased
        card.y = card.startY + (card.targetY - card.startY) * eased

        local currentScale = card.selected and selectedCardScale or cardScale
        local cardImage = getCardBackImage(card.def)
        local halfW = cardImage:getWidth() * currentScale / 2
        local halfH = cardImage:getHeight() * currentScale / 2
        local dx = mouseX - card.x
        local dy = mouseY - card.y
        local outsideX = math.max(math.abs(dx) - halfW, 0)
        local outsideY = math.max(math.abs(dy) - halfH, 0)
        local outsideDistance = math.sqrt(outsideX * outsideX + outsideY * outsideY)
        local targetHover = self.phase == "choosing" and math.max(0, 1 - outsideDistance / hoverDistance) or 0
        local isHovered = targetHover > 0.72
        if isHovered and not card.wasHovered then
            playSound(singleCardSoundBase, 0.28, 1.12 + math.random() * 0.10)
        end
        card.wasHovered = isHovered
        card.hover = approach(card.hover or 0, targetHover, 9, dt)
        if card.hover > strongestHover then
            strongestHover = card.hover
            previewCard = card.def
        end
        card.tiltX = approach(card.tiltX or 0, clamp(dx / math.max(halfW, 1), -1, 1), 7, dt)
        card.tiltY = approach(card.tiltY or 0, clamp(dy / math.max(halfH, 1), -1, 1), 7, dt)
    end

    if self.phase == "choosing" then
        self.previewCard = strongestHover > 0.22 and previewCard or nil
    elseif self.phase == "celebrate" then
        self.previewCard = self.selectedCardDef
    end

    if self.phase == "celebrate" and self.timer >= 0.92 and #self.particles == 0 then
        self.active = false
        self.phase = "idle"
        self.previewCard = nil
        self.selectedCardDef = nil
        Dialog.breakMovements = false
    end
end

function CardChoice:choose(index)
    if not self.active or self.phase ~= "choosing" then
        return false
    end

    local card = self.cards[index]
    if not card then
        return false
    end

    self.selectedCardDef = card.def
    self.previewCard = card.def

    if card.def.apply then
        card.def.apply()
    end

    if Player and Player.startCardPickupFlash then
        Player:startCardPickupFlash()
    end

    self.phase = "celebrate"
    self.timer = 0
    self.cards = { card }
    card.targetX = baseWidth / 2
    card.targetY = baseHeight / 2 - 46
    card.startX = card.x
    card.startY = card.y
    card.timer = 0
    card.delay = 0
    card.selected = true
    self:spawnBurst(card.x, card.y, 44, 125)
    playSound(smoothCardSoundBase, 0.58, 1.22 + math.random() * 0.12)
    playSound(singleCardSoundBase, 0.72, 0.96 + math.random() * 0.08)

    if Game and Game.particles and Player then
        for i = 1, 12 do
            local angle = math.random() * math.pi * 2
            local lifetime = math.random(20, 34) / 100
            local particle = Ball:new(Player.x, Player.y, 14, math.cos(angle) * 0.75, math.sin(angle) * 0.75, lifetime, 0.55)
            table.insert(Game.particles, particle)
        end
    end

    return true
end

function CardChoice:keypressed(key)
    if key == "1" or key == "2" or key == "3" or key == "4" or key == "5" then
        return self:choose(tonumber(key))
    end
    return false
end

function CardChoice:mousepressed(x, y, button)
    if button ~= 1 then
        return false
    end

    for i, card in ipairs(self.cards) do
        local scale = cardScale * (1 + (card.hover or 0) * 0.08)
        local cardImage = getCardBackImage(card.def)
        local w = cardImage:getWidth() * scale
        local h = cardImage:getHeight() * scale
        if x >= card.x - w / 2 and x <= card.x + w / 2 and y >= card.y - h / 2 and y <= card.y + h / 2 then
            return self:choose(i)
        end
    end

    return false
end

function CardChoice:drawCard(card, index)
    local alpha = self.drawAlpha or 1
    local time = love.timer.getTime()
    local bob = math.sin(time * 1.4 + index) * 1.8
    local baseRot = math.sin(time * 0.85 + index * 0.7) * 0.025
    local hover = card.hover or 0
    local leanX = (card.tiltX or 0) * hover
    local leanY = (card.tiltY or 0) * hover
    local rot = baseRot + leanX * 0.12
    local shearX = leanX * 0.035
    local shearY = leanY * 0.022
    local scale = (card.selected and selectedCardScale or cardScale) * (1 + hover * 0.08)
    local x = card.x
    local y = card.y + bob - hover * 8
    local def = card.def
    local cardImage = getCardBackImage(def)
    local artImage = getCardArtImage(def)
    local cardW = cardImage:getWidth()
    local cardH = cardImage:getHeight()
    local screenCardW = math.floor(cardW * scale + 0.5)
    local screenCardH = math.floor(cardH * scale + 0.5)
    local textW = screenCardW - 20
    local rarity = CardDefinitions:getRarity(def)

    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(rot)
    love.graphics.scale(scale, scale)
    love.graphics.shear(shearX, shearY)
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.draw(cardImage, 0, 0, 0, 1, 1, cardW / 2, cardH / 2)
    if artImage then
        love.graphics.draw(artImage, 0, 0, 0, 1, 1, artImage:getWidth() / 2, artImage:getHeight() / 2)
    end
    love.graphics.pop()

    local textX = math.floor(x - textW / 2 + 0.5)
    local textLeanX = round(leanX * 4)
    local textLeanY = round(leanY * 2)
    local rarityX = math.floor(textX + textLeanX + 0.5)
    local nameX = math.floor(textX + 0.5)
    local amountX = math.floor(textX - textLeanX + 0.5)
    local rarityY = math.floor(y - screenCardH * 0.40 + 0.5) - textLeanY
    local nameY = math.floor(y - screenCardH * 0.08 + 0.5)
    local amountY = math.floor(y + screenCardH * 0.22 + 0.5) + textLeanY
    local fixedCardW = math.floor(cardW * cardScale + 0.5)
    local fixedCardH = math.floor(cardH * cardScale + 0.5)
    local descriptionW = fixedCardW
    local descriptionX = math.floor(x - descriptionW / 2 + 0.5)
    local descriptionY = math.floor((card.y + bob) + fixedCardH / 2 + 8 + 0.5)

    love.graphics.setFont(cardRarityFont)
    love.graphics.setColor(0.02, 0.01, 0.035, alpha)
    local rarityLabel = string.upper(CardDefinitions:getRarityLabel(def.rarity))
    local cardName = CardDefinitions:getCardName(def)
    local cardAmount = CardDefinitions:getCardAmount(def)
    local cardDescription = CardDefinitions:getCardDescription(def)

    love.graphics.setColor(rarity.color[1], rarity.color[2], rarity.color[3], alpha)
    love.graphics.printf(rarityLabel, rarityX, rarityY, textW, "center")

    love.graphics.setFont(cardNameFont)
    love.graphics.setColor(0.10, 0.035, 0.13, alpha)
    love.graphics.printf(cardName, nameX, nameY, textW, "center")

    love.graphics.setFont(cardAmountFont)
    love.graphics.setColor(0.22, 0.09, 0.13, alpha)
    love.graphics.printf(cardAmount, amountX, amountY, textW, "center")

    love.graphics.setFont(cardDescriptionFont)
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.printf(cardDescription, descriptionX, descriptionY, descriptionW, "center")
end

function CardChoice:draw()
    if not self.active then
        return
    end

    local fadeAlpha = 1
    if self.phase == "celebrate" and self.timer > 0.28 then
        fadeAlpha = math.max(0, 1 - (self.timer - 0.28) / 0.64)
    end

    love.graphics.setColor(0.02, 0.01, 0.04, 0.62 * fadeAlpha)
    love.graphics.rectangle("fill", 0, 0, baseWidth, baseHeight)

    for _, p in ipairs(self.particles) do
        local alpha = 1 - math.min(p.timer / p.lifeTime, 1)
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha * fadeAlpha)
        love.graphics.rectangle("fill", math.floor(p.x + 0.5), math.floor(p.y + 0.5), p.size, p.size)
    end

    love.graphics.setFont(titleFont)
    love.graphics.setColor(1, 1, 1, fadeAlpha)
    love.graphics.printf(Localization:t("cards.choose"), 0, 42, baseWidth, "center")

    self.drawAlpha = fadeAlpha
    for i, card in ipairs(self.cards) do
        self:drawCard(card, i)
    end
    self.drawAlpha = 1

    PlayerStatusHud:draw(baseWidth / 2 - 435, baseHeight - 220, {
        width = 870,
        height = 200,
        alpha = fadeAlpha,
        previewCard = self.phase == "choosing" and self.previewCard or nil,
        highlightCard = self.phase == "celebrate" and self.selectedCardDef or nil,
    })

    love.graphics.setColor(1, 1, 1, 1)
end

CardChoice:load()

return CardChoice
