local PathCache = {}
PathCache.__index = PathCache

local function makeKey(startMapX, startMapY, endMapX, endMapY)
    return startMapX .. ":" .. startMapY .. ">" .. endMapX .. ":" .. endMapY
end

local function copyPath(path)
    if not path then
        return nil
    end

    local result = {}
    for i = 1, #path do
        result[i] = path[i]
    end
    result.grid = path.grid
    return setmetatable(result, getmetatable(path))
end

function PathCache:new(options)
    options = options or {}
    return setmetatable({
        entries = {},
        count = 0,
        maxEntries = options.maxEntries or 96,
        ttl = options.ttl or 0.6,
    }, self)
end

function PathCache:clear()
    self.entries = {}
    self.count = 0
end

function PathCache:get(startMapX, startMapY, endMapX, endMapY)
    local key = makeKey(startMapX, startMapY, endMapX, endMapY)
    local entry = self.entries[key]
    if not entry then
        return nil, false
    end

    local now = love.timer.getTime()
    if now - (entry.time or 0) > self.ttl then
        self.entries[key] = nil
        self.count = math.max(0, (self.count or 1) - 1)
        return nil, false
    end

    entry.lastUsed = now
    if entry.path == false then
        return nil, true
    end

    return copyPath(entry.path), true
end

function PathCache:prune(now)
    local count = self.count or 0
    if count <= self.maxEntries then
        return
    end

    local oldestKey = nil
    local oldestTime = math.huge
    for key, entry in pairs(self.entries) do
        local age = now - (entry.time or 0)
        if age > self.ttl then
            self.entries[key] = nil
            count = count - 1
        elseif (entry.lastUsed or entry.time or 0) < oldestTime then
            oldestKey = key
            oldestTime = entry.lastUsed or entry.time or 0
        end
    end

    while count > self.maxEntries and oldestKey do
        self.entries[oldestKey] = nil
        count = count - 1
        oldestKey = nil
        oldestTime = math.huge

        for key, entry in pairs(self.entries) do
            local lastUsed = entry.lastUsed or entry.time or 0
            if lastUsed < oldestTime then
                oldestKey = key
                oldestTime = lastUsed
            end
        end
    end

    self.count = math.max(0, count)
end

function PathCache:put(startMapX, startMapY, endMapX, endMapY, path)
    local key = makeKey(startMapX, startMapY, endMapX, endMapY)
    local now = love.timer.getTime()
    if not self.entries[key] then
        self.count = (self.count or 0) + 1
    end

    self.entries[key] = {
        path = path and copyPath(path) or false,
        time = now,
        lastUsed = now,
    }
    self:prune(now)
end

return PathCache
