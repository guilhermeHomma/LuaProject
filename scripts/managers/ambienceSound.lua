
local windSound = love.audio.newSource("assets/sfx/ambience/wind-leaves.mp3", "stream")

AmbienceSound = {}

function AmbienceSound:load()
    self.targetPitch = 1
    self.pitch = 1

    self.targetVolume = 0.1
    self.volume = 0.05

    windSound:setLooping(true) 
    windSound:setVolume(self.volume)
    
end

function AmbienceSound:startGame()
    windSound:play()
end


function AmbienceSound:playCricketSound()

    
    local sound = love.audio.newSource("assets/sfx/ambience/cricket.mp3", "static")

    sound:setVolume(0.05 + math.random() * 0.03)
    sound:setPitch((1 + math.random() * 0.1) * GAME_PITCH)
    sound:play()
end

function AmbienceSound:playCrowSound()

    
    local sound = love.audio.newSource("assets/sfx/ambience/crow.mp3", "static")
    if math.random() > 0.5 then 
        sound = love.audio.newSource("assets/sfx/ambience/crow2.mp3", "static")
    end

    sound:setVolume(0.04 + math.random() * 0.01)
    sound:setPitch((0.9 + math.random() * 0.1) * GAME_PITCH)


    local max_distance = 1
    local angle = math.random() * (2 * math.pi) 
    local distance = math.random() * max_distance * 0.7 + max_distance * 0.3
    local x = math.cos(angle) * distance
    local y = math.sin(angle) * distance
    sound:setPosition(x, 0.4, y)

    sound:play()
end

function AmbienceSound:update(dt)
    if state == STATES.game or state == STATES.gameDead or state == STATES.mainMenu or state == STATES.gameIntro then
        self.targetPitch = 1
        self.targetVolume = 0.1
    elseif state == STATES.gamePause then
        self.targetPitch = 0.6
        self.targetVolume = 0.1
    else
        self.targetVolume = 0.0
    end

    local speed = 2
    self.pitch = self.pitch + (self.targetPitch - self.pitch) * dt * speed
    self.volume = self.volume + (self.targetVolume - self.volume) * dt * speed

    windSound:setVolume(self.volume)
    windSound:setPitch(self.pitch)

end

return AmbienceSound