local Tombstones = { FLOOR_TILE = 16, WALL_TILE = 17 }

function Tombstones.getMaxCount(room)
    local area = math.max(1, (room.gridWidth or 1) * (room.gridHeight or 1))
    return math.min(16, 5 + math.ceil((area - 1) * 11 / 15))
end

function Tombstones.populate(map, upperLayer, room, canRender, reserved, excluded)
    local state = room.state
    if not state then return end
    local function allowed(x, y, surface)
        if surface ~= 1 then return false end
        if not canRender(x, y) or (excluded and excluded[y .. ":" .. x]) then return false end
        for dy = -2, 2 do
            for dx = -2, 2 do
                local value = map[y + dy] and map[y + dy][x + dx]
                if value == 4 or value == 9 then return false end
            end
        end
        local upper = upperLayer[y] and upperLayer[y][x] == 1
        for dy = -1, 1 do
            for dx = -1, 1 do
                local row = map[y + dy]
                if not row or row[x + dx] ~= surface then return false end
                if reserved[(y + dy) .. ":" .. (x + dx)] then return false end
                local neighborUpper = upperLayer[y + dy] and upperLayer[y + dy][x + dx] == 1 or false
                if neighborUpper ~= (upper or false) then return false end
            end
        end
        return true
    end
    if state.tombstones == nil then
        state.tombstones = {}
        state.tombstoneTargetCount = math.random() < 0.9 and math.random(2, Tombstones.getMaxCount(room)) or 0
    end
    local target = state.tombstoneTargetCount or #state.tombstones
    local previous = state.tombstones
    state.tombstones = {}
    for _, entry in ipairs(previous) do
        if allowed(entry.x, entry.y, entry.surface) then
            state.tombstones[#state.tombstones + 1] = entry
            map[entry.y][entry.x] = Tombstones.WALL_TILE
        end
    end
    if #state.tombstones < target then
        local candidates = {}
        for y, row in ipairs(map) do
            for x, surface in ipairs(row) do
                if surface == 1 and allowed(x, y, surface) then
                    candidates[#candidates + 1] = {x = x, y = y, surface = surface}
                end
            end
        end
        for index = #state.tombstones + 1, target do
            local selected
            while #candidates > 0 do
                local pick = math.random(#candidates)
                local candidate = candidates[pick]
                candidates[pick], candidates[#candidates] = candidates[#candidates], nil
                if allowed(candidate.x, candidate.y, candidate.surface) then
                    selected = candidate
                    break
                end
            end
            if not selected then break end
            state.tombstones[#state.tombstones + 1] = selected
            map[selected.y][selected.x] = Tombstones.WALL_TILE
        end
    end
end

return Tombstones
