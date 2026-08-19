local baseMenu = require("scripts/managers/menu/baseMenu")
local Localization = require("scripts/managers/localization")
local Fonts = require("scripts/ui/fonts")
local TransitionManager = require("scripts.managers.transitionManager")
local MainMenu = {}

setmetatable(MainMenu, { __index = baseMenu })


local sheetImage = love.graphics.newImage("assets/sprites/menu/menuart.png")
local backgroundImage = love.graphics.newImage("assets/sprites/menu/capa-mobize-mono-menu.png")
local backgroundShader = love.graphics.newShader("scripts/shaders/oldTvMenuBackground.glsl")
local sheetWidth, sheetHeight = sheetImage:getDimensions()
local frameWidth, frameHeight = 324, 184
local animationTimer = 0
local currentFrame = 1
local frameDuration = 0.3
local animationQuads = {}
local versionFont = Fonts:logo("version")

sheetImage:setFilter("nearest", "nearest")
backgroundImage:setFilter("linear", "linear")
for i = 0, math.floor(sheetWidth / frameWidth) - 1 do
    table.insert(animationQuads, love.graphics.newQuad(i * frameWidth, 0, frameWidth, frameHeight, sheetWidth, sheetHeight))
end


function MainMenu:load()
    baseMenu.load(self)
    self.MenuTItle = "mobize"
    self.menuOptions = {"start_game", "settings", "exit_game"}
    self.fontTitle = Fonts:logo("mainLogo")
    self.lockOnSelect = true

    self.fontOptions = Fonts:translated("menuOption")


end

function MainMenu:update(dt)
    if self:isInteractionLocked() and (not TransitionManager or not TransitionManager.isTransiting) then
        self:unlockInteractions()
    end

    animationTimer = animationTimer + dt
    if animationTimer >= frameDuration then
        animationTimer = animationTimer - frameDuration
        currentFrame = currentFrame % #animationQuads + 1
    end

    baseMenu.update(self, dt)
end

function MainMenu:getOptionLabel(index)
    return Localization:t("menu." .. self.menuOptions[index])
end

function MainMenu:draw()

    love.graphics.setColor(hexToRGB("090909"))
    love.graphics.rectangle("fill", 0, 0, baseWidth * 2, baseHeight * 2)

    local imageWidth, imageHeight = backgroundImage:getDimensions()
    local backgroundScale = math.max(baseWidth / imageWidth, baseHeight / imageHeight)
    local backgroundX = math.floor((baseWidth - imageWidth * backgroundScale) / 2)
    local backgroundY = math.floor((baseHeight - imageHeight * backgroundScale) / 2)
    backgroundShader:send("u_time", love.timer.getTime() * 0.3)
    backgroundShader:send("u_intensity", 0.3)
    love.graphics.setShader(backgroundShader)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(backgroundImage, backgroundX, backgroundY, 0, backgroundScale, backgroundScale)
    love.graphics.setShader()

    local quad = animationQuads[currentFrame]
    --love.graphics.draw(sheetImage, quad, -6, -6, 0, 3, 3)


    baseMenu.draw(self)
    love.graphics.setFont(versionFont)
    love.graphics.setColor(1, 1, 1, 0.22)
    love.graphics.print("v" .. tostring(GAME_VERSION or "0.1.0a"), 6, baseHeight - 32)
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
