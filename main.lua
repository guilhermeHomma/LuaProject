Player = require "scripts/player/player"

require "scripts/utils"
local stretchFactor = 0.65

local Camera = require("scripts/camera")
local canvas
camera = Camera:new()

local Ground = require("scripts/ground")
local WaveManager = require("scripts/managers/waves")
local Clouds = require("scripts/clouds")
local Tilemap = require("scripts/tilemap")
local DoorsManager = require("scripts/managers/doorsManager")
local shader = love.graphics.newShader("scripts/shaders/palette.glsl")
local paletteList = require("scripts/shaders/paletteList")

love.graphics.setDefaultFilter("nearest", "nearest")

drawQueue = {}
enemies = {}
particles = {}

DEBUG = false
FPS = false

local music 

function love.load()

    canvas = love.graphics.newCanvas(love.graphics.getWidth(), love.graphics.getHeight())
    math.randomseed(os.time())
    WaveManager:load()
    camera = Camera:new()
    Player:load(camera)
    Ground:load()
    Clouds:load()
    Tilemap:load()
    DoorsManager:load()

    

    local cursorImage = love.image.newImageData("assets/sprites/cursor.png")
    local cursor = love.mouse.newCursor(cursorImage, 8, 8) 
    love.mouse.setCursor(cursor)
    music = love.audio.newSource("assets/sfx/music.wav", "stream")
    music:setLooping(true) 
    music:setVolume(0.8)
    --music:play()
    changeShaders(1)
end


local function restartGame()
    enemies = {}
    particles = {}
    drawQueue = {}

    camera = Camera:new()
    WaveManager:load()
    Player:load(camera)
    Ground:load()
    Clouds:load()
    DoorsManager:load()
    Tilemap:load()

end

function changeShaders(index)

    if index >= #paletteList then return end

    local oldColors = paletteList[1]
    local newColors = paletteList[index+1]

    shader:send("oldColors", unpack(oldColors))
    shader:send("newColors", unpack(newColors))
    shader:send("threshold", 0.1) 
end

function love.keypressed(key)
    if key == "r" then
        restartGame()
    end

    if key == "o" then
        DoorsManager:openSouth()
        DoorsManager:openNorth()
    end

    if key == "f5" then
        FPS = not FPS
    end

    if key == "f6" then
        DEBUG = not DEBUG
    end

    if key == "g" then
        shadersEnable = not shadersEnable
    end

    if tonumber(key) then
        changeShaders(tonumber(key))
    end
end

function love.update(dt)
    for _, enemy in ipairs(enemies) do
        if enemy.isAlive then
            enemy:update(dt) 
            addToDrawQueue(enemy.y +4 + enemy.drawPriority, enemy)
        else
            table.remove(enemies, _)
        end
    end

    for i = #particles, 1, -1 do
        local particle = particles[i]
        particle:update(dt)
        if not particle.isAlive then
            table.remove(particles, i)
        end
    end

    WaveManager:update(dt)
    Clouds:update(dt)
    Player:update(dt)
    DoorsManager:update(dt)

    Tilemap:update()

    camera:update(Player.x *3 - love.graphics.getWidth() / camera.scale / 2, Player.y*2 - love.graphics.getHeight() / camera.scale  / 2)
end


function addToDrawQueue(priority, object)
    table.insert(drawQueue, {priority = priority, object = object})
end

function love.draw()

    love.graphics.setCanvas(canvas)

    love.graphics.clear(0.780, 0.75, 0.57)
    camera:attach()

    love.graphics.scale(3, 2) 

    love.graphics.setShader(shader)

    Ground:draw(Player)
    
    table.sort(drawQueue, function(a, b) return a.priority < b.priority end)
    Clouds:drawShadow()

    for _, item in ipairs(drawQueue) do
        if type(item.object.drawShadow) == "function" then

            if distance(Player, item.object) < 300 then 
                item.object:drawShadow()
            end
        end
    end

    Player:drawS()
    Player:drawSight()

    for _, item in ipairs(drawQueue) do
        if distance(Player, item.object) < 400 then 
            item.object:draw()
        end
    end
    Clouds:draw()
    
    love.graphics.scale(1, 1)
    
    drawQueue = {}
    camera:detach()
    love.graphics.setShader()
    love.graphics.setCanvas()
    love.graphics.draw(canvas, 0, 0, 0, camera.scale, camera.scale)
    Player:drawLife()
    WaveManager:draw()
    
    if FPS or DEBUG then 
        love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 60)
    end
    if DEBUG then
        love.graphics.print("enemies qty: " .. #enemies, 10, 80)
    end
   
end

