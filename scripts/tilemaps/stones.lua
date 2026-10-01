local Stones = { TILE = 18 }

function Stones.getCountRange(room)
    local area = math.max(1, (room.gridWidth or 1) * (room.gridHeight or 1))
    if area == 1 then return 3, 6 end
    if area == 2 then return 7, 10 end
    return 12, 16
end

function Stones.populate(map, room, canRender, reserved, excluded)
    local state = room.state
    if not state then return end
    local function allowed(x, y)
        if not canRender(x, y) or excluded[y .. ":" .. x] then return false end
        for dy = -2, 2 do
            for dx = -2, 2 do
                local value = map[y + dy] and map[y + dy][x + dx]
                if value == 4 or value == 9 then return false end
            end
        end
        -- One empty floor tile separates stones from walls and other objects.
        for dy = -1, 1 do
            for dx = -1, 1 do
                local row = map[y + dy]
                if not row or row[x + dx] ~= 0 or reserved[(y + dy) .. ":" .. (x + dx)] then
                    return false
                end
            end
        end
        return true
    end
    if state.stones == nil then
        local minCount, maxCount = Stones.getCountRange(room)
        state.stones = {}
        state.stoneTargetCount = math.random() < 0.3 and math.random(minCount, maxCount) or 0
    end
    local target = state.stoneTargetCount or #state.stones
    local previous = state.stones
    state.stones = {}
    for _, entry in ipairs(previous) do
        if allowed(entry.x, entry.y) then
            state.stones[#state.stones + 1] = entry
            map[entry.y][entry.x] = Stones.TILE
        end
    end
    if #state.stones >= target then return end

    local candidates = {}
    for y, row in ipairs(map) do
        for x, value in ipairs(row) do
            if value == 0 and allowed(x, y) then
                candidates[#candidates + 1] = {x = x, y = y, tieBreak = math.random()}
            end
        end
    end
    while #state.stones < target do
        local best, bestScore
        for index, candidate in ipairs(candidates) do
            if allowed(candidate.x, candidate.y) then
                local nearest = math.huge
                for _, stone in ipairs(state.stones) do
                    local dx, dy = candidate.x - stone.x, candidate.y - stone.y
                    nearest = math.min(nearest, dx * dx + dy * dy)
                end
                local score = (#state.stones == 0 and 0 or nearest) + candidate.tieBreak
                if not bestScore or score > bestScore then best, bestScore = index, score end
            end
        end
        if not best then break end
        local candidate = table.remove(candidates, best)
        local entry = {x = candidate.x, y = candidate.y, variant = math.random(1, 2)}
        state.stones[#state.stones + 1] = entry
        map[entry.y][entry.x] = Stones.TILE
    end
end

return Stones
