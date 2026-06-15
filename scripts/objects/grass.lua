Grass = {}
Grass.__index = Grass

local sprite = love.graphics.newImage("assets/sprites/objects/grass/grass1.png")
local sprite2 = love.graphics.newImage("assets/sprites/objects/grass/grass2.png")
local sprite3 = love.graphics.newImage("assets/sprites/objects/grass/grass3.png")
local sprite4 = love.graphics.newImage("assets/sprites/objects/grass/grass4.png")
sprite:setFilter("nearest", "nearest")
sprite2:setFilter("nearest", "nearest")
sprite3:setFilter("nearest", "nearest")
sprite4:setFilter("nearest", "nearest")

local stretch = 1.4
local grassSoundBase = love.audio.newSource("assets/sfx/ambience/grass.mp3", "static")

local function playClonedSound(baseSource, volume, pitch)
    local sound = baseSource:clone()
    sound:setVolume(volume)
    sound:setPitch(pitch)
    sound:play()
    return sound
end

local function isClose(a, b, radius)
    local dx = a.x - b.x
    local dy = a.y - b.y
    return dx * dx + dy * dy < radius * radius
end


local grassShader = love.graphics.newShader([[
    extern number direction;
    extern vec2 spriteSize;

    vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
        vec2 pixelCoord = texture_coords * spriteSize;
        if (pixelCoord.y < spriteSize.y - 5.0) {
            texture_coords.x += direction / spriteSize.x;
        }
        if (pixelCoord.y < spriteSize.y - 8.0) {
            texture_coords.x += direction / spriteSize.x;
        }    
        return Texel(tex, texture_coords) * color;
    }
]])


grassShader:send("direction", 1.0) 
local grassSpriteSize = {16.0, 16.0}
grassShader:send("spriteSize", grassSpriteSize)

local lastGrassShaderDirection = nil


local function getGrassIndex(tile)
    if tile == 1 then
        if math.random() < 0.1 then return 1 end
        if math.random() < 0.6 then return 3 end
        if math.random() < 0.04 then return 2 end
    return 4 
    end

    if math.random() < 0.8 then return 1 end
    if math.random() < 0.4 then return 3 end
    if math.random() < 0.05 then return 2 end
    return 4
end

local grassSprites = {sprite, sprite2, sprite3, sprite4}

function Grass:new(x, y, tile, state)
    local grass = setmetatable({}, Grass)
    state = state or {}

    grass.x = x 
    grass.y = y 
    grass.index = state.index or getGrassIndex(tile)
    grass.sprite = grassSprites[grass.index] or sprite
    grass.shaderDirection = 1
    grass.collisionDirection = 0
    grass.tile = tile
    grass.spatialRadius = 24

    grass.changedTarget = true
    grass.soundTimer = 2
    return grass
end

function Grass:markInteraction(sourceX)
    if self.tile == 1 then
        return
    end

    if sourceX < self.x then
        self.externalTargetDirection = -1
    else
        self.externalTargetDirection = 1
    end
end


function Grass:getTarget()
    if self.tile == 1 then return 0 end

    if Player.isAlive then
        if isClose(self, Player, 10) then
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
            else
                return 1
            end
        end

        self.changedTarget = true
    end

    if self.externalTargetDirection then
        return self.externalTargetDirection
    end

    return 0
end

function Grass:update(dt)    
    self.soundTimer = self.soundTimer + dt
    local target = self:getTarget()
    self.externalTargetDirection = nil
    local windMultiplier = WIND_AMBIENCE_MULTIPLIER or 1
    local windIntensity = WIND_AMBIENCE_INTENSITY or 1
    local windTime = WIND_AMBIENCE_TIME or love.timer.getTime()

    local speed = 2
    if target ~= 0 then speed = 12 end

    if self.tile ~= 1 then 
        addToDrawQueue(self.y + 3 , self)
    else
        addToDrawQueue(self.y + 18, self)
    end
    
    self.collisionDirection = self.collisionDirection + (target - self.collisionDirection) * dt * speed * windMultiplier

    local windDirection = ((math.sin(windTime + (self.y / 10))) / 2 + 1) * windIntensity
    self.shaderDirection = windDirection + self.collisionDirection * 0.8
end

function Grass:draw()
    love.graphics.setShader(grassShader)
    if self.shaderDirection ~= lastGrassShaderDirection then
        grassShader:send("direction", self.shaderDirection)
        lastGrassShaderDirection = self.shaderDirection
    end


    love.graphics.draw(self.sprite or sprite, self.x - 8, self.y - 15 * stretch, 0, 1, stretch)

    love.graphics.setShader()
end
