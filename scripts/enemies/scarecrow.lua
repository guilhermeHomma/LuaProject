require("scripts/utils")

local Scarecrow = {}
Scarecrow.__index = Scarecrow


function Scarecrow:new(x, y)
    local scarecrow = setmetatable({}, Scarecrow)
    scarecrow.x = x
    scarecrow.y = y
    scarecrow.totalLife = 50
    scarecrow.life = scarecrow.totalLife
    return
end

function Scarecrow:collisionBox(x, y, size)
    if not x then x = self.x end
    if not y then y = self.y end
    if not size then size = 4 end

    return {x = x - size/2, y = y - size/2, width = size, height = size}
end


function Scarecrow:update(dt)
    self:death()
end

function Scarecrow:draw()

end