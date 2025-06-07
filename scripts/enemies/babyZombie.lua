Zombie = require("scripts/enemies/zombie")

babyZombie = setmetatable({}, {__index = Zombie})
babyZombie.__index = babyZombie

function babyZombie:new(x, y)
    local zombie = Zombie.new(self, x, y)
    zombie.speed = math.random(53, 57)
    zombie.damageTimer = 0.1
    zombie.dropPoints = 15
    zombie.totalLife = 35
    zombie.life = zombie.totalLife
    return zombie
end

function babyZombie:getSprite()
    return love.graphics.newImage("assets/sprites/enemy/enemy-baby.png")
end


function babyZombie:takeDamage(damage, dx, dy)
    self.animationTimer = 0.2
    self.state = babyZombie.states.damage
    self.stateTimer = 0
    self.kbdx = dx
    self.kbdy = dy 
    self.life = self.life - damage
    self.noise:stop()

    if self.soundTimer <= 1 then
        self.soundTimer = 1.1
    end

    local bulletSound = love.audio.newSource("assets/sfx/enemyDamage.mp3", "static")
    bulletSound:setVolume(2)
    bulletSound:setPitch((0.6 + math.random() * 0.1) * GAME_PITCH)
    bulletSound:play()
end

function babyZombie:drawMouth()
    
end

function babyZombie:noiseCheck(dt)
    self.soundTimer = self.soundTimer + dt
    if self.soundTimer >= 10 and Player.isAlive then
        self.soundTimer = 0
        local soundPositionX, soundPositionY = soundPosition(Player, self)

        self.noise:setPosition(soundPositionX, soundPositionY, 0)
        self.noise:setVolume(1)
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
            self.idleDuration = math.random(0.15, 0.2)
            self.state = Zombie.states.idle
        end
        self.stateTimer = 0
    end 
end

return babyZombie