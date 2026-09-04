local Shared = require("scripts/player/weapons/shared")

return Shared.createWeapon({
    id = 6,
    name = "cakegun",
    price = 60,
    shotCooldown = 0.6,
    magCount = 10,
    magCapacity = 10,
    reloadDuration = 0.9,
    reloadSpinDuration = 0.28,
    damage = 12,
    bulletSpeed = 265,
    ammoPerShot = 2,
    bulletSize = Shared.bulletSizes.standard,
    shake = { intensity = 3.5, decay = 0.8 },
    audio = { folder = "squaregun", volume = 0.32, pitchMin = 0.94, pitchMax = 1.04 },
    initialBullet = {
        id = "bulletblue",
        sprite = "assets/sprites/bullets/bulletblue.png",
        soundVolume = 0.2,
        lifeTime = 0.4,
    },
    bulletModule = "particle",
    projectileSprite = "assets/sprites/bullets/bulletblue.png",
    spriteTrailDistance = 5,
    spriteTrailLifetime = 0.13,
    muzzleFlashSprite = "assets/sprites/particles/gunSquare.png",
    impactFlashSprite = "assets/sprites/particles/gunSquare.png",
    projectiles = {
        { angleJitterMin = -0.05, angleJitterMax = 0.05, offsetDistance = 5 },
        { angleOffset = 0.1, offsetDistance = 10, spawnOffsetX = 2, spawnOffsetY = 2, height = 15 }
    }
})
