require("scripts/utils")

local Player = {}

local Bullet = require("scripts/bullet")
local Particle = require("scripts/particle")
local Tilemap = require("scripts/tilemap")

local bulletSound = love.audio.newSource("assets/sfx/tanksound.wav", "static")
bulletSound:setVolume(0.4)
bulletSound:setLooping(true) 

function Player:load(camera)
    self.x = 0
    self.y = 20
    self.speed = 45
    self.currentVelocity = 10
    self.size = 40
    self.angle = 0
    self.squareAngle = 0
    self.currentSprites = {}
    self.spriteSize = 32
    self.playerSheet = love.graphics.newImage("assets/sprites/player/player.png")
    self.playerOutlineSheet = love.graphics.newImage("assets/sprites/player/player-outline.png")
    self.playerSheet:setFilter("nearest", "nearest")
    self.playerOutlineSheet:setFilter("nearest", "nearest")
    self.bullets = {}
    self.bulletSpeed = 340
    self.camera = camera
    self.totalLife = 4
    self.life = self.totalLife
    self.isAlive = true

    local sheetWidth, sheetHeight = self.playerSheet:getDimensions()

    for x = 0, sheetWidth - self.spriteSize, self.spriteSize do

        local quad = love.graphics.newQuad(x, 0, self.spriteSize, self.spriteSize, sheetWidth, sheetHeight)
        table.insert(self.currentSprites, quad)

    end
end

function Player:update(dt)
    if not self.isAlive then
        return
    end

    local moveX, moveY = 0, 0
    local acceleration = 35
    local deceleration = 40
    local moving = false

    if self.currentVelocity > 17 then
        self.squareAngle = self.squareAngle + self.currentVelocity *0.04*dt
    else 
        self.squareAngle = self.squareAngle + 0.8*dt
    end

    if love.keyboard.isDown("w") then
        self.currentVelocity = math.min(self.currentVelocity + acceleration * dt, self.speed)
        moving = true
    elseif love.keyboard.isDown("s") then
        self.currentVelocity = math.max(self.currentVelocity - acceleration * dt, -self.speed / 2)
        moving = true
    else
        if self.currentVelocity > 0 then
            self.currentVelocity = math.max(0, self.currentVelocity - deceleration * dt)
        elseif self.currentVelocity < 0 then
            self.currentVelocity = math.min(0, self.currentVelocity + deceleration * dt)
        end
    end

    if love.keyboard.isDown("a") then
        self.angle = self.angle - 0.02
        moving = true
    end
    if love.keyboard.isDown("d") then
        self.angle = self.angle + 0.02
        moving = true
    end

    if moving then
        if bulletSound:isPlaying() == false then
            love.audio.play(bulletSound)
        end
    else
        love.audio.stop(bulletSound)
    end

    moveX = math.cos(self.angle) * self.currentVelocity * dt
    moveY = math.sin(self.angle) * self.currentVelocity * dt
    
    local collidedX, collidedY = self:isColliding(moveX, moveY)

    if collidedX then moveX = 0 end
    if collidedY then moveY = 0 end
    if collidedX or collidedY then self.currentVelocity = self.currentVelocity * 0.96 end
    self.x = self.x + moveX
    self.y = self.y + moveY


    addToDrawQueue(self.y+7, Player)

    for i = #self.bullets, 1, -1 do
        local bullet = self.bullets[i]
        bullet:update(dt)
        if not bullet.isAlive then
            table.remove(self.bullets, i)
        end
    end

    for _, enemy in ipairs(enemies) do
        local dx = enemy.x - self.x
        local dy = enemy.y - self.y
        local distance = math.sqrt(dx * dx + dy * dy)

        if distance < 15 then
            enemy.life = 0
            enemy:death()
            camera:shake(2, 0.95)
            self.life = self.life - 1
            local bulletSound = love.audio.newSource("assets/sfx/damage.wav", "static")

            bulletSound:setVolume(1.8)
            bulletSound:setPitch(0.9 + math.random() * 0.2)
            bulletSound:play()
        end
    end

    Player:death()
end


function Player:getCollisionBox()
    return { x = self.x - 22/2, y = self.y - 22/2, width = 22, height = 22 }
end

function Player:isColliding(moveX, moveY, size)
    if not size then size = 22 end

    local futureX = self.x + moveX
    local futureY = self.y + moveY

    local playerBoxX = { x = futureX - size/2, y = self.y - size/2, width = size, height = size }
    local playerBoxY = { x = self.x - size/2, y = futureY - size/2, width = size, height = size }
    
    local collidedX = false
    local collidedY = false

    for _, tile in ipairs(Tilemap.tiles) do
        if tile.quadIndex ~= 5 and tile.quadIndex ~= 15 then
            local tileBox = { x = tile.xWorld - tile.size/2, y = tile.yWorld - tile.size, width = tile.size, height = tile.size }

            if checkCollision(playerBoxX, tileBox) then
                collidedX = true
            end
            if checkCollision(playerBoxY, tileBox) then
                collidedY = true
            end
        end
    end

    return collidedX, collidedY
end

function Player:death()
    if self.life > 0 or not self.isAlive then
        return
    end
    
    self.isAlive = false 
    local particle = Particle:new(self.x, self.y, 13, 7,0.3)
    table.insert(particles, particle)
    for i = 1, 7 do
        local particle = Particle:new(
            self.x + math.random(-3, 3),
            self.y + math.random(-3, 3),
            math.random(5, 15),
            math.random(7, 8),
            math.random(0.4 + i*0.05, 0.5 + i*0.05)
        )
        table.insert(particles, particle)
    end

    love.audio.stop(bulletSound)
end

function Player:mouseAngle()
    local mouseX, mouseY = love.mouse.getPosition()
    
    mouseX = mouseX/3 - self.x + self.camera.x/3 + self.x
    mouseY = mouseY/2 - self.y + self.camera.y/2 + self.y

    return math.atan2(mouseY - self.y, mouseX - self.x)
end

function Player:shoot()

    local angle = Player:mouseAngle()

    local offsetX = math.cos(angle) * 5
    local offsetY = math.sin(angle) * 5

    local bullet = Bullet:new(self.x + offsetX, self.y + offsetY, angle, 15,self.bulletSpeed)
    camera:shake(1, 0.88)
    table.insert(self.bullets, bullet)
end

function love.mousepressed(x, y, button)
    if button == 1 and Player.isAlive then
        Player:shoot()
    end
end

function Player:drawLife()
    if not self.isAlive then
        return
    end

    local size = 32
    local spacing = 5
    local startX = 15
    local startY = 15

    for i = 1, self.totalLife do
        love.graphics.setColor(0.274, 0.4, 0.45)

        if self.life < i then
            love.graphics.setColor(0.70, 0.63, 0.52)

        end
        love.graphics.rectangle("fill", startX + (i - 1) * (size + spacing), startY, size, size)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function Player:drawSight()
    if not self.isAlive then
        return
    end

    local mouseX, mouseY = love.mouse.getPosition()
    mouseX = mouseX/3 - self.x + self.camera.x/3 + self.x
    mouseY = mouseY/2 - self.y + self.camera.y/2 + self.y
    love.graphics.setColor(0.274, 0.4, 0.45, 1)

    self:drawSquare(mouseX, mouseY, self.squareAngle*3.5, 3)

end

function Player:drawS()
    if not self.isAlive then
        return
    end

    love.graphics.draw(self.playerSheet, self.currentSprites[1], self.x, self.y, self.angle, 1, 1, self.spriteSize/2, self.spriteSize/2)

    self:drawSquare(self.x, self.y, self.squareAngle, 32 * 0.45)

end

function Player:drawSquare(x, y, angle, halfSize)
    local cx, cy = x, y
    local cosA, sinA = math.cos(angle), math.sin(angle)

    local x1 = cx + (-halfSize * cosA - (-halfSize) * sinA)
    local y1 = cy + (-halfSize * sinA + (-halfSize) * cosA)

    local x2 = cx + (halfSize * cosA - (-halfSize) * sinA)
    local y2 = cy + (halfSize * sinA + (-halfSize) * cosA)

    local x3 = cx + (halfSize * cosA - halfSize * sinA)
    local y3 = cy + (halfSize * sinA + halfSize * cosA)

    local x4 = cx + (-halfSize * cosA - halfSize * sinA)
    local y4 = cy + (-halfSize * sinA + halfSize * cosA)

    love.graphics.setLineWidth(0.8)
    love.graphics.line(x1, y1, x2, y2)
    love.graphics.line(x2, y2, x3, y3)
    love.graphics.line(x3, y3, x4, y4)
    love.graphics.line(x4, y4, x1, y1)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setLineWidth(1)
end

function Player:draw()
    if not self.isAlive then
        return
    end

    local padding = 1

    for i, quad in ipairs(self.currentSprites) do
        
            local x = self.x
            local y = self.y - i * padding
    
            local angle = self.angle
    
            if i >= 15 then
                angle = self:mouseAngle()
            end

            love.graphics.draw(self.playerOutlineSheet, quad, x, y, angle, 1, 1, self.spriteSize/2, self.spriteSize/2)
          
    end

    if DEBUG then
        love.graphics.rectangle("line", self.x - 11, self.y - 11, 22, 22)
    end
    
    for i, quad in ipairs(self.currentSprites) do
        if i == 1 then
            do
                goto continue
            end
        end
        local x = self.x
        local y = self.y - i * padding

        local angle = self.angle

        if i >= 15 then
            angle = self:mouseAngle()
        end

        love.graphics.draw(self.playerSheet, quad, x, y, angle, 1, 1, self.spriteSize/2, self.spriteSize/2)
        ::continue::
    end

    
end

return Player