

local Gun = {}

local Bullet = require("scripts/bullet")

function Gun:load()
    self.x = 0
    self.y = 0
    self.size = 16
    self.centerDistance = 0
    self.bullets = {}
    self.gunSheet = love.graphics.newImage("assets/sprites/player/guns.png")
    
    self.bulletSheet = love.graphics.newImage("assets/sprites/player/gun-bullet.png")
    self.gunSheet:setFilter("nearest", "nearest")
    self.bulletSheet:setFilter("nearest", "nearest")
    self.squareAngle = 0
    self.gunIndex = 1 -- 1 2 ou 3
    self.height = 16
    self.angle = 0

    self.gunConfig = {
        {shotCooldown = 0.54, magCount = 12 ,magCapacity = 6, damage = 10, bulletSpeed = 300, shootFunction = function() self:shootPistol() end},
        {shotCooldown = 0.92, magCount = 15 ,magCapacity = 6, damage = 15, bulletSpeed = 230, shootFunction = function() self:shootShotgun() end},
        {shotCooldown = 0.3, magCount = 10, magCapacity = 10, damage = 15, bulletSpeed = 340, shootFunction = function() self:shootPistol() end},
        {shotCooldown = 0.6, magCount = 12, magCapacity = 8, damage = 10, bulletSpeed = 250, shootFunction = function() self:shootSquareGun() end},
    }
    self.currentMagCapacity = self.gunConfig[self.gunIndex].magCapacity
    self.currentMagCount = self.gunConfig[self.gunIndex].magCount

    self.shootTimer = 0
    self.showGunTime = 0.5
    self.showGun = false

    self.font = love.graphics.newFont("assets/fonts/ThaleahFat.ttf", 32)
    self.font:setFilter("nearest", "nearest")


    self.particlesshootSheet = love.graphics.newImage("assets/sprites/particles/gunSmoke.png")
    self.particlesTimer = 0
    self.showParticles = false

end

function Gun:update(dt, playerX, playerY)
    self.x = playerX
    self.y = playerY
    self.angle = math.floor(mouseAngle() * 6) / 6
    self.squareAngle = self.squareAngle + 0.8*dt
    self.shootTimer = self.shootTimer + dt
    self.particlesTimer = self.particlesTimer + dt

    if self.shootTimer >= self.showGunTime then
        self.showGun = false
    end

    if love.mouse.isDown(2) then
        self:aim()
    end

    if love.mouse.isDown(1) then
        self:shoot()
    end

    for i = #self.bullets, 1, -1 do
        local bullet = self.bullets[i]
        bullet:update(dt)
        if not bullet.isAlive then
            table.remove(self.bullets, i)
        end
    end
end

function Gun:showshootParticles()
    self.particlesTimer = 0
    self.showParticles = true
end

function Gun:shootShotgun()
    local angle = mouseAngle()

    local offsetX = math.cos(angle) * 5
    local offsetY = math.sin(angle) * 5

    local damage = self.gunConfig[self.gunIndex].damage
    local bulletSpeed = self.gunConfig[self.gunIndex].bulletSpeed

    local bullet = Bullet:new(self.x + offsetX, self.y + offsetY, angle + (math.random() * 0.1), self.height, bulletSpeed, damage)
    table.insert(self.bullets, bullet)

    local bullet = Bullet:new(self.x + offsetX, self.y + offsetY, angle + (math.random() * 0.1) + 0.15, self.height, bulletSpeed, damage)
    table.insert(self.bullets, bullet)

    local bullet = Bullet:new(self.x + offsetX, self.y + offsetY, angle + (math.random() * 0.1)- 0.15, self.height, bulletSpeed, damage)
    table.insert(self.bullets, bullet)

    local bulletSound = love.audio.newSource("assets/sfx/bullet.mp3", "static")
    self.currentMagCapacity = self.currentMagCapacity - 3
    bulletSound:setVolume(1)
    bulletSound:setPitch((0.7 + math.random() * 0.1) * GAME_PITCH)
    bulletSound:play()
end

function Gun:shootPistol()
    

    local angle = mouseAngle() + (math.random() * 0.1) - 0.05

    local offsetX = math.cos(angle) * 5
    local offsetY = math.sin(angle) * 5

    local damage = self.gunConfig[self.gunIndex].damage
    local bulletSpeed = self.gunConfig[self.gunIndex].bulletSpeed

    self.currentMagCapacity = self.currentMagCapacity - 1

    local bullet = Bullet:new(self.x + offsetX, self.y + offsetY, angle, self.height, bulletSpeed, damage)
    table.insert(self.bullets, bullet)

    local bulletSound = love.audio.newSource("assets/sfx/bullet.mp3", "static")

    bulletSound:setVolume(0.8)
    bulletSound:setPitch((0.9 + math.random() * 0.1) * GAME_PITCH)
    bulletSound:play()
end

function Gun:shootSquareGun()
    local angle = mouseAngle() + (math.random() * 0.1) - 0.05

    local offsetX = math.cos(angle) * 5
    local offsetY = math.sin(angle) * 5

    local damage = self.gunConfig[self.gunIndex].damage
    local bulletSpeed = self.gunConfig[self.gunIndex].bulletSpeed

    local bullet = Bullet:new(self.x + offsetX, self.y + offsetY, angle, self.height, bulletSpeed, damage)
    table.insert(self.bullets, bullet)

    local bullet = Bullet:new(self.x + offsetX * 2 + 2, self.y + offsetY* 2 + 2, angle + 0.1, 15, bulletSpeed, damage)
    table.insert(self.bullets, bullet)

    local bulletSound = love.audio.newSource("assets/sfx/bullet.mp3", "static")
    self.currentMagCapacity = self.currentMagCapacity - 2
    bulletSound:setVolume(0.8)
    bulletSound:setPitch((0.9 + math.random() * 0.1) * GAME_PITCH)
    bulletSound:play()
end

function Gun:shootRaygun()
    local bulletSound = love.audio.newSource("assets/sfx/bullet.mp3", "static")
    bulletSound:setVolume(0.5)
    bulletSound:setPitch((1.0 + math.random() * 0.1) * GAME_PITCH)
    bulletSound:play()
end

function Gun:shoot()
    if self.gunConfig[self.gunIndex].shotCooldown >= self.shootTimer then return end

    self.showGun = true
    self.shootTimer = 0 - math.random() * 0.1

    if self.currentMagCapacity > 0 then
        self.gunConfig[self.gunIndex].shootFunction(self)
        camera:shake(80, 0.88)
        self:showshootParticles()

    elseif self.currentMagCount > 0 then
        self.currentMagCount = self.currentMagCount - 1
        self.currentMagCapacity = self.gunConfig[self.gunIndex].magCapacity
        local bulletSound = love.audio.newSource("assets/sfx/bullet.mp3", "static")
        bulletSound:setVolume(0.1)
        bulletSound:setPitch((1.6 + math.random() * 0.1) * GAME_PITCH)
        bulletSound:play()
        self.shootTimer = self.shootTimer + self.gunConfig[self.gunIndex].shotCooldown / 2

    else
        local bulletSound = love.audio.newSource("assets/sfx/bullet.mp3", "static")
        bulletSound:setVolume(0.2)
        bulletSound:setPitch((1.9 + math.random() * 0.1) * GAME_PITCH)
        bulletSound:play()
    end 
        

    
end

function Gun:aim()
    self.showGun = true
    self.showSight = true
end


function Gun:changeGun(index)
    self.gunIndex = index
    self.showGun = true
    self.shootTimer = 0 - math.random() * 0.1

    self.currentMagCapacity = self.gunConfig[self.gunIndex].magCapacity
    self.currentMagCount = self.gunConfig[self.gunIndex].magCount
end

function Gun:drawSight()
    if not self.showSight then return end
    self.showSight = false
    local mouseX, mouseY = mousePosition()
    love.graphics.setColor(0.274, 0.4, 0.45, 1)

    Player:drawSquare(mouseX, mouseY, self.squareAngle*3.5, 3)
end

function Gun:drawParticles()

    local frameDuration = 0.04
    local totalFrames = 6

    if self.particlesTimer > frameDuration * totalFrames then return end

    local frameIndex = math.floor(self.particlesTimer / frameDuration) % totalFrames

    local quad = love.graphics.newQuad(
        frameIndex * 16, 0,
        16, 16,
        self.particlesshootSheet:getDimensions()
    )

    local offsetX = math.cos(self.angle) * (self.centerDistance + 11)
    local offsetY = math.sin(self.angle) * (self.centerDistance + 11)

    for i = 1, 0, -0.5 do

        love.graphics.draw(
            self.particlesshootSheet,
            quad,
            self.x + offsetX,
            self.y + offsetY - self.height + i,
            self.angle,
            0.7, 0.7,
            0,
            self.size / 2
        )
    end 
end

function Gun:drawUI()
    local size = 40
    local startX = 13.5
    local startY = 10.5
    local line = 3
    love.graphics.setLineWidth(line)
    love.graphics.setColor(hexToRGB("090909"))
    love.graphics.rectangle("line", startX+line, startY+line, size, size)
    --love.graphics.rectangle("line", startX + size + 10+line, startY+line, size, size)
    love.graphics.setColor(1, 1, 1, 1)
    
    love.graphics.rectangle("line", startX, startY, size, size)
    love.graphics.setColor(0.274, 0.4, 0.45, 1)

    --love.graphics.rectangle("line", startX + size + 10, startY, size, size)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
    local quad = love.graphics.newQuad(
        (self.gunIndex - 1) * self.size, 16,
        self.size, self.size,
        self.gunSheet:getDimensions()
    )

    love.graphics.draw(
        self.gunSheet, quad, 20,
        40, 0, 3, 3, 0,
        self.size / 2
    )

    local text = self.currentMagCount .. "/" .. self.gunConfig[self.gunIndex].magCount
    local textWidth = self.font:getWidth(text)

    local x = 66
    local y = 27
    
    love.graphics.setFont(self.font)
    --love.graphics.setColor(0.05, 0, 0.05, 1)
    love.graphics.print(text, x, y)

    local startX = 12
    local startY = 81
    for i = 1, self.gunConfig[self.gunIndex].magCapacity do
        local quad = love.graphics.newQuad(
        0, 0,
        self.size, self.size,
        self.bulletSheet:getDimensions()
        )   
        
        local quad2 = love.graphics.newQuad(
        self.size, 0,
        self.size, self.size,
        self.bulletSheet:getDimensions()
        )  

        love.graphics.draw(
            self.bulletSheet, quad2, startX,
            startY + i * 18, 0, 3, 3, 0,
            0
        )

        if i <= self.currentMagCapacity then
            love.graphics.draw(
                self.bulletSheet, quad, startX,
                startY + i * 18, 0, 3, 3, 0,
                0
            )
        end
    end
end

function Gun:draw()

    self:drawParticles()

    local quad = love.graphics.newQuad(
        (self.gunIndex - 1) * self.size, 
        0,
        self.size, self.size,
        self.gunSheet:getDimensions()
    )

    local offsetX = math.cos(self.angle) * self.centerDistance
    local offsetY = math.sin(self.angle) * self.centerDistance

    for i = 2, 0, -0.5 do

        love.graphics.draw(
            self.gunSheet,
            quad,
            self.x + offsetX,
            self.y + offsetY - self.height + i,
            self.angle,
            0.8, 0.8,
            0,
            self.size / 2
        )
    end 

end

return Gun