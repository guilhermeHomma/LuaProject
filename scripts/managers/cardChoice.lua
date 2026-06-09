local CardChoice = {}

local Ball = require("scripts/particles/ballParticle")
local CardDefinitions = require("scripts/cards/cardDefinitions")
local PlayerStatusHud = require("scripts/ui/playerStatusHud")
local Localization = require("scripts/managers/localization")
local Fonts = require("scripts/ui/fonts")
local SelectCorners = require("scripts/ui/selectCorners")

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
local diamondParticleImage = loadCardImage("assets/sprites/ui/particles/diamond.png")
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
local diamondFrameSize = 16
local diamondFrameDuration = 0.10
local diamondFrameCount = math.max(1, math.floor(diamondParticleImage:getWidth() / diamondFrameSize))
local diamondParticleQuads = {}

for i = 1, diamondFrameCount do
    diamondParticleQuads[i] = love.graphics.newQuad(
        (i - 1) * diamondFrameSize,
        0,
        diamondFrameSize,
        diamondFrameSize,
        diamondParticleImage:getDimensions()
    )
end

local diamondParticleShader = love.graphics.newShader([[
    extern vec4 tintColor;

    vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
        vec4 pixel = Texel(tex, texture_coords);
        return pixel * color * tintColor;
    }
]])

diamondParticleShader:send("tintColor", {1, 1, 1, 1})

local diamondParticleConfigs = {
    rare = {
        count = 8,
        aboveCount = 2,
        rarityColor = {240 / 255, 160 / 255, 60 / 255, 1},
    },
    epic = {
        count = 12,
        aboveCount = 3,
        rarityColor = {220 / 255, 70 / 255, 140 / 255, 1},
        finalColor = {0x77 / 255, 0xe5 / 255, 0x36 / 255, 1},
    },
}

local diamondEdgesByCount = {
    [6] = {"left", "right", "left", "right", "top", "bottom"},
    [8] = {"left", "right", "left", "right", "left", "right", "top", "bottom"},
    [9] = {"left", "right", "left", "right", "left", "right", "top", "bottom", "bottom"},
}

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

local function lerpColor(fromColor, toColor, t)
    t = clamp(t or 0, 0, 1)
    return {
        fromColor[1] + (toColor[1] - fromColor[1]) * t,
        fromColor[2] + (toColor[2] - fromColor[2]) * t,
        fromColor[3] + (toColor[3] - fromColor[3]) * t,
        fromColor[4] + ((toColor[4] or 1) - (fromColor[4] or 1)) * t,
    }
end

local function applyDiamondColorVariation(color, variation)
    if not variation then
        return color
    end

    return {
        clamp(color[1] * variation[1], 0, 1),
        clamp(color[2] * variation[2], 0, 1),
        clamp(color[3] * variation[3], 0, 1),
        color[4] or 1,
    }
end

local function getDiamondParticleConfig(cardDef)
    local rarity = cardDef and cardDef.rarity
    return diamondParticleConfigs[rarity]
end

local function getDiamondParticleColor(particle, config)
    local whiteColor = {1, 1, 1, 1}
    local rarityColor = config.rarityColor
    local whiteBlendDuration = diamondFrameDuration * 2.4
    local whiteBlend = clamp(particle.timer / whiteBlendDuration, 0, 1)

    if not config.finalColor then
        return lerpColor(whiteColor, rarityColor, whiteBlend)
    end

    local migrationStart = (diamondFrameCount - 3) * diamondFrameDuration
    if particle.timer < migrationStart then
        return lerpColor(whiteColor, rarityColor, whiteBlend)
    end

    local migrationTime = math.max(diamondFrameDuration * 3, 0.01)
    local t = (particle.timer - migrationStart) / migrationTime
    return lerpColor(rarityColor, config.finalColor, t)
end

local function getDiamondEdgeSequence(count)
    if diamondEdgesByCount[count] then
        return diamondEdgesByCount[count]
    end

    local edges = {}
    for i = 1, count do
        edges[i] = (i % 4 == 1 and "left")
            or (i % 4 == 2 and "right")
            or (i % 4 == 3 and "top")
            or "bottom"
    end
    return edges
end

local function getCardBackImage(cardDef)
    local rarityId = cardDef and cardDef.rarity or "common"
    return cardBackImages[rarityId] or fallbackCardImage
end

local function getCardScreenBounds(card, useSelectedScale)
    local cardImage = getCardBackImage(card.def)
    local hover = card.hover or 0
    local scale = (useSelectedScale and selectedCardScale or cardScale) * (1 + hover * 0.08)
    local w = cardImage:getWidth() * scale
    local h = cardImage:getHeight() * scale
    return {
        x = card.x,
        y = card.y,
        w = w,
        h = h,
        scale = scale,
    }
end

local function getEdgePoint(bounds, edge, edgeT, centerInset)
    local t = clamp(edgeT or math.random(), 0.08, 0.92)
    local x, y

    if edge == "left" then
        x = bounds.x - bounds.w * 0.5 + centerInset
        y = bounds.y - bounds.h * 0.5 + bounds.h * t
    elseif edge == "right" then
        x = bounds.x + bounds.w * 0.5 - centerInset
        y = bounds.y - bounds.h * 0.5 + bounds.h * t
    elseif edge == "top" then
        x = bounds.x - bounds.w * 0.5 + bounds.w * t
        y = bounds.y - bounds.h * 0.5 + centerInset
    else
        x = bounds.x - bounds.w * 0.5 + bounds.w * t
        y = bounds.y + bounds.h * 0.5 - centerInset
    end

    return x, y
end

local function addEdgeJitter(x, y, edge, bounds)
    local verticalEdge = edge == "left" or edge == "right"
    local longJitter = verticalEdge and bounds.h * 0.035 or bounds.w * 0.035
    local shortJitter = 4

    if verticalEdge then
        return x + (math.random() * 2 - 1) * shortJitter, y + (math.random() * 2 - 1) * longJitter
    end

    return x + (math.random() * 2 - 1) * longJitter, y + (math.random() * 2 - 1) * shortJitter
end

local function getEdgeAngle(edge, inward)
    local angle = 0
    if edge == "left" then
        angle = math.pi
    elseif edge == "right" then
        angle = 0
    elseif edge == "top" then
        angle = -math.pi * 0.5
    else
        angle = math.pi * 0.5
    end

    if inward then
        angle = angle + math.pi
    end

    return angle
end

local function playSound(baseSource, volume, pitch)
    local sound = baseSource:clone()
    sound:setVolume(volume or 1)
    sound:setPitch((pitch or 1) * (GAME_PITCH or 1))
    sound:play()
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

function CardChoice:spawnDiamondParticle(card, layer, edge, edgeT, initialTimer)
    local config = getDiamondParticleConfig(card.def)
    if not config then
        return
    end

    local bounds = getCardScreenBounds(card, card.selected == true)
    local centerInset = math.min(bounds.w * 0.075, bounds.h * 0.055)
    local x, y = getEdgePoint(bounds, edge, edgeT, centerInset)
    x, y = addEdgeJitter(x, y, edge, bounds)
    local spread = math.pi * 0.5
    local angle = getEdgeAngle(edge, false) + (math.random() * 2 - 1) * spread * 0.5
    local speed = layer == "above" and (20 + math.random() * 10) or (14 + math.random() * 10)
    local list = layer == "above" and card.diamondParticlesAbove or card.diamondParticlesBehind

    list[#list + 1] = {
        x = x,
        y = y,
        vx = math.cos(angle) * speed,
        vy = math.sin(angle) * speed,
        timer = initialTimer or 0,
        lifeTime = diamondFrameCount * diamondFrameDuration,
        scale = bounds.scale,
        colorVariation = math.random() < 0.5 and {
            0.92 + math.random() * 0.16,
            0.92 + math.random() * 0.16,
            0.92 + math.random() * 0.16,
        } or nil,
    }
end

function CardChoice:ensureDiamondParticles(card, layer, targetCount, initialFill)
    local list = layer == "above" and card.diamondParticlesAbove or card.diamondParticlesBehind
    local edges = getDiamondEdgeSequence(targetCount)

    while #list < targetCount do
        local spawnIndex = (card.diamondSpawnIndex or 0) + 1
        card.diamondSpawnIndex = spawnIndex
        local edge = edges[((spawnIndex - 1) % #edges) + 1]
        local edgeT = (spawnIndex * 0.61803398875 + math.random() * 0.22) % 1
        edgeT = clamp(edgeT, 0.10, 0.90)
        local initialTimer = initialFill and math.random() * diamondFrameCount * diamondFrameDuration * 0.72 or 0
        self:spawnDiamondParticle(card, layer, edge, edgeT, initialTimer)
    end
end

function CardChoice:updateDiamondParticleList(list, dt, anchorDx, anchorDy)
    anchorDx = anchorDx or 0
    anchorDy = anchorDy or 0

    for i = #list, 1, -1 do
        local p = list[i]
        p.timer = p.timer + dt
        p.x = p.x + anchorDx + p.vx * dt
        p.y = p.y + anchorDy + p.vy * dt

        if p.timer >= p.lifeTime then
            table.remove(list, i)
        end
    end
end

function CardChoice:updateCardDiamondParticles(card, dt, anchorDx, anchorDy)
    local config = getDiamondParticleConfig(card.def)
    if not config then
        card.diamondParticlesBehind = nil
        card.diamondParticlesAbove = nil
        return
    end

    card.diamondParticlesBehind = card.diamondParticlesBehind or {}
    card.diamondParticlesAbove = card.diamondParticlesAbove or {}

    self:updateDiamondParticleList(card.diamondParticlesBehind, dt, anchorDx, anchorDy)
    self:updateDiamondParticleList(card.diamondParticlesAbove, dt, anchorDx, anchorDy)

    local aboveCount = config.aboveCount or 0
    local behindCount = math.max(0, (config.count or 0) - aboveCount)
    local initialFill = not card.diamondParticlesInitialized
    self:ensureDiamondParticles(card, "behind", behindCount, initialFill)
    self:ensureDiamondParticles(card, "above", aboveCount, initialFill)
    card.diamondParticlesInitialized = true
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
        local previousCardX = card.x
        local previousCardY = card.y
        card.x = card.startX + (card.targetX - card.startX) * eased
        card.y = card.startY + (card.targetY - card.startY) * eased
        local particleAnchorDx = card.x - (previousCardX or card.x)
        local particleAnchorDy = card.y - (previousCardY or card.y)

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
        local selectActive = card.selected or card.hover > 0.22
        if selectActive and not card.selectActive then
            card.selectStartTime = love.timer.getTime()
        end
        card.selectActive = selectActive
        if card.hover > strongestHover then
            strongestHover = card.hover
            previewCard = card.def
        end
        card.tiltX = approach(card.tiltX or 0, clamp(dx / math.max(halfW, 1), -1, 1), 7, dt)
        card.tiltY = approach(card.tiltY or 0, clamp(dy / math.max(halfH, 1), -1, 1), 7, dt)
        self:updateCardDiamondParticles(card, dt, particleAnchorDx, particleAnchorDy)
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
    card.diamondParticlesBehind = nil
    card.diamondParticlesAbove = nil
    card.diamondParticlesInitialized = false
    card.diamondSpawnIndex = 0
    card.selectActive = true
    card.selectStartTime = love.timer.getTime()
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

function CardChoice:drawDiamondParticles(card, layer, alpha)
    local config = getDiamondParticleConfig(card.def)
    if not config then
        return
    end

    local list = layer == "above" and card.diamondParticlesAbove or card.diamondParticlesBehind
    if not list or #list == 0 then
        return
    end

    local previousShader = love.graphics.getShader()
    love.graphics.setShader(diamondParticleShader)

    for _, p in ipairs(list) do
        local frame = math.min(diamondFrameCount, math.floor(p.timer / diamondFrameDuration) + 1)
        local frameAlpha = math.max(0, 1 - math.max(0, p.timer - p.lifeTime + diamondFrameDuration * 1.5) / (diamondFrameDuration * 1.5))
        local tint = applyDiamondColorVariation(getDiamondParticleColor(p, config), p.colorVariation)
        diamondParticleShader:send("tintColor", {
            tint[1],
            tint[2],
            tint[3],
            (tint[4] or 1) * (alpha or 1) * frameAlpha,
        })
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(
            diamondParticleImage,
            diamondParticleQuads[frame],
            math.floor(p.x + 0.5),
            math.floor(p.y + 0.5),
            0,
            p.scale,
            p.scale,
            diamondFrameSize / 2,
            diamondFrameSize / 2
        )
    end

    love.graphics.setShader(previousShader)
    love.graphics.setColor(1, 1, 1, 1)
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

    self:drawDiamondParticles(card, "behind", alpha)

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

    self:drawDiamondParticles(card, "above", alpha)
    if card.selectActive then
        SelectCorners.draw({
            left = x - screenCardW / 2,
            top = y - screenCardH / 2,
            width = screenCardW,
            height = screenCardH,
        }, {
            startedAt = card.selectStartTime,
            scale = 3.2,
            padding = 2,
            alpha = alpha,
            color = {0.96, 0.93, 0.72, 1},
        })
    end
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
