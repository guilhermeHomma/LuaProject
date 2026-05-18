local ZombieMouthConfig = {
    spritePath = "assets/sprites/enemy/zombie/mouth.png",
    frameWidth = 16,
    frameHeight = 16,
    openFrameIndex = 0,
    closedFrameIndex = 1,
    originX = 8,
    originY = 8,
    baseOffsetX = 0,
    baseOffsetY = -18,
    soundVisibleTime = 1,
    variants = {
        zombie = {
            offsetX = 0,
            offsetY = 0,
        },
        babyZombie = {
            offsetX = 0,
            offsetY = 3,
        },
        noHead = {
            offsetX = 0,
            offsetY = 0,
        },
    },
    frameOffsets = {
        idle = {
            [1] = { x = 0, y = 0 },
            [2] = { x = 0, y = 1 },
        },
        walk = {
            [3] = { x = 0, y = -1 },
            [5] = { x = 0, y = -1 },
        },
    },
}

return ZombieMouthConfig
