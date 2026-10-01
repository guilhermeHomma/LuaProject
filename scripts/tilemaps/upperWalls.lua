local UpperWalls = {}

local INSET = 2
local MAX_PATCHES = 6

local function isWall(value)
    return value == 1 or value == 3 or value == 14 or value == 11
end

local function isTree(value)
    return value == 3 or value == 14
end

local function isRaisedEdge(layer, x, y)
    if not (layer[y] and layer[y][x] == 1) then return false end
    for dy = -1, 1 do
        for dx = -1, 1 do
            if not (layer[y + dy] and layer[y + dy][x + dx] == 1) then return true end
        end
    end
    return false
end

-- Trees on raised edges move to a free flat tile; poles keep their position.
function UpperWalls.build(map, roomId, canRender)
    local layer, blocked, candidates = {}, {}, {}
    local seed = 0
    for i = 1, #tostring(roomId or "") do
        seed = (seed * 31 + string.byte(tostring(roomId), i)) % 65521
    end
    for y, row in ipairs(map) do
        layer[y], blocked[y] = {}, {}
        for x in ipairs(row) do
            layer[y][x] = 0
            if isWall(row[x]) and canRender(x, y) then
                candidates[#candidates + 1] = {
                    x = x, y = y,
                    score = (x * 7387 + y * 1933 + seed * 31 + x * y * 97) % 65521,
                }
            end
        end
    end
    table.sort(candidates, function(a, b)
        if a.score ~= b.score then return a.score < b.score end
        if a.y ~= b.y then return a.y < b.y end
        return a.x < b.x
    end)

    local count = 0
    for _, candidate in ipairs(candidates) do
        if count >= MAX_PATCHES then break end
        local x, y = candidate.x, candidate.y
        local width = 2 + candidate.score % 4
        local height = 2 + math.floor(candidate.score / 4) % 3
        local fits = true
        -- Require exactly INSET supporting tiles beyond each edge of the patch.
        for checkY = y - INSET, y + height - 1 + INSET do
            for checkX = x - INSET, x + width - 1 + INSET do
                local row = map[checkY]
                if not (row and isWall(row[checkX]))
                    or (layer[checkY] and layer[checkY][checkX] == 1) then
                    fits = false
                    break
                end
            end
            if not fits then break end
        end
        if fits then
            for patchY = y - 1, y + height - 1 do
                for patchX = x, x + width - 1 do
                    if not canRender(patchX, patchY) then fits = false end
                end
            end
        end
        if fits then
            for patchY = y, y + height - 1 do
                for patchX = x, x + width - 1 do
                    layer[patchY][patchX] = 1
                end
            end
            local moves, reserved = {}, {}
            for treeY = y, y + height - 1 do
                for treeX = x, x + width - 1 do
                    if isTree(map[treeY][treeX]) and isRaisedEdge(layer, treeX, treeY) then
                        local target
                        for radius = 1, math.max(#map, #map[treeY]) do
                            for dy = -radius, radius do
                                for dx = -radius, radius do
                                    if math.max(math.abs(dx), math.abs(dy)) == radius then
                                        local tx, ty = treeX + dx, treeY + dy
                                        local key = ty .. ":" .. tx
                                        if map[ty] and map[ty][tx] == 1 and not reserved[key]
                                            and canRender(tx, ty) and not isRaisedEdge(layer, tx, ty) then
                                            target = {x = tx, y = ty}
                                            reserved[key] = true
                                            break
                                        end
                                    end
                                end
                                if target then break end
                            end
                            if target then break end
                        end
                        if target then
                            moves[#moves + 1] = {x = treeX, y = treeY, target = target}
                        else
                            fits = false
                        end
                    end
                end
            end
            if fits then
                for _, move in ipairs(moves) do
                    map[move.target.y][move.target.x] = map[move.y][move.x]
                    map[move.y][move.x] = 1
                end
            else
                -- Preserve every tree if there is no safe relocation available.
                for patchY = y, y + height - 1 do
                    for patchX = x, x + width - 1 do
                        layer[patchY][patchX] = 0
                    end
                end
            end
        end
        if fits then
            count = count + 1
            -- Keep vegetation off the faces, but retain trees on the flat top.
            for clearY = y, y + height - 1 do
                for clearX = x, x + width - 1 do
                    blocked[clearY][clearX] = true
                end
            end
        end
    end
    return layer, blocked
end

return UpperWalls
