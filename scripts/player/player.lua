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
    self.speed = 55
    self.size = 40

    self.squareAngle = 0
    self.spriteSize = 40
    self.bullets = {}
    self.bulletSpeed = 340
    self.camera = camera
    self.totalLife = 4
    self.life = self.totalLife
    self.isAlive = true
    self.flipX = false
    self.playerSheet = love.graphics.newImage("assets/sprites/player/soldier/soldier.png")
    self.playerShadow = love.graphics.newImage("assets/sprites/player/shadow.png")
    self.playerSheet:setFilter("nearest", "nearest")
    self.playerShadow:setFilter("nearest", "nearest")

    self.spriteQuad = love.graphics.newQuad(0, 0, self.spriteSize, self.spriteSize, self.playerSheet:getDimensions())

    self.animations = {
        idle = { frames = {0, 1}, duration = 2 },
        walk = { frames = {2, 3, 4, 5}, duration = 0.6 }
    }
    self.currentAnimation = "idle"
    self.currentFrame = 1
    self.animationTimer = 0

    -- Pré-carrega os quads
    self.quads = {}
    local sheetWidth = self.playerSheet:getWidth()
    for i = 0, 5 do
        local quad = love.graphics.newQuad(
            i * self.spriteSize, 0,
            self.spriteSize, self.spriteSize,
            sheetWidth, self.playerSheet:getHeight()
        )
        table.insert(self.quads, quad)
    end

end

function Player:updateAnimation(dt, moving)
    local newAnimation = moving and "walk" or "idle"

    if self.currentAnimation ~= newAnimation then
        self.currentAnimation = newAnimation
        self.currentFrame = 1
        self.animationTimer = 0
    end

    local anim = self.animations[self.currentAnimation]
    local frameTime = anim.duration / #anim.frames

    if self.currentAnimation == "idle" and self.currentFrame == 2 then
        frameTime = 0.1
    end

    self.animationTimer = self.animationTimer + dt

    if self.animationTimer >= frameTime then
        self.animationTimer = self.animationTimer - frameTime
        self.currentFrame = self.currentFrame + 1
        if self.currentFrame > #anim.frames then
            self.currentFrame = 1
        end
    end
end

function Player:update(dt)
    if not self.isAlive then
        return
    end

    self.squareAngle = self.squareAngle + 0.8*dt

    local moveX, moveY = 0, 0

    -- Input WASD
    if love.keyboard.isDown("w") then
        moveY = moveY - 1
    end
    if love.keyboard.isDown("s") then
        moveY = moveY + 1
    end
    if love.keyboard.isDown("a") then
        moveX = moveX - 1
    end
    if love.keyboard.isDown("d") then
        moveX = moveX + 1
    end

    if moveX ~= 0 and moveY ~= 0 then
        local diagFactor = 1 / math.sqrt(2)
        moveX = moveX * diagFactor
        moveY = moveY * diagFactor
    end

    local collidedX, collidedY = self:isColliding(moveX, moveY)

    if collidedX then moveX = 0 end
    if collidedY then moveY = 0 end

    --if moveX ~= 0 then
        --if moveX > 0 then self.flipH = true
        --else self.flipH = false end
    --end
    
    self.x = self.x + moveX * self.speed * dt
    self.y = self.y + moveY * self.speed * dt


    addToDrawQueue(self.y+7, Player)

    for i = #self.bullets, 1, -1 do
        local bullet = self.bullets[i]
        bullet:update(dt)
        if not bullet.isAlive then
            table.remove(self.bullets, i)
        end
    end

    self:checkDamage()
    self:updateAnimation(dt, moveX ~= 0 or moveY ~= 0)
    self:death()
end

function Player:checkDamage()
    for _, enemy in ipairs(enemies) do
        local dx = enemy.x - self.x
        local dy = enemy.y - self.y
        local distance = math.sqrt(dx * dx + dy * dy)

        if distance < 12 then
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
end

function Player:getCollisionBox()
    local size = 12
    return { x = self.x - size/2, y = self.y - size/2, width = size, height = size, size = size }
end

function Player:isColliding(moveX, moveY, size)
    if not size then size = self:getCollisionBox().size end


    local playerBoxX = self:getCollisionBox()
    playerBoxX.x = playerBoxX.x + moveX
    local playerBoxY = self:getCollisionBox()
    playerBoxY.y = playerBoxY.y + moveY

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

    if mouseX > self.x then
        self.flipH = true
    elseif mouseX < self.x then
        self.flipH = false
    end

    love.graphics.setColor(0.274, 0.4, 0.45, 1)

    self:drawSquare(mouseX, mouseY, self.squareAngle*3.5, 3)

end

function Player:drawS()
    if not self.isAlive then
        return
    end

    love.graphics.draw(self.playerShadow, self.x, self.y, 0, 0.85, 0.85, 8, 8)
    --love.graphics.draw(self.spriteShadow, self.x - 6, self.y - 6, 0 , 0.7, 0.7)
    --self:drawSquare(self.x, self.y, self.squareAngle, 16 * 0.45)

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
    if not self.isAlive then return end

    local anim = self.animations[self.currentAnimation]
    local frameIndex = anim.frames[self.currentFrame]

    local quad = self.quads[frameIndex + 1] -- +1 porque Lua começa em 1

    local scaleX = self.flipH and -0.85 or 0.85
    local originX = self.flipH and (self.spriteSize - self.spriteSize / 2) or (self.spriteSize / 2)

    love.graphics.draw(
        self.playerSheet,
        quad,
        self.x,
        self.y,
        0,
        scaleX, 1.2,
        originX, self.spriteSize
    )

    if DEBUG then
        local collisionBox = self:getCollisionBox()
        love.graphics.rectangle("line", collisionBox.x, collisionBox.y, collisionBox.width, collisionBox.height)
    end
end

return Player