local AsyncPathfinder = {}
local Path = require("jumperj.core.path")
local MAX_PENDING = 32
local TIMEOUT = 0.4

local thread, requests, results, mapGeneration = nil, nil, nil, 0
local pending = {}
local pendingCount = 0
local disabled = false

local function startWorker()
    if disabled then return false end
    if thread then
        if thread:getError() then
            disabled = true
            return false
        end
        return true
    end
    if not (love.thread and love.thread.newThread) then return false end
    local ok, worker, requestChannel, resultChannel = pcall(function()
        local input = love.thread.newChannel()
        local output = love.thread.newChannel()
        local workerThread = love.thread.newThread("scripts/tilemaps/pathfindingWorker.lua")
        workerThread:start(input, output)
        return workerThread, input, output
    end)
    if not ok then
        disabled = true
        return false
    end
    thread, requests, results = worker, requestChannel, resultChannel
    return true
end

local function key(sx, sy, ex, ey)
    return sx .. ":" .. sy .. ">" .. ex .. ":" .. ey
end

function AsyncPathfinder:setMap(pathMap)
    mapGeneration = mapGeneration + 1
    pending = {}
    pendingCount = 0
    if not startWorker() then return end
    requests:clear()
    results:clear()
    requests:push({kind = "map", generation = mapGeneration, map = pathMap})
end

function AsyncPathfinder:poll(tilemap)
    if not results then return end
    while true do
        local result = results:pop()
        if not result then break end
        if result.kind == "error" then
            disabled = true
        elseif result.kind == "path" and result.generation == mapGeneration and pending[result.key] then
            local job = pending[result.key]
            pending[result.key] = nil
            pendingCount = pendingCount - 1
            local path
            if result.nodes and tilemap.sharedGrid then
                path = Path:new()
                path.grid = tilemap.sharedGrid
                for i, node in ipairs(result.nodes) do
                    local gridNode = tilemap.sharedGrid:getNodeAt(node.x, node.y)
                    if not gridNode then path = nil break end
                    path[i] = gridNode
                end
            end
            tilemap:getPathCache():put(job.sx, job.sy, job.ex, job.ey, path)
        end
    end
end

function AsyncPathfinder:request(sx, sy, ex, ey)
    if not startWorker() then return false end
    local requestKey = key(sx, sy, ex, ey)
    local job = pending[requestKey]
    if job then
        if love.timer.getTime() - job.time < TIMEOUT then return true end
        pending[requestKey] = nil
        pendingCount = pendingCount - 1
        return false
    end
    if pendingCount >= MAX_PENDING then return false end
    pending[requestKey] = {sx = sx, sy = sy, ex = ex, ey = ey, time = love.timer.getTime()}
    pendingCount = pendingCount + 1
    requests:push({kind = "path", generation = mapGeneration, key = requestKey,
        sx = sx, sy = sy, ex = ex, ey = ey})
    return true
end

return AsyncPathfinder
