local Creator = require "scripts.creator.creator"

local FirstCreatorInteraction = {}
FirstCreatorInteraction.__index = FirstCreatorInteraction
setmetatable(FirstCreatorInteraction, { __index = Creator })

function FirstCreatorInteraction:load()
    Creator.load(self)
    self.x = 2000
    self.y = 200

    self.timer = 0
    self.speed = 1000
    self.dialogIndex = 1
    self.dialogList = {
        "Hello, Player",
        "I am homma, the creator of the game",
        "I will teach and help you how to play this game"
    }

    self.startfirstDialog = 10
    self.dialogStarted = false

    self.targetPositionX = self.x
    self.targetPositionY = self.y
    self.start = false
    self.endInteraction = false
    WaveManager.start = false

    self.vx = 0
    self.vy = 0

end

function FirstCreatorInteraction:update(dt)
    Creator.update(self, dt)
    
    self.timer = self.timer  + dt
    if self.timer >= 2 then
        Dialog:showPassDialog()
    end

    local dx = self.targetPositionX - self.x
    local dy = self.targetPositionY - self.y
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist > 5 then
            local ax = dx * 5    -- ajuste esse valor para suavidade
        local ay = dy * 5

        self.vx = self.vx + ax * dt
        self.vy = self.vy + ay * dt

        -- amortecimento para desacelerar perto do alvo
        self.vx = self.vx * 0.8
        self.vy = self.vy * 0.8

        self.x = self.x + self.vx * dt
        self.y = self.y + self.vy * dt
    end

    if Player.isAlive and Player.y < 208 then
        self.start = true
    end

    if self.start and not self.endInteraction then
        self.targetPositionX = Player.x + 20
        self.targetPositionY = Player.y
    end

    if self.endInteraction then
        self.targetPositionX = -2000
    end

    local playerDistance = distance(self, Player)
    if self.start 
    and playerDistance < 30
    and not self.dialogStarted 
    then
        self.dialogStarted = true
        self.timer = 0
        self:showNextDialog()
        self.dialogIndex = self.dialogIndex + 1
    end
end

function FirstCreatorInteraction:keypressed(key)
    -- key F
    if Dialog.PassDialog then
        self.timer = 0

        if self.dialogIndex >= #self.dialogList then
            Dialog:hide()
            self.endInteraction = true
            WaveManager.start = true
            Music:startGame()
        else 
            self.dialogIndex = self.dialogIndex + 1
            self:showNextDialog()
        end
        
        

    end
end

function FirstCreatorInteraction:showNextDialog()
    self:setMessage(self.dialogList[self.dialogIndex])
end

function FirstCreatorInteraction:draw()
    Creator.draw(self)
end

return FirstCreatorInteraction
