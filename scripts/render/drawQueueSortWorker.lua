local requests, results = ...

while true do
    local request = requests:demand()
    if request == false then
        break
    end

    local keys = request.keys
    local indices = {}
    for i = 1, #keys / 2 do
        indices[i] = i
    end
    table.sort(indices, function(a, b)
        local aPriority, bPriority = keys[a * 2 - 1], keys[b * 2 - 1]
        if aPriority == bPriority then
            return keys[a * 2] < keys[b * 2]
        end
        return aPriority < bPriority
    end)
    results:push({id = request.id, indices = indices})
end
