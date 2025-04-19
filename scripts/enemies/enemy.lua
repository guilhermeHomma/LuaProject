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
    enemy.speed = 30

    enemy.totalLife = 40
    enemy.life = enemy.totalLife
    enemy.damageTimer = 0.1
    enemy.kbdx = 0
    enemy.kbdy = 0

    enemy.isAlive = true
    if math.random(1,5) % 4 == 0 then

        enemy.spriteSheet = love.graphics.newImage("assets/sprites/enemy/enemy2.png")
    else
        enemy.spriteSheet = love.graphics.newImage("assets/sprites/enemy/enemy.png")
        
    end
    enemy.spriteSheet:setFilter("nearest", "nearest")

    enemy.spriteOutline = love.graphics.newImage("assets/sprites/enemy/enemyOutline.png")
    enemy.spriteOutline:setFilter("nearest", "nearest")

    enemy.spriteShadow = love.graphics.newImage("assets/sprites/enemy/enemyShadow.png")
    enemy.spriteShadow:setFilter("nearest", "nearest")
    
    enemy.frameWidth = 32
    enemy.frameHeight = 32
    enemy.frames = {}

    local angle = math.random() * (2 * math.pi)
    enemy.randomDirX = math.cos(angle)
    enemy.randomDirY = math.sin(angle) 

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

    enemy.state = (math.random(0, 1) == 0) and Enemy.states.idle or Enemy.states.walk
    return enemy
end

function Enemy:update(dt)

    local velocityX = 0
    local velocityY = 0
    
    if true then
        local collidedX, collidedY = self:isColliding(self.randomDirX, self.randomDirY)

        if collidedX then 
            self.randomDirX = -self.randomDirX

        end
        if collidedY then 
            self.randomDirY = -self.randomDirY
        end

        if collidedX or collidedY then
            self.randomDirX = self.randomDirX + (math.random() - 0.5) * 0.1
            self.randomDirY = self.randomDirY + (math.random() - 0.5) * 0.1
        end

        velocityX = self.randomDirX
        velocityY = self.randomDirY

    elseif self:playerDistance() > 10 then
        if Player.x > self.x+1 then
            velocityX = 1
        end

        if Player.x < self.x-1 then
            velocityX = -1
        end

        if Player.y > self.y+1 then
            velocityY = 1
        end
        if Player.y < self.y-1 then
            velocityY = -1
        end
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
            negative = -1
            if self.x > Player.x then
                self.flipH = true
            else 
                self.flipH = false
            end
        end

        self.x = self.x + velocityX*negative * self.speed * dt
        self.y = self.y + velocityY*negative * self.speed * dt
    end
end

function Enemy:isColliding(moveX, moveY, size)
    if not size then size = 7 end

    local futureX = self.x + moveX
    local futureY = self.y + moveY

    local selfBoxX = { x = futureX - size/2, y = self.y - size/2, width = size, height = size }
    local selfBoxY = { x = self.x - size/2, y = futureY - size/2, width = size, height = size }

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
    self.animationTimer = 0.5
    self.state = Enemy.states.damage
    self.stateTimer = 0
    self.kbdx = dx
    self.kbdy = dy 
    self.life = self.life - damage

    local bulletSound = love.audio.newSource("assets/sfx/enemyDamage.wav", "static")
    bulletSound:setVolume(4)
    bulletSound:setPitch(0.9 + math.random() * 0.2)
    bulletSound:play()
end

function Enemy:death()
    if self.life > 0 or not self.isAlive then
        return
    end

    local bulletSound = love.audio.newSource("assets/sfx/bullet.wav", "static")
    bulletSound:setVolume(1.5)
    bulletSound:setPitch(1.2)
    bulletSound:play()

    self.isAlive = false
    local particle = Particle:new(self.x, self.y, 13, 7,0.3)
    table.insert(particles, particle)
    local particle = Particle:new(self.x +  math.random(-2, 2), self.y + math.random(-2, 2), math.random(5, 15), math.random(5, 7), math.random(0.2, 0.3))
    table.insert(particles, particle)
    local particle = Particle:new(self.x +  math.random(-2,2), self.y + math.random(-2, 2), math.random(5, 15), math.random(5, 7), math.random(0.2, 0.3))
    table.insert(particles, particle)
end

function Enemy:animate(startFrame, endFrame, dt)
    self.animationTimer = self.animationTimer + dt
    if self.animationTimer >= self.animationSpeed then
        self.animationTimer = 0
        self.currentFrame = self.currentFrame + 1
        if self.currentFrame > endFrame then
            self.currentFrame = startFrame
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

    local scaleX = 0.7
    if self.flipH then
        scaleX = -0.7
    end

    love.graphics.draw(self.spriteShadow, self.x - 6, self.y - 6, 0 , 0.7, 0.7)
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

    if DEBUG then 
        love.graphics.rectangle("line", self.x - 3.5, self.y - 3.5, 7, 7)
    end
end

return Enemy