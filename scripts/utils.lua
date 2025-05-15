
function checkCollision(a, b)
    if distance(a, b) >60 then return false end

    return a.x < b.x + b.width and
           a.x + a.width > b.x and
           a.y < b.y + b.height and
           a.y + a.height > b.y
end

function drawOutline(text, x, y, width, def, color)
    if not color then color = "090909" end
    love.graphics.setColor(hexToRGB(color))
    local lineSize = 3

    --right
    love.graphics.printf(text, x+lineSize, y, width, def)
    --left
    love.graphics.printf(text, x-lineSize, y, width, def)
    --up
    love.graphics.printf(text, x, y-lineSize, width, def)
    --up
    love.graphics.printf(text, x, y+lineSize, width, def)
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
    return -playerDistanceX/30, -playerDistanceY/30
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


function debugObject(obj)
    print("== Object Debug ==")
    print("type: " .. type(obj))
    print("ToString: " .. tostring(obj))

    local mt = getmetatable(obj)
    if mt then
        print("Metatable:")
        for k, v in pairs(mt) do
            print("  ", k, v)
        end
    end

    print("atrr:")
    for k, v in pairs(obj) do
        print("  ", k, v)
    end
end