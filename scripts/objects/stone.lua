local Tile = require("scripts/objects/tile")
local Stone = setmetatable({}, {__index = Tile})
Stone.__index = Stone
Stone.castsShadow = false

local sprite = love.graphics.newImage("assets/sprites/objects/stone.png")
sprite:setFilter("nearest", "nearest")
local width, height = sprite:getDimensions()
local frames = {
    love.graphics.newQuad(0, 0, 16, 32, width, height),
    love.graphics.newQuad(16, 0, 16, 32, width, height),
}

function Stone:new(x, y, variant)
    local object = Tile.new(self, x, y, 5, true)
    setmetatable(object, Stone)
    object.isStone = true
    object.variant = variant == 2 and 2 or 1
    object.isXrayBoxOccluder = true
    return object
end

function Stone:getDrawPriority()
    return self.yWorld - 0.1
end

function Stone:onshoot()
    return false
end

function Stone:draw()
    love.graphics.draw(sprite, frames[self.variant], self.xWorld, self.yWorld, 0, 1, 1, 8, 32)
end

function Stone:getXrayOccluderBox()
    return {x = self.xWorld - 8, y = self.yWorld - 32, width = 16, height = 32}
end

function Stone:drawXrayOccluder()
    self:draw()
end

return Stone
