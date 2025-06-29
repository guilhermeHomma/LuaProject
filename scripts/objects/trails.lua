local Trails = {}

local sprite = love.graphics.newImage("assets/sprites/trail/trail.png")

sprite:setFilter("nearest", "nearest")

function Trails:load()
    self.trails = {
        {x = -360, y=330},  -- intro show
        {x = -480, y=330},

   
        {x = -004, y=-114}, --close to the first door
        {x = -124, y=-114},

        {x = -120, y=74}, --around first area
        {x = -240, y=74},

        {x = 140, y=150}, --close to spawn



    }
end

function Trails:drawShadow()

end

function Trails:draw()

    for _, trail in ipairs(self.trails) do
        love.graphics.draw(sprite, trail.x, trail.y)
    end
end

return Trails