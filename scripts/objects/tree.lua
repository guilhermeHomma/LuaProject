TreeTile = setmetatable({}, {__index = Tile})
TreeTile.__index = TreeTile
TileSet = require("scripts.objects.tileset")

local threeImage1 = love.graphics.newImage("assets/sprites/objects/three1.png")
local threeImage2 = love.graphics.newImage("assets/sprites/objects/three2.png")
local threeImage3 = love.graphics.newImage("assets/sprites/objects/three3.png")

threeImage1:setFilter("nearest", "nearest")
threeImage2:setFilter("nearest", "nearest")
threeImage3:setFilter("nearest", "nearest")

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

    setmetatable(tile, TreeTile)
    return tile
end

function TreeTile:update(dt)
    self.shaderDirection = math.sin(love.timer.getTime() + (self.yWorld/10)) / 2 + 1
end

local function getTargetAlpha(box)
    if checkCollision(box, Player:getCollisionBox()) then 
        return 0.4
    end

    for _, enemy in ipairs(Game.enemies) do
        if checkCollision(enemy:collisionBox(), box ) then
            return 0.4
        end 
    end

    return 1
end


function TreeTile:draw()

    local tileSet = TileSet:getTileSet()
    local tileSize = TileSet.tileSize
    local tilesetImage = TileSet.tilesetImage
    love.graphics.setShader(shader)
    shader:send("direction", self.shaderDirection)
    love.graphics.draw(tilesetImage, tileSet[5], self.xWorld, self.yWorld, 0, 1, 1, tileSize/2, tileSize)
    local targetAlpha = 1
    local image = threeImage1

    if self.quadIndex == 17 then image = threeImage2 end 
    if self.quadIndex == 19 then image = threeImage3 end

    local box = {x = self.xWorld - 20, y = self.yWorld - 90, width = 50, height = 85}

    local targetAlpha = getTargetAlpha(box)


    self.alpha = self.alpha + (targetAlpha - self.alpha) * 0.1
    
    love.graphics.setColor(1, 1, 1, self.alpha)
    love.graphics.draw(image, self.xWorld, self.yWorld, 0, 1, 1.6, 32, 93)
    love.graphics.setColor(1, 1, 1) 
    love.graphics.setShader()
    self:drawDebug()    
end