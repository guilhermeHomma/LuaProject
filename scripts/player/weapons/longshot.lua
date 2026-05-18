local Shared = require("scripts/player/weapons/shared")

return Shared.createWeapon({
    id = 5,
    name = "longshot",
    price = 320,
    shotCooldown = 0.9,
    magCount = 12,
    magCapacity = 5,
    reloadDuration = 1.05,
    reloadSpinDuration = 0.3,
    damage = 15,
    bulletSpeed = 280,
    ammoPerShot = 1,
    bulletSize = Shared.bulletSizes.standard,
    shake = { intensity = 3.4, decay = 0.82 },
    audio = { folder = "squaregun", volume = 0.28, pitchMin = 0.82, pitchMax = 0.92 },
    initialBullet = {
        id = "bulletblue",
        sprite = "assets/sprites/bullets/bulletcyan.png",
        soundVolume = 0.18,
        lifeTime = 0.5,
    },
    bulletModule = "particle",
    projectileSprite = "assets/sprites/bullets/bulletcyan.png",
    spriteTrailDistance = 5,
    spriteTrailLifetime = 0.14,
    impactFlashSprite = "assets/sprites/particles/gunSquare.png",
    projectiles = {
        { angleJitterMin = -0.035, angleJitterMax = 0.035, offsetDistance = 5 }
    }
})
