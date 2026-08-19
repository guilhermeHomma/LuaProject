local Shared = require("scripts/player/weapons/shared")

return Shared.createWeapon({
    id = 3,
    name = "raygun",
    price = 90,
    shotCooldown = 0.3,
    magCount = 10,
    magCapacity = 10,
    reloadDuration = 0.9,
    reloadSpinDuration = 0.22,
    damage = 15,
    bulletSpeed = 340,
    ammoPerShot = 1,
    bulletSize = Shared.bulletSizes.standard,
    shake = { intensity = 2.8, decay = 0.88 },
    audio = { folder = "raygun", volume = 0.3, pitchMin = 1.02, pitchMax = 1.12 },
    initialBullet = {
        id = "bulletred",
        sprite = "assets/sprites/bullets/bulletred.png",
        soundVolume = 0.16,
    },
    bulletModule = "particle",
    projectileSprite = "assets/sprites/bullets/bulletred.png",
    spriteTrailDistance = 5,
    spriteTrailLifetime = 0.14,
    projectiles = {
        { angleJitterMin = -0.05, angleJitterMax = 0.05, offsetDistance = 5 }
    }
})
