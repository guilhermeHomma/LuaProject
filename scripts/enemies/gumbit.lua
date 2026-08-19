local Zombie = require("scripts/enemies/zombie")

local Gumbit = setmetatable({}, {__index = Zombie})
Gumbit.__index = Gumbit
Gumbit.enemyTypeId = "gumbit"

local FRAME_SIZE = 32
local DEATH_FRAME_DURATION = 0.12
local SHADOW_SCALE = 1.5
local SPEED_SCALE = 0.75
local spriteRoot = "assets/sprites/enemy/gumbit/"
local idleSprite = love.graphics.newImage(spriteRoot .. "idle.png")
local walkSprite = love.graphics.newImage(spriteRoot .. "walk.png")
local deathSprite = love.graphics.newImage(spriteRoot .. "death.png")
local idleFrames = {}
local walkFrames = {}
local deathFrames = {}

local function buildFrames(sprite)
    local frames = {}
    for index = 0, math.floor(sprite:getWidth() / FRAME_SIZE) - 1 do
        frames[#frames + 1] = love.graphics.newQuad(
            index * FRAME_SIZE,
            0,
            FRAME_SIZE,
            FRAME_SIZE,
            sprite:getDimensions()
        )
    end
    return frames
end

for _, sprite in ipairs({idleSprite, walkSprite, deathSprite}) do
    sprite:setFilter("nearest", "nearest")
end
idleFrames = buildFrames(idleSprite)
walkFrames = buildFrames(walkSprite)
deathFrames = buildFrames(deathSprite)

function Gumbit:new(x, y, speed)
    local movementSpeed = speed and speed * SPEED_SCALE or math.random(45, 48)
    local enemy = Zombie.new(self, x, y, movementSpeed)
    enemy.gumbitAnimationTimer = math.random()
    enemy.deathBodyParticleEnabled = true
    enemy.deathBodyParticleOptions = {
        hitFrame = 3,
        deadFrame = 4,
        frameWidth = FRAME_SIZE,
        frameHeight = FRAME_SIZE,
    }
    return enemy
end

function Gumbit:getSpriteKey()
    return spriteRoot .. "idle.png"
end

function Gumbit:getSprite()
    return idleSprite
end

function Gumbit:drawMouth()
end

function Gumbit:drawShadow()
    if not self.isAlive then
        return
    end

    local shadowWidth, shadowHeight = self.spriteShadow:getDimensions()
    love.graphics.draw(
        self.spriteShadow,
        self.x + 1,
        self.y + 1,
        0,
        SHADOW_SCALE,
        SHADOW_SCALE,
        shadowWidth / 2,
        shadowHeight / 2
    )
end

function Gumbit:drawBodySprite(xOffset, yOffset, scaleX, scaleY, damageScaleX, damageScaleY)
    local sprite = self.state == Zombie.states.walk and walkSprite or idleSprite
    local frames = self.state == Zombie.states.walk and walkFrames or idleFrames
    local frameIndex = (math.floor((self.gumbitAnimationTimer or 0) / self.animationSpeed) % #frames) + 1

    love.graphics.draw(
        sprite,
        frames[frameIndex],
        xOffset + self.x,
        self.y + yOffset,
        0,
        scaleX * damageScaleX,
        scaleY * damageScaleY,
        FRAME_SIZE / 2,
        FRAME_SIZE
    )
end

function Gumbit:startDeathAnimation()
    self.dying = true
    self.collisionDisabled = true
    self.deathAnimationTimer = 0
    self.deathFrame = 1
    self.noise:stop()
end

function Gumbit:updateDeathAnimation(dt)
    addToDrawQueue(self.y + 6 + self.drawPriority, self)
    self.deathAnimationTimer = self.deathAnimationTimer + dt
    self.deathFrame = math.min(#deathFrames, math.floor(self.deathAnimationTimer / DEATH_FRAME_DURATION) + 1)

    if self.deathAnimationTimer >= #deathFrames * DEATH_FRAME_DURATION then
        self.dying = false
        self.state = Zombie.states.idle
        self.spriteSheet = deathSprite
        Zombie.death(self)
    end
end

function Gumbit:update(dt)
    if self.dying then
        self:updateDeathAnimation(dt)
        return
    end
    self.gumbitAnimationTimer = (self.gumbitAnimationTimer or 0) + dt
    Zombie.update(self, dt)
end

function Gumbit:death()
    if self.life > 0 or not self.isAlive or self.dying then
        return
    end
    if self.state == Zombie.states.damage then
        return
    end
    self:startDeathAnimation()
end

function Gumbit:draw()
    if not self.dying then
        Zombie.draw(self)
        return
    end

    local scaleX = self.flipH and -1 or 1
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(
        deathSprite,
        deathFrames[self.deathFrame],
        self.x,
        self.y,
        0,
        scaleX,
        1.4,
        FRAME_SIZE / 2,
        FRAME_SIZE
    )
end

function Gumbit:drawXray()
    self:draw()
end

return Gumbit
