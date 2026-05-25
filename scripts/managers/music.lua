local MusicList = {
    love.audio.newSource("assets/sfx/musics/intro/stairway.mp3", "stream"),
    love.audio.newSource("assets/sfx/musics/horror/midnight.mp3", "stream"),
    --love.audio.newSource("assets/sfx/musics/horror/a_horror_theme.mp3", "stream"),
    love.audio.newSource("assets/sfx/musics/default/late-song.mp3", "stream"),
}

local MusicPlayer = MusicList[1]
local BattleMusicPlayer = love.audio.newSource("assets/sfx/musics/enemies/enemiesbeat.mp3", "stream")
Music = {}

function Music:load()
    self.targetPitch = 1
    self.pitch = 1
    self.musicIndex = 1
    
    self.targetVolume = 0.8
    self.volume = 1
    self.battleVolume = 0
    self.battleTargetVolume = 0
    self.battleActive = false
    self.defaultBattleVolume = 0.05
    self.defaultFadeInSpeed = 0.65
    self.battleMaxVolume = 0.72
    self.battleFadeInSpeed = 4.5
    self.battleFadeOutSpeed = 2.2
    self.fadeSpeedOverride = nil

    MusicPlayer:setLooping(false)
    MusicPlayer:setVolume(self.volume * MUSIC_VOLUME)
    BattleMusicPlayer:setLooping(true)
    BattleMusicPlayer:setVolume(0)
end

function Music:death()
    self:setBattleActive(false, true)
    self.volume = 1
    self.targetVolume = 1
    self.targetPitch = 1
    self.pitch = 1
    self.musicIndex = #MusicList
    self:startMusic()
end

function Music:startGame()
    self:setBattleActive(false, true)
    self.fadeSpeedOverride = nil
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
    MusicPlayer:setVolume((self.volume or 1) * MUSIC_VOLUME)
    MusicPlayer:setPitch((self.pitch or 1) * GAME_PITCH)
    MusicPlayer:play()
end

function Music:setBattleActive(active, immediate)
    active = active == true
    self.battleVolume = self.battleVolume or 0
    self.battleMaxVolume = self.battleMaxVolume or 0.72
    local target = active and self.battleMaxVolume or 0
    self.battleActive = active
    self.battleTargetVolume = target
    self.targetVolume = active and (self.defaultBattleVolume or 0.05) or 1

    if active and not BattleMusicPlayer:isPlaying() then
        BattleMusicPlayer:setLooping(true)
        BattleMusicPlayer:setVolume(0)
        BattleMusicPlayer:setPitch((self.pitch or 1) * GAME_PITCH)
        BattleMusicPlayer:play()
    end

    if not active and state == STATES.game and Player and Player.isAlive and not MusicPlayer:isPlaying() then
        self:startMusic()
    end

    if immediate then
        self.battleVolume = target
        self.volume = active and (self.defaultBattleVolume or 0.05) or (self.targetVolume or 1)
        MusicPlayer:setVolume(self.volume * MUSIC_VOLUME)
        BattleMusicPlayer:setVolume(self.battleVolume * MUSIC_VOLUME)
        if target <= 0 and BattleMusicPlayer:isPlaying() then
            BattleMusicPlayer:stop()
        end
    end
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
    self.fadeSpeedOverride = 18
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

    if state == STATES.game then
        if self.battleActive then
            self.targetVolume = self.defaultBattleVolume or 0.05
        elseif Player.isAlive then
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

    local volumeSpeed = self.fadeSpeedOverride or ((not self.battleActive and self.volume < self.targetVolume) and (self.defaultFadeInSpeed or 0.65) or 2)
    local pitchSpeed = self.fadeSpeedOverride or 2
    self.pitch = self.pitch + (self.targetPitch - self.pitch) * dt * pitchSpeed
    self.volume = self.volume + (self.targetVolume - self.volume) * dt * volumeSpeed
    if self.fadeSpeedOverride and math.abs((self.targetVolume or 0) - (self.volume or 0)) <= 0.02 then
        self.volume = self.targetVolume or 0
        self.fadeSpeedOverride = nil
    end

    if state ~= STATES.game then
        self.battleActive = false
        self.battleTargetVolume = 0
    end

    local battleFadeSpeed = self.battleTargetVolume > self.battleVolume and self.battleFadeInSpeed or self.battleFadeOutSpeed
    self.battleVolume = self.battleVolume + (self.battleTargetVolume - self.battleVolume) * dt * battleFadeSpeed

    local keepGameMusicAlive = state == STATES.game and Player and Player.isAlive
    if self.volume <= 0.05 and MusicPlayer:isPlaying() and not keepGameMusicAlive then
        MusicPlayer:stop()
    end
    
    MusicPlayer:setVolume(self.volume * MUSIC_VOLUME)
    MusicPlayer:setPitch(self.pitch  * GAME_PITCH)

    if self.battleVolume > 0.01 or self.battleTargetVolume > 0 then
        if not BattleMusicPlayer:isPlaying() then
            BattleMusicPlayer:play()
        end
        BattleMusicPlayer:setVolume(self.battleVolume * MUSIC_VOLUME)
        BattleMusicPlayer:setPitch(self.pitch * GAME_PITCH)
    elseif BattleMusicPlayer:isPlaying() then
        BattleMusicPlayer:stop()
    end

    if not MusicPlayer:isPlaying() and state == STATES.game and not self.battleActive then
        self.musicIndex = self.musicIndex + 1
        if self.musicIndex > #MusicList-1 then
            self.musicIndex = 1
        end
        if Player.isAlive then
            self:startMusic()
        end
    end

end

return Music
