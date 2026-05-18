Zombie = require("scripts/enemies/zombie")

babyZombie = setmetatable({}, {__index = Zombie})
babyZombie.__index = babyZombie
babyZombie.enemyTypeId = "babyZombie"

local damageBase = love.audio.newSource("assets/sfx/enemyDamage.mp3", "static")
local DamageStretch = require("scripts/effects/damageStretch")

local function playClonedSound(baseSource, volume, pitch)
    local sound = baseSource:clone()
    sound:setVolume(volume)
    sound:setPitch(pitch)
    sound:play()
    return sound
end

function babyZombie:new(x, y)
    local zombie = Zombie.new(self, x, y)
    zombie.speed = math.random(62, 79)
    zombie.damageTimer = 0.14
    zombie.totalLife = 25
    zombie.footStepAlpha = 0.3
    zombie.life = zombie.totalLife
    zombie.mouthVariant = "babyZombie"
    zombie.roamAroundPlayer = false
    return zombie
end

function babyZombie:getSprite()
    return Zombie.getSprite(self)
end

function babyZombie:getSpriteKey()
    return "assets/sprites/enemy/zombie/enemy-baby.png"
end


function babyZombie:takeDamage(damage, dx, dy)
    self.life = self.life - damage

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

    if self.soundTimer >= 10 and Player.isAlive then
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
            if not Player.isAlive then
                self.state = babyZombie.states.idle
                self.stateTimer = 0
            end
        elseif Player.isAlive then
            self.idleDuration = math.random(15, 20) / 100
            self.state = Zombie.states.idle
        end
        self.stateTimer = 0
    end 
end

return babyZombie
