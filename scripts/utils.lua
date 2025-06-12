
function checkCollision(a, b)
    if distance(a, b) >60 then return false end

    return a.x < b.x + b.width and
           a.x + a.width > b.x and
           a.y < b.y + b.height and
           a.y + a.height > b.y
end

function transitionValue(value, targetValue, speed, dt)

    if value ~= targetValue then
        value = value + (targetValue - value) * dt *  speed
        if math.abs(targetValue - value) < 0.001 then
            value = targetValue
        end
    end

    return value
end

function drawOutline(text, x, y, width, def, color)
    if not color then color = "090909" end
    love.graphics.setColor(hexToRGB(color))
    local lineSize = 3
    if def then
    --right
    love.graphics.printf(text, x+lineSize, y, width, def)
    --left
    love.graphics.printf(text, x-lineSize, y, width, def)
    --up
    love.graphics.printf(text, x, y-lineSize, width, def)
    --up
    love.graphics.printf(text, x, y+lineSize, width, def)
    else 
        lineSize = 1
        --right
        love.graphics.print(text, x+lineSize, y)
        --left
        love.graphics.print(text, x-lineSize, y)
        --up
        love.graphics.print(text, x, y-lineSize)
        --up
        love.graphics.print(text, x, y+lineSize)
    end
    love.graphics.setColor(hexToRGB("fbfaf7"))

end

function isColorMatch(r, g, b, target)
    local tolerance = 0.1
    return math.abs(r - target.r) < tolerance and
           math.abs(g - target.g) < tolerance and
           math.abs(b - target.b) < tolerance
end

function getDistanceVolume(distance, maxVolume, maxDistance)
    if maxVolume == nil then maxVolume = 1 end
    if maxDistance == nil then maxDistance = 200 end

    if distance >= maxDistance then
        return 0
    end
    local factor = 1 - (distance / maxDistance)
    return maxVolume * factor
end

function normalize(dx, dy)
    local mag = math.sqrt(dx * dx + dy * dy)
    if mag == 0 then return 0, 0 end
    return dx / mag, dy / mag
end

function soundPosition(player, soundObject) 
    local playerDistanceX, playerDistanceY = vectorDistance(Player, soundObject)
    return -playerDistanceX/30/2, -playerDistanceY/30/2
end 

function mousePosition()

    local mouseX, mouseY = love.mouse.getPosition()

    mouseX = mouseX/3/camera.scale+ camera.x/3
    mouseY = mouseY/2/camera.scale + camera.y/2
    return mouseX, mouseY
end

function mouseAngle()
    local mouseX, mouseY = mousePosition()
 
    return math.atan2(mouseY - Player.y, mouseX - Player.x)
end

function setColor255(r, g, b, a)
    a = a or 255
    love.graphics.setColor(r/255, g/255, b/255, a/255)
end

function hexToRGB(hex)
    hex = hex:gsub("#", "")
    return tonumber("0x"..hex:sub(1,2))/255, tonumber("0x"..hex:sub(3,4))/255, tonumber("0x"..hex:sub(5,6))/255
end

function deepcopy(orig, copies)
    copies = copies or {}
    if type(orig) ~= 'table' then return orig end
    if copies[orig] then return copies[orig] end

    local copy = {}
    copies[orig] = copy

    for k, v in pairs(orig) do
        copy[deepcopy(k, copies)] = deepcopy(v, copies)
    end

    setmetatable(copy, deepcopy(getmetatable(orig), copies))
    return copy
end

function distance(a, b)

    local dx = a.x - b.x
    local dy = a.y - b.y

    if b.yWorld then
        dx = a.x - b.xWorld
        dy = a.y - b.yWorld
    end

    return math.sqrt(dx * dx + dy * dy)
end


function vectorDistance(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y

    if b.xWorld and b.yWorld then
        dx = a.x - b.xWorld
        dy = a.y - b.yWorld
    end

    return dx, dy
end



function autoTile(x, y, tilemap) -- grass wall

    local function isNotSolid(y, x)
        local v = tilemap[y] and tilemap[y][x]
        return v ~= 1 and v ~= 3
    end

    local function isSolid(y, x)
        local v = tilemap[y] and tilemap[y][x]
        return v == 1 or v == 3
    end

    if x == 1 or y == 1 or x == #tilemap[y] or y == #tilemap then 
        return 5
    end

    local top = isNotSolid(y - 1, x)
    local bottom = isNotSolid(y + 1, x)
    local left = isNotSolid(y, x - 1)
    local right = isNotSolid(y, x + 1)
    
    local topLeft = isNotSolid(y - 1, x - 1)
    local topRight = isNotSolid(y - 1, x + 1)
    local bottomLeft = isNotSolid(y + 1, x - 1)
    local bottomRight = isNotSolid(y + 1, x + 1)

    local leftNoBottom = left and isSolid(y+1, x-1)
    local rightNoBottom = right and isSolid(y+1, x+1)

    if top and left then return 1 end
    if top and right then return 3 end
    if bottom and left then return 7 end
    if bottom and right then return 9 end



    if top then return 2 end
    if bottom then return 8 end


    if leftNoBottom then return 13 end
    if rightNoBottom then return 12 end

    if left then return 4 end
    if right then return 6 end

    if topLeft then return 5 end --13
    if topRight then return 5 end --12
    if bottomLeft then return 11 end
    if bottomRight then return 10 end

    return 5

end


function autoTileWater(x, y, tilemap) -- water

    local function isNotWater(y, x)
        local v = tilemap[y] and tilemap[y][x]
        return v ~= 8
    end

    if x == 1 or y == 1 or x == #tilemap[y] or y == #tilemap then 
        return 5
    end

    local top = isNotWater(y - 1, x)
    local bottom = isNotWater(y + 1, x)
    local left = isNotWater(y, x - 1)
    local right = isNotWater(y, x + 1)
    
    local topLeft = isNotWater(y - 1, x - 1)
    local topRight = isNotWater(y - 1, x + 1)
    local bottomLeft = isNotWater(y + 1, x - 1)
    local bottomRight = isNotWater(y + 1, x + 1)


    if top and left then return 1 end
    if top and right then return 3 end
    if bottom and left then return 7 end
    if bottom and right then return 9 end

    if top then return 2 end
    if bottom then return 8 end
    if left then return 4 end
    if right then return 6 end

    if bottomLeft then return 11 end
    if bottomRight then return 10 end
    if topLeft then return 13 end
    if topRight then return 12 end 

    return 5

end