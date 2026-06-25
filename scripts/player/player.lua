require("scripts/utils")

local Player = {}

local Bullet = require("scripts/bullet")
local BallParticle = require("scripts/particles/ballParticle")
local WalkParticle = require("scripts/particles/walkParticle")
local WalkParticleSquare = require("scripts/particles/walkParticleSquare")
local BloodPixel = require("scripts/particles/bloodPixel")
local BloodDecal = require("scripts/particles/bloodDecal")
local Tilemap = require("scripts/tilemap")
local TransitionManager = require("scripts.managers.transitionManager")
local Dash = require("scripts/player/dash")
local CardPickupEffects = require("scripts/player/cardPickupEffects")
local PlayerAnimation = require("scripts/player/playerAnimation")
local playerGlitchShader = love.graphics.newShader("scripts/shaders/playerGlitch.glsl")
local footstepBase = love.audio.newSource("assets/sfx/footsteps/foot-steps-0.mp3", "static")
local damageBase = love.audio.newSource("assets/sfx/player/ow-damage.mp3", "static")
local damageSplatBase = love.audio.newSource("assets/sfx/player/splat.mp3", "static")
local electricBase = love.audio.newSource("assets/sfx/menu/eletric-transition.mp3", "static")
local PLAYER_DAMAGE_HIT_AUDIO_DUCK_DELAY = 0.28
local PLAYER_DAMAGE_OW_DELAY = 0.20
local PLAYER_DAMAGE_OW_CHANCE = 0.40
local heartImage = love.graphics.newImage("assets/sprites/ui/heart.png")
local heartWhiteShader = love.graphics.newShader("scripts/shaders/whiteShader.glsl")
local heartFrameSize = 16
local heartFrames = {
    full = love.graphics.newQuad(0, 0, heartFrameSize, heartFrameSize, heartImage:getDimensions()),
    half = love.graphics.newQuad(heartFrameSize, 0, heartFrameSize, heartFrameSize, heartImage:getDimensions()),
    empty = love.graphics.newQuad(heartFrameSize * 2, 0, heartFrameSize, heartFrameSize, heartImage:getDimensions()),
}
local DAMAGE_KNOCKBACK_DURATION = 0.3
local DAMAGE_KNOCKBACK_SPEED = 125
local DAMAGE_HITSTOP_DURATION = 0.2
local DAMAGE_HITSTOP_RECOVERY = 0.28
local DAMAGE_AUDIO_DISTORTION_DURATION = 0.7
local DAMAGE_AUDIO_VOLUME_DUCK_DURATION = 0.7

heartImage:setFilter("nearest", "nearest")

local function playClonedSound(baseSource, volume, pitch)
    local sound = baseSource:clone()
    setSourceVolume(sound, volume)
    sound:setPitch(pitch)
    sound:play()
    return sound
end

function Player:load(camera, spawnX, spawnY)
    self.x = spawnX or 30
    self.y = spawnY or 340
    self.baseSpeed = 100
    self.speed = self.baseSpeed
    self.velocityX = 0
    self.velocityY = 0
    self.acceleration = 10
    self.friction = 6
    self.size = 40
    self.gun = require("scripts/player/gun")
    self.spriteSize = 40
    self.bullets = {}
    self.bulletSpeed = 340
    self.camera = camera
    self.totalLife = 6
    self.life = self.totalLife
    self.isAlive = true
    self.flipX = false
    self.playerSheet = love.graphics.newImage("assets/sprites/player/alice/alice.png")
    self.playerShadow = love.graphics.newImage("assets/sprites/player/shadow.png")
    self.handImage = love.graphics.newImage("assets/sprites/player/hand.png")
    self.idleHandSheet = love.graphics.newImage("assets/sprites/player/alice/hand.png")
    self.handImage:setFilter("nearest", "nearest")
    self.idleHandSheet:setFilter("nearest", "nearest")
    self.playerSheet:setFilter("nearest", "nearest")
    self.playerShadow:setFilter("nearest", "nearest")
    self.mouseAngle = 0
    self.animations = {
        idle = { frames = {0, 1}, duration = 2 },
        walk = { frames = {2, 3, 4, 5}, duration = 0.52 }
    }
    self.currentAnimation = "idle"
    self.currentFrame = 1
    self.animationTimer = 0
    self.idleHandFrame = 1
    self.idleHandTimer = 0
    self.SquareParticleTime = 0
    self.damageTimer = 4
    self.gun:load()
    self.moveX = 0
    self.moveY = 0
    self.sideChangeTimer = 0
    self.quads = PlayerAnimation.createGridQuads(self.playerSheet, self.spriteSize, 3, 6)
    PlayerAnimation.load(self)

    self.damageAlha = 0

    self.shadowTimer = 0
    self.glitchDuration = 0.35
    self.glitchTimer = 0
    self.glitchDisplacementPixels = 2
    self.whiteFlashDuration = 0.12
    self.whiteFlashTimer = 0
    CardPickupEffects.init(self)
    self.pendingDamageOwTimer = 0
    self.pendingDamageOwPitch = 1
    self.damageBlinkDelay = 0.1
    self.damageVignettePulse = 0
    self.reloadBarFlashDuration = 0.18
    self.reloadBarFlashTimer = 0
    self.reloadBarWasReloading = false
    self.isXrayVisible = true
    self.webSlowTimer = 0
    self.webSlowMultiplier = 1
    self.damageKnockbackTimer = 0
    self.damageKnockbackDuration = DAMAGE_KNOCKBACK_DURATION
    self.damageKnockbackSpeed = DAMAGE_KNOCKBACK_SPEED
    self.damageKnockbackX = 0
    self.damageKnockbackY = 0
    self.dash = Dash:new(self)

end

function Player:isDashing()
    return self.dash and self.dash:isActive()
end

function Player:isActionLocked()
    return self:isDashing() or PlayerAnimation.isFallIntroActive(self)
end

function Player:getDashVisualOffsetY()
    if not (self.dash and self.dash.getVisualOffsetY) then
        return 0
    end

    return self.dash:getVisualOffsetY()
end

function Player:getDashVisualStretch()
    if not (self.dash and self.dash.getVisualStretch) then
        return 0
    end

    return self.dash:getVisualStretch()
end

function Player:tryDash()
    if not (self.isAlive and self.dash) then
        return false
    end

    return self.dash:start()
end

function Player:cancelDash()
    if self.dash and self.dash.reset then
        self.dash:reset()
    elseif self.dash and self.dash.cancel then
        self.dash:cancel()
    elseif self.dash and self.dash.stop then
        self.dash:stop()
    end
end

function Player:restartDashCooldown()
    if self.dash and self.dash.restartCooldown then
        self.dash:restartCooldown()
    end
end

function Player:startDamageKnockback(damageDx, damageDy)
    local dx = damageDx or 0
    local dy = damageDy or 0
    local length = math.sqrt(dx * dx + dy * dy)

    if length <= 0.001 then
        dx = -(self.moveX or 0)
        dy = -(self.moveY or 0)
        length = math.sqrt(dx * dx + dy * dy)
    end
    if length <= 0.001 then
        dx, dy = 0, 1
        length = 1
    end

    self.damageKnockbackX = dx / length
    self.damageKnockbackY = dy / length
    self.damageKnockbackTimer = self.damageKnockbackDuration or DAMAGE_KNOCKBACK_DURATION
end

function Player:updateDamageVignette(dt)
    local damageAlphaTarget = 0
    if self.life and self.life <= 1 then
        damageAlphaTarget = 0.45
    end

    self.damageVignettePulse = transitionValue(self.damageVignettePulse or 0, 0, 2.4, dt)

    local vignetteTarget = math.max(damageAlphaTarget, self.damageVignettePulse or 0)
    local vignetteSpeed = self.damageAlha < vignetteTarget and 14 or 2.4
    self.damageAlha = transitionValue(self.damageAlha or 0, vignetteTarget, vignetteSpeed, dt)
end

function Player:updateAnimation(dt, moving)
    local newAnimation = moving and "walk" or "idle"
    self.shadowTimer = self.shadowTimer + dt

    if self.currentAnimation ~= newAnimation then
        if self.SquareParticleTime > 1.2 and self.animationTimer >0.05 then
            local lifetime = math.random(190, 195) / 100
            local particle = WalkParticleSquare:new(self.x, self.y, lifetime)
            table.insert(Game.particles, particle)
            self.SquareParticleTime = 0

            playClonedSound(footstepBase, 0.18, (2.5 + math.random() * 0.4) * GAME_PITCH)

        end
        self.currentAnimation = newAnimation
        self.currentFrame = 1
        self.animationTimer = 0
        self.idleHandFrame = 1
        self.idleHandTimer = 0
    end
    self.SquareParticleTime = self.SquareParticleTime + dt
    local anim = self.animations[self.currentAnimation]

    if not moving then
        self.currentFrame = 1
        self.animationTimer = 0
        self.idleHandTimer = self.idleHandTimer + dt
        if self.idleHandTimer >= 0.6 then
            self.idleHandTimer = self.idleHandTimer - 0.6
            self.idleHandFrame = self.idleHandFrame == 1 and 2 or 1
        end
        return
    end

    local duration = anim.duration
    if self.gun.showGun then duration = duration * 1.25 end
    local frameTime = duration / #anim.frames

    if self.currentAnimation == "idle" then
        self.idleHandTimer = self.idleHandTimer + dt
        if self.idleHandTimer >= 0.6 then
            self.idleHandTimer = self.idleHandTimer - 0.6
            self.idleHandFrame = self.idleHandFrame == 1 and 2 or 1
        end
    else
        self.idleHandFrame = self.currentFrame
        self.idleHandTimer = 0
    end

    if self.currentAnimation == "idle" and self.currentFrame == 2 then
        frameTime = 0.1
    end

    self.animationTimer = self.animationTimer + dt
    local advancedFrames = 0
    while self.animationTimer >= frameTime and advancedFrames < 4 do
        self.animationTimer = self.animationTimer - frameTime
        self.currentFrame = self.currentFrame + 1
        if self.currentFrame > #anim.frames then
            self.currentFrame = 1
        end
        advancedFrames = advancedFrames + 1

        if moving and self.currentFrame % 2 == 0 then
            
            playClonedSound(footstepBase, 0.34, (0.7 + math.random() * 0.6) * GAME_PITCH)
            
            local lifetime = math.random(45, 55) / 100
            local particle = WalkParticle:new(self.x, self.y, lifetime)

            if math.random() > 0.1 then
                table.insert(Game.particles, particle)
                if math.random() > 0.5 then
                    local particle = WalkParticle:new(self.x + 2, self.y + 2, lifetime)
                    table.insert(Game.particles, particle)
                end
            end
        end
    end


end

function Player:update(dt)
    self.sideChangeTimer = self.sideChangeTimer + dt
    if (self.pendingDamageOwTimer or 0) > 0 then
        self.pendingDamageOwTimer = math.max(0, self.pendingDamageOwTimer - dt)
        if self.pendingDamageOwTimer <= 0 then
            playClonedSound(
                damageBase,
                0.65 * (SOUND_VOLUME or 1),
                (self.pendingDamageOwPitch or 1) * (GAME_PITCH or 1)
            )
        end
    end

    if not self.isAlive then
        return
    end

    self.damageTimer = self.damageTimer + dt
    self.glitchTimer = math.max(0, self.glitchTimer - dt)
    self.whiteFlashTimer = math.max(0, self.whiteFlashTimer - dt)
    CardPickupEffects.update(self, dt)
    self.webSlowTimer = math.max(0, (self.webSlowTimer or 0) - dt)
    local dashMoveX, dashMoveY, dashActive = 0, 0, false
    if self.dash then
        dashMoveX, dashMoveY, dashActive = self.dash:update(dt)
    end

    self.mouseAngle = math.floor(mouseAngle() * 4) / 4
    local moveX, moveY = 0, 0
    local knockbackActive = (self.damageKnockbackTimer or 0) > 0

    -- Input WASD
    if not Dialog.breakMovements and not knockbackActive and not dashActive then
        if love.keyboard.isDown("w") then
            moveY = moveY - 1
        end
        if love.keyboard.isDown("s") then
            moveY = moveY + 1
        end
        if love.keyboard.isDown("a") then
            moveX = moveX - 1
        end
        if love.keyboard.isDown("d") then
            moveX = moveX + 1
        end
    end
    if moveX ~= 0 and moveY ~= 0 then
        local diagFactor = 1 / math.sqrt(2)
        moveX = moveX * diagFactor
        moveY = moveY * diagFactor
    end

    if not dashActive then
        local assistX, assistY = self:getCornerAssistInput(moveX, moveY)
        moveX = moveX + assistX
        moveY = moveY + assistY
    end

    if moveX ~= 0 and moveY ~= 0 then
        local length = math.sqrt(moveX * moveX + moveY * moveY)
        if length > 1 then
            moveX = moveX / length
            moveY = moveY / length
        end
    end

    if moveX ~= 0 or moveY ~= 0 then
        DisableWalkTutorial()
    end

    local speed = self.speed
    if (self.webSlowTimer or 0) > 0 then
        speed = speed * (self.webSlowMultiplier or 0.6)
    elseif self.gun.showGun then
        speed = speed * 0.7
    end

    local targetVelocityX = (knockbackActive or dashActive) and 0 or moveX * speed
    local targetVelocityY = (knockbackActive or dashActive) and 0 or moveY * speed
    local movementSpeed = knockbackActive and self.friction or ((moveX ~= 0 or moveY ~= 0) and self.acceleration or self.friction)

    self.velocityX = transitionValue(self.velocityX, targetVelocityX, movementSpeed, dt)
    self.velocityY = transitionValue(self.velocityY, targetVelocityY, movementSpeed, dt)

    if moveX == 0 and moveY == 0 then
        if math.abs(self.velocityX) < 2 then self.velocityX = 0 end
        if math.abs(self.velocityY) < 2 then self.velocityY = 0 end
    end

    local sumMoveX = self.velocityX * dt
    local sumMoveY = self.velocityY * dt
    if dashActive then
        sumMoveX = dashMoveX
        sumMoveY = dashMoveY
    end
    if not dashActive and (self.damageKnockbackTimer or 0) > 0 then
        local duration = self.damageKnockbackDuration or DAMAGE_KNOCKBACK_DURATION
        local progress = math.max(0, math.min(self.damageKnockbackTimer / math.max(duration, 0.001), 1))
        local knockbackSpeed = (self.damageKnockbackSpeed or DAMAGE_KNOCKBACK_SPEED) * progress * progress
        sumMoveX = sumMoveX + (self.damageKnockbackX or 0) * knockbackSpeed * dt
        sumMoveY = sumMoveY + (self.damageKnockbackY or 0) * knockbackSpeed * dt
        self.damageKnockbackTimer = math.max(0, self.damageKnockbackTimer - dt)
    end

    self:resolveStuckCollision()

    local resolvedMoveX, resolvedMoveY = self:resolveCollisionMove(sumMoveX, sumMoveY)
    local dashCollided = dashActive and (resolvedMoveX ~= sumMoveX or resolvedMoveY ~= sumMoveY)

    if dashCollided then
        if self.dash then
            self.dash:stop()
        end
        sumMoveX = 0
        sumMoveY = 0
        self.velocityX = 0
        self.velocityY = 0
    elseif resolvedMoveX ~= sumMoveX then
        if dashActive and self.dash then
            self.dash:stop()
        end
        sumMoveX = resolvedMoveX
        if sumMoveX == 0 then
            self.velocityX = 0
        end
    end
    if not dashCollided and resolvedMoveY ~= sumMoveY then
        if dashActive and self.dash then
            self.dash:stop()
        end
        sumMoveY = resolvedMoveY
        if sumMoveY == 0 then
            self.velocityY = 0
        end
    end

    local previousX = self.x
    local previousY = self.y
    self.x = self.x + sumMoveX
    self.y = self.y + sumMoveY
    if dashActive and self.dash and self.dash.spawnLineSegment then
        self.dash:spawnLineSegment(previousX, previousY, self.x, self.y)
    end

    addToDrawQueue(self.y + 6, Player)

    local wasReloading = self.reloadBarWasReloading == true
    self.gun:update(dt, self.x, self.y)
    local isReloading = self.gun and self.gun.reloadingSlot ~= nil
    if wasReloading and not isReloading then
        self.reloadBarFlashTimer = self.reloadBarFlashDuration
    elseif isReloading then
        self.reloadBarFlashTimer = 0
    else
        self.reloadBarFlashTimer = math.max(0, (self.reloadBarFlashTimer or 0) - dt)
    end
    self.reloadBarWasReloading = isReloading

    local mouseX, mouseY = mousePosition()

    local canChangeSide = self.sideChangeTimer > 0.25
    local haschangedSide = false
    local visualMoveX = math.abs(sumMoveX) >= 0.01 and sumMoveX or 0
    local visualMoveY = math.abs(sumMoveY) >= 0.01 and sumMoveY or 0

    if (visualMoveX ~= 0 or visualMoveY ~= 0) and canChangeSide then
        self.moveX = visualMoveX
        self.moveY = visualMoveY
        self.sideChangeTimer = 0
    end

    if not self.gun.showGun and visualMoveX ~= 0 and canChangeSide then
        if visualMoveX > 0 then 
            self.flipH = true
        else 
            self.flipH = false
        end
    elseif self.gun.showGun and canChangeSide then

        if mouseX > self.x then
            self.moveX = 1
            self.flipH = true
            self.sideChangeTimer = 0
        elseif mouseX < self.x then
            self.flipH = false
            self.moveX = -1
            self.sideChangeTimer = 0
        end
        if math.abs(mouseX - self.x) < 30 then
            if mouseY > self.y then
                self.moveY = 1
                self.moveX = 0
                self.sideChangeTimer = 0
            elseif mouseY < self.y then
                self.moveY = -1
                self.moveX = 0
                self.sideChangeTimer = 0
            end
        end

 
    end 

    self:checkDamage()


    local actualMoveSpeed = math.sqrt(sumMoveX * sumMoveX + sumMoveY * sumMoveY) / math.max(dt, 0.001)
    local moving = actualMoveSpeed > 3
    self:updateAnimation(dt, moving)
    self:death()
end

function Player:takeDamage(amount, damageDx, damageDy, hitX, hitY)
    if self:isDashing() then return false end
    if self.damageTimer < 1.2 then return false end

    self:restartDashCooldown()
    if Game and Game.startHitStop then
        Game:startHitStop(DAMAGE_HITSTOP_DURATION, DAMAGE_HITSTOP_RECOVERY)
    end
    if Game and Game.startDamageAudioDistortion then
        Game:startDamageAudioDistortion(
            DAMAGE_AUDIO_DISTORTION_DURATION,
            0.58,
            PLAYER_DAMAGE_HIT_AUDIO_DUCK_DELAY,
            DAMAGE_AUDIO_VOLUME_DUCK_DURATION
        )
    end
    damageDx = damageDx or self.velocityX or 0
    damageDy = damageDy or self.velocityY or 0
    if Game and Game.showPlayerDamageFlash then
        Game:showPlayerDamageFlash(damageDx, damageDy, hitX, hitY)
    end
    self:startDamageKnockback(damageDx, damageDy)
    BloodPixel.spawnBurst(self.x, self.y - 2, damageDx, damageDy, 5, 7)
    camera:shake(10, 0.97)
    camera:damageZoom(0.85, 16, 8, 0.06)
    self.life = math.max(0, self.life - (amount or 1))
    if self.life > 0 then
        BloodDecal.spawn(self.x, self.y, damageDx, damageDy, {
            scaleMultiplier = 0.45,
            volumeMultiplier = 0.45,
            pitchMultiplier = 0.78,
        })
    end
    --playClonedSound(electricBase, 0.2, (1.5 + math.random() * 0.1) * GAME_PITCH)
    TransitionManager:setDistortion(1)
    TransitionManager.distortionTimer = 0.5
    self.damageTimer = 0
    self.glitchTimer = self.glitchDuration
    self.whiteFlashTimer = self.whiteFlashDuration
    playClonedSound(damageSplatBase, (0.9 * (SOUND_VOLUME or 1)) , (0.96 + math.random() * 0.08) * (GAME_PITCH or 1))
    if self.life > 0 and math.random() < PLAYER_DAMAGE_OW_CHANCE then
        self.pendingDamageOwTimer = PLAYER_DAMAGE_OW_DELAY
        self.pendingDamageOwPitch = 0.95 + math.random() * 0.36
    else
        self.pendingDamageOwTimer = 0
    end
    self.damageVignettePulse = self.life <= 1 and 1.45 or 1.25
    if self.life <= 0 then
        TransitionManager.distortionTimer = 1
    end

    return true
end

function Player:checkDamage()
    if self:isDashing() then return end
    if self.damageTimer < 1.2 then return end 

    for _, enemy in ipairs(Game.enemies) do
        local dx = enemy.x - self.x
        local dy = enemy.y - self.y
        local distance = math.sqrt(dx * dx + dy * dy)

        if enemy.canDamagePlayer ~= false and distance < 10 then
            --enemy.life = 0
            --enemy:death()
            local damageDx = self.x - enemy.x
            local damageDy = self.y - enemy.y
            local length = math.sqrt(damageDx * damageDx + damageDy * damageDy)
            local hitX, hitY = self.x, self.y - 18
            if length > 0.001 then
                hitX = hitX - (damageDx / length) * 8
                hitY = hitY - (damageDy / length) * 13
            end
            self:takeDamage(1, damageDx, damageDy, hitX, hitY)
            break
        end
    end
end

function Player:catchLife()
    local previousLife = self.life or 0
    if self.life < self.totalLife then
        self.life = math.min(self.totalLife, self.life + 2)
    end
    self.damageTimer = 0
    self.whiteFlashTimer = self.whiteFlashDuration
    return (self.life or 0) - previousLife
end

function Player:startCardPickupFlash()
    CardPickupEffects.start(self)
end

function Player:getCollisionBox()
    local size = 12
    return { x = self.x - size/2, y = self.y - size/2, width = size, height = size, size = size }
end

local function getPlayerTileCollisionBox(tile)
    local box = {
        x = tile.xWorld - tile.size / 2,
        y = tile.yWorld - tile.size,
        width = tile.size,
        height = tile.size,
    }

    return box
end

local function getPlayerOctagonPoints(box)
    local bevel = 3
    local left = box.x
    local right = box.x + box.width
    local top = box.y
    local bottom = box.y + box.height

    return {
        {x = left + bevel, y = top},
        {x = right - bevel, y = top},
        {x = right, y = top + bevel},
        {x = right, y = bottom - bevel},
        {x = right - bevel, y = bottom},
        {x = left + bevel, y = bottom},
        {x = left, y = bottom - bevel},
        {x = left, y = top + bevel},
    }
end

local function getRectPoints(box)
    return {
        {x = box.x, y = box.y},
        {x = box.x + box.width, y = box.y},
        {x = box.x + box.width, y = box.y + box.height},
        {x = box.x, y = box.y + box.height},
    }
end

local function projectPolygon(points, axisX, axisY)
    local minProjection = points[1].x * axisX + points[1].y * axisY
    local maxProjection = minProjection

    for i = 2, #points do
        local projection = points[i].x * axisX + points[i].y * axisY
        minProjection = math.min(minProjection, projection)
        maxProjection = math.max(maxProjection, projection)
    end

    return minProjection, maxProjection
end

local function polygonsOverlapOnAxis(aPoints, bPoints, axisX, axisY)
    local aMin, aMax = projectPolygon(aPoints, axisX, axisY)
    local bMin, bMax = projectPolygon(bPoints, axisX, axisY)
    return aMax > bMin and bMax > aMin
end

local function addPolygonAxes(points, axes)
    for i = 1, #points do
        local a = points[i]
        local b = points[i % #points + 1]
        local edgeX = b.x - a.x
        local edgeY = b.y - a.y
        local axisX = -edgeY
        local axisY = edgeX
        local length = math.sqrt(axisX * axisX + axisY * axisY)

        if length > 0 then
            axes[#axes + 1] = {x = axisX / length, y = axisY / length}
        end
    end
end

local function polygonsCollide(aPoints, bPoints)
    local axes = {}
    addPolygonAxes(aPoints, axes)
    addPolygonAxes(bPoints, axes)

    for _, axis in ipairs(axes) do
        if not polygonsOverlapOnAxis(aPoints, bPoints, axis.x, axis.y) then
            return false
        end
    end

    return true
end

local function isPlayerTileColliding(playerBox, tile)
    local tileBox = getPlayerTileCollisionBox(tile)
    if not checkCollision(playerBox, tileBox) then
        return false
    end

    return polygonsCollide(getPlayerOctagonPoints(playerBox), getRectPoints(tileBox))
end

local function clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

local function getCircleTileCollision(centerX, centerY, radius, tile)
    local tileBox = getPlayerTileCollisionBox(tile)
    local closestX = clamp(centerX, tileBox.x, tileBox.x + tileBox.width)
    local closestY = clamp(centerY, tileBox.y, tileBox.y + tileBox.height)
    local dx = centerX - closestX
    local dy = centerY - closestY
    local distSq = dx * dx + dy * dy

    if distSq > radius * radius then
        return nil
    end

    if distSq > 0.0001 then
        local dist = math.sqrt(distSq)
        return {
            normalX = dx / dist,
            normalY = dy / dist,
            penetration = radius - dist,
        }
    end

    local leftDepth = math.abs(centerX - tileBox.x)
    local rightDepth = math.abs((tileBox.x + tileBox.width) - centerX)
    local topDepth = math.abs(centerY - tileBox.y)
    local bottomDepth = math.abs((tileBox.y + tileBox.height) - centerY)
    local minDepth = math.min(leftDepth, rightDepth, topDepth, bottomDepth)

    if minDepth == leftDepth then
        return {normalX = -1, normalY = 0, penetration = radius}
    elseif minDepth == rightDepth then
        return {normalX = 1, normalY = 0, penetration = radius}
    elseif minDepth == topDepth then
        return {normalX = 0, normalY = -1, penetration = radius}
    end

    return {normalX = 0, normalY = 1, penetration = radius}
end

local function getObjectCollisionBoxes(object)
    if not (object and object.isAlive ~= false and object.blocksPlayer) then
        return nil
    end

    if type(object.collisionBoxes) == "function" then
        return object:collisionBoxes()
    end

    if type(object.collisionBox) == "function" then
        local box = object:collisionBox()
        return box and {box} or nil
    end

    return nil
end

local function isPlayerCollidingWithBlockingObjects(playerBox)
    for _, object in ipairs((Game and Game.objects) or {}) do
        local boxes = getObjectCollisionBoxes(object)
        for _, box in ipairs(boxes or {}) do
            if checkCollision(playerBox, box) then
                return true
            end
        end
    end

    return false
end

function Player:getTileCollisionAtOffset(moveX, moveY)
    local radius = 6
    local centerX = self.x + (moveX or 0)
    local centerY = self.y + (moveY or 0)

    local closeTiles = Tilemap:getNearbyTiles(centerX, centerY)
    local bestCollision = nil
    for _, tile in ipairs(closeTiles) do
        if tile.collider then
            local collision = getCircleTileCollision(centerX, centerY, radius, tile)
            if collision and (not bestCollision or collision.penetration > bestCollision.penetration) then
                bestCollision = collision
            end
        end
    end

    return bestCollision
end

function Player:isCollidingAtOffset(moveX, moveY)
    local playerBox = self:getCollisionBox()
    playerBox.x = playerBox.x + (moveX or 0)
    playerBox.y = playerBox.y + (moveY or 0)

    if self:getTileCollisionAtOffset(moveX, moveY) then
        return true
    end

    for _, enemy in ipairs((Game and Game.enemies) or {}) do
        if enemy.isAlive and enemy.blocksPlayer and enemy.collisionBox then
            if checkCollision(playerBox, enemy:collisionBox()) then
                return true
            end
        end
    end

    if isPlayerCollidingWithBlockingObjects(playerBox) then
        return true
    end

    return false
end

function Player:getCornerAssistInput(moveX, moveY)
    local assistStrength = 0.42
    local lookAhead = 4.4

    if moveX ~= 0 and moveY == 0 then
        local collision = self:getTileCollisionAtOffset((moveX > 0 and 1 or -1) * lookAhead, 0)
        if collision and math.abs(collision.normalY) > 0.18 then
            return 0, collision.normalY * assistStrength
        end
    elseif moveY ~= 0 and moveX == 0 then
        local collision = self:getTileCollisionAtOffset(0, (moveY > 0 and 1 or -1) * lookAhead)
        if collision and math.abs(collision.normalX) > 0.18 then
            return collision.normalX * assistStrength, 0
        end
    end

    return 0, 0
end

function Player:resolveCollisionMove(moveX, moveY)
    local collision = self:getTileCollisionAtOffset(moveX, moveY)
    if not collision and not self:isCollidingAtOffset(moveX, moveY) then
        return moveX, moveY
    end

    if collision then
        local dot = moveX * collision.normalX + moveY * collision.normalY
        if dot < 0 then
            local stickiness = 0.14
            local slideX = moveX - collision.normalX * dot
            local slideY = moveY - collision.normalY * dot
            local resolvedX = slideX * (1 - stickiness)
            local resolvedY = slideY * (1 - stickiness)

            for _ = 1, 4 do
                if not self:isCollidingAtOffset(resolvedX, resolvedY) then
                    return resolvedX, resolvedY
                end
                resolvedX = resolvedX * 0.5
                resolvedY = resolvedY * 0.5
            end
        end
    end

    if moveX ~= 0 and not self:isCollidingAtOffset(moveX, 0) then
        return moveX, 0
    end
    if moveY ~= 0 and not self:isCollidingAtOffset(0, moveY) then
        return 0, moveY
    end

    return 0, 0
end

function Player:resolveStuckCollision()
    if not self:isCollidingAtOffset(0, 0) then
        return
    end

    local directions = {
        {x = 0, y = -1},
        {x = 1, y = 0},
        {x = 0, y = 1},
        {x = -1, y = 0},
        {x = 1, y = -1},
        {x = 1, y = 1},
        {x = -1, y = 1},
        {x = -1, y = -1},
    }

    for distanceStep = 0.5, 6, 0.5 do
        for _, direction in ipairs(directions) do
            local moveX = direction.x * distanceStep
            local moveY = direction.y * distanceStep
            if not self:isCollidingAtOffset(moveX, moveY) then
                self.x = self.x + moveX
                self.y = self.y + moveY
                return
            end
        end
    end
end

function Player:isColliding(moveX, moveY, size)
    if not size then size = self:getCollisionBox().size end

    local playerBoxX = self:getCollisionBox()
    playerBoxX.x = playerBoxX.x + moveX
    local playerBoxY = self:getCollisionBox()
    playerBoxY.y = playerBoxY.y + moveY

    local collidedX = false
    local collidedY = false

    local closeTiles = Tilemap:getNearbyTiles(self.x, self.y)
    for _, tile in ipairs(closeTiles) do
        if tile.collider then
            if isPlayerTileColliding(playerBoxX, tile) then
                collidedX = true
            end
            if isPlayerTileColliding(playerBoxY, tile) then
                collidedY = true
            end
        end
    end

    for _, enemy in ipairs((Game and Game.enemies) or {}) do
        if enemy.isAlive and enemy.blocksPlayer and enemy.collisionBox then
            local enemyBox = enemy:collisionBox()
            if checkCollision(playerBoxX, enemyBox) then
                collidedX = true
            end
            if checkCollision(playerBoxY, enemyBox) then
                collidedY = true
            end
        end
    end

    for _, object in ipairs((Game and Game.objects) or {}) do
        local boxes = getObjectCollisionBoxes(object)
        for _, box in ipairs(boxes or {}) do
            if checkCollision(playerBoxX, box) then
                collidedX = true
            end
            if checkCollision(playerBoxY, box) then
                collidedY = true
            end
        end
    end

    return collidedX, collidedY
end

function Player:death()
    if self.life > 0 or not self.isAlive then
        return
    end
    
    self.isAlive = false 
    BloodDecal.spawn(self.x, self.y, self.velocityX or 0, self.velocityY or 0, {
        scaleMultiplier = 1.15,
        volumeMultiplier = 1,
        pitchMultiplier = 0.82,
    })
    for i = 1, -3 do
        local angle = math.random() * 2 * math.pi

        local dx = math.cos(angle)
        local dy = math.sin(angle)
        
        local lifetime = math.random(30, 45) / 100
        local size = math.random(8, 10) / 10
        local particle = BallParticle:new(self.x, self.y, 1,dx, dy, lifetime, size)
        table.insert(Game.particles, particle)
        local particle = BallParticle:new(self.x, self.y, 1,-dx, -dy, lifetime, size)
        table.insert(Game.particles, particle)
    end
    playerDeath()

end

function Player:drawLife()
    if not self.isAlive then
        return
    end
    local blink = false
    if self.life <= 1 then
        local time = love.timer.getTime()
        blink = math.floor(time * 3) % 2 ~= 0
    end

    local scale = 3
    local spacing = -16
    local startX = 3
    local startY = 46
    local shouldFlashWhite = self.damageTimer < 0.4

    if shouldFlashWhite then
        love.graphics.setShader(heartWhiteShader)
    end

    local slots = math.max(1, math.floor((self.totalLife or 0) / 2 + 0.5))
    for i = 1, slots do
        local remaining = self.life - ((i - 1) * 2)
        local frame = heartFrames.empty

        if remaining >= 2 then
            frame = heartFrames.full
        elseif remaining == 1 and not (i == 1 and blink) then
            frame = heartFrames.half
        end

        local x = startX + (i - 1) * (heartFrameSize * scale + spacing)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(heartImage, frame, x, startY, 0, scale, scale)
    end

    if shouldFlashWhite then
        love.graphics.setShader()
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function Player:drawSight()
    if not self.isAlive then
        return
    end
    if self:isActionLocked() then return end
    if Dialog.breakMovements then return end


    self.gun:drawSight()
end

function Player:drawShadow()
    if not self.isAlive then
        return
    end

    local alpha = PlayerAnimation.getFallIntroShadowAlpha(self)
    if alpha <= 0 then
        return
    end

    love.graphics.setColor(1, 1, 1, alpha)
    if math.floor(self.shadowTimer * 2) % 2 == 0 then
        love.graphics.draw(self.playerShadow, self.x, self.y, 0, 1, 1, 8, 8)
    else
        love.graphics.draw(self.playerShadow, self.x, self.y, 0, 0.98, 1, 8, 8)

    end
    love.graphics.setColor(1, 1, 1, 1)
    
end

function Player:drawReloadBar()
    if not (self.gun and self.gun.getReloadProgress) then
        return
    end

    local progress = self.gun:getReloadProgress()
    local flashTimer = self.reloadBarFlashTimer or 0
    local isFlashing = not progress and flashTimer > 0
    if not progress and not isFlashing then
        return
    end

    progress = progress or 1

    local width = 7
    local height = 1.2
    local x = math.floor(self.x - width / 2 + 0.5)
    local y = math.floor(self.y - 42 + 0.5)
    local r, g, b, a = love.graphics.getColor()
    local flashProgress = isFlashing and (flashTimer / self.reloadBarFlashDuration) or 0
    local fillAlpha = isFlashing and (0.95 * flashProgress) or 0.72
    local backAlpha = isFlashing and (0.14 * flashProgress) or 0.18
    local outlineAlpha = isFlashing and (0.32 * flashProgress) or 0.24

    love.graphics.setColor(1, 1, 1, backAlpha)
    love.graphics.rectangle("fill", x, y, width, height)
    love.graphics.setColor(1, 1, 1, fillAlpha)
    love.graphics.rectangle("fill", x, y, width * progress, height)
    love.graphics.setColor(1, 1, 1, outlineAlpha)
    love.graphics.rectangle("line", x - 1, y - 1, width + 2, height + 2)
    love.graphics.setColor(r, g, b, a)
end

function Player:drawSquare(x, y, angle, halfSize)
    local cx, cy = x, y
    local cosA, sinA = math.cos(angle), math.sin(angle)

    local x1 = cx + (-halfSize * cosA - (-halfSize) * sinA)
    local y1 = cy + (-halfSize * sinA + (-halfSize) * cosA)

    local x2 = cx + (halfSize * cosA - (-halfSize) * sinA)
    local y2 = cy + (halfSize * sinA + (-halfSize) * cosA)

    local x3 = cx + (halfSize * cosA - halfSize * sinA)
    local y3 = cy + (halfSize * sinA + halfSize * cosA)

    local x4 = cx + (-halfSize * cosA - halfSize * sinA)
    local y4 = cy + (-halfSize * sinA + halfSize * cosA)

    love.graphics.setLineWidth(0.8)
    love.graphics.line(x1, y1, x2, y2)
    love.graphics.line(x2, y2, x3, y3)
    love.graphics.line(x3, y3, x4, y4)
    love.graphics.line(x4, y4, x1, y1)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setLineWidth(1)
end

function Player:drawHand()
    if not self.gun.showGun then return end
    if Dialog.breakMovements then return end

    local handX = self.x + math.cos(self.mouseAngle) * 5
    local handY = self.y + math.sin(self.mouseAngle) * 7

    local scaleX = (math.cos(self.mouseAngle) < 0) and -1 or 1

    self:drawPlayerImage(
        self.handImage,
        nil,
        handX - 8,
        handY - 2,
        0,
        1,
        1.2,
        0,
        16
    )
    local visualOffsetY = self:getDashVisualOffsetY()
    if visualOffsetY ~= 0 then
        self.gun.y = self.gun.y + visualOffsetY
        self.gun:draw()
        self.gun.y = self.gun.y - visualOffsetY
    else
        self.gun:draw()
    end

end

function Player:drawIdleHand(quad, scaleX, originX)
    if self.gun.showGun then return end

    self:drawPlayerImage(
        self.idleHandSheet,
        quad,
        self.x,
        self.y,
        0,
        scaleX,
        1.4,
        originX,
        self.spriteSize
    )
end

function Player:applyGlitchShader(image)
    if self.glitchTimer <= 0 and self.whiteFlashTimer <= 0 then
        return false
    end

    local intensity = 0
    if self.glitchTimer > 0 then
        intensity = self.glitchTimer / self.glitchDuration
    end

    local flash = 0
    if self.whiteFlashTimer > 0 and math.floor(self.whiteFlashTimer * 18) % 2 == 0 then
        flash = 1
    end

    playerGlitchShader:send("texturePixelSize", {
        1 / image:getWidth(),
        1 / image:getHeight()
    })
    playerGlitchShader:send("displacementPixels", self.glitchDisplacementPixels)
    playerGlitchShader:send("time", love.timer.getTime())
    playerGlitchShader:send("intensity", intensity)
    playerGlitchShader:send("flash", flash)
    love.graphics.setShader(playerGlitchShader)
    return true
end

function Player:drawPlayerImage(image, quad, x, y, rotation, scaleX, scaleY, originX, originY)
    local hasGlitch = self:applyGlitchShader(image)
    local visualOffsetY = self:getDashVisualOffsetY()
    local visualStretch = self:getDashVisualStretch()
    y = y + visualOffsetY
    scaleX = (scaleX or 1) * (1 - visualStretch * 0.5)
    scaleY = (scaleY or 1) * (1 + visualStretch)

    local function drawImageWithCurrentColor()
        if quad then
            love.graphics.draw(
                image,
                quad,
                x,
                y,
                rotation or 0,
                scaleX or 1,
                scaleY or 1,
                originX or 0,
                originY or 0
            )
        else
            love.graphics.draw(
                image,
                x,
                y,
                rotation or 0,
                scaleX or 1,
                scaleY or 1,
                originX or 0,
                originY or 0
            )
        end
    end

    local dashTint = self:isDashing() and self.dash
    if dashTint then
        self.dash:beginPlayerTint()
    else
        love.graphics.setColor(1, 1, 1, 1)
    end
    drawImageWithCurrentColor()
    if dashTint then
        self.dash:endTint()
    end

    if quad then
        local flashProgress = CardPickupEffects.getFlashProgress(self)
        if flashProgress > 0 then
            local previousBlendMode, previousAlphaMode = love.graphics.getBlendMode()
            love.graphics.setShader()
            love.graphics.setBlendMode("add", "alphamultiply")
            love.graphics.setColor(1, 1, 1, 0.95 * flashProgress)
            drawImageWithCurrentColor()
            love.graphics.setBlendMode(previousBlendMode, previousAlphaMode)
            if hasGlitch then
                self:applyGlitchShader(image)
            end
        end
    end

    if hasGlitch then
        love.graphics.setShader()
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function Player:draw()
    if not self.isAlive then return end

    if PlayerAnimation.drawFallIntro(self) then
        return
    end

    if self.dash then
        self.dash:drawAfterimages(self)
    end

    if self.damageTimer > (self.damageBlinkDelay or 0) and self.damageTimer < 1 then
        if math.floor(self.damageTimer * 15) % 2 == 0 then
            return
        end
    end

    local anim = self.animations[self.currentAnimation]
    local frameIndex = anim.frames[self.currentFrame]
    local handFrameIndex = frameIndex

    local quad = self.quads[frameIndex + 1] -- +1 porque Lua começa em 1

    local handQuad = quad

    if self.moveX == 0 and self.moveY > 0  then
        quad = self.quads[frameIndex + 1 + 6]
        handQuad = quad

    end

    if self.moveX == 0 and self.moveY < 0  then
        quad = self.quads[frameIndex + 1 + 12]
        handQuad = quad

    end

    if self.currentAnimation == "idle" then
        handFrameIndex = anim.frames[self.idleHandFrame]
        handQuad = self.quads[handFrameIndex + 1]

        if self.moveX == 0 and self.moveY > 0 then
            handQuad = self.quads[handFrameIndex + 1 + 6]
        end

        if self.moveX == 0 and self.moveY < 0 then
            handQuad = self.quads[handFrameIndex + 1 + 12]
        end
    end
    

    local walkStretchX = 1
    local walkStretchY = 1
    if self.currentAnimation == "walk" then
        local walkDuration = anim.duration
        if self.gun.showGun then walkDuration = walkDuration * 1.25 end

        local walkFrameTime = walkDuration / #anim.frames
        local frameProgress = math.min(self.animationTimer / walkFrameTime, 1)
        local loopProgress = ((self.currentFrame - 1) + frameProgress) / #anim.frames
        local walkPulse = math.sin(loopProgress * math.pi * 4)

        walkStretchX = 1 + walkPulse * 0.025
        walkStretchY = 1 - walkPulse * 0.018
    end

    local scaleX = (self.flipH and -1 or 1) * walkStretchX
    local scaleY = 1.4 * walkStretchY
    local originX = self.flipH and (self.spriteSize - self.spriteSize / 2) or (self.spriteSize / 2)
    
    local mouseX, mouseY = mousePosition()

    if mouseY > self.y then

        self:drawPlayerImage(self.playerSheet, quad, self.x, self.y, 0, scaleX, scaleY, originX, self.spriteSize)
        if self.gun.showGun then
            self:drawHand()
        else
            self:drawIdleHand(handQuad, scaleX, originX)
        end
    else 
        if self.gun.showGun then
            self:drawHand()
        end
        self:drawPlayerImage(self.playerSheet, quad, self.x, self.y, 0, scaleX, scaleY, originX, self.spriteSize)
        self:drawIdleHand(handQuad, scaleX, originX)
    end

    self:drawReloadBar()

end

function Player:getCurrentDrawQuads()
    local anim = self.animations[self.currentAnimation]
    local frameIndex = anim.frames[self.currentFrame]
    local handFrameIndex = frameIndex
    local quad = self.quads[frameIndex + 1]
    local handQuad = quad

    if self.moveX == 0 and self.moveY > 0 then
        quad = self.quads[frameIndex + 1 + 6]
        handQuad = quad
    end

    if self.moveX == 0 and self.moveY < 0 then
        quad = self.quads[frameIndex + 1 + 12]
        handQuad = quad
    end

    if self.currentAnimation == "idle" then
        handFrameIndex = anim.frames[self.idleHandFrame]
        handQuad = self.quads[handFrameIndex + 1]

        if self.moveX == 0 and self.moveY > 0 then
            handQuad = self.quads[handFrameIndex + 1 + 6]
        end

        if self.moveX == 0 and self.moveY < 0 then
            handQuad = self.quads[handFrameIndex + 1 + 12]
        end
    end

    return quad, handQuad
end

function Player:drawXray()
    if not self.isAlive then return end

    local quad, handQuad = self:getCurrentDrawQuads()
    local scaleX = self.flipH and -1 or 1
    local scaleY = 1.4
    local originX = self.flipH and (self.spriteSize - self.spriteSize / 2) or (self.spriteSize / 2)

    love.graphics.draw(self.playerSheet, quad, self.x, self.y, 0, scaleX, scaleY, originX, self.spriteSize)

    if self.gun and self.gun.showGun and not Dialog.breakMovements then
        local handX = self.x + math.cos(self.mouseAngle) * 5
        local handY = self.y + math.sin(self.mouseAngle) * 7
        love.graphics.draw(self.handImage, handX - 8, handY - 2, 0, 1, 1.2, 0, 16)

        local slot = self.gun.getSelectedWeaponSlot and self.gun:getSelectedWeaponSlot()
        if slot and self.gun.gunSheet then
            local weaponQuad = love.graphics.newQuad(
                (slot.index - 1) * self.gun.size,
                0,
                self.gun.size,
                self.gun.size,
                self.gun.gunSheet:getDimensions()
            )
            local angle = self.gun.angle or self.mouseAngle
            local offsetX = math.cos(angle) * (self.gun.centerDistance or 0)
            local offsetY = math.sin(angle) * (self.gun.centerDistance or 0)
            love.graphics.draw(
                self.gun.gunSheet,
                weaponQuad,
                self.x + offsetX,
                self.y + offsetY - (self.gun.height or 16),
                angle,
                0.8,
                0.8,
                0,
                self.gun.size / 2
            )
        end
    elseif not self.gun or not self.gun.showGun then
        love.graphics.draw(self.idleHandSheet, handQuad, self.x, self.y, 0, scaleX, 1.4, originX, self.spriteSize)
    end
end

return Player
