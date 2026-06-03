local DamageImpactParticle = {}
DamageImpactParticle.__index = DamageImpactParticle

local sprite = love.graphics.newImage("assets/sprites/effects/particle-damage.png")
sprite:setFilter("nearest", "nearest")

local spriteWidth = sprite:getWidth()
local spriteHeight = sprite:getHeight()
local DEFAULT_LIFETIME = 0.07

local function easeOutCubic(t)
    local inv = 1 - t
    return 1 - inv * inv * inv
end

local function getImpactAngle(dx, dy)
    dx = dx or 0
    dy = dy or 0
    if dx * dx + dy * dy <= 0.0001 then
        return 0
    end

    return math.atan2(-dy, -dx)
end

function DamageImpactParticle:new(target, dx, dy, options)
    options = options or {}
    local x, y = target.x or 0, target.y or 0
    if type(target.getDamageImpactPosition) == "function" then
        x, y = target:getDamageImpactPosition()
    end

    local particle = setmetatable({}, DamageImpactParticle)
    particle.target = target
    particle.x = x
    particle.y = y
    particle.angle = getImpactAngle(dx, dy)
    particle.timer = 0
    particle.lifeTime = options.lifeTime or DEFAULT_LIFETIME
    particle.startScale = options.startScale or 0.35
    particle.endScale = options.endScale or 1.12
    particle.alpha = 1
    particle.isAlive = true
    particle.castsShadow = false
    return particle
end

function DamageImpactParticle:update(dt)
    local target = self.target
    if target and type(target.getDamageImpactPosition) == "function" then
        self.x, self.y = target:getDamageImpactPosition()
    end

    local priority = (self.y or 0) + 18
    if target then
        priority = (target.y or self.y or 0)
            + (target.damageImpactDrawPriorityOffset or 12)
            + (target.drawPriority or 0)
    end
    addToDrawQueue(priority, self, false)

    self.timer = self.timer + dt
    if self.timer >= self.lifeTime then
        self.isAlive = false
    end
end

function DamageImpactParticle:drawShadow()
end

function DamageImpactParticle:draw()
    if not self.isAlive then
        return
    end

    local progress = math.min(self.timer / self.lifeTime, 1)
    local grow = easeOutCubic(math.min(progress / 0.45, 1))
    local scale = self.startScale + (self.endScale - self.startScale) * grow
    local alpha = 1 - progress * progress

    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.draw(
        sprite,
        self.x,
        self.y,
        self.angle,
        scale,
        scale,
        spriteWidth / 2,
        spriteHeight / 2
    )
    love.graphics.setColor(1, 1, 1, 1)
end

return DamageImpactParticle
