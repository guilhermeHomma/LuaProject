local Camera = {}
Camera.__index = Camera
local GameConfig = require("scripts/config/gameConfig")

local function snapToPixel(value, zoom)
    zoom = zoom or 1
    return math.floor(value * zoom + 0.5) / zoom
end

function Camera:new(x, y, target)
    if not x then x = 0 end
    if not y then y = 0 end 
    
    local cam = setmetatable({}, Camera)

    cam.windowWidth = love.graphics.getWidth()
    cam.windowHeight = love.graphics.getHeight()

    local scaleX = cam.windowWidth / baseWidth
    local scaleY = cam.windowHeight / baseHeight

    cam.scale = math.min(scaleX, scaleY)
    cam.worldScaleX = GameConfig.worldScaleX
    cam.worldScaleY = GameConfig.yScale
    cam.viewWidth = baseWidth
    cam.viewHeight = baseHeight
    cam.targetViewWidth = cam.viewWidth
    cam.targetViewHeight = cam.viewHeight
    cam.baseTargetViewWidth = cam.viewWidth
    cam.baseTargetViewHeight = cam.viewHeight
    cam.viewTransitionSpeed = 4
    cam.zoomX = 1
    cam.zoomY = 1
    cam.mode = "follow"
    cam.fixedFocusX = x
    cam.fixedFocusY = y
    cam.x = x * cam.worldScaleX - cam.viewWidth / 2
    cam.y = y * cam.worldScaleY - cam.viewHeight / 2

    cam.smoothSpeed = 3
    cam.shakeIntensity = 0
    cam.shakeDecay = 0.5
    cam.shakeOffsetX = 0
    cam.shakeOffsetY = 0
    cam.damageZoomScale = 1
    cam.damageZoomTarget = 1
    cam.damageZoomInSpeed = 18
    cam.damageZoomOutSpeed = 4.5
    cam.damageZoomHoldDuration = 0.05
    cam.damageZoomHoldTimer = 0

    cam.targetDistanceX = 0.5
    cam.targetDistanceY = 0.5

    local bounds = GameConfig:getCameraBounds()
    cam.minLeft = bounds.minLeft
    cam.maxRight = bounds.maxRight
    cam.minDown = bounds.minDown
    cam.maxTop = bounds.maxTop
    cam.objectWorldPosition = cam:updateObjectPosition()
    cam.target = target
    return cam
end

function Camera:setViewSize(width, height, speed)
    self.baseTargetViewWidth = width or self.baseTargetViewWidth
    self.baseTargetViewHeight = height or self.baseTargetViewHeight
    if speed then
        self.viewTransitionSpeed = speed
    end
end

function Camera:updateTargetViewSize()
    self.targetViewWidth = self.baseTargetViewWidth * self.damageZoomScale
    self.targetViewHeight = self.baseTargetViewHeight * self.damageZoomScale
end

function Camera:setFollowMode(width, height, speed)
    self.mode = "follow"
    self:setViewSize(width or baseWidth, height or baseHeight, speed)
end

function Camera:setFixedMode(focusX, focusY, width, height, speed)
    self.mode = "fixed"
    self.fixedFocusX = focusX
    self.fixedFocusY = focusY
    self:setViewSize(width or baseWidth, height or baseHeight, speed)
end

function Camera:setCenterDistance(targetX, targetY)

    local dx = targetX - self.x
    local dy = targetY - self.y 
    self.targetDistanceX = self.windowWidth/2 + dx
    self.targetDistanceY = self.windowHeight/2 + dy
end

function Camera:getFocusPosition()
    local focusX = self.target.x
    local focusY = self.target.y - 5
    if self.mode == "fixed" then
        focusX = self.fixedFocusX
        focusY = self.fixedFocusY
    end
    return focusX, focusY
end

function Camera:updateViewZoom()
    self.zoomX = baseWidth / self.viewWidth
    self.zoomY = baseHeight / self.viewHeight
end

function Camera:snapToCurrentMode()
    local level = GameConfig.currentLevel
    if level and level.updateCamera then
        level:updateCamera(self, self.target, 0)
    else
        self:setFollowMode(baseWidth, baseHeight)
    end

    self:updateTargetViewSize()
    self.viewWidth = self.targetViewWidth
    self.viewHeight = self.targetViewHeight
    self:updateViewZoom()

    local focusX, focusY = self:getFocusPosition()
    local targetX = focusX * self.worldScaleX - self.viewWidth / 2
    local targetY = focusY * self.worldScaleY - self.viewHeight / 2

    self.x = targetX
    self.y = targetY - 40

    if self.minDown and self.y > self.minDown then self.y = self.minDown end
    if self.minLeft and self.x < self.minLeft then self.x = self.minLeft end
    if self.maxRight and self.x > self.maxRight then self.x = self.maxRight end
    if self.maxTop and self.y < self.maxTop then self.y = self.maxTop end

    self.objectWorldPosition = self:updateObjectPosition()
end

function Camera:update(dt)
    local level = GameConfig.currentLevel
    if level and level.updateCamera then
        level:updateCamera(self, self.target, dt)
    else
        self:setFollowMode(baseWidth, baseHeight)
    end

    if self.damageZoomHoldTimer > 0 then
        self.damageZoomHoldTimer = math.max(0, self.damageZoomHoldTimer - dt)
        if self.damageZoomHoldTimer == 0 and self.damageZoomTarget < 1 then
            self.damageZoomTarget = 1
        end
    end

    local zoomSpeed = self.damageZoomScale > self.damageZoomTarget and self.damageZoomInSpeed or self.damageZoomOutSpeed
    self.damageZoomScale = transitionValue(self.damageZoomScale, self.damageZoomTarget, zoomSpeed, dt)
    self:updateTargetViewSize()

    self.viewWidth = transitionValue(self.viewWidth, self.targetViewWidth, self.viewTransitionSpeed, dt)
    self.viewHeight = transitionValue(self.viewHeight, self.targetViewHeight, self.viewTransitionSpeed, dt)
    self:updateViewZoom()

    local focusX, focusY = self:getFocusPosition()

    local targetX = focusX * self.worldScaleX - self.viewWidth / 2
    local targetY = focusY * self.worldScaleY - self.viewHeight / 2

    self:setCenterDistance(targetX, targetY)

    self.x = self.x + (targetX - self.x) * self.smoothSpeed * dt
    self.y = self.y + (targetY -40- self.y) * self.smoothSpeed * dt

    if self.shakeIntensity > 0 then
        self.shakeOffsetX = love.math.randomNormal(self.shakeIntensity, 0)
        self.shakeOffsetY = love.math.randomNormal(self.shakeIntensity, 0)
        self.shakeIntensity = self.shakeIntensity * (self.shakeDecay ^ (dt * 60))
        if self.shakeIntensity < 0.05 then
            self.shakeIntensity = 0
        end
    else
        self.shakeOffsetX = 0
        self.shakeOffsetY = 0
    end

    if self.minDown and self.y > self.minDown then self.y = self.minDown end
    if self.minLeft and self.x < self.minLeft then self.x = self.minLeft end
    if self.maxRight and self.x > self.maxRight then self.x = self.maxRight end
    if self.maxTop and self.y < self.maxTop then self.y = self.maxTop end

    self.objectWorldPosition = self:updateObjectPosition()
end

function Camera:updateObjectPosition()
    return {
        x = self.x / self.worldScaleX + self.viewWidth / (self.worldScaleX * 2), 
        y = self.y / self.worldScaleY + self.viewHeight / (self.worldScaleY * 2)
    }
end

function Camera:damageZoom(intensity, zoomInSpeed, zoomOutSpeed, holdDuration)
    local zoomScale = clamp(intensity or 0.88, 0.75, 1)
    self.damageZoomTarget = zoomScale
    if zoomInSpeed then
        self.damageZoomInSpeed = zoomInSpeed
    end
    if zoomOutSpeed then
        self.damageZoomOutSpeed = zoomOutSpeed
    end
    self.damageZoomHoldDuration = holdDuration or self.damageZoomHoldDuration
    self.damageZoomHoldTimer = self.damageZoomHoldDuration
    self:updateTargetViewSize()
end

function Camera:objectPosition()
    return self.objectWorldPosition
end

function Camera:resize(w, h)
    camera.windowWidth = w
    camera.windowHeight = h

    local scaleX = w / baseWidth
    local scaleY = h / baseHeight

    camera.scale = math.min(scaleX, scaleY)
end

function Camera:attach()
    local snappedX = snapToPixel(self.x + self.shakeOffsetX, self.zoomX)
    local snappedY = snapToPixel(self.y + self.shakeOffsetY, self.zoomY)

    love.graphics.push()
    love.graphics.scale(self.zoomX, self.zoomY)
    love.graphics.translate(-snappedX, -snappedY)
end


function Camera:getTargetScreenPosition()
    if not self.target then return 0, 0 end
    return self:worldToScreen(self.target.x, self.target.y)
end

function Camera:worldToScreen(wx, wy)
    local snappedX = snapToPixel(self.x + self.shakeOffsetX, self.zoomX)
    local snappedY = snapToPixel(self.y + self.shakeOffsetY, self.zoomY)
    local px = (wx * self.worldScaleX - snappedX) * self.zoomX * self.scale + viewportOffsetX
    local py = (wy * self.worldScaleY - snappedY) * self.zoomY * self.scale + viewportOffsetY
    return px, py
end

function Camera:shake(intensity, decay)
    self.shakeIntensity = intensity or 50
    self.shakeDecay = decay or 0.4
end

function Camera:detach()
    love.graphics.pop()
end

return Camera
