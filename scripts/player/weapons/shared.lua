local Shared = {}

Shared.bulletSizes = {
    pistol = {
        radius = 0.85,
        spriteTrailScale = 0.85,
    },
    standard = {
        radius = 1.0,
        spriteTrailScale = 1.0,
    },
}

local function copyTable(source)
    local result = {}
    for key, value in pairs(source) do
        if type(value) == "table" then
            result[key] = copyTable(value)
        else
            result[key] = value
        end
    end
    return result
end

local function mergeTables(base, overrides)
    local result = copyTable(base)

    if not overrides then
        return result
    end

    for key, value in pairs(overrides) do
        if type(value) == "table" and type(result[key]) == "table" then
            result[key] = mergeTables(result[key], value)
        else
            result[key] = value
        end
    end

    return result
end

local defaultLineTrail = {
    enabled = true,
    sampleDistance = 10,
    spawnInterval = 0.02,
    pointLifetime = 1.0,
    fadeDelay = 0.12,
    headDelay = 0.04,
    lineWidth = 1.4,
    mainAlpha = 0.28,
    rgbAlpha = 0.18,
    rgbShiftPixels = 1,
    lateralOffset = 2.2,
    directionBias = 0.25,
    turnJitter = 0.7,
    turnInterval = 0.04,
    gapChance = 0.2,
    lineColor = {0.94, 0.98, 1, 1},
    redColor = {1, 0.08, 0.08, 0.85},
    cyanColor = {0.15, 1, 0.28, 0.85},
    glowLineWidth = 8,
    glowAlpha = 0.08,
    headGlowAlpha = 0.18,
    glowColor = {0.68, 0.50, 0.26, 1},
    headOuterColor = {0.15, 1, 0.28, 1},
    headMidColor = {1, 0.08, 0.08, 1},
    headInnerColor = {1, 0.96, 0.82, 1}
}

local defaultWeapon = {
    audio = {
        root = "assets/sfx/gun",
        folder = nil,
        shot = "shot.mp3",
        load = "load.mp3",
        empty = "assets/sfx/gun/empty.mp3",
        volume = 0.35,
        loadVolume = 0.35,
        reloadBulletVolume = 0.06,
        emptyVolume = 0.25,
        pitchMin = 0.96,
        pitchMax = 1.04,
        loadPitchMin = 0.96,
        loadPitchMax = 1.04,
        emptyPitchMin = 0.98,
        emptyPitchMax = 1.05,
    },
    initialBullet = {
        id = "bulletblue",
        module = "particle",
        sprite = "assets/sprites/bullets/bulletblue.png",
        soundRoot = "assets/sfx/bullet",
        sound = "bullet.mp3",
        soundVolume = 0.18,
        soundPitchMin = 0.96,
        soundPitchMax = 1.04,
    },
    reloadDuration = 1,
    reloadSpinDuration = 0.25,
    defaultBulletLifeTime = 0.35,
    shotShockwave = {
        enabled = true,
        duration = 0.43,
        radius = 74,
        width = 16,
        intensity = 4.2,
    },
    impactShockwave = {
        enabled = true,
        duration = 0.3,
        radius = 58,
        width = 13,
        intensity = 3.2,
    },
}

function Shared.createLineTrail(overrides)
    return mergeTables(defaultLineTrail, overrides)
end

function Shared.createWeapon(overrides)
    local weapon = mergeTables(defaultWeapon, overrides)
    if weapon.bulletSize then
        weapon.bulletRadius = weapon.bulletRadius or weapon.bulletSize.radius
        weapon.spriteTrailScale = weapon.spriteTrailScale or weapon.bulletSize.spriteTrailScale
    end
    weapon.audio.folder = weapon.audio.folder or weapon.name
    weapon.bulletModule = weapon.bulletModule or weapon.initialBullet.module
    weapon.projectileSprite = weapon.projectileSprite or weapon.initialBullet.sprite
    weapon.range = weapon.range
        or weapon.initialBullet.range
        or ((weapon.bulletSpeed or 0) * (weapon.initialBullet.lifeTime or weapon.defaultBulletLifeTime))
    return weapon
end

return Shared
