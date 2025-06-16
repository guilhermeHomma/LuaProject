local GameIntro = {}

local Camera = require("scripts/camera")
local Ground = require("scripts/ground")
local Clouds = require("scripts/clouds")
local Tilemap = require("scripts/tilemap")
local font = love.graphics.newFont("assets/fonts/ThaleahFat.ttf", 80)
font:setFilter("nearest", "nearest")


camera = nil
local target = {x = -330, y = 330}
function GameIntro:load()
    
    math.randomseed(os.time())
    love.graphics.setDefaultFilter("nearest", "nearest")
    camera = Camera:new(target.x, target.y-10, target)

    Ground:load()
    Clouds:load(target)
    Tilemap:load()

    self.drawQueue = {}

    self.timer = 0
    self.changed = false
    self.playedCrowSound = false
    AmbienceSound:playCricketSound()
end


function GameIntro:close()
    self = {}
end

function GameIntro:update(dt)
    self.drawQueue = {}
    self.timer = self.timer + dt
    local targetPitch = 1

    target.x = target.x + 0.7 * dt
    target.y = target.y - 1 * dt

    Clouds:update(dt)

    Tilemap:update(dt)

    camera:update(dt)

    if self.timer > 2 and not self.playedCrowSound then
        AmbienceSound:playCrowSound()
        self.playedCrowSound = true
    end

    if self.timer > 7 and not self.changed then
        
        loadGame()
        self:close()
        self.changed = true
    end
end

function GameIntro:draw()
    camera:attach()

    love.graphics.scale(3, YSCALE) 

    Ground:draw(target)
    
    table.sort(self.drawQueue, function(a, b) return a.priority < b.priority end)
    Clouds:drawShadow()

    for _, item in ipairs(self.drawQueue) do
        if type(item.object.drawShadow) == "function" then
            item.object:drawShadow()
        end
    end

    for _, item in ipairs(self.drawQueue) do
        local d = distance(camera:objectPosition(), item.object)

        local minDist = 20
        local maxDist = 200

        local minDist = 110
        local maxDist = 260

        local t = math.min(math.max((d - minDist) / (maxDist - minDist), 0), 1)
        local brightness = 1 - t * 0.8
        local r, g, b, a = 1,1,1,1
        --love.graphics.setColor(r * brightness, g * brightness, b * brightness, a)
        item.object:draw()
        love.graphics.setColor(r, g, b, a)
    end
    local text = "Mobize"

    love.graphics.setFont(font)
    local textWidth = font:getWidth(text)
    love.graphics.print(text, target.x - textWidth/2, target.y -50)
    Clouds:draw()
    
    love.graphics.scale(1, 1)
    
    camera:detach()
    
end

return GameIntro