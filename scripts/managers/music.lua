


local MusicPlayer = love.audio.newSource("assets/sfx/musics/intro/stairway.wav", "stream")

Music = {}

function Music:load()
    self.targetPitch = 1
    self.pitch = 1

    
    self.targetVolume = 0.8
    self.volume = 1

    MusicPlayer:setLooping(false) 
    MusicPlayer:setVolume(self.volume)
end


function Music:startGame()
    self.volume = 1
    self.targetVolume = 1
    self.targetPitch = 1
    self.pitch = 1
    MusicPlayer = love.audio.newSource("assets/sfx/musics/intro/stairway.wav", "stream")
    MusicPlayer:setLooping(false) 
    MusicPlayer:play()
end

function Music:update(dt)

    if state == STATES.game then
        self.targetPitch = 1
        self.targetVolume = 0.8

    elseif state == STATES.gamePause then
        self.targetPitch = 0.7
        self.targetVolume = 0.1

    else
        self.targetVolume = 0.0
    end

    local speed = 2
    self.pitch = self.pitch + (self.targetPitch - self.pitch) * dt * speed
    self.volume = self.volume + (self.targetVolume - self.volume) * dt * speed

    MusicPlayer:setVolume(self.volume)
    MusicPlayer:setPitch(self.pitch)

end

return Music