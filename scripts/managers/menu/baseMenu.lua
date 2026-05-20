
local baseMenu = {}
local navigateSound = love.audio.newSource("assets/sfx/menu/menu-button.mp3", "static")
local confirmSound = love.audio.newSource("assets/sfx/menu/menu-selected.mp3", "static")

function baseMenu:load()
    self.menuOptions = {}
    self.selectedOption = 1
    self.optionBounds = {}
    self.MenuTItle = "MENU BASE - make a new menu"
    self.fontTitle = love.graphics.newFont("assets/fonts/ThaleahFat.ttf", 48)
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

function baseMenu:drawTitle()
    love.graphics.setFont(self.fontTitle)


    local titleX, titleY = 01, self:getHeight() / 2 - 60
    --drawOutline(self.MenuTItle, titleX, titleY, self:getWidth(), "center")

    love.graphics.setColor(hexToRGB("fbfaf7"))  
    love.graphics.printf(self.MenuTItle, titleX, titleY, self:getWidth(), "center")
    love.graphics.setColor(hexToRGB("ffffff"))

end

local hoverPalette = {
    "b8bd99",
    "9ab7ad",
    "aa99bb",
    "b6a49a",
    "97a983",
    "afa0b4",
}

function baseMenu:drawHoverText(text, y)
    local time = love.timer.getTime()
    local font = self.fontOptions
    local textWidth = font:getWidth(text)
    local x = self:getWidth() / 2 - textWidth / 2
    local paletteShift = math.floor(time * 3.2)

    for i = 1, #text do
        local char = text:sub(i, i)
        local charWidth = font:getWidth(char)
        local phase = time * 4.2 + i * 0.72
        local runX = math.sin(phase) * 0.9 + math.sin(time * 6.5 + i * 1.3) * 0.32
        local runY = math.cos(time * 3.1 + i * 0.58) * 0.75
        local drawX = math.floor(x + runX)
        local drawY = math.floor(y + runY)
        local color = hoverPalette[((i + paletteShift - 1) % #hoverPalette) + 1]

        if char ~= " " then
            love.graphics.setColor(0.02, 0.015, 0.025, 0.8)
            love.graphics.print(char, drawX + 1, drawY + 1)
            love.graphics.setColor(hexToRGB(color))
            love.graphics.print(char, drawX, drawY)
        end

        x = x + charWidth
    end

    love.graphics.setColor(hexToRGB("fbfaf7"))
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

    self:drawSelectSprite(text, y)
    self:drawHoverText(text, y)

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
        self.optionBounds[i] = {
            left = left,
            top = y,
            width = textWidth + 72,
            height = self.fontOptions:getHeight() + 10,
        }
        self:drawOption(optionText, 0, y, "center", isSelected, isInactive, self.optionBounds[i])
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
