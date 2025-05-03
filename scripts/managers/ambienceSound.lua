
local windSound = love.audio.newSource("assets/sfx/ambience/wind-leaves.mp3", "stream")

AmbienceSound = {}

function AmbienceSound:load()
    windSound:setLooping(true) 
    windSound:setVolume(0.05)
    windSound:play()
end

function AmbienceSound:update(dt)


end

return AmbienceSound