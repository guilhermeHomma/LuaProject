local baseMenu = require("scripts/managers/menu/baseMenu")
local MainMenu = {}

setmetatable(MainMenu, { __index = baseMenu })


function MainMenu:load()
    baseMenu.load(self)
    self.MenuTItle = "CATLIPS"
    self.menuOptions = {"start game", "exit",} -- "options"}
    self.fontTitle = love.graphics.newFont("assets/fonts/ThaleahFat.ttf", 80)
    self.fontTitle:setFilter("nearest", "nearest")

    self.fontOptions = love.graphics.newFont("assets/fonts/ThaleahFat.ttf", 48)
    self.fontOptions:setFilter("nearest", "nearest")


end

function MainMenu:drawOption(text, x, y, def, isSelected)
    if not isSelected then
        drawOutline(text, x, y, self:getWidth(), def)
        love.graphics.setColor(hexToRGB("5c7873"))
        love.graphics.printf(text, x, y, self:getWidth(), def)
        love.graphics.setColor(hexToRGB("fbfaf7"))
        return
    end

    local time = love.timer.getTime()
    local blink = math.floor(time * 10) % 2 == 0 
    
    if blink then
        drawOutline(text, x, y, self:getWidth(), def)
        love.graphics.setColor(hexToRGB("c7c093"))
        love.graphics.printf(text, x, y, self:getWidth(), def)
        love.graphics.setColor(hexToRGB("fbfaf7"))
        return
    end
    drawOutline(text, x, y, self:getWidth(), def)

    --drawOutline(text, x, y, self:getWidth(), def)
    love.graphics.setColor(hexToRGB("5c7873"))
    love.graphics.printf(text, x, y, self:getWidth(), def)
end



function MainMenu:drawTitle()
    love.graphics.setColor(hexToRGB("fbfaf7"))
    love.graphics.setFont(self.fontTitle)

    local x = 0
    local y = self:getHeight() / 2 - 100

    love.graphics.setColor(hexToRGB("090909"))
    --love.graphics.setColor(hexToRGB("fbfaf7"))
    --outline
    --right
    love.graphics.printf(self.MenuTItle, x+6, y, self:getWidth(), "center")
    love.graphics.printf(self.MenuTItle, x+3, y+3, self:getWidth(), "center")
    --left
    love.graphics.printf(self.MenuTItle, x-3, y, self:getWidth(), "center")
    love.graphics.printf(self.MenuTItle, x-3, y+3, self:getWidth(), "center")
    --up
    love.graphics.printf(self.MenuTItle, x, y-3, self:getWidth(), "center")
    love.graphics.printf(self.MenuTItle, x+3, y-3, self:getWidth(), "center")
    --up
    love.graphics.printf(self.MenuTItle, x, y+6, self:getWidth(), "center")

    love.graphics.setColor(hexToRGB("c7c093"))
    love.graphics.printf(self.MenuTItle, x+3, y, self:getWidth(), "center")
    love.graphics.printf(self.MenuTItle, x, y+3, self:getWidth(), "center")
    love.graphics.setColor(hexToRGB("3a4a6b"))

    love.graphics.printf(self.MenuTItle, x, y, self:getWidth(), "center")
    love.graphics.setColor(hexToRGB("fbfaf7"))

end

-- function MainMenu:drawOption(isSelected)
--     if not isSelected then isSelected = false end
-- end

function MainMenu:draw()
    love.graphics.setColor(hexToRGB("302c5e"))
    love.graphics.setColor(hexToRGB("85917a"))
    love.graphics.rectangle("fill", 0, 0, baseWidth, baseHeight)
    baseMenu.draw(self)
    love.graphics.setColor(hexToRGB("ffffff"))

end


function MainMenu:onSelect()
    if self.selectedOption == 1 then
        loadGame()
    elseif self.selectedOption == 2 then
        love.event.quit()
    end
end


return MainMenu
