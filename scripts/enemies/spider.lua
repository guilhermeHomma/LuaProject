local Zombie = require("scripts/enemies/zombie")
local Tilemap = require("scripts/tilemap")
local EnemyDirector = require("scripts/enemies/enemyDirector")
local SpiderWeb = require("scripts/particles/spiderWeb")

local spiderSoundBase = love.audio.newSource("assets/sfx/enemies/spider.mp3", "static")
local footstepSounds = {
    love.audio.newSource("assets/sfx/footsteps/foot-steps-1.mp3", "static"),
    love.audio.newSource("assets/sfx/footsteps/foot-steps-0.mp3", "static"),
}

local function setSourcePositionIfMono(source, x, y, z)
    if not source then
        return false
    end

    if source.getChannelCount then
        local ok, channelCount = pcall(source.getChannelCount, source)
        if ok and channelCount and channelCount > 1 then
            return false
        end
    elseif source.getChannels then
        local ok, channelCount = pcall(source.getChannels, source)
        if ok and channelCount and channelCount > 1 then
            return false
        end
    end

    local ok = pcall(function()
        source:setPosition(x, y, z or 0)
    end)
    return ok
end

local Spider = setmetatable({}, {__index = Zombie})
Spider.__index = Spider
Spider.enemyTypeId = "spider"
local SPIDER_COLLISION_RADIUS = 6 * 2.5
local WEB_DROP_CHANCE = 0.05

local function distanceSqToPoint(x1, y1, x2, y2)
    local dx = x1 - x2
    local dy = y1 - y2
    return dx * dx + dy * dy
end

local function playSpiderFootstep(playerDistance)
    local now = love.timer.getTime()
    if now - (Spider.lastFootstepSoundTime or 0) < 0.018 then
        return
    end

    Spider.lastFootstepSoundTime = now
    local baseSound = footstepSounds[math.random(1, #footstepSounds)]
    local sound = baseSound:clone()
    sound:setVolume(getDistanceVolume(playerDistance, 0.38, 175))
    sound:setPitch((1.3 + math.random() * 0.3) * (GAME_PITCH or 1))
    sound:play()
end

function Spider:new(x, y)
    local enemy = Zombie.new(self, x, y, math.random(80, 92))
    enemy.totalLife = 38
    enemy.life = enemy.totalLife
    enemy.size = SPIDER_COLLISION_RADIUS
    enemy.dropPoints = 0
    enemy.roamAroundPlayer = false
    enemy.pathUpdateInterval = 0.25
    enemy.pathUpdateCounter = enemy.pathUpdateInterval
    enemy.idleDuration = 0.6
    enemy.walkDuration = 8
    enemy.randomPathTiles = 6
    enemy.randomPathIdleTimer = 0.6
    enemy.randomPathPauseTimer = math.random() * 0.35
    enemy.footStepAlpha = 0.18
    enemy.footStepVisualInterval = 0.5
    enemy.animationSpeed = 0.1
    enemy.noise = spiderSoundBase:clone()
    enemy.soundInterval = 3.8 + math.random() * 2.4
    enemy.damageImpactHeightRatio = 0.62
    enemy.bloodSpawnYOffset = -2
    enemy.hitBloodPixelMin = 2
    enemy.hitBloodPixelMax = 3
    enemy.deathBloodPixelMin = 5
    enemy.deathBloodPixelMax = 7
    enemy.hitBloodDecalCooldown = 0.18
    enemy.hitBloodDecalScaleMultiplier = 0.34
    enemy.hitBloodDecalVolumeMultiplier = 0.55
    enemy.hitBloodDecalPitchMultiplier = 0.62
    enemy.deathBloodDecalOptions = {
        scaleMultiplier = 0.72,
        volumeMultiplier = 0.72,
    }
    enemy.deadDropParticleMin = 1
    enemy.deadDropParticleMax = 2
    enemy.footstepEveryWalkFrame = true
    enemy.skipWalkParticles = true
    enemy.mouthVariant = "none"
    enemy.spawnIntroDuration = 0.2
    enemy.spawnIntroTimer = enemy.spawnIntroDuration
    return enemy
end

function Spider:getSpriteKey()
    return "assets/sprites/enemy/spider/spider.png"
end

function Spider:drawMouth()
end

function Spider:noiseCheck(dt)
    self.soundTimer = self.soundTimer + dt

    if self.soundTimer < (self.soundInterval or 5) or not Player.isAlive then
        return
    end

    self.soundTimer = 0
    self.soundInterval = 3.8 + math.random() * 2.4
    local soundPositionX, soundPositionY = soundPosition(Player, self)
    local playerDistance = distance(Player, self) / 2
    local volume = getDistanceVolume(playerDistance, 0.18, 180)
    self.noise:stop()
    setSourcePositionIfMono(self.noise, soundPositionX, soundPositionY, 0)
    self.noise:setVolume(volume)
    self.noise:setPitch((1.1 + math.random() * 0.1) * (GAME_PITCH or 1))
    self.noise:play()
end

function Spider:playFootstepSound(playerDistance)
    playSpiderFootstep(playerDistance)
    return true
end

function Spider:getShotCollisionCircles()
    return {
        { x = self.x, y = self.y, radius = 6 },
        { x = self.x, y = self.y - 4, radius = 6 },
    }
end

function Spider:checkShotCollision(bullet)
    local radius = (bullet.radius or 1.1) + 6
    local radiusSq = radius * radius
    local dx = bullet.x - self.x
    local dy = bullet.y - self.y

    if dx * dx + dy * dy < radiusSq then
        return true
    end

    dy = bullet.y - (self.y - 4)
    return dx * dx + dy * dy < radiusSq
end

function Spider:drawShadow()
    if not self.isAlive then
        return
    end

    love.graphics.draw(self.spriteShadow, self.x - 8, self.y - 12, 0, 1.2, 1.2)
end

function Spider:pickRandomPathTarget()
    local currentMapX, currentMapY = Tilemap:worldToMap(self.x, self.y)
    local distanceTiles = self.randomPathTiles or 6

    local angle = math.random() * math.pi * 2
    local targetMapX = currentMapX + math.floor(math.cos(angle) * distanceTiles + 0.5)
    local targetMapY = currentMapY + math.floor(math.sin(angle) * distanceTiles + 0.5)
    local targetX, targetY = Tilemap:mapToWorld(targetMapX, targetMapY)
    targetY = targetY - 8

    local path = nil
    local requested = true
    if EnemyDirector and EnemyDirector.requestPath then
        path, requested = EnemyDirector:requestPath(self.x, self.y, targetX, targetY)
    else
        path = Tilemap:getPathBetweenWorldPoints(self.x, self.y, targetX, targetY)
    end
    if path and #path > 1 then
        return path
    end

    return requested and nil or self.path
end

function Spider:startIdlePause()
    self:tryDropWeb()
    self.state = Zombie.states.idle
    self.stateTimer = 0
    self.path = nil
    self.randomPathPauseTimer = self.randomPathIdleTimer or 0.6
end

function Spider:tryDropWeb()
    if math.random() >= WEB_DROP_CHANCE then
        return
    end

    local mapX, mapY = Tilemap:worldToMap(self.x, self.y)
    if SpiderWeb.hasAtTile(mapX, mapY) then
        return
    end

    local webX, webY = Tilemap:mapToWorld(mapX, mapY)
    SpiderWeb.spawn(webX, webY - 8, mapX, mapY)
end

function Spider:updateDying(dt)
    if not self.spiderDying then
        return false
    end

    self.spiderDeathTimer = (self.spiderDeathTimer or 0) + dt
    self:animate(7, 8, dt)
    addToDrawQueue(self.y + 3 + self.drawPriority, self)

    if self.spiderDeathTimer >= (self.spiderDeathDuration or 0.28) then
        self.spiderDying = false
        Zombie.death(self)
    end

    return true
end

function Spider:startDying()
    if self.spiderDying then
        return
    end

    self.spiderDying = true
    self.spiderDeathTimer = 0
    self.spiderDeathDuration = 0.28
    self.canDamagePlayer = false
    self.state = Zombie.states.idle
    self.currentFrame = 7
    self.animationTimer = 0
end

function Spider:update(dt)
    if self:updateDying(dt) then
        return
    end

    addToDrawQueue(self.y + 3 + self.drawPriority, self)

    local dispSq = (self.x - (self.prevX or self.x))^2 + (self.y - (self.prevY or self.y))^2
    if dispSq > (10 * dt)^2 then
        self.visualWalkTimer = math.min((self.visualWalkTimer or 0) + dt, 0.15)
    else
        self.visualWalkTimer = math.max((self.visualWalkTimer or 0) - dt * 2, 0)
    end
    self.isVisuallyWalking = (self.visualWalkTimer or 0) > 0.08
    self.prevX = self.x
    self.prevY = self.y

    if self.spawnIntroTimer and self.spawnIntroTimer > 0 then
        self.spawnIntroTimer = math.max(0, self.spawnIntroTimer - dt)
        self.state = Zombie.states.idle
        self:animate(1, 2, dt)
        return
    end

    self.glitchTimer = math.max(0, self.glitchTimer - dt)
    self.whiteFlashTimer = math.max(0, self.whiteFlashTimer - dt)
    self:noiseCheck(dt)

    if self.life <= 0 then
        if self.state == Zombie.states.damage then
            self.stateTimer = self.stateTimer + dt
            self:animate(1, 2, dt)
            if self.stateTimer >= self.damageTimer then
                self:startDying()
            end
        else
            self:startDying()
        end
        return
    end

    if self.state == Zombie.states.damage then
        self.stateTimer = self.stateTimer + dt
        self:animate(1, 2, dt)

        local moveX = self.kbdx * dt * 0.05
        local moveY = self.kbdy * dt * 0.05
        local collidedX, collidedY = self:isColliding(moveX, moveY)
        if not collidedX then self.x = self.x + moveX end
        if not collidedY then self.y = self.y + moveY end

        if self.stateTimer >= self.damageTimer then
            self.stateTimer = 0
            self:startIdlePause()
        end
        return
    end

    if (self.randomPathPauseTimer or 0) > 0 then
        self.randomPathPauseTimer = math.max(0, self.randomPathPauseTimer - dt)
        self.state = Zombie.states.idle
        self:animate(1, 2, dt)
        return
    end

    if not EnemyDirector:shouldUsePathfinding(self) then
        self.roamTargetTimer = math.max(0, (self.roamTargetTimer or 0) - dt)
        local needsRandomTarget = not self.roamTargetX
            or not self.roamTargetY
            or self.roamTargetTimer <= 0
            or distance({x = self.roamTargetX, y = self.roamTargetY}, self) < 8
        if needsRandomTarget then
            EnemyDirector:configureRandomRoam(self, 1.1 + math.random() * 1.4)
        end

        local velocityX = (self.roamTargetX or self.x) - self.x
        local velocityY = (self.roamTargetY or self.y) - self.y
        local length = math.sqrt(velocityX * velocityX + velocityY * velocityY)
        if length <= 0 then
            self:startIdlePause()
            return
        end

        velocityX = velocityX / length
        velocityY = velocityY / length
        local repulseX, repulseY = self:getRepulsionVector()
        velocityX = velocityX + repulseX * 6
        velocityY = velocityY + repulseY * 6
        length = math.sqrt(velocityX * velocityX + velocityY * velocityY)
        if length > 0 then
            velocityX = velocityX / length
            velocityY = velocityY / length
        end
        self.state = Zombie.states.walk
        if self.isVisuallyWalking then self:animate(3, 6, dt) else self:animate(1, 2, dt) end

        local moveX = velocityX * self.speed * dt
        local moveY = velocityY * self.speed * dt
        local previousX, previousY = self.x, self.y
        local collidedX, collidedY = self:isColliding(moveX, moveY)
        if not collidedX then self.x = self.x + moveX end
        if not collidedY then self.y = self.y + moveY end
        if (collidedX or collidedY) and distanceSqToPoint(previousX, previousY, self.x, self.y) < 0.2 * 0.2 then
            self:startIdlePause()
        end
        return
    end

    if not self.path or #self.path < 2 then
        self.path = self:pickRandomPathTarget()
        if not self.path then
            self:startIdlePause()
            return
        end
    end

    local nextNode = self.path[2]
    local nextTileX, nextTileY = Tilemap:mapToWorld(nextNode.x, nextNode.y)
    nextTileY = nextTileY - 8

    if distanceSqToPoint(nextTileX, nextTileY, self.x, self.y) < 4 * 4 then
        table.remove(self.path, 1)
        if #self.path < 2 then
            self:startIdlePause()
            return
        end

        nextNode = self.path[2]
        nextTileX, nextTileY = Tilemap:mapToWorld(nextNode.x, nextNode.y)
        nextTileY = nextTileY - 8
    end

    local velocityX = nextTileX - self.x
    local velocityY = nextTileY - self.y
    local repulseX, repulseY = self:getRepulsionVector()
    velocityX = velocityX + repulseX * 6
    velocityY = velocityY + repulseY * 6
    local length = math.sqrt(velocityX * velocityX + velocityY * velocityY)
    if length <= 0 then
        self:startIdlePause()
        return
    end

    velocityX = velocityX / length
    velocityY = velocityY / length
    self.state = Zombie.states.walk
    self:animate(3, 6, dt)

    self.flipTimer = self.flipTimer + dt
    if self.flipTimer > 0.1 then
        if velocityX > 0 and not self.flipH then
            self.flipH = true
            self.flipTimer = 0
        elseif velocityX <= 0 and self.flipH then
            self.flipH = false
            self.flipTimer = 0
        end
    end

    local moveX = velocityX * self.speed * dt
    local moveY = velocityY * self.speed * dt
    local remainingDistance = math.sqrt(distanceSqToPoint(nextTileX, nextTileY, self.x, self.y))
    local moveDistance = math.sqrt(moveX * moveX + moveY * moveY)
    if remainingDistance > 0 and moveDistance > remainingDistance then
        local scale = remainingDistance / moveDistance
        moveX = moveX * scale
        moveY = moveY * scale
    end

    local previousX, previousY = self.x, self.y
    local collidedX, collidedY = self:isColliding(moveX, moveY)
    if not collidedX then self.x = self.x + moveX end
    if not collidedY then self.y = self.y + moveY end

    if (collidedX or collidedY) and distanceSqToPoint(previousX, previousY, self.x, self.y) < 0.2 * 0.2 then
        self:startIdlePause()
    end
end

return Spider
