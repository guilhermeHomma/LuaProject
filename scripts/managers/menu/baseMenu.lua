
local baseMenu = {}
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
    self.fontTitle = love.graphics.newFont("assets/fonts/ThaleahFat.ttf", 56)
    self.fontTitle:setFilter("nearest", "nearest")

    self.fontOptions = love.graphics.newFont("assets/fonts/ThaleahFat.ttf", 32)
    self.fontOptions:setFilter("nearest", "nearest")
    self.scale = 1
    self.lastSelectChange = -1

    self.scaleTarget = 1
    self.lastMouseX = nil
    self.lastMouseY = nil
    self.mouseNeedsSync = true

    self.selectSprite = love.graphics.newImage("assets/sprites/menu/menu-select.png")

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
    navigateSound:setVolume(1)
    navigateSound:setPitch(0.95 + math.random() * 0.1)
    navigateSound:play()
end

function baseMenu:playConfirmSound()
    confirmSound:stop()
    confirmSound:setPitch(1)
    confirmSound:setVolume(0.2)
    confirmSound:play()
end

function baseMenu:onSelect()

end

function baseMenu:drawSelectSprite(text, y)

    local spriteX =  math.ceil(self:getWidth()/ 2 - self.fontOptions:getWidth(text) / 2 - 30)
    love.graphics.draw(self.selectSprite, spriteX, y+ 3, 0, 3, 3)
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

local function drawWavyMenuText(self, text, y, font, config)
    local time = love.timer.getTime()
    local textWidth = font:getWidth(text)
    local x = self:getWidth() / 2 - textWidth / 2
    local centerX = x + textWidth / 2
    local halfTextWidth = math.max(textWidth / 2, 1)
    local paletteShift = math.floor(time * config.paletteSpeed)
    local leanX = config.leanX or 0
    local leanY = config.leanY or 0
    local leanTiltY = config.leanTiltY or 0
    local leanTiltX = config.leanTiltX or 0

    for i = 1, #text do
        local char = text:sub(i, i)
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

        if char ~= " " then
            love.graphics.setColor(0.02, 0.015, 0.025, config.shadowAlpha)
            love.graphics.print(char, drawX + 1, drawY + 1)
            love.graphics.setColor(hexToRGB(color))
            love.graphics.print(char, drawX, drawY)
        end

        x = x + charWidth
    end

    love.graphics.setColor(hexToRGB("fbfaf7"))
end

function baseMenu:drawTitle()
    love.graphics.setFont(self.fontTitle)

    local titleY = self:getHeight() / 2 - 72
    drawWavyMenuText(self, self.MenuTItle, titleY, self.fontTitle, {
        paletteSpeed = 1.55,
        phaseSpeed = 1.65,
        letterPhase = 0.42,
        xAmplitude = 0.38,
        secondarySpeed = 2.2,
        secondaryX = 0.16,
        ySpeed = 1.35,
        yAmplitude = 0.28,
        shadowAlpha = 0.62,
        color = "fbfaf7",
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
        shadowAlpha = 0.8,
        leanX = leanX,
        leanY = leanY,
        leanTiltY = 3.0,
        leanTiltX = -1.45,
    })
end

function baseMenu:drawSelectedOptionContent(text, y, bounds)
    local leanX, leanY = self:getMouseLean(bounds)
    love.graphics.push()
    love.graphics.translate(math.floor(leanY * -1 + 0.5), math.floor(leanX * 1 + 0.5))
    self:drawSelectSprite(text, y)
    love.graphics.pop()
    self:drawHoverText(text, y, bounds)
end

function baseMenu:drawOption(text, x, y, def, isSelected, isInactive, bounds)
    if isInactive then
        love.graphics.setColor(0, 0, 0, 0.45)
        love.graphics.rectangle("fill", bounds.left, bounds.top - 2, bounds.width, bounds.height)
        love.graphics.setColor(0.45, 0.45, 0.45, 0.55)
        love.graphics.printf(text, x, y, self:getWidth(), def)
        return
    end

    if not isSelected then
        --drawOutline(text, x, y, self:getWidth(), def)
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
            self.scale = 1.05
            love.graphics.scale(1.05, 1.05)
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

    love.graphics.setColor(1, 1, 1)
end

function baseMenu:update(dt)
    local mouseX = love.mouse.getX()
    local mouseY = love.mouse.getY()

    local mouseMoved = self.lastMouseX ~= mouseX or self.lastMouseY ~= mouseY
    self.lastMouseX = mouseX
    self.lastMouseY = mouseY

    if not mouseMoved and not self.mouseNeedsSync then
        return
    end

    self.mouseNeedsSync = false

    local optionIndex = self:getOptionAtPosition(
        (mouseX - viewportOffsetX) / scale,
        (mouseY - viewportOffsetY) / scale
    )
    if optionIndex and not self:isOptionIndexInactive(optionIndex) and optionIndex ~= self.selectedOption then
        self.selectedOption = optionIndex
    end
end

function baseMenu:getOptionAtPosition(x, y)
    for i, bounds in ipairs(self.optionBounds or {}) do
        if x >= bounds.left and x <= bounds.left + bounds.width and
           y >= bounds.top and y <= bounds.top + bounds.height then
            return i
        end
    end
    return nil
end

function baseMenu:mousepressed(x, y, button)
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

    self.selectedOption = optionIndex
    self.lastSelectChange = love.timer.getTime()
    self.mouseNeedsSync = false
    self:playConfirmSound()
    self:onSelect()
end

function baseMenu:keypressed(key)
    if key == "up" then
        self:moveSelection(-1)
    elseif key == "down" then
        self:moveSelection(1)
    elseif key == "return" or key == "space" then
        if self:isOptionIndexInactive(self.selectedOption) then
            return
        end
        self:playConfirmSound()
        self:onSelect()
        self.lastSelectChange = love.timer.getTime()
        return
    else
        return
    end

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
            self.selectedOption = nextOption
            return
        end
    end
end

return baseMenu
