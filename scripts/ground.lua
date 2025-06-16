local Ground = {}

function Ground:load(target)
    self.image = love.graphics.newImage("assets/sprites/ground.png")
    self.image:setFilter("nearest", "nearest")
    self.width = self.image:getWidth()
    self.height = self.image:getHeight()
end

function Ground:draw(player)
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()

    local startX = math.floor(player.x / self.width) * self.width
    local startY = math.floor(player.y / self.height) * self.height

    local tilesX = math.ceil(screenWidth / self.width) + 2
    local tilesY = math.ceil(screenHeight / self.height) + 2

    for i = -1, tilesX do
        for j = -1, tilesY do
            love.graphics.draw(self.image, startX + i * self.width, startY + j * self.height)
        end
    end
end

return Ground