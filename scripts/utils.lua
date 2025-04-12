
function checkCollision(a, b)
    if distance(a, b) >60 then return false end

    return a.x < b.x + b.width and
           a.x + a.width > b.x and
           a.y < b.y + b.height and
           a.y + a.height > b.y
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