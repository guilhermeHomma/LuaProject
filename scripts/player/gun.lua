local Gun = {}

local weapons = require("scripts/player/weapons/init")
local whiteShader = love.graphics.newShader("scripts/shaders/whiteShader.glsl")
local WalkParticle = require("scripts/particles/walkParticle")
local ShellParticle = require("scripts/particles/shellParticle")
local GunStarDraw = require("scripts/effects/gunStarDraw")
local bulletModules = {
    particle = require("scripts/player/bullets/particleBullet"),
    line = require("scripts/player/bullets/lineBullet")
}

local soundCache = {}

local function copyTable(source)
    local result = {}
    for key, value in pairs(source or {}) do
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

    for key, value in pairs(overrides or {}) do
        if type(value) == "table" and type(result[key]) == "table" then
            result[key] = mergeTables(result[key], value)
        else
            result[key] = value
        end
    end

    return result
end

local function playClonedSound(baseSource, volume, pitch)
    if not baseSource then
        return nil
    end

    local sound = baseSource:clone()
    sound:setVolume(volume)
    sound:setPitch(pitch)
    sound:play()
    return sound
end

local function randomRange(minValue, maxValue)
    if minValue == nil and maxValue == nil then
        return 0
    end

    minValue = minValue or maxValue or 0
    maxValue = maxValue or minValue
    return minValue + math.random() * (maxValue - minValue)
end

local function getSoundSource(path)
    if not path or path == "" then
        return nil
    end

    if soundCache[path] == false then
        return nil
    end

    if soundCache[path] then
        return soundCache[path]
    end

    if love.filesystem and love.filesystem.getInfo and not love.filesystem.getInfo(path) then
        soundCache[path] = false
        return nil
    end

    local ok, source = pcall(love.audio.newSource, path, "static")
    if not ok then
        soundCache[path] = false
        return nil
    end

    soundCache[path] = source
    return source
end

local function playSound(path, volume, pitchMin, pitchMax)
    local source = getSoundSource(path)
    local pitch = randomRange(pitchMin or 0.96, pitchMax or 1.04) * GAME_PITCH
    return playClonedSound(source, volume or 0.3, pitch)
end

local function resolveWeaponSoundPath(weaponConfig, soundKey)
    local audio = weaponConfig.audio or {}
    local file = audio[soundKey]

    if not file or file == "" then
        return nil
    end

    if file:find("/") or file:find("\\") then
        return file
    end

    local root = audio.root or "assets/sfx/gun"
    local folder = audio.folder or weaponConfig.name
    return root .. "/" .. folder .. "/" .. file
end

local function resolveBulletConfig(weaponConfig, bulletOverrides)
    return mergeTables(weaponConfig.initialBullet or {}, bulletOverrides or {})
end

local function resolveBulletSoundPath(bulletConfig)
    if bulletConfig.soundPath then
        return bulletConfig.soundPath
    end

    if not bulletConfig.id then
        return nil
    end

    return (bulletConfig.soundRoot or "assets/sfx/bullet")
        .. "/" .. bulletConfig.id
        .. "/" .. (bulletConfig.sound or "bullet.mp3")
end

local function createWeaponSlot(index, weaponConfig, infiniteAmmo)
    if not weaponConfig then
        return nil
    end

    return {
        index = index,
        config = weaponConfig,
        infiniteAmmo = infiniteAmmo == true,
        currentMagCapacity = weaponConfig.magCapacity or 0,
        currentMagCount = weaponConfig.magCount or 0,
    }
end

local function updateAnimatedShot(shot, dt)
    shot.timer = shot.timer + dt
    shot.x = shot.x + shot.vx * dt
    shot.y = shot.y + shot.vy * dt
    shot.vy = shot.vy + shot.gravity * dt
    if shot.groundOffsetY and shot.startY and shot.y > shot.startY + shot.groundOffsetY then
        shot.y = shot.startY + shot.groundOffsetY
        shot.vy = 0
    end
    local drag = math.max(0, 1 - (shot.drag or 0) * dt)
    shot.vx = shot.vx * drag
    shot.vy = shot.vy * drag
    shot.rotation = shot.rotation + shot.rotationSpeed * dt

    if shot.z then
        shot.z = math.max(0, shot.z + shot.vz * dt)
        shot.vz = shot.vz - shot.zGravity * dt
        shot.vz = shot.vz * drag
        if shot.z == 0 and shot.vz < 0 then
            shot.vz = 0
            shot.vy = 0
        end
    end

    if shot.timer > shot.lifeTime then
        shot.alpha = math.max(0, 1 - ((shot.timer - shot.lifeTime) / shot.fadeTime))
    end

    return shot.timer >= shot.lifeTime + shot.fadeTime
end

function Gun:load()
    self.x = 0
    self.y = 0
    self.size = 16
    self.centerDistance = 0
    self.bullets = {}
    self.weaponDefinitions = weapons
    self.gunSheet = love.graphics.newImage("assets/sprites/player/guns.png")
    self.bulletSheet = love.graphics.newImage("assets/sprites/player/gun-bullet.png")
    self.infinityIcon = love.graphics.newImage("assets/sprites/ui/infinity.png")
    self.gunSheet:setFilter("nearest", "nearest")
    self.bulletSheet:setFilter("nearest", "nearest")
    self.infinityIcon:setFilter("nearest", "nearest")
    self.squareAngle = 0
    self.primary_weapon = createWeaponSlot(1, self:getWeaponConfig(1), true)
    self.secondary_weapon = nil
    self.selected_slot = 1
    self.current_weapon = self.primary_weapon
    self.gunIndex = self.current_weapon and self.current_weapon.index or 0
    self.height = 16
    self.angle = 0

    self.currentMagCapacity = 0
    self.currentMagCount = 0
    self.weaponEventListeners = {}
    self.weaponEvents = {}
    self.uiShotParticles = {}

    self.shootTimer = 0
    self.showGunTime = 0.5
    self.showGun = false
    self.defaultReloadDuration = 1
    self.defaultReloadSpinDuration = 0.25
    self.reloadDuration = self.defaultReloadDuration
    self.reloadSpinDuration = self.defaultReloadSpinDuration
    self.reloadSpinTurns = 2
    self.reloadSpinTimer = 0
    self.reloadTimer = 0
    self.reloadingSlot = nil
    self.reloadSpinStarted = false
    self.reloadFillDuration = 0
    self.reloadFillTimer = 0
    self.reloadFillInterval = 0
    self.reloadFillCount = 0
    self.reloadLoadedCount = 0
    self.reloadMagazineConsumed = false

    self.font = love.graphics.newFont("assets/fonts/ThaleahFat.ttf", 32)
    self.font:setFilter("nearest", "nearest")

    self.particlesshootSheet = love.graphics.newImage("assets/sprites/particles/gunSmoke.png")
    self.particlesshootSheet:setFilter("nearest", "nearest")
    self.particlesTimer = 0
    self.showParticles = false
    self:syncCurrentWeaponState()
    self:emitWeaponEvent("secondary_empty", { slot = 2 })
end

function Gun:getWeaponConfig(index)
    return self.weaponDefinitions[index or self.gunIndex]
end

function Gun:getCurrentWeapon()
    self.current_weapon = self:getSelectedWeaponSlot()
    return self.current_weapon and self.current_weapon.config or nil
end

function Gun:getSelectedWeaponSlot()
    if self.selected_slot == 2 and self.secondary_weapon then
        return self.secondary_weapon
    end

    return self.primary_weapon
end

function Gun:syncCurrentWeaponState()
    self.current_weapon = self:getSelectedWeaponSlot()
    self.gunIndex = self.current_weapon and self.current_weapon.index or 0
    self.currentMagCapacity = self.current_weapon and self.current_weapon.currentMagCapacity or 0
    self.currentMagCount = self.current_weapon and self.current_weapon.currentMagCount or 0
end

function Gun:syncSelectedSlotAmmo()
    local slot = self:getSelectedWeaponSlot()
    if not slot or slot.infiniteAmmo then
        self:syncCurrentWeaponState()
        return
    end

    slot.currentMagCapacity = self.currentMagCapacity
    slot.currentMagCount = self.currentMagCount
    self:syncCurrentWeaponState()
end

function Gun:cancelReload()
    if self.reloadingSlot then
        self.reloadTimer = 0
        self.reloadingSlot = nil
        self.reloadSpinTimer = 0
        self.reloadSpinStarted = false
        self.reloadFillDuration = 0
        self.reloadFillTimer = 0
        self.reloadFillInterval = 0
        self.reloadFillCount = 0
        self.reloadLoadedCount = 0
        self.reloadMagazineConsumed = false
    end
end

function Gun:getWeaponReloadDurations(weaponConfig)
    local spinDuration = weaponConfig.reloadSpinDuration or self.defaultReloadSpinDuration
    local reloadDuration = weaponConfig.reloadDuration or self.defaultReloadDuration
    return math.max(reloadDuration, spinDuration), spinDuration
end

function Gun:getReloadingWeaponSlot()
    if not self.reloadingSlot then
        return nil
    end

    return self.reloadingSlot == 2 and self.secondary_weapon or self.primary_weapon
end

function Gun:consumeReloadMagazine(slot)
    if self.reloadMagazineConsumed or not slot or slot.infiniteAmmo then
        self.reloadMagazineConsumed = self.reloadMagazineConsumed or (slot and slot.infiniteAmmo) == true
        return true
    end

    if slot.currentMagCount <= 0 then
        return false
    end

    slot.currentMagCount = slot.currentMagCount - 1
    self.reloadMagazineConsumed = true
    return true
end

function Gun:playReloadBulletClickSound(weaponConfig)
    local audio = weaponConfig.audio or {}
    playSound(
        resolveWeaponSoundPath(weaponConfig, "load"),
        audio.reloadBulletVolume or 0.06,
        audio.reloadBulletPitchMin or audio.loadPitchMin or audio.pitchMin,
        audio.reloadBulletPitchMax or audio.loadPitchMax or audio.pitchMax
    )
end

function Gun:addReloadBullet(slot, weaponConfig, playClick)
    if not slot or slot.currentMagCapacity >= weaponConfig.magCapacity then
        return false
    end

    if not self:consumeReloadMagazine(slot) then
        return false
    end

    slot.currentMagCapacity = math.min(weaponConfig.magCapacity, slot.currentMagCapacity + 1)
    self:syncCurrentWeaponState()
    self:emitWeaponEvent("ammo_changed", {
        slot = self.selected_slot,
        weapon = weaponConfig,
        currentMagCapacity = self.currentMagCapacity,
        currentMagCount = self.currentMagCount,
    })

    if playClick then
        self:playReloadBulletClickSound(weaponConfig)
    end

    return true
end

function Gun:finishReloadFill(playClick)
    local slot = self:getReloadingWeaponSlot()
    if not slot then
        return
    end

    local weaponConfig = slot.config
    while self.reloadLoadedCount < self.reloadFillCount do
        if not self:addReloadBullet(slot, weaponConfig, playClick) then
            break
        end
        self.reloadLoadedCount = self.reloadLoadedCount + 1
    end
end

function Gun:startReloadSpin(weaponConfig)
    if self.reloadSpinStarted then
        return
    end

    self.reloadSpinStarted = true
    self.reloadSpinTimer = self.reloadSpinDuration
    self:playReloadClickSound(weaponConfig)
end

function Gun:startReload(slot, weaponConfig)
    if not slot or self.reloadingSlot then
        return false
    end

    if not slot.infiniteAmmo and slot.currentMagCount <= 0 then
        return false
    end

    local reloadDuration, spinDuration = self:getWeaponReloadDurations(weaponConfig)
    local missingBullets = math.max(0, (weaponConfig.magCapacity or 0) - (slot.currentMagCapacity or 0))
    if missingBullets <= 0 then
        return false
    end

    self.reloadingSlot = self.selected_slot
    self.reloadDuration = reloadDuration
    self.reloadSpinDuration = spinDuration
    self.reloadTimer = reloadDuration
    self.reloadSpinTimer = 0
    self.reloadSpinStarted = false
    self.reloadFillDuration = reloadDuration - spinDuration
    self.reloadFillTimer = 0
    self.reloadFillCount = missingBullets
    self.reloadLoadedCount = 0
    self.reloadMagazineConsumed = slot.infiniteAmmo == true
    self.reloadFillInterval = self.reloadFillDuration > 0 and (self.reloadFillDuration / missingBullets) or 0
    self.showGun = true

    if self.reloadFillDuration <= 0 then
        self:finishReloadFill(false)
        self:startReloadSpin(weaponConfig)
    end

    return true
end

function Gun:finishReload()
    if not self.reloadingSlot then
        return
    end

    self:finishReloadFill(false)

    local slot = self:getReloadingWeaponSlot()
    self.reloadingSlot = nil
    self.reloadTimer = 0
    self.reloadSpinTimer = 0
    self.reloadSpinStarted = false
    self.reloadFillDuration = 0
    self.reloadFillTimer = 0
    self.reloadFillInterval = 0
    self.reloadFillCount = 0
    self.reloadLoadedCount = 0
    self.reloadMagazineConsumed = false

    if not slot then
        self:syncCurrentWeaponState()
        return
    end

    local weaponConfig = slot.config
    self:syncCurrentWeaponState()
    self:emitWeaponEvent("ammo_changed", {
        slot = self.selected_slot,
        weapon = weaponConfig,
        currentMagCapacity = self.currentMagCapacity,
        currentMagCount = self.currentMagCount,
    })
end

function Gun:onWeaponEvent(eventName, callback)
    if type(callback) ~= "function" then
        return
    end

    self.weaponEventListeners[eventName] = self.weaponEventListeners[eventName] or {}
    table.insert(self.weaponEventListeners[eventName], callback)
end

function Gun:emitWeaponEvent(eventName, payload)
    payload = payload or {}
    payload.name = eventName
    self.weaponEvents[#self.weaponEvents + 1] = payload

    for _, callback in ipairs(self.weaponEventListeners[eventName] or {}) do
        callback(payload)
    end
end

function Gun:selectSlot(slot)
    if slot == 2 and not self.secondary_weapon then
        slot = 1
    end

    if slot ~= 1 and slot ~= 2 then
        return false
    end

    if self.selected_slot == slot then
        self:syncCurrentWeaponState()
        return true
    end

    self:cancelReload()
    self.selected_slot = slot
    self.showGun = true
    self.shootTimer = 0.15 - math.random() * 0.08
    self:syncCurrentWeaponState()
    self:emitWeaponEvent("weapon_selected", {
        slot = self.selected_slot,
        weapon = self.current_weapon and self.current_weapon.config,
    })
    return true
end

function Gun:toggleWeaponSlot()
    if self.selected_slot == 1 and self.secondary_weapon then
        return self:selectSlot(2)
    end

    return self:selectSlot(1)
end

function Gun:equipSecondaryWeapon(index)
    if self.primary_weapon and index == self.primary_weapon.index then
        self:selectSlot(1)
        return false
    end

    local weaponConfig = self:getWeaponConfig(index)
    if not weaponConfig then
        return false
    end

    DisableXTutorial()

    self:cancelReload()
    self.secondary_weapon = createWeaponSlot(index, weaponConfig, false)
    self.selected_slot = 2
    self.showGun = true
    self.shootTimer = 0.2 - math.random() * 0.1
    self.reloadSpinTimer = 0
    self:syncCurrentWeaponState()
    self:emitWeaponEvent("secondary_equipped", { slot = 2, weapon = weaponConfig })
    self:emitWeaponEvent("weapon_selected", { slot = 2, weapon = weaponConfig })
    self:emitWeaponEvent("ammo_changed", {
        slot = 2,
        weapon = weaponConfig,
        currentMagCapacity = self.currentMagCapacity,
        currentMagCount = self.currentMagCount,
    })
    return true
end

function Gun:getSecondaryWeapon()
    return self.secondary_weapon and self.secondary_weapon.config or nil
end

function Gun:getSecondaryAmmo()
    if not self.secondary_weapon then
        return nil
    end

    return {
        currentMagCapacity = self.secondary_weapon.currentMagCapacity,
        currentMagCount = self.secondary_weapon.currentMagCount,
        magCapacity = self.secondary_weapon.config.magCapacity,
        magCount = self.secondary_weapon.config.magCount,
    }
end

function Gun:update(dt, playerX, playerY)
    self.x = playerX
    self.y = playerY
    self.angle = math.floor(mouseAngle() * 6) / 6
    self.squareAngle = self.squareAngle + 0.8 * dt
    self.shootTimer = self.shootTimer + dt
    self.particlesTimer = self.particlesTimer + dt
    if self.reloadingSlot then
        self.reloadTimer = math.max(0, self.reloadTimer - dt)
        local slot = self:getReloadingWeaponSlot()
        local weaponConfig = slot and slot.config
        local spinStartTime = self.reloadSpinDuration

        if slot and weaponConfig and self.reloadFillDuration > 0 and not self.reloadSpinStarted then
            self.reloadFillTimer = self.reloadFillTimer + dt
            while self.reloadLoadedCount < self.reloadFillCount
                and self.reloadFillTimer >= self.reloadFillInterval
            do
                self.reloadFillTimer = self.reloadFillTimer - self.reloadFillInterval
                if not self:addReloadBullet(slot, weaponConfig, true) then
                    break
                end
                self.reloadLoadedCount = self.reloadLoadedCount + 1
            end
        end

        if not self.reloadSpinStarted and self.reloadTimer <= spinStartTime then
            self:finishReloadFill(false)
            self:startReloadSpin(weaponConfig)
        end

        if self.reloadTimer <= 0 then
            self:finishReload()
        end
    else
        self.reloadSpinTimer = math.max(0, self.reloadSpinTimer - dt)
    end

    if self.reloadingSlot and self.reloadSpinStarted then
        self.reloadSpinTimer = math.max(0, self.reloadSpinTimer - dt)
    end

    if self.reloadingSlot then
        self.showGun = true
    elseif self.shootTimer >= self.showGunTime then
        self.showGun = false
    end

    if not Dialog.breakMovements then
        if love.mouse.isDown(2) then
            self:aim()
        end

        if love.mouse.isDown(1) then
            self:shoot()
        end
    end

    for i = #self.bullets, 1, -1 do
        local bullet = self.bullets[i]
        bullet:update(dt)
        if not bullet.isAlive then
            table.remove(self.bullets, i)
        end
    end

    for i = #self.uiShotParticles, 1, -1 do
        if updateAnimatedShot(self.uiShotParticles[i], dt) then
            table.remove(self.uiShotParticles, i)
        end
    end

end

function Gun:showshootParticles()
    self.particlesTimer = 0
    self.showParticles = true
end

function Gun:createBullet(spawnX, spawnY, angle, height, weaponConfig, bulletOverrides)
    local bulletConfig = resolveBulletConfig(weaponConfig, bulletOverrides)
    local bulletModule = bulletModules[bulletConfig.module or weaponConfig.bulletModule or "particle"]
    local bullet = bulletModule:new(
        spawnX,
        spawnY,
        angle,
        height or self.height,
        weaponConfig.bulletSpeed,
        weaponConfig.damage,
        {
            level = bulletConfig.level,
            radius = bulletConfig.radius or weaponConfig.bulletRadius,
            lifeTime = bulletConfig.lifeTime,
            trail = bulletConfig.trail or weaponConfig.bulletTrail,
            glow = bulletConfig.glow or weaponConfig.bulletGlow,
            projectileSprite = bulletConfig.projectileSprite or bulletConfig.sprite or weaponConfig.projectileSprite,
            spriteTrailDistance = bulletConfig.spriteTrailDistance or weaponConfig.spriteTrailDistance,
            spriteTrailLifetime = bulletConfig.spriteTrailLifetime or weaponConfig.spriteTrailLifetime,
            spriteTrailScale = bulletConfig.spriteTrailScale or weaponConfig.spriteTrailScale,
            spriteTrailMaxPerUpdate = bulletConfig.spriteTrailMaxPerUpdate or weaponConfig.spriteTrailMaxPerUpdate,
            impactFlashSprite = bulletConfig.impactFlashSprite or weaponConfig.impactFlashSprite,
            impactShockwave = bulletConfig.impactShockwave or weaponConfig.impactShockwave
        }
    )

    table.insert(self.bullets, bullet)
    return bullet
end

function Gun:spawnMuzzleParticle(angle, offsetDistance)
    local offsetX = math.cos(angle) * (offsetDistance or 5)
    local offsetY = math.sin(angle) * (offsetDistance or 5)
    local lifetime = math.random(45, 55) / 100
    local particle = WalkParticle:new(self.x + offsetX * 2.5, self.y + offsetY * 2.5 - self.height, lifetime)
    table.insert(Game.particles, particle)
end

function Gun:spawnHudShotParticle(slotIndex)
    local bulletUIX = 12
    local bulletUIY = 81 + slotIndex * 18

    self.uiShotParticles[#self.uiShotParticles + 1] = {
        x = bulletUIX,
        y = bulletUIY,
        vx = 148 + math.random() * 36,
        vy = -140 - math.random() * 28,
        gravity = 1240,
        drag = 2.4,
        rotation = 0,
        rotationSpeed = 8.5 + math.random() * 2.5,
        flashTime = 0.08,
        alpha = 1,
        timer = 0,
        lifeTime = 0.5,
        fadeTime = 0.2,
        scale = 3,
        originX = 2,
        originY = 1,
    }
end

function Gun:spawnWorldShotParticle(angle)
    local spawnDistance = self.centerDistance + 7
    local spawnX = self.x + math.cos(angle) * spawnDistance
    local spawnY = self.y + math.sin(angle) * spawnDistance - self.height

    local particle = ShellParticle:new(spawnX, spawnY, angle, {
        flashTime = 0.05,
        color = {0.5, 0.5, 0.5},
        fadeTime = 2,
        scale = 0.55,
        originX = 2,
        originY = 1,
    })
    table.insert(Game.particles, particle)
end

function Gun:spawnShotShockwave(angle, weaponConfig)
    local shockwave = weaponConfig and weaponConfig.shotShockwave
    if not (shockwave and shockwave.enabled ~= false and Game and Game.addWeaponShockwave) then
        return
    end

    local spawnDistance = self.centerDistance + 11
    local spawnX = self.x + math.cos(angle) * spawnDistance
    local spawnY = self.y + math.sin(angle) * spawnDistance - self.height
    Game:addWeaponShockwave(spawnX, spawnY, shockwave)
end

function Gun:spawnShotParticles(ammoSpent, previousMagCapacity, angle)
    for index = 0, ammoSpent - 1 do
        local slotIndex = previousMagCapacity - index
        if slotIndex > 0 then
            self:spawnHudShotParticle(slotIndex)
        end
    end

    self:spawnWorldShotParticle(angle)
    local weaponConfig = self:getCurrentWeapon()
    self:spawnShotShockwave(angle, weaponConfig)
end

function Gun:playWeaponShotSound(weaponConfig)
    local audio = weaponConfig.audio or {}
    playSound(
        resolveWeaponSoundPath(weaponConfig, "shot"),
        audio.volume,
        audio.pitchMin,
        audio.pitchMax
    )
end

function Gun:playBulletShotSound(bulletConfig)
    playSound(
        resolveBulletSoundPath(bulletConfig),
        bulletConfig.soundVolume,
        bulletConfig.soundPitchMin,
        bulletConfig.soundPitchMax
    )
end

function Gun:applyWeaponShake(weaponConfig)
    camera:shake(weaponConfig.shake.intensity, weaponConfig.shake.decay)
end

function Gun:fireWeaponProjectiles(weaponConfig)
    local baseAngle = mouseAngle()
    local previousMagCapacity = self.currentMagCapacity
    local selectedWeapon = self:getSelectedWeaponSlot()
    local ammoSpent = math.min(weaponConfig.ammoPerShot, previousMagCapacity)

    for _, projectile in ipairs(weaponConfig.projectiles) do
        local bulletConfig = resolveBulletConfig(weaponConfig, projectile.bullet)
        local shotAngle = baseAngle
            + (projectile.angleOffset or 0)
            + randomRange(projectile.angleJitterMin, projectile.angleJitterMax)
        local spawnDistance = projectile.offsetDistance or 5
        local spawnX = self.x + math.cos(shotAngle) * spawnDistance + (projectile.spawnOffsetX or 0)
        local spawnY = self.y + math.sin(shotAngle) * spawnDistance + (projectile.spawnOffsetY or 0)

        self:createBullet(
            spawnX,
            spawnY,
            shotAngle,
            projectile.height or self.height,
            weaponConfig,
            bulletConfig
        )
        self:playBulletShotSound(bulletConfig)
    end

    self.currentMagCapacity = math.max(0, self.currentMagCapacity - weaponConfig.ammoPerShot)
    selectedWeapon.currentMagCapacity = self.currentMagCapacity
    selectedWeapon.currentMagCount = self.currentMagCount
    self:emitWeaponEvent("ammo_changed", {
        slot = self.selected_slot,
        weapon = weaponConfig,
        currentMagCapacity = self.currentMagCapacity,
        currentMagCount = self.currentMagCount,
    })
    self:spawnShotParticles(ammoSpent, previousMagCapacity, baseAngle)
    self:playWeaponShotSound(weaponConfig)
    self:spawnMuzzleParticle(baseAngle, 5)
end

function Gun:playReloadClickSound(weaponConfig)
    local audio = weaponConfig.audio or {}
    playSound(
        resolveWeaponSoundPath(weaponConfig, "load"),
        audio.loadVolume or audio.volume,
        audio.loadPitchMin or audio.pitchMin,
        audio.loadPitchMax or audio.pitchMax
    )
end

function Gun:playEmptyClickSound(weaponConfig)
    local audio = weaponConfig.audio or {}
    playSound(
        audio.empty or "assets/sfx/gun/empty.mp3",
        audio.emptyVolume,
        audio.emptyPitchMin,
        audio.emptyPitchMax
    )
end

function Gun:shoot()
    DisableMouseTutorial()

    local weaponConfig = self:getCurrentWeapon()
    if not weaponConfig then return end

    if weaponConfig.shotCooldown >= self.shootTimer then return end
    if self.reloadingSlot then return end

    self.showGun = true
    self.shootTimer = 0 - math.random() * 0.1
    local selectedWeapon = self:getSelectedWeaponSlot()

    if self.currentMagCapacity > 0 then
        self:fireWeaponProjectiles(weaponConfig)
        self:applyWeaponShake(weaponConfig)
        self:showshootParticles()
    elseif selectedWeapon and self:startReload(selectedWeapon, weaponConfig) then
        self.shootTimer = self.shootTimer + self.reloadDuration
    else
        self:playEmptyClickSound(weaponConfig)
        self:emitWeaponEvent("secondary_empty_ammo", { slot = self.selected_slot, weapon = weaponConfig })
    end
end

function Gun:aim()
    if not self:getSelectedWeaponSlot() then return end
    self.showGun = true
    self.showSight = true
end

function Gun:isFullBullets()
    local weapon = self.secondary_weapon
    if not weapon then return true end
    local weaponConfig = weapon.config

    return weapon.currentMagCapacity == weaponConfig.magCapacity
        and weapon.currentMagCount == weaponConfig.magCount
end

function Gun:canFillCurrentMagazine()
    local weapon = self.secondary_weapon
    if not weapon then return false end
    local weaponConfig = weapon.config

    return weapon.currentMagCapacity < weaponConfig.magCapacity
        or weapon.currentMagCount < weaponConfig.magCount
end

function Gun:fillCurrentMagazine()
    local weapon = self.secondary_weapon
    if not weapon then return false end
    local weaponConfig = weapon.config

    self:cancelReload()

    if weapon.currentMagCount < weaponConfig.magCount then
        weapon.currentMagCount = math.min(weaponConfig.magCount, weapon.currentMagCount + 1)
    elseif weapon.currentMagCapacity < weaponConfig.magCapacity then
        weapon.currentMagCapacity = weaponConfig.magCapacity
    else
        return false
    end

    self.reloadSpinTimer = 0
    self:syncCurrentWeaponState()
    self:emitWeaponEvent("ammo_changed", {
        slot = 2,
        weapon = weaponConfig,
        currentMagCapacity = weapon.currentMagCapacity,
        currentMagCount = weapon.currentMagCount,
    })
    return true
end

function Gun:fillSecondaryWeaponToMax()
    local weapon = self.secondary_weapon
    if not weapon then return false end
    local weaponConfig = weapon.config

    self:cancelReload()
    weapon.currentMagCapacity = weaponConfig.magCapacity
    weapon.currentMagCount = weaponConfig.magCount
    self.reloadSpinTimer = 0
    self:syncCurrentWeaponState()
    self:emitWeaponEvent("ammo_changed", {
        slot = 2,
        weapon = weaponConfig,
        currentMagCapacity = weapon.currentMagCapacity,
        currentMagCount = weapon.currentMagCount,
    })
    return true
end

function Gun:changeGun(index)
    return self:equipSecondaryWeapon(index)
end

function Gun:drawSight()
    if not self:getSelectedWeaponSlot() then return end
    if not self.showSight then return end

    self.showSight = false
    local mouseX, mouseY = mousePosition()
    love.graphics.setColor(0.274, 0.4, 0.45, 1)
    Player:drawSquare(mouseX, mouseY, self.squareAngle * 3.5, 3)
end

function Gun:drawParticles()
    local frameDuration = 0.03
    local totalFrames = 5

    if self.particlesTimer > frameDuration * totalFrames then return end

    local frameIndex = math.floor(self.particlesTimer / frameDuration) % totalFrames
    local quad = love.graphics.newQuad(
        frameIndex * 16,
        0,
        16,
        16,
        self.particlesshootSheet:getDimensions()
    )

    local offsetX = math.cos(self.angle) * (self.centerDistance + 11)
    local offsetY = math.sin(self.angle) * (self.centerDistance + 11)
    local particleX = self.x + offsetX
    local particleY = self.y + offsetY - self.height

    for i = 1, 0, -0.5 do
        love.graphics.draw(
            self.particlesshootSheet,
            quad,
            particleX,
            particleY + i,
            self.angle,
            1,
            1,
            0,
            self.size / 2
        )
    end

    local weaponConfig = self:getCurrentWeapon()
    GunStarDraw.draw(particleX, particleY, frameIndex, 1, 1, weaponConfig and weaponConfig.muzzleFlashSprite)
end

function Gun:drawUI()
    local size = 40
    local startX = 13.5
    local startY = 10.5
    local line = 3
    local weaponConfig = self:getCurrentWeapon()
    local slotGap = 48
    local function drawSlotBox(slotIndex, hasWeapon)
        local x = startX + (slotIndex - 1) * slotGap
        love.graphics.setLineWidth(line)
        love.graphics.setColor(hexToRGB("090909"))
        love.graphics.rectangle("line", x + line, startY + line, size, size)
        if self.selected_slot == slotIndex then
            love.graphics.setColor(1, 1, 1, 1)
        elseif hasWeapon then
            love.graphics.setColor(0.55, 0.55, 0.55, 1)
        else
            love.graphics.setColor(0.28, 0.28, 0.28, 1)
        end
        love.graphics.rectangle("line", x, startY, size, size)
        love.graphics.setLineWidth(1)
    end

    drawSlotBox(1, self.primary_weapon ~= nil)
    drawSlotBox(2, self.secondary_weapon ~= nil)

    if not weaponConfig then return end

    love.graphics.setFont(self.font)
    for slotIndex, weapon in ipairs({self.primary_weapon, self.secondary_weapon}) do
        if weapon then
            local quad = love.graphics.newQuad(
                (weapon.index - 1) * self.size,
                16,
                self.size,
                self.size,
                self.gunSheet:getDimensions()
            )
            love.graphics.setColor(slotIndex == self.selected_slot and 1 or 0.65, slotIndex == self.selected_slot and 1 or 0.65, slotIndex == self.selected_slot and 1 or 0.65, 1)
            love.graphics.draw(self.gunSheet, quad, 20 + (slotIndex - 1) * slotGap, 40, 0, 3, 3, 0, self.size / 2)
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
    local currentSlot = self:getSelectedWeaponSlot()
    if not (currentSlot and currentSlot.infiniteAmmo) then
        local text = self.currentMagCount .. "/" .. weaponConfig.magCount
        love.graphics.print(text, 130, 27)
    end

    local bulletUIX = 12
    local bulletUIY = 81

    local fullQuad = love.graphics.newQuad(0, 0, self.size, self.size, self.bulletSheet:getDimensions())
    local emptyQuad = love.graphics.newQuad(self.size, 0, self.size, self.size, self.bulletSheet:getDimensions())

    for i = 1, weaponConfig.magCapacity do
        love.graphics.draw(self.bulletSheet, emptyQuad, bulletUIX, bulletUIY + i * 18, 0, 3, 3, 0, 0)

        if i <= self.currentMagCapacity then
            love.graphics.draw(self.bulletSheet, fullQuad, bulletUIX, bulletUIY + i * 18, 0, 3, 3, 0, 0)
        end
    end

    for _, shot in ipairs(self.uiShotParticles) do
        love.graphics.setColor(1, 1, 1, shot.alpha)
        if shot.timer <= (shot.flashTime or 0) then
            love.graphics.setShader(whiteShader)
        end
        love.graphics.draw(
            self.bulletSheet,
            fullQuad,
            shot.x + shot.originX * shot.scale,
            shot.y + shot.originY * shot.scale,
            shot.rotation,
            shot.scale,
            shot.scale,
            shot.originX,
            shot.originY
        )
        love.graphics.setShader()
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function Gun:draw()
    if not self:getSelectedWeaponSlot() then return end

    self:drawParticles()

    local quad = love.graphics.newQuad(
        (self.gunIndex - 1) * self.size,
        0,
        self.size,
        self.size,
        self.gunSheet:getDimensions()
    )

    local offsetX = math.cos(self.angle) * self.centerDistance
    local offsetY = math.sin(self.angle) * self.centerDistance
    if self.shootTimer <= 0.01 then
        love.graphics.setShader(whiteShader)
    end

    local drawAngle = self.angle
    if self.reloadSpinTimer > 0 then
        local progress = 1 - self.reloadSpinTimer / self.reloadSpinDuration
        drawAngle = drawAngle + progress * self.reloadSpinTurns * math.pi * 2
    end

    local drawX = self.x + offsetX
    local drawY = self.y + offsetY - self.height
    local originX = 0
    local originY = self.size / 2

    if self.reloadSpinTimer > 0 then
        originX = self.size / 2
        originY = self.size / 2
        drawX = drawX + math.cos(self.angle) * 3
        drawY = drawY + math.sin(self.angle) * 3
    end

    for i = 2, 0, -0.5 do
        love.graphics.draw(
            self.gunSheet,
            quad,
            drawX,
            drawY + i,
            drawAngle,
            0.8,
            0.8,
            originX,
            originY
        )
    end

    love.graphics.setShader()
    love.graphics.setColor(1, 1, 1, 1)
end

return Gun
