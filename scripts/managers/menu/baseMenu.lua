
local baseMenu = {}


function baseMenu:load()
    self.menuOptions = {}
    self.selectedOption = 1
    self.MenuTItle = "MENU BASE - make a new menu"
    self.fontTitle = love.graphics.newFont("assets/fonts/ThaleahFat.ttf", 48)
    self.fontTitle:setFilter("nearest", "nearest")

    self.fontOptions = love.graphics.newFont("assets/fonts/ThaleahFat.ttf", 32)
    self.fontOptions:setFilter("nearest", "nearest")
    self.scale = 1
    self.lastSelectChange = -1

    self.scaleTarget = 1

    self.selectSprite = love.graphics.newImage("assets/sprites/menu/menu-select.png")

end


function baseMenu:onSelect()

end

function baseMenu:drawSelectSprite(text, y)

    local spriteX =  math.ceil(self:getWidth()/ 2 - self.fontOptions:getWidth(text) / 2 - 30)
    love.graphics.draw(self.selectSprite, spriteX, y+ 3, 0, 3, 3)
end

function baseMenu:drawTitle()
    love.graphics.setFont(self.fontTitle)


    local titleX, titleY = 01, self:getHeight() / 2 - 60
    --drawOutline(self.MenuTItle, titleX, titleY, self:getWidth(), "center")

    love.graphics.setColor(hexToRGB("fbfaf7"))  
    love.graphics.printf(self.MenuTItle, titleX, titleY, self:getWidth(), "center")
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
    
    self:drawSelectSprite(text, y)

    if blink then
        --drawOutline(text, x, y, self:getWidth(), def)
        love.graphics.setColor(hexToRGB("c7c093"))
        love.graphics.printf(text, x, y, self:getWidth(), def)
        love.graphics.setColor(hexToRGB("fbfaf7"))
        return
    end

    --drawOutline(text, x, y, self:getWidth(), def)
    love.graphics.setColor(hexToRGB("fbfaf7"))

    love.graphics.printf(text, x, y, self:getWidth(), def)


end

function baseMenu:getHeight()
    return love.graphics.getHeight()/ scale / self.scale
end

function baseMenu:getWidth()
    return love.graphics.getWidth() / scale / self.scale
end


function baseMenu:draw()

    self:drawTitle()
    love.graphics.setFont(self.fontOptions)
    love.graphics.setColor(hexToRGB("fbfaf7"))

    for i, option in ipairs(self.menuOptions) do
        
        local isSelected = i == self.selectedOption
        love.graphics.push()
        if isSelected and self.lastSelectChange + 0.06 > love.timer.getTime() then
            self.scale = 1.05
            love.graphics.scale(1.05, 1.05)
        end
        local centerHeight =  self:getHeight() / 2    
        local y = (centerHeight) + (i * 30)
        self:drawOption(option, 0, y, "center", isSelected)
        self.scale = 1
        love.graphics.pop()

    end

    love.graphics.setColor(1, 1, 1)
end

function baseMenu:update(dt)

end

function baseMenu:keypressed(key)

    local sound = love.audio.newSource("assets/sfx/menu/menu-button.mp3", "static")
    sound:setVolume(1)
    sound:setPitch(0.95 + math.random() * 0.1)

    if key == "up" then
        self.selectedOption = self.selectedOption - 1
        if self.selectedOption < 1 then self.selectedOption = #self.menuOptions end
    elseif key == "down" then
        self.selectedOption = self.selectedOption + 1
        if self.selectedOption > #self.menuOptions then self.selectedOption = 1 end
    elseif key == "return" or key == "space" then
        sound = love.audio.newSource("assets/sfx/menu/menu-selected.mp3", "static")
        sound:setPitch(1)
        sound:setVolume(0.2)

        self:onSelect()
    else
        return
    end

    self.lastSelectChange = love.timer.getTime()
    sound:play()
end

return baseMenu