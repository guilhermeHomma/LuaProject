local MusicList = {
    love.audio.newSource("assets/sfx/musics/intro/stairway.mp3", "stream"),
    love.audio.newSource("assets/sfx/musics/horror/midnight.mp3", "stream"),
    --love.audio.newSource("assets/sfx/musics/horror/a_horror_theme.mp3", "stream"),
    love.audio.newSource("assets/sfx/musics/default/late-song.mp3", "stream"),
}

local MusicPlayer = MusicList[1]
Music = {}

function Music:load()
    self.targetPitch = 1
    self.pitch = 1
    self.musicIndex = 1
    
    self.targetVolume = 0.8
    self.volume = 1

    MusicPlayer:setLooping(false)
    MusicPlayer:setVolume(self.volume * MUSIC_VOLUME)
end

function Music:death()
    self.volume = 1
    self.targetVolume = 1
    self.targetPitch = 1
    self.pitch = 1
    self.musicIndex = #MusicList
    self:startMusic()
end

function Music:startGame()
    self.volume = 1
    self.targetVolume = 1 
    self.targetPitch = 1
    self.pitch = 1
    self.musicIndex = 1
    self:startMusic()
    GAME_PITCH = 1
end

function Music:startMusic()
    MusicPlayer:stop()
    MusicPlayer = MusicList[self.musicIndex]
    MusicPlayer:setLooping(false)
    MusicPlayer:play()
end

function Music:changePause(isPaused)
    if isPaused then
        self.targetPitch = 0.99
        self.targetVolume = 0.1
        return
    end

    if not isPaused then 
        self.targetPitch = 1
        self.targetVolume = 0.8
    end
end

function Music:closeGame()
    self.targetVolume = 0.0
    GAME_PITCH = 1
end

function Music:update(dt)

    if state == STATES.game then
        if Player.isAlive then
            if Player.life == 1 then
                self.targetVolume = 0.0
            else 
                self.targetVolume = 1.0

            end
        end
    elseif state == STATES.gamePause then
        self.targetPitch = 0.99
        self.targetVolume = 0.1
    end

    local speed = 2
    self.pitch = self.pitch + (self.targetPitch - self.pitch) * dt * speed
    self.volume = self.volume + (self.targetVolume - self.volume) * dt * speed

    if self.volume <= 0.05 and MusicPlayer:isPlaying() then  
        MusicPlayer:stop()
    end
    
    MusicPlayer:setVolume(self.volume * MUSIC_VOLUME)
    MusicPlayer:setPitch(self.pitch  * GAME_PITCH)

    if not MusicPlayer:isPlaying() and state == STATES.game then
        self.musicIndex = self.musicIndex + 1
        if self.musicIndex > #MusicList-1 then
            self.musicIndex = 1
        end
        if Player.isAlive and Player.life > 1 then
            self:startMusic()
        end
    end

end

return Music
