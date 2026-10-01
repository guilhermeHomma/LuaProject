local Geometry = {}

function Geometry.base(x, y)
    return {x = x - 64, y = y - 96, width = 128, height = 112}
end

function Geometry.interaction(x, y)
    return {x = x - 32, y = y - 64, width = 64, height = 48}
end

function Geometry.contains(box, x, y)
    return x >= box.x and x < box.x + box.width
        and y >= box.y and y < box.y + box.height
end

return Geometry
