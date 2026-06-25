
local baseMenu = {}
local Localization = require("scripts/managers/localization")
local Fonts = require("scripts/ui/fonts")
local SelectCorners = require("scripts/ui/selectCorners")
local navigateSound = love.audio.newSource("assets/sfx/menu/menu-button.mp3", "static")
local confirmSound = love.audio.newSource("assets/sfx/menu/menu-selected.mp3", "static")

local function clampValue(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

function baseMenu:load()
    self.menuOptions = {}
    self.selectedOption = 1
    self.optionBounds = {}
    self.MenuTItle = "MENU BASE - make a new menu"
    self.fontTitle = Fonts:translated("menuTitle")

    self.fontOptions = Fonts:translated("menuOption")
    self.scale = 1
    self.lastSelectChange = -1

    self.scaleTarget = 1
    self.lastMouseX = nil
    self.lastMouseY = nil
    self.mouseNeedsSync = true
    self.inputMode = "mouse"
    self.hoverSoundCooldowns = {}
    self.cornerExits = {}
    self.lockOnSelect = false
    self.interactionsLocked = false

end

function baseMenu:getOptionLabel(index)
    return self.menuOptions[index]
end

function baseMenu:isOptionInactive(optionId)
    return false
end

function baseMenu:isOptionIndexInactive(index)
    return self:isOptionInactive(self.menuOptions[index])
end

function baseMenu:playNavigateSound()
    navigateSound:stop()
    setSourceVolume(navigateSound, 0.4 * (SOUND_VOLUME or 1))
    navigateSound:setPitch(0.95 + math.random() * 0.1)
    navigateSound:play()
end

function baseMenu:playConfirmSound()
    confirmSound:stop()
    confirmSound:setPitch(1)
    setSourceVolume(confirmSound, 0.7 * (SOUND_VOLUME or 1))
    confirmSound:play()
end

function baseMenu:onSelect()

end

function baseMenu:lockInteractions()
    self.interactionsLocked = true
    self.mouseNeedsSync = true
end

function baseMenu:unlockInteractions()
    self.interactionsLocked = false
    self.mouseNeedsSync = true
end

function baseMenu:isInteractionLocked()
    return self.interactionsLocked == true
end

function baseMenu:confirmSelectedOption()
    if self:isInteractionLocked() or self:isOptionIndexInactive(self.selectedOption) then
        return false
    end

    self:playConfirmSound()
    self.lastSelectChange = love.timer.getTime()
    if self.lockOnSelect then
        self:lockInteractions()
    end
    self:onSelect()
    return true
end

function baseMenu:getCanvasMousePosition()
    return (love.mouse.getX() - viewportOffsetX) / scale,
        (love.mouse.getY() - viewportOffsetY) / scale
end

function baseMenu:getMouseLean(bounds)
    if not bounds then
        return 0, 0
    end

    local mouseX, mouseY = self:getCanvasMousePosition()
    local centerX = bounds.left + bounds.width / 2
    local centerY = bounds.top + bounds.height / 2
    local halfW = math.max(bounds.width / 2, 1)
    local halfH = math.max(bounds.height / 2, 1)

    return clampValue((mouseX - centerX) / halfW, -1, 1),
        clampValue((mouseY - centerY) / halfH, -1, 1)
end

local hoverPalette = {
    "c6cbaa",
    "abc8bd",
    "f2f0df",
    "b8aac8",
    "c7b5ab",
    "a9ba95",
    "bfb0c5",
}

local MENU_TEXT_SHADOW_X = 2
local MENU_TEXT_SHADOW_Y = 2
local MENU_TEXT_SHADOW_DARKEN = 0.42
local MOUSE_REACTIVATE_DISTANCE = 6
local MARQUEE_SPEED = 28
local MARQUEE_END_PAUSE = 0.8

local function setDarkerTextColor(r, g, b, a)
    love.graphics.setColor(
        r * MENU_TEXT_SHADOW_DARKEN,
        g * MENU_TEXT_SHADOW_DARKEN,
        b * MENU_TEXT_SHADOW_DARKEN,
        a or 1
    )
end

local cp1252ToCodepoint = {
    [0x80] = 0x20AC, [0x82] = 0x201A, [0x83] = 0x0192, [0x84] = 0x201E,
    [0x85] = 0x2026, [0x86] = 0x2020, [0x87] = 0x2021, [0x88] = 0x02C6,
    [0x89] = 0x2030, [0x8A] = 0x0160, [0x8B] = 0x2039, [0x8C] = 0x0152,
    [0x8E] = 0x017D, [0x91] = 0x2018, [0x92] = 0x2019, [0x93] = 0x201C,
    [0x94] = 0x201D, [0x95] = 0x2022, [0x96] = 0x2013, [0x97] = 0x2014,
    [0x98] = 0x02DC, [0x99] = 0x2122, [0x9A] = 0x0161, [0x9B] = 0x203A,
    [0x9C] = 0x0153, [0x9E] = 0x017E, [0x9F] = 0x0178,
}

local function isContinuationByte(byte)
    return byte and byte >= 0x80 and byte <= 0xBF
end

local function getSequenceLength(byte)
    if byte < 0x80 then
        return 1
    elseif byte >= 0xC2 and byte <= 0xDF then
        return 2
    elseif byte >= 0xE0 and byte <= 0xEF then
        return 3
    elseif byte >= 0xF0 and byte <= 0xF4 then
        return 4
    end
    return 0
end

local function appendCodepoint(characters, byte)
    if utf8 and utf8.char then
        characters[#characters + 1] = utf8.char(cp1252ToCodepoint[byte] or byte)
    else
        characters[#characters + 1] = "?"
    end
end

local function getSafeUtf8Characters(text)
    local characters = {}
    text = tostring(text or "")
    local index = 1

    while index <= #text do
        local byte = text:byte(index)
        local sequenceLength = getSequenceLength(byte)

        if sequenceLength == 1 then
            characters[#characters + 1] = text:sub(index, index)
            index = index + 1
        elseif sequenceLength > 1 then
            local valid = index + sequenceLength - 1 <= #text
            for offset = 1, sequenceLength - 1 do
                if not isContinuationByte(text:byte(index + offset)) then
                    valid = false
                    break
                end
            end

            if valid then
                characters[#characters + 1] = text:sub(index, index + sequenceLength - 1)
                index = index + sequenceLength
            else
                appendCodepoint(characters, byte)
                index = index + 1
            end
        else
            appendCodepoint(characters, byte)
            index = index + 1
        end
    end

    return characters
end

local function drawWavyMenuText(self, text, y, font, config)
    text = Localization:normalizeText(text)
    local time = love.timer.getTime()
    local characters = getSafeUtf8Characters(text)
    local textWidth = 0
    for _, char in ipairs(characters) do
        textWidth = textWidth + font:getWidth(char)
    end
    local maxWidth = config.maxWidth
    local clipX = config.clipX or (maxWidth and (self:getWidth() / 2 - maxWidth / 2) or nil)
    local previousX, previousY, previousWidth, previousHeight
    local x = self:getWidth() / 2 - textWidth / 2

    if maxWidth and textWidth > maxWidth then
        local overflow = textWidth - maxWidth
        local travelTime = math.max(overflow / MARQUEE_SPEED, 0.001)
        local cycleTime = travelTime + MARQUEE_END_PAUSE
        local elapsed = ((love.timer.getTime() - (self.lastSelectChange or 0)) % cycleTime)
        local offset = elapsed >= travelTime and overflow or (elapsed / travelTime) * overflow
        x = clipX - math.floor(offset + 0.5)
        previousX, previousY, previousWidth, previousHeight = love.graphics.getScissor()
        love.graphics.setScissor(clipX, y - 4, maxWidth, font:getHeight() + 12)
    end

    local centerX = x + textWidth / 2
    local halfTextWidth = math.max(textWidth / 2, 1)
    local paletteShift = math.floor(time * config.paletteSpeed)
    local leanX = config.leanX or 0
    local leanY = config.leanY or 0
    local leanTiltY = config.leanTiltY or 0
    local leanTiltX = config.leanTiltX or 0

    for i, char in ipairs(characters) do
        local charWidth = font:getWidth(char)
        local relativeX = ((x + charWidth / 2) - centerX) / halfTextWidth
        local phase = time * config.phaseSpeed + i * config.letterPhase
        local runX = math.sin(phase) * config.xAmplitude
            + math.sin(time * config.secondarySpeed + i * 1.3) * config.secondaryX
        local runY = math.cos(time * config.ySpeed + i * 0.58) * config.yAmplitude
        runX = runX + relativeX * leanY * leanTiltX
        runY = runY + relativeX * leanX * leanTiltY
        local drawX = math.floor(x + runX + 0.5)
        local drawY = math.floor(y + runY + 0.5)
        local color = config.color or hoverPalette[((i + paletteShift - 1) % #hoverPalette) + 1]
        local shadowX = config.shadowOffsetX or MENU_TEXT_SHADOW_X
        local shadowY = config.shadowOffsetY or MENU_TEXT_SHADOW_Y

        if char ~= " " then
            local r, g, b = hexToRGB(color)
            if config.drawShadow ~= false then
                setDarkerTextColor(r, g, b, config.shadowAlpha or 1)
                love.graphics.print(char, drawX + shadowX, drawY + shadowY)
            end
            love.graphics.setColor(r, g, b)
            love.graphics.print(char, drawX, drawY)
        end
        x = x + charWidth
    end

    if previousX then
        love.graphics.setScissor(previousX, previousY, previousWidth, previousHeight)
    elseif maxWidth and textWidth > maxWidth then
        love.graphics.setScissor()
    end

    love.graphics.setColor(hexToRGB("fbfaf7"))
end

local function drawShadowedPrintf(text, x, y, width, align, color, shadowAlpha)
    local r, g, b = color[1], color[2], color[3]
    local a = color[4] or 1
    setDarkerTextColor(r, g, b, shadowAlpha or a)
    love.graphics.printf(text, x + MENU_TEXT_SHADOW_X, y + MENU_TEXT_SHADOW_Y, width, align)
    love.graphics.setColor(r, g, b, a)
    love.graphics.printf(text, x, y, width, align)
end

function baseMenu:drawTitle()
    love.graphics.setFont(self.fontTitle)

    local titleY = self.titleYOverride or (self:getHeight() / 2 - 72)
    drawWavyMenuText(self, self.MenuTItle, titleY, self.fontTitle, {
        paletteSpeed = 1.55,
        phaseSpeed = 1.65,
        letterPhase = 0.42,
        xAmplitude = 0.38,
        secondarySpeed = 2.2,
        secondaryX = 0.16,
        ySpeed = 1.35,
        yAmplitude = 0.28,
        shadowAlpha = 1,
        color = "fbfaf7",
        maxWidth = self:getWidth() - 28,
        drawShadow = true,
    })
    love.graphics.setColor(hexToRGB("ffffff"))
end

function baseMenu:drawHoverText(text, y, bounds)
    local leanX, leanY = self:getMouseLean(bounds)
    drawWavyMenuText(self, text, y, self.fontOptions, {
        paletteSpeed = 3.2,
        phaseSpeed = 4.2,
        letterPhase = 0.72,
        xAmplitude = 0.9,
        secondarySpeed = 6.5,
        secondaryX = 0.32,
        ySpeed = 3.1,
        yAmplitude = 0.75,
        shadowAlpha = 1,
        leanX = leanX,
        leanY = leanY,
        leanTiltY = 3.0,
        leanTiltX = -1.45,
        maxWidth = math.max(24, math.min((bounds and bounds.width or self:getWidth()) - 18, self:getWidth() - 74)),
        drawShadow = false,
    })
end

function baseMenu:drawSelectedOptionContent(text, y, bounds)
    local normalizedText = Localization:normalizeText(text)
    local ok, textWidth = pcall(function()
        return self.fontOptions:getWidth(normalizedText)
    end)
    textWidth = ok and textWidth or math.max((bounds and bounds.width or 80) - 72, 24)
    local visualBounds = self:getSelectedOptionVisualBounds(textWidth, bounds)
    self.lastSelectedVisualBounds = visualBounds

    local leanX, leanY = self:getMouseLean(bounds)
    love.graphics.push()
    love.graphics.translate(math.floor(leanY * -1 + 0.5), math.floor(leanX * 1 + 0.5))
    SelectCorners.draw(visualBounds, {
        startedAt = self.lastSelectChange,
        scale = 2.25,
        padding = -1,
        color = {0.95, 0.92, 0.74, 1},
    })
    love.graphics.pop()
    self:drawHoverText(text, y, bounds)
end

function baseMenu:getSelectedOptionVisualBounds(textWidth, bounds)
    local visualPaddingX = 10
    local visualPaddingY = 2
    return {
        left = math.floor(self:getWidth() / 2 - textWidth / 2 - visualPaddingX + 0.5),
        top = bounds.top + visualPaddingY,
        width = math.floor(textWidth + visualPaddingX * 2 + 0.5),
        height = bounds.height - visualPaddingY * 2 - 6,
    }
end

function baseMenu:queueCornerExit(optionIndex, now)
    local bounds = self.optionBounds and self.optionBounds[optionIndex]
    if not bounds then
        return
    end

    local optionText = self:getOptionLabel(optionIndex)
    local normalizedText = Localization:normalizeText(optionText or "")
    local ok, textWidth = pcall(function()
        return self.fontOptions:getWidth(normalizedText)
    end)
    textWidth = ok and textWidth or math.max((bounds and bounds.width or 80) - 72, 24)

    self.cornerExits = self.cornerExits or {}
    self.cornerExits[#self.cornerExits + 1] = {
        bounds = self:getSelectedOptionVisualBounds(textWidth, bounds),
        startedAt = self.lastSelectChange,
        exitedAt = now or love.timer.getTime(),
    }
end

function baseMenu:drawCornerExits()
    local exits = self.cornerExits
    if not exits then
        return
    end

    local now = love.timer.getTime()
    for i = #exits, 1, -1 do
        local exit = exits[i]
        if now - exit.exitedAt >= 0.1 then
            table.remove(exits, i)
        else
            SelectCorners.draw(exit.bounds, {
                startedAt = exit.startedAt,
                exitedAt = exit.exitedAt,
                exitDuration = 0.1,
                scale = 2.25,
                padding = -1,
                color = {0.95, 0.92, 0.74, 1},
            })
        end
    end
end

function baseMenu:drawOption(text, x, y, def, isSelected, isInactive, bounds)
    if isInactive then
        love.graphics.setColor(0, 0, 0, 0.45)
        love.graphics.rectangle("fill", bounds.left, bounds.top - 2, bounds.width, bounds.height)
        love.graphics.setColor(0.45, 0.45, 0.45, 0.7)
        love.graphics.printf(text, x, y, self:getWidth(), def)
        return
    end

    if not isSelected then
        love.graphics.setColor(hexToRGB("fbfaf7"))
        love.graphics.printf(text, x, y, self:getWidth(), def)
        return
    end

    self:drawSelectedOptionContent(text, y, bounds)

end

function baseMenu:getHeight()
    return baseHeight / self.scale
end

function baseMenu:getWidth()
    return baseWidth / self.scale
end


function baseMenu:draw()
    self.optionBounds = {}
    self:drawTitle()
    love.graphics.setFont(self.fontOptions)
    love.graphics.setColor(hexToRGB("fbfaf7"))

    for i, option in ipairs(self.menuOptions) do
        local optionText = self:getOptionLabel(i)
        
        local isInactive = self:isOptionIndexInactive(i)
        local isSelected = i == self.selectedOption and not isInactive
        love.graphics.push()
        if isSelected and self.lastSelectChange + 0.06 > love.timer.getTime() then
            self.scale = 1
        end
        local centerHeight =  self:getHeight() / 2    
        local y = (centerHeight) + (i * 30)
        local textWidth = self.fontOptions:getWidth(optionText)
        local left = math.floor(self:getWidth() / 2 - textWidth / 2 - 36)
        local bounds = {
            left = left,
            top = y,
            width = textWidth + 72,
            height = self.fontOptions:getHeight() + 10,
        }
        if type(self.getOptionBounds) == "function" then
            bounds = self:getOptionBounds(i, optionText, y, bounds) or bounds
        end
        self.optionBounds[i] = bounds
        self.currentDrawIndex = i
        self:drawOption(optionText, 0, y, "center", isSelected, isInactive, self.optionBounds[i])
        self.currentDrawIndex = nil
        self.scale = 1
        love.graphics.pop()

    end

    self:drawCornerExits()

    love.graphics.setColor(1, 1, 1)
end

function baseMenu:update(dt)
    local mouseX = love.mouse.getX()
    local mouseY = love.mouse.getY()

    local hadMousePosition = self.lastMouseX ~= nil and self.lastMouseY ~= nil
    local mouseMoved = hadMousePosition and (self.lastMouseX ~= mouseX or self.lastMouseY ~= mouseY)
    self.lastMouseX = mouseX
    self.lastMouseY = mouseY

    if self:isInteractionLocked() then
        return
    end

    if not mouseMoved then
        return
    end

    if self.inputMode == "keyboard" and self.keyboardMouseAnchorX and self.keyboardMouseAnchorY then
        local dx = mouseX - self.keyboardMouseAnchorX
        local dy = mouseY - self.keyboardMouseAnchorY
        if dx * dx + dy * dy < MOUSE_REACTIVATE_DISTANCE * MOUSE_REACTIVATE_DISTANCE then
            return
        end
    end

    self.inputMode = "mouse"
    self.mouseNeedsSync = false

    local optionIndex = self:getOptionAtPosition(
        (mouseX - viewportOffsetX) / scale,
        (mouseY - viewportOffsetY) / scale
    )
    if optionIndex and not self:isOptionIndexInactive(optionIndex) and optionIndex ~= self.selectedOption then
        local now = love.timer.getTime()
        self:queueCornerExit(self.selectedOption, now)
        self.selectedOption = optionIndex
        self.lastSelectChange = now
        if now >= (self.hoverSoundCooldowns[optionIndex] or 0) then
            self.hoverSoundCooldowns[optionIndex] = now + 0.12
            self:playNavigateSound()
        end
    end
end

function baseMenu:getOptionAtPosition(x, y)
    local closestIndex = nil
    local closestDistance = math.huge
    for i, bounds in ipairs(self.optionBounds or {}) do
        if x >= bounds.left and x <= bounds.left + bounds.width and
           y >= bounds.top and y <= bounds.top + bounds.height then
            local centerY = bounds.top + bounds.height / 2
            local distanceToCenter = math.abs(y - centerY)
            if distanceToCenter < closestDistance then
                closestDistance = distanceToCenter
                closestIndex = i
            end
        end
    end
    return closestIndex
end

function baseMenu:mousepressed(x, y, button)
    if self:isInteractionLocked() then
        return true
    end

    if button ~= 1 then
        return
    end

    local optionIndex = self:getOptionAtPosition(x, y)
    if not optionIndex then
        return
    end

    if self:isOptionIndexInactive(optionIndex) then
        return
    end

    self.inputMode = "mouse"
    if optionIndex ~= self.selectedOption then
        self:queueCornerExit(self.selectedOption, love.timer.getTime())
    end
    self.selectedOption = optionIndex
    self.lastSelectChange = love.timer.getTime()
    self.mouseNeedsSync = false
    self:confirmSelectedOption()
    return true
end

function baseMenu:keypressed(key)
    if self:isInteractionLocked() then
        return true
    end

    local handled = true
    if key == "up" then
        self:moveSelection(-1)
    elseif key == "down" then
        self:moveSelection(1)
    elseif key == "return" or key == "space" then
        self:confirmSelectedOption()
        return
    else
        handled = false
    end

    if not handled then
        return
    end

    self.inputMode = "keyboard"
    self.keyboardMouseAnchorX = love.mouse.getX()
    self.keyboardMouseAnchorY = love.mouse.getY()
    self.mouseNeedsSync = true
    self.lastSelectChange = love.timer.getTime()
    self:playNavigateSound()
end

function baseMenu:moveSelection(direction)
    if #self.menuOptions == 0 then
        return
    end

    local nextOption = self.selectedOption
    for _ = 1, #self.menuOptions do
        nextOption = nextOption + direction
        if nextOption < 1 then
            nextOption = #self.menuOptions
        elseif nextOption > #self.menuOptions then
            nextOption = 1
        end

        if not self:isOptionIndexInactive(nextOption) then
            if nextOption ~= self.selectedOption then
                self:queueCornerExit(self.selectedOption, love.timer.getTime())
            end
            self.selectedOption = nextOption
            return
        end
    end
end

return baseMenu
