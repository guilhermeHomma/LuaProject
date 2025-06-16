
local baseMenu = require("scripts/managers/menu/baseMenu")
local gameOverMenu = {}

setmetatable(gameOverMenu, { __index = baseMenu })


function gameOverMenu:load()
    baseMenu.load(self)
    self.MenuTItle = "GAME OVER"
    self.menuOptions = {"Restart", "Exit Game"}
end

function gameOverMenu:draw()
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 0, 0, self:getWidth(), self:getHeight())
    baseMenu.draw(self)
end


function gameOverMenu:onSelect()
    if self.selectedOption == 1 then
        loadGame()
    elseif self.selectedOption == 2 then
        quitGame()
    end
end

return gameOverMenu