local Camera = {}
Camera.__index = Camera

function Camera:new(x, y)
    local cam = setmetatable({}, Camera)
    cam.x = x or 0
    cam.y = y or 0
    cam.smoothSpeed = 0.03
    cam.shakeIntensity = 0
    cam.shakeDecay = 0.5
    return cam
end

function Camera:update(targetX, targetY)
    self.x = self.x + (targetX - self.x) * self.smoothSpeed
    self.y = self.y + (targetY -40- self.y) * self.smoothSpeed
    if self.shakeIntensity > 0 then
        local dx = love.math.randomNormal(-1, 1) * self.shakeIntensity
        local dy = love.math.randomNormal(-1, 1) * self.shakeIntensity
        self.x = self.x + dx
        self.y = self.y + dy
        self.shakeIntensity = self.shakeIntensity * self.shakeDecay
    end

end

function Camera:attach()
    love.graphics.push()
    love.graphics.translate(-self.x, -self.y)
end

function Camera:shake(intensity, decay)
    self.shakeIntensity = intensity or 5
    self.shakeDecay = decay or 0.4
end

function Camera:detach()
    love.graphics.pop()
end

return Camera