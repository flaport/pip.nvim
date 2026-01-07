local common = require("pip.popup.common")
local versions = require("pip.popup.versions")
local state = require("pip.state")
local util = require("pip.util")

local M = {}

---@return TomlPackage?, PackageInfo?
local function get_package_under_cursor()
    local buf = util.current_buf()
    local cache = state.buf_cache[buf]
    if not cache then
        return nil, nil
    end

    local cursor = vim.api.nvim_win_get_cursor(0)
    local line = cursor[1] - 1 -- 0-indexed

    for key, pkg in pairs(cache.packages) do
        if pkg.lines.s <= line and line < pkg.lines.e then
            return pkg, cache.info[key]
        end
    end

    return nil, nil
end

---@return boolean
function M.available()
    local pkg, _ = get_package_under_cursor()
    return pkg ~= nil
end

function M.show()
    if common.is_open() then
        common.focus()
        return
    end

    M.show_versions()
end

function M.show_versions()
    local pkg, info = get_package_under_cursor()
    if not pkg then
        return
    end

    local api_pkg = state.api_cache[pkg:package()]
    if not api_pkg or not api_pkg.versions then
        vim.notify("pip.nvim: Package information not available", vim.log.levels.WARN)
        return
    end

    versions.show(api_pkg.name, api_pkg.versions)
end

function M.hide()
    common.hide()
end

function M.focus(line)
    if common.is_open() then
        common.focus()
        if line and common.state.win then
            vim.api.nvim_win_set_cursor(common.state.win, { line, 0 })
        end
    end
end

return M
