
local FloorManager = require("scripts/managers/floorManager")
local windSound = love.audio.newSource("assets/sfx/ambience/wind-leaves.mp3", "stream")

local function isCurrentRoomCave()
    local theme = FloorManager.getCurrentRoomTheme and FloorManager:getCurrentRoomTheme() or nil
    return theme and theme.id == "cave"
end

AmbienceSound = {}

function AmbienceSound:load()
    self.targetPitch = 1
    self.pitch = 1

    self.targetVolume = 0.1
    self.volume = 0.05
    self.windBoostTimer = 0
    self.windBoostDuration = 0
    self.windBoostMultiplier = 2

    windSound:setLooping(true) 
    windSound:setVolume(self.volume)
    
end

function AmbienceSound:startGame()
    windSound:play()
end

function AmbienceSound:silence()
    self.targetVolume = 0
    self.volume = 0
    self.windBoostTimer = 0
    windSound:setVolume(0)
end

function AmbienceSound:startWindBoost(duration, multiplier)
    self.windBoostDuration = duration or 1
    self.windBoostTimer = self.windBoostDuration
    self.windBoostMultiplier = multiplier or 2
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
    if state == STATES.game or state == STATES.gameDead or state == STATES.floorIntro or state == STATES.mainMenu or state == STATES.gameIntro then
        self.targetPitch = (state == STATES.game or state == STATES.gameDead or state == STATES.floorIntro) and isCurrentRoomCave() and 0.72 or 1
        self.targetVolume = 0.1
    elseif state == STATES.gamePause then
        self.targetPitch = isCurrentRoomCave() and 0.52 or 0.6
        self.targetVolume = 0.1
    else
        self.targetVolume = 0.0
    end

    local baseTargetVolume = self.targetVolume
    if (self.windBoostTimer or 0) > 0 then
        self.windBoostTimer = math.max(0, self.windBoostTimer - dt)
        local duration = math.max(self.windBoostDuration or 1, 0.001)
        local progress = self.windBoostTimer / duration
        local boostMultiplier = 1 + ((self.windBoostMultiplier or 2) - 1) * progress
        self.targetVolume = baseTargetVolume * boostMultiplier
    end

    local speed = (self.windBoostTimer or 0) > 0 and 6 or 2
    self.pitch = self.pitch + (self.targetPitch - self.pitch) * dt * speed
    self.volume = self.volume + (self.targetVolume - self.volume) * dt * speed

    windSound:setVolume(self.volume)
    windSound:setPitch(self.pitch)

end

return AmbienceSound
