local Camera = {}
Camera.__index = Camera
--local baseWidth = 960
--local baseHeight = 540


function Camera:new(x, y)
    if not x then x = 0 end
    if not y then y = 0 end 
    
    local cam = setmetatable({}, Camera)

    cam.windowWidth = love.graphics.getWidth()
    cam.windowHeight = love.graphics.getHeight()

    
    local scaleX = cam.windowWidth / baseWidth
    local scaleY = cam.windowHeight / baseHeight

    cam.scale = math.max(scaleX, scaleY)

    cam.x = x*3 - love.graphics.getWidth() / cam.scale / 2
    cam.y = y*2 - love.graphics.getHeight() / cam.scale  / 2

    cam.smoothSpeed = 0.03
    cam.shakeIntensity = 0
    cam.shakeDecay = 0.5

    cam.targetDistanceX = 0.5
    cam.targetDistanceY = 0.5

    return cam
end

function Camera:setCenterDistance(targetX, targetY)

    local dx = targetX - self.x
    local dy = targetY - self.y 
    self.targetDistanceX = self.windowWidth/2 + dx
    self.targetDistanceY = self.windowHeight/2 + dy
end

function Camera:update(targetX, targetY)

    local targetX = Player.x*3 - love.graphics.getWidth() / self.scale / 2
    local targetY = Player.y*2 - love.graphics.getHeight() / self.scale  / 2

    self:setCenterDistance(targetX, targetY)

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


function Camera:resize(w, h)
    camera.windowWidth = w
    camera.windowHeight = h

    local scaleX = w / baseWidth
    local scaleY = h / baseHeight

    camera.scale = math.max(scaleX, scaleY)
end

function Camera:attach()
    love.graphics.push()

    --love.graphics.scale(1, 1)
    
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