local DamageNumber = {}
DamageNumber.__index = DamageNumber

local DamagePixel = {}
DamagePixel.__index = DamagePixel
local PickupNumber = {}
PickupNumber.__index = PickupNumber

local Ball = require("scripts/particles/ballParticle")
local damageEnabled = false
local pickupMergeWindow = 0.24
local pickupMergeDistance = 28
local itemParticleImage = love.graphics.newImage("assets/sprites/particles/itemparticle.png")
itemParticleImage:setFilter("nearest", "nearest")
local itemParticleFrameSize = 16
local itemParticleFrameCount = itemParticleImage:getWidth() / itemParticleFrameSize
local itemParticleDuration = 0.16
local itemParticleQuads = {}

for frame = 1, itemParticleFrameCount do
    itemParticleQuads[frame] = love.graphics.newQuad(
        (frame - 1) * itemParticleFrameSize,
        0,
        itemParticleFrameSize,
        itemParticleFrameSize,
        itemParticleImage:getDimensions()
    )
end

local palette = {
    {0.80, 0.32, 0.22, 1}, -- strong red
    {0.70, 0.30, 0.00, 1}, -- orange
    {0.97, 0.97, 0.97, 1}, -- white
    {0.70, 0.78, 0.10, 1}, -- yellow
    {0.97, 0.97, 0.97, 1}, -- white
}

local coinPalette = {
    {1.00, 1.00, 1.00, 1},
    {1.00, 0.96, 0.16, 1},
    {1.00, 0.84, 0.00, 1},
    {1.00, 1.00, 1.00, 1},
    {1.00, 0.72, 0.00, 1},
    {0.95, 0.56, 0.00, 1},
}

local lifePalette = {
    {1.00, 0.04, 0.14, 1},
    {1.00, 0.22, 0.42, 1},
    {1.00, 0.42, 0.70, 1},
    {0.82, 0.04, 0.28, 1},
    {1.00, 0.90, 0.96, 1},
    {1.00, 1.00, 1.00, 1},
}

local digitPatterns = {
    ["+"] = {"00100", "00100", "11111", "00100", "00100"},
    ["0"] = {"11111", "10011", "10101", "11001", "11111"},
    ["1"] = {"00100", "01100", "00100", "00100", "01110"},
    ["2"] = {"11110", "00001", "01110", "10000", "11111"},
    ["3"] = {"11111", "00001", "01110", "00001", "11111"},
    ["4"] = {"10000", "10100", "10100", "11110", "00100"},
    ["5"] = {"11111", "10000", "11110", "00001", "11110"},
    ["6"] = {"11111", "10000", "11111", "10001", "11111"},
    ["7"] = {"11111", "00001", "00010", "00100", "00100"},
    ["8"] = {"11111", "10001", "11111", "10001", "11111"},
    ["9"] = {"11111", "10001", "11111", "00001", "11111"},
}

local pickupDigitPatterns = {
    ["+"] = {"010", "010", "111", "010", "010"},
    ["."] = {"000", "000", "000", "000", "010"},
    ["0"] = {"111", "101", "101", "101", "111"},
    ["1"] = {"010", "110", "010", "010", "111"},
    ["2"] = {"111", "001", "111", "100", "111"},
    ["3"] = {"111", "001", "111", "001", "111"},
    ["4"] = {"101", "101", "111", "001", "001"},
    ["5"] = {"111", "100", "111", "001", "111"},
    ["6"] = {"111", "100", "111", "101", "111"},
    ["7"] = {"111", "001", "010", "010", "010"},
    ["8"] = {"111", "101", "111", "101", "111"},
    ["9"] = {"111", "101", "111", "001", "111"},
}

local digitWidth = 5
local pickupDigitWidth = 3
local digitHeight = 5
local pixelSize = 1
local digitSpacing = 1

local function colorAt(timer, offset)
    local index = (math.floor((timer or 0) * 34 + (offset or 0)) % #palette) + 1
    return palette[index]
end

local function colorFrom(colors, timer, offset)
    colors = colors or palette
    local index = (math.floor((timer or 0) * 14 + (offset or 0)) % #colors) + 1
    return colors[index]
end

local function addParticle(particle)
    if Game and Game.particles then
        table.insert(Game.particles, particle)
    end
end

local function textWidth(text)
    return #text * digitWidth + math.max(#text - 1, 0) * digitSpacing
end

local function drawDigits(text, x, y, color, scaleX, scaleY)
    scaleX = scaleX or 1
    scaleY = scaleY or scaleX
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)

    local cursorX = x
    for i = 1, #text do
        local pattern = digitPatterns[text:sub(i, i)]
        if pattern then
            for row = 1, digitHeight do
                local line = pattern[row]
                for col = 1, digitWidth do
                    if line:sub(col, col) == "1" then
                        love.graphics.rectangle(
                            "fill",
                            cursorX + (col - 1) * pixelSize * scaleX,
                            y + (row - 1) * pixelSize * scaleY,
                            pixelSize * scaleX,
                            pixelSize * scaleY
                        )
                    end
                end
            end
        end
        cursorX = cursorX + (digitWidth + digitSpacing) * pixelSize * scaleX
    end
end

local function pickupTextWidth(text, scale)
    scale = scale or 1
    return (#text * pickupDigitWidth + math.max(#text - 1, 0) * digitSpacing) * scale
end

local function drawPickupDigits(text, x, y, color, scale)
    scale = scale or 1
    love.graphics.setColor(color[1], color[2], color[3], 1)

    local cursorX = x
    for i = 1, #text do
        local pattern = pickupDigitPatterns[text:sub(i, i)]
        if pattern then
            for row = 1, digitHeight do
                local line = pattern[row]
                for col = 1, pickupDigitWidth do
                    if line:sub(col, col) == "1" then
                        love.graphics.rectangle(
                            "fill",
                            cursorX + (col - 1) * scale,
                            y + (row - 1) * scale,
                            scale,
                            scale
                        )
                    end
                end
            end
        end
        cursorX = cursorX + (pickupDigitWidth + digitSpacing) * scale
    end
end

local function drawPickupDigitBlock(text, x, y, color, scale)
    scale = scale or 1
    drawPickupDigits(text, x + scale, y, {0.05, 0.00, 0.04, 1}, scale)
    drawPickupDigits(text, x, y + scale, {0.05, 0.00, 0.04, 1}, scale)
    drawPickupDigits(text, x, y, color, scale)
end

local function drawDigitBlock(text, x, y, color, scaleX, scaleY, outlineMode)
    if outlineMode == "bottomRight" then
        drawDigits(text, x + 1, y, {0.05, 0.00, 0.04, 1}, scaleX, scaleY)
        drawDigits(text, x, y + 1, {0.05, 0.00, 0.04, 1}, scaleX, scaleY)
    else
        drawDigits(text, x - 1, y, {0.05, 0.00, 0.04, 1}, scaleX, scaleY)
        drawDigits(text, x + 1, y, {0.05, 0.00, 0.04, 1}, scaleX, scaleY)
        drawDigits(text, x, y - 1, {0.05, 0.00, 0.04, 1}, scaleX, scaleY)
        drawDigits(text, x, y + 1, {0.05, 0.00, 0.04, 1}, scaleX, scaleY)
    end
    drawDigits(text, x, y, color, scaleX, scaleY)
end

local function drawConfettiText(text, x, y, colors, timer, scaleX, scaleY, outlineMode)
    local charStep = (digitWidth + digitSpacing) * pixelSize * scaleX

    for i = 1, #text do
        local char = text:sub(i, i)
        local charTimer = timer - (i - 1) * 0.045

        if charTimer >= 0 then
            local popProgress = math.min(charTimer / 0.16, 1)
            local floatProgress = math.min(charTimer / 0.26, 1)
            local popOffset = math.floor(math.sin(popProgress * math.pi) * 2 + 0.5)
            local riseOffset = math.floor(floatProgress * 5 + 0.5)
            local charX = math.floor(x + (i - 1) * charStep + 0.5)
            local charY = math.floor(y - popOffset - riseOffset + 0.5)
            local color = colorFrom(colors, timer + i * 0.09, i * 2)

            drawDigitBlock(char, charX, charY, color, scaleX, scaleY, outlineMode)
        end
    end
end

local function drawPickupConfettiText(text, x, y, colors, timer, scale)
    scale = scale or 1
    local charStep = (pickupDigitWidth + digitSpacing) * scale

    for i = 1, #text do
        local char = text:sub(i, i)
        local charTimer = timer - (i - 1) * 0.045

        if charTimer >= 0 then
            local popProgress = math.min(charTimer / 0.16, 1)
            local floatProgress = math.min(charTimer / 0.26, 1)
            local popOffset = math.floor(math.sin(popProgress * math.pi) * 1 + 0.5)
            local riseOffset = math.floor(floatProgress * 4 + 0.5)
            local charX = math.floor(x + (i - 1) * charStep + 0.5)
            local charY = math.floor(y - popOffset - riseOffset + 0.5)
            local color = colorFrom(colors, timer + i * 0.09, i * 2)

            drawPickupDigitBlock(char, charX, charY, color, scale)
        end
    end
end

function DamagePixel:new(x, y, height, colorOffset, index, count)
    local centerIndex = ((index or 1) - ((count or 1) + 1) / 2)
    local spread = count and centerIndex / math.max(count - 1, 1) or 0
    local angle = -math.pi / 2 + spread * 0.95
    local pixel = setmetatable({}, DamagePixel)

    pixel.x = math.floor(x + 0.5)
    pixel.y = math.floor(y + 0.5)
    pixel.height = height or 0
    pixel.vx = math.cos(angle) * (0.8 + math.random() * 0.6)
    pixel.vy = math.sin(angle) * (0.5 + math.random() * 0.4) * 0.16
    pixel.ax = math.cos(angle) * (7 + math.random() * 4)
    pixel.ay = math.sin(angle) * (0.6 + math.random() * 0.5)
    pixel.heightVelocity = 1.4 + math.random() * 1.2
    pixel.heightAccel = 5 + math.random() * 4
    pixel.blinkRate = 0.08
    pixel.timer = 0
    pixel.lifeTime = 0.26 + ((index or 1) - 1) * 0.055
    pixel.colorOffset = colorOffset or math.random(0, #palette - 1)
    pixel.palette = palette
    pixel.isAlive = true
    return pixel
end

function DamagePixel:update(dt)
    addToDrawQueue(self.y + 17, self)
    self.timer = self.timer + dt

    self.vx = self.vx + self.ax * dt
    self.vy = self.vy + self.ay * dt
    self.heightVelocity = self.heightVelocity + self.heightAccel * dt
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt
    self.height = self.height + self.heightVelocity * dt

    if self.timer >= self.lifeTime then
        self.isAlive = false
    end
end

function DamagePixel:drawShadow()
end

function DamagePixel:draw()
    local blinkStep = math.floor(self.timer / self.blinkRate)
    if blinkStep % 4 == 1 then
        return
    end

    local color = colorFrom(self.palette, self.timer, self.colorOffset)
    love.graphics.setColor(color[1], color[2], color[3], 1)
    love.graphics.rectangle("fill", math.floor(self.x + 0.5), math.floor(self.y - self.height + 0.5), 1, 1)
    love.graphics.setColor(1, 1, 1, 1)
end

function DamageNumber:new(x, y, height, amount)
    local number = setmetatable({}, DamageNumber)
    number.x = x
    number.y = y
    number.height = (height or 0) + 4
    number.amount = tostring(math.floor((amount or 0) + 0.5))
    number.timer = 0
    number.lifeTime = 0.38
    number.popDuration = 0.08
    number.floatSpeed = 14 + math.random() * 3
    number.sideDrift = (math.random() * 2 - 1) * 3
    number.wobblePhase = math.random() * math.pi * 2
    number.spawnedPixels = false
    number.isAlive = true
    return number
end

function DamageNumber:burstPixels()
    if self.spawnedPixels then
        return
    end

    self.spawnedPixels = true
    local count = math.min(7, math.max(4, #self.amount + 3))
    local centerX = math.floor(self.x + 0.5)
    local centerY = math.floor(self.y - self.height + 0.5)

    for i = 1, count do
        addParticle(DamagePixel:new(centerX, centerY, 0, i, i, count))
    end
end

function DamageNumber:update(dt)
    addToDrawQueue(self.y + 14, self)
    self.timer = self.timer + dt
    self.height = self.height + self.floatSpeed * dt
    self.x = self.x + self.sideDrift * dt + math.sin(self.wobblePhase + self.timer * 16) * dt * 2

    if self.timer >= self.lifeTime then
        self:burstPixels()
        self.isAlive = false
    end
end

function DamageNumber:drawShadow()
end

function DamageNumber:draw()
    local progress = math.min(self.timer / self.lifeTime, 1)
    local blink = math.floor(self.timer * 42) % 2 == 0
    local color = colorAt(self.timer, self.amount:len())
    local scaleX = 0.9
    local scaleY = scaleX * 1.4
    local width = textWidth(self.amount) * scaleX
    local height = digitHeight * scaleY
    local drawX = math.floor(self.x - width / 2 + 0.5)
    local drawY = math.floor(self.y - self.height - height / 2 + 0.5)
    local popOffset = 0

    if self.timer < self.popDuration then
        popOffset = math.floor(math.sin((self.timer / self.popDuration) * math.pi) * 2 + 0.5)
    end

    if progress > 0.82 and not blink then
        return
    end

    drawDigits(self.amount, drawX - 1, drawY - popOffset, {0.05, 0.00, 0.04, 1}, scaleX, scaleY)
    drawDigits(self.amount, drawX + 1, drawY - popOffset, {0.05, 0.00, 0.04, 1}, scaleX, scaleY)
    drawDigits(self.amount, drawX, drawY - 1 - popOffset, {0.05, 0.00, 0.04, 1}, scaleX, scaleY)
    drawDigits(self.amount, drawX, drawY + 1 - popOffset, {0.05, 0.00, 0.04, 1}, scaleX, scaleY)
    drawDigits(self.amount, drawX, drawY - popOffset, color, scaleX, scaleY)
    love.graphics.setColor(1, 1, 1, 1)
end

function DamageNumber.spawn(x, y, height, amount)
    if not damageEnabled or not (Game and Game.particles and x and y) then
        return
    end

    addParticle(DamageNumber:new(x, y, height or 0, amount or 0))
end

function DamageNumber.setDamageEnabled(enabled)
    damageEnabled = enabled == true
end

function PickupNumber:new(x, y, height, text, colors, options)
    local pickup = setmetatable({}, PickupNumber)
    options = options or {}
    pickup.x = x
    pickup.y = y
    pickup.height = height or 0
    pickup.amount = tostring(text or "+1")
    pickup.value = options.value or tonumber((pickup.amount:gsub("^%+", ""))) or 0
    pickup.kind = options.kind or "coin"
    pickup.decimals = options.decimals or 0
    pickup.palette = colors or coinPalette
    pickup.timer = 0
    pickup.lifeTime = options.lifeTime or 0.46
    pickup.popDuration = 0.09
    pickup.floatSpeed = options.floatSpeed or 18
    pickup.spawnedPixels = false
    pickup.spawnedBalls = false
    pickup.isAlive = true
    return pickup
end

local function formatPickupText(value, decimals)
    if (decimals or 0) > 0 then
        local text = string.format("%." .. decimals .. "f", value or 0)
        text = text:gsub("0+$", ""):gsub("%.$", "")
        return "+" .. text
    end

    return "+" .. tostring(math.floor((value or 0) + 0.5))
end

function PickupNumber:merge(x, y, height, value)
    local currentValue = self.value or tonumber((self.amount:gsub("^%+", ""))) or 0
    local addedValue = value or 0
    local total = currentValue + addedValue

    self.value = total
    self.amount = formatPickupText(total, self.decimals or 0)
    self.x = (self.x + (x or self.x)) / 2
    self.y = (self.y + (y or self.y)) / 2
    self.height = math.max(self.height or 0, height or 0)
    self.timer = math.min(self.timer, 0.08)
    self.lifeTime = math.max(self.lifeTime or 0.46, self.timer + 0.38)
    self.spawnedPixels = false
end

function PickupNumber:burstBalls()
    if self.spawnedBalls then
        return
    end

    self.spawnedBalls = true
    for i = 1, 3 do
        local angle = math.random() * math.pi * 2
        local dx = math.cos(angle) * 0.45
        local dy = math.sin(angle) * 0.45
        local lifetime = math.random(18, 26) / 100
        local size = math.random(4, 6) / 10
        table.insert(Game.particles, Ball:new(self.x, self.y, self.height, dx, dy, lifetime, size))
        table.insert(Game.particles, Ball:new(self.x, self.y, self.height, -dx, -dy, lifetime, size))
    end
end

function PickupNumber:burstPixels()
    if self.spawnedPixels then
        return
    end

    self.spawnedPixels = true
    local count = 12
    local centerX = math.floor(self.x + 0.5)
    local centerY = math.floor(self.y - self.height + 0.5)

    for i = 1, count do
        local pixel = DamagePixel:new(centerX, centerY, 0, i, i, count)
        pixel.palette = self.palette
        pixel.lifeTime = 0.32 + (i - 1) * 0.035
        addParticle(pixel)
    end
end

function PickupNumber:update(dt)
    addToDrawQueue(self.y + 19, self)
    self.timer = self.timer + dt
    self.height = self.height + self.floatSpeed * dt

    if self.timer >= 0.06 then
        self:burstBalls()
    end

    if self.timer >= self.lifeTime then
        self:burstPixels()
        self.isAlive = false
    end
end

function PickupNumber:drawShadow()
end

function PickupNumber:draw()
    local showNumber = self.timer >= 0.04
    local growProgress = math.min(self.timer / (self.popDuration or 0.09), 1)
    local growWave = math.sin(growProgress * math.pi)
    local scale = 0.62 + 0.38 * growProgress + 0.12 * growWave
    local width = pickupTextWidth(self.amount, scale)
    local height = digitHeight * scale
    local drawX = math.floor(self.x - width / 2 + 0.5)
    local drawY = math.floor(self.y - self.height - height / 2 + 0.5)
    if self.timer < itemParticleDuration then
        local frameIndex = math.floor((self.timer / itemParticleDuration) * itemParticleFrameCount) + 1

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(
            itemParticleImage,
            itemParticleQuads[frameIndex],
            math.floor(self.x + 0.5),
            math.floor(self.y - self.height + 0.5),
            0,
            1,
            1.3,
            itemParticleFrameSize / 2,
            itemParticleFrameSize / 2
        )
    end

    if showNumber then
        drawPickupConfettiText(self.amount, drawX, drawY, self.palette, self.timer - 0.04, scale)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function DamageNumber.spawnPickup(x, y, height, text, kind, options)
    if not (Game and Game.particles and x and y) then
        return
    end

    options = options or {}
    local colors = kind == "life" and lifePalette or coinPalette
    local value = options.value or tonumber((tostring(text or "+1"):gsub("^%+", ""))) or 0
    local decimals = options.decimals or (kind == "life" and 1 or 0)

    for _, particle in ipairs(Game.particles) do
        if getmetatable(particle) == PickupNumber
            and particle.isAlive
            and particle.kind == (kind or "coin")
            and (particle.timer or 0) <= pickupMergeWindow then
            local dx = (particle.x or x) - x
            local dy = (particle.y or y) - y
            if dx * dx + dy * dy <= pickupMergeDistance * pickupMergeDistance then
                particle:merge(x, y, height or 0, value)
                return
            end
        end
    end

    addParticle(PickupNumber:new(x, y, height or 0, formatPickupText(value, decimals), colors, {
        kind = kind or "coin",
        value = value,
        decimals = decimals,
    }))
end

return DamageNumber
