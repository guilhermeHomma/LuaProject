local Shared = require("scripts/player/weapons/shared")

return Shared.createWeapon({
    id = 1,
    name = "pistol",
    price = 0,
    shotCooldown = 0.5,
    magCount = 12,
    magCapacity = 6,
    reloadDuration = 0.9,
    reloadSpinDuration = 0.25,
    damage = 10,
    bulletSpeed = 300,
    ammoPerShot = 1,
    bulletSize = Shared.bulletSizes.pistol,
    shake = { intensity = 2.4, decay = 0.84 },
    audio = { folder = "pistol", volume = 0.25, loadVolume = 0.35 },
    initialBullet = {
        id = "bulletblue",
        sprite = "assets/sprites/bullets/bulletblue.png",
        soundVolume = 0.2,
    },
    bulletModule = "particle",
    projectileSprite = "assets/sprites/bullets/bulletblue.png",
    bulletGlow = {
        outerColor = {0.15, 1, 0.28, 0.12},
        midColor = {1, 0.08, 0.08, 0.16},
        innerColor = {1, 0.96, 0.82, 0.35}
    },
    projectiles = {
        { angleJitterMin = -0.05, angleJitterMax = 0.05, offsetDistance = 5 }
    }
})
