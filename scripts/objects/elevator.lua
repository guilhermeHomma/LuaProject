local Elevator = {}
Elevator.__index = Elevator

local LightConfig = require("scripts/config/lightConfig")
local Localization = require("scripts/managers/localization")
local Geometry = require("scripts/objects/elevatorGeometry")
local ElevatorSmoke = require("scripts/particles/elevatorSmoke")
local startSound = love.audio.newSource("assets/sfx/elevator/start-elevator.mp3", "static")
local loopSound = love.audio.newSource("assets/sfx/elevator/elevator-loop.mp3", "static")
local unpackValues = table.unpack or unpack

local images = {}
for part, filename in pairs({back = "elevator-structure-back", front = "elevator-structure-front", ground = "elevator-ground", groundBack = "elevator-ground-back"}) do
    images[part] = love.graphics.newImage("assets/sprites/objects/elevator/" .. filename .. ".png")
    images[part]:setFilter("nearest", "nearest")
end
local frameWidth, frameHeight = images.back:getDimensions()
local platformImage = love.graphics.newImage("assets/sprites/objects/elevator/elevator-sheet.png")
platformImage:setFilter("nearest", "nearest")
local platformQuads = {
    love.graphics.newQuad(0, 0, 96, 88, 192, 88),
    love.graphics.newQuad(96, 0, 96, 88, 192, 88),
}
local TILE_SIZE = 16
local LIGHT_RADIUS = TILE_SIZE * 9
local MAX_LIGHTS = 8
local DEFAULT_COLLISION_PATTERN = {
    "cccccc",
    "cxxxxc",
    "cxxxxc",
    "cxxxxc",
    "cxxxxc",
}

local lightShader = love.graphics.newShader([[
const int MAX_LIGHTS = 8;

extern number u_lightCount;
extern vec2 u_lightCenters[MAX_LIGHTS];
extern number u_innerRadii[MAX_LIGHTS];
extern number u_outerRadii[MAX_LIGHTS];
extern number u_maxBrightnesses[MAX_LIGHTS];
extern number u_additiveStrengths[MAX_LIGHTS];
extern number u_generalShadowMinBrightness;
extern vec3 u_generalShadowColor;

vec4 effect(vec4 color, Image tex, vec2 texCoord, vec2 screenCoord) {
    vec4 pixel = Texel(tex, texCoord) * color;
    float brightness = u_generalShadowMinBrightness;
    float maxLightLift = max(1.0 - u_generalShadowMinBrightness, 0.0001);
    float additiveBrightness = 0.0;

    for (int i = 0; i < MAX_LIGHTS; i++) {
        if (float(i) >= u_lightCount) {
            break;
        }

        float t = smoothstep(u_innerRadii[i], u_outerRadii[i], distance(screenCoord, u_lightCenters[i]));
        float lightBrightness = mix(u_maxBrightnesses[i], u_generalShadowMinBrightness, t);
        float lightLift = max(lightBrightness - u_generalShadowMinBrightness, 0.0);
        float remainingLift = clamp(1.0 - ((brightness - u_generalShadowMinBrightness) / maxLightLift), 0.0, 1.0);
        brightness += lightLift * remainingLift;
        additiveBrightness += (1.0 - t) * u_additiveStrengths[i];
    }

    vec3 shadowedColor = pixel.rgb * u_generalShadowColor;
    pixel.rgb = mix(shadowedColor, pixel.rgb, brightness);
    pixel.rgb = min(pixel.rgb + additiveBrightness, vec3(1.0));
    return pixel;
}
]])

local function makePart(elevator, part)
    local isFrontPart = part == "front"
    return {
        x = elevator.x,
        y = elevator.y,
        xWorld = elevator.xWorld,
        yWorld = elevator.yWorld,
        isAlive = true,
        isGroundLayer = part == "groundBack",
        isXrayOccluder = isFrontPart,
        xraySortY = elevator.y,
        getXrayOccluderBox = function()
            return elevator:getXrayOccluderBox()
        end,
        drawXrayOccluder = function()
            elevator:drawXrayOccluder(part)
        end,
        draw = function()
            elevator:drawPart(part)
        end,
    }
end

function Elevator:new(x, y, options)
    options = options or {}
    local elevator = setmetatable({}, Elevator)
    elevator.x = x
    elevator.y = y
    elevator.xWorld = x
    elevator.yWorld = y
    elevator.interactionDistance = 34
    elevator.isAlive = true
    elevator.isElevator = true
    elevator.blocksPlayer = true
    elevator.triggered = false
    elevator.collisionPattern = options.collisionPattern or DEFAULT_COLLISION_PATTERN
    elevator.collisionTileSize = options.collisionTileSize or TILE_SIZE
    elevator.collisionThickness = options.collisionThickness or TILE_SIZE
    elevator.lightCenters = {}
    elevator.innerRadii = {}
    elevator.outerRadii = {}
    elevator.maxBrightnesses = {}
    elevator.additiveStrengths = {}
    elevator.backPart = makePart(elevator, "back")
    elevator.frontPart = makePart(elevator, "front")
    elevator.groundPart = makePart(elevator, "ground")
    elevator.groundBackPart = makePart(elevator, "groundBack")
    elevator.platformPart = makePart(elevator, "platform")
    elevator.platformOffset = 0
    elevator.platformTimer = 0
    return elevator
end

function Elevator:getCollisionPattern()
    return self.collisionPattern or DEFAULT_COLLISION_PATTERN
end

function Elevator:isCollisionCell(pattern, rowIndex, colIndex)
    local row = pattern[rowIndex]
    return row and row:sub(colIndex, colIndex) == "c"
end

function Elevator:collisionBoxes()
    local pattern = self:getCollisionPattern()
    local tileSize = self.collisionTileSize or TILE_SIZE
    local thickness = math.max(1, math.min(self.collisionThickness or tileSize, tileSize))
    local rows = #pattern
    local cols = 0
    local boxes = self._collisionBoxes or {}
    self._collisionBoxes = boxes

    for i = #boxes, 1, -1 do
        boxes[i] = nil
    end

    for _, row in ipairs(pattern) do
        cols = math.max(cols, #row)
    end

    local left = self.x - cols * tileSize / 2
    local top = self.y - rows * tileSize

    for rowIndex, row in ipairs(pattern) do
        for colIndex = 1, #row do
            if self:isCollisionCell(pattern, rowIndex, colIndex) then
                local cellX = left + (colIndex - 1) * tileSize
                local cellY = top + (rowIndex - 1) * tileSize
                local hasHorizontalNeighbor = self:isCollisionCell(pattern, rowIndex, colIndex - 1)
                    or self:isCollisionCell(pattern, rowIndex, colIndex + 1)
                local hasVerticalNeighbor = self:isCollisionCell(pattern, rowIndex - 1, colIndex)
                    or self:isCollisionCell(pattern, rowIndex + 1, colIndex)

                if hasHorizontalNeighbor then
                    boxes[#boxes + 1] = {
                        x = cellX,
                        y = cellY + (tileSize - thickness) / 2,
                        width = tileSize,
                        height = thickness,
                    }
                end

                if hasVerticalNeighbor then
                    boxes[#boxes + 1] = {
                        x = cellX + (tileSize - thickness) / 2,
                        y = cellY,
                        width = thickness,
                        height = tileSize,
                    }
                end

                if not hasHorizontalNeighbor and not hasVerticalNeighbor then
                    boxes[#boxes + 1] = {
                        x = cellX + (tileSize - thickness) / 2,
                        y = cellY + (tileSize - thickness) / 2,
                        width = thickness,
                        height = thickness,
                    }
                end
            end
        end
    end

    return boxes
end

function Elevator:collisionBox()
    local boxes = self:collisionBoxes()
    return boxes[1]
end

function Elevator:isPlayerNear()
    if not (Player and Player.isAlive) then
        return false
    end

    return Geometry.contains(Geometry.interaction(self.x, self.y), Player.x, Player.y)
end

function Elevator:update(dt)
    addToDrawQueue(self.y - 72, self.platformPart, false)
    addToDrawQueue(self.y - TILE_SIZE * 5, self.groundBackPart, false)
    addToDrawQueue(self.y - TILE_SIZE * 5, self.backPart, false)
    addToDrawQueue(self.y, self.frontPart, false)
    addToDrawQueue(self.y - TILE_SIZE, self.groundPart, false)

    if self.triggered then
        return
    end

    if self:isPlayerNear() then
        Game.drawtext = Localization:t("game.next_floor")
        Game.textAlphaTarget = 1
    end
end

function Elevator:updateSequence(dt)
    local center = Geometry.interaction(self.x, self.y)
    local centerX, centerY = center.x + center.width / 2, center.y + center.height / 2
    Player.velocityX, Player.velocityY = 0, 0
    Player.gun.showGun = false
    if self.sequencePhase == "centering" then
        local dx, dy = centerX - Player.x, centerY - Player.y
        local distance = math.sqrt(dx * dx + dy * dy)
        local step = 45 * dt
        if distance <= step then
            Player.x, Player.y = centerX, centerY
            self.sequencePhase = "starting"
            self.startTimer = 0
            self.riseTimer = 0
            self.shakePhase = 0
            self.startSound = startSound:clone()
            self.startSound:setVolume(SOUND_VOLUME or 1)
            self.startSound:play()
            ElevatorSmoke.emit(self, 12)
        else
            Player.x, Player.y = Player.x + dx / distance * step, Player.y + dy / distance * step
            Player.moveX, Player.moveY = dx, dy
        end
        Player:updateAnimation(dt, self.sequencePhase == "centering")
    else
        local riseDt = dt
        if self.sequencePhase == "starting" then
            self.startTimer = self.startTimer + dt
            riseDt = math.max(0, self.startTimer - 0.5)
            if self.startTimer >= 0.5 then
                self.sequencePhase = "rising"
            end
        end
        self.riseTimer = self.riseTimer + riseDt
        if self.sequencePhase == "rising" and self.riseTimer < 3.6 then
            if not self.loopSound then
                self.loopSound = loopSound:clone()
                self.nextLoopTime = 0
            end
            if self.riseTimer >= self.nextLoopTime then
                self.loopSound:stop()
                self.loopSound:setVolume(SOUND_VOLUME or 1)
                self.loopSound:setPitch(0.97 + math.random() * 0.06)
                self.loopSound:play()
                self.nextLoopTime = (math.floor(self.riseTimer / 1.2) + 1) * 1.2
            end
        end
        -- Fade the vibration out completely during the first second of ascent.
        local shakeProgress = math.min(1, self.riseTimer)
        local shakeAmplitude = 0.05 * (1 - shakeProgress * shakeProgress * (3 - 2 * shakeProgress))
        local shakeHz = 1.5 + 1.5 * math.exp(-self.riseTimer * 2)
        self.shakePhase = self.shakePhase + dt * shakeHz * math.pi * 2
        self.shakeX = math.sin(self.shakePhase) * shakeAmplitude
        self.shakeY = math.sin(self.shakePhase * 1.17) * shakeAmplitude
        -- Integral of a smooth acceleration from 3 to 65 pixels/second over 2 seconds.
        local t = math.min(self.riseTimer, 2)
        local u = t / 2
        self.platformOffset = 3 * t + 124 * (u ^ 3 - 0.5 * u ^ 4)
            + math.max(0, self.riseTimer - 2) * 65
        self.platformTimer = self.platformTimer + dt
        Player.x, Player.y = centerX, centerY
        Player:updateAnimation(dt, false)
        Game.elevatorFadeAlpha = math.min(1, math.max(0, (self.riseTimer - 2.8) / 0.8))
    end
    if self.sequencePhase ~= "centering" then
        Player.moveX, Player.moveY, Player.flipH = 0, 1, false
    end
    self:update(dt)
    local playerSortY = self.sequencePhase == "rising" and centerY or Player.y
    addToDrawQueue(playerSortY + 6, Player)
    local finished = (Game.elevatorFadeAlpha or 0) >= 1
    if finished and self.loopSound then
        self.loopSound:stop()
    end
    return finished
end

function Elevator:getLightCenter()
    return self.x, self.y - TILE_SIZE * 2.5
end

function Elevator:getScreenLightCenter(source)
    local center = source.__elevatorScreenLightCenter or {}
    source.__elevatorScreenLightCenter = center
    center[1] = (source.x * WORLD_SCALE_X - camera.x) * camera.zoomX
    center[2] = (source.y * YSCALE - camera.y) * camera.zoomY
    return center
end

function Elevator:sendLightShader()
    local generalShadow = LightConfig:getGeneralShadow() or {}
    local lightManager = ACTIVE_LIGHT_MANAGER or Game
    local lightSources = lightManager and lightManager.getLightSources and lightManager:getLightSources() or {}
    local centerX, centerY = self:getLightCenter()
    local lightCount = 0

    for _, source in ipairs(camera and lightSources or {}) do
        if lightCount >= MAX_LIGHTS then
            break
        end

        local groundLight = source.config and source.config.groundLight
        local dx = (source.x or 0) - centerX
        local dy = (source.y or 0) - centerY
        if groundLight and groundLight.enabled ~= false and dx * dx + dy * dy <= LIGHT_RADIUS * LIGHT_RADIUS then
            lightCount = lightCount + 1
            self.lightCenters[lightCount] = self:getScreenLightCenter(source)
            self.innerRadii[lightCount] = groundLight.innerRadius or 95
            self.outerRadii[lightCount] = groundLight.outerRadius or 360
            self.maxBrightnesses[lightCount] = groundLight.maxBrightness or 1
            self.additiveStrengths[lightCount] = groundLight.additive and (groundLight.additiveStrength or 0.12) or 0
        end
    end

    for i = lightCount + 1, MAX_LIGHTS do
        self.lightCenters[i] = self.lightCenters[i] or {0, 0}
        self.lightCenters[i][1], self.lightCenters[i][2] = 0, 0
        self.innerRadii[i] = 0
        self.outerRadii[i] = 1
        self.maxBrightnesses[i] = 1
        self.additiveStrengths[i] = 0
    end

    lightShader:send("u_lightCount", lightCount)
    lightShader:send("u_lightCenters", unpackValues(self.lightCenters, 1, MAX_LIGHTS))
    lightShader:send("u_innerRadii", unpackValues(self.innerRadii, 1, MAX_LIGHTS))
    lightShader:send("u_outerRadii", unpackValues(self.outerRadii, 1, MAX_LIGHTS))
    lightShader:send("u_maxBrightnesses", unpackValues(self.maxBrightnesses, 1, MAX_LIGHTS))
    lightShader:send("u_additiveStrengths", unpackValues(self.additiveStrengths, 1, MAX_LIGHTS))
    lightShader:send("u_generalShadowMinBrightness", generalShadow.minBrightness or 1)
    lightShader:send("u_generalShadowColor", generalShadow.color or {0, 0, 0})
end

function Elevator:keypressed(key)
    if key == "f" and not self.triggered and self:isPlayerNear() then
        self.triggered = true
        self.sequencePhase = "centering"
        Game.elevatorSequence = self
        Game.elevatorFadeAlpha = 0
        Game.textAlpha, Game.textAlphaTarget = 0, 0
    end
end

function Elevator:getXrayOccluderBox()
    return {
        x = self.x - frameWidth / 2,
        y = self.y - frameHeight + TILE_SIZE,
        width = frameWidth,
        height = frameHeight,
    }
end

function Elevator:drawXrayOccluder(part)
    local image = images[part]
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(image, self.x, self.y, 0, 1, 1, frameWidth / 2, frameHeight - TILE_SIZE)
end

function Elevator:drawPart(part)
    if part == "platform" then
        local image = self.platformImage or platformImage
        local quads = self.platformQuads or platformQuads
        self:sendLightShader()
        love.graphics.setShader(lightShader)
        love.graphics.setColor(1, 1, 1, 1)
        local frame = math.floor(self.platformTimer / 0.12) % #quads + 1
        love.graphics.draw(image, quads[frame], self.x + (self.shakeX or 0), self.y + TILE_SIZE - self.platformOffset + (self.shakeY or 0), 0, 1, 1, 48, 88)
        love.graphics.setShader()
        return
    end
    self:drawStructureImage(images[part])
end

function Elevator:drawStructureImage(image)
    self:sendLightShader()
    love.graphics.setShader(lightShader)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(image, self.x, self.y, 0, 1, 1, frameWidth / 2, frameHeight - TILE_SIZE)
    love.graphics.setShader()
end

return Elevator
