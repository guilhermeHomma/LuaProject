local baseMenu = require("scripts/managers/menu/baseMenu")
local Settings = require("scripts/managers/settings")

local SettingsMenu = {}
setmetatable(SettingsMenu, { __index = baseMenu })

local function formatPercent(value)
    return tostring(value) .. "%"
end

function SettingsMenu:load()
    baseMenu.load(self)
    self.MenuTItle = "SETTINGS"
    self.menuOptions = { "screenSize", "fullscreen", "vsync", "crt", "cameraShake", "master", "music", "back" }
    self.arrowBounds = {}
    self.optionActions = {
        screenSize = function(direction)
            Settings:cycleResolution(direction)
        end,
        fullscreen = function()
            Settings:toggleFullscreen()
        end,
        vsync = function()
            Settings:toggleVsync()
        end,
        crt = function()
            Settings:toggleCrt()
        end,
        cameraShake = function()
            Settings:toggleCameraShake()
        end,
        master = function(direction)
            Settings:adjustMasterVolume(0.1 * direction)
        end,
        music = function(direction)
            Settings:adjustMusicVolume(0.1 * direction)
        end,
    }

    if self:isOptionIndexInactive(self.selectedOption) then
        self:moveSelection(1)
    end
end

function SettingsMenu:isArrowOption(optionId)
    return optionId == "screenSize"
        or optionId == "master"
        or optionId == "music"
end

function SettingsMenu:isOptionInactive(optionId)
    return optionId == "screenSize" and Settings.fullscreen == true
end

function SettingsMenu:canChangeOption(optionId, direction)
    if not self:isArrowOption(optionId) or direction == 0 then
        return false
    end

    if optionId == "screenSize" then
        if Settings.fullscreen then
            return false
        end
        if direction < 0 then
            return Settings.resolutionIndex > 1
        end
        return Settings.resolutionIndex < #Settings.resolutionPresets
    elseif optionId == "master" then
        return direction < 0 and Settings.masterVolume > 0
            or direction > 0 and Settings.masterVolume < 1
    elseif optionId == "music" then
        return direction < 0 and Settings.musicVolume > 0
            or direction > 0 and Settings.musicVolume < 1
    end

    return false
end

function SettingsMenu:getOptionLabel(index)
    local optionId = self.menuOptions[index]
    if optionId == "screenSize" then
        return "screen size: < " .. Settings:getResolutionLabel() .. " >"
    elseif optionId == "fullscreen" then
        return "fullscreen: " .. Settings:getFullscreenLabel()
    elseif optionId == "vsync" then
        return "vsync: " .. Settings:getVsyncLabel()
    elseif optionId == "crt" then
        return "crt filter: " .. Settings:getCrtLabel()
    elseif optionId == "cameraShake" then
        return "camera shake: " .. Settings:getCameraShakeLabel()
    elseif optionId == "master" then
        return "sound: < " .. formatPercent(Settings:getMasterPercent()) .. " >"
    elseif optionId == "music" then
        return "music: < " .. formatPercent(Settings:getMusicPercent()) .. " >"
    end

    return "back"
end

function SettingsMenu:changeSelectedOption(direction)
    local optionId = self.menuOptions[self.selectedOption]
    if self:isOptionInactive(optionId) then
        return false
    end
    if self:isArrowOption(optionId) and not self:canChangeOption(optionId, direction) then
        self.mouseNeedsSync = true
        return false
    end

    local action = self.optionActions[optionId]
    if action then
        action(direction)
        self.mouseNeedsSync = true
        self.lastSelectChange = love.timer.getTime()
        self:playNavigateSound()
        return true
    end
    return false
end

local function isPointInside(bounds, x, y)
    return bounds
        and x >= bounds.x
        and x <= bounds.x + bounds.width
        and y >= bounds.y
        and y <= bounds.y + bounds.height
end

function SettingsMenu:getCanvasMousePosition()
    return (love.mouse.getX() - viewportOffsetX) / scale,
        (love.mouse.getY() - viewportOffsetY) / scale
end

function SettingsMenu:drawArrow(symbol, x, y, enabled, isSelected, bounds)
    local mouseX, mouseY = self:getCanvasMousePosition()
    local hovered = enabled and isPointInside(bounds, mouseX, mouseY)
    local drawX = x
    local drawY = y

    if not enabled then
        love.graphics.setColor(0.13, 0.13, 0.14, 0.72)
    elseif hovered then
        local pulse = math.sin(love.timer.getTime() * 8) * 0.35
        drawX = drawX + (symbol == "<" and -1 or 1)
        drawY = drawY + pulse
        love.graphics.setColor(hexToRGB("f2f0df"))
    elseif isSelected then
        love.graphics.setColor(hexToRGB("c9c6a4"))
    else
        love.graphics.setColor(hexToRGB("fbfaf7"))
    end

    love.graphics.print(symbol, math.floor(drawX), math.floor(drawY))
end

function SettingsMenu:getOptionValueBounds(text)
    local startIndex = text:find("<", 1, true)
    local endIndex = text:find(">", 1, true)
    if not (startIndex and endIndex) then
        return nil
    end

    local prefix = text:sub(1, startIndex - 1)
    local throughLeft = text:sub(1, startIndex)
    local beforeRight = text:sub(1, endIndex - 1)
    local textWidth = self.fontOptions:getWidth(text)
    local textLeft = self:getWidth() / 2 - textWidth / 2
    local leftX = textLeft + self.fontOptions:getWidth(prefix)
    local rightX = textLeft + self.fontOptions:getWidth(beforeRight)

    return {
        leftX = leftX,
        rightX = rightX,
        leftClickX = leftX - 10,
        rightClickX = rightX - 10,
        width = 28,
    }
end

function SettingsMenu:getOptionBounds(index, text, y, defaultBounds)
    local optionId = self.menuOptions[index]
    if not self:isArrowOption(optionId) then
        return defaultBounds
    end

    local valueBounds = self:getOptionValueBounds(text)
    local textWidth = self.fontOptions:getWidth(text)
    local textLeft = self:getWidth() / 2 - textWidth / 2
    local left = math.floor(valueBounds and valueBounds.leftClickX or textLeft)
    local right = math.floor(valueBounds and (valueBounds.rightClickX + valueBounds.width) or (textLeft + textWidth))
    return {
        left = left,
        top = y,
        width = right - left,
        height = defaultBounds.height,
    }
end

function SettingsMenu:drawOption(text, x, y, def, isSelected, isInactive, bounds)
    local optionId = self.menuOptions[self.currentDrawIndex or 1]
    if not self:isArrowOption(optionId) then
        baseMenu.drawOption(self, text, x, y, def, isSelected, isInactive, bounds)
        return
    end

    local leftEnabled = not isInactive and self:canChangeOption(optionId, -1)
    local rightEnabled = not isInactive and self:canChangeOption(optionId, 1)
    local valueBounds = self:getOptionValueBounds(text)
    local leftArrowX = valueBounds and valueBounds.leftX or bounds.left
    local rightArrowX = valueBounds and valueBounds.rightX or (bounds.left + bounds.width)

    self.arrowBounds[self.currentDrawIndex] = {
        left = {
            x = leftArrowX - 8,
            y = y,
            width = 26,
            height = self.fontOptions:getHeight() + 10,
            enabled = leftEnabled,
        },
        right = {
            x = rightArrowX - 8,
            y = y,
            width = 26,
            height = self.fontOptions:getHeight() + 10,
            enabled = rightEnabled,
        },
    }

    if isSelected and not isInactive then
        self:drawSelectedOptionContent(text, y, bounds)
    elseif isInactive then
        love.graphics.setColor(0.45, 0.45, 0.45, 0.55)
        love.graphics.printf(text, x, y, self:getWidth(), def)
    else
        love.graphics.setColor(hexToRGB("fbfaf7"))
        love.graphics.printf(text, x, y, self:getWidth(), def)
    end

    self:drawArrow("<", leftArrowX, y, leftEnabled, isSelected, self.arrowBounds[self.currentDrawIndex].left)
    self:drawArrow(">", rightArrowX, y, rightEnabled, isSelected, self.arrowBounds[self.currentDrawIndex].right)
    love.graphics.setColor(1, 1, 1, 1)
end

function SettingsMenu:draw()
    love.graphics.setColor(hexToRGB("090909"))
    love.graphics.rectangle("fill", 0, 0, baseWidth * 2, baseHeight * 2)
    self.arrowBounds = {}
    baseMenu.draw(self)
end

function SettingsMenu:keypressed(key)
    self.inputMode = "keyboard"
    if key == "left" then
        if not self:isArrowOption(self.menuOptions[self.selectedOption]) then
            return
        end
        self:changeSelectedOption(-1)
        return
    elseif key == "right" then
        if not self:isArrowOption(self.menuOptions[self.selectedOption]) then
            return
        end
        self:changeSelectedOption(1)
        return
    elseif key == "escape" then
        self:goBack()
        return
    end

    baseMenu.keypressed(self, key)
end

function SettingsMenu:onSelect()
    local optionId = self.menuOptions[self.selectedOption]
    if optionId == "back" then
        self:goBack()
        return
    end

    self:changeSelectedOption(1)
end

function SettingsMenu:goBack()
    closeSettings()
end

function SettingsMenu:mousepressed(x, y, button)
    if button ~= 1 then
        return
    end

    local optionIndex = self:getOptionAtPosition(x, y)
    if not optionIndex then
        return
    end

    self.inputMode = "mouse"
    local optionId = self.menuOptions[optionIndex]
    if self:isOptionInactive(optionId) then
        return
    end

    self.selectedOption = optionIndex
    self.lastSelectChange = love.timer.getTime()

    if optionId == "back" then
        self:playConfirmSound()
        self:goBack()
        return true
    end

    local arrows = self.arrowBounds and self.arrowBounds[optionIndex]
    if arrows then
        if x >= arrows.left.x and x <= arrows.left.x + arrows.left.width
            and y >= arrows.left.y and y <= arrows.left.y + arrows.left.height then
            self:changeSelectedOption(-1)
            return true
        end
        if x >= arrows.right.x and x <= arrows.right.x + arrows.right.width
            and y >= arrows.right.y and y <= arrows.right.y + arrows.right.height then
            self:changeSelectedOption(1)
            return true
        end
    end

    local bounds = self.optionBounds[optionIndex]
    if optionId == "fullscreen" or optionId == "vsync" or optionId == "crt" or optionId == "cameraShake" then
        self:changeSelectedOption(1)
        return true
    end

    if optionId == "screenSize" then
        self:changeSelectedOption(1)
        return true
    end

    local relativeX = (x - bounds.left) / bounds.width
    if relativeX < 0.5 then
        self:changeSelectedOption(-1)
    else
        self:changeSelectedOption(1)
    end
    return true
end

return SettingsMenu
