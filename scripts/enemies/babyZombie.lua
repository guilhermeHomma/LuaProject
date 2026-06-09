Zombie = require("scripts/enemies/zombie")

babyZombie = setmetatable({}, {__index = Zombie})
babyZombie.__index = babyZombie
babyZombie.enemyTypeId = "babyZombie"

local damageBase = love.audio.newSource("assets/sfx/enemyDamage.mp3", "static")
local DamageStretch = require("scripts/effects/damageStretch")
local BloodPixel = require("scripts/particles/bloodPixel")
local BloodDecal = require("scripts/particles/bloodDecal")

local function playClonedSound(baseSource, volume, pitch)
    local sound = baseSource:clone()
    sound:setVolume(volume)
    sound:setPitch(pitch)
    sound:play()
    return sound
end

function babyZombie:new(x, y)
    local zombie = Zombie.new(self, x, y)
    zombie.speed = math.random(72, 83)
    zombie.damageTimer = 0.14
    zombie.totalLife = 25
    zombie.skipWalkParticles = true
    zombie.life = zombie.totalLife
    zombie.mouthVariant = "babyZombie"
    zombie.damageImpactHeightRatio = 0.58
    zombie.roamAroundPlayer = false
    zombie.pathUpdateInterval = 0.45
    zombie.pathUpdateCounter = love.math.random() * zombie.pathUpdateInterval
    return zombie
end

function babyZombie:getSprite()
    return Zombie.getSprite(self)
end

function babyZombie:getSpriteKey()
    return "assets/sprites/enemy/zombie/enemy-baby.png"
end


function babyZombie:takeDamage(damage, dx, dy)
    if self.life <= 0 or self.isAlive == false then
        return
    end

    self:spawnDamageImpact(dx, dy)
    self.lastDamageDx = dx
    self.lastDamageDy = dy
    self.life = self.life - damage
    BloodPixel.spawnBurst(self.x, self.y - 2, dx, dy, 4, 6)
    if self.life > 0 then
        BloodDecal.spawn(self.x, self.y, dx, dy, {
            scaleMultiplier = 0.5,
            volumeMultiplier = 0.5,
            pitchMultiplier = 0.72,
        })
    else
        self:spawnDeathBloodDecal()
    end

    if self:canStartDamageAnimation() then
        DamageStretch:start(self)
        self.animationTimer = 0.2
        self.state = babyZombie.states.damage
        self.stateTimer = 0
        self.kbdx = dx
        self.kbdy = dy 
        self.noise:stop()

        if self.soundTimer <= 1 then
            self.soundTimer = 1.1
        end
        playClonedSound(damageBase, 1.2, (1 + math.random() * 0.1) * GAME_PITCH)
    end
end

function babyZombie:noiseCheck(dt)
    self.soundTimer = self.soundTimer + dt

    if self.soundTimer >= (self.soundInterval or 5) and Player.isAlive then
        self.soundTimer = 0
        local soundPositionX, soundPositionY = soundPosition(Player, self)
        local playerDistance = distance(Player, self) / 2
        local volume = getDistanceVolume(playerDistance, 0.1, 180)
        self.noise:stop()
        self.noise:setPosition(soundPositionX, soundPositionY, 0)
        self.noise:setVolume(volume)
        self.noise:setPitch((2 + math.random() * 0.2) * GAME_PITCH)
        self.noise:play()
    end
end

function babyZombie:stateManager(dt, animationDuration)

    self.stateTimer = self.stateTimer + dt
    if self.stateTimer >= animationDuration then
        if self.state == babyZombie.states.idle then
            self.walkDuration = math.random(4, 6)
            self.state = babyZombie.states.walk
        elseif Player.isAlive then
            self.idleDuration = math.random(15, 20) / 100
            self.state = Zombie.states.idle
        else
            self.idleDuration = math.random(8, 14) / 10
            self.state = Zombie.states.idle
        end
        self.stateTimer = 0
    end 
end

return babyZombie
