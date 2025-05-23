local Enemy = {}
Enemy.__index = Enemy
Enemy.states = { idle = 1, walk = 2, damage = 3 }

local Particle = require("scripts/particles/particle")
local Tilemap = require("scripts/tilemap")

require("scripts/utils")

function Enemy:new(x, y)
    local enemy = setmetatable({}, Enemy)

    enemy.x = x
    enemy.y = y
    enemy.size = 7
    enemy.totalLife = 30
    enemy.life = enemy.totalLife
    enemy.dropPoints = 10
    enemy.isAlive = true

    return enemy
end

function Enemy:update(dt)
    self:death()
end

function Enemy:isColliding(moveX, moveY)
    local futureX = self.x + moveX
    local futureY = self.y + moveY

    local selfBoxX = { x = futureX - self.size/2, y = self.y - self.size/2, width = self.size, height = self.size }
    local selfBoxY = { x = self.x - self.size/2, y = futureY - self.size/2, width = self.size, height = self.size }

    local collidedX = false
    local collidedY = false

    for _, tile in ipairs(Tilemap.tiles) do
        if tile.quadIndex ~= 5 then
            local tileBox = { x = tile.xWorld - tile.size/2, y = tile.yWorld - tile.size, width = tile.size, height = tile.size }

            if checkCollision(selfBoxX, tileBox) then
                collidedX = true
            end
            if checkCollision(selfBoxY, tileBox) then
                collidedY = true
            end
        end
    end

    return collidedX, collidedY
end

function Enemy:takeDamage(damage, dx, dy)
    self.life = self.life - damage
end

function Enemy:death()
    if self.life > 0 or not self.isAlive then
        return
    end

    Game:increasePlayerPoints(self.dropPoints)
    self.isAlive = false
end


function Enemy:playerDistance()
    local dx = self.x - Player.x
    local dy = self.y - Player.y
    return math.sqrt(dx * dx + dy * dy)
end

function Enemy:collisionBox(x, y)
    if not x then x = self.x end
    if not y then y = self.y end

    return {x = x - self.size/2, y = y - self.size/2, width = self.size, height = self.size}
end

function Enemy:draw()

    if not self.isAlive then
        return
    end

    local scaleX = 1
    if self.flipH then
        scaleX = -1
    end

    if self.state == Enemy.states.damage and Player.isAlive then
        love.graphics.draw(self.spriteOutline, self.frames[self.currentFrame], self.x, self.y, 0, scaleX, 1, self.frameWidth / 2, self.frameHeight)
    else 
        love.graphics.draw(self.spriteSheet, self.frames[self.currentFrame], self.x, self.y, 0, scaleX, 1, self.frameWidth / 2, self.frameHeight)
    end

    self.drawDebug(x, y)
end

function Enemy:drawDebug()
    if not DEBUG then return end

    local box = collisionBox(x, y)
    love.graphics.rectangle("line", box.x, box.y, box.width, box.height)
end

return Enemy