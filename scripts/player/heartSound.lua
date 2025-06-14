

local HeartSound = {}
soundPlayer = love.audio.newSource("assets/sfx/player/heart.mp3", "stream")
local TransitionManager = require("scripts.managers.transitionManager")

function HeartSound:load()    
    soundPlayer:stop()
    soundPlayer:setLooping(false) 
    soundPlayer:setVolume(0.7)

end

function HeartSound:stop()
    soundPlayer:stop()
end

function HeartSound:update(dt)
    if not Player.isAlive then 
        if soundPlayer:isPlaying() then
            self:stop()
        end
        return 
    end

    if state ~= STATES.game then 
        self:stop()
    end
    
    if Player.life == 1 then 
        soundPlayer:setVolume(0.5)
    elseif Player.life == 2 then
        soundPlayer:setVolume(0.1)
    else 
        self:stop()
    end
    
    if not soundPlayer:isPlaying() and (Player.life == 1 or Player.life == 2) and state == STATES.game then
        if Player.life == 1 then
            TransitionManager:setDistortion(0.4)
        else
            TransitionManager:setDistortion(0.1)
        end
        soundPlayer:play()
    end
end

return HeartSound