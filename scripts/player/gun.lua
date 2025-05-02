

local Gun = {}

local Bullet = require("scripts/bullet")

local bulletSound = love.audio.newSource("assets/sfx/tanksound.wav", "static")
bulletSound:setVolume(0.4)
bulletSound:setLooping(true) 

function Gun:load()
    self.x = 0
    self.y = 0
    self.size = 16
    self.centerDistance = 5
    self.bullets = {}
    self.gunSheet = love.graphics.newImage("assets/sprites/player/guns.png")
    self.gunSheet:setFilter("nearest", "nearest")
    self.squareAngle = 0
    self.gunIndex = 2 -- 1 2 ou 3

    self.gunConfig = {
        {shotCooldown = 0.54, damage = 10, bulletSpeed = 300, shootFunction = function() self:shootPistol() end},
        {shotCooldown = 0.8, damage = 15, bulletSpeed = 230, shootFunction = function() self:shootShotgun() end},
        {shotCooldown = 0.4, damage = 20, bulletSpeed = 340, shootFunction = function() self:shootPistol() end},

    }

    self.shootTimer = 0
    self.showGunTime = 1.5
    self.showGun = false
end



function Gun:update(dt, playerX, playerY)
    self.x = playerX
    self.y = playerY

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

    local bullet = Bullet:new(self.x + offsetX, self.y + offsetY, angle, 15, bulletSpeed, damage)
    table.insert(self.bullets, bullet)

    local bullet = Bullet:new(self.x + offsetX, self.y + offsetY, angle + 0.15, 15, bulletSpeed, damage)
    table.insert(self.bullets, bullet)

    local bullet = Bullet:new(self.x + offsetX, self.y + offsetY, angle- 0.15, 15, bulletSpeed, damage)
    table.insert(self.bullets, bullet)

    local bulletSound = love.audio.newSource("assets/sfx/bullet.wav", "static")

    bulletSound:setVolume(0.9)
    bulletSound:setPitch(0.7 + math.random() * 0.2)
    bulletSound:play()

end

function Gun:shootPistol()
    local angle = mouseAngle()

    local offsetX = math.cos(angle) * 5
    local offsetY = math.sin(angle) * 5

    local damage = self.gunConfig[self.gunIndex].damage
    local bulletSpeed = self.gunConfig[self.gunIndex].bulletSpeed

    local bullet = Bullet:new(self.x + offsetX, self.y + offsetY, angle, 15, bulletSpeed, damage)
    table.insert(self.bullets, bullet)

    local bulletSound = love.audio.newSource("assets/sfx/bullet.wav", "static")

    bulletSound:setVolume(0.6)
    bulletSound:setPitch(0.9 + math.random() * 0.3)
    bulletSound:play()

end

function Gun:shootRaygun()


    local bulletSound = love.audio.newSource("assets/sfx/bullet.wav", "static")

    bulletSound:setVolume(0.9)
    bulletSound:setPitch(0.9 + math.random() * 0.3)
    bulletSound:play()

end

function Gun:shoot()
    if self.gunConfig[self.gunIndex].shotCooldown >= self.shootTimer then return end

    self.showGun = true
    self.shootTimer = 0

    self.gunConfig[self.gunIndex].shootFunction(self)

    camera:shake(1, 0.88) 
end

function Gun:aim()
    self.showGun = true
    self.showSight = true
end


function Gun:drawSight()
    if not self.showSight then return end
    self.showSight = false
    local mouseX, mouseY = mousePosition()
    love.graphics.setColor(0.274, 0.4, 0.45, 1)

    Player:drawSquare(mouseX, mouseY, self.squareAngle*3.5, 3)
end

function Gun:draw()

    local angle = mouseAngle()

    local quad = love.graphics.newQuad(
        (self.gunIndex - 1) * self.size, 
        0,
        self.size, self.size,
        self.gunSheet:getDimensions()
    )

    local offsetX = math.cos(angle) * self.centerDistance
    local offsetY = math.sin(angle) * self.centerDistance

    for i = 0, 2, 1 do

        love.graphics.draw(
            self.gunSheet,
            quad,
            self.x + offsetX,
            self.y + offsetY - 14 + i,
            angle,
            0.8, 0.8,
            0,
            self.size / 2
        )
    end 

end

return Gun