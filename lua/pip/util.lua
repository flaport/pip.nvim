local semver = require("pip.semver")

local M = {}

---@return integer
function M.current_buf()
    return vim.api.nvim_get_current_buf()
end

---@param url string
function M.open_url(url)
    local cmd
    if vim.fn.has("mac") == 1 then
        cmd = { "open", url }
    elseif vim.fn.has("unix") == 1 then
        cmd = { "xdg-open", url }
    elseif vim.fn.has("win32") == 1 then
        cmd = { "cmd", "/c", "start", "", url }
    else
        vim.notify("Cannot open URL: unsupported platform", vim.log.levels.ERROR)
        return
    end

    vim.fn.jobstart(cmd, { detach = true })
end

-- Get the newest version from a list of versions
---@param versions ApiVersion[]?
---@param requirements Requirement[]?
---@param allow_pre boolean?
---@return ApiVersion? newest
---@return ApiVersion? newest_pre
---@return ApiVersion? newest_yanked
function M.get_newest(versions, requirements, allow_pre)
    if not versions or #versions == 0 then
        return nil, nil, nil
    end

    ---@type ApiVersion?
    local newest = nil
    ---@type ApiVersion?
    local newest_pre = nil
    ---@type ApiVersion?
    local newest_yanked = nil

    for _, v in ipairs(versions) do
        if not v.parsed then
            goto continue
        end

        local matches = not requirements or semver.matches_requirements(v.parsed, requirements)
        if not matches then
            goto continue
        end

        local is_pre = v.parsed.pre ~= nil or v.parsed.dev ~= nil

        if v.yanked then
            if not newest_yanked then
                newest_yanked = v
            end
        elseif is_pre then
            if not newest_pre then
                newest_pre = v
            end
            -- If pre-releases are allowed and this is newer, use it
            if allow_pre and not newest then
                newest = v
            end
        else
            if not newest then
                newest = v
            end
        end

        ::continue::
    end

    return newest, newest_pre, newest_yanked
end

-- Normalize package name according to PEP 503
---@param name string
---@return string
function M.normalize_package_name(name)
    return name:lower():gsub("[_.-]+", "-")
end

return M
