
local Pause = {}

local menuOptions = {"Continue", "Restart", "Go to menu"}
local selectedOption = 1

local width = 1
local height = 1

function Pause:load()
    width = baseWidth * scale
    height = baseHeight * scale

    self.fontTitle = love.graphics.newFont("assets/fonts/ThaleahFat.ttf", 48)
    self.fontTitle:setFilter("nearest", "nearest")

    self.fontOptions = love.graphics.newFont("assets/fonts/ThaleahFat.ttf", 32)
    self.fontOptions:setFilter("nearest", "nearest")
end

function Pause:draw()
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 0, 0, baseWidth, baseHeight)

    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(self.fontTitle)
    love.graphics.printf("PAUSED", 0, baseHeight / 2 - 60, baseWidth, "center")

    love.graphics.setFont(self.fontOptions)
    for i, option in ipairs(menuOptions) do
        local y = (baseHeight / 2) + i * 25
        if i == selectedOption then
            love.graphics.setColor(1, 1, 0)
        else
            love.graphics.setColor(1, 1, 1)
        end
        love.graphics.printf(option, 0, y, baseWidth, "center")
    end

    love.graphics.setColor(1, 1, 1)
end

function Pause:update(key)

end

function Pause:keypressed(key)
    if key == "up" then
        selectedOption = selectedOption - 1
        if selectedOption < 1 then selectedOption = #menuOptions end
    elseif key == "down" then
        selectedOption = selectedOption + 1
        if selectedOption > #menuOptions then selectedOption = 1 end
    elseif key == "return" or key == "space" then
        if selectedOption == 1 then
            changePause()
        elseif selectedOption == 2 then
            loadGame()
        elseif selectedOption == 3 then
            quitToMenu()
        end
    end
end

return Pause