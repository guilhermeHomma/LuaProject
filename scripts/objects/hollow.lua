local Hollow = {}
Hollow.__index = Hollow

local image = love.graphics.newImage("assets/sprites/objects/hollow.png")
image:setFilter("nearest", "nearest")

function Hollow:new(x, y)
    local hollow = setmetatable({}, Hollow)
    hollow.x = x
    hollow.y = y
    hollow.xWorld = x
    hollow.yWorld = y
    hollow.interactionDistance = 20
    hollow.timer = 0
    hollow.isAlive = true
    hollow.isGroundLayer = true
    hollow.triggered = false
    return hollow
end

function Hollow:isPlayerNear()
    if not (Player and Player.isAlive) then
        return false
    end

    local dx = Player.x - self.x
    local dy = Player.y - self.y
    local distanceLimit = self.interactionDistance or 20
    return dx * dx + dy * dy <= distanceLimit * distanceLimit
end

function Hollow:update(dt)
    self.timer = self.timer + dt
    addToDrawQueue(self.y - 79, self, false)

    if self.triggered then
        return
    end

    if self:isPlayerNear() then
        Game.drawtext = "press f to go to the next floor"
        Game.textAlphaTarget = 1
    end
end

function Hollow:keypressed(key)
    if key == "f" and not self.triggered and self:isPlayerNear() then
        self.triggered = true
        if Game and Game.enterFloorHollow then
            Game:enterFloorHollow()
        end
    end
end

function Hollow:drawShadow()
end

function Hollow:draw()
    local pulse = 0.88 + math.sin(self.timer * 3.2) * 0.08
    love.graphics.setColor(pulse, pulse, pulse, 1)
    love.graphics.draw(image, self.x, self.y, 0, 1, 1, image:getWidth() / 2, image:getHeight())
    love.graphics.setColor(1, 1, 1, 1)
end

return Hollow
