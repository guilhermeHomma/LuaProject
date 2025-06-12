Zombie = require("scripts/enemies/zombie")

BigZombie = setmetatable({}, {__index = Zombie})
BigZombie.__index = BigZombie

function BigZombie:new(x, y)
    local zombie = Zombie.new(self, x, y)
    zombie.speed = math.random(33, 40)
    zombie.damageTimer = 0.1
    zombie.dropPoints = 25
    zombie.totalLife = 70
    zombie.life = zombie.totalLife
    return zombie
end

function BigZombie:getSprite()
    return love.graphics.newImage("assets/sprites/enemy/enemy-big.png")
end


function BigZombie:takeDamage(damage, dx, dy)
    self.animationTimer = 0.3
    self.state = BigZombie.states.damage
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

function BigZombie:drawMouth()
    
end

function BigZombie:noiseCheck(dt)
    self.soundTimer = self.soundTimer + dt
    if self.soundTimer >= 10 and Player.isAlive then
        self.soundTimer = 0
        local soundPositionX, soundPositionY = soundPosition(Player, self)

        self.noise:setPosition(soundPositionX, soundPositionY, 0)
        self.noise:setVolume(1)
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