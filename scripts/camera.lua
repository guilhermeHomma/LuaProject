local Camera = {}
Camera.__index = Camera
local baseWidth = 960
local baseHeight = 540
function Camera:new(x, y)
    if not x then x = 0 end
    if not y then y = 0 end 
    
    local cam = setmetatable({}, Camera)

    cam.windowWidth = love.graphics.getWidth()
    cam.windowHeight = love.graphics.getHeight()

    cam.x = x - cam.windowWidth / 2
    cam.y = y - cam.windowHeight / 2
    cam.x = 0
    cam.y =0
    cam.smoothSpeed = 0.03
    cam.shakeIntensity = 0
    cam.shakeDecay = 0.5

    local scaleX = cam.windowWidth / baseWidth
    local scaleY = cam.windowHeight / baseHeight

    cam.scale = math.max(scaleX, scaleY)

    return cam
end

function Camera:update(targetX, targetY)
    self.windowWidth = love.graphics.getWidth()
    self.windowHeight = love.graphics.getHeight()

    local scaleX = self.windowWidth / baseWidth
    local scaleY = self.windowHeight / baseHeight

    self.scale = math.max(scaleX, scaleY)
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

    love.graphics.scale(self.scale, self.scale)
    
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