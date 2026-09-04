local Zombie = {}
Zombie.__index = Zombie
Zombie.states = { idle = 1, walk = 2, damage = 3 }
Zombie.enemyTypeId = "zombie"

local ZParticle = require("scripts/particles/zombieDeadParticle")
local Tilemap = require("scripts/tilemap")
local EnemyDirector = require("scripts/enemies/enemyDirector")
local whiteShader = love.graphics.newShader("scripts/shaders/whiteShader.glsl")
local glitchShader = love.graphics.newShader("scripts/shaders/playerGlitch.glsl")
local WalkParticle = require("scripts/particles/walkParticle")
local DamageStretch = require("scripts/effects/damageStretch")
local ZombieMouthConfig = require("scripts/enemies/zombieMouthConfig")
local BloodPixel = require("scripts/particles/bloodPixel")
local BloodDecal = require("scripts/particles/bloodDecal")
local DamageImpactParticle = require("scripts/particles/damageImpactParticle")
local EnemyRepulsion = require("scripts/enemies/enemyRepulsion")
local EnemyDeathProjectiles = require("scripts/enemies/enemyDeathProjectiles")

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
    local floorConfigs = level.enemyDropConfigByFloor and level.enemyDropConfigByFloor[floorIndex] or nil
    local multiplier = level.enemyDropMultiplier or 1
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

local function getParticleCount()
    return #(Game and Game.particles or {})
end

local function distanceSqToPoint(x1, y1, x2, y2)
    local dx = x1 - x2
    local dy = y1 - y2
    return dx * dx + dy * dy
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
    setSourceVolume(sound, volume)
    sound:setPitch(pitch)
    sound:play()
    return sound
end

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

function Zombie:new(x, y, speed)
    local enemy = setmetatable({}, {__index = self})

    local speedTotal = speed
    if not speedTotal then
        speedTotal = math.random(60, 64)
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
    enemy.spriteTexturePixelSize = {1 / enemy.spriteSheet:getWidth(), 1 / enemy.spriteSheet:getHeight()}
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
    enemy.stateTimer = 0
    enemy.idleDuration = math.random(7, 13) / 10
    enemy.walkDuration = math.random(4, 6)

    enemy.lastFlip = 0
    enemy.flipTimer = 0
    enemy.flipH = false

    enemy.soundInterval = 5
    enemy.soundTimer = math.random() * enemy.soundInterval
    enemy.spawnIntroDuration = 0.3
    enemy.spawnIntroTimer = enemy.spawnIntroDuration
    enemy.glitchDuration = 0.14
    enemy.glitchTimer = 0
    enemy.glitchDisplacementPixels = 0.14
    enemy.whiteFlashDuration = 0.07
    enemy.whiteFlashTimer = 0
    enemy.damageAnimationInterval = 0.08
    enemy.lastDamageAnimationTime = -math.huge
    enemy.hitBloodPixelMin = 4
    enemy.hitBloodPixelMax = 6
    enemy.deathBloodPixelMin = 9
    enemy.deathBloodPixelMax = 12
    enemy.hitBloodDecalCooldown = 0.06
    enemy.nextHitBloodDecalTime = 0
    enemy.deadDropParticleMin = 2
    enemy.deadDropParticleMax = 4
    enemy.deathBodyParticleEnabled = true
    enemy.enemyRepulsionRadius = 18
    enemy.enemyRepulsionForce = 10
    enemy.stuckEscapeTimer = 0
    enemy.stuckEscapeDirX = 0
    enemy.stuckEscapeDirY = 0
    enemy.prevX = x
    enemy.prevY = y
    enemy.visualWalkTimer = 0
    DamageStretch:init(enemy, 0.08, 0.06)

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
    local enemies = Game and Game.getEnemiesNearPoint and Game:getEnemiesNearPoint(x, y, 120) or (Game and Game.enemies) or {}

    for _, enemy in ipairs(enemies) do
        if enemy.isAlive and not enemy.collisionDisabled and enemy ~= self and enemy.x and enemy.y then
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
        local targetX, targetY = EnemyDirector:configureRandomRoam(self, 1.8 + math.random() * 2.4)
        if targetX and targetY then
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
        local targetX, targetY = self:chooseSeparatedReachableTarget(Player, self.emptySpaceTargetMinPlayerDistance or tileSize * 5, getRoamTargetAttempts())
        if targetX and targetY then
            self:setRoamTarget(targetX, targetY, self.roamTargetDuration)
            return
        end
    end

    local targetX, targetY = self:chooseSeparatedPlayerRoamTarget(getRoamTargetAttempts())
    self:setRoamTarget(targetX, targetY, self.roamTargetDuration)
end

function Zombie:ensureRoamTarget(dt)
    if not Player.isAlive then
        self.roamTargetTimer = math.max(0, (self.roamTargetTimer or 0) - dt)
        local needsTarget = not self.roamTargetX
            or not self.roamTargetY
            or self.roamTargetTimer <= 0
            or distanceSqToPoint(self.roamTargetX or self.x, self.roamTargetY or self.y, self.x, self.y) < 8 * 8

        if needsTarget then
            self:pickRoamTarget()
        end
        return
    end

    if not self.roamAroundPlayer then
        self.roamTargetX = Player.x
        self.roamTargetY = Player.y
        return
    end

    self.roamTargetTimer = math.max(0, (self.roamTargetTimer or 0) - dt)

    local needsTarget = not self.roamTargetX
        or not self.roamTargetY
        or self.roamTargetTimer <= 0
        or distanceSqToPoint(self.roamTargetX or self.x, self.roamTargetY or self.y, self.x, self.y) < 8 * 8
        or (Player.isAlive and distanceSqToPoint(self.roamTargetX or Player.x, self.roamTargetY or Player.y, Player.x, Player.y) > (self.roamRadiusMax + 32) * (self.roamRadiusMax + 32))

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
    local usePathfinding = EnemyDirector:shouldUsePathfinding(self)
    if not usePathfinding then
        self.roamTargetTimer = math.max(0, (self.roamTargetTimer or 0) - dt)
        local needsRandomTarget = not self.roamTargetX
            or not self.roamTargetY
            or self.roamTargetTimer <= 0
            or distanceSqToPoint(self.roamTargetX or self.x, self.roamTargetY or self.y, self.x, self.y) < 8 * 8
        if needsRandomTarget then
            EnemyDirector:configureRandomRoam(self, Player.isAlive and self.roamTargetDuration or (1.8 + math.random() * 2.4))
        end
        targetX = self.roamTargetX or targetX
        targetY = self.roamTargetY or targetY
        self.path = nil
    elseif self.pathUpdateCounter >= getScaledPathUpdateInterval(self) or self.path == nil or #self.path < 2 then
    --if (self.pathUpdateCounter >= self.pathUpdateInterval and self.state == Zombie.states.idle and Player.isAlive) or self.path == nil or #self.path < 2 then
        self.pathUpdateCounter = 0
        local path, requested = EnemyDirector:requestPath(self.x, self.y, targetX, targetY)
        if requested then
            self.path = path
        end
    end

    local nextTileX, nextTileY = self.x, self.y
    
    if usePathfinding and self.path and #self.path > 1 then --ok

        local nextNode = self.path[2]

        nextTileX, nextTileY = Tilemap:mapToWorld(nextNode.x, nextNode.y)

        nextTileY = nextTileY - 8

        if distanceSqToPoint(self.x, self.y, nextTileX, nextTileY) < 4 * 4 then
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
        
    elseif not usePathfinding and targetX and targetY then
        velocityX = targetX - self.x
        velocityY = targetY - self.y
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
        if self.isVisuallyWalking then
            self:animate(3, 6, dt)
        else
            self:animate(1, 2, dt)
        end

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
        
        self.stuckEscapeTimer = math.max(0, self.stuckEscapeTimer - dt)
        if self.stuckEscapeTimer > 0 then
            velocityX = self.stuckEscapeDirX
            velocityY = self.stuckEscapeDirY
        end

        local moveX = velocityX * self.speed * dt
        local moveY = velocityY * self.speed * dt
        if self.stuckEscapeTimer <= 0 then
            local remainingDistance = math.sqrt((nextTileX - self.x)^2 + (nextTileY - self.y)^2)
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

        if (collidedX or collidedY) and distanceSqToPoint(previousX, previousY, self.x, self.y) < 0.2 * 0.2
            and self.stuckEscapeTimer <= 0 then
            if not Player.isAlive then
                self:startDeathRoamPause()
            else
                local blockMassX, blockMassY = 0, 0
                local fx, fy = previousX + moveX, previousY + moveY
                for _, other in ipairs((Game and Game.nearbyEnemies) or {}) do
            if other ~= self and other.isAlive ~= false and not other.collisionDisabled then
                        local threshold = (self.size + (other.size or self.size)) * 0.6
                        if math.abs(fx - other.x) < threshold and math.abs(fy - other.y) < threshold then
                            blockMassX = blockMassX + (self.x - other.x)
                            blockMassY = blockMassY + (self.y - other.y)
                        end
                    end
                end

                if blockMassX ~= 0 or blockMassY ~= 0 then
                    local perpX, perpY = -velocityY, velocityX
                    if perpX * blockMassX + perpY * blockMassY < 0 then
                        perpX, perpY = -perpX, -perpY
                    end
                    self.stuckEscapeDirX = perpX
                    self.stuckEscapeDirY = perpY
                    self.stuckEscapeTimer = 0.4
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
end


function Zombie:noiseCheck(dt)
    self.soundTimer = self.soundTimer + dt

    if self.soundTimer >= (self.soundInterval or 5) and Player.isAlive then
        self.soundTimer = 0
        local soundPositionX, soundPositionY = soundPosition(Player, self)
        local playerDistance = distance(Player, self) / 2
        local volume = getDistanceVolume(playerDistance, 0.1, 180)
        self.noise:stop()
        setSourcePositionIfMono(self.noise, soundPositionX, soundPositionY, 0)
        setSourceVolume(self.noise, volume)
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
    return EnemyRepulsion.getVector(self)
end

function Zombie:steerVelocityAwayFromEnemies(velocityX, velocityY, force)
    return EnemyRepulsion.steerVelocity(self, velocityX, velocityY, force)
end

function Zombie:collisionBox(x, y)
    if not x then x = self.x end
    if not y then y = self.y end

    return {x = x - self.size/2, y = y - self.size/2, width = self.size, height = self.size}
end

function Zombie:isColliding(moveX, moveY)
    local futureX = self.x + moveX
    local futureY = self.y + moveY

    local halfSize = self.size / 2
    local boxXLeft = futureX - halfSize
    local boxXRight = futureX + halfSize
    local boxXTop = self.y - halfSize
    local boxXBottom = self.y + halfSize
    local boxYLeft = self.x - halfSize
    local boxYRight = self.x + halfSize
    local boxYTop = futureY - halfSize
    local boxYBottom = futureY + halfSize

    local collidedX = false
    local collidedY = false

    local closeTiles = Tilemap:getNearbyTiles(self.x, self.y)
    for _, tile in ipairs(closeTiles) do
        if tile.collider then
            local tileLeft = tile.xWorld - tile.size / 2
            local tileRight = tileLeft + tile.size
            local tileTop = tile.yWorld - tile.size
            local tileBottom = tileTop + tile.size

            if boxXLeft < tileRight and boxXRight > tileLeft and boxXTop < tileBottom and boxXBottom > tileTop then
                collidedX = true
            end
            if boxYLeft < tileRight and boxYRight > tileLeft and boxYTop < tileBottom and boxYBottom > tileTop then
                collidedY = true
            end
        end
    end

    for _, other in ipairs((Game and Game.nearbyEnemies) or {}) do
        if other ~= self and other.isAlive ~= false and not other.collisionDisabled then
            local threshold = (self.size + (other.size or self.size)) * 0.6
            local currDx = math.abs(self.x - other.x)
            local currDy = math.abs(self.y - other.y)
            if not collidedX then
                local futureDx = math.abs(futureX - other.x)
                if futureDx < threshold and currDy < threshold and futureDx < currDx then
                    collidedX = true
                end
            end
            if not collidedY then
                local futureDy = math.abs(futureY - other.y)
                if currDx < threshold and futureDy < threshold and futureDy < currDy then
                    collidedY = true
                end
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

function Zombie:getDamageImpactPosition()
    local visualHeight = self.damageImpactVisualHeight
        or ((self.frameHeight or 32) * (self.damageImpactScaleY or 1.4))
    local ratioFromTop = self.damageImpactHeightRatio or 0.5
    return self.x, self.y - visualHeight + visualHeight * ratioFromTop
end

function Zombie:spawnDamageImpact(dx, dy)
    if Game and Game.particles and getParticleCount() < 160 then
        table.insert(Game.particles, DamageImpactParticle:new(self, dx, dy))
    end
end

function Zombie:getHitBloodRange()
    local minCount = self.hitBloodPixelMin or 4
    local maxCount = self.hitBloodPixelMax or 6
    local particleCount = getParticleCount()

    if particleCount >= 180 then
        return 1, 2
    elseif particleCount >= 120 then
        return math.min(minCount, 2), math.min(maxCount, 3)
    end

    return minCount, maxCount
end

function Zombie:canSpawnHitBloodDecal()
    return getParticleCount() < 150
end

function Zombie:spawnDeathBloodDecal()
    if self.deathBloodDecalSpawned then
        return
    end

    self.deathBloodDecalSpawned = true
    BloodDecal.spawn(self.x, self.y + (self.bloodSpawnYOffset or 0), self.lastDamageDx, self.lastDamageDy, self.deathBloodDecalOptions)
end

function Zombie:takeDamage(damage, dx, dy)
    if self.life <= 0 or self.isAlive == false then
        return
    end

    self:spawnDamageImpact(dx, dy)
    self.lastDamageDx = dx
    self.lastDamageDy = dy
    self.life = self.life - damage
    local bloodY = self.y + (self.bloodSpawnYOffset or 0)
    local hitBloodMin, hitBloodMax = self:getHitBloodRange()
    BloodPixel.spawnBurst(self.x, bloodY - 2, dx, dy, hitBloodMin, hitBloodMax)
    if self.life > 0 then
        local now = love.timer.getTime()
        if self:canSpawnHitBloodDecal() and now >= (self.nextHitBloodDecalTime or 0) then
            self.nextHitBloodDecalTime = now + (self.hitBloodDecalCooldown or 0)
            BloodDecal.spawn(self.x, bloodY, dx, dy, {
                scaleMultiplier = self.hitBloodDecalScaleMultiplier or 0.5,
                volumeMultiplier = self.hitBloodDecalVolumeMultiplier or 0.75,
                pitchMultiplier = self.hitBloodDecalPitchMultiplier or 0.62,
            })
        end
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
        local damageSoundBase = self.damageSoundBase or enemyDamageBase
        local pitchMin = self.damageSoundPitchMin or 1
        local pitchMax = self.damageSoundPitchMax or 1.1
        local pitch = pitchMin + math.random() * (pitchMax - pitchMin)
        playClonedSound(damageSoundBase, self.damageSoundVolume or 1, pitch * (GAME_PITCH or 1))
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

    local deadDropMin = self.deadDropParticleMin or 2
    local deadDropMax = self.deadDropParticleMax or 4
    local deadDropCount = math.random(deadDropMin, deadDropMax)
    if #(Game.particles or {}) > 120 then
        deadDropCount = math.random(math.min(deadDropMin, 1), math.min(deadDropMax, 2))
    end
    for _ = 1, deadDropCount do
        table.insert(Game.particles, EnemyDeadDropParticle:new(self.x, self.y))
    end

    if self.deathBodyParticleEnabled ~= false then
        local particle = ZParticle:new(self.x, self.y, self.spriteSheet, self.deathBodyParticleOptions)
        table.insert(Game.particles, particle)
    end
    BloodPixel.spawnBurst(
        self.x,
        self.y + (self.bloodSpawnYOffset or 0) - 2,
        0,
        -1,
        self.deathBloodPixelMin or 9,
        self.deathBloodPixelMax or 12
    )
    self:spawnDeathBloodDecal()

    Game:increasePlayerPoints(self.dropPoints)
    EnemyDeathProjectiles.spawn(self)
    self.noise:stop()

    self.isAlive = false    
end

function Zombie:animate(startFrame, endFrame, dt)
    self.animationTimer = self.animationTimer + dt

    local advancedFrames = 0
    while self.animationTimer >= self.animationSpeed and advancedFrames < 4 do
        self.animationTimer = self.animationTimer - self.animationSpeed
        self.currentFrame = self.currentFrame + 1
        if self.currentFrame > endFrame then
            self.currentFrame = startFrame
        end
        advancedFrames = advancedFrames + 1

        if self.state == Zombie.states.walk and (self.footstepEveryWalkFrame or self.currentFrame % 2 == 0) then --ok

            local playerDistance = self:playerDistance()
            if playerDistance <= 150 then
                local soundPositionX, soundPositionY = soundPosition(Player, self)

                setSourcePositionIfMono(self.noise, soundPositionX, soundPositionY, 0)
                local customFootstepPlayed = self.playFootstepSound and self:playFootstepSound(playerDistance)
                if not customFootstepPlayed then
                    playClonedSound(footstepBase, 0.4, (0.4 + math.random() * 0.4) * GAME_PITCH)
                end

                if not self.skipWalkParticles and math.random() > 0.6 then
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
                intensity = (self.glitchTimer / self.glitchDuration) * 0.65
            end
            if self.whiteFlashTimer > 0 then
                flash = 1
            end
            glitchShader:send("texturePixelSize", self.spriteTexturePixelSize)
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
            intensity = (self.glitchTimer / self.glitchDuration) * 0.45
        end
        if self.whiteFlashTimer > 0 then
            flash = 1
        end
        glitchShader:send("texturePixelSize", self.spriteTexturePixelSize)
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
