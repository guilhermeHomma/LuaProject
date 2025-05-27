TransitionManager = {}

function TransitionManager:load()
    self.alpha = 1
    self.targetAlpha = 0
    self.speed = 2
    self.isTransiting = false

    self.transitionTimer = 0
    self.callback = nil
end

function TransitionManager:update(dt)
    if self.alpha ~= self.targetAlpha then
        self.alpha = self.alpha + (self.targetAlpha - self.alpha) * dt *  self.speed
        
        if math.abs(self.targetAlpha - self.alpha) < 0.01 then
            self.alpha = self.targetAlpha
        end
    end

    if self.isTransiting then 
        self.transitionTimer = self.transitionTimer  - dt
    end

    if self.callback ~= nil and self.transitionTimer <= 0 then
        self:callback()
        self:finishTransition()
    end
end

function TransitionManager:startTransition(callback, speed, timer)
    if not speed or speed <= 0 then speed = 3 end
    if not timer or timer < 0 or timer >= 10 then timer = 3 end
    
    self.callback = callback
    self.targetAlpha = 1
    self.isTransiting = true
    self.speed = speed
    self.transitionTimer = timer
end

function TransitionManager:finishTransition()
    self.targetAlpha = 0
    self.callback = nil
    self.isTransiting = false
    self.transitionTimer = 3
end

function TransitionManager:draw()
    love.graphics.setColor(0, 0, 0, self.alpha)
    love.graphics.rectangle("fill", 0, 0, baseWidth, baseHeight)

    love.graphics.setColor(1, 1, 1)
end

return TransitionManager