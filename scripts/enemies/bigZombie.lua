Zombie = require("scripts/enemies/zombie")

BigZombie = setmetatable({}, {__index = Zombie})
BigZombie.__index = BigZombie
BigZombie.enemyTypeId = "bigZombie"

local damageBase = love.audio.newSource("assets/sfx/enemyDamage.mp3", "static")
local DamageStretch = require("scripts/effects/damageStretch")
local BloodPixel = require("scripts/particles/bloodPixel")

local function playClonedSound(baseSource, volume, pitch)
    local sound = baseSource:clone()
    sound:setVolume(volume)
    sound:setPitch(pitch)
    sound:play()
    return sound
end

function BigZombie:new(x, y)
    local zombie = Zombie.new(self, x, y)
    zombie.speed = math.random(43, 47)
    zombie.damageTimer = 0.14
    zombie.totalLife = 50
    zombie.life = zombie.totalLife
    zombie.footStepAlpha = 0.7
    zombie.roamAroundPlayer = false
    return zombie
end

function BigZombie:getSprite()
    return Zombie.getSprite(self)
end

function BigZombie:getSpriteKey()
    return "assets/sprites/enemy/zombie/enemy-big.png"
end

function BigZombie:takeDamage(damage, dx, dy)
    self.life = self.life - damage
    BloodPixel.spawnBurst(self.x, self.y - 2, dx, dy, 4, 6)

    if self:canStartDamageAnimation() then
        DamageStretch:start(self)
        self.animationTimer = 0.3
        self.state = BigZombie.states.damage
        self.stateTimer = 0
        self.kbdx = dx
        self.kbdy = dy 
        self.noise:stop()
        
        if self.soundTimer <= 1 then
            self.soundTimer = 1.1
        end
        playClonedSound(damageBase, 1.2, (0.9 + math.random() * 0.1) * GAME_PITCH)
    end
end

function BigZombie:drawMouth()
    
end

function BigZombie:noiseCheck(dt)
    self.soundTimer = self.soundTimer + dt

    if self.soundTimer >= 10 and Player.isAlive then
        self.soundTimer = 0
        local soundPositionX, soundPositionY = soundPosition(Player, self)
        local playerDistance = distance(Player, self) / 2
        local volume = getDistanceVolume(playerDistance, 0.2, 180)
        self.noise:stop()
        self.noise:setPosition(soundPositionX, soundPositionY, 0)
        self.noise:setVolume(volume)
        self.noise:setPitch((0.75 + math.random() * 0.2) * GAME_PITCH)
        self.noise:play()
    end
end

function BigZombie:stateManager(dt, animationDuration)

    self.stateTimer = self.stateTimer + dt
    if self.stateTimer >= animationDuration then
        if self.state == BigZombie.states.idle then
            self.walkDuration = math.random(4, 6)
            self.state = BigZombie.states.walk
            if not Player.isAlive then
                self.state = BigZombie.states.idle
                self.stateTimer = 0
            end
        elseif Player.isAlive then
            self.idleDuration = math.random(10, 15) / 100
            self.state = Zombie.states.idle
        end
        self.stateTimer = 0
    end 
end

return BigZombie
