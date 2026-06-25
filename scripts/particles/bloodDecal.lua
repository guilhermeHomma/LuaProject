local BloodDecal = {}
BloodDecal.__index = BloodDecal
BloodDecal.castsShadow = false

require("scripts/utils")

local bloodSpritePath = "assets/sprites/enemy/blood"
local bloodSprites = {}
local splatBase = love.audio.newSource("assets/sfx/enemies/splat.mp3", "static")
local bloodPixelSize = 1
local centerFillRadius = 0.22
local maxBloodDecals = 24
local fadeOutDuration = 5
local bloodDecalUpdateInterval = 1 / 30
local deferredPixelBatchSize = 80

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
    local volume = 0.26

    if Player then
        volume = getDistanceVolume(distance({ x = x, y = y }, Player), 0.38, 220)
    end

    local sound = splatBase:clone()
    setSourceVolume(sound, volume * (options.volumeMultiplier or 1))
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

local function getPixelDrawPosition(decal, pixel, cosA, sinA)
    local localX = pixel.x * decal.scale
    local localY = pixel.y * decal.scale
    return math.floor(localX * cosA - localY * sinA + 0.5),
        math.floor(localX * sinA + localY * cosA + 0.5)
end

local function setupStaticCanvas(decal)
    local cosA = math.cos(decal.rotation)
    local sinA = math.sin(decal.rotation)
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local centerPixels = {}
    local pendingPixels = {}

    for _, pixel in ipairs(decal.sprite.pixels or {}) do
        local drawX, drawY = getPixelDrawPosition(decal, pixel, cosA, sinA)
        minX = math.min(minX, drawX)
        minY = math.min(minY, drawY)
        maxX = math.max(maxX, drawX + 1)
        maxY = math.max(maxY, drawY + 1)

        local centeredU = pixel.u - 0.5
        local centeredV = pixel.v - 0.5
        local distanceFromCenter = math.sqrt(centeredU * centeredU + centeredV * centeredV)
        local drawData = {
            x = drawX,
            y = drawY,
            pixel = pixel,
            center = distanceFromCenter <= centerFillRadius,
        }

        if drawData.center then
            centerPixels[#centerPixels + 1] = drawData
        else
            pendingPixels[#pendingPixels + 1] = drawData
        end
    end

    if minX == math.huge then
        return
    end

    local width = math.max(1, maxX - minX + 3)
    local height = math.max(1, maxY - minY + 3)
    local canvas = love.graphics.newCanvas(width, height)
    canvas:setFilter("nearest", "nearest")

    decal.staticCanvas = canvas
    decal.staticCanvasX = decal.x + minX - 1
    decal.staticCanvasY = decal.y + minY - 1
    decal.staticCanvasOffsetX = -minX + 1
    decal.staticCanvasOffsetY = -minY + 1
    decal.drawnPixels = {}
    decal.pendingPixels = pendingPixels
    decal.pendingPixelIndex = 1

    return centerPixels
end

local function drawPixelBatch(decal, pixels, startIndex, maxCount)
    if not (decal and decal.staticCanvas and pixels) then
        return startIndex or 1, 0
    end

    local previousCanvas = love.graphics.getCanvas()
    local previousShader = love.graphics.getShader()
    local r, g, b, a = love.graphics.getColor()
    love.graphics.setCanvas(decal.staticCanvas)
    love.graphics.setShader()

    local function drawCachedPixel(drawX, drawY, pixel, alpha)
        local key = drawX .. ":" .. drawY
        if decal.drawnPixels[key] then
            return
        end

        decal.drawnPixels[key] = true
        love.graphics.setColor(pixel.r, pixel.g, pixel.b, pixel.a * (alpha or 1))
        love.graphics.rectangle(
            "fill",
            drawX + decal.staticCanvasOffsetX,
            drawY + decal.staticCanvasOffsetY,
            bloodPixelSize,
            bloodPixelSize
        )
    end

    local index = startIndex or 1
    local drawnCount = 0
    local limit = maxCount or #pixels

    while index <= #pixels and drawnCount < limit do
        local drawData = pixels[index]
        drawCachedPixel(drawData.x, drawData.y, drawData.pixel, 1)
        if drawData.center and decal.scale > 1 then
            drawCachedPixel(drawData.x + 1, drawData.y, drawData.pixel, 0.92)
            drawCachedPixel(drawData.x, drawData.y + 1, drawData.pixel, 0.92)
        end
        index = index + 1
        drawnCount = drawnCount + 1
    end

    love.graphics.setCanvas(previousCanvas)
    love.graphics.setShader(previousShader)
    love.graphics.setColor(r, g, b, a)

    return index, drawnCount
end

local function buildStaticCanvas(decal)
    local centerPixels = setupStaticCanvas(decal)
    if not centerPixels then
        return
    end

    local previousCanvas = love.graphics.getCanvas()
    love.graphics.setCanvas(decal.staticCanvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setCanvas(previousCanvas)

    drawPixelBatch(decal, centerPixels, 1, #centerPixels)
end

function BloodDecal:new(x, y, damageDx, damageDy, options)
    options = options or {}
    local decal = setmetatable({}, BloodDecal)

    decal.x = x
    decal.y = y
    decal.sprite = bloodSprites[math.random(1, #bloodSprites)]
    decal.rotation = getSourceAngle(x, y, damageDx, damageDy)
    decal.scale = randomRange(1.3, 1.7) * (options.scaleMultiplier or 1)
    decal.timer = 0
    decal.lifeTime = 35
    decal.revealDuration = 0.16
    decal.flashDuration = 0.12
    decal.fadeStart = decal.lifeTime - fadeOutDuration
    decal.alpha = 1
    decal.isAlive = true
    decal.particleType = "bloodDecal"
    decal.isGroundLayer = true
    decal.drawPriority = y + 0.4
    decal.updateInterval = bloodDecalUpdateInterval
    decal.maxUpdateDt = bloodDecalUpdateInterval * 2
    decal.updateAccumulator = bloodDecalUpdateInterval

    buildStaticCanvas(decal)
    playSplat(x, y, options)

    return decal
end

function BloodDecal:queueDraw()
    if Game and Game.groundDecalQueue then
        Game.groundDecalQueue[#Game.groundDecalQueue + 1] = self
    else
        addToDrawQueue(self.drawPriority, self, false)
    end
end

function BloodDecal:update(dt)
    self.timer = self.timer + dt

    if self.pendingPixels and self.pendingPixelIndex <= #self.pendingPixels then
        self.pendingPixelIndex = drawPixelBatch(
            self,
            self.pendingPixels,
            self.pendingPixelIndex,
            deferredPixelBatchSize
        )
        if self.pendingPixelIndex > #self.pendingPixels then
            self.pendingPixels = nil
            self.pendingPixelIndex = nil
        end
    end

    if self.timer >= self.lifeTime then
        self.isAlive = false
    end
end

function BloodDecal:drawShadow()
end

function BloodDecal:draw()
    if not self.staticCanvas then return end
    local r, g, b, a = love.graphics.getColor()
    local alpha = 1

    if self.timer >= self.fadeStart then
        alpha = 1 - smoothstep(self.fadeStart, self.lifeTime, self.timer)
    end

    if self.timer < self.revealDuration then
        alpha = alpha * smoothstep(0, self.revealDuration, self.timer)
    end

    love.graphics.setColor(r, g, b, a * alpha)
    love.graphics.draw(self.staticCanvas, self.staticCanvasX, self.staticCanvasY)
    love.graphics.setColor(r, g, b, a)
end

function BloodDecal.spawn(x, y, damageDx, damageDy, options)
    if not Game or not Game.particles then
        return
    end

    local oldestIndex = nil
    local oldestTimer = -math.huge
    local count = 0
    for index, particle in ipairs(Game.particles) do
        if particle.particleType == "bloodDecal" then
            count = count + 1
            if (particle.timer or 0) > oldestTimer then
                oldestTimer = particle.timer or 0
                oldestIndex = index
            end
        end
    end

    if count >= maxBloodDecals and oldestIndex then
        table.remove(Game.particles, oldestIndex)
    end

    table.insert(Game.particles, BloodDecal:new(x, y, damageDx, damageDy, options))
end

return BloodDecal
