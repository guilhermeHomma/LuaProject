local Tile = require("scripts/objects/tile")
local Tombstone = setmetatable({}, {__index = Tile})
Tombstone.__index = Tombstone
Tombstone.castsShadow = false

local sprite = love.graphics.newImage("assets/sprites/objects/tombstone.png")
sprite:setFilter("nearest", "nearest")
local width, height = sprite:getDimensions()

function Tombstone:new(x, y, onWall)
    local object = Tile.new(self, x, y, 5, true)
    setmetatable(object, Tombstone)
    object.isTombstone = true
    object.onWall = onWall
    object.isXrayTileOccluder = false
    return object
end

function Tombstone:getDrawPriority()
    return self.yWorld + 12 + (self.ySortOffset or 0)
end

function Tombstone:onshoot()
    return false
end

function Tombstone:draw()
    if self.onWall and not self.isOnUpperWall then self:drawGroundBase() end
    love.graphics.draw(sprite, self.xWorld, self.yWorld, 0, 1, 1, width / 2, height)
end

function Tombstone:getXrayOccluderBox()
    return {x = self.xWorld - width / 2, y = self.yWorld - height, width = width, height = height}
end

function Tombstone:drawXrayOccluder()
    love.graphics.draw(sprite, self.xWorld, self.yWorld, 0, 1, 1, width / 2, height)
end

return Tombstone
