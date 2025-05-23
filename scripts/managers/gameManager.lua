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
local shader = love.graphics.newShader("scripts/shaders/palette.glsl")
local paletteList = require("scripts/shaders/paletteList")

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

    self:changeShaders(0)
end

function Game:close()
    HeartSound:stop()
end

function Game:changeShaders(index)
    if index >= #paletteList then return end
    local oldColors = paletteList[1]
    local newColors = paletteList[index + 1]
    shader:send("oldColors", unpack(oldColors))
    shader:send("newColors", unpack(newColors))
    shader:send("threshold", 0.1)
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

    for _, enemy in ipairs(self.enemies) do
        if enemy.isAlive then
            enemy:update(dt) 
            addToDrawQueue(enemy.y +6 + enemy.drawPriority, enemy)
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

    camera:update()
end

function addToDrawQueue(priority, object)
    table.insert(Game.drawQueue, {priority = priority, object = object})
end

function Game:draw()
    camera:attach()

    love.graphics.scale(3, 2) 

    --love.graphics.setShader(shader)

    Ground:draw(Player)
    
    table.sort(self.drawQueue, function(a, b) return a.priority < b.priority end)
    Clouds:drawShadow()

    for _, item in ipairs(self.drawQueue) do
        if type(item.object.drawShadow) == "function" then

            if distance(Player, item.object) < 300 then 
                item.object:drawShadow()
            end
        end
    end

    Player:drawS()
    Player:drawSight()

    for _, item in ipairs(self.drawQueue) do
        if distance(Player, item.object) < 400 then 
            item.object:draw()
        end
    end
    Clouds:draw()
    
    love.graphics.scale(1, 1)
    
    camera:detach()
    --love.graphics.setShader()
    
    PointsManager:draw()
    Player:drawLife()
    if Player and Player.isAlive then
        Player.gun:drawUI()
    end
    WaveManager:draw()
  

    if DEBUG then
        love.graphics.print("enemies qty: " .. #self.enemies, 10, 110)
    end
end

function Game:keypressed(key)
    if key == "f6" then
        DEBUG = not DEBUG
    elseif key == "x" then
        Tilemap:keypressed(key)
    elseif key == "o" then
        DoorsManager:openSouth()
        DoorsManager:openNorth()
    elseif tonumber(key) then
        self:changeShaders(tonumber(key))
    end
end

return Game