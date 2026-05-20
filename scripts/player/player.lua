require("scripts/utils")

local Player = {}

local Bullet = require("scripts/bullet")
local BallParticle = require("scripts/particles/ballParticle")
local WalkParticle = require("scripts/particles/walkParticle")
local WalkParticleSquare = require("scripts/particles/walkParticleSquare")
local FootStep = require("scripts/particles/footstep")
local BloodPixel = require("scripts/particles/bloodPixel")
local Tilemap = require("scripts/tilemap")
local TransitionManager = require("scripts.managers.transitionManager")
local playerGlitchShader = love.graphics.newShader("scripts/shaders/playerGlitch.glsl")
local footstepBase = love.audio.newSource("assets/sfx/footsteps/foot-steps-0.mp3", "static")
local damageBase = love.audio.newSource("assets/sfx/damage.mp3", "static")
local electricBase = love.audio.newSource("assets/sfx/menu/eletric-transition.mp3", "static")
local heartImage = love.graphics.newImage("assets/sprites/ui/heart.png")
local heartWhiteShader = love.graphics.newShader("scripts/shaders/whiteShader.glsl")
local heartFrameSize = 16
local heartFrames = {
    full = love.graphics.newQuad(0, 0, heartFrameSize, heartFrameSize, heartImage:getDimensions()),
    half = love.graphics.newQuad(heartFrameSize, 0, heartFrameSize, heartFrameSize, heartImage:getDimensions()),
    empty = love.graphics.newQuad(heartFrameSize * 2, 0, heartFrameSize, heartFrameSize, heartImage:getDimensions()),
}

heartImage:setFilter("nearest", "nearest")

local function playClonedSound(baseSource, volume, pitch)
    local sound = baseSource:clone()
    sound:setVolume(volume)
    sound:setPitch(pitch)
    sound:play()
    return sound
end

function Player:load(camera, spawnX, spawnY)
    self.x = spawnX or 30
    self.y = spawnY or 340
    self.speed = 83
    self.velocityX = 0
    self.velocityY = 0
    self.acceleration = 12
    self.friction = 7
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
    self.playerSheet = love.graphics.newImage("assets/sprites/player/soldier/pink-girl.png")
    self.playerShadow = love.graphics.newImage("assets/sprites/player/shadow.png")
    self.handImage = love.graphics.newImage("assets/sprites/player/hand.png")
    self.idleHandSheet = love.graphics.newImage("assets/sprites/player/soldier/hand.png")
    self.handImage:setFilter("nearest", "nearest")
    self.idleHandSheet:setFilter("nearest", "nearest")
    self.playerSheet:setFilter("nearest", "nearest")
    self.playerShadow:setFilter("nearest", "nearest")
    self.mouseAngle = 0
    self.animations = {
        idle = { frames = {0, 1}, duration = 2 },
        walk = { frames = {2, 3, 4, 5}, duration = 0.6 }
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
    self.quads = {}
    local sheetWidth = self.playerSheet:getWidth()
    for i = 0, 5 do
        local quad = love.graphics.newQuad(
            i * self.spriteSize, 0,
            self.spriteSize, self.spriteSize,
            sheetWidth, self.playerSheet:getHeight()
        )
        table.insert(self.quads, quad)
    end

    for i = 0, 5 do
        local quad = love.graphics.newQuad(
            i * self.spriteSize, 40,
            self.spriteSize, self.spriteSize,
            sheetWidth, self.playerSheet:getHeight()
        )
        table.insert(self.quads, quad)
    end

    for i = 0, 5 do
        local quad = love.graphics.newQuad(
            i * self.spriteSize, 80,
            self.spriteSize, self.spriteSize,
            sheetWidth, self.playerSheet:getHeight()
        )
        table.insert(self.quads, quad)
    end

    self.damageAlha = 0

    self.shadowTimer = 0
    self.footStepTimer = 0 
    self.glitchDuration = 0.35
    self.glitchTimer = 0
    self.glitchDisplacementPixels = 2
    self.whiteFlashDuration = 0.12
    self.whiteFlashTimer = 0
    self.damageBlinkDelay = 0.1
    self.damageVignettePulse = 0

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

            playClonedSound(footstepBase, 0.3, (2.5 + math.random() * 0.4) * GAME_PITCH)

        end
        self.currentAnimation = newAnimation
        self.currentFrame = 1
        self.animationTimer = 0
        self.idleHandFrame = 1
        self.idleHandTimer = 0
    end
    self.SquareParticleTime = self.SquareParticleTime + dt
    local anim = self.animations[self.currentAnimation]

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
    self.footStepTimer = self.footStepTimer + dt
    if moving and self.footStepTimer > 0.11 then
        self.footStepTimer = 0
        local randx = math.random(-1.5,1.5)
        local randy = math.random(-1.5,1.5)
        local footstep = FootStep:new(self.x + randx, self.y +randy)
        table.insert(Game.footsteps, footstep)

    
    end
    
    if self.animationTimer >= frameTime then
        self.animationTimer = self.animationTimer - frameTime
        self.currentFrame = self.currentFrame + 1
        if self.currentFrame > #anim.frames then
            self.currentFrame = 1
        end

        if moving and self.currentFrame % 2 == 0 then
            
            playClonedSound(footstepBase, 0.75, (0.9 + math.random() * 0.4) * GAME_PITCH)
            
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

    local damageAlphaTarget = 0
    self.sideChangeTimer = self.sideChangeTimer + dt
    if self.life <= 2 then
        damageAlphaTarget = 1
    end

    self.damageVignettePulse = transitionValue(self.damageVignettePulse or 0, 0, 2.4, dt)
    
    local vignetteTarget = math.max(damageAlphaTarget, self.damageVignettePulse or 0)
    local vignetteSpeed = self.damageAlha < vignetteTarget and 14 or 2.4
    self.damageAlha = transitionValue(self.damageAlha, vignetteTarget, vignetteSpeed, dt)

    if not self.isAlive then
        return
    end

    self.damageTimer = self.damageTimer + dt
    self.glitchTimer = math.max(0, self.glitchTimer - dt)
    self.whiteFlashTimer = math.max(0, self.whiteFlashTimer - dt)

    self.mouseAngle = math.floor(mouseAngle() * 4) / 4
    local moveX, moveY = 0, 0

    -- Input WASD
    if not Dialog.breakMovements then
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

    if moveX ~= 0 or moveY ~= 0 then
        DisableWalkTutorial()
    end

    local speed = self.speed
    if self.gun.showGun then speed = speed * 0.7 end

    local targetVelocityX = moveX * speed
    local targetVelocityY = moveY * speed
    local movementSpeed = (moveX ~= 0 or moveY ~= 0) and self.acceleration or self.friction

    self.velocityX = transitionValue(self.velocityX, targetVelocityX, movementSpeed, dt)
    self.velocityY = transitionValue(self.velocityY, targetVelocityY, movementSpeed, dt)

    if math.abs(self.velocityX) < 2 then self.velocityX = 0 end
    if math.abs(self.velocityY) < 2 then self.velocityY = 0 end

    local sumMoveX = self.velocityX * dt
    local sumMoveY = self.velocityY * dt

    self:resolveStuckCollision()

    local resolvedMoveX, resolvedMoveY = self:resolveCollisionMove(sumMoveX, sumMoveY)

    if resolvedMoveX ~= sumMoveX then
        sumMoveX = resolvedMoveX
        if sumMoveX == 0 then
            self.velocityX = 0
        end
    end
    if resolvedMoveY ~= sumMoveY then
        sumMoveY = resolvedMoveY
        if sumMoveY == 0 then
            self.velocityY = 0
        end
    end

    self.x = self.x + sumMoveX
    self.y = self.y + sumMoveY

    addToDrawQueue(self.y + 6, Player)

    self.gun:update(dt, self.x, self.y)

    local mouseX, mouseY = mousePosition()

    local canChangeSide = self.sideChangeTimer > 0.25
    local haschangedSide = false
    local visualMoveX = moveX
    local visualMoveY = moveY
    if visualMoveX == 0 and visualMoveY == 0 and (self.velocityX ~= 0 or self.velocityY ~= 0) then
        visualMoveX = self.velocityX
        visualMoveY = self.velocityY
    end

    if (visualMoveX ~= 0 or visualMoveY ~= 0) and canChangeSide then
        self.moveX = visualMoveX
        self.moveY = visualMoveY
        if self.moveX ~= moveX or self.moveY ~= moveY then
            self.sideChangeTimer = 0
        end
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


    local animationSpeed = math.sqrt(self.velocityX * self.velocityX + self.velocityY * self.velocityY)
    self:updateAnimation(dt, animationSpeed > 8)
    self:death()
end

function Player:takeDamage(amount)
    if self.damageTimer < 1.2 then return false end

    BloodPixel.spawnBurst(self.x, self.y - 2, self.velocityX or 0, self.velocityY or 0, 5, 7)
    camera:shake(10, 0.97)
    camera:damageZoom(0.85, 16, 8, 0.06)
    self.life = math.max(0, self.life - (amount or 1))
    playClonedSound(electricBase, 0.9, (1.5 + math.random() * 0.1) * GAME_PITCH)
    TransitionManager:setDistortion(1)
    TransitionManager.distortionTimer = 0.5
    self.damageTimer = 0
    self.glitchTimer = self.glitchDuration
    self.whiteFlashTimer = self.whiteFlashDuration
    playClonedSound(damageBase, 1.8, (0.9 + math.random() * 0.2) * GAME_PITCH)
    self.damageVignettePulse = 0.85
    if self.life > 0 then
        GAME_PITCH = 0.6
    else
        TransitionManager.distortionTimer = 1
    end

    return true
end

function Player:checkDamage()
    if self.damageTimer < 1.2 then return end 

    for _, enemy in ipairs(Game.enemies) do
        local dx = enemy.x - self.x
        local dy = enemy.y - self.y
        local distance = math.sqrt(dx * dx + dy * dy)

        if enemy.canDamagePlayer ~= false and distance < 10 then
            --enemy.life = 0
            --enemy:death()
            self:takeDamage(1)
            break
        end
    end
end

function Player:catchLife()
    if self.life < self.totalLife then
        self.life = math.min(self.totalLife, self.life + 2)
    end
    self.damageTimer = 0
    self.whiteFlashTimer = self.whiteFlashDuration
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

local function getCornerSlideFromBox(playerBox, tileBox, axis, primaryMove)
    local maxCornerDepth = 5.5

    if axis == "x" then
        local topDepth = playerBox.y + playerBox.height - tileBox.y
        if topDepth > 0 and topDepth <= maxCornerDepth then
            local step = math.min(topDepth * 0.45, math.max(0.12, math.abs(primaryMove) * 0.35))
            return -step
        end

        local bottomDepth = tileBox.y + tileBox.height - playerBox.y
        if bottomDepth > 0 and bottomDepth <= maxCornerDepth then
            local step = math.min(bottomDepth * 0.45, math.max(0.12, math.abs(primaryMove) * 0.35))
            return step
        end
    else
        local leftDepth = playerBox.x + playerBox.width - tileBox.x
        if leftDepth > 0 and leftDepth <= maxCornerDepth then
            local step = math.min(leftDepth * 0.45, math.max(0.12, math.abs(primaryMove) * 0.35))
            return -step
        end

        local rightDepth = tileBox.x + tileBox.width - playerBox.x
        if rightDepth > 0 and rightDepth <= maxCornerDepth then
            local step = math.min(rightDepth * 0.45, math.max(0.12, math.abs(primaryMove) * 0.35))
            return step
        end
    end

    return 0
end

function Player:isCollidingAtOffset(moveX, moveY)
    local playerBox = self:getCollisionBox()
    playerBox.x = playerBox.x + (moveX or 0)
    playerBox.y = playerBox.y + (moveY or 0)

    local closeTiles = Tilemap:getNearbyTiles(self.x + (moveX or 0), self.y + (moveY or 0))
    for _, tile in ipairs(closeTiles) do
        if tile.collider and isPlayerTileColliding(playerBox, tile) then
            return true
        end
    end

    for _, enemy in ipairs((Game and Game.enemies) or {}) do
        if enemy.isAlive and enemy.blocksPlayer and enemy.collisionBox then
            if checkCollision(playerBox, enemy:collisionBox()) then
                return true
            end
        end
    end

    return false
end

function Player:getCornerSlide(axis, primaryMove)
    local playerBox = self:getCollisionBox()
    if axis == "x" then
        playerBox.x = playerBox.x + primaryMove
    else
        playerBox.y = playerBox.y + primaryMove
    end

    local bestSlide = 0
    local closeTiles = Tilemap:getNearbyTiles(self.x, self.y)
    for _, tile in ipairs(closeTiles) do
        if tile.collider and isPlayerTileColliding(playerBox, tile) then
            local slide = getCornerSlideFromBox(playerBox, getPlayerTileCollisionBox(tile), axis, primaryMove)
            if slide ~= 0 and (bestSlide == 0 or math.abs(slide) < math.abs(bestSlide)) then
                bestSlide = slide
            end
        end
    end

    return bestSlide
end

function Player:resolveCollisionMove(moveX, moveY)
    if not self:isCollidingAtOffset(moveX, moveY) then
        return moveX, moveY
    end

    local resolvedX = moveX
    local resolvedY = moveY

    if moveX ~= 0 and self:isCollidingAtOffset(moveX, 0) then
        local slideY = self:getCornerSlide("x", moveX)
        if slideY ~= 0 and not self:isCollidingAtOffset(0, moveY + slideY)
            and not self:isCollidingAtOffset(moveX, moveY + slideY) then
            resolvedY = moveY + slideY
        else
            resolvedX = 0
        end
    end

    if moveY ~= 0 and self:isCollidingAtOffset(0, moveY) then
        local slideX = self:getCornerSlide("y", moveY)
        if slideX ~= 0 and not self:isCollidingAtOffset(moveX + slideX, 0)
            and not self:isCollidingAtOffset(moveX + slideX, moveY) then
            resolvedX = moveX + slideX
        else
            resolvedY = 0
        end
    end

    if self:isCollidingAtOffset(resolvedX, resolvedY) then
        if moveX ~= 0 and not self:isCollidingAtOffset(moveX, 0) then
            return moveX, 0
        end
        if moveY ~= 0 and not self:isCollidingAtOffset(0, moveY) then
            return 0, moveY
        end
        return 0, 0
    end

    return resolvedX, resolvedY
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

    return collidedX, collidedY
end

function Player:death()
    if self.life > 0 or not self.isAlive then
        return
    end
    
    self.isAlive = false 
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

    for i = 1, 3 do
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
    if Dialog.breakMovements then return end


    self.gun:drawSight()
end

function Player:drawShadow()
    if not self.isAlive then
        return
    end

    if math.floor(self.shadowTimer * 2) % 2 == 0 then
        love.graphics.draw(self.playerShadow, self.x, self.y, 0, 1, 1, 8, 8)
    else
        love.graphics.draw(self.playerShadow, self.x, self.y, 0, 0.98, 1, 8, 8)

    end
    
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
    self.gun:draw()

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
        1.5,
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

    if hasGlitch then
        love.graphics.setShader()
    end
end

function Player:draw()
    if not self.isAlive then return end

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
    local scaleY = 1.5 * walkStretchY
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

    if DEBUG then
        local collisionBox = self:getCollisionBox()
        love.graphics.rectangle("line", collisionBox.x, collisionBox.y, collisionBox.width, collisionBox.height)

        love.graphics.rectangle("line", self.x, self.y, 1, 1)

        local tileX, tileY = Tilemap:worldToMap(self.x, self.y)
        local worldX, worldY = Tilemap:mapToWorld(tileX, tileY)

        love.graphics.setColor(0, 1, 1, 0.1)
        love.graphics.rectangle("fill", worldX-8, worldY-16, 16, 16)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

return Player
