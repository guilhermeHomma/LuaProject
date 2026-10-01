local WalkDust = require("scripts/particles/walkDust")
local Smoke = setmetatable({}, {__index = WalkDust})
Smoke.__index = Smoke

function Smoke:new(x, y, vx, vy, priority)
    local particle = WalkDust.new(self, x, y)
    particle.vx, particle.vy = vx, vy
    particle.priority = priority
    particle.lifeTime = 0.7 + math.random() * 0.2
    return particle
end

function Smoke:update(dt)
    self.timer = self.timer + dt
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt
    self.alpha = 0.55 * math.max(0, 1 - self.timer / self.lifeTime)
    self.isAlive = self.timer < self.lifeTime
    if self.isAlive then addToDrawQueue(self.priority, self) end
end

function Smoke:draw()
    local scale = 1 + self.timer * 0.7
    love.graphics.push()
    love.graphics.translate(self.x, self.y)
    love.graphics.scale(scale, scale)
    love.graphics.translate(-self.x, -self.y)
    WalkDust.draw(self)
    love.graphics.pop()
end

function Smoke.emit(elevator, count)
    for i = 1, count do
        local side = (i - 1) % 4
        local x, y, vx, vy
        if side < 2 then
            local sign = side == 0 and -1 or 1
            x, y = elevator.x + sign * 48, elevator.y - math.random(0, 80)
            vx, vy = sign * math.random(5, 10), -math.random(2, 5)
        else
            local rear = side == 2
            x, y = elevator.x + math.random(-48, 48), elevator.y - (rear and 80 or 0)
            vx, vy = math.random(-4, 4), rear and -8 or 5
        end
        Game.particles[#Game.particles + 1] = Smoke:new(x, y, vx, vy, elevator.y + 17)
    end
end

return Smoke
