local Fonts = {}

Fonts.paths = {
    translated = "assets/fonts/upheavtt.ttf",
    logo = "assets/fonts/ThaleahFat.ttf",
    numeric = "assets/fonts/PixelGame.otf",
}

Fonts.sizes = {
    menuTitle = 32,
    menuOption = 22,
    mainLogo = 64,
    version = 28,
    cardTitle = 24,
    cardName = 20,
    cardRarity = 16,
    cardAmount = 20,
    cardDescription = 16,
    hudMessage = 20,
    store = 16,
    floorTitle = 36,
    thanks = 28,
    madeBy = 18,
    status = 18,
    statusSmall = 16,
    statusTitle = 16,
    fps = 16,
    dialog = 16,
}

Fonts.lineHeights = {
    menuTitle = 1,
    menuOption = 1,
    cardDescription = 1.05,
    hudMessage = 1,
    dialog = 1,
}

function Fonts:snap(value)
    return math.floor((value or 0) + 0.5)
end

function Fonts:new(path, size)
    local font = love.graphics.newFont(path, size)
    font:setFilter("nearest", "nearest")
    font:setLineHeight(self.lineHeights[size] or 1)
    return font
end

function Fonts:translated(sizeKey)
    local font = self:new(self.paths.translated, self.sizes[sizeKey] or sizeKey)
    font:setLineHeight(self.lineHeights[sizeKey] or 1)
    return font
end

function Fonts:logo(sizeKey)
    local font = self:new(self.paths.logo, self.sizes[sizeKey] or sizeKey)
    font:setLineHeight(self.lineHeights[sizeKey] or 1)
    return font
end

function Fonts:numeric(sizeKey)
    local font = self:new(self.paths.numeric, self.sizes[sizeKey] or sizeKey)
    font:setLineHeight(self.lineHeights[sizeKey] or 1)
    return font
end

return Fonts
