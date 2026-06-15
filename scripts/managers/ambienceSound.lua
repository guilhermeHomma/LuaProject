local AmbienceWind = require("scripts/managers/ambienceWind")
local AmbienceEvents = require("scripts/managers/ambienceEvents")
local ElevatorAmbience = require("scripts/managers/elevatorAmbience")

AmbienceSound = {}

local function isAudibleState()
    return state == STATES.game
        or state == STATES.gameDead
        or state == STATES.floorIntro
        or state == STATES.mainMenu
        or state == STATES.gameIntro
        or state == STATES.gamePause
end

function AmbienceSound:load()
    AmbienceWind:load()
    AmbienceEvents:load()
    ElevatorAmbience:load()
end

function AmbienceSound:startGame()
    AmbienceWind:start()
end

function AmbienceSound:silence()
    AmbienceWind:silence()
    ElevatorAmbience:silence()
end

function AmbienceSound:startWindBoost(duration, multiplier)
    AmbienceWind:startBoost(duration, multiplier)
end

function AmbienceSound:getWindMotionMultiplier()
    return AmbienceWind:getMotionMultiplier()
end

function AmbienceSound:playCricketSound()
    AmbienceEvents:play("cricket")
end

function AmbienceSound:playCrowSound()
    AmbienceEvents:play("crow")
end

function AmbienceSound:playOwlSound()
    AmbienceEvents:play("owl")
end

function AmbienceSound:updateRandomEvents(dt)
    AmbienceEvents:update(dt)
end

function AmbienceSound:update(dt)
    local audible = isAudibleState()
    AmbienceWind:update(dt, audible)
    ElevatorAmbience:update(dt, audible)
end

return AmbienceSound
