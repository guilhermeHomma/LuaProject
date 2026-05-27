local ShellParticle = {}
ShellParticle.__index = ShellParticle
ShellParticle.castsShadow = false

local whiteShader = love.graphics.newShader("scripts/shaders/whiteShader.glsl")
local bulletSheet = love.graphics.newImage("assets/sprites/player/gun-bullet.png")
bulletSheet:setFilter("nearest", "nearest")

local size = 16
local quad = love.graphics.newQuad(0, 0, size, size, bulletSheet:getDimensions())

function ShellParticle:new(x, y, angle, options)
    options = options or {}
    local backAngle = angle + math.pi

    local particle = setmetatable({}, self)
    particle.x = x
    particle.y = y
    particle.groundY = y + (options.groundOffsetY or 14)
    particle.z = options.z or 10
    particle.vx = math.cos(backAngle) * (options.speed or 58)
    particle.vy = math.sin(backAngle) * (options.speed or 58) + (options.fallSpeed or 20)
    particle.vz = options.vz or 18
    particle.gravity = options.gravity or 260
    particle.zGravity = options.zGravity or 420
    particle.drag = options.drag or 2.1
    particle.rotation = angle
    particle.rotationSpeed = options.rotationSpeed or (8 + math.random() * 2.4)
    particle.flashTime = options.flashTime or 0.05
    particle.timer = 0
    particle.fadeTimer = 0
    particle.fadeTime = options.fadeTime or 2
    particle.alpha = 1
    particle.scale = options.scale or 0.55
    particle.originX = options.originX or 2
    particle.originY = options.originY or 1
    particle.color = options.color or {0.5, 0.5, 0.5}
    particle.grounded = false
    particle.isAlive = true
    return particle
end

function ShellParticle:update(dt)
    addToDrawQueue(self.y + 0.2, self)
    self.timer = self.timer + dt

    if not self.grounded then
        self.x = self.x + self.vx * dt
        self.y = self.y + self.vy * dt
        self.vy = self.vy + self.gravity * dt

        local drag = math.max(0, 1 - self.drag * dt)
        self.vx = self.vx * drag
        self.vy = self.vy * drag

        self.z = math.max(0, self.z + self.vz * dt)
        self.vz = (self.vz - self.zGravity * dt) * drag
        self.rotation = self.rotation + self.rotationSpeed * dt

        if self.y >= self.groundY then
            self.y = self.groundY
            self.vy = 0
        end

        if self.y >= self.groundY and self.z <= 0 then
            self.y = self.groundY
            self.z = 0
            self.vx = 0
            self.vy = 0
            self.vz = 0
            self.rotationSpeed = 0
            self.grounded = true
        end
    else
        self.fadeTimer = self.fadeTimer + dt
        self.alpha = math.max(0, 1 - self.fadeTimer / self.fadeTime)
        if self.fadeTimer >= self.fadeTime then
            self.isAlive = false
        end
    end
end

function ShellParticle:draw()
    local color = self.color
    love.graphics.setColor(color[1], color[2], color[3], self.alpha)
    if self.timer <= self.flashTime then
        love.graphics.setShader(whiteShader)
    end

    love.graphics.draw(
        bulletSheet,
        quad,
        self.x,
        self.y - self.z,
        self.rotation,
        self.scale,
        self.scale,
        self.originX,
        self.originY
    )

    love.graphics.setShader()
    love.graphics.setColor(1, 1, 1, 1)
end

function ShellParticle:drawShadow()
end

return ShellParticle
