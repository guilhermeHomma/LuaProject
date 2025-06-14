Particle = require("scripts/particles/particle")
Ball = require("scripts/particles/ballParticle")
ZombieParticle = setmetatable({}, {__index = Particle})
ZombieParticle.__index = ZombieParticle
local whiteShader = love.graphics.newShader("scripts/shaders/whiteShader.glsl")


function ZombieParticle:new(x, y, sprite)

    local particle = Particle.new(self, x, y, 10, 7, 0.9)
    particle.sprite = sprite
    particle.spriteShadow = love.graphics.newImage("assets/sprites/enemy/enemyShadow.png")
    particle.spriteShadow:setFilter("nearest", "nearest")
    return particle
end

function ZombieParticle:update(dt)
    addToDrawQueue(self.y + 5, self)

    self.timer = self.timer + dt

    if self.timer >= self.lifeTime then
        self:death()
    end
end


function ZombieParticle:drawShadow()

    if not self.isAlive then
        return
    end

    love.graphics.draw(self.spriteShadow, self.x - 6, self.y- 6, 0 , 1, 1)
end


function ZombieParticle:death()
    self.isAlive = false
    local playerDistance = distance(Player, self)
    
    local bulletSound = love.audio.newSource("assets/sfx/particles/particle-end.mp3", "static")

    getDistanceVolume(playerDistance, 0.2, 200)
    bulletSound:setVolume(0.1)
    bulletSound:setPitch((1 + math.random() * 0.1) * GAME_PITCH)
    bulletSound:play()
    
    for i = 1, 3 do
        local angle = math.random() * 2 * math.pi

        local dx = math.cos(angle)
        local dy = math.sin(angle)
        
        local lifetime = math.random(40, 50) / 100
        local size = math.random(8, 10) / 10
        local particle = Ball:new(self.x, self.y, 1,dx, dy, lifetime, size )
        table.insert(Game.particles, particle)
        local particle = Ball:new(self.x, self.y, 1,-dx, -dy, lifetime, size )
        table.insert(Game.particles, particle)
    end
end

function ZombieParticle:draw()


    if self.timer < 0.05  then
        love.graphics.setShader(whiteShader)   
    end

    love.graphics.setColor(1, 1, 1, 1)
    local sheetWidth = self.sprite:getWidth()
    local sheetHeight = self.sprite:getHeight()
    local quad = love.graphics.newQuad(7 * 32, 0, 32, 32, sheetWidth, sheetHeight)
    if self.timer < 0.3 then
        quad = love.graphics.newQuad(6 * 32, 0, 32, 32, sheetWidth, sheetHeight)
    end
    love.graphics.draw(self.sprite, quad, self.x, self.y + 3, 0, 1, 1.5, 32 / 2, 32)
    love.graphics.setShader()   

    --love.graphics.circle("fill", self.x, self.y -self.height, self.radius)
    love.graphics.setColor(1, 1, 1)
end

return ZombieParticle