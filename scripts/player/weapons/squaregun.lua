local Shared = require("scripts/player/weapons/shared")

return Shared.createWeapon({
    id = 4,
    name = "squaregun",
    price = 44,
    shotCooldown = 0.55,
    magCount = 12,
    magCapacity = 8,
    reloadDuration = 0.9,
    reloadSpinDuration = 0.25,
    damage = 10,
    bulletSpeed = 250,
    ammoPerShot = 2,
    bulletSize = Shared.bulletSizes.standard,
    shake = { intensity = 3.1, decay = 0.8 },
    audio = { folder = "squaregun", volume = 0.3, pitchMin = 1.08, pitchMax = 1.18 },
    initialBullet = {
        id = "bulletblue",
        sprite = "assets/sprites/bullets/bulletblue.png",
        soundVolume = 0.2,
    },
    bulletModule = "particle",
    projectileSprite = "assets/sprites/bullets/bulletblue.png",
    spriteTrailDistance = 5,
    spriteTrailLifetime = 0.12,
    muzzleFlashSprite = "assets/sprites/particles/gunSquare.png",
    impactFlashSprite = "assets/sprites/particles/gunSquare.png",
    projectiles = {
        { angleJitterMin = -0.05, angleJitterMax = 0.05, offsetDistance = 5 },
        { angleOffset = 0.1, offsetDistance = 10, spawnOffsetX = 2, spawnOffsetY = 2, height = 15 }
    }
})
