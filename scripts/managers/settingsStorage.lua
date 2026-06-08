local SettingsStorage = {}

local settingsFileName = "settings.txt"

local function getDirectory(path)
    if not path or path == "" then
        return nil
    end

    local normalized = path:gsub("\\", "/")
    local directory = normalized:match("^(.*)/[^/]*$")
    if directory and directory ~= "" then
        return directory:gsub("/", package.config:sub(1, 1))
    end

    return nil
end

local function addCandidate(candidates, path)
    if path and path ~= "" then
        for _, candidate in ipairs(candidates) do
            if candidate == path then
                return
            end
        end
        candidates[#candidates + 1] = path
    end
end

function SettingsStorage:getPathCandidates()
    local candidates = {}
    local separator = package.config:sub(1, 1)

    if love and love.filesystem then
        local baseDirectory = love.filesystem.getSourceBaseDirectory and love.filesystem.getSourceBaseDirectory()
        if not baseDirectory or baseDirectory == "" then
            baseDirectory = love.filesystem.getSource and love.filesystem.getSource()
        end
        addCandidate(candidates, baseDirectory and (baseDirectory .. separator .. settingsFileName))
    end

    addCandidate(candidates, settingsFileName)

    local sourcePath = debug and debug.getinfo and debug.getinfo(2, "S")
    sourcePath = sourcePath and sourcePath.source
    if sourcePath and sourcePath:sub(1, 1) == "@" then
        local sourceDirectory = getDirectory(sourcePath:sub(2))
        addCandidate(candidates, sourceDirectory and (sourceDirectory .. separator .. settingsFileName))
    end

    local executableDirectory = arg and getDirectory(arg[0])
    addCandidate(candidates, executableDirectory and (executableDirectory .. separator .. settingsFileName))

    return candidates
end

function SettingsStorage:encode(data)
    return data or ""
end

function SettingsStorage:decode(data)
    return data
end

function SettingsStorage:serialize(settings)
    return table.concat({
        "v=1",
        "w=" .. tostring(settings.width or ""),
        "h=" .. tostring(settings.height or ""),
        "fs=" .. (settings.fullscreen and "1" or "0"),
        "vs=" .. (settings.vsyncEnabled and "1" or "0"),
        "crt=" .. (settings.crtEnabled and "1" or "0"),
        "shake=" .. (settings.cameraShakeEnabled and "1" or "0"),
        "fps=" .. (settings.fpsEnabled and "1" or "0"),
        "lang=" .. tostring(settings.language or "en"),
        "brightness=" .. tostring(settings.brightness or 5),
        "master=" .. tostring(settings.masterVolume or 1),
        "music=" .. tostring(settings.musicVolume or 0.6),
    }, "\n")
end

function SettingsStorage:parse(data)
    local result = {}
    for line in (data or ""):gmatch("[^\r\n]+") do
        local key, value = line:match("^([^=]+)=(.*)$")
        if key then
            result[key] = value
        end
    end

    if result.v ~= "1" then
        return nil
    end

    return result
end

function SettingsStorage:read()
    for _, path in ipairs(self:getPathCandidates()) do
        local file = io.open(path, "rb")
        if file then
            local contents = file:read("*a")
            file:close()
            return contents
        end
    end

    if love and love.filesystem and love.filesystem.getInfo and love.filesystem.getInfo(settingsFileName) then
        return love.filesystem.read(settingsFileName)
    end

    return nil
end

function SettingsStorage:write(contents)
    for _, path in ipairs(self:getPathCandidates()) do
        local file = io.open(path, "wb")
        if file then
            file:write(contents)
            file:close()
            return true
        end
    end

    if love and love.filesystem then
        return love.filesystem.write(settingsFileName, contents)
    end

    return false
end

function SettingsStorage:loadSaved()
    return self:parse(self:decode(self:read()))
end

return SettingsStorage
