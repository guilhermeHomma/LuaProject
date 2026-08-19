local Drop = {}
local Localization = require("scripts/managers/localization")
Drop.__index = Drop

function Drop:new(x, y)

    local drop = setmetatable({}, {__index = self})
    drop.x = x
    drop.y = y
    
    drop.isAlive = true
    drop.isXrayVisible = true
    drop.timer = 0
    drop.lifeTime = 15
    drop.lifetimeTimer = 0
    return drop
end

function Drop:checkCatch()
    if self.requirePickupKey then
        return
    end

    local inRange = self.fromChest and self:isPlayerInPickupRange() or distance(self, Player) < 10
    if inRange then
        if not self.isAlive or self.isCollecting then
            return
        end
        self:markPersistentCollected()
        if type(self.startCollectAnimation) == "function" then
            self:startCollectAnimation()
        else
            self.isAlive = false
            self:onCatch()
        end
    end
end

function Drop:markPersistentCollected()
    if not (self.persistRoomDrop and self.roomDropKey) then
        return
    end

    local FloorManager = require("scripts/managers/floorManager")
    local state = FloorManager:getCurrentRoomState()
    local entry = state and state.drops and state.drops[self.roomDropKey]
    if entry then
        entry.collected = true
    end
end

function Drop:updatePersistentPosition()
    if not (self.persistRoomDrop and self.roomDropKey) then
        return
    end

    local FloorManager = require("scripts/managers/floorManager")
    local state = FloorManager:getCurrentRoomState()
    local entry = state and state.drops and state.drops[self.roomDropKey]
    if entry and not entry.collected then
        entry.x = self.x
        entry.y = self.y
    end
end

function Drop:update(dt)
    addToDrawQueue((self.drawBaseY or self.y) + (self.drawPriorityOffset or 10), self)

    self:checkCatch()
    self:updatePickupTutorial(dt)
    if self.isCollecting then
        if type(self.updateCollectAnimation) == "function" then
            self:updateCollectAnimation(dt)
        end
        return true
    end

    self:updatePersistentPosition()
    self.lifetimeTimer = self.lifetimeTimer + dt
    self.timer = self.timer + dt

    if not self.neverExpires and self.timer >= self.lifeTime then
        self.isAlive = false
    end
end

function Drop:isPlayerInPickupRange()
    local pickupDistance = self.pickupDistance or 13
    if distance(self, Player) < pickupDistance then
        return true
    end

    if self.pickupX and self.pickupY then
        return distance({x = self.pickupX, y = self.pickupY}, Player) < pickupDistance
    end

    return false
end

function Drop:updatePickupTutorial(dt)
    if not self.requirePickupKey or not self.isAlive or self.isCollecting then
        return
    end

    if self:isPlayerInPickupRange() then
        Game.drawtext = Localization:t("game.press_pickup")
        Game.textAlphaTarget = 1
    end
end

function Drop:keypressed(key)
    if key == "f" and self.requirePickupKey and self:isPlayerInPickupRange() then
        if not self.isAlive or self.isCollecting then
            return
        end
        self:markPersistentCollected()
        if type(self.startCollectAnimation) == "function" then
            self:startCollectAnimation()
        else
            self.isAlive = false
            self:onCatch()
        end
    end
end

function Drop:onCatch()

end

function Drop:drawShadow()

    if not self.isAlive then
        return
    end

    love.graphics.setColor(0,0,0, 0.2)
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

function Drop:drawXray()
    if not self.isAlive then
        return
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", self.x, self.y - (self.height or 0), 4)
end

return Drop
