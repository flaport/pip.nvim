local actions = require("pip.actions")
local async = require("pip.async")
local command = require("pip.command")
local config = require("pip.config")
local core = require("pip.core")
local highlight = require("pip.highlight")
local popup = require("pip.popup")
local state = require("pip.state")
local util = require("pip.util")

local function attach()
    core.update()
    state.cfg.on_attach(util.current_buf())
end

---@param cfg table?
local function setup(cfg)
    state.cfg = config.build(cfg)

    command.register()
    highlight.define()

    ---@type integer
    local group = vim.api.nvim_create_augroup("Pip", {})
    if state.cfg.autoload then
        if vim.fn.expand("%:t") == "pyproject.toml" then
            attach()
        end

        vim.api.nvim_create_autocmd("BufRead", {
            group = group,
            pattern = "pyproject.toml",
            callback = function(_)
                attach()
            end,
        })
    end

    -- initialize the throttled update function with timeout
    core.inner_throttled_update = async.throttle(core.update, state.cfg.autoupdate_throttle)

    if state.cfg.autoupdate then
        vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "TextChangedP" }, {
            group = group,
            pattern = "pyproject.toml",
            callback = function()
                core.throttled_update(nil, false)
            end,
        })
    end

    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
        group = group,
        pattern = "pyproject.toml",
        callback = function()
            popup.hide()
        end,
    })
end

---@class Pip
local M = {
    ---Setup config and auto commands.
    ---@type fun(cfg: table?)
    setup = setup,

    ---Disable UI elements (virtual text and diagnostics).
    ---@type fun()
    hide = core.hide,
    ---Enable UI elements (virtual text and diagnostics).
    ---@type fun()
    show = core.show,
    ---Enable or disable UI elements (virtual text and diagnostics).
    ---@type fun()
    toggle = core.toggle,
    ---Update data. Optionally specify which buffer to update.
    ---@type fun(buf: integer?)
    update = core.update,
    ---Reload data (clears cache). Optionally specify which buffer to reload.
    ---@type fun(buf: integer?)
    reload = core.reload,

    ---Upgrade the package on the current line.
    ---@type fun()
    upgrade_package = actions.upgrade_package,
    ---Upgrade the packages on the lines visually selected.
    ---@type fun()
    upgrade_packages = actions.upgrade_packages,
    ---Upgrade all packages in the buffer.
    ---@type fun()
    upgrade_all_packages = actions.upgrade_all_packages,

    ---Open the PyPI page of the package on the current line.
    ---@type fun()
    open_pypi = actions.open_pypi,
    ---Open the homepage of the package on the current line.
    ---@type fun()
    open_homepage = actions.open_homepage,
    ---Open the documentation page of the package on the current line.
    ---@type fun()
    open_documentation = actions.open_documentation,
    ---Open the repository page of the package on the current line.
    ---@type fun()
    open_repository = actions.open_repository,

    ---Returns whether there is information to show in a popup.
    ---@type fun(): boolean
    popup_available = popup.available,
    ---Show/hide popup with package versions.
    ---If popup is open, calling this again will focus it.
    ---@type fun()
    show_popup = popup.show,
    ---Same as show_popup() but always show versions.
    ---@type fun()
    show_versions_popup = popup.show_versions,
    ---Focus the popup (jump into the floating window).
    ---Optionally specify the line to jump to inside the popup.
    ---@type fun(line: integer?)
    focus_popup = popup.focus,
    ---Hide the popup.
    ---@type fun()
    hide_popup = popup.hide,
}

return M
