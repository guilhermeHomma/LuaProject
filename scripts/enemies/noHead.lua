local Zombie = require("scripts/enemies/zombie")
local Tilemap = require("scripts/tilemap")
local EnemyDirector = require("scripts/enemies/enemyDirector")
local NoHeadBullet = require("scripts/enemies/noHeadBullet")
local GunStarParticle = require("scripts/particles/gunStarParticle")
local WalkParticle = require("scripts/particles/walkParticle")

local NoHead = setmetatable({}, {__index = Zombie})
NoHead.__index = NoHead
NoHead.enemyTypeId = "noHead"

local shotSoundBase = love.audio.newSource("assets/sfx/gun/pistol/shot.mp3", "static")
local reloadTickSoundBase = love.audio.newSource("assets/sfx/gun/pistol/load.mp3", "static")
local handsSheet = love.graphics.newImage("assets/sprites/enemy/nohead/nohead-hands.png")
local handSprite = love.graphics.newImage("assets/sprites/enemy/nohead/hand.png")
local gunSheet = love.graphics.newImage("assets/sprites/player/guns.png")
local gunWhiteShader = love.graphics.newShader("scripts/shaders/whiteShader.glsl")
local gunChargeShader = love.graphics.newShader([[
    extern number alpha;

    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
    {
        vec4 pixel = Texel(texture, texture_coords);
        return vec4(1.0, 1.0, 1.0, pixel.a * alpha);
    }
]])

handsSheet:setFilter("nearest", "nearest")
handSprite:setFilter("nearest", "nearest")
gunSheet:setFilter("nearest", "nearest")

local gunFrameSize = 16
local gunQuad = love.graphics.newQuad(0, 0, gunFrameSize, gunFrameSize, gunSheet:getDimensions())

local function playClonedSound(baseSource, volume, pitch)
    local sound = baseSource:clone()
    sound:setVolume(volume)
    sound:setPitch(pitch)
    sound:play()
    return sound
end

local function getLightTint(enemy)
    local brightness = enemy and enemy.lightBrightness or 1
    brightness = math.max(brightness, 0.8)
    return brightness, brightness, brightness
end

local function distanceSqToPoint(x1, y1, x2, y2)
    local dx = x1 - x2
    local dy = y1 - y2
    return dx * dx + dy * dy
end

local function getScaledPathUpdateInterval(enemy)
    local interval = enemy.pathUpdateInterval or 1
    local enemyCount = #(Game and Game.enemies or {})

    if enemyCount >= 42 then
        return interval * 2.2
    elseif enemyCount >= 26 then
        return interval * 1.55
    end

    return interval
end

local function getRoamTargetAttempts()
    local enemyCount = #(Game and Game.enemies or {})
    if enemyCount >= 28 then
        return 3
    elseif enemyCount >= 16 then
        return 4
    end
    return 6
end

local function segmentIntersectsRect(x1, y1, x2, y2, rect)
    local dx = x2 - x1
    local dy = y2 - y1
    local enter = 0
    local exit = 1

    if math.abs(dx) < 0.0001 then
        if x1 < rect.x or x1 > rect.x + rect.width then
            return false
        end
    else
        local tx1 = (rect.x - x1) / dx
        local tx2 = (rect.x + rect.width - x1) / dx
        enter = math.max(enter, math.min(tx1, tx2))
        exit = math.min(exit, math.max(tx1, tx2))
    end

    if math.abs(dy) < 0.0001 then
        if y1 < rect.y or y1 > rect.y + rect.height then
            return false
        end
    else
        local ty1 = (rect.y - y1) / dy
        local ty2 = (rect.y + rect.height - y1) / dy
        enter = math.max(enter, math.min(ty1, ty2))
        exit = math.min(exit, math.max(ty1, ty2))
    end

    return exit >= enter
end

local function getExpandedTileBox(tile, padding)
    padding = padding or 0
    return {
        x = tile.xWorld - tile.size / 2 - padding,
        y = tile.yWorld - tile.size - padding,
        width = tile.size + padding * 2,
        height = tile.size + padding * 2,
    }
end

local function isBreakableTile(tile)
    return tile.quadIndex == 14 or tile.quadIndex == 18
end

local function getObjectLineOfSightBox(object)
    if object.isAlive == false or not (object.collider == true or object.blocksPlayer == true) then
        return nil
    end

    if type(object.collisionBox) == "function" then
        return object:collisionBox()
    end

    if type(object.getBox) == "function" then
        return object:getBox()
    end

    if object.collider and object.xWorld and object.yWorld and object.size then
        return {
            x = object.xWorld - object.size / 2,
            y = object.yWorld - object.size,
            width = object.size,
            height = object.size,
        }
    end

    return nil
end

function NoHead:new(x, y)
    local enemy = Zombie.new(self, x, y, math.random(52, 60))
    enemy.totalLife = 30
    enemy.life = enemy.totalLife
    enemy.footStepAlpha = 0.35
    enemy.shootDistance = math.random(96, 128)
    enemy.shootCancelDistance = enemy.shootDistance + 72
    enemy.shootCooldown = math.random(75, 100) / 100
    enemy.shootTimer = math.random() * 0.6
    enemy.shootDisabledTimer = 0
    enemy.shootDisabledMin = 1.6
    enemy.shootDisabledMax = 2.0
    enemy.bulletSpeed = 125
    enemy.aimAngle = 0
    enemy.lockedAimAngle = nil
    enemy.lockedAimTargetX = nil
    enemy.lockedAimTargetY = nil
    enemy.aimLockLeadTime = 0.5
    enemy.aimLocked = false
    enemy.aimWindupTimer = 0
    enemy.reloadTickDelays = {0.12, 0.1, 0.07, 0.07}
    enemy.postTickShotDelay = 0.2
    enemy.aimWindupDuration = 0.56
    enemy.reloadTickIndex = 1
    enemy.reloadTickElapsed = 0
    enemy.gunVisibleTimer = 0
    enemy.gunVisibleDuration = 0.46
    enemy.shotFlashTimer = 0
    enemy.shotFlashDuration = 0.16
    enemy.postShotRecoilTimer = 0
    enemy.postShotRecoilDurationMin = 1
    enemy.postShotRecoilDurationMax = 1
    enemy.postShotRecoilSpeed = enemy.speed
    enemy.cooldownDustTimer = 0
    enemy.postShotMoveX = 0
    enemy.postShotMoveY = 0
    enemy.retreatChance = 0.45
    enemy.closeRetreatChance = 0.75
    enemy.retreatDistance = 78
    enemy.roamTargetX = nil
    enemy.roamTargetY = nil
    enemy.roamTargetTimer = 0
    enemy.roamTargetDuration = 1.4
    enemy.roamRadiusMin = 46
    enemy.roamRadiusMax = 104
    enemy.moveMode = "chase"
    enemy.chaseModeTimer = 0.8 + math.random() * 0.35
    enemy.chaseModeDurationMin = 0.65
    enemy.chaseModeDurationMax = 1.05
    enemy.chaseStopDistance = enemy.shootDistance * 0.82
    enemy.roamModeDurationMin = 0.9
    enemy.roamModeDurationMax = 1.45
    enemy.flipDeadzone = 14
    enemy.flipCooldown = 0.45
    enemy.flipCooldownTimer = 0
    enemy.mouthVariant = "noHead"
    return enemy
end

function NoHead:getSprite()
    return Zombie.getSprite(self)
end

function NoHead:getSpriteKey()
    return "assets/sprites/enemy/nohead/nohead.png"
end

function NoHead:drawMouth()
    Zombie.drawMouth(self)
end

function NoHead:disableShootingAfterDamage()
    local minTimer = self.shootDisabledMin or 1.6
    local maxTimer = self.shootDisabledMax or 2.0
    self.shootDisabledTimer = minTimer + math.random() * (maxTimer - minTimer)
    self.aimWindupTimer = 0
    self.gunVisibleTimer = 0
    self.aimLocked = false
    self.lockedAimAngle = nil
    self.lockedAimTargetX = nil
    self.lockedAimTargetY = nil
end

function NoHead:takeDamage(damage, dx, dy)
    Zombie.takeDamage(self, damage, dx, dy)
    if self.isAlive ~= false then
        self:disableShootingAfterDamage()
    end
end

function NoHead:getShotPosition()
    return self.x, self.y - 12
end

function NoHead:getHandsQuad()
    local quad = love.graphics.newQuad(
        (self.currentFrame - 1) * self.frameWidth,
        0,
        self.frameWidth,
        self.frameHeight,
        handsSheet:getDimensions()
    )
    return quad
end

function NoHead:isGunVisible()
    return (self.aimWindupTimer or 0) > 0 or (self.gunVisibleTimer or 0) > 0
end

function NoHead:getGunChargeAlpha()
    if (self.aimWindupTimer or 0) <= 0 then
        return 0
    end

    local level = math.max(0, math.min((self.reloadTickIndex or 1) - 1, 4))
    local alphas = {0.14, 0.26, 0.42, 0.62}
    return alphas[level] or 0
end

function NoHead:drawBodyOverlay(xOffset, yOffset, scaleX, scaleY, damageScaleX, damageScaleY, alpha)
    if self:isGunVisible() then
        return
    end

    local r, g, b = getLightTint(self)
    love.graphics.setColor(r, g, b, alpha or 1)
    love.graphics.draw(
        handsSheet,
        self:getHandsQuad(),
        xOffset + self.x,
        self.y + yOffset,
        0,
        scaleX * damageScaleX,
        scaleY * damageScaleY,
        self.frameWidth / 2,
        self.frameHeight
    )
end

function NoHead:drawGun()
    if not self:isGunVisible() then
        return
    end

    local shotX, shotY = self:getShotPosition()
    local drawAngle = self.aimAngle or 0
    local drawX = shotX + math.cos(drawAngle)* 0.14
    local drawY = shotY + math.sin(drawAngle)* 0.14
    local handX = drawX + math.cos(drawAngle) * 3.4
    local handY = drawY + math.sin(drawAngle) * 3.4
    local gunChargeAlpha = self:getGunChargeAlpha()

    if (self.shotFlashTimer or 0) > 0 then
        love.graphics.setShader(gunWhiteShader)
    end

    local r, g, b = getLightTint(self)
    love.graphics.setColor(r, g, b, 1)
    love.graphics.draw(
        handSprite,
        handX,
        handY + 3 ,
        0,
        0.85,
        1,
        handSprite:getWidth() / 2,
        handSprite:getHeight() / 2
    )

    for layer = 2,0,-0.5 do
        love.graphics.setColor(r, g, b, 1)
        love.graphics.draw(
            gunSheet,
            gunQuad,
            drawX,
            drawY + layer-1,
            drawAngle,
            0.75,
            0.75,
            0,
            gunFrameSize / 2
        )

        if gunChargeAlpha > 0 and (self.shotFlashTimer or 0) <= 0 then
            gunChargeShader:send("alpha", gunChargeAlpha)
            love.graphics.setShader(gunChargeShader)
            love.graphics.draw(
                gunSheet,
                gunQuad,
                drawX,
                drawY + layer-1,
                drawAngle,
                0.75,
                0.75,
                0,
                gunFrameSize / 2
            )
            love.graphics.setShader()
        end
    end
    love.graphics.setShader()
    love.graphics.setColor(1, 1, 1, 1)
end

function NoHead:shootAtPlayer()
    local shotX, shotY = self:getShotPosition()
    local angle = self.lockedAimAngle or self.aimAngle or math.atan2((Player.y - 10) - shotY, Player.x - shotX)
    local spawnX = shotX + math.cos(angle) * 8
    local spawnY = shotY + math.sin(angle) * 8 + 14
    local bullet = NoHeadBullet:new(spawnX, spawnY, angle, self.bulletSpeed, 1, 10)

    local immediateTile = bullet:collidingTile()
    if immediateTile and not isBreakableTile(immediateTile) then
        return false
    end

    self.aimAngle = angle
    self.shotFlashTimer = self.shotFlashDuration
    self.gunVisibleTimer = self.gunVisibleDuration
    self.animationTimer = 0
    table.insert(Game.objects, bullet)
    table.insert(Game.particles, GunStarParticle:new(spawnX, spawnY, 14, 0.75))

    local playerDistance = distance(Player, self)
    local volume = getDistanceVolume(playerDistance, 0.35, 220)
    playClonedSound(shotSoundBase, volume, (0.88 + math.random() * 0.12) * GAME_PITCH)
    return true
end

function NoHead:getAimWindupDuration()
    local duration = self.postTickShotDelay or 0.2
    for _, delay in ipairs(self.reloadTickDelays or {}) do
        duration = duration + delay
    end
    return duration
end

function NoHead:playReloadTick()
    local tickIndex = self.reloadTickIndex or 1
    local playerDistance = distance(Player, self)
    local volume = getDistanceVolume(playerDistance, 0.22, 190)
    local pitch = (0.78 + tickIndex * 0.13) * GAME_PITCH
    playClonedSound(reloadTickSoundBase, volume, pitch)
end

function NoHead:startAiming()
    self.aimWindupDuration = self:getAimWindupDuration()
    self.aimWindupTimer = self.aimWindupDuration
    self.gunVisibleTimer = self.aimWindupDuration
    self.aimLocked = false
    self.lockedAimAngle = nil
    self.lockedAimTargetX = nil
    self.lockedAimTargetY = nil
    self.reloadTickIndex = 1
    self.reloadTickElapsed = 0
    self.state = Zombie.states.idle
    self.animationTimer = 0
end

function NoHead:updateAimAtPlayer()
    local shotX, shotY = self:getShotPosition()
    self.aimAngle = math.atan2((Player.y - 10) - shotY, Player.x - shotX)
end

function NoHead:lockAimTarget()
    if self.aimLocked then
        return
    end

    local shotX, shotY = self:getShotPosition()
    self.lockedAimTargetX = Player.x
    self.lockedAimTargetY = Player.y - 10
    self.lockedAimAngle = math.atan2(self.lockedAimTargetY - shotY, self.lockedAimTargetX - shotX)
    self.aimAngle = self.lockedAimAngle
    self.aimLocked = true
end

function NoHead:hasLineOfSightToPlayer()
    local now = love.timer.getTime()
    if self.lineOfSightCacheTime and now - self.lineOfSightCacheTime < 0.12 then
        return self.lineOfSightCache == true
    end

    local shotX, shotY = self:getShotPosition()
    local targetX = self.aimLocked and self.lockedAimTargetX or Player.x
    local targetY = self.aimLocked and self.lockedAimTargetY or Player.y - 10
    if not (targetX and targetY) then
        return false
    end
    local padding = 4
    local minX = math.min(shotX, targetX) - padding
    local maxX = math.max(shotX, targetX) + padding
    local minY = math.min(shotY, targetY) - padding
    local maxY = math.max(shotY, targetY) + padding
    local tiles = Tilemap.getTilesInWorldBox and Tilemap:getTilesInWorldBox(minX, minY, maxX, maxY) or Tilemap.tiles or {}

    for _, tile in ipairs(tiles) do
        if tile.isAlive ~= false and tile.collider and not tile.isWater then
            local tileBox = getExpandedTileBox(tile, padding)

            if segmentIntersectsRect(shotX, shotY, targetX, targetY, tileBox) then
                self.lineOfSightCacheTime = now
                self.lineOfSightCache = false
                return false
            end
        end
    end

    for _, object in ipairs((Game and Game.objects) or {}) do
        local objectBox = getObjectLineOfSightBox(object)
        if objectBox and segmentIntersectsRect(shotX, shotY, targetX, targetY, objectBox) then
            self.lineOfSightCacheTime = now
            self.lineOfSightCache = false
            return false
        end
    end

    local lineBox = {x = minX, y = minY, width = maxX - minX, height = maxY - minY}
    local enemies = Game and Game.getEnemiesNearBox and Game:getEnemiesNearBox(lineBox, padding)
        or (Game and Game.enemies) or {}
    for _, enemy in ipairs(enemies) do
        if enemy ~= self and enemy.blocksPlayer and enemy.isAlive ~= false then
            local enemyBox = getObjectLineOfSightBox(enemy)
            if enemyBox and segmentIntersectsRect(shotX, shotY, targetX, targetY, enemyBox) then
                self.lineOfSightCacheTime = now
                self.lineOfSightCache = false
                return false
            end
        end
    end

    self.lineOfSightCacheTime = now
    self.lineOfSightCache = true
    return true
end

function NoHead:updateFacing(targetX, dt)
    self.flipCooldownTimer = math.max(0, (self.flipCooldownTimer or 0) - dt)

    local dx = targetX - self.x
    if math.abs(dx) <= self.flipDeadzone or self.flipCooldownTimer > 0 then
        return
    end

    local targetFlip = dx > 0
    if targetFlip ~= self.flipH then
        self.flipH = targetFlip
        self.flipCooldownTimer = self.flipCooldown
    end
end

function NoHead:pickPostShotMove()
    if Player.isAlive and math.random() < 0.5 then
        local toPlayerX = Player.x - self.x
        local toPlayerY = Player.y - self.y
        local length = math.sqrt(toPlayerX * toPlayerX + toPlayerY * toPlayerY)

        if length > 0 then
            return toPlayerX / length, toPlayerY / length
        end
    end

    local angle = math.random() * math.pi * 2
    return math.cos(angle), math.sin(angle)
end

function NoHead:startPostShotRecoil()
    local minDuration = self.postShotRecoilDurationMin or 0.26
    local maxDuration = self.postShotRecoilDurationMax or minDuration
    local moveX, moveY = self:pickPostShotMove()

    self.postShotRecoilTimer = minDuration + math.random() * (maxDuration - minDuration)
    self.postShotMoveX = moveX
    self.postShotMoveY = moveY
    self.cooldownDustTimer = 0
    self.path = nil
end

function NoHead:spawnCooldownDust(dt)
    self.cooldownDustTimer = (self.cooldownDustTimer or 0) + dt
    while self.cooldownDustTimer >= 0.055 do
        self.cooldownDustTimer = self.cooldownDustTimer - 0.055
        local particle = WalkParticle:new(self.x + math.random(-3, 3), self.y + math.random(-2, 2), 0.32 + math.random() * 0.12)
        particle.alpha = 0.42
        particle.radius = 0.22
        table.insert(Game.particles, particle)
    end
end

function NoHead:updatePostShotRecoil(dt)
    self.postShotRecoilTimer = math.max(0, (self.postShotRecoilTimer or 0) - dt)
    self.state = Zombie.states.walk
    self:animate(3, 6, dt)
    self:updateFacing(self.x + (self.postShotMoveX or 0) * 24, dt)
    self:spawnCooldownDust(dt)

    local moveX = (self.postShotMoveX or 0) * (self.postShotRecoilSpeed or 46) * dt
    local moveY = (self.postShotMoveY or 0) * (self.postShotRecoilSpeed or 46) * dt
    local collidedX, collidedY = self:isColliding(moveX, moveY)
    if not collidedX then self.x = self.x + moveX end
    if not collidedY then self.y = self.y + moveY end
end

function NoHead:updateReloadTicks(dt)
    self.reloadTickElapsed = (self.reloadTickElapsed or 0) + dt

    local delays = self.reloadTickDelays or {}
    while self.reloadTickIndex <= #delays and self.reloadTickElapsed >= delays[self.reloadTickIndex] do
        self.reloadTickElapsed = self.reloadTickElapsed - delays[self.reloadTickIndex]
        self:playReloadTick()
        self.reloadTickIndex = self.reloadTickIndex + 1
    end
end

function NoHead:moveWithVelocity(velocityX, velocityY, dt, targetX, targetY)
    local repulseX, repulseY = self:getRepulsionVector()
    velocityX = velocityX + repulseX * 10
    velocityY = velocityY + repulseY * 10

    local length = math.sqrt(velocityX * velocityX + velocityY * velocityY)
    if length <= 0 then
        self.state = Zombie.states.idle
        self:animate(1, 2, dt)
        return false, false
    end

    if length > 0 then
        velocityX = velocityX / length
        velocityY = velocityY / length
    end

    self.state = Zombie.states.walk
    self:animate(3, 6, dt)
    self:updateFacing(self.x + velocityX * 24, dt)

    local moveX = velocityX * self.speed * dt
    local moveY = velocityY * self.speed * dt
    if targetX and targetY then
        local remainingDistance = math.sqrt(distanceSqToPoint(targetX, targetY, self.x, self.y))
        local moveDistance = math.sqrt(moveX * moveX + moveY * moveY)
        if remainingDistance > 0 and moveDistance > remainingDistance then
            local scale = remainingDistance / moveDistance
            moveX = moveX * scale
            moveY = moveY * scale
        end
    end

    local previousX, previousY = self.x, self.y
    local collidedX, collidedY = self:isColliding(moveX, moveY)
    if not collidedX then self.x = self.x + moveX end
    if not collidedY then self.y = self.y + moveY end

    if (collidedX or collidedY) and distanceSqToPoint(previousX, previousY, self.x, self.y) < 0.2 * 0.2 then
        if not Player.isAlive then
            self:startDeathRoamPause()
        else
            self.state = Zombie.states.idle
            self.path = nil
            self.roamTargetTimer = 0
        end
    end

    return collidedX, collidedY
end

function NoHead:pickRoamTarget()
    if not Player.isAlive then
        Zombie.pickRoamTarget(self)
        return
    end

    local targetX, targetY = self:chooseSeparatedPlayerRoamTarget(getRoamTargetAttempts())
    self:setRoamTarget(targetX, targetY, self.roamTargetDuration)
end

function NoHead:startChaseMode()
    self.moveMode = "chase"
    self.chaseModeTimer = self.chaseModeDurationMin + math.random() * (self.chaseModeDurationMax - self.chaseModeDurationMin)
    self.roamTargetX = nil
    self.roamTargetY = nil
    self.path = nil
    self.pathUpdateCounter = self.pathUpdateInterval
end

function NoHead:startRoamMode()
    self.moveMode = "roam"
    self.roamTargetDuration = self.roamModeDurationMin + math.random() * (self.roamModeDurationMax - self.roamModeDurationMin)
    self.roamTargetTimer = 0
    self:pickRoamTarget()
end

function NoHead:ensureRoamTarget(dt)
    if not Player.isAlive then
        self.moveMode = "roam"
        Zombie.ensureRoamTarget(self, dt)
        return
    end

    if self.moveMode ~= "roam" then
        return
    end

    self.roamTargetTimer = math.max(0, (self.roamTargetTimer or 0) - dt)

    local needsTarget = not self.roamTargetX
        or not self.roamTargetY
        or self.roamTargetTimer <= 0
        or distanceSqToPoint(self.roamTargetX or self.x, self.roamTargetY or self.y, self.x, self.y) < 10 * 10
        or (Player.isAlive and distanceSqToPoint(self.roamTargetX or Player.x, self.roamTargetY or Player.y, Player.x, Player.y) > (self.roamRadiusMax + 36) * (self.roamRadiusMax + 36))

    if needsTarget then
        self:pickRoamTarget()
    end
end

function NoHead:updateMoveMode(dt, playerDistance)
    if not Player.isAlive then
        self.moveMode = "roam"
        return
    end

    if self.moveMode == "chase" then
        self.chaseModeTimer = math.max(0, (self.chaseModeTimer or 0) - dt)
        if self.chaseModeTimer <= 0 and playerDistance <= self.chaseStopDistance then
            self:startRoamMode()
        end
        return
    end

    if self.moveMode ~= "roam" then
        self:startChaseMode()
        return
    end

    if playerDistance > self.roamRadiusMax + 52 then
        self:startChaseMode()
    end
end

function NoHead:getMoveTarget(dt, playerDistance)
    self:updateMoveMode(dt, playerDistance)

    if self.moveMode == "chase" and Player.isAlive then
        return Player.x, Player.y
    end

    self:ensureRoamTarget(dt)
    return self.roamTargetX or Player.x, self.roamTargetY or Player.y
end

function NoHead:update(dt)
    addToDrawQueue(self.y + 6 + self.drawPriority, self)

    if self.spawnIntroTimer and self.spawnIntroTimer > 0 then
        self.spawnIntroTimer = math.max(0, self.spawnIntroTimer - dt)
        self.state = Zombie.states.idle
        self:animate(1, 2, dt)
        return
    end

    self.glitchTimer = math.max(0, self.glitchTimer - dt)
    self.whiteFlashTimer = math.max(0, self.whiteFlashTimer - dt)
    self.shotFlashTimer = math.max(0, (self.shotFlashTimer or 0) - dt)
    self.gunVisibleTimer = math.max(0, (self.gunVisibleTimer or 0) - dt)
    self.shootDisabledTimer = math.max(0, (self.shootDisabledTimer or 0) - dt)
    self.shootTimer = self.shootTimer + dt

    self:noiseCheck(dt)
    self:death()
    if not self.isAlive then
        return
    end

    if self:updateDeathRoamPause(dt) then
        return
    end

    local playerDistance = distance(Player, self)
    if not self.aimLocked then
        self:updateAimAtPlayer()
    end

    if self.state == Zombie.states.damage then
        self.stateTimer = self.stateTimer + dt
        self:animate(1, 2, dt)

        local movekbX = self.kbdx * dt * 0.05
        local movekbY = self.kbdy * dt * 0.05
        local collidedX, collidedY = self:isColliding(movekbX, movekbY)

        if not collidedX then self.x = self.x + movekbX end
        if not collidedY then self.y = self.y + movekbY end

        if self.stateTimer >= self.damageTimer then
            self.stateTimer = 0
            self.state = Zombie.states.idle
        end
        return
    end

    if self.postShotRecoilTimer > 0 then
        self:updatePostShotRecoil(dt)
        return
    end

    if self.aimWindupTimer > 0 then
        if (self.shootDisabledTimer or 0) > 0 then
            self.aimWindupTimer = 0
            self.gunVisibleTimer = 0
            self.aimLocked = false
            return
        end

        self.aimWindupTimer = math.max(0, self.aimWindupTimer - dt)
        if self.aimWindupTimer <= (self.aimLockLeadTime or 0.5) then
            self:lockAimTarget()
        elseif not self.aimLocked then
            self:updateAimAtPlayer()
        end

        self.state = Zombie.states.idle
        self:updateFacing((self.aimLocked and self.lockedAimTargetX) or Player.x, dt)
        self:animate(1, 2, dt)
        self:updateReloadTicks(dt)

        if self.aimWindupTimer == 0 then
            self.shootTimer = 0
            local targetDistance = playerDistance
            if self.aimLocked and self.lockedAimTargetX and self.lockedAimTargetY then
                local dx = self.lockedAimTargetX - self.x
                local dy = self.lockedAimTargetY - self.y
                targetDistance = math.sqrt(dx * dx + dy * dy)
            end
            local targetInShotRange = Player.isAlive and targetDistance <= self.shootCancelDistance
            if targetInShotRange then
                if self:hasLineOfSightToPlayer() and self:shootAtPlayer() then
                    self:startPostShotRecoil()
                else
                    self.gunVisibleTimer = 0
                    self:startPostShotRecoil()
                end
            else
                self.gunVisibleTimer = 0
            end
            self.aimLocked = false
            self.lockedAimAngle = nil
            self.lockedAimTargetX = nil
            self.lockedAimTargetY = nil
        end
        return
    end

    if Player.isAlive
        and (self.shootDisabledTimer or 0) <= 0
        and playerDistance <= self.shootDistance
        and self:hasLineOfSightToPlayer() then
        self.state = Zombie.states.idle
        self:updateFacing(Player.x, dt)
        self:animate(1, 2, dt)

        if self.shootTimer >= self.shootCooldown then
            self:startAiming()
        end
        return
    end

    local targetX, targetY = self:getMoveTarget(dt, playerDistance)

    self.pathUpdateCounter = self.pathUpdateCounter + dt
    local usePathfinding = EnemyDirector:shouldUsePathfinding(self)
    if not usePathfinding then
        self.roamTargetTimer = math.max(0, (self.roamTargetTimer or 0) - dt)
        local needsRandomTarget = not self.roamTargetX
            or not self.roamTargetY
            or self.roamTargetTimer <= 0
            or distanceSqToPoint(self.roamTargetX or self.x, self.roamTargetY or self.y, self.x, self.y) < 10 * 10
        if needsRandomTarget then
            EnemyDirector:configureRandomRoam(self, Player.isAlive and self.roamTargetDuration or (1.8 + math.random() * 2.4))
        end
        targetX = self.roamTargetX or targetX
        targetY = self.roamTargetY or targetY
        self.path = nil
    elseif self.pathUpdateCounter >= getScaledPathUpdateInterval(self) or self.path == nil or #self.path < 2 then
        self.pathUpdateCounter = 0
        local path, requested = EnemyDirector:requestPath(self.x, self.y, targetX, targetY)
        if requested then
            self.path = path
        end
    end

    local velocityX = 0
    local velocityY = 0
    local nextTileX, nextTileY = nil, nil
    if usePathfinding and self.path and #self.path > 1 then
        local nextNode = self.path[2]
        nextTileX, nextTileY = Tilemap:mapToWorld(nextNode.x, nextNode.y)
        nextTileY = nextTileY - 8

        if distanceSqToPoint(nextTileX, nextTileY, self.x, self.y) < 4 * 4 then
            table.remove(self.path, 1)
            if #self.path > 1 then
                nextNode = self.path[2]
                nextTileX, nextTileY = Tilemap:mapToWorld(nextNode.x, nextNode.y)
                nextTileY = nextTileY - 8
            else
                if not Player.isAlive then
                    self:startDeathRoamPause()
                    return
                else
                    self.roamTargetTimer = 0
                end
            end
        end

        velocityX = nextTileX - self.x
        velocityY = nextTileY - self.y
    elseif not usePathfinding and targetX and targetY then
        nextTileX = targetX
        nextTileY = targetY
        velocityX = targetX - self.x
        velocityY = targetY - self.y
    else
        if not Player.isAlive then
            self:startDeathRoamPause()
            return
        else
            self.roamTargetTimer = 0
        end
    end

    self:moveWithVelocity(velocityX, velocityY, dt, nextTileX, nextTileY)
end

function NoHead:draw()
    local aimingUp = self:isGunVisible() and math.sin(self.aimAngle or 0) < 0

    if aimingUp then
        self:drawGun()
    end

    Zombie.draw(self)

    if not aimingUp then
        self:drawGun()
    end
end

return NoHead
