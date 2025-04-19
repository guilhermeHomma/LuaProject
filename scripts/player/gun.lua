

local Gun = {}

local Bullet = require("scripts/bullet")

local bulletSound = love.audio.newSource("assets/sfx/tanksound.wav", "static")
bulletSound:setVolume(0.4)
bulletSound:setLooping(true) 

function Gun:load()
    self.x = 0
    self.y = 0
    self.centerDistance = 5
    self.bullets = {}
    self.bulletSpeed = 340
end

function Gun:update(dt, playerX, playerY)


    for i = #self.bullets, 1, -1 do
        local bullet = self.bullets[i]
        bullet:update(dt)
        if not bullet.isAlive then
            table.remove(self.bullets, i)
        end
    end

end

function Gun:shoot()

    local angle = Player:mouseAngle()

    local offsetX = math.cos(angle) * 5
    local offsetY = math.sin(angle) * 5

    local bullet = Bullet:new(self.x + offsetX, self.y + offsetY, angle, 15,self.bulletSpeed)
    camera:shake(1, 0.88)
    table.insert(self.bullets, bullet)
end