local common = require("pip.popup.common")
local state = require("pip.state")

local M = {}

---@param package_name string
---@param versions ApiVersion[]
---@param on_select fun(version: ApiVersion)?
function M.show(package_name, versions, on_select)
    local lines = {}
    local highlights = {}

    for i, v in ipairs(versions) do
        local text
        local hl_group

        if v.yanked then
            text = string.format(state.cfg.popup.text.yanked, v.num)
            hl_group = state.cfg.popup.highlight.yanked
        elseif v.parsed and (v.parsed.pre or v.parsed.dev) then
            text = string.format(state.cfg.popup.text.prerelease, v.num)
            hl_group = state.cfg.popup.highlight.prerelease
        else
            text = string.format(state.cfg.popup.text.version, v.num)
            hl_group = state.cfg.popup.highlight.version
        end

        table.insert(lines, text)
        table.insert(highlights, {
            line = i - 1,
            col_start = 0,
            col_end = -1,
            hl_group = hl_group,
        })
    end

    local title = string.format(state.cfg.popup.text.title, package_name)

    common.show_popup(lines, highlights, title)
    common.state.package_name = package_name
    common.state.versions = versions

    -- Set up select keymaps
    if on_select and common.state.buf then
        for _, key in ipairs(state.cfg.popup.keys.select) do
            vim.api.nvim_buf_set_keymap(common.state.buf, "n", key, "", {
                callback = function()
                    local cursor = vim.api.nvim_win_get_cursor(common.state.win)
                    local line_nr = cursor[1]
                    local version = versions[line_nr]
                    if version then
                        common.hide()
                        on_select(version)
                    end
                end,
                noremap = true,
                silent = true,
            })
        end
    end
end

return M
