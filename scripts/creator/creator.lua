local Creator = {}

local sprite = love.graphics.newImage("assets/sprites/trail/trail.png")

sprite:setFilter("nearest", "nearest")

function Creator:load()
    self.creatorSheet = love.graphics.newImage("assets/sprites/player/soldier/soldier.png")
    self.creatorShadow = love.graphics.newImage("assets/sprites/player/shadow.png")
    self.x = 120
    self.y = 360
    self.height = 40
    self.flipH = false
    self.spriteSize = 40
    self.quads = {}
    self.isAlive = true
    local sheetWidth = self.creatorSheet:getWidth()
    for i = 0, 5 do
        local quad = love.graphics.newQuad(
            i * self.spriteSize, 0,
            self.spriteSize, self.spriteSize,
            sheetWidth, self.creatorSheet:getHeight()
        )
        table.insert(self.quads, quad)
    end
end


function Creator:setMessage(message)
    Dialog:show(message)
end

function Creator:update(dt)
    if self.x > Player.x + 5 then
        self.flipH = false
    end

    if self.x < Player.x - 5 then
        self.flipH = true
    end

    local time = love.timer.getTime()
    self.height = 25 + math.sin(time * 2) * 5

    addToDrawQueue(self.y + 6, self)
end

function Creator:drawShadow()
    love.graphics.draw(self.creatorShadow, self.x, self.y, 0, 0.85, 0.85, 8, 8)
end

function Creator:draw()
    if not self.isAlive then return end

    local quad = self.quads[1] 

    local scaleX = self.flipH and -1 or 1
    local originX = self.flipH and (self.spriteSize - self.spriteSize / 2) or (self.spriteSize / 2)
    
    love.graphics.draw(
        self.creatorSheet,
        quad,
        self.x,
        self.y - self.height,
        0,
        scaleX, 1.4,
        originX, self.spriteSize
    )
    Dialog:draw()

end

return Creator