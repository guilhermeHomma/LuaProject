local GrassManager = {}
local grassList = {}

Grass = {}
Grass.__index = Grass

function Grass:new(x, y)
    local grass = setmetatable({}, Grass)
    grass.x = x
    grass.y = y
    grass.height = 5
    return grass
end

function Grass:drawShadow()
    love.graphics.setColor(0.70, 0.63, 0.52)
    love.graphics.circle("fill", self.x, self.y, 2)

    love.graphics.setColor(1, 1, 1)
end

function Grass:playerDistance()
    local dx = self.x - Player.x
    local dy = self.y - Player.y
    return math.sqrt(dx * dx + dy * dy)
end

function Grass:draw()

    local movementX = 0
    local movementY = 0
    if self:playerDistance() < 100 then
        movementX = math.cos(Player.angle) * 0.01 * Player.speed * self:playerDistance()
        movementY = math.cos(Player.angle) * 0.01 * Player.speed * self:playerDistance()
    end

    love.graphics.setColor(0.36, 0.47, 0.45)
    love.graphics.line(self.x, self.y, self.x + movementX, self.y-self.height + movementY)
    love.graphics.setColor(1, 1, 1)
end

function GrassManager:load()
    
end

function GrassManager:update(dt)
    grassList = {}

    for x = -5, 10 do
        for y = -5, 10 do

            local distanceBetween = 6
            local gx = x*distanceBetween
            local gy = y*distanceBetween
            local gx = x * distanceBetween -- Pequena variação pseudoaleatória
            local gy = y * distanceBetween
            if y % 2 == 1 then
                gx = gx + distanceBetween/2
            end

            grass = Grass:new(gx, gy)
            
            addToDrawQueue(gy, grass)
            
        end
    end
end

return GrassManager