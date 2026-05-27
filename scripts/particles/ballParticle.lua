local Particle = require("scripts/particles/particle")
local Ball = setmetatable({}, {__index = Particle})
Ball.__index = Ball
Ball.castsShadow = false
local RgbShiftDraw = require("scripts/effects/rgbShiftDraw")

local sprite = love.graphics.newImage("assets/sprites/particles/ball.png")
sprite:setFilter("nearest", "nearest")
local starSprite = love.graphics.newImage("assets/sprites/particles/star.png")
starSprite:setFilter("nearest", "nearest")
local starChance = 0.5

function Ball:new(x, y, height, dx, dy, lifetime, size, options)
    if not size then size = 1 end
    if not dx then dx = 0 end
    if not dy then dy = 0 end
    if not lifetime  then lifetime = math.random(30, 45) / 100 end
    options = options or {}

    local particle = Particle.new(self, x, y, height, size, lifetime)
    particle.sprite = math.random() < starChance and starSprite or sprite
    particle.speed = math.random(30, 35)
    particle.speedDown = math.random(45, 55)
    particle.dx = dx
    particle.dy = dy
    if options.rgbShift then
        --particle.rgbShift = RgbShiftDraw.createConfig(options.rgbShift)
    end
    return particle
end

function Ball:update(dt)
    addToDrawQueue(self.drawPriorityY or (self.y + (self.drawPriorityOffset or 5)), self)
    self.x = self.x + self.dx * self.speed * dt
    self.y = self.y + self.dy * self.speed * dt
    self.timer = self.timer + dt
    self.radius = self.initialRadius * (1 - (self.timer / self.lifeTime))
    self.speed = self.speed - 33*dt
    if self.speed <= 0 then self.speed = 0 end

    self.height = self.height + self.speedDown * dt
    if self.timer >= self.lifeTime then
        self:death()
    end
end

function Ball:drawShadow()
    
end

function Ball:death()
    self.isAlive = false
end

function Ball:draw()
    local drawX = self.x
    local drawY = self.y - self.height
    local scaleX = 1 * self.radius
    local scaleY = 1.5 * self.radius
    local originX = 16 / 2
    local originY = 16 / 2 * 1.5

    RgbShiftDraw.drawSprite(
        self.sprite,
        nil,
        drawX,
        drawY,
        0,
        scaleX,
        scaleY,
        originX,
        originY,
        self.timer,
        self.rgbShift,
        0.8
    )

    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.draw(self.sprite, drawX, drawY, 0, scaleX, scaleY, originX, originY)
    love.graphics.setColor(1, 1, 1, 1)
end

return Ball
