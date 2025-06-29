local Creator = require "scripts.creator.creator"

local FirstCreatorInteraction = {}
FirstCreatorInteraction.__index = FirstCreatorInteraction
setmetatable(FirstCreatorInteraction, { __index = Creator })

function FirstCreatorInteraction:load()
    Creator.load(self)

    self.timer = 0
    self.dialogIndex = 1
    self.dialogList = {
        "Hello, Player",
        "I am homma, the creator of the game",
        "I will teach and help you to play this game"
    }

    self.startfirstDialog = 5
    self.dialogStarted = false
end

function FirstCreatorInteraction:update(dt)
    Creator.update(self, dt)
    self.timer = self.timer  + dt
    if self.timer >= 2 then
        Dialog:showPassDialog()
    end
    if self.timer >= self.startfirstDialog and not self.dialogStarted then
        self.dialogStarted = true
        self.timer = 0
        self.dialogIndex = 2
        self:showNextDialog()
        print("start")
    end
end

function FirstCreatorInteraction:showNextDialog()
    self:setMessage(self.dialogList[self.dialogIndex])
end

function FirstCreatorInteraction:draw()
    Creator.draw(self)
end

return FirstCreatorInteraction
