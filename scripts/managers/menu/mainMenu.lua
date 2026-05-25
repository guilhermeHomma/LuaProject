local baseMenu = require("scripts/managers/menu/baseMenu")
local MainMenu = {}

setmetatable(MainMenu, { __index = baseMenu })


local sheetImage = love.graphics.newImage("assets/sprites/menu/menuart.png")
local sheetWidth, sheetHeight = sheetImage:getDimensions()
local frameWidth, frameHeight = 324, 184
local animationTimer = 0
local currentFrame = 1
local frameDuration = 0.3
local animationQuads = {}

sheetImage:setFilter("nearest", "nearest")

for i = 0, math.floor(sheetWidth / frameWidth) - 1 do
    table.insert(animationQuads, love.graphics.newQuad(i * frameWidth, 0, frameWidth, frameHeight, sheetWidth, sheetHeight))
end


function MainMenu:load()
    baseMenu.load(self)
    self.MenuTItle = "mobize"
    self.menuOptions = {"start game", "settings", "exit game"}
    self.fontTitle = love.graphics.newFont("assets/fonts/ThaleahFat.ttf", 56)
    self.fontTitle:setFilter("nearest", "nearest")

    self.fontOptions = love.graphics.newFont("assets/fonts/ThaleahFat.ttf", 32)
    self.fontOptions:setFilter("nearest", "nearest")


end

function MainMenu:update(dt)
    animationTimer = animationTimer + dt
    if animationTimer >= frameDuration then
        animationTimer = animationTimer - frameDuration
        currentFrame = currentFrame % #animationQuads + 1
    end

    baseMenu.update(self, dt)
end

function MainMenu:draw()

    love.graphics.setColor(hexToRGB("090909"))
    love.graphics.rectangle("fill", 0, 0, baseWidth * 2, baseHeight * 2)

    local quad = animationQuads[currentFrame]
    --love.graphics.draw(sheetImage, quad, -6, -6, 0, 3, 3)


    baseMenu.draw(self)
    love.graphics.setColor(hexToRGB("ffffff"))

end


function MainMenu:onSelect()
    if self.selectedOption == 1 then
        loadGame()
    elseif self.selectedOption == 2 then
        openSettings(STATES.mainMenu)
    elseif self.selectedOption == 3 then
        openQuitGameConfirm(STATES.mainMenu)
    end
end


return MainMenu
