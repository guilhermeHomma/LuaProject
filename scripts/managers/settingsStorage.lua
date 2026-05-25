local SettingsStorage = {}

local settingsFileName = "pak02.bin"
local settingsKey = "mobize-runtime-cache-v2"
local bitXor = bit and bit.bxor or bit32 and bit32.bxor

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

local function encodeByte(value)
    return string.format("%02x", value)
end

local function decodeByte(hex)
    return tonumber(hex, 16) or 0
end

local function crypt(data)
    if not bitXor then
        return data
    end

    local output = {}
    local keyLength = #settingsKey

    for i = 1, #data do
        local dataByte = data:byte(i)
        local keyByte = settingsKey:byte(((i - 1) % keyLength) + 1)
        output[i] = string.char(bitXor(dataByte, keyByte))
    end

    return table.concat(output)
end

function SettingsStorage:encode(data)
    local encrypted = crypt(data)
    local output = {}

    for i = 1, #encrypted do
        output[i] = encodeByte(encrypted:byte(i))
    end

    return table.concat(output)
end

function SettingsStorage:decode(data)
    if not data or #data < 2 then
        return nil
    end

    local bytes = {}
    for i = 1, #data - 1, 2 do
        bytes[#bytes + 1] = string.char(decodeByte(data:sub(i, i + 1)))
    end

    return crypt(table.concat(bytes))
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
