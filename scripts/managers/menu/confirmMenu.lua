local baseMenu = require("scripts/managers/menu/baseMenu")
local Localization = require("scripts/managers/localization")
local TransitionManager = require("scripts.managers.transitionManager")

local ConfirmMenu = {}
setmetatable(ConfirmMenu, { __index = baseMenu })

function ConfirmMenu:load()
    baseMenu.load(self)
    self.MenuTItle = Localization:t("menu.confirm")
    self.message = Localization:t("confirm.return_menu")
    self.menuOptions = {"yes", "no"}
    self.onConfirm = nil
    self.lockOnSelect = true
end

function ConfirmMenu:open(title, message, onConfirm)
    self:unlockInteractions()
    self.titleKey = title
    self.messageKey = message
    self.MenuTItle = title and Localization:t(title) or Localization:t("menu.confirm")
    self.message = message and Localization:t(message) or Localization:t("confirm.are_you_sure")
    self.onConfirm = onConfirm
    self.selectedOption = 2
    self.mouseNeedsSync = true
end

function ConfirmMenu:update(dt)
    if self:isInteractionLocked() and not TransitionManager.isTransiting then
        self:unlockInteractions()
    end

    baseMenu.update(self, dt)
end

function ConfirmMenu:draw()
    self.MenuTItle = self.titleKey and Localization:t(self.titleKey) or Localization:t("menu.confirm")
    self.message = self.messageKey and Localization:t(self.messageKey) or self.message
    love.graphics.setColor(0.03, 0.02, 0.02, 0.94)
    love.graphics.rectangle("fill", 0, 0, baseWidth, baseHeight)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(self.fontOptions)
    love.graphics.printf(self.message, 0, self:getHeight() / 2 - 10, self:getWidth(), "center")
    baseMenu.draw(self)
end

function ConfirmMenu:getOptionLabel(index)
    return Localization:t("menu." .. self.menuOptions[index])
end

function ConfirmMenu:onSelect()
    if self.selectedOption == 1 then
        local callback = self.onConfirm
        if callback then
            callback()
        else
            closeConfirmMenu()
        end
        return
    end

    closeConfirmMenu()
end

function ConfirmMenu:keypressed(key)
    if self:isInteractionLocked() then
        return true
    end

    if key == "escape" then
        closeConfirmMenu()
        return
    end

    baseMenu.keypressed(self, key)
end

return ConfirmMenu
