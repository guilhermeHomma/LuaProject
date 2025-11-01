
local logoIntro = {}

local totalFrames = 33
function logoIntro:load()
    self.timer = 0
    self.finish = false


    self.frames = {}
    for i = 1, totalFrames do
        self.frames[i] = love.graphics.newImage("assets/logo/logo_animated" .. i .. ".png")
        self.frames[i]:setFilter("nearest", "nearest")
    end
    self.frame_index = 1
    self.frame_time = 0
end

function logoIntro:getHeight()
    return love.graphics.getHeight()/ scale 
end

function logoIntro:getWidth()
    return love.graphics.getWidth() / scale 
end


function logoIntro:draw()

    love.graphics.clear(0, 0, 0)
    love.graphics.setColor(1, 1, 1)

    local centerX = self:getWidth() / 2
    local centerY = self:getHeight() / 2

    love.graphics.draw(self.frames[self.frame_index], centerX - 256, centerY - 256)
end

function logoIntro:update(dt)
    self.timer = self.timer + dt

    if self.timer > 0.5 then 
        self.frame_time = self.frame_time + dt
    end
    if self.frame_time > 0.12 and self.frame_index <= 10 then
        self.frame_time = 0

        self.frame_index = self.frame_index + 1 
    end


    if self.frame_time > 0.03 and self.frame_index < totalFrames and self.frame_index > 10 then
        self.frame_time = 0

        self.frame_index = self.frame_index + 1 
    end

    if self.timer > 6 and not self.finish then
        loadIntro()
        self.finish = true
    end

end

function logoIntro:keypressed(key)


end

return logoIntro