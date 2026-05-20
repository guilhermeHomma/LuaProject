local CardChoice = {}

local Ball = require("scripts/particles/ballParticle")
local CardDefinitions = require("scripts/cards/cardDefinitions")

local cardImage = love.graphics.newImage("assets/sprites/ui/cards/card.png")
cardImage:setFilter("nearest", "nearest")

local titleFont = love.graphics.newFont("assets/fonts/ThaleahFat.ttf", 38)
local cardNameFont = love.graphics.newFont("assets/fonts/pixelart.ttf", 26)
local cardRarityFont = love.graphics.newFont("assets/fonts/pixelart.ttf", 16)
local cardAmountFont = love.graphics.newFont("assets/fonts/PixelGame.otf", 29)
local cardDescriptionFont = love.graphics.newFont("assets/fonts/pixelart.ttf", 14)
titleFont:setFilter("nearest", "nearest")
cardNameFont:setFilter("nearest", "nearest")
cardRarityFont:setFilter("nearest", "nearest")
cardAmountFont:setFilter("nearest", "nearest")
cardDescriptionFont:setFilter("nearest", "nearest")

local colors = {
    {0.48, 0.04, 0.18, 1},
    {0.04, 0.32, 0.38, 1},
    {0.46, 0.28, 0.02, 1},
    {0.08, 0.34, 0.16, 1},
    {0.32, 0.08, 0.48, 1},
}

local cardScale = 3.1875
local selectedCardScale = 3.5
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

local function getMouseCanvasPosition()
    local mx, my = love.mouse.getPosition()
    return (mx - viewportOffsetX) / scale, (my - viewportOffsetY) / scale
end

local function approach(value, target, speed, dt)
    return value + (target - value) * math.min(speed * dt, 1)
end

function CardChoice:load()
    self.active = false
    self.cards = {}
    self.particles = {}
    self.timer = 0
    self.phase = "idle"
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

function CardChoice:start(worldX, worldY)
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

    local available = self:getEligibleCards()
    shuffle(available)

    local count = math.min(3, #available)
    local cardWidth = cardImage:getWidth() * cardScale
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
            selected = false,
            hover = 0,
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

    for _, card in ipairs(self.cards) do
        card.timer = card.timer + dt
        local t = math.max(0, math.min((card.timer - card.delay) / 0.32, 1))
        local eased = easeOut(t)
        card.x = card.startX + (card.targetX - card.startX) * eased
        card.y = card.startY + (card.targetY - card.startY) * eased

        local currentScale = card.selected and selectedCardScale or cardScale
        local halfW = cardImage:getWidth() * currentScale / 2
        local halfH = cardImage:getHeight() * currentScale / 2
        local dx = mouseX - card.x
        local dy = mouseY - card.y
        local outsideX = math.max(math.abs(dx) - halfW, 0)
        local outsideY = math.max(math.abs(dy) - halfH, 0)
        local outsideDistance = math.sqrt(outsideX * outsideX + outsideY * outsideY)
        local targetHover = self.phase == "choosing" and math.max(0, 1 - outsideDistance / hoverDistance) or 0
        card.hover = approach(card.hover or 0, targetHover, 9, dt)
        card.tiltX = approach(card.tiltX or 0, clamp(dx / math.max(halfW, 1), -1, 1), 7, dt)
        card.tiltY = approach(card.tiltY or 0, clamp(dy / math.max(halfH, 1), -1, 1), 7, dt)
    end

    if self.phase == "celebrate" and self.timer >= 0.48 and #self.particles == 0 then
        self.active = false
        self.phase = "idle"
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

    if card.def.apply then
        card.def.apply()
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
        local w = cardImage:getWidth() * scale
        local h = cardImage:getHeight() * scale
        if x >= card.x - w / 2 and x <= card.x + w / 2 and y >= card.y - h / 2 and y <= card.y + h / 2 then
            return self:choose(i)
        end
    end

    return false
end

function CardChoice:drawCard(card, index)
    local time = love.timer.getTime()
    local bob = math.sin(time * 1.4 + index) * 1.8
    local baseRot = math.sin(time * 0.85 + index * 0.7) * 0.025
    local hover = card.hover or 0
    local rot = baseRot + (card.tiltX or 0) * 0.11 * hover
    local scale = (card.selected and selectedCardScale or cardScale) * (1 + hover * 0.08)
    local x = card.x
    local y = card.y + bob - hover * 8
    local def = card.def
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
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(cardImage, 0, 0, 0, 1, 1, cardW / 2, cardH / 2)
    love.graphics.pop()

    local textX = math.floor(x - textW / 2 + 0.5)
    local rarityY = math.floor(y - screenCardH * 0.40 + 0.5)
    local nameY = math.floor(y - screenCardH * 0.11 + 0.5)
    local amountY = math.floor(y + screenCardH * 0.22 + 0.5)
    local descriptionW = screenCardW
    local descriptionX = math.floor(x - descriptionW / 2 + 0.5)
    local descriptionY = math.floor(y + screenCardH / 2 + 8 + 0.5)

    love.graphics.setFont(cardRarityFont)
    love.graphics.setColor(0.02, 0.01, 0.035, 1)
    love.graphics.printf(string.upper(rarity.label), textX + 1, rarityY + 1, textW, "center")
    love.graphics.setColor(rarity.color[1], rarity.color[2], rarity.color[3], 1)
    love.graphics.printf(string.upper(rarity.label), textX, rarityY, textW, "center")

    love.graphics.setFont(cardNameFont)
    love.graphics.setColor(0.02, 0.01, 0.035, 1)
    love.graphics.printf(def.name, textX + 1, nameY + 1, textW, "center")
    love.graphics.setColor(0.10, 0.035, 0.13, 1)
    love.graphics.printf(def.name, textX, nameY, textW, "center")

    love.graphics.setFont(cardAmountFont)
    love.graphics.setColor(0.02, 0.01, 0.035, 1)
    love.graphics.printf(def.amount, textX + 1, amountY + 1, textW, "center")
    love.graphics.setColor(0.22, 0.09, 0.13, 1)
    love.graphics.printf(def.amount, textX, amountY, textW, "center")

    love.graphics.setFont(cardDescriptionFont)
    love.graphics.setColor(0.02, 0.01, 0.035, 1)
    love.graphics.printf(def.description, descriptionX + 1, descriptionY + 1, descriptionW, "center")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(def.description, descriptionX, descriptionY, descriptionW, "center")
end

function CardChoice:draw()
    if not self.active then
        return
    end

    love.graphics.setColor(0.02, 0.01, 0.04, 0.62)
    love.graphics.rectangle("fill", 0, 0, baseWidth, baseHeight)

    for _, p in ipairs(self.particles) do
        local alpha = 1 - math.min(p.timer / p.lifeTime, 1)
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)
        love.graphics.rectangle("fill", math.floor(p.x + 0.5), math.floor(p.y + 0.5), p.size, p.size)
    end

    love.graphics.setFont(titleFont)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("CHOOSE A CARD", 0, 42, baseWidth, "center")

    for i, card in ipairs(self.cards) do
        self:drawCard(card, i)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

CardChoice:load()

return CardChoice
