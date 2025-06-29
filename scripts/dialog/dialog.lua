local DialogBox = {}


function DialogBox:load()
    self.text = "text test text test sdasdasd asdasda sdas dasd"
    self.visible = false
    self.font = love.graphics.newFont("assets/fonts/ThaleahFat.ttf", 32)
    self.padding = 20
    self.boxWidth = 500
    self.boxHeight = 130
    self.breakMovements = false
    self.PassDialog = false
    self.font:setLineHeight(0.7)
end

function DialogBox:show(message)
    self.text = message
    self.visible = true
    self.PassDialog = false
    self.breakMovements = true
end

function DialogBox:hide()
    self.visible = false
    self.breakMovements = true

end

function DialogBox:showPassDialog()
    self.PassDialog = true
end

function DialogBox:draw()
    if not self.visible then return end
    if not Player.isAlive then return end

    love.graphics.setFont(self.font)

    local x = (getScreenWidth() - self.boxWidth) / 2
    local y = getScreenHeight() - self.boxHeight - 40

    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", x, y, self.boxWidth, self.boxHeight, 12, 12)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(self.text, x + self.padding, y + self.padding, self.boxWidth - self.padding * 2, "left")

    if self.PassDialog then
        local time = love.timer.getTime()
        local alpha = 0.4 + 0.6 * math.abs(math.sin(time * 1.5)) -- Pisca suavemente entre 0.4 e 1.0

        love.graphics.setColor(1, 1, 1, alpha)

        local textX = x + self.boxWidth - self.padding
        local textY = y + self.boxHeight - self.padding

        love.graphics.printf("X", textX - 150, textY - 10, 160, "right")
    end
end

return DialogBox