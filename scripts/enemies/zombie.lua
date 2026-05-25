local Zombie = {}
Zombie.__index = Zombie
Zombie.states = { idle = 1, walk = 2, damage = 3 }
Zombie.enemyTypeId = "zombie"

local ZParticle = require("scripts/particles/zombieDeadParticle")
local Tilemap = require("scripts/tilemap")
local whiteShader = love.graphics.newShader("scripts/shaders/whiteShader.glsl")
local glitchShader = love.graphics.newShader("scripts/shaders/playerGlitch.glsl")
local WalkParticle = require("scripts/particles/walkParticle")
local FootStep = require("scripts/particles/footstep")
local DamageStretch = require("scripts/effects/damageStretch")
local ZombieMouthConfig = require("scripts/enemies/zombieMouthConfig")
local BloodPixel = require("scripts/particles/bloodPixel")
local BloodDecal = require("scripts/particles/bloodDecal")

local DropTemplates = require("scripts/drops/dropTemplates")
local EnemyDeadDropParticle = require("scripts/particles/enemyDeadDropParticle")
local stretch = 1.4
local tileSize = 16
require("scripts/utils")

local spriteCache = {}
local frameCache = {}
local shadowSprite = love.graphics.newImage("assets/sprites/enemy/zombie/enemyShadow.png")
local zombieNoiseBase = love.audio.newSource("assets/sfx/enemies/zombie.mp3", "static")
local enemyDamageBase = love.audio.newSource("assets/sfx/enemyDamage.mp3", "static")
local coinDropBase = love.audio.newSource("assets/sfx/drops/coin-drop.mp3", "static")
local footstepBase = love.audio.newSource("assets/sfx/footsteps/foot-steps-0.mp3", "static")

shadowSprite:setFilter("nearest", "nearest")

local function getSharedSprite(path)
    if not spriteCache[path] then
        local image = love.graphics.newImage(path)
        image:setFilter("nearest", "nearest")
        spriteCache[path] = image
    end

    return spriteCache[path]
end

local mouthSprite = getSharedSprite(ZombieMouthConfig.spritePath)
local mouthQuads = {}

local function getMouthQuad(frameIndex)
    if not mouthQuads[frameIndex] then
        mouthQuads[frameIndex] = love.graphics.newQuad(
            frameIndex * ZombieMouthConfig.frameWidth,
            0,
            ZombieMouthConfig.frameWidth,
            ZombieMouthConfig.frameHeight,
            mouthSprite:getWidth(),
            mouthSprite:getHeight()
        )
    end

    return mouthQuads[frameIndex]
end

local function getSharedFrames(key, spriteSheet, frameWidth, frameHeight)
    local cachedFrames = frameCache[key]
    if cachedFrames then
        return cachedFrames
    end

    cachedFrames = {}
    local sheetWidth = spriteSheet:getWidth()
    local sheetHeight = spriteSheet:getHeight()
    local cols = sheetWidth / frameWidth
    local rows = sheetHeight / frameHeight

    for i = 0, rows - 1 do
        for j = 0, cols - 1 do
            cachedFrames[#cachedFrames + 1] = love.graphics.newQuad(
                j * frameWidth,
                i * frameHeight,
                frameWidth,
                frameHeight,
                sheetWidth,
                sheetHeight
            )
        end
    end

    frameCache[key] = cachedFrames
    return cachedFrames
end

local function copyTable(source)
    if type(source) ~= "table" then
        return source
    end

    local result = {}
    for key, value in pairs(source) do
        result[key] = copyTable(value)
    end

    return result
end

local function mergeTables(base, overrides)
    local result = copyTable(base) or {}
    if type(overrides) ~= "table" then
        return result
    end

    for key, value in pairs(overrides) do
        if type(value) == "table" and type(result[key]) == "table" then
            result[key] = mergeTables(result[key], value)
        else
            result[key] = copyTable(value)
        end
    end

    return result
end

local function getEnemyDropConfig(enemyTypeId)
    local level = CURRENT_LEVEL
    local overrides = level and level.enemyDropConfig and level.enemyDropConfig[enemyTypeId] or nil

    if level then
        local floorIndex = level.currentFloorIndex or 1
        local floorConfigs = level.enemyDropConfigByFloor and level.enemyDropConfigByFloor[floorIndex] or nil
        if floorConfigs and floorConfigs[enemyTypeId] then
            overrides = mergeTables(overrides or {}, floorConfigs[enemyTypeId])
        end
    end

    return DropTemplates.getEnemyConfig(enemyTypeId, overrides), 1
end

local function getEnemyDropMultiplier()
    local level = CURRENT_LEVEL
    if not level then
        return 1
    end

    local floorIndex = level.currentFloorIndex or 1
    local floorLevel = level.floorLevels and level.floorLevels[floorIndex] or nil
    local floorConfigs = level.enemyDropConfigByFloor and level.enemyDropConfigByFloor[floorIndex] or nil
    local multiplier = level.enemyDropMultiplier or 1
    if floorLevel and floorLevel.enemyDropMultiplier then
        multiplier = multiplier * floorLevel.enemyDropMultiplier
    end
    if floorConfigs and floorConfigs.multiplier then
        multiplier = multiplier * floorConfigs.multiplier
    end

    return multiplier
end

local function getLightTint(enemy)
    local brightness = enemy and enemy.lightBrightness or 1
    brightness = math.max(brightness, 0.8)
    return brightness, brightness, brightness
end

function Zombie:startDeathRoamPause()
    local minPause = self.deathRoamPauseMin or 0.55
    local maxPause = self.deathRoamPauseMax or 1.4
    self.deathRoamPauseTimer = minPause + math.random() * (maxPause - minPause)
    self.roamTargetX = nil
    self.roamTargetY = nil
    self.roamTargetTimer = 0
    self.path = nil
    self.state = Zombie.states.idle
    self.stateTimer = 0
end

function Zombie:updateDeathRoamPause(dt)
    if Player.isAlive or (self.deathRoamPauseTimer or 0) <= 0 then
        return false
    end

    self.deathRoamPauseTimer = math.max(0, self.deathRoamPauseTimer - dt)
    self.state = Zombie.states.idle
    self:animate(1, 2, dt)
    return true
end

function Zombie:applyDropConfig(enemyTypeId)
    local config = getEnemyDropConfig(enemyTypeId or self.enemyTypeId or "zombie")
    local multiplier = getEnemyDropMultiplier()
    config = config or {}
    multiplier = multiplier or 1

    self.dropPoints = math.floor((config.points or self.dropPoints or 0) * multiplier + 0.5)
    self.resolvedDrops = DropTemplates.resolve(config, { player = Player, source = self })
end

local function playClonedSound(baseSource, volume, pitch)
    local sound = baseSource:clone()
    sound:setVolume(volume)
    sound:setPitch(pitch)
    sound:play()
    return sound
end

function Zombie:new(x, y, speed)
    local enemy = setmetatable({}, {__index = self})

    local speedTotal = speed
    if not speedTotal then
        speedTotal = math.random(50, 68)
    end

    enemy.x = x
    enemy.y = y
    enemy.speed = speedTotal
    enemy.totalLife = 30
    enemy.life = enemy.totalLife
    enemy.damageTimer = 0.14
    enemy.kbdx = 0
    enemy.kbdy = 0
    enemy.size = 7
    enemy.dropPoints = 5
    enemy.drawPriority = math.random()
    enemy.coinDropQty = 0
    enemy.coinDropChance = 0.6
    enemy.enemyTypeId = self.enemyTypeId or "zombie"
    enemy:applyDropConfig(enemy.enemyTypeId)

    enemy.isAlive = true
    enemy.isXrayVisible = true

    enemy.spriteKey = self:getSpriteKey()
    enemy.spriteSheet = self:getSprite()
    enemy.spriteShadow = shadowSprite
    enemy.mouthVariant = "zombie"
    
    enemy.frameWidth = 32
    enemy.frameHeight = 32
    enemy.frames = getSharedFrames(enemy.spriteKey, enemy.spriteSheet, enemy.frameWidth, enemy.frameHeight)
    enemy.noise = zombieNoiseBase:clone()
    enemy.pathUpdateInterval = 3
    enemy.pathUpdateCounter = love.math.random(0, enemy.pathUpdateInterval)

    enemy.path = nil
    enemy.finder = "JPS"
    --if math.random(0, 2) >= 1 then enemy.finder = "JPS" end
    enemy.roamAroundPlayer = true
    enemy.roamTargetX = nil
    enemy.roamTargetY = nil
    enemy.roamTargetTimer = 0
    enemy.roamTargetDuration = 1.2
    enemy.roamRadiusMin = 34
    enemy.roamRadiusMax = 82
    enemy.deathRoamPauseTimer = 0
    enemy.deathRoamPauseMin = 0.55
    enemy.deathRoamPauseMax = 1.4
    enemy.emptySpaceTargetChance = 0.3
    enemy.emptySpaceTargetMinPlayerDistance = tileSize * 5

    enemy.currentFrame = 1
    enemy.animationTimer = 0
    enemy.animationSpeed = 0.15
    enemy.footStepTimer = 0
    enemy.footStepAlpha = 0.4
    enemy.stateTimer = 0
    enemy.idleDuration = math.random(7, 13) / 10
    enemy.walkDuration = math.random(4, 6)

    enemy.lastFlip = 0
    enemy.flipTimer = 0
    enemy.flipH = false

    enemy.soundTimer = math.random() * 8
    enemy.spawnIntroDuration = 0.3
    enemy.spawnIntroTimer = enemy.spawnIntroDuration
    enemy.glitchDuration = 0.95
    enemy.glitchTimer = 0
    enemy.glitchDisplacementPixels = 0.25
    enemy.whiteFlashDuration = 0.1
    enemy.whiteFlashTimer = 0
    enemy.damageAnimationInterval = 0.04
    enemy.lastDamageAnimationTime = -math.huge
    DamageStretch:init(enemy, 0.1, 0.1)

    enemy.state = (math.random(0, 1) == 0) and Zombie.states.idle or Zombie.states.walk
    return enemy
end

function Zombie:getSpriteKey()
    if math.random(1, 100) < 2 then
        return "assets/sprites/enemy/zombie/enemy-paulo.png"
    end
    if math.random(1, 100) < 2 then
        return "assets/sprites/enemy/zombie/enemy-ponei.png"
    end
    if math.random(1, 100) < 2 then
        return "assets/sprites/enemy/zombie/enemy-jhone.png"
    end
    if math.random(1, 3) == 2 then
        return "assets/sprites/enemy/zombie/enemy2.png"
    end
    if math.random(1, 3) == 2 then
        return "assets/sprites/enemy/zombie/enemy3.png"
    end

    return "assets/sprites/enemy/zombie/enemy.png"
end

function Zombie:getSprite()
    return getSharedSprite(self.spriteKey or self:getSpriteKey())
end

function Zombie:getEnemySeparationScore(x, y)
    local bestDistanceSq = math.huge

    for _, enemy in ipairs((Game and Game.enemies) or {}) do
        if enemy.isAlive and enemy ~= self and enemy.x and enemy.y then
            local dx = x - enemy.x
            local dy = y - enemy.y
            local distanceSq = dx * dx + dy * dy
            if distanceSq < bestDistanceSq then
                bestDistanceSq = distanceSq
            end
        end
    end

    if bestDistanceSq == math.huge then
        return math.huge
    end

    return bestDistanceSq
end

function Zombie:setRoamTarget(x, y, duration)
    self.roamTargetX = x
    self.roamTargetY = y
    self.roamTargetTimer = duration or self.roamTargetDuration
    self.path = nil
    self.pathUpdateCounter = self.pathUpdateInterval
end

function Zombie:chooseSeparatedReachableTarget(reference, minDistance, attempts)
    local bestX, bestY = nil, nil
    local bestScore = -math.huge

    for _ = 1, attempts or 8 do
        local targetX, targetY = Tilemap:getRandomReachableSpawnPosition(reference, minDistance)
        if targetX and targetY then
            local score = self:getEnemySeparationScore(targetX, targetY)
            if score > bestScore then
                bestScore = score
                bestX = targetX
                bestY = targetY
            end
        end
    end

    return bestX, bestY
end

function Zombie:chooseSeparatedPlayerRoamTarget(attempts)
    local bestX, bestY = nil, nil
    local bestScore = -math.huge

    for _ = 1, attempts or 8 do
        local angle = math.random() * math.pi * 2
        local radius = self.roamRadiusMin + math.random() * (self.roamRadiusMax - self.roamRadiusMin)
        local targetX = Player.x + math.cos(angle) * radius
        local targetY = Player.y + math.sin(angle) * radius
        local score = self:getEnemySeparationScore(targetX, targetY)

        if score > bestScore then
            bestScore = score
            bestX = targetX
            bestY = targetY
        end
    end

    return bestX, bestY
end

function Zombie:pickRoamTarget()
    if not Player.isAlive then
        local targetX, targetY = self:chooseSeparatedReachableTarget(self, tileSize * 3, 10)
        if targetX and targetY then
            self:setRoamTarget(targetX, targetY, 8 + math.random() * 4)
            self.deathRoamPauseTimer = 0
            self.state = Zombie.states.walk
            return
        end
    end

    if self.enemyTypeId == "zombie"
        and Player
        and Player.isAlive
        and distance(self, Player) > (self.emptySpaceTargetMinPlayerDistance or tileSize * 5)
        and math.random() < (self.emptySpaceTargetChance or 0) then
        local targetX, targetY = self:chooseSeparatedReachableTarget(Player, self.emptySpaceTargetMinPlayerDistance or tileSize * 5, 8)
        if targetX and targetY then
            self:setRoamTarget(targetX, targetY, self.roamTargetDuration)
            return
        end
    end

    local targetX, targetY = self:chooseSeparatedPlayerRoamTarget(8)
    self:setRoamTarget(targetX, targetY, self.roamTargetDuration)
end

function Zombie:ensureRoamTarget(dt)
    if not self.roamAroundPlayer then
        self.roamTargetX = Player.x
        self.roamTargetY = Player.y
        return
    end

    self.roamTargetTimer = math.max(0, (self.roamTargetTimer or 0) - dt)

    local needsTarget = not self.roamTargetX
        or not self.roamTargetY
        or self.roamTargetTimer <= 0
        or distance({x = self.roamTargetX, y = self.roamTargetY}, self) < 8
        or (Player.isAlive and distance({x = self.roamTargetX, y = self.roamTargetY}, Player) > self.roamRadiusMax + 32)

    if needsTarget then
        self:pickRoamTarget()
    end
end

function Zombie:getMovementTarget(dt)
    if not Player.isAlive then
        self:ensureRoamTarget(dt)
        return self.roamTargetX or self.x, self.roamTargetY or self.y
    end

    self:ensureRoamTarget(dt)
    return self.roamTargetX or Player.x, self.roamTargetY or Player.y
end

function Zombie:update(dt)

    addToDrawQueue(self.y + 6 + self.drawPriority, self)

    if self.spawnIntroTimer and self.spawnIntroTimer > 0 then
        self.spawnIntroTimer = math.max(0, self.spawnIntroTimer - dt)
        self.state = Zombie.states.idle
        self.velocityX = 0
        self.velocityY = 0
        self:animate(1, 2, dt)
        return
    end

    self.glitchTimer = math.max(0, self.glitchTimer - dt)
    self.whiteFlashTimer = math.max(0, self.whiteFlashTimer - dt)

    if self:updateDeathRoamPause(dt) then
        return
    end

    self.pathUpdateCounter = self.pathUpdateCounter + dt

    local velocityX = 0
    local velocityY = 0

    self:noiseCheck(dt)

    local targetX, targetY = self:getMovementTarget(dt)
    if self.pathUpdateCounter >= self.pathUpdateInterval or self.path == nil or #self.path < 2 then
    --if (self.pathUpdateCounter >= self.pathUpdateInterval and self.state == Zombie.states.idle and Player.isAlive) or self.path == nil or #self.path < 2 then
        self.pathUpdateCounter = 0
        self.path = Tilemap:getPathBetweenWorldPoints(self.x, self.y, targetX, targetY)
    end

    local nextTileX, nextTileY = self.x, self.y
    
    if self.path and #self.path > 1 then --ok

        local nextNode = self.path[2]

        nextTileX, nextTileY = Tilemap:mapToWorld(nextNode.x, nextNode.y)

        nextTileY = nextTileY - 8

        local distance = math.sqrt((self.x - nextTileX)^2 + (self.y - nextTileY)^2)
        if distance < 4 then
            table.remove(self.path, 1)
            if #self.path > 1 then
                nextNode = self.path[2]
                nextTileX, nextTileY = Tilemap:mapToWorld(nextNode.x, nextNode.y)
                nextTileY = nextTileY - 8
            end
        end
        if math.abs(nextTileX - self.x) < 1.4 then self.x = nextTileX end
        if math.abs(nextTileY - self.y) < 1.4 then self.y = nextTileY end
        
        local moveX = nextTileX - self.x
        local moveY = nextTileY - self.y

        local repulseX, repulseY = self:getRepulsionVector()
        moveX = moveX + repulseX * 10
        moveY = moveY + repulseY * 10

        velocityX = moveX
        velocityY = moveY
        
    end 

    local length = math.sqrt(velocityX * velocityX + velocityY * velocityY)
    local isMoving = length > 0
    if length > 0 then
        velocityX = velocityX / length
        velocityY = velocityY / length
    end

    local animationDuration = self.idleDuration
    if self.state == Zombie.states.walk then 
        animationDuration = self.walkDuration 
    elseif self.state == Zombie.states.damage then
        animationDuration = self.damageTimer
    end

    self:stateManager(dt, animationDuration)

    self:death()

    if self.state == Zombie.states.walk and not isMoving then
        if not Player.isAlive then
            self:startDeathRoamPause()
        else
            self.state = Zombie.states.idle
            self.stateTimer = 0
            self.path = nil
            self.pathUpdateCounter = self.pathUpdateInterval
            if self.roamAroundPlayer then
                self.roamTargetTimer = 0
            end
        end
    end

    if self.state == Zombie.states.idle or self.state == Zombie.states.damage then
        self:animate(1, 2, dt)
        if self.state == Zombie.states.damage then
            local movekbX = self.kbdx * dt * 0.05
            local movekbY = self.kbdy * dt * 0.05
            local collidedX, collidedY = self:isColliding(movekbX,movekbY)

            if not collidedX then self.x = self.x + movekbX end
            if not collidedY then self.y = self.y + movekbY end
        end

    else
        self:animate(3, 6, dt)

        self.flipTimer = self.flipTimer + dt

        if self.flipTimer > 0.1 then
            if velocityX > 0 and not self.flipH then
                self.flipH = true
                self.flipTimer = 0
            end
            if velocityX <= 0 and self.flipH then
                self.flipH = false
                self.flipTimer = 0
            end
        end
        
        local moveX = velocityX * self.speed * dt
        local moveY = velocityY * self.speed * dt
        local remainingDistance = math.sqrt((nextTileX - self.x)^2 + (nextTileY - self.y)^2)
        local moveDistance = math.sqrt(moveX * moveX + moveY * moveY)
        if remainingDistance > 0 and moveDistance > remainingDistance then
            local scale = remainingDistance / moveDistance
            moveX = moveX * scale
            moveY = moveY * scale
        end

        local previousX, previousY = self.x, self.y
        local collidedX, collidedY = self:isColliding(moveX,moveY)
        if not collidedX then self.x = self.x + moveX end
        if not collidedY then self.y = self.y + moveY end

        if (collidedX or collidedY) and distance({x = previousX, y = previousY}, self) < 0.2 then
            if not Player.isAlive then
                self:startDeathRoamPause()
            else
                self.state = Zombie.states.idle
                self.stateTimer = 0
                self.path = nil
                self.pathUpdateCounter = self.pathUpdateInterval
                if self.roamAroundPlayer then
                    self.roamTargetTimer = 0
                end
            end
        end
    end
end


function Zombie:noiseCheck(dt)
    self.soundTimer = self.soundTimer + dt

    if self.soundTimer >= 10 and Player.isAlive then
        self.soundTimer = 0
        local soundPositionX, soundPositionY = soundPosition(Player, self)
        local playerDistance = distance(Player, self) / 2
        local volume = getDistanceVolume(playerDistance, 0.1, 180)
        self.noise:stop()
        self.noise:setPosition(soundPositionX, soundPositionY, 0)
        self.noise:setVolume(volume)
        self.noise:setPitch((1.2 + math.random() * 0.2) * GAME_PITCH)
        self.noise:play()
    end
end

function Zombie:stateManager(dt, animationDuration)
    self.stateTimer = self.stateTimer + dt
    if self.stateTimer >= animationDuration then
        if self.state == Zombie.states.idle then
            self.walkDuration = math.random(4, 6)
            self.state = Zombie.states.walk
        elseif Player.isAlive then
            self.idleDuration = math.random(7, 13) / 10
            self.state = Zombie.states.idle
        else
            self.idleDuration = math.random(10, 18) / 10
            self.state = Zombie.states.idle
        end
        self.stateTimer = 0
    end 
end

function Zombie:getRepulsionVector()
    local repulseX, repulseY = 0, 0
    local selfBox = self:collisionBox(self.x, self.y)

    for _, enemy in ipairs(Game.enemies) do
        if enemy.isAlive and enemy ~= self and enemy.state == Zombie.states.walk and self.speed < enemy.speed then
            local enemyBox = enemy:collisionBox()
            local dx = self.x - enemy.x
            local dy = self.y - enemy.y
            local distSq = dx * dx + dy * dy
            local minDist = 16

            if distSq < minDist * minDist and distSq > 0 then
                local dist = math.sqrt(distSq)
                local strength = (minDist - dist) / minDist

                repulseX = repulseX + (dx / dist) * strength
                repulseY = repulseY + (dy / dist) * strength
            end
        end
    end

    return repulseX, repulseY
end

function Zombie:collisionBox(x, y)
    if not x then x = self.x end
    if not y then y = self.y end

    return {x = x - self.size/2, y = y - self.size/2, width = self.size, height = self.size}
end

function Zombie:isColliding(moveX, moveY)
    local futureX = self.x + moveX
    local futureY = self.y + moveY

    local selfBoxX = self:collisionBox(futureX, self.y)
    local selfBoxY = self:collisionBox(self.x, futureY)

    local collidedX = false
    local collidedY = false

    local closeTiles = Tilemap:getNearbyTiles(self.x, self.y)
    for _, tile in ipairs(closeTiles) do
        if tile.collider then
            local tileBox = { x = tile.xWorld - tile.size/2, y = tile.yWorld - tile.size, width = tile.size, height = tile.size }

            if checkCollision(selfBoxX, tileBox) then
                collidedX = true
            end
            if checkCollision(selfBoxY, tileBox) then
                collidedY = true
            end
        end
    end

    return collidedX, collidedY
end

function Zombie:canStartDamageAnimation()
    local now = love.timer.getTime()
    local interval = self.damageAnimationInterval or 0

    if now - (self.lastDamageAnimationTime or -math.huge) < interval then
        return false
    end

    self.lastDamageAnimationTime = now
    return true
end

function Zombie:spawnDeathBloodDecal()
    if self.deathBloodDecalSpawned then
        return
    end

    self.deathBloodDecalSpawned = true
    BloodDecal.spawn(self.x, self.y, self.lastDamageDx, self.lastDamageDy)
end

function Zombie:takeDamage(damage, dx, dy)
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

    if self:canStartDamageAnimation() then
        DamageStretch:start(self)
        self.animationTimer = 0.5
        self.state = Zombie.states.damage
        self.stateTimer = 0
        self.glitchTimer = self.glitchDuration
        self.whiteFlashTimer = self.whiteFlashDuration
        self.kbdx = dx
        self.kbdy = dy 
        self.noise:stop()

        if self.soundTimer <= 1 then
            self.soundTimer = 1.1
        end
        playClonedSound(enemyDamageBase, 1, (1 + math.random() * 0.1) * GAME_PITCH)
    end
end

function Zombie:death()
    if self.life > 0 or not self.isAlive then
        return
    end

    if self.state == Zombie.states.damage then
        return
    end

    local playerDistance = distance(Player, self)
    local volume = getDistanceVolume(playerDistance, 0.4, 200)

    if self.resolvedDrops and #self.resolvedDrops > 0 then
        playClonedSound(coinDropBase, volume, (1 + math.random() * 0.1) * GAME_PITCH)
    end

    DropTemplates.spawnResolvedDrops(self.resolvedDrops, self.x, self.y, Game.objects)

    for _ = 1, math.random(2, 4) do
        table.insert(Game.particles, EnemyDeadDropParticle:new(self.x, self.y))
    end

    local particle = ZParticle:new(self.x, self.y, self.spriteSheet)
    table.insert(Game.particles, particle)
    BloodPixel.spawnBurst(self.x, self.y - 2, 0, -1, 9, 12)
    self:spawnDeathBloodDecal()

    Game:increasePlayerPoints(self.dropPoints)
    self.noise:stop()

    self.isAlive = false    
end

function Zombie:animate(startFrame, endFrame, dt)
    self.animationTimer = self.animationTimer + dt

    self.footStepTimer = self.footStepTimer + dt
    if self.footStepTimer > 0.12 and (self.state == Zombie.states.damage or self.state == Zombie.states.walk) and distance(self, Player) < 200 then
        self.footStepTimer = 0
        local randx = math.random(-2,2)
        local randy = math.random(-2,2)
        local footstep = FootStep:new(self.x + randx, self.y +randy, self.footStepAlpha)
        table.insert(Game.footsteps, footstep)
    end
    

    local advancedFrames = 0
    while self.animationTimer >= self.animationSpeed and advancedFrames < 4 do
        self.animationTimer = self.animationTimer - self.animationSpeed
        self.currentFrame = self.currentFrame + 1
        if self.currentFrame > endFrame then
            self.currentFrame = startFrame
        end
        advancedFrames = advancedFrames + 1

        if self.state == Zombie.states.walk and self.currentFrame % 2 == 0 then --ok

            local playerDistance = self:playerDistance()
            if playerDistance <= 150 then
                local soundPositionX, soundPositionY = soundPosition(Player, self)

                self.noise:setPosition(soundPositionX, soundPositionY, 0)
                local customFootstepPlayed = self.playFootstepSound and self:playFootstepSound(playerDistance)
                if not customFootstepPlayed then
                    playClonedSound(footstepBase, 0.4, (0.4 + math.random() * 0.4) * GAME_PITCH)
                end

                if math.random() > 0.6 then
                    local lifetime = math.random(45, 55) / 100
                    local particle = WalkParticle:new(self.x, self.y, lifetime)
                    table.insert(Game.particles, particle)
                    if math.random() > 0.5 then
                        local particle = WalkParticle:new(self.x + 2, self.y + 1, lifetime)
                        table.insert(Game.particles, particle)
                    end
                end

            end

        end
    end
end

function Zombie:playerDistance()
    local dx = self.x - Player.x
    local dy = self.y - Player.y
    return math.sqrt(dx * dx + dy * dy)
end

function Zombie:drawShadow()

    if not self.isAlive then
        return
    end

    love.graphics.draw(self.spriteShadow, self.x - 6, self.y- 6, 0 , 1, 1)
end

function Zombie:drawMouth()
    if self.state == Zombie.states.damage then
        return
    end

    local mouthFrameIndex = ZombieMouthConfig.closedFrameIndex
    if self.noise and self.noise:isPlaying() then
        mouthFrameIndex = ZombieMouthConfig.openFrameIndex
    end

    local stateName = self.state == Zombie.states.walk and "walk" or "idle"
    local variantOffset = ZombieMouthConfig.variants[self.mouthVariant or "zombie"] or ZombieMouthConfig.variants.zombie
    local stateOffsets = ZombieMouthConfig.frameOffsets[stateName] or {}
    local frameOffset = stateOffsets[self.currentFrame] or { x = 0, y = 0 }
    local scaleX = self.flipH and -1 or 1

    local r, g, b = getLightTint(self)
    love.graphics.setColor(r, g, b, 1)
    love.graphics.draw(
        mouthSprite,
        getMouthQuad(mouthFrameIndex),
        self.x + ZombieMouthConfig.baseOffsetX + variantOffset.offsetX + frameOffset.x,
        self.y + ZombieMouthConfig.baseOffsetY + variantOffset.offsetY + frameOffset.y,
        0,
        scaleX,
        1,
        ZombieMouthConfig.originX,
        ZombieMouthConfig.originY
    )
end

function Zombie:draw()

    if not self.isAlive then
        return
    end
    local xOffset = 0
    local scaleX = 1
    local scaleY = stretch
    local alpha = 1
    local yOffset = 0
    if self.flipH then
        scaleX = -1
        xOffset = 1
    end
    local damageScaleX, damageScaleY = DamageStretch:getScale(self)
    local walkStretchX = 1
    local walkStretchY = 1

    if self.state == Zombie.states.walk then
        local walkPulse = math.sin((love.timer.getTime() + self.drawPriority) * 12)
        walkStretchX = 1 + walkPulse * 0.035
        walkStretchY = 1 - walkPulse * 0.025
    end

    if self.spawnIntroTimer and self.spawnIntroTimer > 0 then
        local progress = 1 - self.spawnIntroTimer / self.spawnIntroDuration
        alpha = progress
        scaleX = scaleX * 1.1
        scaleY = stretch * 1.1
        yOffset = 2 * (1 - progress)
        love.graphics.setShader(whiteShader)
    elseif self.state == Zombie.states.damage then
        if self.stateTimer < 0.015 then
            love.graphics.setColor(0, 0, 0, 1)
        elseif self.glitchTimer > 0 or self.whiteFlashTimer > 0 then
            local flash = 0
            local intensity = 0
            if self.glitchTimer > 0 then
                intensity = self.glitchTimer / self.glitchDuration *4
            end
            if self.whiteFlashTimer > 0 then
                flash = 1
            end
            glitchShader:send("texturePixelSize", {
                1 / self.spriteSheet:getWidth(),
                1 / self.spriteSheet:getHeight()
            })
            glitchShader:send("displacementPixels", self.glitchDisplacementPixels)
            glitchShader:send("time", love.timer.getTime())
            glitchShader:send("intensity", intensity)
            glitchShader:send("flash", flash)
            love.graphics.setShader(glitchShader)
        else
            love.graphics.setShader(whiteShader)
        end
    elseif self.glitchTimer > 0 or self.whiteFlashTimer > 0 then
        local flash = 0
        local intensity = 0
        if self.glitchTimer > 0 then
            intensity = self.glitchTimer / self.glitchDuration
        end
        if self.whiteFlashTimer > 0 then
            flash = 1
        end
        glitchShader:send("texturePixelSize", {
            1 / self.spriteSheet:getWidth(),
            1 / self.spriteSheet:getHeight()
        })
        glitchShader:send("displacementPixels", self.glitchDisplacementPixels)
        glitchShader:send("time", love.timer.getTime())
        glitchShader:send("intensity", intensity)
        glitchShader:send("flash", flash)
        love.graphics.setShader(glitchShader)
    end

    local tintR, tintG, tintB = getLightTint(self)
    love.graphics.setColor(tintR, tintG, tintB, alpha)
    if self.drawBodySprite then
        self:drawBodySprite(xOffset, yOffset, scaleX, scaleY, damageScaleX * walkStretchX, damageScaleY * walkStretchY, alpha)
    else
        love.graphics.draw(
            self.spriteSheet,
            self.frames[self.currentFrame],
            xOffset + self.x,
            self.y + yOffset,
            0,
            scaleX * damageScaleX * walkStretchX,
            scaleY * damageScaleY * walkStretchY,
            self.frameWidth / 2,
            self.frameHeight
        )
    end
    if self.drawBodyOverlay then
        self:drawBodyOverlay(xOffset, yOffset, scaleX, scaleY, damageScaleX * walkStretchX, damageScaleY * walkStretchY, alpha)
    end
    love.graphics.setShader()
    love.graphics.setColor(1, 1, 1, 1)
    if not (self.spawnIntroTimer and self.spawnIntroTimer > 0) then
        self:drawMouth()
    end


    if DEBUG then 

        love.graphics.rectangle("line", self.x - self.size/2, self.y - self.size/2, self.size, self.size)
    
        if self.path and #self.path > 1 then
            love.graphics.setColor(0, 1, 0, 0.6)
    
            local points = {}
    
            for i = 1, #self.path do
                local node = self.path[i]
                local worldX, worldY = Tilemap:mapToWorld(node.x, node.y)

                worldY = worldY - 8
                
                table.insert(points, worldX)
                table.insert(points, worldY)
            end
    
            love.graphics.line(points)
            love.graphics.setColor(1, 1, 1, 1)
        end
    end
end

function Zombie:drawXray()
    if not self.isAlive then
        return
    end

    local xOffset = 0
    local scaleX = 1
    local scaleY = stretch
    if self.flipH then
        scaleX = -1
        xOffset = 1
    end

    local damageScaleX, damageScaleY = DamageStretch:getScale(self)
    local walkStretchX = 1
    local walkStretchY = 1
    if self.state == Zombie.states.walk then
        local walkPulse = math.sin((love.timer.getTime() + self.drawPriority) * 12)
        walkStretchX = 1 + walkPulse * 0.035
        walkStretchY = 1 - walkPulse * 0.025
    end

    love.graphics.setColor(1, 1, 1, 1)
    if self.drawBodySprite then
        self:drawBodySprite(xOffset, 0, scaleX, scaleY, damageScaleX * walkStretchX, damageScaleY * walkStretchY, 1)
    else
        love.graphics.draw(
            self.spriteSheet,
            self.frames[self.currentFrame],
            xOffset + self.x,
            self.y,
            0,
            scaleX * damageScaleX * walkStretchX,
            scaleY * damageScaleY * walkStretchY,
            self.frameWidth / 2,
            self.frameHeight
        )
    end

end

return Zombie
