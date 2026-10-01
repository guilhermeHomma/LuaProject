local Enemy = require("scripts/enemies/enemy")
local Tilemap = require("scripts/tilemap")
local Config = require("scripts/config/slimeBossConfig")
local BloodPixel = require("scripts/particles/bloodPixel")
local BloodDecal = require("scripts/particles/bloodDecal")
local EnemyDeathProjectiles = require("scripts/enemies/enemyDeathProjectiles")
local BoxBreakBurst = require("scripts/effects/boxBreakBurst")

local SlimeBoss = setmetatable({}, {__index = Enemy})
SlimeBoss.__index = SlimeBoss
SlimeBoss.enemyTypeId = "slimeBoss"
local nextSlimeId = 0

local variantConfigs = {
    big = Config,
    mid = setmetatable(Config.mid, {__index = Config}),
    mini = setmetatable(Config.mini, {__index = Config}),
}
local visuals = {}
for id, config in pairs(variantConfigs) do
    local sprite = love.graphics.newImage(config.spritePath)
    sprite:setFilter("nearest", "nearest")
    local frames = {}
    for i = 1, #config.frameDurations do
        frames[i] = love.graphics.newQuad((i - 1) * config.frameWidth, 0,
            config.frameWidth, config.frameHeight, sprite:getDimensions())
    end
    visuals[id] = {sprite = sprite, frames = frames}
end
local idleSound = love.audio.newSource("assets/sfx/boss/slime/slime-idle.mp3", "static")
local jumpSound = love.audio.newSource("assets/sfx/boss/slime/slime-jump.mp3", "static")
local damageSound = love.audio.newSource("assets/sfx/enemyDamage.mp3", "static")
local flashShader = love.graphics.newShader([[
    extern number whiteness;
    vec4 effect(vec4 color, Image texture, vec2 textureCoords, vec2 screenCoords) {
        vec4 pixel = Texel(texture, textureCoords) * color;
        pixel.rgb = mix(pixel.rgb, vec3(1.0), clamp(whiteness, 0.0, 1.0));
        return pixel;
    }
]])

local function randomRange(minimum, maximum)
    return minimum + math.random() * (maximum - minimum)
end

local function playSound(source, volume, pitch)
    local sound = source:clone()
    setSourceVolume(sound, volume)
    sound:setPitch(pitch * (GAME_PITCH or 1))
    sound:play()
end

function SlimeBoss:new(x, y, variant)
    variant = variant or "big"
    local Config = assert(variantConfigs[variant], "Unknown slime variant: " .. tostring(variant))
    local boss = setmetatable(Enemy:new(x, y), self)
    nextSlimeId = nextSlimeId + 1
    boss.slimeId = nextSlimeId
    boss.config = Config
    boss.variant = variant
    boss.visual = visuals[variant]
    boss.enemyTypeId = variant == "mini" and "slimeMini"
        or variant == "mid" and "slimeMid"
        or "slimeBoss"
    boss.totalLife = Config.life
    boss.life = Config.life
    boss.size = Config.radius * 2
    boss.contactDamageRadius = Config.radius
    boss.dropPoints = 0
    boss.currentFrame = 1
    boss.frameTimer = 0
    boss.phase = "idle"
    boss.idleRemaining = randomRange(Config.idleDurationMin, Config.idleDurationMax)
    boss.idleSoundRemaining = randomRange(Config.idleSoundMin, Config.idleSoundMax)
    boss.shotCircles = {
        {x = x, y = y, radius = Config.radius},
        {x = x, y = y - Config.upperCollisionOffset, radius = Config.radius},
    }
    return boss
end

function SlimeBoss:getShotCollisionCircles()
    local Config = self.config
    local circle = self.shotCircles[1]
    circle.x, circle.y = self.x, self.y
    self.shotCircles[2].x, self.shotCircles[2].y = self.x, self.y - Config.upperCollisionOffset
    return self.shotCircles
end

function SlimeBoss:overlapsPlayer(player)
    local Config = self.config
    local radius = Config.radius + player:getCollisionBox().size / 2
    for _, circle in ipairs(self:getShotCollisionCircles()) do
        if (player.x - circle.x)^2 + (player.y - circle.y)^2 < radius^2 then
            return true
        end
    end
    return false
end

local function circleTouchesTile(x, y, tile, Config)
    local left, top = tile.xWorld - tile.size / 2, tile.yWorld - tile.size
    local nearestX = math.max(left, math.min(x, left + tile.size))
    local nearestY = math.max(top, math.min(y, top + tile.size))
    return (x - nearestX)^2 + (y - nearestY)^2 < Config.radius^2
end

local function bodyTouchesTile(x, y, tile, Config)
    return circleTouchesTile(x, y, tile, Config)
        or circleTouchesTile(x, y - Config.upperCollisionOffset, tile, Config)
end

local function getBodyTiles(x, y, dx, dy, Config)
    return Tilemap:getTilesInWorldBox(
        math.min(x, x + dx) - Config.radius,
        math.min(y, y + dy) - Config.upperCollisionOffset - Config.radius,
        math.max(x, x + dx) + Config.radius,
        math.max(y, y + dy) + Config.radius)
end

local function isSlime(enemy)
    return enemy and (enemy.enemyTypeId == "slimeBoss"
        or enemy.enemyTypeId == "slimeMid"
        or enemy.enemyTypeId == "slimeMini")
end

function SlimeBoss:getSlimeCollisionRadius()
    return self.config.radius
end

function SlimeBoss:getSlimeRepulsion()
    local Config = self.config
    local repulseX, repulseY = 0, 0
    for _, other in ipairs((Game and Game.enemies) or {}) do
        if other ~= self and other.isAlive ~= false and isSlime(other) then
            local dx, dy = self.x - other.x, self.y - other.y
            local distanceSq = dx * dx + dy * dy
            local collisionDistance = self:getSlimeCollisionRadius()
                + (other.getSlimeCollisionRadius and other:getSlimeCollisionRadius() or other.size * 0.5)
            local repelDistance = collisionDistance + Config.slimeRepulsionDistance
            if distanceSq < repelDistance * repelDistance then
                if distanceSq < 0.0001 then
                    local direction = self.slimeId < (other.slimeId or math.huge) and -1 or 1
                    repulseX = repulseX + direction
                else
                    local distance = math.sqrt(distanceSq)
                    local strength = (repelDistance - distance) / repelDistance
                    repulseX = repulseX + dx / distance * strength
                    repulseY = repulseY + dy / distance * strength
                end
            end
        end
    end
    return repulseX, repulseY
end

function SlimeBoss:touchesOtherSlime(x, y)
    local radius = self:getSlimeCollisionRadius()
    for _, other in ipairs((Game and Game.enemies) or {}) do
        if other ~= self and other.isAlive ~= false and isSlime(other) then
            local otherRadius = other.getSlimeCollisionRadius and other:getSlimeCollisionRadius()
                or (other.size or 0) * 0.5
            local dx, dy = x - other.x, y - other.y
            local nextDistanceSq = dx * dx + dy * dy
            if nextDistanceSq < (radius + otherRadius)^2 then
                local currentDx, currentDy = self.x - other.x, self.y - other.y
                local currentDistanceSq = currentDx * currentDx + currentDy * currentDy
                -- Permit only movement that resolves an overlap which already exists.
                if currentDistanceSq >= (radius + otherRadius)^2 or nextDistanceSq <= currentDistanceSq then
                    return true
                end
            end
        end
    end
    return false
end

function SlimeBoss:positionTouchesTile(x, y)
    local Config = self.config
    for _, tile in ipairs(getBodyTiles(x, y, 0, 0, Config)) do
        if tile.collider and bodyTouchesTile(x, y, tile, Config) then return true end
    end
    return false
end

function SlimeBoss:moveWithSlimeCollision(dx, dy)
    local moved = false
    if dx ~= 0 and not self:positionTouchesTile(self.x + dx, self.y)
        and not self:touchesOtherSlime(self.x + dx, self.y) then
        self.x = self.x + dx
        moved = true
    end
    if dy ~= 0 and not self:positionTouchesTile(self.x, self.y + dy)
        and not self:touchesOtherSlime(self.x, self.y + dy) then
        self.y = self.y + dy
        moved = true
    end
    return moved
end

function SlimeBoss:moveJump(dt)
    local Config = self.config
    local repulseX, repulseY = self:getSlimeRepulsion()
    local dx = ((self.jumpVX or 0) + repulseX * Config.slimeRepulsionSpeed) * dt
    local dy = ((self.jumpVY or 0) + repulseY * Config.slimeRepulsionSpeed) * dt
    -- Small steps keep the circular collider from tunnelling through walls.
    local steps = math.max(1, math.ceil(math.max(math.abs(dx), math.abs(dy)) / 4))
    dx, dy = dx / steps, dy / steps
    for _ = 1, steps do
        self:moveWithSlimeCollision(dx, dy)
    end
end

function SlimeBoss:applyIdleRepulsion(dt)
    local Config = self.config
    local repulseX, repulseY = self:getSlimeRepulsion()
    local length = math.sqrt(repulseX * repulseX + repulseY * repulseY)
    if length <= 0.001 then return end
    local multiplier = (self.splitSeparationTimer or 0) > 0 and Config.splitSeparationMultiplier or 1
    local distance = math.min(Config.slimeRepulsionSpeed * multiplier * dt, 5)
    self:moveWithSlimeCollision(repulseX / length * distance, repulseY / length * distance)
end

function SlimeBoss:spawnJumpBlood(options)
    local Config = self.config
    BloodPixel.spawnBurst(self.x, self.y, 0, 0, options.minCount, options.maxCount,
        Config.bloodPalette, Config.bloodScale, Config.bloodParticleTiming)
    BloodDecal.spawn(self.x, self.y, 0, 0, {
        scaleMultiplier = options.decalScale * Config.bloodScale,
        color = Config.bloodColor,
        fadeDuration = Config.bloodDecalFadeDuration,
        volumeMultiplier = 0.35,
    })
end

function SlimeBoss:enterFrame(frame)
    local Config = self.config
    self.currentFrame = frame
    if frame == Config.takeoffFrame then
        local dx, dy = Player.x - self.x, Player.y - self.y
        local distance = math.sqrt(dx * dx + dy * dy)
        local baseLength = math.min(distance, math.max(Config.jumpDistanceMin,
            math.min(Config.jumpDistanceMax, distance * Config.jumpDistanceFactor)))
        local speedMultiplier = Config.jumpSpeedMultiplier or 1
        -- The multiplier makes short hops snappier, but the configured maximum
        -- remains the real maximum distance travelled by a single jump.
        local length = math.min(distance, Config.jumpDistanceMax, baseLength * speedMultiplier)
        local jumpRatio = math.max(0, math.min(1,
            (length - Config.jumpDistanceMin) / math.max(1, Config.jumpDistanceMax - Config.jumpDistanceMin)))
        self.landingShake = Config.landingShake * (Config.landingShakeMinMultiplier
            + (1 - Config.landingShakeMinMultiplier) * jumpRatio)
        local duration = 0
        for i = Config.takeoffFrame, Config.landingFrame - 1 do
            duration = duration + Config.frameDurations[i]
        end
        self.jumpVX = distance > 0 and dx / distance * length / duration or 0
        self.jumpVY = distance > 0 and dy / distance * length / duration or 0
        playSound(jumpSound, Config.takeoffVolume * Config.soundVolumeMultiplier,
            randomRange(Config.takeoffPitchMin, Config.takeoffPitchMax) * Config.soundPitchMultiplier)
        self:spawnJumpBlood(Config.takeoffBlood)
    elseif frame == Config.landingFrame then
        self.jumpVX, self.jumpVY = 0, 0
        playSound(jumpSound, Config.landingVolume * Config.soundVolumeMultiplier,
            randomRange(Config.landingPitchMin, Config.landingPitchMax) * Config.soundPitchMultiplier)
        self:spawnJumpBlood(Config.landingBlood)
        if camera then camera:shake(self.landingShake or Config.landingShake, Config.landingShakeDecay) end
    end
end

function SlimeBoss:update(dt)
    local Config = self.config
    if not self.isAlive then return end
    self.hitFlash = math.max(0, (self.hitFlash or 0) - dt)
    if self.deathTimer then
        self.deathTimer = self.deathTimer - dt
        if self.deathTimer <= 0 then self:completeDeath() end
        if self.isAlive then addToDrawQueue(self.y + Config.frameHeight / 6 * Config.spriteStretch, self) end
        return
    elseif self.life <= 0 then
        self:death()
        addToDrawQueue(self.y + Config.frameHeight / 6 * Config.spriteStretch, self)
        return
    end
    if self.healthDropTimer then
        self.healthDropTimer = self.healthDropTimer - dt
        if self.healthDropTimer <= 0 then
            self.healthDropTimer = nil
            self:spawnHealthDropMini()
        end
        addToDrawQueue(self.y + Config.frameHeight / 6 * Config.spriteStretch, self)
        return
    end
    if self.splitContactTimer then
        self.splitContactTimer = math.max(0, self.splitContactTimer - dt)
        self.canDamagePlayer = self.splitContactTimer <= 0
    end
    if self.splitSeparationTimer then
        self.splitSeparationTimer = math.max(0, self.splitSeparationTimer - dt)
    end
    self.idleSoundRemaining = self.idleSoundRemaining - dt
    self:applyIdleRepulsion(dt)
    -- Consume time at frame boundaries so takeoff/landing fire once even on slow frames.
    local remaining = dt
    while remaining > 0.000001 do
        local step = math.min(remaining, Config.frameDurations[self.currentFrame] - self.frameTimer)
        if self.phase == "idle" then
            step = math.min(step, self.idleRemaining)
            self.idleRemaining = self.idleRemaining - step
            if self.idleSoundRemaining <= 0 then
                playSound(idleSound, Config.idleVolume * Config.soundVolumeMultiplier,
                    randomRange(0.96, 1.04) * Config.soundPitchMultiplier)
                self.idleSoundRemaining = randomRange(Config.idleSoundMin, Config.idleSoundMax)
            end
        elseif self.currentFrame >= Config.takeoffFrame and self.currentFrame < Config.landingFrame then
            self:moveJump(step)
        end
        self.frameTimer = self.frameTimer + step
        remaining = remaining - step
        if self.phase == "idle" and self.idleRemaining <= 0.000001 and Player.isAlive then
            self.phase = "run"
            self.jumpsRemaining = math.random(Config.jumpsMin, Config.jumpsMax)
            self.frameTimer = 0
            self:enterFrame(7)
        elseif self.phase == "idle" and self.idleRemaining <= 0.000001 then
            self.idleRemaining = randomRange(Config.idleDurationMin, Config.idleDurationMax)
        elseif self.frameTimer >= Config.frameDurations[self.currentFrame] - 0.000001 then
            self.frameTimer = 0
            if self.phase == "idle" then
                self:enterFrame(self.currentFrame % 6 + 1)
            elseif self.currentFrame == Config.landingFrame then
                self.jumpsRemaining = self.jumpsRemaining - 1
                if self.jumpsRemaining > 0 and Player.isAlive then
                    self:enterFrame(7)
                else
                    self.phase = "idle"
                    self.idleRemaining = randomRange(Config.idleDurationMin, Config.idleDurationMax)
                    self:enterFrame(1)
                end
            else
                self:enterFrame(self.currentFrame + 1)
            end
        end
    end
    addToDrawQueue(self.y + Config.frameHeight / 6 * Config.spriteStretch, self)
end

function SlimeBoss:takeDamage(damage, dx, dy)
    local Config = self.config
    if not self.isAlive or self.life <= 0 then return end
    local previousLife = self.life
    self.life = math.max(0, self.life - damage)
    self.hitFlash = Config.damageFlashDuration
    self.hitFlashAmount = Config.damageFlashAmount
    playSound(damageSound, 1.5 * Config.soundVolumeMultiplier,
        randomRange(1, 1.1) * Config.soundPitchMultiplier)
    self.lastDamageDx, self.lastDamageDy = dx, dy
    BloodPixel.spawnBurst(self.x, self.y, dx, dy, 4, 6, Config.bloodPalette, Config.bloodScale, Config.bloodParticleTiming)
    local healthDropLife = self.totalLife * (Config.healthDropThreshold or 0)
    if self.variant == "big" and not self.healthDropChecked
        and previousLife > healthDropLife and self.life <= healthDropLife then
        self.healthDropChecked = true
        if self.life > 0 and math.random() < (Config.healthDropMiniChance or 0) then
            self.healthDropTimer = Config.healthDropFlashDuration
            self.hitFlash = Config.healthDropFlashDuration
            self.hitFlashAmount = Config.healthDropFlashAmount
            playSound(idleSound, Config.idleVolume * Config.soundVolumeMultiplier,
                randomRange(0.96, 1.04) * Config.soundPitchMultiplier)
        end
    end
    if self.life > 0 then
        BloodDecal.spawn(self.x, self.y, dx, dy, {
            scaleMultiplier = 0.5 * Config.bloodScale, color = Config.bloodColor,
            fadeDuration = Config.bloodDecalFadeDuration,
        })
    else
        self:death()
    end
end

function SlimeBoss:findSplitPosition(config, children, preferredAngle)
    for _, radius in ipairs({self.config.splitDistance, self.config.splitDistance * 0.5, 0}) do
        for step = 0, 11 do
            local angle = preferredAngle + step * math.pi / 6
            local x, y = self.x + math.cos(angle) * radius, self.y + math.sin(angle) * radius
            local clear = true
            for _, tile in ipairs(getBodyTiles(x, y, 0, 0, config)) do
                if tile.collider and bodyTouchesTile(x, y, tile, config) then clear = false break end
            end
            for _, child in ipairs(children) do
                if (child.x - x)^2 + (child.y - y)^2 < (config.radius * 2)^2 then clear = false break end
            end
            if clear then return x, y end
        end
    end
    -- The parent's larger collider already fits here if no separated spot is available.
    return self.x, self.y
end

function SlimeBoss:spawnHealthDropMini()
    if not (Game and Game.enemies) then return end
    local miniConfig = variantConfigs.mini
    local angle = math.random() * math.pi * 2
    local x, y = self:findSplitPosition(miniConfig, {}, angle)
    local child = SlimeBoss:new(x, y, "mini")
    child.splitContactTimer = self.config.splitContactGrace
    child.splitSeparationTimer = miniConfig.splitSeparationDuration
    child.canDamagePlayer = false
    child.encounterWaveId = self.encounterWaveId
    Game.enemies[#Game.enemies + 1] = child
end

function SlimeBoss:spawnChildren()
    local Config = self.config
    if not Config.splitInto or not (Game and Game.enemies) then return end
    local children = {}
    local angle = math.random() * math.pi * 2
    local splitCount = Config.splitCount
    if math.random() < (Config.splitExtraChance or 0) then
        splitCount = splitCount + 1
    end
    for index = 1, splitCount do
        local x, y = self:findSplitPosition(variantConfigs[Config.splitInto], children,
            angle + (index - 1) * math.pi * 2 / splitCount)
        local child = SlimeBoss:new(x, y, Config.splitInto)
        child.splitContactTimer = Config.splitContactGrace
        child.splitSeparationTimer = child.config.splitSeparationDuration
        child.canDamagePlayer = false
        child.encounterWaveId = self.encounterWaveId
        local idleRange = child.config.idleDurationMax - child.config.idleDurationMin
        local idleStep = splitCount > 1 and (index - 1) / (splitCount - 1) or 0
        child.idleRemaining = child.config.idleDurationMin + idleRange * idleStep
        child.currentFrame = 1 + ((index - 1) * 3) % 6
        child.frameTimer = (index - 1) * 0.04
        children[#children + 1] = child
        Game.enemies[#Game.enemies + 1] = child
    end
end

function SlimeBoss:spawnSplitBlood()
    local Config = self.config
    local options = Config.splitBlood
    BloodPixel.spawnRadial(self.x, self.y, options.particleCount,
        Config.bloodPalette, Config.bloodScale, {
            speedMin = options.speedMin,
            speedMax = options.speedMax,
            lifeTimeMin = Config.bloodParticleTiming.lifeTimeMin,
            lifeTimeMax = Config.bloodParticleTiming.lifeTimeMax,
            fadeDuration = Config.bloodParticleTiming.fadeDuration,
        })
    BloodDecal.spawn(self.x, self.y, 0, 0, {
        scaleMultiplier = options.decalScale * Config.bloodScale,
        color = Config.bloodColor,
        fadeDuration = Config.bloodDecalFadeDuration,
        volumeMultiplier = 1,
    })
    BoxBreakBurst.spawn(self.x, self.y, {footstep = false})
    playSound(jumpSound, Config.landingVolume * Config.soundVolumeMultiplier,
        randomRange(Config.landingPitchMin, Config.landingPitchMax) * Config.soundPitchMultiplier)
end

function SlimeBoss:death()
    local Config = self.config
    if not self.isAlive or self.life > 0 or self.deathTimer then return end
    self.canDamagePlayer = false
    self.jumpVX, self.jumpVY = 0, 0
    self.deathTimer = Config.splitInto and Config.splitFlashDuration
        or Config.deathFlashDuration or Config.damageFlashDuration
    self.hitFlash = self.deathTimer
    self.hitFlashAmount = Config.splitInto and Config.splitFlashAmount
        or Config.deathFlashAmount or Config.damageFlashAmount
end

function SlimeBoss:completeDeath()
    local Config = self.config
    if not self.isAlive then return end
    self.isAlive = false
    self.canDamagePlayer = false
    self:spawnChildren()
    if Config.splitInto then
        self:spawnSplitBlood()
    else
        BloodPixel.spawnBurst(self.x, self.y, 0, -1, 9, 12,
            Config.bloodPalette, Config.bloodScale, Config.bloodParticleTiming)
        BloodDecal.spawn(self.x, self.y, self.lastDamageDx, self.lastDamageDy, {
            scaleMultiplier = Config.bloodScale, color = Config.bloodColor,
            fadeDuration = Config.bloodDecalFadeDuration,
        })
        if Config.deathSmoke then
            BoxBreakBurst.spawn(self.x, self.y, {
                pixelMinCount = 0,
                pixelMaxCount = 0,
                boxParticle = false,
                footstep = false,
                ballPairCount = 3,
            })
        end
    end
    EnemyDeathProjectiles.spawn(self)
end

function SlimeBoss:drawShadow()
    local Config = self.config
    if not self.isAlive then return end
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.ellipse("fill", self.x, self.y + 3 * Config.spriteStretch,
        Config.shadowRadiusX, Config.shadowRadiusY * Config.spriteStretch)
    love.graphics.setColor(1, 1, 1, 1)
end

function SlimeBoss:drawDebug()
    if not DEBUG then return end
    love.graphics.setColor(0.2, 1, 0.3, 1)
    for _, circle in ipairs(self:getShotCollisionCircles()) do
        love.graphics.circle("line", circle.x, circle.y, circle.radius)
        love.graphics.line(circle.x - 2, circle.y, circle.x + 2, circle.y)
        love.graphics.line(circle.x, circle.y - 2, circle.x, circle.y + 2)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function SlimeBoss:draw()
    local Config = self.config
    if not self.isAlive then return end
    local r, g, b, a = love.graphics.getColor()
    if (self.hitFlash or 0) > 0 then
        flashShader:send("whiteness", self.hitFlashAmount or Config.damageFlashAmount)
        love.graphics.setShader(flashShader)
    end
    -- World x/y is the centre of the sprite's bottom third (5/6 of its height).
    love.graphics.draw(self.visual.sprite, self.visual.frames[self.currentFrame], math.floor(self.x + 0.5),
        math.floor(self.y + 0.5), 0, 1, Config.spriteStretch, Config.frameWidth / 2, Config.frameHeight * 5 / 6)
    love.graphics.setShader()
    self:drawDebug()
    love.graphics.setColor(r, g, b, a)
end

return SlimeBoss
