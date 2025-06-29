TreeTile = setmetatable({}, {__index = Tile})
TreeTile.__index = TreeTile
TileSet = require("scripts.objects.tileset")

local threeImage1 = love.graphics.newImage("assets/sprites/objects/three1.png")
local threeImage2 = love.graphics.newImage("assets/sprites/objects/three2.png")
local threeImage3 = love.graphics.newImage("assets/sprites/objects/three3.png")
local threeImage4 = love.graphics.newImage("assets/sprites/objects/three4.png")
local threeImage5 = love.graphics.newImage("assets/sprites/objects/three5.png")

threeImage1:setFilter("nearest", "nearest")
threeImage2:setFilter("nearest", "nearest")
threeImage3:setFilter("nearest", "nearest")
threeImage4:setFilter("nearest", "nearest")
threeImage5:setFilter("nearest", "nearest")

local shader = love.graphics.newShader([[
    extern number direction;
    extern vec2 spriteSize;

    vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
        vec2 pixelCoord = texture_coords * spriteSize;
        if (pixelCoord.y < spriteSize.y - 30.0) {
            texture_coords.x += direction / spriteSize.x;
        }
        if (pixelCoord.y < spriteSize.y - 56.0) {
            texture_coords.x += direction / spriteSize.x;
        }    
        return Texel(tex, texture_coords) * color;
    }
]])

shader:send("direction", 1.0) 
shader:send("spriteSize", {64.0, 96.0})

function TreeTile:new(x, y, quadIndex, collider)
    local tile = Tile.new(self, x, y, quadIndex, collider)

    tile.shaderDirection = 0
    tile.yAdd = math.random(3, 3)
    tile.treeIndex = math.random(3)

    if math.random(30) == 1 and not collider then 
        tile.treeIndex = 4
    end

    if math.random(45) == 1 and not collider then
        tile.treeIndex = 5
    end

    tile.stretch = 1.4
    if tile.treeIndex == 5 then 
        tile.stretch = 1.2
    elseif math.random() > 0.6 then
        tile.stretch = 1.3
    end

    setmetatable(tile, TreeTile)
    return tile
end

function TreeTile:update(dt)
    addToDrawQueue(self.yWorld+1 + self.yAdd, self)
    self.shaderDirection = math.sin(love.timer.getTime() + (self.yWorld/10)) * 0.45 + 1
    --print(self.shaderDirection)
end

function TreeTile:getTargetAlpha(box)
    if self.treeIndex == 4 or self.treeIndex == 5 then
        return 1
    end

    if Player.isAlive then
        if checkCollision(box, Player:getCollisionBox()) then 
            return 0.4
        end
    end
    
    if Game.enemies then
        for _, enemy in ipairs(Game.enemies) do
            if checkCollision(enemy:collisionBox(), box ) then
                return 0.4
            end 
        end
    end
    return 1
end

function TreeTile:drawShadow()
   
end

function TreeTile:draw()

    local tileSet = TileSet:getTileSet()
    local tileSize = TileSet.tileSize
    local tilesetImage = TileSet.tilesetImage
    if self.treeIndex ~= 4 and self.treeIndex ~= 5 then
        love.graphics.setShader(shader)
    end
    shader:send("direction", self.shaderDirection)
    if not self.collider then
        love.graphics.draw(tilesetImage, tileSet[5], self.xWorld, self.yWorld , 0, 1, 1, tileSize/2, tileSize)
    end
    local targetAlpha = 1
    local image = threeImage1

    if self.treeIndex == 2 then image = threeImage2 end 
    if self.treeIndex == 3 then image = threeImage3 end
    if self.treeIndex == 4 then image = threeImage4 end
    if self.treeIndex == 5 then image = threeImage5 end

    local box = {x = self.xWorld - 20, y = self.yWorld - 90, width = 50, height = 85}

    local targetAlpha = self:getTargetAlpha(box)

    self.alpha = self.alpha + (targetAlpha - self.alpha) * 0.1
    
    local r, g, b, a = love.graphics.getColor()
    love.graphics.setColor(r, g, b, self.alpha)

    if Player.isAlive then
        if Player.y + 100 < self.yWorld then         
            love.graphics.setColor(r, g, b, 1)
        end
    end
    
    love.graphics.draw(image, self.xWorld, self.yWorld, 0, 1, self.stretch, 32, 93)
    love.graphics.setColor(r, g, b, a) 
    love.graphics.setShader()
    self:drawDebug()    
end

return TreeTile