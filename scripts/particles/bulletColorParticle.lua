local BulletColorParticle = {}
BulletColorParticle.__index = BulletColorParticle
BulletColorParticle.castsShadow = false

local paletteCache = {}

local function brighten(color, amount)
    amount = amount or 0.18
    return {
        math.min(color[1] + amount, 1),
        math.min(color[2] + amount, 1),
        math.min(color[3] + amount, 1),
        1,
    }
end

local function colorKey(r, g, b)
    return math.floor(r * 15) .. ":" .. math.floor(g * 15) .. ":" .. math.floor(b * 15)
end

local function buildPaletteFromSprite(path)
    if not path then
        return nil
    end

    if paletteCache[path] then
        return paletteCache[path]
    end

    local ok, imageData = pcall(love.image.newImageData, path)
    if not ok or not imageData then
        paletteCache[path] = nil
        return nil
    end

    local palette = {}
    local used = {}
    local width, height = imageData:getDimensions()

    for y = 0, height - 1 do
        for x = 0, width - 1 do
            local r, g, b, a = imageData:getPixel(x, y)
            if a > 0.2 then
                local key = colorKey(r, g, b)
                if not used[key] then
                    used[key] = true
                    palette[#palette + 1] = brighten({r, g, b, 1}, 0.14)
                end
            end
        end
    end

    if #palette == 0 then
        palette = nil
    end

    paletteCache[path] = palette
    return palette
end

function BulletColorParticle.getPalette(spritePath, fallbackColors)
    return buildPaletteFromSprite(spritePath) or fallbackColors or {
        {0.95, 0.95, 0.90, 1},
        {0.72, 0.90, 0.86, 1},
    }
end

function BulletColorParticle:new(x, y, height, palette, options)
    options = options or {}
    local particle = setmetatable({}, BulletColorParticle)
    local angle = math.random() * math.pi * 2
    local speed = (options.speedMin or 7) + math.random() * ((options.speedMax or 18) - (options.speedMin or 7))

    particle.x = x + math.random(-2, 2)
    particle.y = y + math.random(-2, 2)
    particle.height = height or 0
    particle.vx = math.cos(angle) * speed
    particle.vy = math.sin(angle) * speed
    particle.timer = 0
    particle.lifeTime = options.lifeTime or (0.42 + math.random() * 0.16)
    particle.size = options.size or 1
    particle.palette = palette
    particle.colorOffset = math.random(0, math.max(#palette - 1, 0))
    particle.wobblePhase = math.random() * math.pi * 2
    particle.fadeOut = options.fadeOut == true
    particle.alpha = options.alpha or 1
    particle.isAlive = true
    return particle
end

function BulletColorParticle:update(dt)
    addToDrawQueue(self.drawPriorityY or (self.y + 6), self)

    self.timer = self.timer + dt
    local wobble = self.wobblePhase + self.timer * 18
    self.vx = self.vx + math.cos(wobble) * 18 * dt
    self.vy = self.vy + math.sin(wobble * 0.83) * 18 * dt
    self.vx = self.vx * math.max(0, 1 - 1.6 * dt)
    self.vy = self.vy * math.max(0, 1 - 1.6 * dt)
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt

    if self.timer >= self.lifeTime then
        self.isAlive = false
    end
end

function BulletColorParticle:drawShadow()
end

function BulletColorParticle:draw()
    local x, y, size, r, g, b, alpha = self:getBatchDrawInfo()
    love.graphics.setColor(r, g, b, alpha)
    love.graphics.rectangle("fill", x, y, size, size)
    love.graphics.setColor(1, 1, 1, 1)
end

function BulletColorParticle:getBatchDrawInfo()
    local index = (math.floor(self.timer * 12 + self.colorOffset) % #self.palette) + 1
    local color = self.palette[index]
    local alpha = self.alpha or 1
    if self.fadeOut then
        local progress = math.min(self.timer / math.max(self.lifeTime, 0.001), 1)
        alpha = alpha * (1 - progress * progress)
    end

    return math.floor(self.x + 0.5), math.floor(self.y - self.height + 0.5), self.size, color[1], color[2], color[3], alpha
end

function BulletColorParticle.spawnBurst(x, y, height, palette, count, options)
    if not (Game and Game.particles and palette) then
        return
    end

    local maxPerFrame = 48
    local currentCount = Game.bulletColorParticleCount or 0
    local spawnCount = math.min(count or 1, maxPerFrame - currentCount)
    if spawnCount <= 0 then
        return
    end

    Game.bulletColorParticleCount = currentCount + spawnCount
    for _ = 1, spawnCount do
        table.insert(Game.particles, BulletColorParticle:new(x, y, height, palette, options))
    end
end

return BulletColorParticle
