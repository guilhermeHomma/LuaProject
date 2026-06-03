local RoomScreenTransition = {}

local SLIDE_DURATION = 0.4
local FADE_MAX_ALPHA = 1

local directionVectors = {
    left = { x = -1, y = 0 },
    right = { x = 1, y = 0 },
    up = { x = 0, y = -1 },
    down = { x = 0, y = 1 },
    west = { x = -1, y = 0 },
    east = { x = 1, y = 0 },
    north = { x = 0, y = -1 },
    south = { x = 0, y = 1 },
}

local function resolveDirection(direction)
    if type(direction) == "table" then
        local x = direction.x or 0
        local y = direction.y or 0
        if math.abs(x) > math.abs(y) then
            return { x = x < 0 and -1 or 1, y = 0 }
        elseif y ~= 0 then
            return { x = 0, y = y < 0 and -1 or 1 }
        end
    end

    return directionVectors[direction] or directionVectors.right
end

local function easeInOutCubic(t)
    t = math.max(0, math.min(t, 1))
    if t < 0.5 then
        return 4 * t * t * t
    end

    return 1 - ((-2 * t + 2) ^ 3) / 2
end

local function ensureCanvas(self)
    if self.oldCanvas
        and self.oldCanvas:getWidth() == baseWidth
        and self.oldCanvas:getHeight() == baseHeight then
        return self.oldCanvas
    end

    self.oldCanvas = love.graphics.newCanvas(baseWidth, baseHeight)
    self.oldCanvas:setFilter("nearest", "nearest")
    return self.oldCanvas
end

local function ensureCompositeCanvas(self)
    if self.compositeCanvas
        and self.compositeCanvas:getWidth() == baseWidth
        and self.compositeCanvas:getHeight() == baseHeight then
        return self.compositeCanvas
    end

    self.compositeCanvas = love.graphics.newCanvas(baseWidth, baseHeight)
    self.compositeCanvas:setFilter("nearest", "nearest")
    return self.compositeCanvas
end

local function getSlideOffsets(self)
    local direction = self.direction or directionVectors.right
    local progress = easeInOutCubic((self.timer or 0) / (self.duration or SLIDE_DURATION))
    local slideX = direction.x * baseWidth * progress
    local slideY = direction.y * baseHeight * progress
    local newX = slideX - direction.x * baseWidth
    local newY = slideY - direction.y * baseHeight
    return slideX, slideY, newX, newY
end

function RoomScreenTransition:beginCapture(direction)
    self.captureDirection = direction
    self.capturing = true
    self.captured = false
    self.active = false
    self.timer = 0
end

function RoomScreenTransition:captureOldFrame(sourceCanvas)
    if not (self.capturing and sourceCanvas) then
        return
    end

    local oldCanvas = ensureCanvas(self)
    love.graphics.setCanvas(oldCanvas)
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(sourceCanvas, 0, 0)
    love.graphics.setCanvas()
    self.captured = true
end

function RoomScreenTransition:startSlide(direction)
    if not self.oldCanvas then
        return
    end

    self.direction = resolveDirection(direction or self.captureDirection or "right")
    self.timer = 0
    self.duration = SLIDE_DURATION
    self.active = true
    self.capturing = false
    self.captured = false
end

function RoomScreenTransition:getDuration()
    return SLIDE_DURATION
end

function RoomScreenTransition:hasCaptured()
    return self.captured == true
end

function RoomScreenTransition:isActive()
    return self.active == true
end

function RoomScreenTransition:isCapturing()
    return self.capturing == true
end

function RoomScreenTransition:getProgress()
    if not self.active then
        return 0
    end

    return math.max(0, math.min((self.timer or 0) / (self.duration or SLIDE_DURATION), 1))
end

function RoomScreenTransition:getFadeAlpha()
    if not self.active then
        return 0
    end

    local progress = self:getProgress()
    return math.sin(progress * math.pi) * FADE_MAX_ALPHA
end

function RoomScreenTransition:update(dt)
    if not self.active then
        return
    end

    self.timer = math.min(self.duration or SLIDE_DURATION, (self.timer or 0) + dt)
    if self.timer >= (self.duration or SLIDE_DURATION) then
        self.active = false
        self.timer = 0
    end
end

function RoomScreenTransition:getPresentationCanvas(sourceCanvas)
    if not (self.active and self.oldCanvas and sourceCanvas) then
        return sourceCanvas
    end

    local compositeCanvas = ensureCompositeCanvas(self)
    local slideX, slideY, newX, newY = getSlideOffsets(self)

    love.graphics.setCanvas(compositeCanvas)
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.oldCanvas, -slideX, -slideY)
    love.graphics.draw(sourceCanvas, -newX, -newY)
    love.graphics.setCanvas()

    return compositeCanvas
end

function RoomScreenTransition:draw(sourceCanvas, x, y, scaleValue)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self:getPresentationCanvas(sourceCanvas), x, y, 0, scaleValue, scaleValue)
end

return RoomScreenTransition
