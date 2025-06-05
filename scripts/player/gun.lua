

local Gun = {}

local Bullet = require("scripts/bullet")

function Gun:load()
    self.x = 0
    self.y = 0
    self.size = 16
    self.centerDistance = 0
    self.bullets = {}
    self.gunSheet = love.graphics.newImage("assets/sprites/player/guns.png")
    self.gunSheet:setFilter("nearest", "nearest")
    self.squareAngle = 0
    self.gunIndex = 1 -- 1 2 ou 3
    self.height = 16
    self.angle = 0

    self.gunConfig = {
        {shotCooldown = 0.54, damage = 10, bulletSpeed = 300, shootFunction = function() self:shootPistol() end},
        {shotCooldown = 0.92, damage = 15, bulletSpeed = 230, shootFunction = function() self:shootShotgun() end},
        {shotCooldown = 0.3, damage = 15, bulletSpeed = 340, shootFunction = function() self:shootPistol() end},
        {shotCooldown = 0.6, damage = 10, bulletSpeed = 250, shootFunction = function() self:shootSquareGun() end},
    }

    self.shootTimer = 0
    self.showGunTime = 0.5
    self.showGun = false
end

function Gun:update(dt, playerX, playerY)
    self.x = playerX
    self.y = playerY
    self.angle = math.floor(mouseAngle() * 6) / 6
    self.squareAngle = self.squareAngle + 0.8*dt
    self.shootTimer = self.shootTimer + dt

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

    bulletSound:setVolume(1)
    bulletSound:setPitch(0.7 + math.random() * 0.1)
    bulletSound:play()
end

function Gun:shootPistol()
    local angle = mouseAngle() + (math.random() * 0.1) - 0.05

    local offsetX = math.cos(angle) * 5
    local offsetY = math.sin(angle) * 5

    local damage = self.gunConfig[self.gunIndex].damage
    local bulletSpeed = self.gunConfig[self.gunIndex].bulletSpeed

    local bullet = Bullet:new(self.x + offsetX, self.y + offsetY, angle, self.height, bulletSpeed, damage)
    table.insert(self.bullets, bullet)

    local bulletSound = love.audio.newSource("assets/sfx/bullet.mp3", "static")

    bulletSound:setVolume(0.8)
    bulletSound:setPitch(0.9 + math.random() * 0.1)
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

    bulletSound:setVolume(0.8)
    bulletSound:setPitch(0.9 + math.random() * 0.1)
    bulletSound:play()
end

function Gun:shootRaygun()
    local bulletSound = love.audio.newSource("assets/sfx/bullet.mp3", "static")
    bulletSound:setVolume(0.5)
    bulletSound:setPitch(1.0 + math.random() * 0.1)
    bulletSound:play()
end

function Gun:shoot()
    if self.gunConfig[self.gunIndex].shotCooldown >= self.shootTimer then return end

    self.showGun = true
    self.shootTimer = 0 - math.random() * 0.1

    self.gunConfig[self.gunIndex].shootFunction(self)

    camera:shake(80, 0.88)
end

function Gun:aim()
    self.showGun = true
    self.showSight = true
end


function Gun:changeGun(index)
    self.gunIndex = index
    self.showGun = true
    self.shootTimer = 0 - math.random() * 0.1
end

function Gun:drawSight()
    if not self.showSight then return end
    self.showSight = false
    local mouseX, mouseY = mousePosition()
    love.graphics.setColor(0.274, 0.4, 0.45, 1)

    Player:drawSquare(mouseX, mouseY, self.squareAngle*3.5, 3)
end

function Gun:drawUI()
    local size = 40
    local startX = 13.5
    local startY = 10.5
    local line = 3
    love.graphics.setLineWidth(line)
    love.graphics.setColor(hexToRGB("090909"))
    love.graphics.rectangle("line", startX+line, startY+line, size, size)
    love.graphics.rectangle("line", startX + size + 10+line, startY+line, size, size)
    love.graphics.setColor(1, 1, 1, 1)
    
    love.graphics.rectangle("line", startX, startY, size, size)
    love.graphics.setColor(0.274, 0.4, 0.45, 1)

    love.graphics.rectangle("line", startX + size + 10, startY, size, size)
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

end

function Gun:draw()

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