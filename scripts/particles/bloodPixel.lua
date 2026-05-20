local BloodPixel = {}
BloodPixel.__index = BloodPixel

local bloodPixelScale = 1.45

local palette = {
    {0.46, 0.12, 0.10, 1},
    {0.36, 0.07, 0.08, 1},
    {0.58, 0.20, 0.16, 1},
    {0.28, 0.05, 0.06, 1},
    {0.50, 0.15, 0.13, 1},
}

function BloodPixel:new(x, y, dx, dy)
    local particle = setmetatable({}, BloodPixel)
    local angle = math.atan2(dy or 0, dx or 0)
    local hasDirection = math.abs(dx or 0) + math.abs(dy or 0) > 0.001
    local spread = (math.random() - 0.5) * 1.7

    if not hasDirection then
        angle = math.random() * math.pi * 2
    end

    angle = angle + math.pi + spread

    local speed = 10 + math.random() * 24
    particle.x = x + math.random(-3, 3)
    particle.y = y + math.random(-3, 3)
    particle.height = 4 + math.random() * 7
    particle.vx = math.cos(angle) * speed
    particle.vy = math.sin(angle) * speed * 0.65
    particle.heightVelocity = 18 + math.random() * 18
    particle.gravity = 128 + math.random() * 30
    particle.timer = 0
    particle.lifeTime = 3 + math.random() * 3
    particle.grounded = false
    particle.groundedTimer = 0
    particle.colorFreezeDelay = 0.16
    particle.colorOffset = math.random(0, #palette - 1)
    particle.frozenColor = nil
    particle.isAlive = true
    return particle
end

function BloodPixel:update(dt)
    addToDrawQueue(self.y + 8, self)

    self.timer = self.timer + dt
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt

    if not self.grounded then
        self.height = self.height + self.heightVelocity * dt
        self.heightVelocity = self.heightVelocity - self.gravity * dt

        if self.height <= 0 then
            self.height = 0
            self.grounded = true
            self.groundedTimer = 0
            self.vx = self.vx * 0.35
            self.vy = self.vy * 0.35
        end
    else
        self.groundedTimer = (self.groundedTimer or 0) + dt
        if not self.frozenColor and self.groundedTimer >= (self.colorFreezeDelay or 0.16) then
            local colorIndex = (math.floor(self.timer * 12 + self.colorOffset) % #palette) + 1
            self.frozenColor = palette[colorIndex]
        end

        local friction = math.max(0, 1 - 7 * dt)
        self.vx = self.vx * friction
        self.vy = self.vy * friction
    end

    if self.timer >= self.lifeTime then
        self.isAlive = false
    end
end

function BloodPixel:drawShadow()
end

function BloodPixel:draw()
    local color = self.frozenColor
    if not color then
        local colorIndex = (math.floor(self.timer * 12 + self.colorOffset) % #palette) + 1
        color = palette[colorIndex]
    end

    love.graphics.setColor(color[1], color[2], color[3], 1)
    love.graphics.rectangle(
        "fill",
        math.floor(self.x + 0.5),
        math.floor(self.y - self.height + 0.5),
        bloodPixelScale,
        bloodPixelScale
    )
    love.graphics.setColor(1, 1, 1, 1)
end

function BloodPixel.spawnBurst(x, y, dx, dy, minCount, maxCount)
    if not (Game and Game.particles) then
        return
    end

    local count = math.random(minCount or 4, maxCount or minCount or 4)
    for _ = 1, count do
        table.insert(Game.particles, BloodPixel:new(x, y, dx, dy))
    end
end

return BloodPixel
