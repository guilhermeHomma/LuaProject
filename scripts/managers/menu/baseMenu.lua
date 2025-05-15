
local baseMenu = {}

function baseMenu:load()
    self.menuOptions = {}
    self.selectedOption = 1
    self.MenuTItle = "MENU BASE - make a new menu"
    self.fontTitle = love.graphics.newFont("assets/fonts/ThaleahFat.ttf", 64)
    self.fontTitle:setFilter("nearest", "nearest")

    self.fontOptions = love.graphics.newFont("assets/fonts/ThaleahFat.ttf", 48)
    self.fontOptions:setFilter("nearest", "nearest")
end


function baseMenu:onSelect()

end

function baseMenu:drawTitle()
    love.graphics.setFont(self.fontTitle)

    love.graphics.setColor(hexToRGB("fbfaf7"))
    love.graphics.printf(self.MenuTItle, 0, self:getHeight() / 2 - 60, self:getWidth(), "center")
    love.graphics.setColor(hexToRGB("ffffff"))

end

function baseMenu:drawOption(text, x, y, def, isSelected)
    if not isSelected then
        --drawOutline(text, x, y, self:getWidth(), def)
        love.graphics.setColor(hexToRGB("fbfaf7"))
        love.graphics.printf(text, x, y, self:getWidth(), def)
        return
    end

    local time = love.timer.getTime()
    local blink = math.floor(time * 10) % 2 == 0 
    
    if blink then
        --drawOutline(text, x, y, self:getWidth(), def)
        love.graphics.setColor(hexToRGB("c7c093"))
        love.graphics.printf(text, x, y, self:getWidth(), def)
        love.graphics.setColor(hexToRGB("fbfaf7"))
        return
    end

    --drawOutline(text, x, y, baseWidth, def)
    love.graphics.setColor(hexToRGB("fbfaf7"))
    love.graphics.printf(text, x, y, self:getWidth(), def)
end

function baseMenu:getHeight()
    return love.graphics.getHeight() / scale
end

function baseMenu:getWidth()
    return love.graphics.getWidth() / scale
end


function baseMenu:draw()
    --love.graphics.setColor(0, 0, 0, 0.5)
    --love.graphics.rectangle("fill", 0, 0, baseWidth, baseHeight)


    self:drawTitle()

    love.graphics.setFont(self.fontOptions)
    love.graphics.setColor(hexToRGB("fbfaf7"))

    local centerHeight =  self:getHeight() / 2    

    for i, option in ipairs(self.menuOptions) do
        local y = (centerHeight) + i * 30
        local isSelected = i == self.selectedOption
        self:drawOption(option, 0, y, "center", isSelected)
    end

    love.graphics.setColor(1, 1, 1)
end

function baseMenu:update(dt)

end

function baseMenu:keypressed(key)

    local sound = love.audio.newSource("assets/sfx/menu/menu-button.wav", "static")
    sound:setVolume(1)
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
    else
        return
    end

    sound:play()
end

return baseMenu