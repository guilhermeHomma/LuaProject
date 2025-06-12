local Game = {}

Player = require "scripts/player/player"
Camera = require("scripts/camera")

local Ground = require("scripts/ground")
local WaveManager = require("scripts/managers/waves")
local Clouds = require("scripts/clouds")
local Tilemap = require("scripts/tilemap")
local PointsManager = require("scripts/managers/pointsManager")
local DoorsManager = require("scripts/managers/doorsManager")
local HeartSound = require("scripts/player/heartSound")

camera = nil

function Game:load()
    
    math.randomseed(os.time())
    love.graphics.setDefaultFilter("nearest", "nearest")
    camera = Camera:new(10, 15)
    Player:load(camera)
    Ground:load()
    WaveManager:load()
    Clouds:load()
    Tilemap:load()
    DoorsManager:load()
    PointsManager:load()
    HeartSound:load()

    local cursorImage = love.image.newImageData("assets/sprites/cursor.png")
    local cursor = love.mouse.newCursor(cursorImage, 8, 8) 
    love.mouse.setCursor(cursor)

    self.enemies = {}
    self.drawQueue = {}
    self.particles = {}
    --self:openNorth()
    --self:openSouth()

    
end

function Game:openSouth()
    DoorsManager:openSouth()
    camera.minDown = 240
end

function Game:openNorth()
    DoorsManager:openNorth()
    camera.maxTop = -1000
end

function Game:close()
    HeartSound:stop()
    self = {}
end

function Game:getPlayerPoints()
    return PointsManager:getPoints()
end

function Game:increasePlayerPoints(qty)
    PointsManager:increasePoints(qty)
end

function Game:decreasePlayerPoints(qty)
    return PointsManager:decreasePoints(qty)
end


function Game:update(dt)
    self.drawQueue = {}
    --love.audio.setPosition(Player.x, Player.y, 0)
    local targetPitch = 1

    if Player.life == 1
    then
        targetPitch = 0.9
    end
    GAME_PITCH = transitionValue(GAME_PITCH, targetPitch, 1.3, dt)


    for _, enemy in ipairs(self.enemies) do
        if enemy.isAlive then
            enemy:update(dt) 
        else
            table.remove(self.enemies, _)
        end
    end

    for i = #self.particles, 1, -1 do
        local particle = self.particles[i]
        particle:update(dt)
        if not particle.isAlive then
            table.remove(self.particles, i)
        end
    end

    WaveManager:update(dt)
    Clouds:update(dt)
    Player:update(dt)
    DoorsManager:update(dt)
    HeartSound:update(dt)
    Tilemap:update(dt)
    PointsManager:update(dt)

    camera:update(dt)
end

function addToDrawQueue(priority, object)
    if distance(camera:objectPosition(), object) > 300 then
        return
    end
    table.insert(Game.drawQueue, {priority = priority, object = object})
end

function Game:draw()
    camera:attach()

    love.graphics.scale(3, 2) 

    

    Ground:draw(Player)
    
    table.sort(self.drawQueue, function(a, b) return a.priority < b.priority end)
    Clouds:drawShadow()

    for _, item in ipairs(self.drawQueue) do
        if type(item.object.drawShadow) == "function" then
            item.object:drawShadow()
        end
    end

    Player:drawSight()

    for _, item in ipairs(self.drawQueue) do
        local d = distance(camera:objectPosition(), item.object)

        local minDist = 20
        local maxDist = 200

        local minDist = 110
        local maxDist = 260

        local t = math.min(math.max((d - minDist) / (maxDist - minDist), 0), 1)
        local brightness = 1 - t * 0.8
        local r, g, b, a = 1,1,1,1
        --love.graphics.setColor(r * brightness, g * brightness, b * brightness, a)
        item.object:draw()
        love.graphics.setColor(r, g, b, a)
    end
    Clouds:draw()
    
    love.graphics.scale(1, 1)
    
    camera:detach()
    
    
    PointsManager:draw()
    Player:drawLife()
    if Player and Player.isAlive then
        Player.gun:drawUI()
    end
    WaveManager:draw()
  

    if DEBUG then
        love.graphics.print("enemies qty: " .. #self.enemies, 10, 110)
    end

    --love.graphics.setColor(0.3, 0.45, 0.45, Player.damageAlha)
    love.graphics.setColor(0, 0, 0.1, Player.damageAlha)
    love.graphics.rectangle("fill", 0, 0, baseWidth, baseHeight)
    love.graphics.setColor(1, 1, 1)

end

function Game:keypressed(key)
    if key == "f6" then
        --DEBUG = not DEBUG
    elseif key == "x" then
        Tilemap:keypressed(key)
    elseif key == "o" then
        DoorsManager:openSouth()
        DoorsManager:openNorth()
    elseif tonumber(key) then
        --self:changeShaders(tonumber(key))
    end
end

return Game