Grass = {}
Grass.__index = Grass

local sprite = love.graphics.newImage("assets/sprites/objects/grass1.png")
local sprite2 = love.graphics.newImage("assets/sprites/objects/grass2.png")
sprite:setFilter("nearest", "nearest")
sprite2:setFilter("nearest", "nearest")

local stretch = 1.5


local grassShader = love.graphics.newShader([[
    extern number direction;
    extern vec2 spriteSize;

    vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
        vec2 pixelCoord = texture_coords * spriteSize;
        if (pixelCoord.y < spriteSize.y - 5.0) {
            texture_coords.x += direction / spriteSize.x;
        }
        if (pixelCoord.y < spriteSize.y - 8.0) {
            texture_coords.x += direction / spriteSize.x;
        }    
        return Texel(tex, texture_coords) * color;
    }
]])


grassShader:send("direction", 1.0) 
grassShader:send("spriteSize", {16.0, 16.0})

function Grass:new(x, y, tile)
    local grass = setmetatable({}, Grass)
    grass.x = x 
    grass.y = y 
    grass.index = 1
    grass.shaderDirection = 1
    grass.collisionDirection = 0
    if math.random() > 0.7 or tile == 4 then grass.index = 2 end
    return grass
end


function Grass:getTarget()
    if distance(self, Player) < 10 then
        if Player.x < self.x then
            return -1
        else
            return 1
        end
    end

    for _, bullet in ipairs(Player.gun.bullets) do
        if distance(self, bullet) < 10 then
            if bullet.x < self.x then
                return -1
            else
                return 1
            end
        end 
    end

    for _, enemy in ipairs(Game.enemies) do
        if distance(self, enemy) < 10 then
            if enemy.x < self.x then
                return -1
            else
                return 1
            end
        end 
    end
    return 0
end

function Grass:update(dt)
    local target = self:getTarget()
    local speed = 2
    if target ~= 0 then speed = 15 end
    addToDrawQueue(self.y + 4, self)

    self.collisionDirection = self.collisionDirection + (target - self.collisionDirection) * dt * speed

    self.shaderDirection = (math.sin(love.timer.getTime() + (self.y/10)   )) / 2 + 1  + self.collisionDirection*0.7


    
end

function Grass:draw()
    love.graphics.setShader(grassShader)
    grassShader:send("direction", self.shaderDirection)

    if self.index == 1 then
        love.graphics.draw(sprite, self.x - 8, self.y - 15 * stretch, 0, 1, stretch)
    else
        love.graphics.draw(sprite2, self.x - 8, self.y - 15 * stretch, 0, 1, stretch)
    end
    love.graphics.setShader()
end