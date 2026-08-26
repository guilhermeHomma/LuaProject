local Zombie = require("scripts/enemies/zombie")
local ZombieDeadParticle = require("scripts/particles/zombieDeadParticle")

local Fly = setmetatable({}, {__index = Zombie})
Fly.__index = Fly
Fly.enemyTypeId = "fly"

local FLY_COLLISION_RADIUS = 10
local FLY_SPEED_MIN = 78
local FLY_SPEED_MAX = 88
local FLY_FLY_START_FRAME = 1
local FLY_FLY_END_FRAME = 4
local FLY_DEATH_HIT_FRAME = 5
local FLY_DEAD_FRAME = 6
local FLY_DEATH_HIT_TIME = 0.20
local FLY_DEATH_DEAD_TIME = 0.90
local FLY_WALL_RANDOM_TURN_CHANCE = 0.45
local FLY_WHOOSH_INTERVAL = 0.28
local flyWhooshBase = love.audio.newSource("assets/sfx/effects/whoosh.mp3", "static")

local function randomDiagonalDirection()
    local dx = math.random(0, 1) == 0 and -1 or 1
    local dy = math.random(0, 1) == 0 and -1 or 1
    local length = math.sqrt(dx * dx + dy * dy)
    return dx / length, dy / length
end

local function normalize(dx, dy)
    local length = math.sqrt((dx or 0) * (dx or 0) + (dy or 0) * (dy or 0))
    if length <= 0.001 then
        return randomDiagonalDirection()
    end

    return dx / length, dy / length
end

local function setSourcePositionIfMono(source, x, y, z)
    local ok, channels = pcall(function()
        return source:getChannelCount()
    end)

    if ok and channels == 1 then
        source:setPosition(x, y, z or 0)
    end
end

function Fly:new(x, y)
    local enemy = Zombie.new(self, x, y, FLY_SPEED_MIN + math.random() * (FLY_SPEED_MAX - FLY_SPEED_MIN))
    enemy.totalLife = 24
    enemy.life = enemy.totalLife
    enemy.size = FLY_COLLISION_RADIUS
    enemy.dropPoints = 0
    enemy:applyDropConfig("fly")
    enemy.animationSpeed = 0.085
    enemy.damageTimer = 0.14
    enemy.whiteFlashDuration = 0.07
    enemy.damageAnimationInterval = 0.08
    enemy.damageKnockbackTimer = 0
    enemy.damageKnockbackDuration = 0.18
    enemy.damageKnockbackSpeed = 110
    enemy.damageImpactHeightRatio = 0.42
    enemy.bloodSpawnYOffset = -7
    enemy.hitBloodPixelMin = 2
    enemy.hitBloodPixelMax = 3
    enemy.deathBloodPixelMin = 5
    enemy.deathBloodPixelMax = 7
    enemy.hitBloodDecalCooldown = 0.18
    enemy.hitBloodDecalScaleMultiplier = 0.34
    enemy.hitBloodDecalVolumeMultiplier = 0.55
    enemy.hitBloodDecalPitchMultiplier = 0.70
    enemy.deathBloodDecalOptions = {
        scaleMultiplier = 0.64,
        volumeMultiplier = 0.64,
    }
    enemy.deadDropParticleMin = 1
    enemy.deadDropParticleMax = 2
    -- The fly already shows its full death animation before Zombie.death runs.
    -- Spawning another body particle here makes that death appear to happen twice.
    enemy.deathBodyParticleEnabled = false
    enemy.mouthVariant = "none"
    enemy.spawnIntroDuration = 0.16
    enemy.spawnIntroTimer = enemy.spawnIntroDuration
    enemy.skipWalkParticles = true
    enemy.flyWhooshTimer = math.random() * FLY_WHOOSH_INTERVAL
    enemy.flyDirX, enemy.flyDirY = randomDiagonalDirection()
    enemy.state = Zombie.states.walk
    return enemy
end

function Fly.isSpawnPositionClear(x, y)
    local probe = setmetatable({
        x = x,
        y = y,
        size = FLY_COLLISION_RADIUS,
        collisionDisabled = true,
    }, Fly)
    local clearance = 4
    local checks = {
        {clearance, 0},
        {-clearance, 0},
        {0, clearance},
        {0, -clearance},
    }

    for _, offset in ipairs(checks) do
        local collidedX, collidedY = Zombie.isColliding(probe, offset[1], offset[2])
        if collidedX or collidedY then
            return false
        end
    end

    return true
end

function Fly:getSpriteKey()
    return "assets/sprites/enemy/fly/fly.png"
end

function Fly:drawMouth()
end

function Fly:drawShadow()
    if not self.isAlive then
        return
    end

    love.graphics.draw(self.spriteShadow, self.x - 7, self.y - 8, 0, 0.95, 0.95)
end

function Fly:getShotCollisionCircles()
    if self.life <= 0 or self.isAlive == false then
        return {}
    end

    return {
        { x = self.x, y = self.y - 9, radius = 9 },
        { x = self.x, y = self.y - 2, radius = 8 },
    }
end

function Fly:checkShotCollision(bullet)
    if self.life <= 0 or self.isAlive == false then
        return false
    end

    local radius = (bullet.radius or 1.1) + 9
    local dx = bullet.x - self.x
    local dy = bullet.y - (self.y - 7)
    return dx * dx + dy * dy < radius * radius
end

function Fly:takeDamage(damage, dx, dy)
    if self.life <= 0 or self.isAlive == false then
        return
    end

    Zombie.takeDamage(self, damage, dx, dy)
    self.damageKnockbackTimer = self.damageKnockbackDuration or 0.10
    self.damageKnockbackX, self.damageKnockbackY = normalize(dx or 0, dy or 0)
    self.state = Zombie.states.walk
end

function Fly:updateDying(dt)
    if not self.flyDying then
        return false
    end

    self.flyDeathTimer = (self.flyDeathTimer or 0) + dt
    self.glitchTimer = math.max(0, (self.glitchTimer or 0) - dt)
    self.whiteFlashTimer = math.max(0, (self.whiteFlashTimer or 0) - dt)

    if self.flyDeathTimer < FLY_DEATH_HIT_TIME then
        self.currentFrame = FLY_DEATH_HIT_FRAME
    else
        self.currentFrame = FLY_DEAD_FRAME
    end
    self.state = Zombie.states.idle

    addToDrawQueue(self.y + 2 + self.drawPriority, self)

    if self.flyDeathTimer >= FLY_DEATH_HIT_TIME + FLY_DEATH_DEAD_TIME then
        self.flyDying = false
        ZombieDeadParticle.spawnVanishBurst(self.x, self.y)
        Zombie.death(self)
    end

    return true
end

function Fly:startDying()
    if self.flyDying then
        return
    end

    self.flyDying = true
    self.flyDeathTimer = 0
    self.canDamagePlayer = false
    self.state = Zombie.states.idle
    self.currentFrame = FLY_DEATH_HIT_FRAME
    self.animationTimer = 0
end

function Fly:turnAfterCollision(collidedX, collidedY)
    if math.random() < FLY_WALL_RANDOM_TURN_CHANCE then
        self.flyDirX, self.flyDirY = randomDiagonalDirection()
        return
    end

    if collidedX then
        self.flyDirX = -(self.flyDirX or 1)
    end
    if collidedY then
        self.flyDirY = -(self.flyDirY or 1)
    end
    self.flyDirX, self.flyDirY = normalize(self.flyDirX, self.flyDirY)
end

function Fly:updateMovement(dt)
    local dirX, dirY = normalize(self.flyDirX, self.flyDirY)
    self.flyDirX, self.flyDirY = dirX, dirY

    local moveX = dirX * self.speed * dt
    local moveY = dirY * self.speed * dt

    if (self.damageKnockbackTimer or 0) > 0 then
        local duration = math.max(self.damageKnockbackDuration or 0.10, 0.001)
        local progress = math.max(0, math.min((self.damageKnockbackTimer or 0) / duration, 1))
        local knockbackSpeed = (self.damageKnockbackSpeed or 32) * progress
        moveX = moveX + (self.damageKnockbackX or 0) * knockbackSpeed * dt
        moveY = moveY + (self.damageKnockbackY or 0) * knockbackSpeed * dt
        self.damageKnockbackTimer = math.max(0, (self.damageKnockbackTimer or 0) - dt)
    end

    local collidedX, collidedY = self:isColliding(moveX, moveY)
    if not collidedX then
        self.x = self.x + moveX
    end
    if not collidedY then
        self.y = self.y + moveY
    end

    if collidedX or collidedY then
        self:turnAfterCollision(collidedX, collidedY)
    end

    if dirX > 0 and not self.flipH then
        self.flipH = true
    elseif dirX < 0 and self.flipH then
        self.flipH = false
    end
end

function Fly:playFootstepSound(playerDistance)
    self.flyWhooshTimer = self.flyWhooshTimer or 0
    if self.flyWhooshTimer > 0 then
        return true
    end

    self.flyWhooshTimer = FLY_WHOOSH_INTERVAL

    local volume = getDistanceVolume(playerDistance, 0.055, 170) * (SOUND_VOLUME or 1)
    if volume <= 0 then
        return true
    end

    local sound = flyWhooshBase:clone()
    local soundPositionX, soundPositionY = soundPosition(Player, self)
    setSourcePositionIfMono(sound, soundPositionX, soundPositionY, 0)
    setSourceVolume(sound, volume)
    sound:setPitch((1.10 + math.random() * 0.15) * (GAME_PITCH or 1))
    sound:play()
    return true
end

function Fly:update(dt)
    if self:updateDying(dt) then
        return
    end

    addToDrawQueue(self.y + 2 + self.drawPriority, self)

    if self.spawnIntroTimer and self.spawnIntroTimer > 0 then
        self.spawnIntroTimer = math.max(0, self.spawnIntroTimer - dt)
    end

    self.glitchTimer = math.max(0, (self.glitchTimer or 0) - dt)
    self.whiteFlashTimer = math.max(0, (self.whiteFlashTimer or 0) - dt)
    self.flyWhooshTimer = math.max(0, (self.flyWhooshTimer or 0) - dt)
    self.state = Zombie.states.walk
    self:animate(FLY_FLY_START_FRAME, FLY_FLY_END_FRAME, dt)

    if self.life <= 0 then
        self:startDying()
        return
    end

    self:updateMovement(dt)
end

return Fly
