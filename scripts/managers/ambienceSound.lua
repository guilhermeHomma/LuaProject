
local windSound = love.audio.newSource("assets/sfx/ambience/wind-leaves.mp3", "stream")

AmbienceSound = {}

function AmbienceSound:load()
    self.targetPitch = 1
    self.pitch = 1

    self.targetVolume = 0.05
    self.volume = 0.05

    windSound:setLooping(true) 
    windSound:setVolume(self.volume)
    
end

function AmbienceSound:startGame()
    windSound:play()
end


function AmbienceSound:update(dt)

    if state == STATES.game or state == STATES.gameDead then
        self.targetPitch = 1
        self.targetVolume = 0.03
    elseif state == STATES.gamePause then
        self.targetPitch = 0.6
        self.targetVolume = 0.10
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