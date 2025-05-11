local baseMenu = require("scripts/managers/menu/baseMenu")
local MainMenu = {}

setmetatable(MainMenu, { __index = baseMenu })


function MainMenu:load()
    baseMenu.load(self)
    self.MenuTItle = "GAME OVER"
    self.menuOptions = {"Start Game", "Exit"}
end

function MainMenu:draw()asd
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 0, 0, baseWidth, baseHeight)
    baseMenu.draw(self)
end


function MainMenu:onSelect()
    if self.selectedOption == 1 then
        loadGame()
    elseif self.selectedOption == 2 then
        love.event.quit()
    end
end


return MainMenu
