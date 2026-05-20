PointsManager = {}


function PointsManager:load()
    self.font = love.graphics.newFont("assets/fonts/ThaleahFat.ttf", 32)
    self.font:setFilter("nearest", "nearest")
    self.points = (GAME_FLAGS and GAME_FLAGS.weaponTestLevel) and 10000 or 100
    self.displayPoints = self.points
    self.targetPoints = self.points
    self.animationStartPoints = self.points
    self.valueAnimationTimer = 1
    self.valueAnimationDuration = 0.2
    self.animationMode = "idle"
    self.popTimer = 1
    self.popDuration = 0.18

    self.animationColor = "c7c093"
    self.animationTimer = 10
    self.confettiColors = {
        {1.00, 1.00, 1.00, 1},
        {1.00, 0.92, 0.08, 1},
        {1.00, 0.68, 0.00, 1},
        {0.84, 0.44, 0.00, 1},
    }
    self.lossColors = {
        {0.20, 0.16, 0.08, 1},
        {0.28, 0.22, 0.11, 1},
        {0.16, 0.13, 0.08, 1},
        {0.36, 0.29, 0.14, 1},
    }
end

function PointsManager:update(dt)
    self.animationTimer = self.animationTimer + dt
    self.popTimer = self.popTimer + dt

    if self.displayPoints ~= self.targetPoints then
        self.valueAnimationTimer = math.min(
            (self.valueAnimationTimer or 0) + dt,
            self.valueAnimationDuration or 0.2
        )

        local progress = self.valueAnimationTimer / (self.valueAnimationDuration or 0.2)
        local value = self.animationStartPoints + (self.targetPoints - self.animationStartPoints) * progress

        if progress >= 1 then
            self.displayPoints = self.targetPoints
        elseif self.targetPoints >= self.animationStartPoints then
            self.displayPoints = math.floor(value)
        else
            self.displayPoints = math.ceil(value)
        end
    end
end

function PointsManager:getPoints()
    return self.points
end 

function PointsManager:decreasePoints(points)
    self.animationTimer = 0
    self.animationColor = "3a4a6b"
    self.points = self.points - points
    if self.points <= 0 then self.points = 0 end
    self.animationStartPoints = self.displayPoints or self.points
    self.targetPoints = self.points
    self.valueAnimationTimer = 0
    self.animationMode = "loss"
    self.popTimer = 0
end

function PointsManager:increasePoints(points)
    if (points or 0) <= 0 then
        return
    end

    self.animationTimer = 0
    self.animationColor = "c7c093"
    self.points = self.points + points
    self.animationStartPoints = self.displayPoints or self.points
    self.targetPoints = self.points
    self.valueAnimationTimer = 0
    self.animationMode = "gain"
    self.popTimer = 0
end

function PointsManager:getConfettiColor(index)
    local colors = self.animationMode == "loss" and self.lossColors or self.confettiColors
    local colorIndex = (math.floor(self.animationTimer * 14 + index) % #colors) + 1
    return colors[colorIndex]
end

function PointsManager:drawText(text, x, y, scaleX, scaleY, colorize)
    local cursorX = x

    for i = 1, #text do
        local char = text:sub(i, i)
        local color = colorize and self:getConfettiColor(i) or {1, 1, 1, 1}
        love.graphics.setColor(color[1], color[2], color[3], color[4])
        love.graphics.print(char, cursorX, y, 0, scaleX, scaleY)
        cursorX = cursorX + self.font:getWidth(char) * scaleX
    end
end

function PointsManager:draw()
    if not Player.isAlive then return end
    local drawPoints = self.displayPoints or self.points
    local text = drawPoints .. "C"
    local textWidth = self.font:getWidth(text)
    local x = love.graphics.getWidth() / scale - textWidth - 15

    x = 128
    local y = 6
    local popProgress = math.min((self.popTimer or 1) / (self.popDuration or 0.18), 1)
    local popWave = math.sin(popProgress * math.pi)
    local isLoss = self.animationMode == "loss" and (self.animationTimer <= 0.35 or self.displayPoints ~= self.targetPoints)
    local scaleX = isLoss and (1 - popWave * 0.025) or (1 + popWave * 0.05)
    local scaleY = isLoss and (1 + popWave * 0.025) or (1 - popWave * 0.035)
    local originAdjustX = textWidth * (scaleX - 1) / 2
    local originAdjustY = self.font:getHeight() * (scaleY - 1) / 2
    local drawX = math.floor(x - originAdjustX + 0.5)
    local drawY = math.floor(y - originAdjustY + 0.5)
    
    love.graphics.setFont(self.font)
    --love.graphics.setColor(0.274, 0.4, 0.45, 1)
    love.graphics.setColor(0.05, 0, 0.05, 1)
    love.graphics.print(text, drawX + 3, drawY + 3, 0, scaleX, scaleY)
    
    love.graphics.setColor(1, 1, 1)
    local colorize = self.animationTimer <= 0.35 or self.displayPoints ~= self.targetPoints
    self:drawText(text, drawX, drawY, scaleX, scaleY, colorize)
    love.graphics.setColor(1, 1, 1)
end


return PointsManager
