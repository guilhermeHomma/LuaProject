BigGrass = {}
BigGrass.__index = BigGrass

local sprite = love.graphics.newImage("assets/sprites/objects/grass/biggrass.png")
local spriteWidth, spriteHeight = sprite:getDimensions()
local grassSoundBase = love.audio.newSource("assets/sfx/ambience/grass.mp3", "static")

sprite:setFilter("nearest", "nearest")

local function playClonedSound(baseSource, volume, pitch)
    local sound = baseSource:clone()
    sound:setVolume(volume)
    sound:setPitch(pitch)
    sound:play()
    return sound
end

local function randomSideOffset()
    local direction = math.random() > 0.5 and 1 or -1
    return direction * math.random(0, 2)
end

local bigGrassShader = love.graphics.newShader([[
    extern number direction;
    extern vec2 spriteSize;

    vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
        vec2 pixelCoord = texture_coords * spriteSize;
        if (pixelCoord.y < spriteSize.y - 5.0) {
            texture_coords.x += direction / spriteSize.x;
        }
        if (pixelCoord.y < spriteSize.y - 9.0) {
            texture_coords.x += direction / spriteSize.x;
        }
        return Texel(tex, texture_coords) * color;
    }
]])

bigGrassShader:send("spriteSize", {spriteWidth, spriteHeight})
local lastBigGrassShaderDirection = nil

local function sendBigGrassDirection(direction)
    if direction ~= lastBigGrassShaderDirection then
        bigGrassShader:send("direction", direction)
        lastBigGrassShaderDirection = direction
    end
end

function BigGrass:new(x, y, options)
    options = options or {}
    local grass = setmetatable({}, BigGrass)

    grass.x = x
    grass.y = y - (options.yOffset or 0)
    grass.interactionY = y - 5
    grass.interactive = options.interactive ~= false
    grass.ySortOffset = options.ySortOffset or 0
    grass.shaderDirection = 0
    grass.collisionDirection = 0
    grass.soundTimer = 2
    grass.changedTarget = true
    grass.phase = options.phase or math.random() * math.pi * 2
    grass.drawPriority = options.drawPriority or math.random() * 0.1
    grass.spatialRadius = 24
    grass.blades = {}

    if options.blades then
        for i, blade in ipairs(options.blades) do
            grass.blades[i] = {
                x = blade.x or 0,
                y = blade.y or 0,
                flipH = blade.flipH == true,
                directionOffset = blade.directionOffset or 0,
            }
        end
        return grass
    end

    local bladeCount = math.random(1, 3)
    local ySlots = {0}
    if bladeCount == 2 then
        ySlots = {-2, 2}
    elseif bladeCount == 3 then
        ySlots = {-4, 0, 4}
    end

    for i = 1, bladeCount do
        grass.blades[i] = {
            x = randomSideOffset(),
            y = ySlots[i],
            flipH = math.random() > 0.5,
            directionOffset = (math.random() - 0.5) * 0.25
        }
    end

    return grass
end

function BigGrass:isCloseTo(object, radius)
    local dx = self.x - object.x
    local dy = self.interactionY - object.y
    return dx * dx + dy * dy < radius * radius
end

function BigGrass:markInteraction(sourceX)
    if not self.interactive then
        return
    end

    if sourceX < self.x then
        self.externalTargetDirection = -1
    else
        self.externalTargetDirection = 1
    end
end

function BigGrass:getTarget()
    if not self.interactive then
        return 0
    end

    if Player.isAlive then
        if self:isCloseTo(Player, 12) then
            if self.soundTimer >= 2 and self.changedTarget then
                local volume = math.random() * 0.03
                if math.random() > 0.4 then
                    playClonedSound(grassSoundBase, 0.05 + volume, (1.2 + math.random() * 0.7) * GAME_PITCH)
                end
                self.changedTarget = false
                self.soundTimer = 0
            end

            if Player.x < self.x then
                return -1
            end
            return 1
        end

        self.changedTarget = true
    end

    if self.externalTargetDirection then
        return self.externalTargetDirection
    end

    return 0
end

function BigGrass:update(dt)
    self.soundTimer = self.soundTimer + dt

    local target = self:getTarget()
    self.externalTargetDirection = nil
    local windMultiplier = WIND_AMBIENCE_MULTIPLIER or 1
    local windIntensity = WIND_AMBIENCE_INTENSITY or 1
    local windTime = WIND_AMBIENCE_TIME or love.timer.getTime()
    local speed = 2
    if target ~= 0 then speed = 14 end

    self.collisionDirection = self.collisionDirection + (target - self.collisionDirection) * dt * speed * windMultiplier
    self.shaderDirection = math.sin(windTime + self.phase) * 0.25 * windIntensity + self.collisionDirection * 0.55

    addToDrawQueue(self.y + self.ySortOffset + self.drawPriority, self, false)
end

function BigGrass:draw()
    love.graphics.setShader(bigGrassShader)

    for _, blade in ipairs(self.blades) do
        local scaleX = blade.flipH and -1 or 1
        local xOffset = blade.flipH and 1 or 0

        sendBigGrassDirection(self.shaderDirection + blade.directionOffset)

        love.graphics.draw(
            sprite,
            self.x + blade.x + xOffset,
            self.y + blade.y - 4,
            0,
            scaleX,
            1,
            spriteWidth / 2,
            spriteHeight - 2
        )
    end

    love.graphics.setShader()
end

return BigGrass
