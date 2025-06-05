Grass = {}
Grass.__index = Grass

local sprite = love.graphics.newImage("assets/sprites/objects/grass/grass1.png")
local sprite2 = love.graphics.newImage("assets/sprites/objects/grass/grass2.png")
local sprite3 = love.graphics.newImage("assets/sprites/objects/grass/grass3.png")
local sprite4 = love.graphics.newImage("assets/sprites/objects/grass/grass3.png")
sprite:setFilter("nearest", "nearest")
sprite2:setFilter("nearest", "nearest")
sprite3:setFilter("nearest", "nearest")
sprite4:setFilter("nearest", "nearest")

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


local function getGrassIndex()
    if math.random() < 0.6 then return 1 end
    if math.random() < 0.5 then return 3 end
    if math.random() < 0.15 then return 2 end
    return 4
end

function Grass:new(x, y, tile)
    local grass = setmetatable({}, Grass)

    grass.x = x 
    grass.y = y 
    grass.index = getGrassIndex()
    grass.shaderDirection = 1
    grass.collisionDirection = 0
    grass.tile = tile

    return grass
end


function Grass:getTarget()
    if self.tile == 1 then return 0 end

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
    if distance(self, camera:objectPosition()) > 230 then
        return
    end


    local target = self:getTarget()
    local speed = 2
    if target ~= 0 then speed = 15 end

    if not self.tile == 1 then 
        addToDrawQueue(self.y + 2, self)
    else
        addToDrawQueue(self.y + 8, self)
        
    end
    self.collisionDirection = self.collisionDirection + (target - self.collisionDirection) * dt * speed

    self.shaderDirection = (math.sin(love.timer.getTime() + (self.y/10)   )) / 2 + 1  + self.collisionDirection*0.7
end

function Grass:draw()
    love.graphics.setShader(grassShader)
    grassShader:send("direction", self.shaderDirection)


    local currentSprite = sprite
    if self.index == 1 then
        currentSprite = sprite
    elseif self.index == 2 then
        currentSprite = sprite2
    elseif self.index == 3 then
        currentSprite = sprite3
    else 
        currentSprite = sprite4
    end

    love.graphics.draw(currentSprite, self.x - 8, self.y - 15 * stretch, 0, 1, stretch)

    love.graphics.setShader()
end