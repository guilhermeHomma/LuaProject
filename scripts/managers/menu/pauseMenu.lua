local baseMenu = require("scripts/managers/menu/baseMenu")
local Localization = require("scripts/managers/localization")
local pauseMenu = {}

setmetatable(pauseMenu, { __index = baseMenu })


function pauseMenu:load()
    baseMenu.load(self)
    self.MenuTItle = Localization:t("menu.paused")
    self.menuOptions = {"continue", "settings", "new_run", "main_menu"}
end

function pauseMenu:getOptionLabel(index)
    return Localization:t("menu." .. self.menuOptions[index])
end

function pauseMenu:draw()
    self.MenuTItle = Localization:t("menu.paused")
    love.graphics.setColor(0.03, 0.02, 0.02, 1)
    love.graphics.rectangle("fill", 0, 0, baseWidth * 2, baseHeight * 2)
    baseMenu.draw(self)
end

function pauseMenu:onSelect()
    if self.selectedOption == 1 then
        changePause()
    elseif self.selectedOption == 2 then
        openSettings(STATES.gamePause)
    elseif self.selectedOption == 3 then
        openRestartConfirm(STATES.gamePause)
    elseif self.selectedOption == 4 then
        openReturnToMenuConfirm(STATES.gamePause)
    end
end

return pauseMenu
