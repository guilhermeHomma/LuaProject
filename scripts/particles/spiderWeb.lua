local SpiderWeb = {}
SpiderWeb.__index = SpiderWeb
SpiderWeb.castsShadow = false

local Tilemap = require("scripts/tilemap")

local sprite = love.graphics.newImage("assets/sprites/enemy/spider/web.png")
sprite:setFilter("nearest", "nearest")

local MAX_WEBS_PER_ROOM = 7
local START_SCALE = 0.7
local SPAWN_DURATION = 0.2
local SLOW_MULTIPLIER = 0.5
local SLOW_REFRESH_TIME = 0.08
local COLLISION_RADIUS = 4
local WEB_WALKABLE_PADDING_TILES = 1
local TILE_FLOOR = 0
local TILE_DOOR_BACK = 9

local function isWalkableTile(tile)
    return tile == TILE_FLOOR or tile == TILE_DOOR_BACK
end

local function isSafeWebTile(mapX, mapY)
    local tilemap = Tilemap:getTilemap()
    if not (tilemap and tilemap[mapY]) then
        return false
    end

    for y = mapY - WEB_WALKABLE_PADDING_TILES, mapY + WEB_WALKABLE_PADDING_TILES do
        for x = mapX - WEB_WALKABLE_PADDING_TILES, mapX + WEB_WALKABLE_PADDING_TILES do
            if not isWalkableTile(tilemap[y] and tilemap[y][x]) then
                return false
            end
        end
    end

    return true
end

function SpiderWeb:new(x, y, mapX, mapY)
    local web = setmetatable({}, SpiderWeb)
    web.x = x
    web.y = y
    web.mapX = mapX
    web.mapY = mapY
    web.isAlive = true
    web.particleType = "spiderWeb"
    web.isGroundLayer = true
    web.affectedByLight = true
    web.drawPriority = y + 0.6
    web.radius = COLLISION_RADIUS
    web.timer = 0
    web.stretchTimer = 0
    web.lastTouchPositions = {}
    return web
end

function SpiderWeb:queueDraw()
    if Game and Game.groundDecalQueue then
        Game.groundDecalQueue[#Game.groundDecalQueue + 1] = self
    else
        addToDrawQueue(self.drawPriority, self, false)
    end
end

local function touchMoved(web, object, dt)
    if not object then
        return false
    end

    local previous = web.lastTouchPositions[object]
    local moved = false
    if previous then
        local dx = (object.x or 0) - previous.x
        local dy = (object.y or 0) - previous.y
        moved = dx * dx + dy * dy > 0.04 * (dt * 60)
    end

    web.lastTouchPositions[object] = { x = object.x or 0, y = object.y or 0 }
    return moved
end

function SpiderWeb:isTouching(object)
    if not (object and object.x and object.y) then
        return false
    end

    local dx = object.x - self.x
    local dy = object.y - self.y - 3
    local radius = self.radius + (object.size or 0) * 0.18
    return dx * dx + dy * dy <= radius * radius
end

function SpiderWeb:update(dt)
    self.timer = self.timer + dt
    self.stretchTimer = math.max(0, (self.stretchTimer or 0) - dt)

    if Player and Player.isAlive and self:isTouching(Player) then
        if math.abs(Player.velocityX or 0) + math.abs(Player.velocityY or 0) > 2 then
            self.stretchTimer = 0.12
        end
        Player.webSlowTimer = SLOW_REFRESH_TIME
        Player.webSlowMultiplier = SLOW_MULTIPLIER
    end

    for _, enemy in ipairs((Game and Game.nearbyEnemies) or {}) do
        if enemy.isAlive ~= false and self:isTouching(enemy) and touchMoved(self, enemy, dt) then
            self.stretchTimer = 0.12
            break
        end
    end
end

function SpiderWeb:draw()
    local spawnProgress = math.min((self.timer or 0) / SPAWN_DURATION, 1)
    local easedSpawn = 1 - (1 - spawnProgress) * (1 - spawnProgress)
    local scale = START_SCALE + (1 - START_SCALE) * easedSpawn
    local spawnStretch = math.sin(spawnProgress * math.pi) * 0.05
    local touchStretch = (self.stretchTimer or 0) > 0 and math.sin(love.timer.getTime() * 22) * 0.025 or 0
    local stretch = spawnStretch + touchStretch
    local scaleX = scale * (1 + stretch)
    local scaleY = scale * (1 - stretch)
    local originX = sprite:getWidth() / 2
    local originY = sprite:getHeight() / 2

    local tintR = self.lightTintR or 1
    local tintG = self.lightTintG or tintR
    local tintB = self.lightTintB or tintR

    love.graphics.setColor(0.02 * tintR, 0.02 * tintG, 0.025 * tintB, 0.1)
    love.graphics.draw(sprite, self.x, self.y + 1, 0, scaleX, scaleY, originX, originY)
    love.graphics.setColor(tintR, tintG, tintB, 0.9)
    love.graphics.draw(sprite, self.x, self.y, 0, scaleX, scaleY, originX, originY)
    love.graphics.setColor(1, 1, 1, 1)
end

function SpiderWeb.countInRoom()
    local count = 0
    for _, particle in ipairs((Game and Game.particles) or {}) do
        if particle.particleType == "spiderWeb" and particle.isAlive ~= false then
            count = count + 1
        end
    end
    return count
end

function SpiderWeb.hasAtTile(mapX, mapY)
    for _, particle in ipairs((Game and Game.particles) or {}) do
        if particle.particleType == "spiderWeb"
            and particle.isAlive ~= false
            and particle.mapX == mapX
            and particle.mapY == mapY then
            return true
        end
    end
    return false
end

function SpiderWeb.spawn(x, y, mapX, mapY)
    if not (Game and Game.particles) then
        return false
    end

    if SpiderWeb.countInRoom() >= MAX_WEBS_PER_ROOM
        or SpiderWeb.hasAtTile(mapX, mapY)
        or not isSafeWebTile(mapX, mapY) then
        return false
    end

    Game.particles[#Game.particles + 1] = SpiderWeb:new(x, y, mapX, mapY)
    return true
end

function SpiderWeb.spawnRandomReachable(count, reference, minDistance)
    local spawned = 0
    local attempts = 0
    local avoidPoints = {}

    while spawned < count and attempts < count * 30 and SpiderWeb.countInRoom() < MAX_WEBS_PER_ROOM do
        attempts = attempts + 1
        local x, y = Tilemap:getRandomReachableSpawnPosition(reference or Player, minDistance or 40, avoidPoints)
        if x and y then
            local mapX, mapY = Tilemap:worldToMap(x, y)
            if not SpiderWeb.hasAtTile(mapX, mapY) and isSafeWebTile(mapX, mapY) then
                local webX, webY = Tilemap:mapToWorld(mapX, mapY)
                if SpiderWeb.spawn(webX, webY - 8, mapX, mapY) then
                    spawned = spawned + 1
                    avoidPoints[#avoidPoints + 1] = { x = webX, y = webY }
                end
            end
        end
    end

    return spawned
end

return SpiderWeb
