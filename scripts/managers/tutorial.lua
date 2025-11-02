local Tutorial = {}

require("scripts/utils")

local FirstTutorial = true
tutorialGunActive = false
function Tutorial:load()
   
    self.keyWalkImage = love.graphics.newImage("assets/sprites/ui/keys1.png")
    self.keyXImage = love.graphics.newImage("assets/sprites/ui/keys2.png")
    self.keyMouseImage = love.graphics.newImage("assets/sprites/ui/keys3.png")

    self.keyWalkImage:setFilter("nearest", "nearest")
    self.keyXImage:setFilter("nearest", "nearest")
    self.keyMouseImage:setFilter("nearest", "nearest")
    self.timer = 0

    self.startTutorialTime = 10
    self.tutorialTimer = 0

    self.drawWalk = FirstTutorial
    self.drawmouse = false
    self.drawX = false

    self._blinkWasActive = false
end


function Tutorial:playSound()
    if (self.drawWalk or self.drawmouse or self.drawX) and self.tutorialTimer > self.startTutorialTime then
        local sound = love.audio.newSource("assets/sfx/logo/madewith.mp3", "static")
        sound:setVolume(0.03)
        sound:setPitch(0.7)
        sound:play()

        FirstTutorial = false
    end
end

function Tutorial:update(dt)
    self.timer = self.timer + dt
    self.tutorialTimer = self.tutorialTimer + dt
    local activeTime = 0.15
    local inactiveTime = 0.45

    local cycle = activeTime + inactiveTime
    local t = self.tutorialTimer % cycle

    local blinkActive = t < activeTime

    if (self.drawWalk or self.drawmouse or (self.drawX and PlayerCloseStore)) and self.tutorialTimer > self.startTutorialTime then
        -- toca o som quando o blink volta (transição true -> false)
        if (blinkActive and not self._blinkWasActive) then


            local sound = love.audio.newSource("assets/sfx/logo/madewith.mp3", "static")
            sound:setVolume(0.02)
            sound:setPitch(0.75)
            sound:play()
        end
    end

    self._blinkWasActive = blinkActive
    tutorialGunActive = self.drawX and self.tutorialTimer > self.startTutorialTime
end

function Tutorial:draw()

    if not Player.isAlive then
        return

    end



    if self.tutorialTimer <= self.startTutorialTime then return end

    if self._blinkWasActive  then
        love.graphics.setColor(1, 1, 1, 0.65)
        --return
    end
    
    if self.drawWalk then 
        local y = getScreenHeight() - 84*3
        local x = -8 * 3 --getScreenWidth()

        love.graphics.draw(self.keyWalkImage, x , y, 0 , 3, 3)
    end

    if self.drawX and PlayerCloseStore then 
        local y = getScreenHeight() - 100* 3
        local x = getScreenWidth() -110 *3 

        love.graphics.draw(self.keyXImage, x , y, 0 , 3, 3)
    end

    if self.drawmouse then 
        local y = getScreenHeight() - 100*3
        local x = getScreenWidth() -110 *3 

        love.graphics.draw(self.keyMouseImage, x , y, 0 ,  3, 3)
    end
    love.graphics.setColor(1, 1, 1)

end


return Tutorial