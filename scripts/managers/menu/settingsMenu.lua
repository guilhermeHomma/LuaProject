local baseMenu = require("scripts/managers/menu/baseMenu")
local Settings = require("scripts/managers/settings")
local Localization = require("scripts/managers/localization")
local SelectCorners = require("scripts/ui/selectCorners")

local SettingsMenu = {}
setmetatable(SettingsMenu, { __index = baseMenu })

local OPTION_HEIGHT = 30
local SECTION_HEIGHT = 22
local SECTION_GAP = 10
local BOX_WIDTH = 198
local BOX_HEIGHT = 25
local VALUE_WIDTH = 168
local VALUE_GAP = 8
local SCROLL_EDGE_OPTIONS = 2
local SCROLL_SPEED = 18

local function formatPercent(value)
    return tostring(value) .. "%"
end

local function clampValue(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

function SettingsMenu:load()
    baseMenu.load(self)
    self.MenuTItle = Localization:t("menu.settings")
    self.titleYOverride = 200
    self.sections = {
        { titleKey = "settings.sections.general", options = { "language", "showFps" } },
        { titleKey = "settings.sections.video", options = { "screenSize", "fullscreen", "vsync", "crt", "cameraShake", "brightness" } },
        { titleKey = "settings.sections.sound", options = { "master", "music" } },
        { title = "", options = { "back" } },
    }
    self.menuOptions = {}
    self.optionIndexById = {}
    for _, section in ipairs(self.sections) do
        for _, optionId in ipairs(section.options) do
            self.menuOptions[#self.menuOptions + 1] = optionId
            self.optionIndexById[optionId] = #self.menuOptions
        end
    end

    self.arrowBounds = {}
    self.scrollY = 0
    self.scrollTargetY = 0
    self.manualScrollTimer = 0
    self.contentHeight = 0
    self.optionActions = {
        showFps = function()
            Settings:toggleFps()
        end,
        language = function(direction)
            Settings:cycleLanguage(direction)
        end,
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
        brightness = function(direction)
            Settings:adjustBrightness(direction)
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
        or optionId == "language"
        or optionId == "brightness"
        or optionId == "master"
        or optionId == "music"
end

function SettingsMenu:isToggleOption(optionId)
    return optionId == "showFps"
        or optionId == "fullscreen"
        or optionId == "vsync"
        or optionId == "crt"
        or optionId == "cameraShake"
end

function SettingsMenu:isOptionInactive(optionId)
    return optionId == "screenSize" and Settings.fullscreen == true
end

function SettingsMenu:canChangeOption(optionId, direction)
    if not self:isArrowOption(optionId) or direction == 0 then
        return false
    end

    if optionId == "language" then
        return true
    elseif optionId == "screenSize" then
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
    elseif optionId == "brightness" then
        return direction < 0 and Settings:getBrightnessValue() > 0
            or direction > 0 and Settings:getBrightnessValue() < 10
    end

    return false
end

function SettingsMenu:getOptionLabel(index)
    local optionId = self.menuOptions[index]
    if optionId == "language" then
        return Localization:t("settings.language"), Settings:getLanguageLabel()
    elseif optionId == "showFps" then
        return Localization:t("settings.show_fps"), Settings:getFpsLabel()
    elseif optionId == "screenSize" then
        return Localization:t("settings.screen_size"), Settings:getResolutionLabel()
    elseif optionId == "fullscreen" then
        return Localization:t("settings.fullscreen"), Settings:getFullscreenLabel()
    elseif optionId == "vsync" then
        return Localization:t("settings.vsync"), Settings:getVsyncLabel()
    elseif optionId == "crt" then
        return Localization:t("settings.crt_filter"), Settings:getCrtLabel()
    elseif optionId == "cameraShake" then
        return Localization:t("settings.camera_shake"), Settings:getCameraShakeLabel()
    elseif optionId == "brightness" then
        return Localization:t("settings.brightness"), Settings:getBrightnessLabel()
    elseif optionId == "master" then
        return Localization:t("settings.sound"), formatPercent(Settings:getMasterPercent())
    elseif optionId == "music" then
        return Localization:t("settings.music"), formatPercent(Settings:getMusicPercent())
    end

    return Localization:t("menu.back")
end

function SettingsMenu:getViewport()
    local top = math.floor(self:getHeight() * 0.34)
    local bottom = self:getHeight() - 18
    return {
        x = 0,
        y = top,
        width = self:getWidth(),
        height = math.max(48, bottom - top),
    }
end

function SettingsMenu:buildLayout()
    local rows = {}
    local optionRows = {}
    local y = 0

    for _, section in ipairs(self.sections) do
        if section.title ~= "" then
            rows[#rows + 1] = {
                kind = "section",
                title = section.titleKey and Localization:t(section.titleKey) or section.title,
                y = y,
                height = SECTION_HEIGHT,
            }
            y = y + SECTION_HEIGHT
        end

        for _, optionId in ipairs(section.options) do
            if optionId == "back" then
                y = y + 12
            end
            local optionIndex = self.optionIndexById[optionId]
            local row = {
                kind = "option",
                optionId = optionId,
                optionIndex = optionIndex,
                y = y,
                height = OPTION_HEIGHT,
            }
            rows[#rows + 1] = row
            optionRows[optionIndex] = row
            y = y + OPTION_HEIGHT
        end

        y = y + SECTION_GAP
    end

    self.rows = rows
    self.optionRows = optionRows
    self.contentHeight = math.max(0, y - SECTION_GAP)
end

function SettingsMenu:getMaxScroll()
    local viewport = self:getViewport()
    return math.max(0, (self.contentHeight or 0) - viewport.height + 8)
end

function SettingsMenu:syncScrollToSelection(immediate)
    local row = self.optionRows and self.optionRows[self.selectedOption]
    if not row then
        return
    end

    local maxScroll = self:getMaxScroll()
    local target = self.scrollTargetY or 0
    if self.selectedOption <= SCROLL_EDGE_OPTIONS then
        target = 0
    elseif self.selectedOption > #self.menuOptions - SCROLL_EDGE_OPTIONS then
        target = maxScroll
    else
        local viewport = self:getViewport()
        target = row.y + row.height * 0.5 - viewport.height * 0.42
    end

    self.scrollTargetY = clampValue(target, 0, maxScroll)
    if immediate then
        self.scrollY = self.scrollTargetY
    end
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

function SettingsMenu:drawOptionBox(bounds, isSelected, isInactive)
    local optionId = self.menuOptions[self.currentDrawIndex or 1]
    love.graphics.setColor(0, 0, 0, 0.32)
    love.graphics.rectangle("fill", bounds.left + 1, bounds.top + 1, bounds.width, bounds.height)

    if optionId == "back" then
        love.graphics.setColor(isSelected and 0.40 or 0.31, isSelected and 0.34 or 0.27, isSelected and 0.28 or 0.23, 0.92)
    elseif isInactive then
        love.graphics.setColor(0.22, 0.22, 0.23, 0.78)
    elseif isSelected then
        love.graphics.setColor(0.35, 0.35, 0.36, 0.92)
    else
        love.graphics.setColor(0.26, 0.26, 0.27, 0.84)
    end
    love.graphics.rectangle("fill", bounds.left, bounds.top, bounds.width, bounds.height)

    if isSelected and not isInactive then
        love.graphics.setColor(0.78, 0.76, 0.62, 0.72)
        love.graphics.rectangle("line", bounds.left, bounds.top, bounds.width, bounds.height)
        SelectCorners.draw(bounds, {
            startedAt = self.lastSelectChange,
            scale = 1.85,
            padding = -1,
            color = {0.95, 0.92, 0.74, 1},
        })
    end
end

function SettingsMenu:getMarqueeOffset(text, maxWidth, isSelected)
    local textWidth = self.fontOptions:getWidth(text)
    if textWidth <= maxWidth or not isSelected then
        return 0
    end

    local overflow = textWidth - maxWidth
    local cycle = overflow / 24 + 1.0
    local time = (love.timer.getTime() - (self.lastSelectChange or 0)) % cycle
    local travelTime = math.max(overflow / 24, 0.001)
    if time >= travelTime then
        return overflow
    end
    return math.floor(time / travelTime * overflow + 0.5)
end

function SettingsMenu:drawClippedLabel(text, bounds, isSelected, isInactive)
    local padding = 12
    local textY = bounds.top + math.floor((bounds.height - self.fontOptions:getHeight()) / 2) - 1
    local clipX = bounds.left + padding
    local clipY = bounds.top
    local clipW = bounds.width - padding * 2
    local previousX, previousY, previousWidth, previousHeight = love.graphics.getScissor()
    local offset = self:getMarqueeOffset(text, clipW, isSelected)

    love.graphics.setScissor(clipX, clipY, clipW, bounds.height)
    local textX = clipX - offset
    if isInactive then
        love.graphics.setColor(0.45, 0.45, 0.45, 0.66)
    elseif isSelected then
        love.graphics.setColor(hexToRGB("f2f0df"))
    else
        love.graphics.setColor(hexToRGB("fbfaf7"))
    end
    love.graphics.print(text, textX, textY)

    if previousX then
        love.graphics.setScissor(previousX, previousY, previousWidth, previousHeight)
    else
        love.graphics.setScissor()
    end
end

function SettingsMenu:drawValue(text, y, bounds, isSelected, isInactive, optionId)
    if not text then
        return
    end

    local valueLeft = bounds.left + bounds.width + VALUE_GAP
    local textY = bounds.top + math.floor((bounds.height - self.fontOptions:getHeight()) / 2) - 1
    local arrowOption = self:isArrowOption(optionId)
    local valueText = text
    local padding = 2
    local clipX = valueLeft + (arrowOption and 16 or 0)
    local clipW = VALUE_WIDTH - (arrowOption and 32 or 0)
    local offset = self:getMarqueeOffset(valueText, clipW - padding * 2, isSelected)
    local previousX, previousY, previousWidth, previousHeight = love.graphics.getScissor()

    if isInactive then
        love.graphics.setColor(0.45, 0.45, 0.45, 0.66)
    elseif isSelected then
        love.graphics.setColor(hexToRGB("c9c6a4"))
    else
        love.graphics.setColor(hexToRGB("fbfaf7"))
    end

    love.graphics.setScissor(clipX, bounds.top, clipW, bounds.height)
    love.graphics.print(valueText, clipX + padding - offset, textY)
    if previousX then
        love.graphics.setScissor(previousX, previousY, previousWidth, previousHeight)
    else
        love.graphics.setScissor()
    end
end

function SettingsMenu:drawOption(text, valueText, y, isSelected, isInactive, bounds)
    local optionId = self.menuOptions[self.currentDrawIndex or 1]
    self:drawOptionBox(bounds, isSelected, isInactive)
    self:drawClippedLabel(text, bounds, isSelected, isInactive)
    self:drawValue(valueText, y, bounds, isSelected, isInactive, optionId)

    if self:isArrowOption(optionId) then
        local leftEnabled = not isInactive and self:canChangeOption(optionId, -1)
        local rightEnabled = not isInactive and self:canChangeOption(optionId, 1)
        local valueLeft = bounds.left + bounds.width + VALUE_GAP
        local leftArrowX = valueLeft
        local rightArrowX = valueLeft + VALUE_WIDTH - self.fontOptions:getWidth(">") - 2

        self.arrowBounds[self.currentDrawIndex] = {
            left = {
                x = valueLeft,
                y = y,
                width = math.max(30, VALUE_WIDTH * 0.5),
                height = self.fontOptions:getHeight() + 10,
                enabled = leftEnabled,
            },
            right = {
                x = valueLeft + VALUE_WIDTH * 0.5,
                y = y,
                width = math.max(30, VALUE_WIDTH * 0.5),
                height = self.fontOptions:getHeight() + 10,
                enabled = rightEnabled,
            },
        }

        self:drawArrow("<", leftArrowX, y, leftEnabled, isSelected, self.arrowBounds[self.currentDrawIndex].left)
        self:drawArrow(">", rightArrowX, y, rightEnabled, isSelected, self.arrowBounds[self.currentDrawIndex].right)
        love.graphics.setColor(1, 1, 1, 1)
        return
    end
end

function SettingsMenu:drawSection(title, y)
    love.graphics.setFont(self.fontOptions)
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.printf(title, 1, y + 1, self:getWidth(), "center")
    love.graphics.setColor(0.67, 0.70, 0.62, 0.92)
    love.graphics.printf(title, 0, y, self:getWidth(), "center")
end

function SettingsMenu:drawScrollbar(viewport)
    local maxScroll = self:getMaxScroll()
    if maxScroll <= 0 then
        return
    end

    local trackHeight = viewport.height - 8
    local thumbHeight = math.max(18, trackHeight * viewport.height / math.max(self.contentHeight or viewport.height, 1))
    local progress = (self.scrollY or 0) / maxScroll
    local thumbY = viewport.y + 4 + (trackHeight - thumbHeight) * progress
    local x = self:getWidth() - 10

    love.graphics.setColor(0, 0, 0, 0.25)
    love.graphics.rectangle("fill", x, viewport.y + 4, 2, trackHeight)
    love.graphics.setColor(0.65, 0.65, 0.62, 0.72)
    love.graphics.rectangle("fill", x, thumbY, 2, thumbHeight)
end

function SettingsMenu:draw()
    self.MenuTItle = Localization:t("menu.settings")
    love.graphics.setColor(hexToRGB("090909"))
    love.graphics.rectangle("fill", 0, 0, baseWidth * 2, baseHeight * 2)

    self:buildLayout()
    if (self.manualScrollTimer or 0) <= 0 then
        self:syncScrollToSelection(false)
    end
    self.arrowBounds = {}
    self.optionBounds = {}
    self:drawTitle()

    local viewport = self:getViewport()
    local contentY = viewport.y + 4 - (self.scrollY or 0)
    local previousX, previousY, previousWidth, previousHeight = love.graphics.getScissor()
    love.graphics.setScissor(viewport.x, viewport.y, viewport.width, viewport.height)

    love.graphics.setFont(self.fontOptions)
    for _, row in ipairs(self.rows or {}) do
        local y = math.floor(contentY + row.y + 0.5)
        if y + row.height >= viewport.y and y <= viewport.y + viewport.height then
            if row.kind == "section" then
                self:drawSection(row.title, y)
            else
                local optionText, valueText = self:getOptionLabel(row.optionIndex)
                local isInactive = self:isOptionIndexInactive(row.optionIndex)
                local isSelected = row.optionIndex == self.selectedOption and not isInactive
                local boxWidth = row.optionId == "back" and 132 or BOX_WIDTH
                local left = math.floor(self:getWidth() / 2 - (boxWidth + (valueText and VALUE_WIDTH + VALUE_GAP or 0)) / 2)
                local bounds = {
                    left = left,
                    top = y + 1,
                    width = boxWidth,
                    height = BOX_HEIGHT,
                }
                if valueText then
                    bounds.hitLeft = bounds.left
                    bounds.hitWidth = boxWidth + VALUE_GAP + VALUE_WIDTH
                end

                self.optionBounds[row.optionIndex] = bounds
                self.currentDrawIndex = row.optionIndex
                self:drawOption(optionText, valueText, y, isSelected, isInactive, bounds)
                self.currentDrawIndex = nil
            end
        end
    end

    if previousX then
        love.graphics.setScissor(previousX, previousY, previousWidth, previousHeight)
    else
        love.graphics.setScissor()
    end

    self:drawScrollbar(viewport)
    love.graphics.setColor(1, 1, 1, 1)
end

function SettingsMenu:update(dt)
    baseMenu.update(self, dt)
    self.manualScrollTimer = math.max(0, (self.manualScrollTimer or 0) - dt)
    if self.manualScrollTimer <= 0 then
        self:syncScrollToSelection(false)
    end

    local target = self.scrollTargetY or 0
    local current = self.scrollY or 0
    local delta = target - current
    if math.abs(delta) < 0.05 then
        self.scrollY = target
    else
        self.scrollY = current + delta * math.min(1, dt * SCROLL_SPEED)
    end
end

function SettingsMenu:moveSelection(direction)
    baseMenu.moveSelection(self, direction)
    self:syncScrollToSelection(false)
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
    self:syncScrollToSelection(false)
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

function SettingsMenu:getOptionAtPosition(x, y)
    local viewport = self:getViewport()
    if y < viewport.y or y > viewport.y + viewport.height then
        return nil
    end

    local closestIndex = nil
    local closestDistance = math.huge
    for i = 1, #self.menuOptions do
        local bounds = self.optionBounds and self.optionBounds[i]
        local hitLeft = bounds and (bounds.hitLeft or bounds.left)
        local hitWidth = bounds and (bounds.hitWidth or bounds.width)
        if bounds
            and x >= hitLeft
            and x <= hitLeft + hitWidth
            and y >= bounds.top
            and y <= bounds.top + bounds.height then
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

function SettingsMenu:wheelmoved(y)
    if (self:getMaxScroll() or 0) <= 0 then
        return false
    end

    self.inputMode = "mouse"
    self.manualScrollTimer = 0.8
    self.scrollTargetY = clampValue((self.scrollTargetY or self.scrollY or 0) - y * 24, 0, self:getMaxScroll())
    self.scrollY = clampValue(self.scrollY or 0, 0, self:getMaxScroll())
    return true
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
    self:syncScrollToSelection(false)

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

    if self:isToggleOption(optionId) or optionId == "screenSize" or optionId == "language" then
        self:changeSelectedOption(1)
        return true
    end

    local bounds = self.optionBounds[optionIndex]
    local relativeX = bounds and ((x - bounds.left) / bounds.width) or 0.5
    if relativeX < 0.5 then
        self:changeSelectedOption(-1)
    else
        self:changeSelectedOption(1)
    end
    return true
end

return SettingsMenu
