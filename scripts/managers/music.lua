local MusicList = {
    stairway = love.audio.newSource("assets/sfx/musics/intro/stairway.mp3", "stream"),
    horror = love.audio.newSource("assets/sfx/musics/horror/midnight.mp3", "stream"),
    death = love.audio.newSource("assets/sfx/musics/default/late-song.mp3", "stream"),
}

local MusicPlayer = MusicList.stairway
Music = {}

function Music:load()
    self.targetPitch = 1
    self.pitch = 1
    self.currentTrack = "stairway"
    
    self.targetVolume = 0.8
    self.volume = 1
    self.battleActive = false
    self.defaultFadeInSpeed = 0.65
    self.fadeSpeedOverride = nil
    self.startDelayTimer = 0

    MusicPlayer:setLooping(true)
    MusicPlayer:setVolume(self.volume * MUSIC_VOLUME)
end

function Music:death()
    self:setBattleActive(false, true)
    self.volume = 1
    self.targetVolume = 1
    self.targetPitch = 1
    self.pitch = 1
    self:startMusic("death")
end

function Music:startGame()
    self:setBattleActive(false, true)
    self.fadeSpeedOverride = nil
    self.volume = 1
    self.targetVolume = 1 
    self.targetPitch = 1
    self.pitch = 1
    self.startDelayTimer = 1
    self.currentTrack = "stairway"
    if MusicPlayer:isPlaying() then
        MusicPlayer:stop()
    end
    GAME_PITCH = 1
end

function Music:startMusic(trackName)
    trackName = trackName or "stairway"
    if self.currentTrack == trackName and MusicPlayer:isPlaying() then
        return
    end

    MusicPlayer:stop()
    self.currentTrack = trackName
    MusicPlayer = MusicList[trackName] or MusicList.stairway
    MusicPlayer:setLooping(true)
    MusicPlayer:setVolume((self.volume or 1) * MUSIC_VOLUME)
    MusicPlayer:setPitch((self.pitch or 1) * GAME_PITCH)
    MusicPlayer:play()
end

function Music:setBattleActive(active, immediate)
    self.battleActive = false

    if state == STATES.game and Player and Player.isAlive and not MusicPlayer:isPlaying() and (self.startDelayTimer or 0) <= 0 then
        self:startMusic(self.currentTrack or "stairway")
    end

    if immediate then
        self.volume = self.targetVolume or 1
        MusicPlayer:setVolume(self.volume * MUSIC_VOLUME)
    end
end

function Music:setShopOrChestRoomActive(active)
    if not (state == STATES.game and Player and Player.isAlive) then
        return
    end

    self:startMusic(active and "horror" or "stairway")
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
    self.battleActive = false
    self:setBattleActive(false)
    self.targetVolume = 0.0
    GAME_PITCH = 1
end

function Music:closeForFloorIntro()
    self.fadeSpeedOverride = 5
    self:setBattleActive(false, true)
    self.targetVolume = 0
    GAME_PITCH = 1
end

function Music:finishFloorIntroFade()
    self.volume = 0
    self.targetVolume = 0
    self.fadeSpeedOverride = nil
    if MusicPlayer:isPlaying() then
        MusicPlayer:stop()
    end
    self:setBattleActive(false, true)
    self.volume = 0
    self.targetVolume = 0
end

function Music:update(dt)
    if (self.startDelayTimer or 0) > 0 then
        self.startDelayTimer = math.max(0, self.startDelayTimer - dt)
        if self.startDelayTimer == 0 and state == STATES.game and Player and Player.isAlive then
            self:startMusic(self.currentTrack or "stairway")
        end
    end

    if state == STATES.game then
        if Player.isAlive then
            if Player.life <= 1 then
                self.targetVolume = 0.5
            else 
                self.targetVolume = 1.0

            end
        end
    elseif state == STATES.gamePause then
        self.targetPitch = 0.99
        self.targetVolume = 0.1
    end

    local volumeSpeed = self.fadeSpeedOverride or ((self.volume < self.targetVolume) and (self.defaultFadeInSpeed or 0.65) or 2)
    local pitchSpeed = self.fadeSpeedOverride or 2
    self.pitch = self.pitch + (self.targetPitch - self.pitch) * dt * pitchSpeed
    self.volume = self.volume + (self.targetVolume - self.volume) * dt * volumeSpeed
    if self.fadeSpeedOverride and math.abs((self.targetVolume or 0) - (self.volume or 0)) <= 0.02 then
        self.volume = self.targetVolume or 0
        self.fadeSpeedOverride = nil
    end

    if state ~= STATES.game then
        self.battleActive = false
    end

    local keepGameMusicAlive = state == STATES.game and Player and Player.isAlive
    if self.volume <= 0.05 and MusicPlayer:isPlaying() and not keepGameMusicAlive then
        MusicPlayer:stop()
    end
    
    MusicPlayer:setVolume(self.volume * MUSIC_VOLUME)
    MusicPlayer:setPitch(self.pitch  * GAME_PITCH)

    if not MusicPlayer:isPlaying() and state == STATES.game and (self.startDelayTimer or 0) <= 0 then
        if Player.isAlive then
            self:startMusic(self.currentTrack or "stairway")
        end
    end

end

return Music
