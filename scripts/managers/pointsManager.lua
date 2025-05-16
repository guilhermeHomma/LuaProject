PointsManager = {}


function PointsManager:load()
    self.font = love.graphics.newFont("assets/fonts/ThaleahFat.ttf", 32)
    self.font:setFilter("nearest", "nearest")
    self.points = 1000
end

function PointsManager:update()

end

function PointsManager:getPoints()
    return self.points
end 

function PointsManager:decreasePoints(points)
    self.points = self.points - points
    if self.points <= 0 then self.points = 0 end
end

function PointsManager:increasePoints(points)
    self.points = self.points + points
end

function PointsManager:draw()
    if not Player.isAlive then return end
    local textWidth = self.font:getWidth(self.points)
    local x = love.graphics.getWidth() / scale - textWidth - 15

    love.graphics.setFont(self.font)
    --love.graphics.setColor(0.274, 0.4, 0.45, 1)
    love.graphics.setColor(0.05, 0, 0.05, 1)
    love.graphics.print(self.points, x + 3, 40 + 3)    
    love.graphics.setColor(1, 1, 1)
    
    love.graphics.print(self.points, x, 40)
    love.graphics.setColor(1, 1, 1)
end


return PointsManager