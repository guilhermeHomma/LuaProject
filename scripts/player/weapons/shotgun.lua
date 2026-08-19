local Shared = require("scripts/player/weapons/shared")

return Shared.createWeapon({
    id = 2,
    name = "shotgun",
    price = 80,
    shotCooldown = 0.8,
    magCount = 15,
    magCapacity = 9,
    reloadDuration = 1.15,
    reloadSpinDuration = 0.32,
    damage = 15,
    bulletSpeed = 250,
    ammoPerShot = 3,
    bulletSize = Shared.bulletSizes.standard,
    shake = { intensity = 4.4, decay = 0.76 },
    audio = { folder = "shotgun", volume = 0.4, pitchMin = 0.88, pitchMax = 0.95 },
    initialBullet = {
        id = "bulletcyan",
        sprite = "assets/sprites/bullets/bulletcyan.png",
        soundVolume = 0.14,
    },
    bulletModule = "particle",
    projectileSprite = "assets/sprites/bullets/bulletcyan.png",
    spriteTrailDistance = 5,
    spriteTrailLifetime = 0.11,
    muzzleFlashSprite = "assets/sprites/particles/gunSquare.png",
    impactFlashSprite = "assets/sprites/particles/gunSquare.png",
    projectiles = {
        { angleJitterMin = 0, angleJitterMax = 0.08, angleOffset = 0, offsetDistance = 5 },
        { angleJitterMin = 0, angleJitterMax = 0.08, angleOffset = 0.1, offsetDistance = 5 },
        { angleJitterMin = 0, angleJitterMax = 0.08, angleOffset = -0.1, offsetDistance = 5 }
    }
})
