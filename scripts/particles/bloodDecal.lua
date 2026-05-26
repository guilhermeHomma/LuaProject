local BloodDecal = {}
BloodDecal.__index = BloodDecal

require("scripts/utils")

local bloodSpritePath = "assets/sprites/enemy/blood"
local bloodSprites = {}
local splatBase = love.audio.newSource("assets/sfx/enemies/splat.mp3", "static")
local bloodPixelSize = 1
local centerFillRadius = 0.22

local function createBloodSprite(path)
    local imageData = love.image.newImageData(path)
    local image = love.graphics.newImage(imageData)
    image:setFilter("nearest", "nearest")

    local bloodSprite = {
        image = image,
        width = imageData:getWidth(),
        height = imageData:getHeight(),
        pixels = {},
    }

    local originX = bloodSprite.width / 2
    local originY = bloodSprite.height / 2
    for y = 0, bloodSprite.height - 1 do
        for x = 0, bloodSprite.width - 1 do
            local r, g, b, a = imageData:getPixel(x, y)
            if a > 0.05 then
                bloodSprite.pixels[#bloodSprite.pixels + 1] = {
                    x = x - originX + 0.5,
                    y = y - originY + 0.5,
                    u = (x + 0.5) / bloodSprite.width,
                    v = (y + 0.5) / bloodSprite.height,
                    r = r,
                    g = g,
                    b = b,
                    a = a,
                }
            end
        end
    end

    return bloodSprite
end

local function loadBloodSprites()
    local files = love.filesystem.getDirectoryItems(bloodSpritePath)
    table.sort(files)

    for _, fileName in ipairs(files) do
        if fileName:lower():match("%.png$") then
            bloodSprites[#bloodSprites + 1] = createBloodSprite(bloodSpritePath .. "/" .. fileName)
        end
    end

    if #bloodSprites == 0 then
        bloodSprites[1] = createBloodSprite(bloodSpritePath .. "/blood.png")
    end
end

loadBloodSprites()

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
    decal.scale = randomRange(1.1, 1.4) * (options.scaleMultiplier or 1)
    decal.timer = 0
    decal.lifeTime = 35
    decal.revealDuration = 0.33
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

    local cosA = math.cos(self.rotation)
    local sinA = math.sin(self.rotation)
    local drawnPixels = {}

    local function drawBloodPixel(drawX, drawY, pixel, pixelAlpha, flash)
        local key = drawX .. ":" .. drawY
        if drawnPixels[key] then
            return
        end

        drawnPixels[key] = true
        local flashR = math.min(pixel.r + 0.46, 1)
        local flashG = math.min(pixel.g + 0.20, 1)
        local flashB = math.min(pixel.b + 0.12, 1)

        love.graphics.setColor(
            pixel.r + (flashR - pixel.r) * flash,
            pixel.g + (flashG - pixel.g) * flash,
            pixel.b + (flashB - pixel.b) * flash,
            pixelAlpha
        )
        love.graphics.rectangle("fill", drawX, drawY, bloodPixelSize, bloodPixelSize)
    end

    for _, pixel in ipairs(self.sprite.pixels or {}) do
        local centeredU = pixel.u - 0.5
        local centeredV = pixel.v - 0.5
        local distanceFromCenter = math.sqrt(centeredU * centeredU + centeredV * centeredV)
        local mask = 1 - smoothstep(revealRadius - 0.025, revealRadius + 0.045, distanceFromCenter)

        if mask > 0.01 then
            local localX = pixel.x * self.scale
            local localY = pixel.y * self.scale
            local drawX = math.floor(self.x + localX * cosA - localY * sinA + 0.5)
            local drawY = math.floor(self.y + localX * sinA + localY * cosA + 0.5)
            local pixelAlpha = a * alpha * pixel.a * mask

            drawBloodPixel(drawX, drawY, pixel, pixelAlpha, flash)
            if distanceFromCenter <= centerFillRadius and self.scale > 1 then
                drawBloodPixel(drawX + 1, drawY, pixel, pixelAlpha * 0.92, flash)
                drawBloodPixel(drawX, drawY + 1, pixel, pixelAlpha * 0.92, flash)
            end
        end
    end

    love.graphics.setColor(r, g, b, a)
end

function BloodDecal.spawn(x, y, damageDx, damageDy, options)
    if not Game or not Game.particles then
        return
    end

    table.insert(Game.particles, BloodDecal:new(x, y, damageDx, damageDy, options))
end

return BloodDecal
