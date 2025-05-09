local MainMenu = {}

local menuOptions = {"Start Game", "Exit"}
local selectedOption = 1

local fontTitle = love.graphics.newFont("assets/fonts/ThaleahFat.ttf", 48)
local fontOptions = love.graphics.newFont("assets/fonts/ThaleahFat.ttf", 32)

function MainMenu:load()
    fontTitle:setFilter("nearest", "nearest")
    fontOptions:setFilter("nearest", "nearest")

    selectedOption = 1
end

function MainMenu:update(dt)

end

function MainMenu:draw()
    love.graphics.setFont(fontTitle)
    love.graphics.clear(hexToRGB("302c5e"))
    titleY = baseHeight / 2 - 60
    love.graphics.setColor(hexToRGB("fbfaf7")) 
    love.graphics.printf("Lua Project", 0, titleY, baseWidth, "center")

    love.graphics.setFont(fontOptions)

    for i, option in ipairs(menuOptions) do
        local y = titleY + 50 + i * 40
        if i == selectedOption then
            love.graphics.setColor(hexToRGB("c7c093"))
        else
            love.graphics.setColor(hexToRGB("fbfaf7")) 
        end
        love.graphics.printf(option, 0, y, baseWidth, "center")
    end

    love.graphics.setColor(hexToRGB("fbfaf7"))
end

function MainMenu:keypressed(key)
    if key == "up" then
        selectedOption = selectedOption - 1
        if selectedOption < 1 then selectedOption = #menuOptions end
    elseif key == "down" then
        selectedOption = selectedOption + 1
        if selectedOption > #menuOptions then selectedOption = 1 end
    elseif key == "return" or key == "space" then
        if selectedOption == 1 then
            loadGame()
        elseif selectedOption == 2 then
            love.event.quit()
        end
    end
end

return MainMenu
