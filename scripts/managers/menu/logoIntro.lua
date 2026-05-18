
local logoIntro = {}

local totalFrames = 33

local madeWithPlayed = false
local logoPlayed = false

function logoIntro:load()
    self.timer = 0
    self.finish = false

    self.startTime = 1.4

    self.frames = {}
    for i = 1, totalFrames do
        self.frames[i] = love.graphics.newImage("assets/logo/logo_animated" .. i .. ".png")
        self.frames[i]:setFilter("nearest", "nearest")
    end
    self.frame_index = 1
    self.frame_time = 0
end

function logoIntro:getHeight()
    return baseHeight
end

function logoIntro:getWidth()
    return baseWidth
end


function logoIntro:draw()

    love.graphics.clear(0, 0, 0)
    love.graphics.setColor(1, 1, 1)

    local centerX = self:getWidth() / 2
    local centerY = self:getHeight() / 2

    if self.timer > self.startTime then 
        love.graphics.draw(self.frames[self.frame_index], centerX - 256, centerY - 286)

    end
end

function logoIntro:update(dt)
    self.timer = self.timer + dt

    if self.timer > self.startTime then 
        self.frame_time = self.frame_time + dt
    end
    if self.frame_time > 0.1 and self.frame_index <= 10 then
        self.frame_time = 0

        self.frame_index = self.frame_index + 1 
        self:playMadeWithSound()
    end


    if self.frame_time > 0.01 and self.frame_index < totalFrames and self.frame_index > 10 then
        self.frame_time = 0

        self.frame_index = self.frame_index + 1 
        self:playLogoSound()
    end

    if self.timer > 2.5 + self.startTime and not self.finish then
        loadIntro()
        self.finish = true
    end

end

function logoIntro:playLogoSound()
    if logoPlayed then return end
    local sound = love.audio.newSource("assets/sfx/logo/intro-logo.mp3", "static")
    logoPlayed = true
    sound:setVolume(0.4)
    --sound:setPitch()
    sound:play()
end

function logoIntro:playMadeWithSound()
    if madeWithPlayed then return end
    local sound = love.audio.newSource("assets/sfx/logo/madewith.mp3", "static")
    sound:setVolume(0.1)
    --sound:setPitch(0.8)
    madeWithPlayed = true
    sound:play()
end

function logoIntro:keypressed(key)


end

return logoIntro
