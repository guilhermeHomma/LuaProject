local AudioDeviceSync = {}

local ffi = require("ffi")
local alcLib = nil
local lastDefaultDevice = nil
local checkTimer = 0
local CHECK_INTERVAL = 3.0
local ALC_DEFAULT_DEVICE_SPECIFIER = 0x1004
local ALC_DEVICE_SPECIFIER = 0x1005
local ALC_DEFAULT_ALL_DEVICES_SPECIFIER = 0x1012
local ALC_ALL_DEVICES_SPECIFIER = 0x1013
local ALC_ENUMERATE_ALL_EXT = "ALC_ENUMERATE_ALL_EXT"
local ALC_SOFT_REOPEN_DEVICE = "ALC_SOFT_reopen_device"

AudioDeviceSync.available = false
AudioDeviceSync.lastError = nil
AudioDeviceSync.lastReopenOk = false
AudioDeviceSync.lastCurrentDevice = nil
AudioDeviceSync.lastDefaultDevice = nil

local function tryLoadAlc()
    local libName = "OpenAL32"
    if ffi.os == "OSX" then
        libName = "openal"
    elseif ffi.os == "Linux" then
        libName = "openal"
    end

    local ok, lib = pcall(ffi.load, libName)
    if not ok then
        AudioDeviceSync.lastError = "failed to load OpenAL"
        return
    end

    local defOk = pcall(ffi.cdef, [[
        typedef struct ALCdevice_struct ALCdevice;
        typedef struct ALCcontext_struct ALCcontext;
        const char*  alcGetString(ALCdevice* device, int param);
        ALCcontext*  alcGetCurrentContext(void);
        ALCdevice*   alcGetContextsDevice(ALCcontext* context);
        int          alcIsExtensionPresent(ALCdevice* device, const char* extname);
        int          alcReopenDeviceSOFT(ALCdevice* device, const char* name, const int* attribs);
    ]])
    if defOk then
        alcLib = lib
        AudioDeviceSync.available = true
    else
        AudioDeviceSync.lastError = "failed to define OpenAL FFI"
    end
end

tryLoadAlc()

local function hasExtension(device, name)
    if not alcLib then
        return false
    end

    local ok, result = pcall(alcLib.alcIsExtensionPresent, device, name)
    return ok and result ~= 0
end

local function getAlcString(device, param)
    if not alcLib then
        return nil
    end

    local ok, ptr = pcall(alcLib.alcGetString, device, param)
    if not ok or ptr == nil then
        return nil
    end

    local text = ffi.string(ptr)
    if text == "" then
        return nil
    end

    return text
end

local function getDevice()
    local ok, ctx = pcall(alcLib.alcGetCurrentContext)
    if not ok or ctx == nil then return nil end
    local ok2, dev = pcall(alcLib.alcGetContextsDevice, ctx)
    return ok2 and dev ~= nil and dev or nil
end

local function getCurrentDeviceName()
    local dev = getDevice()
    if not dev then
        return nil
    end

    return getAlcString(dev, ALC_ALL_DEVICES_SPECIFIER)
        or getAlcString(dev, ALC_DEVICE_SPECIFIER)
end

local function getDefaultDeviceName()
    local useAllDevices = hasExtension(nil, ALC_ENUMERATE_ALL_EXT)
    return getAlcString(nil, useAllDevices and ALC_DEFAULT_ALL_DEVICES_SPECIFIER or ALC_DEFAULT_DEVICE_SPECIFIER)
end

local function tryReopen()
    local dev = getDevice()
    if not dev then
        AudioDeviceSync.lastError = "missing current OpenAL device"
        return false
    end

    if not hasExtension(dev, ALC_SOFT_REOPEN_DEVICE) and not hasExtension(nil, ALC_SOFT_REOPEN_DEVICE) then
        AudioDeviceSync.lastError = "ALC_SOFT_reopen_device unavailable"
        return false
    end

    local ok, result = pcall(alcLib.alcReopenDeviceSOFT, dev, nil, nil)
    local reopened = ok and result ~= 0
    AudioDeviceSync.lastReopenOk = reopened
    AudioDeviceSync.lastError = reopened and nil or "alcReopenDeviceSOFT failed"
    return reopened
end

function AudioDeviceSync:refresh(force)
    if not alcLib then
        return false
    end

    local currentDefault = getDefaultDeviceName()
    if not currentDefault then
        AudioDeviceSync.lastError = "could not read default audio device"
        return false
    end

    local changed = lastDefaultDevice ~= nil and lastDefaultDevice ~= currentDefault
    if force or changed then
        local reopened = tryReopen()
        if changed and not reopened then
            return false
        end
        AudioDeviceSync.lastCurrentDevice = getCurrentDeviceName()
    end

    lastDefaultDevice = currentDefault
    AudioDeviceSync.lastDefaultDevice = currentDefault
    return changed
end

function AudioDeviceSync:update(dt)
    if not alcLib then return end
    checkTimer = checkTimer + dt
    if checkTimer < CHECK_INTERVAL then return end
    checkTimer = 0

    self:refresh(false)
end

return AudioDeviceSync
