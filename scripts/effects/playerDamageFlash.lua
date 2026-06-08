local PlayerDamageFlash = {}
PlayerDamageFlash.__index = PlayerDamageFlash

local defaultConfig = {
    spritePath = "assets/sprites/effects/damage-player.png",
    shaderPath = "scripts/shaders/playerDamageFlash.glsl",
    yOffset = 0,
    scale = 1,
    alpha = 1,
    angleOffset = 0,
    frameDuration = 0.03,
    frameWidth = nil,
    frameHeight = nil,
    pixelSize = 1,
}

local function copyConfig(config)
    local result = {}
    for key, value in pairs(defaultConfig) do
        result[key] = value
    end
    for key, value in pairs(config or {}) do
        result[key] = value
    end
    return result
end

local function angleFromVector(dx, dy)
    if math.atan2 then
        return math.atan2(dy, dx)
    end

    local angle = math.atan(dy / math.max(math.abs(dx), 0.0001))
    if dx < 0 then
        angle = angle + math.pi
    end
    return angle
end

function PlayerDamageFlash:new(config)
    local effect = setmetatable({}, PlayerDamageFlash)
    effect.config = copyConfig(config)
    effect.instances = {}
    effect.image = love.graphics.newImage(effect.config.spritePath)
    effect.image:setFilter("nearest", "nearest")
    effect.shader = love.graphics.newShader(effect.config.shaderPath)
    effect.shader:send("u_textureSize", {effect.image:getWidth(), effect.image:getHeight()})
    effect.frameWidth = effect.config.frameWidth or effect.image:getHeight()
    effect.frameHeight = effect.config.frameHeight or effect.image:getHeight()
    effect.frameCount = math.max(1, math.floor(effect.image:getWidth() / effect.frameWidth))
    effect.quads = {}
    for frame = 1, effect.frameCount do
        effect.quads[frame] = love.graphics.newQuad(
            (frame - 1) * effect.frameWidth,
            0,
            effect.frameWidth,
            effect.frameHeight,
            effect.image:getDimensions()
        )
    end
    return effect
end

function PlayerDamageFlash:spawn(x, y, dx, dy, config)
    local options = copyConfig(config or self.config)
    dx = dx or 0
    dy = dy or -1

    local length = math.sqrt(dx * dx + dy * dy)
    if length <= 0.001 then
        dx, dy = 0, -1
        length = 1
    end

    dx = dx / length
    dy = dy / length

    self.instances[#self.instances + 1] = {
        timer = 0,
        duration = self.frameCount * (options.frameDuration or 0.04),
        frameDuration = options.frameDuration or 0.04,
        x = x or 0,
        y = (y or 0) + (options.yOffset or 0),
        angle = angleFromVector(dx, dy),
        scale = options.scale or 1,
        alpha = options.alpha,
        angleOffset = options.angleOffset,
        pixelSize = options.pixelSize or 1,
    }
end

function PlayerDamageFlash:update(dt)
    for i = #self.instances, 1, -1 do
        local instance = self.instances[i]
        instance.timer = instance.timer + dt
        if instance.timer >= instance.duration then
            table.remove(self.instances, i)
        end
    end
end

function PlayerDamageFlash:draw(cameraRef, viewportScale)
    if #self.instances == 0 then
        return
    end

    viewportScale = viewportScale or 1
    if not (cameraRef and cameraRef.worldToScreen) then
        return
    end

    local previousShader = love.graphics.getShader()
    local previousR, previousG, previousB, previousA = love.graphics.getColor()
    local image = self.image
    local originX = self.frameWidth * 0.5
    local originY = self.frameHeight * 0.5

    love.graphics.setShader(self.shader)

    for _, instance in ipairs(self.instances) do
        local progress = math.min(instance.timer / math.max(instance.duration, 0.001), 1)
        local frame = math.min(
            self.frameCount,
            math.floor(instance.timer / math.max(instance.frameDuration, 0.001)) + 1
        )
        local scale = instance.scale or 1
        local worldScale = math.max(WORLD_SCALE_X or 1, YSCALE or WORLD_SCALE_Y or 1)
        local scaleX = scale * viewportScale * worldScale
        local scaleY = scale * viewportScale * worldScale
        local alpha = instance.alpha * (1 - progress * progress)

        self.shader:send("u_alpha", alpha)
        self.shader:send("u_pixelSize", instance.pixelSize or 1)
        love.graphics.setColor(1, 1, 1, 1)
        local screenX, screenY = cameraRef:worldToScreen(instance.x, instance.y)
        love.graphics.draw(
            image,
            self.quads[frame],
            math.floor(screenX + 0.5),
            math.floor(screenY + 0.5),
            instance.angle + instance.angleOffset,
            scaleX,
            scaleY,
            originX,
            originY
        )
    end

    love.graphics.setShader(previousShader)
    love.graphics.setColor(previousR, previousG, previousB, previousA)
end

return PlayerDamageFlash
