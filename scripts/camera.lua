local Camera = {}
Camera.__index = Camera

function Camera:new(x, y)
    if not x then x = 0 end
    if not y then y = 0 end 
    
    local cam = setmetatable({}, Camera)
    cam.x = x - love.graphics.getWidth() / 2 or love.graphics.getWidth() / 2
    cam.y = y - love.graphics.getHeight() / 2 or love.graphics.getHeight() / 2

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
    --love.graphics.scale(0.4, 0.4)
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