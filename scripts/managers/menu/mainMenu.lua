local baseMenu = require("scripts/managers/menu/baseMenu")
local Localization = require("scripts/managers/localization")
local Fonts = require("scripts/ui/fonts")
local TransitionManager = require("scripts.managers.transitionManager")
local MainMenu = {}

setmetatable(MainMenu, { __index = baseMenu })


local sheetImage = love.graphics.newImage("assets/sprites/menu/menuart.png")
local backgroundImage = love.graphics.newImage("assets/sprites/menu/capa-mobize-mono-menu.png")
local backgroundShader = love.graphics.newShader("scripts/shaders/oldTvMenuBackground.glsl")
local elementsFadeShader = love.graphics.newShader([[
    extern number opacity;
    vec4 effect(vec4 color, Image texture, vec2 textureCoords, vec2 screenCoords) {
        return Texel(texture, textureCoords) * color * opacity;
    }
]])
local sheetWidth, sheetHeight = sheetImage:getDimensions()
local frameWidth, frameHeight = 324, 184
local animationTimer = 0
local currentFrame = 1
local frameDuration = 0.3
local animationQuads = {}
local versionFont = Fonts:logo("version")
local ENTRY_ZOOM_DURATION = 0.8
local EXIT_ZOOM_DURATION = 0.8
local ELEMENT_DURATION = 0.5
local ELEMENT_TRAVEL_PIXELS = 20
local PARALLAX_MAX_PIXELS = 10

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
    self.entering = false
    self.exiting = false
    self.transitionTimer = ENTRY_ZOOM_DURATION
    self.backgroundOffsetX = 0
    self.backgroundOffsetY = 0
    self.pendingStartGame = false
    self.elementsCanvas = love.graphics.newCanvas(baseWidth, baseHeight)
    self.elementsCanvas:setFilter("nearest", "nearest")


end

function MainMenu:beginEntry()
    self.entering = true
    self.exiting = false
    self.transitionTimer = 0
    self.backgroundOffsetX = 0
    self.backgroundOffsetY = 0
    self.pendingStartGame = false
    self.mouseNeedsSync = true
end

function MainMenu:beginExit()
    self.exiting = true
    self.entering = false
    self.transitionTimer = 0
end

function MainMenu:isInteractionLocked()
    return baseMenu.isInteractionLocked(self)
        or (self.entering and self.transitionTimer < ELEMENT_DURATION) or self.exiting
end

local function smoothstep(value)
    local t = math.max(0, math.min(1, value))
    return t * t * t * (t * (t * 6 - 15) + 10)
end

function MainMenu:getTransitionAmount()
    if self.entering then
        return 1 - smoothstep(self.transitionTimer / ENTRY_ZOOM_DURATION)
    elseif self.exiting then
        return smoothstep(self.transitionTimer / EXIT_ZOOM_DURATION)
    end
    return 0
end

function MainMenu:getElementTransitionAmount()
    if self.entering then
        return 1 - smoothstep(self.transitionTimer / ELEMENT_DURATION)
    elseif self.exiting then
        local t = math.max(0, math.min(1, self.transitionTimer / ELEMENT_DURATION))
        return t * t * t
    end
    return 0
end

function MainMenu:update(dt)
    if self.entering or self.exiting then
        local duration = self.entering and ENTRY_ZOOM_DURATION or EXIT_ZOOM_DURATION
        self.transitionTimer = math.min(self.transitionTimer + dt, duration)
    end
    if self.entering and self.transitionTimer >= ENTRY_ZOOM_DURATION then
        self.entering = false
    end
    if self.pendingStartGame and self.transitionTimer >= ELEMENT_DURATION then
        self.pendingStartGame = false
        loadGame()
    end
    if baseMenu.isInteractionLocked(self) and not TransitionManager.isTransiting and not self.exiting then
        self:unlockInteractions()
    end

    local mouseX = (love.mouse.getX() - viewportOffsetX) / scale
    local mouseY = (love.mouse.getY() - viewportOffsetY) / scale
    local targetX = math.max(-1, math.min(1, mouseX / baseWidth * 2 - 1)) * PARALLAX_MAX_PIXELS
    local targetY = math.max(-1, math.min(1, mouseY / baseHeight * 2 - 1)) * PARALLAX_MAX_PIXELS
    local follow = 1 - math.exp(-5 * dt)
    self.backgroundOffsetX = self.backgroundOffsetX + (targetX - self.backgroundOffsetX) * follow
    self.backgroundOffsetY = self.backgroundOffsetY + (targetY - self.backgroundOffsetY) * follow

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
    local transitionAmount = self:getTransitionAmount()
    local backgroundScale = math.max((baseWidth + PARALLAX_MAX_PIXELS * 2) / imageWidth,
            (baseHeight + PARALLAX_MAX_PIXELS * 2) / imageHeight)
        * (1 + 0.15 * transitionAmount)
    local backgroundX = (baseWidth - imageWidth * backgroundScale) / 2 + self.backgroundOffsetX
    local backgroundY = (baseHeight - imageHeight * backgroundScale) / 2 + self.backgroundOffsetY
    backgroundShader:send("u_time", love.timer.getTime() * 0.3)
    backgroundShader:send("u_intensity", 0.3)
    love.graphics.setShader(backgroundShader)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(backgroundImage, backgroundX, backgroundY, 0, backgroundScale, backgroundScale)
    love.graphics.setShader()

    local quad = animationQuads[currentFrame]
    --love.graphics.draw(sheetImage, quad, -6, -6, 0, 3, 3)


    if self.elementsCanvas:getWidth() ~= baseWidth or self.elementsCanvas:getHeight() ~= baseHeight then
        self.elementsCanvas = love.graphics.newCanvas(baseWidth, baseHeight)
        self.elementsCanvas:setFilter("nearest", "nearest")
    end
    local previousCanvas = love.graphics.getCanvas()
    love.graphics.setCanvas({self.elementsCanvas, stencil = true})
    love.graphics.clear(0, 0, 0, 0)
    baseMenu.draw(self)
    love.graphics.setCanvas(previousCanvas)
    local elementAmount = self:getElementTransitionAmount()
    local blendMode, alphaMode = love.graphics.getBlendMode()
    love.graphics.setBlendMode("alpha", "premultiplied")
    elementsFadeShader:send("opacity", 1 - elementAmount)
    love.graphics.setShader(elementsFadeShader)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.elementsCanvas, 0, -ELEMENT_TRAVEL_PIXELS * elementAmount)
    love.graphics.setShader()
    love.graphics.setBlendMode(blendMode, alphaMode)
    love.graphics.setFont(versionFont)
    love.graphics.setColor(1, 1, 1, 0.22)
    love.graphics.print("v" .. tostring(GAME_VERSION or "0.1.0a"), 6, baseHeight - 32)
    love.graphics.setColor(hexToRGB("ffffff"))

end


function MainMenu:onSelect()
    if self.selectedOption == 1 then
        self:beginExit()
        self.pendingStartGame = true
    elseif self.selectedOption == 2 then
        openSettings(STATES.mainMenu)
    elseif self.selectedOption == 3 then
        openQuitGameConfirm(STATES.mainMenu)
    end
end


return MainMenu
