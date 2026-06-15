local Elevator = {}
Elevator.__index = Elevator

local LightConfig = require("scripts/config/lightConfig")
local Localization = require("scripts/managers/localization")
local unpackValues = table.unpack or unpack

local image = love.graphics.newImage("assets/sprites/objects/elevator/elevator-structure.png")
image:setFilter("nearest", "nearest")

local sheetWidth, sheetHeight = image:getDimensions()
local frameWidth = sheetWidth / 2
local frameHeight = sheetHeight
local TILE_SIZE = 16
local LIGHT_RADIUS = TILE_SIZE * 9
local MAX_LIGHTS = 8
local DEFAULT_COLLISION_PATTERN = {
    "ccccc",
    "cxxxc",
    "cxxxc",
    "cxxxc",
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

local backQuad = love.graphics.newQuad(0, 0, frameWidth, frameHeight, sheetWidth, sheetHeight)
local frontQuad = love.graphics.newQuad(frameWidth, 0, frameWidth, frameHeight, sheetWidth, sheetHeight)

local function makePart(elevator, part)
    local isFrontPart = part == "front"
    return {
        x = elevator.x,
        y = elevator.y,
        xWorld = elevator.xWorld,
        yWorld = elevator.yWorld,
        isAlive = true,
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

    local dx = Player.x - self.x
    local dy = Player.y - self.y
    local distanceLimit = self.interactionDistance or 34
    return dx * dx + dy * dy <= distanceLimit * distanceLimit
end

function Elevator:update(dt)
    addToDrawQueue(self.y - TILE_SIZE * 3, self.backPart, false)
    addToDrawQueue(self.y, self.frontPart, false)

    if self.triggered then
        return
    end

    if self:isPlayerNear() then
        Game.drawtext = Localization:t("game.next_floor")
        Game.textAlphaTarget = 1
    end
end

function Elevator:getLightCenter()
    return self.x, self.y - TILE_SIZE * 2
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
        if Game and Game.enterElevator then
            Game:enterElevator()
        end
    end
end

function Elevator:getXrayOccluderBox()
    return {
        x = self.x - frameWidth / 2,
        y = self.y - frameHeight,
        width = frameWidth,
        height = frameHeight,
    }
end

function Elevator:drawXrayOccluder(part)
    local quad = part == "front" and frontQuad or backQuad
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(image, quad, self.x, self.y, 0, 1, 1, frameWidth / 2, frameHeight)
end

function Elevator:drawPart(part)
    local quad = part == "front" and frontQuad or backQuad
    self:sendLightShader()
    love.graphics.setShader(lightShader)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(image, quad, self.x, self.y, 0, 1, 1, frameWidth / 2, frameHeight)
    love.graphics.setShader()
end

return Elevator
