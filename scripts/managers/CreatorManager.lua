local CreatorManager = {}
require "scripts/utils"
local Creator = require("scripts/creator/creator_1")

function CreatorManager:load()
    Creator:load()
end

function CreatorManager:update(dt)
    Creator:update(dt)
end


function CreatorManager:keypressed(key)
    if key ~= "f" then return end
    
    Creator:keypressed(key)
    
end

return CreatorManager
