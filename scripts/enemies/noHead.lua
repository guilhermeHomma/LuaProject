local Zombie = require("scripts/enemies/zombie")
local Tilemap = require("scripts/tilemap")
local NoHeadBullet = require("scripts/enemies/noHeadBullet")
local GunStarParticle = require("scripts/particles/gunStarParticle")

local NoHead = setmetatable({}, {__index = Zombie})
NoHead.__index = NoHead
NoHead.enemyTypeId = "noHead"

local shotSoundBase = love.audio.newSource("assets/sfx/gun/pistol/shot.mp3", "static")
local handsSheet = love.graphics.newImage("assets/sprites/enemy/nohead/nohead-hands.png")
local handSprite = love.graphics.newImage("assets/sprites/enemy/nohead/hand.png")
local gunSheet = love.graphics.newImage("assets/sprites/player/guns.png")
local gunWhiteShader = love.graphics.newShader("scripts/shaders/whiteShader.glsl")

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

local function sign(n)
    if n > 0 then return 1 end
    if n < 0 then return -1 end
    return 0
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
    enemy.shootCooldown = math.random(210, 280) / 100
    enemy.shootTimer = math.random() * 0.6
    enemy.bulletSpeed = 82
    enemy.aimAngle = 0
    enemy.aimWindupTimer = 0
    enemy.aimWindupDuration = 0.58
    enemy.gunVisibleTimer = 0
    enemy.gunVisibleDuration = 0.46
    enemy.shotFlashTimer = 0
    enemy.shotFlashDuration = 0.16
    enemy.postShotWalkTimer = 0
    enemy.postShotWalkDurationMin = 0.45
    enemy.postShotWalkDurationMax = 0.8
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

function NoHead:drawBodyOverlay(xOffset, yOffset, scaleX, scaleY, damageScaleX, damageScaleY, alpha)
    if self:isGunVisible() then
        return
    end

    love.graphics.setColor(1, 1, 1, alpha or 1)
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

    if (self.shotFlashTimer or 0) > 0 then
        love.graphics.setShader(gunWhiteShader)
    end

    love.graphics.setColor(1, 1, 1, 1)
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
    end
    love.graphics.setShader()
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

function NoHead:startAiming()
    self.aimWindupTimer = self.aimWindupDuration
    self.gunVisibleTimer = self.aimWindupDuration
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

function NoHead:startPostShotWalk()
    local minDuration = self.postShotWalkDurationMin or 0.45
    local maxDuration = self.postShotWalkDurationMax or minDuration
    self.postShotWalkTimer = minDuration + math.random() * (maxDuration - minDuration)
    self.postShotMoveX, self.postShotMoveY = self:pickPostShotMove()
    self.path = nil
end

function NoHead:moveWithVelocity(velocityX, velocityY, dt)
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
    local previousX, previousY = self.x, self.y
    local collidedX, collidedY = self:isColliding(moveX, moveY)
    if not collidedX then self.x = self.x + moveX end
    if not collidedY then self.y = self.y + moveY end

    if (collidedX or collidedY) and distance({x = previousX, y = previousY}, self) < 0.2 then
        self.state = Zombie.states.idle
        self.path = nil
        self.roamTargetTimer = 0
    end

    return collidedX, collidedY
end

function NoHead:pickRoamTarget()
    local angle = math.random() * math.pi * 2
    local radius = self.roamRadiusMin + math.random() * (self.roamRadiusMax - self.roamRadiusMin)

    self.roamTargetX = Player.x + math.cos(angle) * radius
    self.roamTargetY = Player.y + math.sin(angle) * radius
    self.roamTargetTimer = self.roamTargetDuration
    self.path = nil
    self.pathUpdateCounter = self.pathUpdateInterval
end

function NoHead:ensureRoamTarget(dt)
    self.roamTargetTimer = math.max(0, (self.roamTargetTimer or 0) - dt)

    local needsTarget = not self.roamTargetX
        or not self.roamTargetY
        or self.roamTargetTimer <= 0
        or distance({x = self.roamTargetX, y = self.roamTargetY}, self) < 10
        or distance({x = self.roamTargetX, y = self.roamTargetY}, Player) > self.roamRadiusMax + 36

    if needsTarget then
        self:pickRoamTarget()
    end
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

    local playerDistance = distance(Player, self)
    local shotX, shotY = self:getShotPosition()
    self.aimAngle = math.atan2((Player.y - 10) - shotY, Player.x - shotX)

    if not Player.isAlive then
        self.state = Zombie.states.idle
        self:animate(1, 2, dt)
        return
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

    if self.postShotWalkTimer > 0 then
        self.postShotWalkTimer = math.max(0, self.postShotWalkTimer - dt)
        local collidedX, collidedY = self:moveWithVelocity(self.postShotMoveX, self.postShotMoveY, dt)

        if collidedX or collidedY then
            self.postShotMoveX, self.postShotMoveY = self:pickPostShotMove()
        end
        return
    end

    if self.aimWindupTimer > 0 then
        self.aimWindupTimer = math.max(0, self.aimWindupTimer - dt)
        self.state = Zombie.states.idle
        self:updateFacing(Player.x, dt)
        self:animate(1, 2, dt)

        if self.aimWindupTimer == 0 then
            self.shootTimer = 0
            if playerDistance <= self.shootDistance and self:hasLineOfSightToPlayer() and self:shootAtPlayer() then
                self:startPostShotWalk()
            else
                self.gunVisibleTimer = 0
            end
        end
        return
    end

    if playerDistance <= self.shootDistance and self:hasLineOfSightToPlayer() then
        self.state = Zombie.states.idle
        self:updateFacing(Player.x, dt)
        self:animate(1, 2, dt)

        if self.shootTimer >= self.shootCooldown then
            self:startAiming()
        end
        return
    end

    self:ensureRoamTarget(dt)

    self.pathUpdateCounter = self.pathUpdateCounter + dt
    if self.pathUpdateCounter >= self.pathUpdateInterval or self.path == nil or #self.path < 2 then
        self.pathUpdateCounter = 0
        self.path = Tilemap:getPathBetweenWorldPoints(self.x, self.y, self.roamTargetX, self.roamTargetY)
    end

    local velocityX = 0
    local velocityY = 0
    if self.path and #self.path > 1 then
        local nextNode = self.path[2]
        local nextTileX, nextTileY = Tilemap:mapToWorld(nextNode.x, nextNode.y)
        nextTileY = nextTileY - 8

        if distance({x = nextTileX, y = nextTileY}, self) < 4 then
            table.remove(self.path, 1)
            if #self.path > 1 then
                nextNode = self.path[2]
                nextTileX, nextTileY = Tilemap:mapToWorld(nextNode.x, nextNode.y)
                nextTileY = nextTileY - 8
            else
                self.roamTargetTimer = 0
            end
        end

        velocityX = sign(nextTileX - self.x)
        velocityY = sign(nextTileY - self.y)
    else
        self.roamTargetTimer = 0
    end

    self:moveWithVelocity(velocityX, velocityY, dt)
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
