local TreeConfig = {}

TreeConfig.fadeArea = {
    marginX = 4,
    topOffset = -12,
    bottomPadding = -22,
    hiddenAlpha = 0.4,
    playerCalculationPadding = 160,
    playerAreaPadding = 0,
    enemyAreaPadding = 0,
    doorAreaPadding = 2,
    doorBoxWidth = 10,
    doorBoxHeight = 28,
    doorBoxYOffset = -34,
    doorMarkWidth = 10,
    doorMarkHeight = 12,
    doorMarkYOffset = -10,
    fadeOutStep = 0.055,
    fadeInStep = 0.075,
}

TreeConfig.foregroundDarken = {
    enabled = true,
    minDistance = 480,
    maxDistance = 630,
    minBrightness = 0.5,
    referenceYOffset = 0,
}

TreeConfig.debug = {
    fadeAreaFillColor = {0.25, 0.8, 1, 0.12},
    fadeAreaLineColor = {0.25, 0.8, 1, 0.85},
}

return TreeConfig
