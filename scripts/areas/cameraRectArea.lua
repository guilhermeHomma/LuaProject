local CameraRectArea = {}
CameraRectArea.__index = CameraRectArea

function CameraRectArea:new(centerX, centerY, sizeX, sizeY, fixedX, fixedY)
    local area = setmetatable({}, CameraRectArea)
    area.centerX = centerX
    area.centerY = centerY
    area.sizeX = sizeX
    area.sizeY = sizeY or sizeX
    area.halfWidth = area.sizeX / 2
    area.halfHeight = area.sizeY / 2
    area.fixedX = fixedX or centerX
    area.fixedY = fixedY or centerY
    return area
end

function CameraRectArea:containsPoint(x, y)
    return
        x >= self.centerX - self.halfWidth and
        x <= self.centerX + self.halfWidth and
        y >= self.centerY - self.halfHeight and
        y <= self.centerY + self.halfHeight
end

function CameraRectArea:getFixedPosition()
    return self.fixedX, self.fixedY
end

function CameraRectArea:drawDebug()
    if not DEBUG then
        return
    end

    local left = self.centerX - self.halfWidth
    local top = self.centerY - self.halfHeight

    love.graphics.setColor(0.85, 0.95, 1, 0.06)
    love.graphics.rectangle("fill", left, top, self.sizeX, self.sizeY)
    love.graphics.setColor(0.85, 0.95, 1, 0.18)
    love.graphics.rectangle("line", left, top, self.sizeX, self.sizeY)
    love.graphics.setColor(1, 1, 1, 1)
end

return CameraRectArea
