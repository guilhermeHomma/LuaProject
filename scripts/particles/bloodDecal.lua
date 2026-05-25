local BloodDecal = {}
BloodDecal.__index = BloodDecal

require("scripts/utils")

local bloodSpritePath = "assets/sprites/enemy/blood"
local bloodSprites = {}
local splatBase = love.audio.newSource("assets/sfx/enemies/splat.mp3", "static")

local function loadBloodSprites()
    local files = love.filesystem.getDirectoryItems(bloodSpritePath)
    table.sort(files)

    for _, fileName in ipairs(files) do
        if fileName:lower():match("%.png$") then
            local sprite = love.graphics.newImage(bloodSpritePath .. "/" .. fileName)
            sprite:setFilter("nearest", "nearest")
            bloodSprites[#bloodSprites + 1] = sprite
        end
    end

    if #bloodSprites == 0 then
        local sprite = love.graphics.newImage(bloodSpritePath .. "/blood.png")
        sprite:setFilter("nearest", "nearest")
        bloodSprites[1] = sprite
    end
end

loadBloodSprites()

local revealShader = love.graphics.newShader([[
extern number revealRadius;
extern number flash;

vec4 effect(vec4 color, Image texture, vec2 textureCoords, vec2 screenCoords)
{
    vec4 pixel = Texel(texture, textureCoords) * color;
    vec2 centered = textureCoords - vec2(0.5, 0.5);
    number distanceFromCenter = length(centered);
    number mask = 1.0 - smoothstep(revealRadius - 0.025, revealRadius + 0.045, distanceFromCenter);

    pixel.a *= mask;
    pixel.rgb = mix(pixel.rgb, min(pixel.rgb + vec3(0.46, 0.20, 0.12), vec3(1.0)), flash * pixel.a);

    return pixel;
}
]])

local function clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

local function smoothstep(edge0, edge1, value)
    local t = clamp((value - edge0) / (edge1 - edge0), 0, 1)
    return t * t * (3 - 2 * t)
end

local function randomRange(minValue, maxValue)
    return minValue + math.random() * (maxValue - minValue)
end

local function playSplat(x, y, options)
    options = options or {}
    local volume = 0.22

    if Player then
        volume = getDistanceVolume(distance({ x = x, y = y }, Player), 0.32, 220)
    end

    local sound = splatBase:clone()
    sound:setVolume(volume * (options.volumeMultiplier or 1))
    sound:setPitch(randomRange(0.76, 1.24) * (options.pitchMultiplier or 1) * (GAME_PITCH or 1))
    sound:play()
end

local function getSourceAngle(x, y, damageDx, damageDy)
    if damageDx and damageDy and math.abs(damageDx) + math.abs(damageDy) > 0.001 then
        return math.atan2(-damageDy, -damageDx)
    end

    if Player then
        local dx = Player.x - x
        local dy = Player.y - y
        if math.abs(dx) + math.abs(dy) > 0.001 then
            return math.atan2(dy, dx)
        end
    end

    return math.random() * math.pi * 2
end

function BloodDecal:new(x, y, damageDx, damageDy, options)
    options = options or {}
    local decal = setmetatable({}, BloodDecal)

    decal.x = x
    decal.y = y
    decal.sprite = bloodSprites[math.random(1, #bloodSprites)]
    decal.rotation = getSourceAngle(x, y, damageDx, damageDy)
    decal.scale = randomRange(1, 1.5) * (options.scaleMultiplier or 1)
    decal.timer = 0
    decal.lifeTime = 15
    decal.revealDuration = 0.28
    decal.flashDuration = 0.24
    decal.fadeStart = 1.25
    decal.alpha = 1
    decal.isAlive = true
    decal.particleType = "bloodDecal"
    decal.isGroundLayer = true
    decal.drawPriority = y + 0.4

    playSplat(x, y, options)

    return decal
end

function BloodDecal:update(dt)
    self.timer = self.timer + dt
    addToDrawQueue(self.drawPriority, self, false)

    if self.timer >= self.lifeTime then
        self.isAlive = false
    end
end

function BloodDecal:drawShadow()
end

function BloodDecal:draw()
    local fadeProgress = smoothstep(self.fadeStart, self.lifeTime, self.timer)
    local alpha = 1 - fadeProgress
    local revealProgress = smoothstep(0, self.revealDuration, self.timer)
    local revealRadius = 0.15 + 0.57 * revealProgress
    local flash = 1 - smoothstep(0, self.flashDuration, self.timer)
    local r, g, b, a = love.graphics.getColor()

    love.graphics.setShader(revealShader)
    revealShader:send("revealRadius", revealRadius)
    revealShader:send("flash", flash)
    love.graphics.setColor(r, g, b, a * alpha)
    love.graphics.draw(
        self.sprite,
        self.x,
        self.y,
        self.rotation,
        self.scale,
        self.scale,
        self.sprite:getWidth() / 2,
        self.sprite:getHeight() / 2
    )
    love.graphics.setShader()
    love.graphics.setColor(r, g, b, a)
end

function BloodDecal.spawn(x, y, damageDx, damageDy, options)
    if not Game or not Game.particles then
        return
    end

    table.insert(Game.particles, BloodDecal:new(x, y, damageDx, damageDy, options))
end

return BloodDecal
