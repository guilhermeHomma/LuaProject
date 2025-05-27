PointsManager = {}


function PointsManager:load()
    self.font = love.graphics.newFont("assets/fonts/ThaleahFat.ttf", 32)
    self.font:setFilter("nearest", "nearest")
    self.points = 1000

    self.animationColor = "c7c093"
    self.animationTimer = 10
end

function PointsManager:update(dt)
    self.animationTimer = self.animationTimer + dt
end

function PointsManager:getPoints()
    return self.points
end 

function PointsManager:decreasePoints(points)
    self.animationTimer = 0
    self.animationColor = "3a4a6b"
    self.points = self.points - points
    if self.points <= 0 then self.points = 0 end
end

function PointsManager:increasePoints(points)
    self.animationTimer = 0
    self.animationColor = "c7c093"
    self.points = self.points + points
end

function PointsManager:draw()
    if not Player.isAlive then return end
    local textWidth = self.font:getWidth(self.points)
    local x = love.graphics.getWidth() / scale - textWidth - 15

    x = 112
    local y = 12
    
    love.graphics.setFont(self.font)
    --love.graphics.setColor(0.274, 0.4, 0.45, 1)
    love.graphics.setColor(0.05, 0, 0.05, 1)
    love.graphics.print(self.points, x + 3, y + 3)
    
    love.graphics.setColor(1, 1, 1)
    if self.animationTimer <= 0.1 or (self.animationTimer <= 0.3 and self.animationTimer > 0.2) then
        love.graphics.setColor(hexToRGB(self.animationColor))
    end
    
    love.graphics.print(self.points, x, y)
    love.graphics.setColor(1, 1, 1)
end


return PointsManager