local Particle = require("scripts/particles/particle")
local RgbShiftDraw = require("scripts/effects/rgbShiftDraw")

local boxParticle = setmetatable({}, {__index = Particle})
boxParticle.__index = boxParticle
boxParticle.castsShadow = false
local sprite = love.graphics.newImage("assets/sprites/particles/box-particles.png")
local quads = {}

sprite:setFilter("nearest", "nearest")

do
    local sheetWidth = sprite:getWidth()
    local sheetHeight = sprite:getHeight()
    for index = 1, 3 do
        quads[index] = love.graphics.newQuad((index - 1) * 32, 0, 32, 32, sheetWidth, sheetHeight)
    end
end


function boxParticle:new(x, y)

    local particle = Particle.new(self, x, y, 0, 4, 100)
    particle.sprite = sprite
    particle.particleType = "boxParticle"
    particle.index = math.random(1, 3)
    particle.rgbShift = RgbShiftDraw.createConfig({
        duration = 0.1,
        shift = 1
    })
    return particle
end

function boxParticle:update(dt)
    addToDrawQueue(self.y -10, self)
    self.timer = self.timer + dt
end


function boxParticle:drawShadow()


end


function boxParticle:death()
    self.isAlive = false

end

function boxParticle:draw()
    local r, g, b, a = love.graphics.getColor()
    local tint = {r, g, b, a}

    RgbShiftDraw.drawSprite(
        self.sprite,
        quads[self.index],
        self.x,
        self.y + 3,
        0,
        1,
        1.1,
        32 / 2,
        32,
        self.timer,
        self.rgbShift,
        1,
        tint
    )

    love.graphics.setColor(r, g, b, a)
    love.graphics.draw(self.sprite, quads[self.index], self.x, self.y + 3, 0, 1, 1.1, 32 / 2, 32)
    love.graphics.setColor(r, g, b, a)
end

return boxParticle
