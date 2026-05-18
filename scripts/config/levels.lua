local Levels = {}

local levelModules = {
    default = "scripts/levels/default",
    menu = "scripts/levels/menu",
    intro = "scripts/levels/intro",
}

function Levels:get(levelId)
    local resolvedId = levelId or "default"
    local levelPath = levelModules[resolvedId]
    assert(levelPath, "Unknown level: " .. tostring(levelId))
    return require(levelPath)
end

function Levels:getDefault()
    return self:get("menu")
end

return Levels
