local Particle = require("scripts/particles/particle")
local Ball = require("scripts/particles/ballParticle")
local DamageStretch = require("scripts/effects/damageStretch")

local ZombieParticle = setmetatable({}, {__index = Particle})
ZombieParticle.__index = ZombieParticle
local whiteShader = love.graphics.newShader("scripts/shaders/whiteShader.glsl")
local spriteShadow = love.graphics.newImage("assets/sprites/enemy/zombie/enemyShadow.png")
local deathSound = love.audio.newSource("assets/sfx/particles/particle-end.mp3", "static")
local mortarBallOptions = {
    sizeMultiplier = 1.1,
    speedMultiplier = 1.2,
    speedDownMultiplier = 1.2,
}

spriteShadow:setFilter("nearest", "nearest")

local function playClonedSound(baseSource, volume, pitch)
    local sound = baseSource:clone()
    setSourceVolume(sound, volume)
    sound:setPitch(pitch)
    sound:play()
    return sound
end


function ZombieParticle:new(x, y, sprite, options)

    local particle = Particle.new(self, x, y, 10, 7, 0.9)
    options = options or {}
    particle.sprite = sprite
    particle.spriteShadow = spriteShadow
    particle.hitFrame = options.hitFrame or 7
    particle.deadFrame = options.deadFrame or 8
    particle.frameWidth = options.frameWidth or 32
    particle.frameHeight = options.frameHeight or 32
    particle.drawYOffset = options.drawYOffset or 3
    particle.drawScaleX = options.scaleX or 1
    particle.drawScaleY = options.scaleY or 1.4
    particle.drawShadowEnabled = options.drawShadowEnabled ~= false
    DamageStretch:init(particle, 0.1, 0.1)
    particle.deathStretchStarted = false

    local playerDistance = distance(Player, particle)

    getDistanceVolume(playerDistance, 0.2, 200)
    playClonedSound(deathSound, 0.07, (1.2 + math.random() * 0.1) * GAME_PITCH)

    return particle
end

function ZombieParticle:update(dt)
    addToDrawQueue(self.y + 5, self)

    self.timer = self.timer + dt

    if not self.deathStretchStarted and self.timer >= self.lifeTime - self.damageStretchDuration then
        self.deathStretchStarted = true
        DamageStretch:start(self)
    end

    if self.timer >= self.lifeTime then
        self:death()
    end
end


function ZombieParticle:drawShadow()

    if not self.isAlive or not self.drawShadowEnabled then
        return
    end

    love.graphics.draw(self.spriteShadow, self.x - 6, self.y- 6, 0 , 1, 1)
end


function ZombieParticle:death()
    self.isAlive = false
    local playerDistance = distance(Player, self)

    getDistanceVolume(playerDistance, 0.2, 200)
    playClonedSound(deathSound, 0.1, (1 + math.random() * 0.1) * GAME_PITCH)

    for i = 1, 3 do
        local angle = math.random() * 2 * math.pi

        local dx = math.cos(angle)
        local dy = math.sin(angle)
        
        local lifetime = math.random(40, 50) / 100
        local size = math.random(8, 10) / 10
        local particle = Ball:new(self.x, self.y, 1,dx, dy, lifetime, size, mortarBallOptions)
        table.insert(Game.particles, particle)
        local particle = Ball:new(self.x, self.y, 1,-dx, -dy, lifetime, size, mortarBallOptions)
        table.insert(Game.particles, particle)
    end
end

function ZombieParticle:draw()

    local stretchScaleX, stretchScaleY = DamageStretch:getScale(self)

    if self.deathStretchStarted then
        love.graphics.setShader(whiteShader)   
    end

    love.graphics.setColor(1, 1, 1, 1)
    local sheetWidth = self.sprite:getWidth()
    local sheetHeight = self.sprite:getHeight()
    local frameWidth = self.frameWidth or 32
    local frameHeight = self.frameHeight or 32
    self.quadDead = self.quadDead or love.graphics.newQuad((self.deadFrame - 1) * frameWidth, 0, frameWidth, frameHeight, sheetWidth, sheetHeight)
    self.quadHit = self.quadHit or love.graphics.newQuad((self.hitFrame - 1) * frameWidth, 0, frameWidth, frameHeight, sheetWidth, sheetHeight)
    local quad = self.quadDead
    if self.timer < 0.2 then
        quad = self.quadHit
    end
    love.graphics.draw(
        self.sprite,
        quad,
        self.x,
        self.y + (self.drawYOffset or 0),
        0,
        (self.drawScaleX or 1) * stretchScaleX,
        (self.drawScaleY or 1) * stretchScaleY,
        frameWidth / 2,
        frameHeight
    )
    love.graphics.setShader()   

    --love.graphics.circle("fill", self.x, self.y -self.height, self.radius)
    love.graphics.setColor(1, 1, 1)
end

return ZombieParticle
