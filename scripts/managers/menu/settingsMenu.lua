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
    self.menuOptions = { "screenSize", "fullscreen", "master", "music", "back" }
    self.optionActions = {
        screenSize = function(direction)
            Settings:cycleResolution(direction)
        end,
        fullscreen = function()
            Settings:toggleFullscreen()
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

function SettingsMenu:isOptionInactive(optionId)
    return optionId == "screenSize" and Settings.fullscreen == true
end

function SettingsMenu:getOptionLabel(index)
    local optionId = self.menuOptions[index]
    if optionId == "screenSize" then
        return "screen size: " .. Settings:getResolutionLabel()
    elseif optionId == "fullscreen" then
        return "fullscreen: " .. Settings:getFullscreenLabel()
    elseif optionId == "master" then
        return "sound: " .. formatPercent(Settings:getMasterPercent())
    elseif optionId == "music" then
        return "music: " .. formatPercent(Settings:getMusicPercent())
    end

    return "back"
end

function SettingsMenu:changeSelectedOption(direction)
    local optionId = self.menuOptions[self.selectedOption]
    if self:isOptionInactive(optionId) then
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

function SettingsMenu:draw()
    love.graphics.setColor(hexToRGB("090909"))
    love.graphics.rectangle("fill", 0, 0, baseWidth * 2, baseHeight * 2)
    baseMenu.draw(self)
end

function SettingsMenu:keypressed(key)
    if key == "left" then
        self:changeSelectedOption(-1)
        return
    elseif key == "right" then
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
    local optionIndex = self:getOptionAtPosition(x, y)
    if not optionIndex then
        return
    end

    local optionId = self.menuOptions[optionIndex]
    if self:isOptionInactive(optionId) then
        return
    end

    self.selectedOption = optionIndex
    self.lastSelectChange = love.timer.getTime()

    if optionId == "back" then
        self:playConfirmSound()
        self:goBack()
        return
    end

    local bounds = self.optionBounds[optionIndex]
    if optionId == "screenSize" or optionId == "fullscreen" then
        self:changeSelectedOption(1)
        return
    end

    local relativeX = (x - bounds.left) / bounds.width
    if relativeX < 0.5 then
        self:changeSelectedOption(-1)
    else
        self:changeSelectedOption(1)
    end
end

return SettingsMenu
