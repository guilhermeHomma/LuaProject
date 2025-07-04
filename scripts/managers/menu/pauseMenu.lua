local baseMenu = require("scripts/managers/menu/baseMenu")
local pauseMenu = {}

setmetatable(pauseMenu, { __index = baseMenu })


function pauseMenu:load()
    baseMenu.load(self)
    self.MenuTItle = "PAUSED"
    --self.menuOptions = {"Continue", "Restart", "Go to menu"}
    self.menuOptions = {"Continue", "Restart", "Exit Game"}
end

function pauseMenu:draw()
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 0, 0, baseWidth * 2, baseHeight * 2)
    baseMenu.draw(self)
end

function pauseMenu:onSelect()
    if self.selectedOption == 1 then
        changePause()
    elseif self.selectedOption == 2 then
        loadGame()
    elseif self.selectedOption == 3 then
        quitGame()
    end
end

return pauseMenu