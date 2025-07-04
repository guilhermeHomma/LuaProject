require("scripts/utils")

local Player = {}

local Bullet = require("scripts/bullet")
local BallParticle = require("scripts/particles/ballParticle")
local WalkParticle = require("scripts/particles/walkParticle")
local Tilemap = require("scripts/tilemap")
local TransitionManager = require("scripts.managers.transitionManager")

function Player:load(camera)
    self.x = 30
    self.y = 340
    self.speed = 60
    self.size = 40
    self.gun = require("scripts/player/gun")
    self.spriteSize = 40
    self.bullets = {}
    self.bulletSpeed = 340
    self.camera = camera
    self.totalLife = 4
    self.life = self.totalLife
    self.isAlive = true
    self.flipX = false
    self.playerSheet = love.graphics.newImage("assets/sprites/player/soldier/girl.png")
    self.playerShadow = love.graphics.newImage("assets/sprites/player/shadow.png")
    self.handImage = love.graphics.newImage("assets/sprites/player/hand.png")
    self.handImage:setFilter("nearest", "nearest")
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

    self.damageTimer = 4
    self.gun:load()

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

    self.damageAlha = 0

end

function Player:updateAnimation(dt, moving)
    local newAnimation = moving and "walk" or "idle"

    if self.currentAnimation ~= newAnimation then
        self.currentAnimation = newAnimation
        self.currentFrame = 1
        self.animationTimer = 0
    end

    local anim = self.animations[self.currentAnimation]

    local duration = anim.duration
    if self.gun.showGun then duration = duration * 1.25 end
    local frameTime = duration / #anim.frames

    if self.currentAnimation == "idle" and self.currentFrame == 2 then
        frameTime = 0.1
    end

    self.animationTimer = self.animationTimer + dt

    if self.animationTimer >= frameTime then
        self.animationTimer = self.animationTimer - frameTime
        self.currentFrame = self.currentFrame + 1
        if self.currentFrame > #anim.frames then
            self.currentFrame = 1
        end

        if moving and self.currentFrame % 2 == 0 then
            
            local stepsound = love.audio.newSource("assets/sfx/footsteps/foot-steps-0.mp3", "static")

            stepsound:setVolume(0.75)
            stepsound:setPitch((0.9 + math.random() * 0.4) * GAME_PITCH)
            stepsound:play()
            
            local lifetime = math.random(45, 55) / 100
            local particle = WalkParticle:new(self.x, self.y, lifetime)

            if math.random() > 0.1 then
                table.insert(Game.particles, particle)
                if math.random() > 0.5 then
                    local particle = WalkParticle:new(self.x + 2, self.y + 1, lifetime)
                    table.insert(Game.particles, particle)
                end
            end
        end
    end


end

function Player:update(dt)

    local damageAlphaTarget = 0

    if self.life == 1 then 
        damageAlphaTarget = 0.15
    end
    
    self.damageAlha = transitionValue(self.damageAlha, damageAlphaTarget, 1.3, dt)

    if not self.isAlive then
        return
    end

    self.damageTimer = self.damageTimer + dt

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

    local collidedX, collidedY = self:isColliding(
        moveX * self.speed * dt,
        moveY * self.speed * dt 
    )

    if collidedX then moveX = 0 end
    if collidedY then moveY = 0 end
    
    local speed = self.speed
    if self.gun.showGun then speed = speed * 0.7 end

    local sumMoveX = moveX * speed * dt
    local sumMoveY = moveY * speed * dt

    self.x = self.x + sumMoveX
    self.y = self.y + sumMoveY

    addToDrawQueue(self.y + 6, Player)

    self.gun:update(dt, self.x, self.y)

    local mouseX, mouseY = mousePosition()

    if not self.gun.showGun and moveX ~= 0 then
        if moveX > 0 then 
            self.flipH = true
        else 
            self.flipH = false
        end
    elseif self.gun.showGun then
        if mouseX > self.x then
            self.flipH = true
        elseif mouseX < self.x then
            self.flipH = false
        end
    end 

    self:checkDamage()
    self:updateAnimation(dt, moveX ~= 0 or moveY ~= 0)
    self:death()
end

function Player:checkDamage()
    if self.damageTimer < 1.2 then return end 

    for _, enemy in ipairs(Game.enemies) do
        local dx = enemy.x - self.x
        local dy = enemy.y - self.y
        local distance = math.sqrt(dx * dx + dy * dy)

        if distance < 10 then
            --enemy.life = 0
            --enemy:death()
            camera:shake(120, 0.95)
            self.life = self.life - 1
            local damageSound = love.audio.newSource("assets/sfx/damage.mp3", "static")
            local sound = love.audio.newSource("assets/sfx/menu/eletric-transition.mp3", "static")
            sound:setVolume(0.9)
            sound:setPitch((1.5 + math.random() * 0.1) * GAME_PITCH)
            sound:play()
            TransitionManager:setDistortion(1)
            TransitionManager.distortionTimer = 0.5
            self.damageTimer = 0
            damageSound:setVolume(1.8)
            damageSound:setPitch((0.9 + math.random() * 0.2) * GAME_PITCH)
            damageSound:play()
            self.damageAlha = 0.2
            if self.life > 0 then
                GAME_PITCH = 0.6
            else
                TransitionManager.distortionTimer = 1
            end
            break
        end
    end
end

function Player:catchLife()
    if self.life < self.totalLife then
        self.life = self.life + 1
    end
    self.damageTimer = 0
end

function Player:getCollisionBox()
    local size = 12
    return { x = self.x - size/2, y = self.y - size/2, width = size, height = size, size = size }
end

function Player:isColliding(moveX, moveY, size)
    if not size then size = self:getCollisionBox().size end

    local playerBoxX = self:getCollisionBox()
    playerBoxX.x = playerBoxX.x + moveX
    local playerBoxY = self:getCollisionBox()
    playerBoxY.y = playerBoxY.y + moveY

    local collidedX = false
    local collidedY = false

    for _, tile in ipairs(Tilemap.tiles) do
        if tile.collider then
            local tileBox = { x = tile.xWorld - tile.size/2, y = tile.yWorld - tile.size, width = tile.size, height = tile.size }

            if checkCollision(playerBoxX, tileBox) then
                collidedX = true
            end
            if checkCollision(playerBoxY, tileBox) then
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


function love.mousepressed(x, y, button)
    if button == 1 and Player.isAlive then
        --self.gun:shoot()
    end
end

function Player:drawLife()
    if not self.isAlive then
        return
    end
    local heartColor = "466673"
    local outlineColor = "090909"
    if self.damageTimer < 0.4 then
        heartColor = "fbfaf7"
        --outlineColor = "fbfaf7"
    end

    local blink = false
    if self.life == 1 then 
        local time = love.timer.getTime()
        
        blink = math.floor(time * 3) % 2 ~= 0 
    end

    local size = 24
    local spacing = 6
    local startX = 15
    local startY = 70
    local line = 3
    local SquareLineSize = size - line
    for _, color in ipairs({outlineColor, heartColor}) do
        for i = 1, self.totalLife do
            love.graphics.setColor(hexToRGB(color))
            local drawTipe = "fill"
            local squareSize = size
            local currentStartX = startX + (i - 1) * (size + spacing) - _*3
            local currentStartY = startY - _*3
            if self.life < i or (i == 1 and blink)then
                drawTipe = "line"
                squareSize = SquareLineSize
                currentStartX = currentStartX + line/2
                currentStartY = currentStartY + line/2
            end
            love.graphics.setLineWidth(line)
            love.graphics.rectangle(drawTipe, currentStartX, currentStartY, squareSize, squareSize)
            love.graphics.setLineWidth(1)
        end
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

    love.graphics.draw(self.playerShadow, self.x, self.y, 0, 0.85, 0.85, 8, 8)
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

    love.graphics.draw(
        self.handImage,
        handX-8,
        handY - 2 ,
        0,
        1, 1.2,
        0, 16
    )
    self.gun:draw()

end

function Player:draw()
    if not self.isAlive then return end

    if self.damageTimer < 1 then
        if math.floor(self.damageTimer * 15) % 2 == 0 then
            return
        end
    end

    local anim = self.animations[self.currentAnimation]
    local frameIndex = anim.frames[self.currentFrame]

    local quad = self.quads[frameIndex + 1] -- +1 porque Lua começa em 1

    local scaleX = self.flipH and -1 or 1
    local originX = self.flipH and (self.spriteSize - self.spriteSize / 2) or (self.spriteSize / 2)
    
    local mouseX, mouseY = mousePosition()

    if mouseY > self.y then

        love.graphics.draw(
            self.playerSheet,
            quad,
            self.x,
            self.y,
            0,
            scaleX, 1.4,
            originX, self.spriteSize
        )
        self:drawHand()
    else 
        self:drawHand()
        love.graphics.draw(
            self.playerSheet,
            quad,
            self.x,
            self.y,
            0,
            scaleX, 1.4,
            originX, self.spriteSize
        )
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