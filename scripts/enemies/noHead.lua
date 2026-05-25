local Zombie = require("scripts/enemies/zombie")
local Tilemap = require("scripts/tilemap")
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

function NoHead:new(x, y)
    local enemy = Zombie.new(self, x, y, math.random(52, 60))
    enemy.totalLife = 30
    enemy.life = enemy.totalLife
    enemy.footStepAlpha = 0.35
    enemy.shootDistance = math.random(96, 128)
    enemy.shootCancelDistance = enemy.shootDistance + 72
    enemy.shootCooldown = math.random(75, 100) / 100
    enemy.shootTimer = math.random() * 0.6
    enemy.bulletSpeed = 96
    enemy.aimAngle = 0
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
    enemy.postShotRecoilDurationMin = 0.14
    enemy.postShotRecoilDurationMax = 0.22
    enemy.postShotRecoilSpeed = 46
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
    local angle = self.aimAngle or math.atan2((Player.y - 10) - shotY, Player.x - shotX)
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
    self.reloadTickIndex = 1
    self.reloadTickElapsed = 0
    self.state = Zombie.states.idle
    self.animationTimer = 0
end

function NoHead:hasLineOfSightToPlayer()
    local shotX, shotY = self:getShotPosition()
    local targetX = Player.x
    local targetY = Player.y - 10
    local padding = 4

    for _, tile in ipairs(Tilemap.tiles or {}) do
        if tile.collider and not tile.isWater and not isBreakableTile(tile) then
            local tileBox = getExpandedTileBox(tile, padding)

            if segmentIntersectsRect(shotX, shotY, targetX, targetY, tileBox) then
                return false
            end
        end
    end

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
    local awayX = self.x - Player.x
    local awayY = self.y - Player.y
    local length = math.sqrt(awayX * awayX + awayY * awayY)

    if length <= 0 then
        awayX = math.random() > 0.5 and 1 or -1
        awayY = 0
        length = 1
    end

    awayX = awayX / length
    awayY = awayY / length

    local playerDistance = distance(Player, self)
    local retreatChance = playerDistance <= self.retreatDistance and self.closeRetreatChance or self.retreatChance
    local moveX, moveY

    if math.random() < retreatChance then
        local strafe = math.random() > 0.5 and 1 or -1
        moveX = awayX + (-awayY * strafe * 0.45)
        moveY = awayY + (awayX * strafe * 0.45)
    else
        local strafe = math.random() > 0.5 and 1 or -1
        moveX = -awayY * strafe
        moveY = awayX * strafe
    end

    local moveLength = math.sqrt(moveX * moveX + moveY * moveY)
    if moveLength <= 0 then
        return awayX, awayY
    end

    return moveX / moveLength, moveY / moveLength
end

function NoHead:startPostShotRecoil()
    local minDuration = self.postShotRecoilDurationMin or 0.26
    local maxDuration = self.postShotRecoilDurationMax or minDuration
    local awayX = self.x - Player.x
    local awayY = self.y - Player.y
    local length = math.sqrt(awayX * awayX + awayY * awayY)

    if length <= 0 then
        awayX = self.flipH and -1 or 1
        awayY = 0
        length = 1
    end

    self.postShotRecoilTimer = minDuration + math.random() * (maxDuration - minDuration)
    self.postShotMoveX = awayX / length
    self.postShotMoveY = awayY / length
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
    self.state = Zombie.states.idle
    self:animate(1, 2, dt)
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
        local remainingDistance = distance({x = targetX, y = targetY}, self)
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

    if (collidedX or collidedY) and distance({x = previousX, y = previousY}, self) < 0.2 then
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

    local targetX, targetY = self:chooseSeparatedPlayerRoamTarget(8)
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
        or distance({x = self.roamTargetX, y = self.roamTargetY}, self) < 10
        or (Player.isAlive and distance({x = self.roamTargetX, y = self.roamTargetY}, Player) > self.roamRadiusMax + 36)

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
    local shotX, shotY = self:getShotPosition()
    self.aimAngle = math.atan2((Player.y - 10) - shotY, Player.x - shotX)

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
        self.aimWindupTimer = math.max(0, self.aimWindupTimer - dt)
        self.state = Zombie.states.idle
        self:updateFacing(Player.x, dt)
        self:animate(1, 2, dt)
        self:updateReloadTicks(dt)

        if self.aimWindupTimer == 0 then
            self.shootTimer = 0
            if Player.isAlive and playerDistance <= self.shootCancelDistance and self:hasLineOfSightToPlayer() and self:shootAtPlayer() then
                self:startPostShotRecoil()
            else
                self.gunVisibleTimer = 0
            end
        end
        return
    end

    if Player.isAlive and playerDistance <= self.shootDistance and self:hasLineOfSightToPlayer() then
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
    if self.pathUpdateCounter >= self.pathUpdateInterval or self.path == nil or #self.path < 2 then
        self.pathUpdateCounter = 0
        self.path = Tilemap:getPathBetweenWorldPoints(self.x, self.y, targetX, targetY)
    end

    local velocityX = 0
    local velocityY = 0
    local nextTileX, nextTileY = nil, nil
    if self.path and #self.path > 1 then
        local nextNode = self.path[2]
        nextTileX, nextTileY = Tilemap:mapToWorld(nextNode.x, nextNode.y)
        nextTileY = nextTileY - 8

        if distance({x = nextTileX, y = nextTileY}, self) < 4 then
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
