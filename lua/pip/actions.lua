local state = require("pip.state")
local util = require("pip.util")

local M = {}

---@return TomlPackage?, PackageInfo?, ApiPackage?
local function get_package_under_cursor()
    local buf = util.current_buf()
    local cache = state.buf_cache[buf]
    if not cache then
        return nil, nil, nil
    end

    local cursor = vim.api.nvim_win_get_cursor(0)
    local line = cursor[1] - 1 -- 0-indexed

    for key, pkg in pairs(cache.packages) do
        if pkg.lines.s <= line and line < pkg.lines.e then
            local info = cache.info[key]
            local api_pkg = state.api_cache[pkg:package()]
            return pkg, info, api_pkg
        end
    end

    return nil, nil, nil
end

---@param pkg TomlPackage
---@param version ApiVersion
local function set_version(pkg, version)
    if not pkg.vers then
        vim.notify("pip.nvim: Cannot update package without version specifier", vim.log.levels.WARN)
        return
    end

    local buf = util.current_buf()
    local line = pkg.vers.line
    local col_start = pkg.vers.col.s
    local col_end = pkg.vers.col.e

    -- Get the current line content
    local lines = vim.api.nvim_buf_get_lines(buf, line, line + 1, false)
    if #lines == 0 then
        return
    end

    local current_line = lines[1]

    -- Determine the new version string
    -- Try to preserve the operator if present
    local old_text = pkg.vers.text
    local new_text

    local operator = old_text:match("^([><=!~]+)")
    if operator then
        -- If there's an operator like >=, preserve it
        if operator == "~=" then
            -- Compatible release, update to new major.minor
            new_text = "~=" .. version.num
        elseif operator == ">=" or operator == ">" then
            -- Greater than, keep the operator
            new_text = ">=" .. version.num
        elseif operator == "==" then
            -- Exact match
            new_text = "==" .. version.num
        else
            -- Other operators, default to >=
            new_text = ">=" .. version.num
        end
    else
        -- No operator, assume exact version
        new_text = ">=" .. version.num
    end

    -- Replace the version in the line
    local new_line = current_line:sub(1, col_start) .. new_text .. current_line:sub(col_end + 1)
    vim.api.nvim_buf_set_lines(buf, line, line + 1, false, { new_line })
end

function M.upgrade_package()
    local pkg, info, api_pkg = get_package_under_cursor()
    if not pkg or not info then
        vim.notify("pip.nvim: No package under cursor", vim.log.levels.WARN)
        return
    end

    if not info.vers_upgrade then
        vim.notify("pip.nvim: Package is already at latest version", vim.log.levels.INFO)
        return
    end

    set_version(pkg, info.vers_upgrade)
end

function M.upgrade_packages()
    local buf = util.current_buf()
    local mode = vim.api.nvim_get_mode().mode
    if mode ~= "v" and mode ~= "V" then
        vim.notify("pip.nvim: Visual selection required", vim.log.levels.WARN)
        return
    end

    local start_line = vim.fn.line("v") - 1
    local end_line = vim.fn.line(".") - 1
    if start_line > end_line then
        start_line, end_line = end_line, start_line
    end

    local cache = state.buf_cache[buf]
    if not cache then
        return
    end

    local upgraded = 0
    for key, pkg in pairs(cache.packages) do
        if pkg.lines.s >= start_line and pkg.lines.e <= end_line + 1 then
            local info = cache.info[key]
            if info and info.vers_upgrade then
                set_version(pkg, info.vers_upgrade)
                upgraded = upgraded + 1
            end
        end
    end

    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
    vim.notify(string.format("pip.nvim: Upgraded %d packages", upgraded), vim.log.levels.INFO)
end

function M.upgrade_all_packages()
    local buf = util.current_buf()
    local cache = state.buf_cache[buf]
    if not cache then
        return
    end

    local upgraded = 0
    for key, pkg in pairs(cache.packages) do
        local info = cache.info[key]
        if info and info.vers_upgrade then
            set_version(pkg, info.vers_upgrade)
            upgraded = upgraded + 1
        end
    end

    vim.notify(string.format("pip.nvim: Upgraded %d packages", upgraded), vim.log.levels.INFO)
end

function M.open_pypi()
    local pkg, _, _ = get_package_under_cursor()
    if not pkg then
        vim.notify("pip.nvim: No package under cursor", vim.log.levels.WARN)
        return
    end

    local url = "https://pypi.org/project/" .. pkg:package()
    util.open_url(url)
end

function M.open_homepage()
    local pkg, _, api_pkg = get_package_under_cursor()
    if not pkg then
        vim.notify("pip.nvim: No package under cursor", vim.log.levels.WARN)
        return
    end

    if api_pkg and api_pkg.homepage then
        util.open_url(api_pkg.homepage)
    else
        -- Fall back to PyPI page
        local url = "https://pypi.org/project/" .. pkg:package()
        util.open_url(url)
    end
end

function M.open_documentation()
    local pkg, _, api_pkg = get_package_under_cursor()
    if not pkg then
        vim.notify("pip.nvim: No package under cursor", vim.log.levels.WARN)
        return
    end

    if api_pkg and api_pkg.documentation then
        util.open_url(api_pkg.documentation)
    else
        -- Fall back to PyPI page
        local url = "https://pypi.org/project/" .. pkg:package()
        util.open_url(url)
    end
end

function M.open_repository()
    local pkg, _, api_pkg = get_package_under_cursor()
    if not pkg then
        vim.notify("pip.nvim: No package under cursor", vim.log.levels.WARN)
        return
    end

    if api_pkg and api_pkg.repository then
        util.open_url(api_pkg.repository)
    else
        -- Fall back to PyPI page
        local url = "https://pypi.org/project/" .. pkg:package()
        util.open_url(url)
    end
end

return M
