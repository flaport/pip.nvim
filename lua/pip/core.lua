local api = require("pip.api")
local async = require("pip.async")
local diagnostic = require("pip.diagnostic")
local state = require("pip.state")
local toml = require("pip.toml")
local ui = require("pip.ui")
local util = require("pip.util")

---@class Core
---@field throttled_updates table<integer,fun()[]>
---@field inner_throttled_update fun(buf: integer?, reload: boolean?)
local M = {
    throttled_updates = {},
}

---@type fun(package_name: string)
M.load_package = async.wrap(function(package_name)
    local pkg, cancelled = api.fetch_package(package_name)
    if cancelled then
        return
    end

    if pkg and pkg.versions and #pkg.versions > 0 then
        state.api_cache[pkg.name] = pkg
    end

    for buf, cache in pairs(state.buf_cache) do
        -- update package in all dependency sections
        for k, p in pairs(cache.packages) do
            local normalized_name = util.normalize_package_name(p:package())
            local normalized_fetch = util.normalize_package_name(package_name)

            if normalized_name == normalized_fetch and vim.api.nvim_buf_is_loaded(buf) then
                local p_diagnostics = {}
                local info = diagnostic.process_api_package(p, pkg, p_diagnostics)
                cache.info[k] = info
                vim.list_extend(cache.diagnostics, p_diagnostics)

                ui.display_package_info(buf, { info })
                ui.display_diagnostics(buf, {}, p_diagnostics)
            end
        end
    end
end)

---@param buf integer?
---@param reload boolean?
local function update(buf, reload)
    buf = buf or util.current_buf()

    if reload then
        state:clear_cache()
        api.cancel_jobs()
    end

    local sections, packages = toml.parse_packages(buf)
    local package_cache, diagnostics = diagnostic.process_packages(sections, packages)
    ---@type BufCache
    local cache = {
        packages = package_cache,
        info = {},
        diagnostics = diagnostics,
    }
    state.buf_cache[buf] = cache

    local packages_info = {}
    local packages_loading = {}
    local custom_diagnostics = {}

    for k, p in pairs(package_cache) do
        local api_pkg = state.api_cache[p:package()]
        if not reload and api_pkg then
            local info = diagnostic.process_api_package(p, api_pkg, custom_diagnostics)
            cache.info[k] = info

            table.insert(packages_info, info)
        else
            if state.cfg.loading_indicator then
                table.insert(packages_loading, p)
            end

            M.load_package(p:package())
        end
    end

    ui.clear(buf)
    ui.display_package_info(buf, packages_info)
    ui.display_loading(buf, packages_loading)
    ui.display_diagnostics(buf, diagnostics, custom_diagnostics)

    vim.list_extend(cache.diagnostics, custom_diagnostics)

    local callbacks = M.throttled_updates[buf]
    if callbacks then
        for _, callback in ipairs(callbacks) do
            callback()
        end
    end
    M.throttled_updates[buf] = nil
end

---@param buf integer?
---@param reload boolean?
function M.throttled_update(buf, reload)
    buf = buf or util.current_buf()
    local existing = M.throttled_updates[buf]
    if not existing then
        M.throttled_updates[buf] = {}
    end

    M.inner_throttled_update(buf, reload)
end

---@param buf integer
---@return boolean
function M.await_throttled_update_if_any(buf)
    local existing = M.throttled_updates[buf]
    if not existing then
        return false
    end

    ---@param resolve fun()
    coroutine.yield(function(resolve)
        table.insert(existing, resolve)
    end)

    return true
end

function M.hide()
    state.visible = false
    for b, _ in pairs(state.buf_cache) do
        ui.clear(b)
    end
end

function M.show()
    state.visible = true

    -- make sure we update the current buffer (first)
    local buf = util.current_buf()
    update(buf, false)

    for b, _ in pairs(state.buf_cache) do
        if b ~= buf then
            update(b, false)
        end
    end
end

function M.toggle()
    if state.visible then
        M.hide()
    else
        M.show()
    end
end

---@param buf integer?
function M.update(buf)
    update(buf, false)
end

---@param buf integer?
function M.reload(buf)
    update(buf, true)
end

return M
