local baseMenu = require("scripts/managers/menu/baseMenu")

local ConfirmMenu = {}
setmetatable(ConfirmMenu, { __index = baseMenu })

function ConfirmMenu:load()
    baseMenu.load(self)
    self.MenuTItle = "CONFIRM"
    self.message = "return to main menu?"
    self.menuOptions = {"yes", "no"}
    self.onConfirm = nil
end

function ConfirmMenu:open(title, message, onConfirm)
    self.MenuTItle = title or "CONFIRM"
    self.message = message or "are you sure?"
    self.onConfirm = onConfirm
    self.selectedOption = 2
    self.mouseNeedsSync = true
end

function ConfirmMenu:draw()
    love.graphics.setColor(0.03, 0.02, 0.02, 0.94)
    love.graphics.rectangle("fill", 0, 0, baseWidth, baseHeight)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(self.fontOptions)
    love.graphics.printf(self.message, 0, self:getHeight() / 2 - 10, self:getWidth(), "center")
    baseMenu.draw(self)
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
    if key == "escape" then
        closeConfirmMenu()
        return
    end

    baseMenu.keypressed(self, key)
end

return ConfirmMenu
