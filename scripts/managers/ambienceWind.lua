local AmbienceWind = {}

local FloorManager = require("scripts/managers/floorManager")

local windSound = love.audio.newSource("assets/sfx/ambience/wind-leaves.mp3", "stream")

local CONFIG = {
    baseVolume = 0.10,
    endRoomVolumeMultiplier = 1.10,
    transitionSpeed = 0.55,
    states = {
        low = {
            volume = 0.05,
            motionMultiplier = 0.70,
            intensityMultiplier = 0.55,
            duration = {min = 10, max = 30},
            weight = 3,
        },
        base = {
            volume = 0.10,
            motionMultiplier = 1.00,
            intensityMultiplier = 0.80,
            duration = {min = 10, max = 30},
            weight = 5,
        },
        high = {
            volume = 0.15,
            motionMultiplier = 1.20,
            intensityMultiplier = 1.20,
            duration = {min = 2, max = 4},
            weight = 2,
        },
    },
}

local function randomRange(range)
    return (range.min or 0) + math.random() * ((range.max or range.min or 0) - (range.min or 0))
end

local function getRoomVolumeMultiplier()
    local room = FloorManager and FloorManager.getCurrentRoom and FloorManager:getCurrentRoom() or nil
    if room and room.isEndRoom then
        return CONFIG.endRoomVolumeMultiplier or 1.10
    end

    return 1
end

local function chooseState()
    local total = 0
    for _, stateConfig in pairs(CONFIG.states) do
        total = total + (stateConfig.weight or 1)
    end

    local roll = math.random() * total
    for stateName, stateConfig in pairs(CONFIG.states) do
        roll = roll - (stateConfig.weight or 1)
        if roll <= 0 then
            return stateName, stateConfig
        end
    end

    return "base", CONFIG.states.base
end

function AmbienceWind:load()
    self.config = CONFIG
    self.stateName = "base"
    self.stateTimer = randomRange(CONFIG.states.base.duration)
    self.volume = CONFIG.baseVolume
    self.motionMultiplier = 1
    self.intensityMultiplier = CONFIG.states.base.intensityMultiplier or 1
    self.targetVolume = self.volume
    self.targetMotionMultiplier = self.motionMultiplier
    self.targetIntensityMultiplier = self.intensityMultiplier
    self.time = 0

    windSound:setLooping(true)
    setSourceVolume(windSound, self.volume)
    windSound:setPitch(1)
    WIND_AMBIENCE_MULTIPLIER = self.motionMultiplier
    WIND_AMBIENCE_INTENSITY = self.intensityMultiplier
    WIND_AMBIENCE_TIME = self.time
end

function AmbienceWind:start()
    if not windSound:isPlaying() then
        windSound:play()
    end
end

function AmbienceWind:silence()
    self.targetVolume = 0
    self.volume = 0
    setSourceVolume(windSound, 0)
end

function AmbienceWind:pickNextState()
    local stateName, stateConfig = chooseState()
    self.stateName = stateName
    self.stateTimer = randomRange(stateConfig.duration)
    self.targetVolume = stateConfig.volume or CONFIG.baseVolume
    self.targetMotionMultiplier = stateConfig.motionMultiplier or 1
    self.targetIntensityMultiplier = stateConfig.intensityMultiplier or 1
end

function AmbienceWind:update(dt, audible)
    self.stateTimer = (self.stateTimer or 0) - dt
    if self.stateTimer <= 0 then
        self:pickNextState()
    end

    local targetVolume = audible and (self.targetVolume or CONFIG.baseVolume) * getRoomVolumeMultiplier() or 0
    local speed = self.config.transitionSpeed or 0.55
    self.volume = self.volume + (targetVolume - self.volume) * math.min(dt * speed, 1)
    self.motionMultiplier = self.motionMultiplier
        + ((self.targetMotionMultiplier or 1) - self.motionMultiplier) * math.min(dt * speed, 1)
    self.intensityMultiplier = self.intensityMultiplier
        + ((self.targetIntensityMultiplier or 1) - self.intensityMultiplier) * math.min(dt * speed, 1)
    self.time = (self.time or 0) + dt * (self.motionMultiplier or 1)

    WIND_AMBIENCE_MULTIPLIER = self.motionMultiplier
    WIND_AMBIENCE_INTENSITY = self.intensityMultiplier
    WIND_AMBIENCE_TIME = self.time

    setSourceVolume(windSound, self.volume * (SOUND_VOLUME or 1))
    windSound:setPitch(1)
end

function AmbienceWind:startBoost(duration, multiplier)
    self.stateName = "high"
    self.stateTimer = duration or randomRange(CONFIG.states.high.duration)
    self.targetVolume = CONFIG.states.high.volume
    self.targetMotionMultiplier = multiplier or CONFIG.states.high.motionMultiplier
    self.targetIntensityMultiplier = multiplier or CONFIG.states.high.intensityMultiplier
end

function AmbienceWind:getMotionMultiplier()
    return self.motionMultiplier or 1
end

function AmbienceWind:getIntensityMultiplier()
    return self.intensityMultiplier or 1
end

return AmbienceWind
