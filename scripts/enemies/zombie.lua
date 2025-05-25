local Zombie = {}
Zombie.__index = Zombie
Zombie.states = { idle = 1, walk = 2, damage = 3 }

local Particle = require("scripts/particles/particle")
local Tilemap = require("scripts/tilemap")
local whiteShader = love.graphics.newShader("scripts/shaders/whiteShader.glsl")


require("scripts/utils")

function Zombie:new(x, y)
    local enemy = setmetatable({}, Zombie)

    enemy.x = x
    enemy.y = y
    enemy.speed = math.random(40, 50)
    enemy.totalLife = 40
    enemy.life = enemy.totalLife
    enemy.damageTimer = 0.1
    enemy.kbdx = 0
    enemy.kbdy = 0
    enemy.size = 7
    enemy.dropPoints = 10
    enemy.drawPriority = math.random()

    enemy.isAlive = true

    enemy.spriteSheet = self:getSprite()
    
    enemy.spriteSheet:setFilter("nearest", "nearest")

    enemy.spriteShadow = love.graphics.newImage("assets/sprites/enemy/enemyShadow.png")
    enemy.spriteShadow:setFilter("nearest", "nearest")
    
    enemy.frameWidth = 32
    enemy.frameHeight = 32
    enemy.frames = {}
    enemy.noise = love.audio.newSource("assets/sfx/enemies/zombie.mp3", "static")
    enemy.pathUpdateInterval = 120
    enemy.pathUpdateCounter = love.math.random(0, enemy.pathUpdateInterval)

    enemy.path = nil
    enemy.finder = "JPS"
    --if math.random(0, 2) >= 1 then enemy.finder = "JPS" end

    local sheetWidth = enemy.spriteSheet:getWidth()
    local sheetHeight = enemy.spriteSheet:getHeight()
    local cols = sheetWidth / enemy.frameWidth
    local rows = sheetHeight / enemy.frameHeight

    for i = 0, rows - 1 do
        for j = 0, cols - 1 do
            table.insert(enemy.frames, love.graphics.newQuad(j * enemy.frameWidth, i * enemy.frameHeight, enemy.frameWidth, enemy.frameHeight, sheetWidth, sheetHeight))
        end
    end

    enemy.currentFrame = 1
    enemy.animationTimer = 0
    enemy.animationSpeed = 0.15
    
    enemy.stateTimer = 0
    enemy.idleDuration = math.random(0.7, 1.3)
    enemy.walkDuration = math.random(4, 6)

    enemy.lastFlip = 0
    enemy.flipTimer = 0
    enemy.flipH = false

    enemy.soundTimer = 0

    enemy.state = (math.random(0, 1) == 0) and Zombie.states.idle or Zombie.states.walk
    return enemy
end

function Zombie:getSprite()
    
    if math.random(1, 100) < 2 then 
        return love.graphics.newImage("assets/sprites/enemy/enemy-paulo.png") end
    if math.random(1, 100) < 2 then 
        return love.graphics.newImage("assets/sprites/enemy/enemy-ponei.png") end
    if math.random(1, 100) < 2 then 
        return love.graphics.newImage("assets/sprites/enemy/enemy-jhone.png") end
    if math.random(1, 2) == 2 then 
        return love.graphics.newImage("assets/sprites/enemy/enemy2.png") end

    return love.graphics.newImage("assets/sprites/enemy/enemy.png")

end

local function sign(n)
    if n > 0 then return 1
    elseif n < 0 then return -1
    else return 0 end
end

function Zombie:update(dt)
    self.pathUpdateCounter = self.pathUpdateCounter + 1

    local velocityX = 0
    local velocityY = 0

    self.soundTimer = self.soundTimer + dt
    if self.soundTimer >= 10 and Player.isAlive then
        self.soundTimer = 0
        local soundPositionX, soundPositionY = soundPosition(Player, self)

        self.noise:setPosition(soundPositionX, soundPositionY, 0)
        self.noise:setVolume(1)
        self.noise:setPitch(1.2 + math.random() * 0.2)
        self.noise:play()
    end

    if (self.pathUpdateCounter >= self.pathUpdateInterval and Player.isAlive) or self.path == nil or #self.path < 2 then
    --if (self.pathUpdateCounter >= self.pathUpdateInterval and self.state == Zombie.states.idle and Player.isAlive) or self.path == nil or #self.path < 2 then
        self.pathUpdateCounter = 0
        --print("generate")
        local posMapX, posMapY = Tilemap:worldToMap(self.x, self.y)

        if love.math.random() < 0.4 then
            local offsetX = love.math.random(-1, 1)
            local offsetY = love.math.random(-1, 1)
            posMapX = posMapX + offsetX
            posMapY = posMapY + offsetY
        end      

        local playerMapX, playerMapY = Tilemap:worldToMap(Player.x, Player.y)

        if love.math.random() < 0.4 then
            local offsetX = love.math.random(-1, 1)
            local offsetY = love.math.random(-1, 1)
            playerMapX = playerMapX + offsetX
            playerMapY = playerMapY + offsetY
        end        


        self.path = Tilemap.finderAstar:getPath(posMapX, posMapY, playerMapX, playerMapY)
    end

    local nextTileX, nextTileY = self.x, self.y
    
    if self.path and #self.path > 1 then

        local nextNode = self.path[2] -- porque path 1 e o tile atual

        nextTileX, nextTileY = Tilemap:mapToWorld(nextNode.x, nextNode.y)

        nextTileY = nextTileY - 8

        local distance = math.sqrt((self.x - nextTileX)^2 + (self.y - nextTileY)^2)
        if distance < 4 then
            table.remove(self.path, 1)
        end
        if math.abs(nextTileX - self.x) < 1.4 then self.x = nextTileX end
        if math.abs(nextTileY - self.y) < 1.4 then self.y = nextTileY end
        
        local moveX = sign(nextTileX - self.x)
        local moveY = sign(nextTileY - self.y)

        local repulseX, repulseY = self:getRepulsionVector()

        moveX = moveX + repulseX * 2
        moveY = moveY + repulseY * 2

        velocityX = moveX
        velocityY = moveY
        
    end 

    local length = math.sqrt(velocityX * velocityX + velocityY * velocityY)
    if length > 0 then
        velocityX = velocityX / length
        velocityY = velocityY / length
    end

    local animationDuration = self.idleDuration
    if self.state == Zombie.states.walk then 
        animationDuration = self.walkDuration 
    elseif self.state == Zombie.states.damage then
        animationDuration = self.damageTimer
    end

    self.stateTimer = self.stateTimer + dt
    if self.stateTimer >= animationDuration then
        if self.state == Zombie.states.idle then
            self.walkDuration = math.random(4, 6)
            self.state = Zombie.states.walk
            if not Player.isAlive then
                self.state = Zombie.states.idle
                self.stateTimer = 0
                local negative = 0
            end
        elseif Player.isAlive then
            self.idleDuration = math.random(0.7, 1.3)
            self.state = Zombie.states.idle
        end
        self.stateTimer = 0
    end 

    self:death()

    if self.state == Zombie.states.idle or self.state == Zombie.states.damage then
        self:animate(1, 2, dt)
        if self.state == Zombie.states.damage then
            local movekbX = self.kbdx * dt * 0.1
            local movekbY = self.kbdy * dt * 0.1
            local collidedX, collidedY = self:isColliding(movekbX,movekbY)

            if not collidedX then self.x = self.x + movekbX end
            if not collidedY then self.y = self.y + movekbY end
        end

    else
        self:animate(3, 6, dt)

        self.flipTimer = self.flipTimer + dt

        if self.flipTimer > 0.1 then
            if velocityX > 0 and not self.flipH then
                self.flipH = true
                self.flipTimer = 0
            end
            if velocityX <= 0 and self.flipH then
                self.flipH = false
                self.flipTimer = 0
            end
        end
        
        local negative = 1
        if not Player.isAlive then
            self.state = Zombie.states.idle
            self.stateTimer = 0
            local negative = 0
        end

        local moveX, moveY =  velocityX *negative * self.speed * dt, velocityY *negative * self.speed * dt
        local collidedX, collidedY = self:isColliding(moveX,moveY)
        if not collidedX then self.x = self.x + moveX end
        if not collidedY then self.y = self.y + moveY end
    end
end


function Zombie:getRepulsionVector()
    local repulseX, repulseY = 0, 0
    local selfBox = self:collisionBox(self.x, self.y)

    for _, enemy in ipairs(Game.enemies) do
        if enemy.isAlive and enemy ~= self and enemy.state == Zombie.states.walk and self.speed < enemy.speed then
            local enemyBox = enemy:collisionBox()
            local dx = self.x - enemy.x
            local dy = self.y - enemy.y
            local distSq = dx * dx + dy * dy
            local minDist = 16

            if distSq < minDist * minDist and distSq > 0 then
                local dist = math.sqrt(distSq)
                local strength = (minDist - dist) / minDist

                repulseX = repulseX + (dx / dist) * strength
                repulseY = repulseY + (dy / dist) * strength
            end
        end
    end

    return repulseX, repulseY
end

function Zombie:collisionBox(x, y)
    if not x then x = self.x end
    if not y then y = self.y end

    return {x = x - self.size/2, y = y - self.size/2, width = self.size, height = self.size}
end

function Zombie:isColliding(moveX, moveY)
    local futureX = self.x + moveX
    local futureY = self.y + moveY

    local selfBoxX = self:collisionBox(futureX, self.y)
    local selfBoxY = self:collisionBox(self.x, futureY)

    local collidedX = false
    local collidedY = false

    for _, tile in ipairs(Tilemap.tiles) do
        if tile.collider then
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

function Zombie:takeDamage(damage, dx, dy)
    self.animationTimer = 0.5
    self.state = Zombie.states.damage
    self.stateTimer = 0
    self.kbdx = dx
    self.kbdy = dy 
    self.life = self.life - damage
    self.noise:stop()

    if self.soundTimer <= 1 then
        self.soundTimer = 1.1
    end

    local bulletSound = love.audio.newSource("assets/sfx/enemyDamage.wav", "static")
    bulletSound:setVolume(2)
    bulletSound:setPitch(0.8 + math.random() * 0.1)
    bulletSound:play()
end

function Zombie:death()
    if self.life > 0 or not self.isAlive then
        return
    end

    local bulletSound = love.audio.newSource("assets/sfx/bullet.mp3", "static")
    bulletSound:setVolume(0.3)
    bulletSound:setPitch(0.8)
    bulletSound:play()
    Game:increasePlayerPoints(self.dropPoints)
    self.noise:stop()

    self.isAlive = false    
    local particle = Particle:new(self.x, self.y, 12, 7,0.3)
    table.insert(Game.particles, particle)
    local particle = Particle:new(self.x +  math.random(-2, 2), self.y + math.random(-2, 2), math.random(5, 15), math.random(5, 7), math.random(0.2, 0.3))
    table.insert(Game.particles, particle)
    local particle = Particle:new(self.x +  math.random(-2,2), self.y + math.random(-2, 2), math.random(5, 15), math.random(5, 7), math.random(0.2, 0.3))
    table.insert(Game.particles, particle)
end

function Zombie:animate(startFrame, endFrame, dt)
    self.animationTimer = self.animationTimer + dt
    if self.animationTimer >= self.animationSpeed then
        self.animationTimer = 0
        self.currentFrame = self.currentFrame + 1
        if self.currentFrame > endFrame then
            self.currentFrame = startFrame
        end

        if self.state == Zombie.states.walk and self.currentFrame % 2 == 0 then

            local playerDistance = self:playerDistance()
            if playerDistance <= 150 then
                local stepsound = love.audio.newSource("assets/sfx/footsteps/foot-steps-0.mp3", "static")
                local soundPositionX, soundPositionY = soundPosition(Player, self)

                self.noise:setPosition(soundPositionX, soundPositionY, 0)
                stepsound:setVolume(0.4)

                stepsound:setPitch(0.4 + math.random() * 0.4)
                stepsound:play()
            end

        end
    end
end

function Zombie:playerDistance()
    local dx = self.x - Player.x
    local dy = self.y - Player.y
    return math.sqrt(dx * dx + dy * dy)
end

function Zombie:drawShadow()

    if not self.isAlive then
        return
    end

    local width = 14
    local height = 14

    love.graphics.draw(self.spriteShadow, self.x - 6, self.y- 6, 0 , 1, 1)
end

function Zombie:draw()

    if not self.isAlive then
        return
    end
    local xOffset = 0
    local scaleX = 1
    if self.flipH then
        scaleX = -1
        xOffset = 1
    end

    if self.state == Zombie.states.damage then
        love.graphics.setShader(whiteShader)
    end

    love.graphics.draw(self.spriteSheet, self.frames[self.currentFrame], xOffset +self.x, self.y, 0, scaleX, 1.5, self.frameWidth / 2, self.frameHeight)
    love.graphics.setShader()

    if self.state ~= Zombie.states.damage then
        love.graphics.setColor(hexToRGB("302c5e"))
        if self.soundTimer >= 0 and self.soundTimer <= 1 then
            love.graphics.circle("fill", self.x , self.y - 18, 1.5)
        else
            love.graphics.rectangle("fill", self.x -0.7 ,self.y - 19, 1.4, 0.6 )
        end
        love.graphics.setColor(1, 1, 1, 1)
    end

    if DEBUG then 

        love.graphics.rectangle("line", self.x - self.size/2, self.y - self.size/2, self.size, self.size)
    
        if self.path and #self.path > 1 then
            love.graphics.setColor(0, 1, 0, 0.6)
    
            local points = {}
    
            for i = 1, #self.path do
                local node = self.path[i]
                local worldX, worldY = Tilemap:mapToWorld(node.x, node.y)

                worldY = worldY - 8
                
                table.insert(points, worldX)
                table.insert(points, worldY)
            end
    
            love.graphics.line(points)
            love.graphics.setColor(1, 1, 1, 1)
        end
    end
end

return Zombie