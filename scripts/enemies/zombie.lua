local Enemy = {}
Enemy.__index = Enemy
Enemy.states = { idle = 1, walk = 2, damage = 3 }

local Particle = require("scripts/particle")
local Tilemap = require("scripts/tilemap")


require("scripts/utils")

function Enemy:new(x, y)
    local enemy = setmetatable({}, Enemy)

    enemy.x = x
    enemy.y = y
    enemy.speed = math.random(25, 45)
    enemy.totalLife = 40
    enemy.life = enemy.totalLife
    enemy.damageTimer = 0.1
    enemy.kbdx = 0
    enemy.kbdy = 0

    enemy.drawPriority = math.random()

    enemy.isAlive = true

    enemy.spriteSheet = love.graphics.newImage("assets/sprites/enemy/enemy.png")
        
    enemy.spriteSheet:setFilter("nearest", "nearest")

    enemy.spriteOutline = love.graphics.newImage("assets/sprites/enemy/enemyOutline.png")
    enemy.spriteOutline:setFilter("nearest", "nearest")

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

    enemy.state = (math.random(0, 1) == 0) and Enemy.states.idle or Enemy.states.walk
    return enemy
end

local function sign(n)
    if n > 0 then return 1
    elseif n < 0 then return -1
    else return 0 end
end

function Enemy:update(dt)
    self.pathUpdateCounter = self.pathUpdateCounter + 1

    local velocityX = 0
    local velocityY = 0

    self.soundTimer = self.soundTimer + dt
    if self.soundTimer >= 10 then
        self.soundTimer = 0
        local playerDistance = self:playerDistance()
        self.noise:setVolume(getDistanceVolume(playerDistance, 0.34))
        self.noise:setPitch(1.2 + math.random() * 0.2)
        self.noise:play()
    end

    if (self.pathUpdateCounter >= self.pathUpdateInterval and Player.isAlive) or self.path == nil or #self.path < 2 then
    --if (self.pathUpdateCounter >= self.pathUpdateInterval and self.state == Enemy.states.idle and Player.isAlive) or self.path == nil or #self.path < 2 then
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

        local repulseX, repulseY = self:getRepulsionVector(moveX,moveY,5)

        moveX = moveX + repulseX * 1.7
        moveY = moveY + repulseY * 1.7

        local collidedX, collidedY = self:isColliding(moveX,moveY,5)

        if not collidedX then velocityX = moveX end
        if not collidedY then velocityY = moveY end
        
    end 

    local length = math.sqrt(velocityX * velocityX + velocityY * velocityY)
    if length > 0 then
        velocityX = velocityX / length
        velocityY = velocityY / length
    end

    local animationDuration = self.idleDuration
    if self.state == Enemy.states.walk then 
        animationDuration = self.walkDuration 
    elseif self.state == Enemy.states.damage then
        animationDuration = self.damageTimer
    end

    self.stateTimer = self.stateTimer + dt
    if self.stateTimer >= animationDuration then
        if self.state == Enemy.states.idle then
            self.walkDuration = math.random(4, 6)
            self.state = Enemy.states.walk
            if not Player.isAlive then
                self.state = Enemy.states.idle
                self.stateTimer = 0
                local negative = 0
            end
        elseif Player.isAlive then
            self.idleDuration = math.random(0.7, 1.3)
            self.state = Enemy.states.idle
        end
        self.stateTimer = 0
    end 

    self:death()

    if self.state == Enemy.states.idle or self.state == Enemy.states.damage then
        self:animate(1, 2, dt)
        if self.state == Enemy.states.damage then
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
            self.state = Enemy.states.idle
            self.stateTimer = 0
            local negative = 0
        end

        self.x = self.x + velocityX*negative * self.speed * dt
        self.y = self.y + velocityY*negative * self.speed * dt
    end
end


function Enemy:getRepulsionVector(size)
    size = size or 4

    local repulseX, repulseY = 0, 0
    local selfBox = self:collisionBox(self.x - size / 2, self.y - size / 2, size)

    for _, enemy in ipairs(Game.enemies) do
        if enemy.isAlive and enemy ~= self and self.state == Enemy.states.walk then
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

function Enemy:collisionBox(x, y, size)
    if not x then x = self.x end
    if not y then y = self.y end
    if not size then size = 4 end

    return {x = x - size/2, y = y - size/2, width = size, height = size}

end

function Enemy:isColliding(moveX, moveY, size)
    if size == nil then size = 7 end


    local futureX = self.x + moveX
    local futureY = self.y + moveY

    local selfBoxX = self:collisionBox(futureX - size/2, self.y - size/2, size)
    local selfBoxY = self:collisionBox(self.x - size/2, futureY - size/2, size)

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

function Enemy:takeDamage(damage, dx, dy)
    self.animationTimer = 0.5
    self.state = Enemy.states.damage
    self.stateTimer = 0
    self.kbdx = dx
    self.kbdy = dy 
    self.life = self.life - damage

    local bulletSound = love.audio.newSource("assets/sfx/enemyDamage.wav", "static")
    bulletSound:setVolume(2)
    bulletSound:setPitch(0.8 + math.random() * 0.1)
    bulletSound:play()
end

function Enemy:death()
    if self.life > 0 or not self.isAlive then
        return
    end

    local bulletSound = love.audio.newSource("assets/sfx/bullet.mp3", "static")
    bulletSound:setVolume(0.3)
    bulletSound:setPitch(0.8)
    bulletSound:play()

    self.noise:stop()

    self.isAlive = false    
    local particle = Particle:new(self.x, self.y, 12, 7,0.3)
    table.insert(Game.particles, particle)
    local particle = Particle:new(self.x +  math.random(-2, 2), self.y + math.random(-2, 2), math.random(5, 15), math.random(5, 7), math.random(0.2, 0.3))
    table.insert(Game.particles, particle)
    local particle = Particle:new(self.x +  math.random(-2,2), self.y + math.random(-2, 2), math.random(5, 15), math.random(5, 7), math.random(0.2, 0.3))
    table.insert(Game.particles, particle)
end

function Enemy:animate(startFrame, endFrame, dt)
    self.animationTimer = self.animationTimer + dt
    if self.animationTimer >= self.animationSpeed then
        self.animationTimer = 0
        self.currentFrame = self.currentFrame + 1
        if self.currentFrame > endFrame then
            self.currentFrame = startFrame
        end

        if self.state == Enemy.states.walk and self.currentFrame % 2 == 0 then

            local playerDistance = self:playerDistance()
            if playerDistance <= 100 then
                local stepsound = love.audio.newSource("assets/sfx/footsteps/foot-steps-0.mp3", "static")

                stepsound:setVolume(getDistanceVolume(playerDistance, 0.64))
                stepsound:setPitch(0.4 + math.random() * 0.4)
                stepsound:play()
            end

        end
    end
end

function Enemy:playerDistance()
    local dx = self.x - Player.x
    local dy = self.y - Player.y
    return math.sqrt(dx * dx + dy * dy)
end

function Enemy:drawShadow()

    if not self.isAlive then
        return
    end

    local width = 0.7
    local height = 0.6

    love.graphics.draw(self.spriteShadow, self.x - (width/2) * 16, self.y- (height/2) * 16 , 0 , width, height)
end

function Enemy:draw()

    if not self.isAlive then
        return
    end
    local xOffset = 0
    local scaleX = 0.7
    if self.flipH then
        scaleX = -0.7
        xOffset = 1
    end

    if self.state == Enemy.states.damage then
        love.graphics.draw(self.spriteOutline, self.frames[self.currentFrame], xOffset + self.x, self.y, 0, scaleX, 0.7, self.frameWidth / 2, self.frameHeight)
    else 
        love.graphics.draw(self.spriteSheet, self.frames[self.currentFrame], xOffset +self.x, self.y, 0, scaleX, 0.7, self.frameWidth / 2, self.frameHeight)
    end

    if DEBUG then 
        love.graphics.rectangle("line", self.x - 3.5, self.y - 3.5, 7, 7)
    
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

return Enemy