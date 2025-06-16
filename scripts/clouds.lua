local Clouds = {}


function Clouds:load(target)
    self.image = love.graphics.newImage("assets/sprites/cloud.png")
    self.image:setFilter("nearest", "nearest")
    self.width = self.image:getWidth()
    self.height = self.image:getHeight()
    self.movement = 0
    self.target = target
end

function Clouds:update(dt)
    local speed = (math.sin(love.timer.getTime() * 0.2) + 3 ) / 4
    self.movement = (self.movement + 10 *dt * speed) % self.width 
end

function Clouds:drawShadow()
    self:drawCloud(true)
end


function Clouds:drawCloud(shadow)
    love.graphics.setColor(1, 1, 1, 0.2)
    local cloudHeight = 80
    if shadow == true then
        love.graphics.setColor(0.70, 0.63, 0.52, 0.3)
        cloudHeight = 0
    end

    local screenWidth = love.graphics.getWidth()

    local screenHeight = love.graphics.getHeight()

    --local startX = math.floor(Player.x / self.width) * self.width + self.movement
    local startX = math.floor((self.target.x + self.movement) / self.width) * self.width
    local startX = math.floor(self.target.x / self.width) * self.width - self.movement
    local startY = math.floor(self.target.y / self.height) * self.height

    local tilesX = 3
    local tilesY = 3

    for i = -1, tilesX do
        for j = -1, tilesY do
            love.graphics.draw(self.image, startX + i * self.width, startY - cloudHeight + j * self.height)
            
        end
    end
    love.graphics.setColor(1, 1, 1)
end

function Clouds:draw()
    self:drawCloud(false)
end

return Clouds