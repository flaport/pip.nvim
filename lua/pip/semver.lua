-- PEP 440 version parsing and comparison for Python packages

local M = {}

---@class SemVer
---@field major integer
---@field minor integer
---@field patch integer
---@field pre string? -- pre-release identifier (a, b, rc)
---@field pre_num integer?
---@field post integer?
---@field dev integer?
---@field local_ver string?
---@field epoch integer?

---@class Requirement
---@field op string -- ==, !=, >=, <=, >, <, ~=, ===
---@field vers SemVer
---@field vers_str string

-- Parse a PEP 440 version string
---@param str string
---@return SemVer?
function M.parse_version(str)
    if not str or str == "" then
        return nil
    end

    -- Normalize common version string variations
    str = str:lower()
        :gsub("^v", "")
        :gsub("^release[%-_]?", "")
        :gsub("alpha", "a")
        :gsub("beta", "b")
        :gsub("preview", "rc")
        :gsub("pre", "rc")
        :gsub("[%-_]", ".")

    ---@type SemVer
    local version = {
        major = 0,
        minor = 0,
        patch = 0,
    }

    -- Check for epoch
    local epoch, rest = str:match("^(%d+)!(.+)$")
    if epoch then
        version.epoch = tonumber(epoch)
        str = rest
    end

    -- Parse main version numbers
    local parts = {}
    local main_version, suffix = str:match("^([%d.]+)(.*)$")
    if not main_version then
        return nil
    end

    for part in main_version:gmatch("(%d+)") do
        table.insert(parts, tonumber(part))
    end

    version.major = parts[1] or 0
    version.minor = parts[2] or 0
    version.patch = parts[3] or 0

    -- Parse pre-release, post-release, and dev segments
    if suffix and suffix ~= "" then
        -- Pre-release: a, b, rc followed by optional number
        local pre, pre_num = suffix:match("%.?(a)(%d*)")
        if not pre then
            pre, pre_num = suffix:match("%.?(b)(%d*)")
        end
        if not pre then
            pre, pre_num = suffix:match("%.?(rc)(%d*)")
        end
        if not pre then
            pre, pre_num = suffix:match("%.?(c)(%d*)") -- c is alias for rc
            if pre then pre = "rc" end
        end

        if pre then
            version.pre = pre
            version.pre_num = tonumber(pre_num) or 0
        end

        -- Post-release: .post followed by number
        local post = suffix:match("%.?post(%d*)")
        if post then
            version.post = tonumber(post) or 0
        end

        -- Dev release: .dev followed by number
        local dev = suffix:match("%.?dev(%d*)")
        if dev then
            version.dev = tonumber(dev) or 0
        end

        -- Local version: +xxx
        local local_ver = suffix:match("%+(.+)$")
        if local_ver then
            version.local_ver = local_ver
        end
    end

    return version
end

-- Compare two versions
-- Returns: -1 if a < b, 0 if a == b, 1 if a > b
---@param a SemVer
---@param b SemVer
---@return integer
function M.compare(a, b)
    -- Compare epoch first
    local epoch_a = a.epoch or 0
    local epoch_b = b.epoch or 0
    if epoch_a ~= epoch_b then
        return epoch_a < epoch_b and -1 or 1
    end

    -- Compare main version
    if a.major ~= b.major then
        return a.major < b.major and -1 or 1
    end
    if a.minor ~= b.minor then
        return a.minor < b.minor and -1 or 1
    end
    if a.patch ~= b.patch then
        return a.patch < b.patch and -1 or 1
    end

    -- Pre-release versions come before release versions
    -- dev < pre < (no suffix) < post
    local function release_phase(v)
        if v.dev then return 0 end
        if v.pre then
            if v.pre == "a" then return 1 end
            if v.pre == "b" then return 2 end
            if v.pre == "rc" then return 3 end
        end
        if not v.pre and not v.post then return 4 end
        if v.post then return 5 end
        return 4
    end

    local phase_a = release_phase(a)
    local phase_b = release_phase(b)
    if phase_a ~= phase_b then
        return phase_a < phase_b and -1 or 1
    end

    -- Compare pre-release numbers
    if a.pre and b.pre then
        local pre_num_a = a.pre_num or 0
        local pre_num_b = b.pre_num or 0
        if pre_num_a ~= pre_num_b then
            return pre_num_a < pre_num_b and -1 or 1
        end
    end

    -- Compare post-release numbers
    if a.post and b.post then
        if a.post ~= b.post then
            return a.post < b.post and -1 or 1
        end
    end

    -- Compare dev numbers
    if a.dev and b.dev then
        if a.dev ~= b.dev then
            return a.dev < b.dev and -1 or 1
        end
    end

    return 0
end

-- Parse requirement operators and version
---@param req_str string
---@return Requirement[]
function M.parse_requirements(req_str)
    if not req_str or req_str == "" then
        return {}
    end

    local requirements = {}

    -- Split by comma for multiple requirements
    for req in req_str:gmatch("[^,]+") do
        req = req:gsub("^%s+", ""):gsub("%s+$", "")

        -- Match operator and version
        local op, vers_str = req:match("^([><=!~]+)%s*(.+)$")
        if op and vers_str then
            local vers = M.parse_version(vers_str)
            if vers then
                table.insert(requirements, {
                    op = op,
                    vers = vers,
                    vers_str = vers_str,
                })
            end
        elseif req:match("^%d") then
            -- No operator, assume ==
            local vers = M.parse_version(req)
            if vers then
                table.insert(requirements, {
                    op = "==",
                    vers = vers,
                    vers_str = req,
                })
            end
        end
    end

    return requirements
end

-- Check if a version matches a requirement
---@param version SemVer
---@param req Requirement
---@return boolean
local function matches_requirement(version, req)
    local cmp = M.compare(version, req.vers)

    if req.op == "==" or req.op == "===" then
        return cmp == 0
    elseif req.op == "!=" then
        return cmp ~= 0
    elseif req.op == ">=" then
        return cmp >= 0
    elseif req.op == "<=" then
        return cmp <= 0
    elseif req.op == ">" then
        return cmp > 0
    elseif req.op == "<" then
        return cmp < 0
    elseif req.op == "~=" then
        -- Compatible release: ~=X.Y is equivalent to >=X.Y, ==X.*
        if cmp < 0 then
            return false
        end
        -- Check major.minor matches
        return version.major == req.vers.major and version.minor == req.vers.minor
    end

    return false
end

-- Check if a version matches all requirements
---@param version SemVer
---@param requirements Requirement[]
---@return boolean
function M.matches_requirements(version, requirements)
    if not requirements or #requirements == 0 then
        return true
    end

    for _, req in ipairs(requirements) do
        if not matches_requirement(version, req) then
            return false
        end
    end

    return true
end

-- Check if requirements allow pre-release versions
---@param requirements Requirement[]
---@return boolean
function M.allows_pre(requirements)
    if not requirements then
        return false
    end

    for _, req in ipairs(requirements) do
        if req.vers and req.vers.pre then
            return true
        end
    end

    return false
end

-- Format a version back to string
---@param vers SemVer
---@return string
function M.format_version(vers)
    local str = string.format("%d.%d.%d", vers.major, vers.minor, vers.patch)

    if vers.pre then
        str = str .. vers.pre .. (vers.pre_num or "")
    end
    if vers.post then
        str = str .. ".post" .. vers.post
    end
    if vers.dev then
        str = str .. ".dev" .. vers.dev
    end
    if vers.local_ver then
        str = str .. "+" .. vers.local_ver
    end
    if vers.epoch then
        str = vers.epoch .. "!" .. str
    end

    return str
end

return M
