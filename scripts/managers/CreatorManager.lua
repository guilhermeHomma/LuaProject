local CreatorManager = {}
require "scripts/utils"
local Creator = require("scripts/creator/creator_1")

function CreatorManager:load()
    Creator:load()
end

function CreatorManager:update(dt)
    Creator:update(dt)
end

function CreatorManager:draw()
    
end

return CreatorManager