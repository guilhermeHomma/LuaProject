local requests, results = ...
local Grid = require("jumperj.grid")
local Pathfinder = require("jumperj.pathfinder")

local finder, fallback, generation

while true do
    local request = requests:demand()
    if request == false then break end

    if request.kind == "map" then
        local ok, err = pcall(function()
            local grid = Grid(request.map)
            finder = Pathfinder(grid, "JPS", 0)
            fallback = Pathfinder(grid, "ASTAR", 0)
            finder:setMode("ORTHOGONAL")
            fallback:setMode("ORTHOGONAL")
            finder:setHeuristicWeight(1.35)
            fallback:setHeuristicWeight(1.35)
            generation = request.generation
        end)
        if not ok then
            finder, fallback, generation = nil, nil, nil
            results:push({kind = "error", message = tostring(err)})
        end
    elseif request.kind == "path" and finder and generation == request.generation then
        local ok, path = pcall(finder.getPath, finder, request.sx, request.sy, request.ex, request.ey)
        if not ok or not path then
            ok, path = pcall(fallback.getPath, fallback, request.sx, request.sy, request.ex, request.ey)
        end
        local nodes
        if ok and path then
            nodes = {}
            for i = 1, #path do
                nodes[i] = {x = path[i].x, y = path[i].y}
            end
        end
        results:push({kind = "path", generation = generation, key = request.key, nodes = nodes})
    end
end
