Zombie = require("scripts/enemies/zombie")
local Tilemap = require("scripts/tilemap")
local NoHeadBullet = require("scripts/enemies/noHeadBullet")

BigZombie = setmetatable({}, {__index = Zombie})
BigZombie.__index = BigZombie
BigZombie.enemyTypeId = "bigZombie"

local damageBase = love.audio.newSource("assets/sfx/enemyDamage.mp3", "static")
local heavyFootstepBase = love.audio.newSource("assets/sfx/footsteps/foot-steps-1.mp3", "static")
local impactBase = love.audio.newSource("assets/sfx/enemies/impact.mp3", "static")
local DamageStretch = require("scripts/effects/damageStretch")
local BloodPixel = require("scripts/particles/bloodPixel")
local BloodDecal = require("scripts/particles/bloodDecal")
local BulletColorParticle = require("scripts/particles/bulletColorParticle")

local tileSize = 16
local rushConfig = {
    alignDistance = tileSize * 7,
    alignThreshold = 8,
    prepareDuration = 0.5,
    stunDuration = 1.12,
    maxDistanceMin = tileSize * 13,
    maxDistanceMax = tileSize * 15,
    speed = 135,
    coastDistance = tileSize,
    coastDuration = 0.26,
    cooldown = 5,
    animationMultiplier = 1.2,
    particleInterval = 0.028,
    footstepSoundInterval = 0.115,
    facingDeadzone = 6,
    facingLockTime = 0.16,
    impactShotCount = 5,
    impactShotSpread = math.rad(150),
    impactShotSpeed = 125,
    impactShotDamage = 1,
    impactShotTileDamage = 8,
    impactShotLifeTime = 2.9,
    impactShotSpawnOffset = 18,
}

local rushPalette = {
    {0.70, 0.70, 0.66, 1},
    {0.58, 0.58, 0.54, 1},
    {0.78, 0.76, 0.68, 1},
    {0.46, 0.46, 0.42, 1},
}

local stunParticlePalette = {
    {0.96, 0.95, 0.88, 1},
    {0.82, 0.78, 0.56, 1},
    {1.00, 1.00, 0.96, 1},
}

local impactDustPalette = {
    {0.76, 0.74, 0.66, 1},
    {0.58, 0.57, 0.52, 1},
    {0.44, 0.43, 0.39, 1},
    {0.84, 0.80, 0.68, 1},
}

local function isBoxTile(tile)
    return tile and (tile.quadIndex == 14 or tile.quadIndex == 18)
end

local function playClonedSound(baseSource, volume, pitch)
    local sound = baseSource:clone()
    sound:setVolume(volume)
    sound:setPitch(pitch)
    sound:play()
    return sound
end

local function getCameraDistance(object)
    if not (camera and camera.objectPosition) then
        return nil
    end

    return distance(camera:objectPosition(), object)
end

local function normalizeVector(x, y)
    local length = math.sqrt(x * x + y * y)
    if length <= 0 then
        return 0, 0
    end

    return x / length, y / length
end

function BigZombie:new(x, y)
    local zombie = Zombie.new(self, x, y)
    zombie.speed = math.random(57, 68)
    zombie.damageTimer = 0.1
    zombie.totalLife = 65
    zombie.life = zombie.totalLife
    zombie.footStepAlpha = 0.7
    zombie.roamAroundPlayer = false
    zombie.rushState = "seeking"
    zombie.rushCooldown = math.random(65, 70) / 100
    zombie.rushParticleTimer = 0
    zombie.rushFootstepSoundTimer = 0
    zombie.rushTravel = 0
    zombie.rushDirX = 0
    zombie.rushDirY = 0
    zombie.rushPrepareTimer = 0
    zombie.rushStunTimer = 0
    zombie.rushCoastTimer = 0
    zombie.rushCoastTravel = 0
    zombie.rushPendingDirX = 0
    zombie.rushPendingDirY = 0
    zombie.rushFacingLockTimer = 0
    return zombie
end

function BigZombie:getSprite()
    return Zombie.getSprite(self)
end

function BigZombie:getSpriteKey()
    return "assets/sprites/enemy/bigzombie/spritesheet.png"
end

function BigZombie:takeDamage(damage, dx, dy)
    self.lastDamageDx = dx
    self.lastDamageDy = dy
    self.life = self.life - damage
    BloodPixel.spawnBurst(self.x, self.y - 2, dx, dy, 4, 6)
    if self.life > 0 then
        BloodDecal.spawn(self.x, self.y, dx, dy, {
            scaleMultiplier = 0.5,
            volumeMultiplier = 0.5,
            pitchMultiplier = 0.72,
        })
    else
        self:spawnDeathBloodDecal()
    end

    if self.rushState == "preparing" or self.rushState == "rushing" or self.rushState == "rushEnding" or self.rushState == "stunned" then
        self.whiteFlashTimer = self.whiteFlashDuration
        self.glitchTimer = math.max(self.glitchTimer or 0, 0.08)
        if self.soundTimer <= 1 then
            self.soundTimer = 1.1
        end
        playClonedSound(damageBase, 1.05, (0.9 + math.random() * 0.1) * GAME_PITCH)
        return
    end

    if self:canStartDamageAnimation() then
        DamageStretch:start(self)
        self.animationTimer = 0.3
        self.state = BigZombie.states.damage
        self.stateTimer = 0
        self.kbdx = dx
        self.kbdy = dy 
        self.noise:stop()
        
        if self.soundTimer <= 1 then
            self.soundTimer = 1.1
        end
        playClonedSound(damageBase, 1.2, (0.9 + math.random() * 0.1) * GAME_PITCH)
    end
end

function BigZombie:getMovementTarget(dt)
    if not Player.isAlive then
        return Zombie.getMovementTarget(self, dt)
    end

    if self.rushState == "rushing" then
        return Player.x, Player.y
    end

    return Player.x, Player.y
end

function BigZombie:getRushDirection()
    if not Player.isAlive then
        return nil
    end

    local dx = Player.x - self.x
    local dy = Player.y - self.y
    local absX = math.abs(dx)
    local absY = math.abs(dy)
    local nearHorizontalLine = absY <= rushConfig.alignThreshold and absX <= rushConfig.alignDistance
    local nearVerticalLine = absX <= rushConfig.alignThreshold and absY <= rushConfig.alignDistance

    if nearHorizontalLine and absX > tileSize * 0.75 then
        return dx > 0 and 1 or -1, 0
    elseif nearVerticalLine and absY > tileSize * 0.75 then
        return 0, dy > 0 and 1 or -1
    end

    return nil
end

function BigZombie:updateRushFacing(dt, force)
    self.rushFacingLockTimer = math.max(0, (self.rushFacingLockTimer or 0) - dt)

    if not Player.isAlive then
        return
    end

    local dx = Player.x - self.x
    if math.abs(dx) <= rushConfig.facingDeadzone then
        return
    end

    local targetFlip = dx > 0
    if self.flipH == targetFlip then
        return
    end

    if force or self.rushFacingLockTimer <= 0 then
        self.flipH = targetFlip
        self.rushFacingLockTimer = rushConfig.facingLockTime
    end
end

function BigZombie:startRushPrepare(dirX, dirY)
    self.rushState = "preparing"
    self.rushPrepareTimer = 0
    self.rushPendingDirX = dirX
    self.rushPendingDirY = dirY
    self.state = Zombie.states.idle
    self.stateTimer = 0
    self.currentFrame = 15
    self.animationTimer = 0
    self.path = nil
    self.pathUpdateCounter = self.pathUpdateInterval
    self.noise:stop()
    self:updateRushFacing(0, true)
end

function BigZombie:startRush(dirX, dirY)
    self.rushState = "rushing"
    self.rushDirX = dirX
    self.rushDirY = dirY
    self.rushTravel = 0
    self.rushMaxDistance = math.random(rushConfig.maxDistanceMin, rushConfig.maxDistanceMax)
    self.rushParticleTimer = 0
    self.rushFootstepSoundTimer = rushConfig.footstepSoundInterval
    self.rushCooldown = rushConfig.cooldown
    self.rushLockedFlipH = self.flipH
    self.state = Zombie.states.walk
    self.stateTimer = 0
    self.path = nil
    self.pathUpdateCounter = self.pathUpdateInterval
    self.noise:stop()
    self:updateRushFacing(0, true)
end

function BigZombie:playFootstepSound(playerDistance)
    return self.rushState == "rushing"
end

function BigZombie:updateRushFootstepSound(dt)
    self.rushFootstepSoundTimer = (self.rushFootstepSoundTimer or 0) + dt
    if self.rushFootstepSoundTimer < rushConfig.footstepSoundInterval then
        return
    end

    self.rushFootstepSoundTimer = self.rushFootstepSoundTimer - rushConfig.footstepSoundInterval

    local playerDistance = distance(Player, self)
    if playerDistance > 420 then
        return
    end

    local volume = math.max(0.34, getDistanceVolume(playerDistance, 1.0, 420))
    playClonedSound(heavyFootstepBase, volume, (0.34 + math.random() * 0.12) * GAME_PITCH)

    if camera and playerDistance <= 190 then
        camera:shake(0.7, 0.66)
    end
end

function BigZombie:spawnRushImpactFeedback()
    local playerDistance = distance(Player, self)
    local volume = getDistanceVolume(playerDistance, 1.05, 360)

    playClonedSound(impactBase, volume, (0.74 + math.random() * 0.12) * GAME_PITCH)
    BulletColorParticle.spawnBurst(self.x, self.y - 2, 1, impactDustPalette, 18, {
        speedMin = 16,
        speedMax = 46,
        lifeTime = 0.42 + math.random() * 0.16,
        size = 1,
        alpha = 0.86,
        fadeOut = true,
    })

    if Game and Game.addWeaponShockwave then
        Game:addWeaponShockwave(self.x, self.y - 8, {
            duration = 0.44,
            radius = 42,
            width = 9,
            intensity = 1.85,
        })
    end

    local shakeDistance = getCameraDistance(self) or playerDistance
    if camera and shakeDistance <= 420 then
        camera:shake(6.0, 0.78)
    end

    self.whiteFlashTimer = math.max(self.whiteFlashTimer or 0, 0.08)
    self.glitchTimer = math.max(self.glitchTimer or 0, 0.1)
end

function BigZombie:spawnRushImpactShots(awayX, awayY)
    awayX, awayY = normalizeVector(awayX or 0, awayY or 0)
    if awayX == 0 and awayY == 0 then
        return
    end

    local baseAngle = math.atan2(awayY, awayX)
    local originX = self.x + awayX * rushConfig.impactShotSpawnOffset
    local originY = self.y + awayY * rushConfig.impactShotSpawnOffset
    local count = rushConfig.impactShotCount
    local spread = rushConfig.impactShotSpread
    local firstOffset = -spread / 2
    local step = count > 1 and spread / (count - 1) or 0

    for i = 1, count do
        local angle = baseAngle + firstOffset + step * (i - 1)
        local bullet = NoHeadBullet:new(
            originX,
            originY,
            angle,
            rushConfig.impactShotSpeed,
            rushConfig.impactShotDamage,
            rushConfig.impactShotTileDamage
        )
        bullet.lifeTime = rushConfig.impactShotLifeTime
        table.insert(Game.objects, bullet)
    end
end

function BigZombie:spawnRushBoxImpactFeedback()
    local playerDistance = distance(Player, self)
    local volume = getDistanceVolume(playerDistance, 0.38, 220)

    playClonedSound(impactBase, volume, (0.86 + math.random() * 0.12) * GAME_PITCH)

    if camera and playerDistance <= 180 then
        camera:shake(1.1, 0.68)
    end
end

function BigZombie:stopRush(spawnImpact)
    if spawnImpact then
        self:spawnRushImpactFeedback()
        self.rushState = "stunned"
        self.rushStunTimer = 0
        self.currentFrame = 9
        self.animationTimer = 0
    else
        self.rushState = "seeking"
        self.rushCooldown = rushConfig.cooldown
    end

    self.rushTravel = 0
    self.rushCoastTimer = 0
    self.rushCoastTravel = 0
    self.rushDirX = 0
    self.rushDirY = 0
    self.rushLockedFlipH = nil
    self.state = Zombie.states.idle
    self.stateTimer = 0
    self.path = nil
    self.pathUpdateCounter = self.pathUpdateInterval
end

function BigZombie:startRushCoast()
    self.rushState = "rushEnding"
    self.rushCoastTimer = 0
    self.rushCoastTravel = 0
    self.rushTravel = 0
    self.currentFrame = 12
    self.animationTimer = 0
    self.state = Zombie.states.walk
    self.stateTimer = 0
end

function BigZombie:spawnRushParticles(dt)
    self.rushParticleTimer = (self.rushParticleTimer or 0) + dt
    while self.rushParticleTimer >= rushConfig.particleInterval do
        self.rushParticleTimer = self.rushParticleTimer - rushConfig.particleInterval
        BulletColorParticle.spawnBurst(self.x + math.random(-3, 3), self.y + math.random(-2, 2), 1, rushPalette, 2, {
            speedMin = 4,
            speedMax = 15,
            lifeTime = 0.46 + math.random() * 0.18,
            size = 1,
            alpha = 0.78,
            fadeOut = true,
        })
    end
end

function BigZombie:isRushColliding(moveX, moveY)
    local futureX = self.x + moveX
    local futureY = self.y + moveY
    local selfBoxX = self:collisionBox(futureX, self.y)
    local selfBoxY = self:collisionBox(self.x, futureY)
    local collidedX = false
    local collidedY = false

    local closeTiles = Tilemap:getNearbyTiles(self.x, self.y)
    for _, tile in ipairs(closeTiles) do
        if tile.collider then
            local tileBox = { x = tile.xWorld - tile.size / 2, y = tile.yWorld - tile.size, width = tile.size, height = tile.size }
            local hitX = checkCollision(selfBoxX, tileBox)
            local hitY = checkCollision(selfBoxY, tileBox)

            if hitX or hitY then
                if isBoxTile(tile) and tile.onshoot then
                    tile:onshoot(999)
                    if not self.rushBoxImpactFeedbackFrame then
                        self:spawnRushBoxImpactFeedback()
                        self.rushBoxImpactFeedbackFrame = true
                    end
                else
                    collidedX = collidedX or hitX
                    collidedY = collidedY or hitY
                end
            end
        end
    end

    return collidedX, collidedY
end

function BigZombie:updateRushPrepare(dt)
    addToDrawQueue(self.y + 6 + self.drawPriority, self)

    self.glitchTimer = math.max(0, self.glitchTimer - dt)
    self.whiteFlashTimer = math.max(0, self.whiteFlashTimer - dt)
    self:noiseCheck(dt)
    self:death()

    if not self.isAlive then
        return
    end

    if not Player.isAlive then
        self.rushState = "seeking"
        Zombie.update(self, dt)
        return
    end

    if self.state == Zombie.states.damage then
        self.rushState = "seeking"
        return
    end

    self.rushPrepareTimer = (self.rushPrepareTimer or 0) + dt
    self:updateRushFacing(dt)
    self:animate(15, 17, dt)

    if self.rushPrepareTimer >= rushConfig.prepareDuration then
        self:startRush(self.rushPendingDirX, self.rushPendingDirY)
    end
end

function BigZombie:updateRush(dt)
    addToDrawQueue(self.y + 6 + self.drawPriority, self)

    self.glitchTimer = math.max(0, self.glitchTimer - dt)
    self.whiteFlashTimer = math.max(0, self.whiteFlashTimer - dt)
    self:noiseCheck(dt)
    self:death()

    if not self.isAlive then
        return
    end

    if not Player.isAlive or self.state == Zombie.states.damage then
        self:stopRush(false)
        if not Player.isAlive then
            Zombie.update(self, dt)
        end
        return
    end

    self:animate(12, 14, dt * rushConfig.animationMultiplier)
    self:updateRushFootstepSound(dt)
    self.rushBoxImpactFeedbackFrame = false
    if self.rushLockedFlipH ~= nil then
        self.flipH = self.rushLockedFlipH
    end

    local moveX = self.rushDirX * rushConfig.speed * dt
    local moveY = self.rushDirY * rushConfig.speed * dt
    local collidedX, collidedY = self:isRushColliding(moveX, moveY)
    local impactShotDirX = collidedX and -self.rushDirX or 0
    local impactShotDirY = collidedY and -self.rushDirY or 0

    if not collidedX then
        self.x = self.x + moveX
    end
    if not collidedY then
        self.y = self.y + moveY
    end

    local movedX = collidedX and 0 or moveX
    local movedY = collidedY and 0 or moveY
    self.rushTravel = self.rushTravel + math.sqrt(movedX * movedX + movedY * movedY)
    self:spawnRushParticles(dt)

    if collidedX or collidedY or self.rushTravel >= (self.rushMaxDistance or rushConfig.maxDistanceMax) then
        if collidedX or collidedY then
            self:spawnRushImpactShots(impactShotDirX, impactShotDirY)
            self:stopRush(true)
        else
            self:startRushCoast()
        end
    end
end

function BigZombie:updateRushCoast(dt)
    addToDrawQueue(self.y + 6 + self.drawPriority, self)

    self.glitchTimer = math.max(0, self.glitchTimer - dt)
    self.whiteFlashTimer = math.max(0, self.whiteFlashTimer - dt)
    self:noiseCheck(dt)
    self:death()

    if not self.isAlive then
        return
    end

    if not Player.isAlive or self.state == Zombie.states.damage then
        self:stopRush(false)
        if not Player.isAlive then
            Zombie.update(self, dt)
        end
        return
    end

    self:animate(12, 14, dt * rushConfig.animationMultiplier * 0.72)
    self.rushBoxImpactFeedbackFrame = false
    if self.rushLockedFlipH ~= nil then
        self.flipH = self.rushLockedFlipH
    end

    local duration = math.max(0.01, rushConfig.coastDuration)
    local previousProgress = math.min((self.rushCoastTimer or 0) / duration, 1)
    self.rushCoastTimer = (self.rushCoastTimer or 0) + dt
    local progress = math.min(self.rushCoastTimer / duration, 1)
    local previousDistance = rushConfig.coastDistance * (1 - (1 - previousProgress) * (1 - previousProgress))
    local targetDistance = rushConfig.coastDistance * (1 - (1 - progress) * (1 - progress))
    local moveDistance = math.max(0, targetDistance - previousDistance)
    local remainingDistance = math.max(0, rushConfig.coastDistance - (self.rushCoastTravel or 0))
    moveDistance = math.min(moveDistance, remainingDistance)

    local moveX = self.rushDirX * moveDistance
    local moveY = self.rushDirY * moveDistance
    local collidedX, collidedY = self:isRushColliding(moveX, moveY)
    local impactShotDirX = collidedX and -self.rushDirX or 0
    local impactShotDirY = collidedY and -self.rushDirY or 0

    if not collidedX then
        self.x = self.x + moveX
    end
    if not collidedY then
        self.y = self.y + moveY
    end

    local movedX = collidedX and 0 or moveX
    local movedY = collidedY and 0 or moveY
    self.rushCoastTravel = (self.rushCoastTravel or 0) + math.sqrt(movedX * movedX + movedY * movedY)
    self:spawnRushParticles(dt)

    if collidedX or collidedY then
        self:spawnRushImpactShots(impactShotDirX, impactShotDirY)
        self:stopRush(true)
    elseif progress >= 1 or self.rushCoastTravel >= rushConfig.coastDistance then
        self:stopRush(false)
    end
end

function BigZombie:updateStunned(dt)
    addToDrawQueue(self.y + 6 + self.drawPriority, self)

    self.glitchTimer = math.max(0, self.glitchTimer - dt)
    self.whiteFlashTimer = math.max(0, self.whiteFlashTimer - dt)
    self:noiseCheck(dt)
    self:death()

    if not self.isAlive then
        return
    end

    self.rushStunTimer = (self.rushStunTimer or 0) + dt
    self.state = Zombie.states.idle
    self:animate(9, 10, dt)

    if self.rushStunTimer >= rushConfig.stunDuration then
        self.rushState = "seeking"
        self.rushCooldown = rushConfig.cooldown
        self.stateTimer = 0
        self.path = nil
        self.pathUpdateCounter = self.pathUpdateInterval
    end
end

function BigZombie:update(dt)
    if self.spawnIntroTimer and self.spawnIntroTimer > 0 then
        Zombie.update(self, dt)
        return
    end

    self.rushCooldown = math.max(0, (self.rushCooldown or 0) - dt)

    if self.rushState == "preparing" then
        self:updateRushPrepare(dt)
        return
    end

    if self.rushState == "rushing" then
        self:updateRush(dt)
        return
    end

    if self.rushState == "rushEnding" then
        self:updateRushCoast(dt)
        return
    end

    if self.rushState == "stunned" then
        self:updateStunned(dt)
        return
    end

    local dirX, dirY = self:getRushDirection()
    if self.rushCooldown <= 0 and dirX and dirY and self.state ~= Zombie.states.damage then
        self:startRushPrepare(dirX, dirY)
        self:updateRushPrepare(dt)
        return
    end

    Zombie.update(self, dt)
end

function BigZombie:drawStunStars()
    if self.rushState ~= "stunned" or not self.isAlive then
        return
    end

    local time = love.timer.getTime()
    local progress = math.min((self.rushStunTimer or 0) / rushConfig.stunDuration, 1)
    local alpha = 1 - progress * 0.25

    for i = 1, 5 do
        local angle = time * 5.2 + i * math.pi * 0.4
        local radiusX = 8
        local radiusY = 2.8
        local x = self.x + math.cos(angle) * radiusX
        local y = self.y - 25 + math.sin(angle) * radiusY
        local frame = (math.floor(time * 9 + i) % #stunParticlePalette) + 1
        local color = stunParticlePalette[frame]
        local size = frame == 3 and 2 or 1

        love.graphics.setColor(color[1], color[2], color[3], alpha * 0.78)
        love.graphics.rectangle("fill", math.floor(x + 0.5), math.floor(y + 0.5), size, size)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function BigZombie:draw()
    Zombie.draw(self)
    self:drawStunStars()
end

function BigZombie:drawMouth()
    
end

function BigZombie:noiseCheck(dt)
    self.soundTimer = self.soundTimer + dt

    if self.soundTimer >= 10 and Player.isAlive then
        self.soundTimer = 0
        local soundPositionX, soundPositionY = soundPosition(Player, self)
        local playerDistance = distance(Player, self) / 2
        local volume = getDistanceVolume(playerDistance, 0.2, 180)
        self.noise:stop()
        self.noise:setPosition(soundPositionX, soundPositionY, 0)
        self.noise:setVolume(volume)
        self.noise:setPitch((0.75 + math.random() * 0.2) * GAME_PITCH)
        self.noise:play()
    end
end

function BigZombie:stateManager(dt, animationDuration)

    self.stateTimer = self.stateTimer + dt
    if self.stateTimer >= animationDuration then
        if self.state == BigZombie.states.idle then
            self.walkDuration = math.random(4, 6)
            self.state = BigZombie.states.walk
        elseif Player.isAlive then
            self.idleDuration = math.random(10, 15) / 100
            self.state = Zombie.states.idle
        else
            self.idleDuration = math.random(10, 18) / 10
            self.state = Zombie.states.idle
        end
        self.stateTimer = 0
    end 
end

return BigZombie
