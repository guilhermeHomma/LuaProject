local Drop = {}
Drop.__index = Drop

function Drop:new(x, y)

    local drop = setmetatable({}, {__index = self})
    drop.x = x
    drop.y = y
    
    drop.isAlive = true
    drop.timer = 0
    drop.lifeTime = 15
    drop.lifetimeTimer = 0
    return drop
end

function Drop:checkCatch()
    if distance(self, Player) < 10 then
        if not self.isAlive then
            return
        end
        self.isAlive = false
        self:onCatch()
    end
end

function Drop:update(dt)
    addToDrawQueue(self.y + 10, self)

    self:checkCatch()
    self.lifetimeTimer = self.lifetimeTimer + dt
    self.timer = self.timer + dt

    if self.timer >= self.lifeTime then
        self.isAlive = false
    end
end

function Drop:onCatch()

end

function Drop:drawShadow()

    if not self.isAlive then
        return
    end

    love.graphics.setColor(0.70, 0.63, 0.52)
    love.graphics.circle("fill", self.x , self.y, 3)
    
    love.graphics.setColor(1, 1, 1)
end

function Drop:draw()


    if not self.isAlive then
        return
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", self.x, self.y, 7)
    love.graphics.setColor(1, 1, 1)

end

return Drop