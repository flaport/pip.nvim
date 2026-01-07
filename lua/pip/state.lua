---@param name string
---@return string
local function normalize_package_name(name)
    -- PEP 503: normalize package names
    local id = name:lower():gsub("[_.-]+", "-")
    return id
end

local ApiCache = {}

function ApiCache.new()
    return setmetatable({}, ApiCache)
end

function ApiCache:__index(key)
    local val = rawget(self, key)
    if val then
        return val
    end

    local id = normalize_package_name(key)
    return rawget(self, id)
end

function ApiCache:__newindex(key, value)
    local id = normalize_package_name(key)
    return rawset(self, id, value)
end

---@class BufCache
---@field packages table<string,TomlPackage>
---@field info table<string,PackageInfo>
---@field diagnostics PipDiagnostic[]

---@class State
---@field cfg Config
---@field buf_cache table<integer,BufCache>
---@field api_cache table<string,ApiPackage>
---@field visible boolean
local State = {
    buf_cache = {},
    api_cache = ApiCache.new(),
    visible = true,
}

function State:clear_cache()
    self.api_cache = ApiCache.new()
end

return State
