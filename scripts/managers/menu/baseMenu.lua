
local baseMenu = {}

function baseMenu:load()
    self.menuOptions = {}
    self.selectedOption = 1
    self.MenuTItle = "MENU BASE - make a new menu"
    self.fontTitle = love.graphics.newFont("assets/fonts/ThaleahFat.ttf", 48)
    self.fontTitle:setFilter("nearest", "nearest")

    self.fontOptions = love.graphics.newFont("assets/fonts/ThaleahFat.ttf", 32)
    self.fontOptions:setFilter("nearest", "nearest")
end


function baseMenu:onSelect()
    if self.selectedOption == 1 then
        loadGame()

    elseif self.selectedOption == 2 then
        quitToMenu()
    end
end

function baseMenu:draw()
    --love.graphics.setColor(0, 0, 0, 0.5)
    --love.graphics.rectangle("fill", 0, 0, baseWidth, baseHeight)

    love.graphics.setColor(hexToRGB("fbfaf7"))
    love.graphics.setFont(self.fontTitle)
    love.graphics.printf("GAME OVER", 0, baseHeight / 2 - 60, baseWidth, "center")

    love.graphics.setFont(self.fontOptions)

    local time = love.timer.getTime()
    local blink = math.floor(time * 10) % 2 == 0 

    for i, option in ipairs(self.menuOptions) do
        local y = (baseHeight / 2) + i * 25

        if i == self.selectedOption and blink then
            love.graphics.printf(option, 0, y, baseWidth + 2, "center")
            love.graphics.setColor(hexToRGB("c7c093"))

        else
            love.graphics.setColor(hexToRGB("fbfaf7"))
        end
        love.graphics.printf(option, 0, y, baseWidth, "center")
    end

    love.graphics.setColor(1, 1, 1)
end

function baseMenu:update(dt)

end

function baseMenu:keypressed(key)

    local sound = love.audio.newSource("assets/sfx/menu/menu-button.wav", "static")
    sound:setVolume(0.4)
    sound:setPitch(0.95 + math.random() * 0.1)

    if key == "up" then
        self.selectedOption = self.selectedOption - 1
        if self.selectedOption < 1 then self.selectedOption = #self.menuOptions end
    elseif key == "down" then
        self.selectedOption = self.selectedOption + 1
        if self.selectedOption > #self.menuOptions then self.selectedOption = 1 end
    elseif key == "return" or key == "space" then
        sound = love.audio.newSource("assets/sfx/menu/menu-selected.wav", "static")
        sound:setPitch(1)
        sound:setVolume(1)

        self:onSelect()
    end

    sound:play()
end

return baseMenu