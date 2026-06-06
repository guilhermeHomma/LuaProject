local MusicList = {
    menu = love.audio.newSource("assets/sfx/musics/menu/stairway.mp3", "stream"),
    florest = love.audio.newSource("assets/sfx/musics/florest/stone-stairway.mp3", "stream"),
    horror = love.audio.newSource("assets/sfx/musics/horror/midnight.mp3", "stream"),
    death = love.audio.newSource("assets/sfx/musics/death/late-song.mp3", "stream"),
}

local MusicPlayer = MusicList.menu
Music = {}

local GAME_TRACK = "florest"
local MENU_TRACK = "menu"
local HORROR_TRACK = "horror"
local DEATH_TRACK = "death"
local GAME_VOLUME_TARGET = 1.0
local MENU_VOLUME_TARGET = 1.0
local PAUSE_VOLUME_TARGET = 0.1
local FADE_IN_SPEED = 3.5
local FADE_OUT_SPEED = 3.50
local TRACK_SWITCH_FADE_OUT_SPEED = 4.1
local FLOOR_INTRO_FADE_OUT_SPEED = 4.0

local function getStateVolumeTarget()
    if state == STATES.game and Player and Player.isAlive then
        return Player.life <= 1 and 0.5 or GAME_VOLUME_TARGET
    elseif state == STATES.gamePause
        or (state == STATES.settings and Music.currentTrack ~= MENU_TRACK)
        or (state == STATES.confirm and Music.currentTrack ~= MENU_TRACK) then
        return PAUSE_VOLUME_TARGET
    elseif state == STATES.mainMenu
        or (state == STATES.settings and Music.currentTrack == MENU_TRACK)
        or (state == STATES.confirm and Music.currentTrack == MENU_TRACK) then
        return MENU_VOLUME_TARGET
    end

    return Music.targetVolume or GAME_VOLUME_TARGET
end

function Music:load()
    self.targetPitch = 1
    self.pitch = 1
    self.currentTrack = MENU_TRACK
    
    self.targetVolume = MENU_VOLUME_TARGET
    self.volume = MENU_VOLUME_TARGET
    self.battleActive = false
    self.defaultFadeInSpeed = FADE_IN_SPEED
    self.defaultFadeOutSpeed = FADE_OUT_SPEED
    self.fadeSpeedOverride = nil
    self.startDelayTimer = 0
    self.pendingTrack = nil
    self.pendingTrackTargetVolume = nil
    self.damagePitchTimer = 0
    self.damagePitchDuration = 1
    self.damagePitch = 0.58

    MusicPlayer:setLooping(true)
    MusicPlayer:setVolume(self.volume * MUSIC_VOLUME)
end

function Music:death()
    self:setBattleActive(false, true)
    self.targetVolume = 1
    self.targetPitch = 1
    self.pitch = 1
    self.damagePitchTimer = 0
    self:startMusic(DEATH_TRACK, 1)
end

function Music:startGame()
    self:setBattleActive(false, true)
    self.fadeSpeedOverride = nil
    self.pendingTrack = nil
    self.pendingTrackTargetVolume = nil
    self.volume = GAME_VOLUME_TARGET
    self.targetVolume = GAME_VOLUME_TARGET
    self.targetPitch = 1
    self.pitch = 1
    self.damagePitchTimer = 0
    self.startDelayTimer = 0
    self:switchToTrack(GAME_TRACK, GAME_VOLUME_TARGET)
    GAME_PITCH = 1
end

function Music:switchToTrack(trackName, targetVolume)
    MusicPlayer:stop()
    self.currentTrack = trackName
    MusicPlayer = MusicList[trackName] or MusicList[GAME_TRACK]
    MusicPlayer:setLooping(true)
    MusicPlayer:setVolume((self.volume or 0) * MUSIC_VOLUME)
    MusicPlayer:setPitch(self.pitch or 1)
    MusicPlayer:play()
    self.targetVolume = targetVolume or getStateVolumeTarget()
end

function Music:startMusic(trackName, targetVolume)
    trackName = trackName or GAME_TRACK
    if self.currentTrack == trackName and MusicPlayer:isPlaying() then
        if targetVolume then
            self.targetVolume = targetVolume
        end
        return
    end

    if MusicPlayer:isPlaying() and (self.volume or 0) > 0.05 then
        self.pendingTrack = trackName
        self.pendingTrackTargetVolume = targetVolume
        self.fadeSpeedOverride = TRACK_SWITCH_FADE_OUT_SPEED
        self.targetVolume = 0
        return
    end

    self.volume = 0
    self:switchToTrack(trackName, targetVolume)
end

function Music:startMenu()
    self:setBattleActive(false, true)
    self.pendingTrack = nil
    self.pendingTrackTargetVolume = nil
    self.fadeSpeedOverride = nil
    self.startDelayTimer = 0
    self.targetPitch = 1
    self.pitch = 1
    self.damagePitchTimer = 0
    self.targetVolume = MENU_VOLUME_TARGET
    if self.currentTrack ~= MENU_TRACK or not MusicPlayer:isPlaying() then
        self.volume = MENU_VOLUME_TARGET
        self:switchToTrack(MENU_TRACK, MENU_VOLUME_TARGET)
        return
    end

    self.volume = MENU_VOLUME_TARGET
    MusicPlayer:setVolume(self.volume * MUSIC_VOLUME)
end

function Music:setBattleActive(active, immediate)
    self.battleActive = false

    if state == STATES.game and Player and Player.isAlive and not MusicPlayer:isPlaying() and (self.startDelayTimer or 0) <= 0 then
        self:startMusic(self.currentTrack or GAME_TRACK)
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

    self:startMusic(active and HORROR_TRACK or GAME_TRACK, GAME_VOLUME_TARGET)
end

function Music:changePause(isPaused)
    if isPaused then
        self.targetPitch = 1
        self.targetVolume = PAUSE_VOLUME_TARGET
        return
    end

    if not isPaused then 
        self.targetPitch = 1
        self.targetVolume = GAME_VOLUME_TARGET
    end
end

function Music:startDamageDistortion(duration, pitch)
    self.damagePitchDuration = duration or 1
    self.damagePitchTimer = self.damagePitchDuration
    self.damagePitch = pitch or 0.58
    self.pitch = self.damagePitch
end

function Music:closeGame()
    self.battleActive = false
    self:setBattleActive(false)
    self.targetVolume = 0.0
    self.damagePitchTimer = 0
    GAME_PITCH = 1
end

function Music:closeForFloorIntro()
    self.fadeSpeedOverride = FLOOR_INTRO_FADE_OUT_SPEED
    self:setBattleActive(false, true)
    self.targetVolume = 0
    self.damagePitchTimer = 0
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
    local isMainMenuState = state == STATES.mainMenu
        or (state == STATES.settings and self.currentTrack == MENU_TRACK)
        or (state == STATES.confirm and self.currentTrack == MENU_TRACK)

    if isMainMenuState then
        self:startMenu()
    end

    if self.pendingTrack then
        self.targetVolume = 0
    elseif (self.startDelayTimer or 0) > 0 then
        self.startDelayTimer = math.max(0, self.startDelayTimer - dt)
        if self.startDelayTimer == 0 and state == STATES.game and Player and Player.isAlive then
            if self.currentTrack == GAME_TRACK and not MusicPlayer:isPlaying() then
                self.volume = getStateVolumeTarget()
                self:switchToTrack(GAME_TRACK, getStateVolumeTarget())
            else
                self:startMusic(self.currentTrack or GAME_TRACK, getStateVolumeTarget())
            end
        end
    end

    if self.pendingTrack then
        self.targetVolume = 0
    elseif state == STATES.game then
        if Player.isAlive then
            if Player.life <= 1 then
                self.targetVolume = 0.5
            else 
                self.targetVolume = GAME_VOLUME_TARGET

            end
        end
    elseif state == STATES.gamePause
        or (state == STATES.settings and self.currentTrack ~= MENU_TRACK)
        or (state == STATES.confirm and self.currentTrack ~= MENU_TRACK) then
        self.targetPitch = 1
        self.targetVolume = PAUSE_VOLUME_TARGET
    end

    local volumeSpeed = self.fadeSpeedOverride
        or ((self.volume < self.targetVolume) and (self.defaultFadeInSpeed or FADE_IN_SPEED) or (self.defaultFadeOutSpeed or FADE_OUT_SPEED))
    if (self.damagePitchTimer or 0) > 0 then
        self.damagePitchTimer = math.max(0, self.damagePitchTimer - dt)
        local duration = math.max(self.damagePitchDuration or 1, 0.001)
        local progress = 1 - (self.damagePitchTimer / duration)
        local eased = 1 - (1 - progress) * (1 - progress)
        local damagePitch = self.damagePitch or 0.58
        self.pitch = damagePitch + ((self.targetPitch or 1) - damagePitch) * eased
    else
        local pitchSpeed = self.fadeSpeedOverride or 4.5
        self.pitch = self.pitch + ((self.targetPitch or 1) - self.pitch) * dt * pitchSpeed
    end
    self.volume = self.volume + (self.targetVolume - self.volume) * dt * volumeSpeed
    if self.pendingTrack and self.volume <= 0.04 then
        local nextTrack = self.pendingTrack
        local nextTargetVolume = self.pendingTrackTargetVolume
        self.pendingTrack = nil
        self.pendingTrackTargetVolume = nil
        self.fadeSpeedOverride = nil
        self.volume = 0
        self:switchToTrack(nextTrack, nextTargetVolume or getStateVolumeTarget())
    elseif self.fadeSpeedOverride and math.abs((self.targetVolume or 0) - (self.volume or 0)) <= 0.02 then
        self.volume = self.targetVolume or 0
        self.fadeSpeedOverride = nil
    end

    if state ~= STATES.game then
        self.battleActive = false
    end

    local keepGameMusicAlive = state == STATES.game and Player and Player.isAlive
    local keepMenuMusicAlive = (state == STATES.mainMenu
        or (state == STATES.settings and self.currentTrack == MENU_TRACK)
        or (state == STATES.confirm and self.currentTrack == MENU_TRACK))
        and (self.currentTrack == MENU_TRACK or self.pendingTrack == MENU_TRACK)
    local keepDeathMusicAlive = state == STATES.gameDead
        and (self.currentTrack == DEATH_TRACK or self.pendingTrack == DEATH_TRACK)
    if self.volume <= 0.05 and MusicPlayer:isPlaying() and not (keepGameMusicAlive or keepMenuMusicAlive or keepDeathMusicAlive) then
        MusicPlayer:stop()
    end
    
    MusicPlayer:setVolume(self.volume * MUSIC_VOLUME)
    MusicPlayer:setPitch(self.pitch)

    if not MusicPlayer:isPlaying() and state == STATES.game and (self.startDelayTimer or 0) <= 0 then
        if Player.isAlive then
            self:startMusic(self.currentTrack or GAME_TRACK, getStateVolumeTarget())
        end
    end

end

return Music
