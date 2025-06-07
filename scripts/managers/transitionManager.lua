TransitionManager = {}

local sound = love.audio.newSource("assets/sfx/menu/eletric-transition.mp3", "static")
 

function TransitionManager:load()
    self.alpha = 1
    self.targetAlpha = 0
    self.speed = 4
    self.isTransiting = false

    self.transitionTimer = 0
    self.callback = nil


    self.distortion = 1
    self.targetDistortion = 0
    self.distortionSpeed = 5
    self.distortionTimer = 1
end

function TransitionManager:update(dt)

    if self.distortion ~= self.targetDistortion and self.distortionTimer >= 1 then
        self.distortion = self.distortion + (self.targetDistortion - self.distortion) * dt *  self.distortionSpeed
        if math.abs(self.targetDistortion - self.distortion) < 0.005 then
            self.distortion = self.targetDistortion
        end
    end

    if self.alpha ~= self.targetAlpha then
        self.alpha = self.alpha + (self.targetAlpha - self.alpha) * dt *  self.speed
        
        if math.abs(self.targetAlpha - self.alpha) < 0.005 then
            self.alpha = self.targetAlpha
        end
    end

    self.distortionTimer = self.distortionTimer + dt

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
    
    sound:setVolume(0.2)
    sound:setPitch(1 + math.random() * 0.3)
    sound:play()
    self.callback = callback
    self.targetAlpha = 1
    self.isTransiting = true
    self.speed = speed
    self.transitionTimer = timer
    self.targetDistortion = 1
    self.distortion = 1
    self.distortionTimer = 1


end

function TransitionManager:finishTransition()


    sound:setVolume(0.1)    
    sound:setPitch(1.2 + math.random() * 0.3)
    sound:play()
    GAME_PITCH = 1
    self.targetAlpha = 0
    self.callback = nil
    self.isTransiting = false
    self.transitionTimer = 3
    self.targetDistortion = 0
    self.distortion = 2

    self.distortionTimer = 1
end

function TransitionManager:draw()
    love.graphics.setColor(0, 0, 0, self.alpha)
    love.graphics.rectangle("fill", 0, 0, baseWidth, baseHeight)

    love.graphics.setColor(1, 1, 1)
end

return TransitionManager