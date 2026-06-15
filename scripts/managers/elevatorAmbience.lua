local ElevatorAmbience = {}

local FloorManager = require("scripts/managers/floorManager")

local elevatorWoodSound = love.audio.newSource("assets/sfx/ambience/elevator-wood.mp3", "stream")

local CONFIG = {
    baseVolume = 0.30,
    highVolume = 0.40,
    transitionSpeed = 0.7,
    baseDuration = {min = 8, max = 18},
    highDuration = {min = 2, max = 4},
    highChance = 0.28,
}

local function randomRange(range)
    return (range.min or 0) + math.random() * ((range.max or range.min or 0) - (range.min or 0))
end

local function currentRoomHasElevator()
    local room = FloorManager and FloorManager.getCurrentRoom and FloorManager:getCurrentRoom() or nil
    if not (room and room.isEndRoom and Game and Game.objects) then
        return false
    end

    for _, object in ipairs(Game.objects) do
        if object and object.isAlive ~= false and object.isElevator == true then
            return true
        end
    end

    return false
end

function ElevatorAmbience:load()
    self.config = CONFIG
    self.volume = 0
    self.targetVolume = CONFIG.baseVolume
    self.stateTimer = randomRange(CONFIG.baseDuration)
    self.isHigh = false

    elevatorWoodSound:setLooping(true)
    elevatorWoodSound:setVolume(0)
    elevatorWoodSound:setPitch(1)
end

function ElevatorAmbience:silence()
    self.volume = 0
    self.targetVolume = 0
    elevatorWoodSound:setVolume(0)
    elevatorWoodSound:pause()
end

function ElevatorAmbience:pickNextState()
    self.isHigh = not self.isHigh and math.random() < (CONFIG.highChance or 0.28)
    self.targetVolume = self.isHigh and CONFIG.highVolume or CONFIG.baseVolume
    self.stateTimer = randomRange(self.isHigh and CONFIG.highDuration or CONFIG.baseDuration)
end

function ElevatorAmbience:update(dt, audible)
    local active = audible == true and state == STATES.game and currentRoomHasElevator()

    if not active then
        self.volume = 0
        elevatorWoodSound:setVolume(0)
        if elevatorWoodSound:isPlaying() then
            elevatorWoodSound:pause()
        end
        return
    end

    if not elevatorWoodSound:isPlaying() then
        elevatorWoodSound:play()
    end

    self.stateTimer = (self.stateTimer or 0) - dt
    if self.stateTimer <= 0 then
        self:pickNextState()
    end

    local targetVolume = self.targetVolume or CONFIG.baseVolume
    local speed = self.config.transitionSpeed or 0.7
    self.volume = self.volume + (targetVolume - self.volume) * math.min(dt * speed, 1)

    elevatorWoodSound:setVolume(self.volume * (SOUND_VOLUME or 1))
    elevatorWoodSound:setPitch(1)
end

return ElevatorAmbience
