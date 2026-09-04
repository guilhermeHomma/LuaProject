local Shared = require("scripts/player/weapons/shared")

return Shared.createWeapon({
    id = 7,
    name = "pistolinha",
    spriteIndex = 1,
    price = 0,
    shotCooldown = 0.4,
    magCount = 9,
    magCapacity = 9,
    reloadDuration = 0.8,
    reloadSpinDuration = 0.25,
    damage = 3,
    bulletSpeed = 210,
    ammoPerShot = 3,
    bulletSize = {
        radius = Shared.bulletSizes.pistol.radius * 0.8,
        spriteTrailScale = Shared.bulletSizes.pistol.spriteTrailScale * 0.8,
    },
    shake = { intensity = 2.0, decay = 0.86 },
    audio = { folder = "pistol", volume = 0.22, loadVolume = 0.3, pitchMin = 1.08, pitchMax = 1.16 },
    initialBullet = {
        id = "bulletblue",
        sprite = "assets/sprites/bullets/bulletblue.png",
        soundVolume = 0.16,
    },
    bulletModule = "particle",
    projectileSprite = "assets/sprites/bullets/bulletblue.png",
    projectiles = {
        { angleOffset = -0.24, angleJitterMin = -0.09, angleJitterMax = 0.09, offsetDistance = 5 },
        { angleOffset = 0, angleJitterMin = -0.09, angleJitterMax = 0.09, offsetDistance = 5 },
        { angleOffset = 0.24, angleJitterMin = -0.09, angleJitterMax = 0.09, offsetDistance = 5 },
    },
})
