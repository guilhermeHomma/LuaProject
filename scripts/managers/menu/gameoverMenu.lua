
local baseMenu = require("scripts/managers/menu/baseMenu")
local Localization = require("scripts/managers/localization")
local gameOverMenu = {}

setmetatable(gameOverMenu, { __index = baseMenu })


function gameOverMenu:load()
    baseMenu.load(self)
    self.MenuTItle = Localization:t("menu.game_over")
    self.menuOptions = {"new_run", "main_menu"}
end

function gameOverMenu:getOptionLabel(index)
    return Localization:t("menu." .. self.menuOptions[index])
end

function gameOverMenu:draw()
    self.MenuTItle = Localization:t("menu.game_over")
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 0, 0, baseWidth * 2, baseHeight * 2)
    baseMenu.draw(self)
end


function gameOverMenu:onSelect()
    if self.selectedOption == 1 then
        loadGame()
    elseif self.selectedOption == 2 then
        openReturnToMenuConfirm(STATES.gameDead)
    end
end

return gameOverMenu
