local state = require("pip.state")

local M = {}

---@class PopupState
---@field win integer?
---@field buf integer?
---@field package_name string?
---@field versions ApiVersion[]?

---@type PopupState
M.state = {
    win = nil,
    buf = nil,
    package_name = nil,
    versions = nil,
}

---@param lines string[]
---@param highlights {line: integer, col_start: integer, col_end: integer, hl_group: string}[]
---@param title string?
function M.show_popup(lines, highlights, title)
    M.hide()

    -- Calculate dimensions
    local width = state.cfg.popup.min_width
    for _, line in ipairs(lines) do
        width = math.max(width, vim.fn.strdisplaywidth(line) + state.cfg.popup.padding * 2)
    end
    local height = math.min(#lines, state.cfg.popup.max_height)

    -- Create buffer
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })

    -- Apply highlights
    for _, hl in ipairs(highlights) do
        vim.api.nvim_buf_add_highlight(buf, -1, hl.hl_group, hl.line, hl.col_start, hl.col_end)
    end

    -- Create window
    local win_opts = {
        relative = "cursor",
        row = 1,
        col = 0,
        width = width,
        height = height,
        style = "minimal",
        border = state.cfg.popup.border,
        title = title,
        title_pos = title and "center" or nil,
    }

    local win = vim.api.nvim_open_win(buf, state.cfg.popup.autofocus, win_opts)
    vim.api.nvim_set_option_value("cursorline", true, { win = win })
    vim.api.nvim_set_option_value("wrap", false, { win = win })

    M.state.win = win
    M.state.buf = buf

    -- Set up keymaps
    for _, key in ipairs(state.cfg.popup.keys.hide) do
        vim.api.nvim_buf_set_keymap(buf, "n", key, "", {
            callback = function()
                M.hide()
            end,
            noremap = true,
            silent = true,
        })
    end

    for _, key in ipairs(state.cfg.popup.keys.copy_value) do
        vim.api.nvim_buf_set_keymap(buf, "n", key, "", {
            callback = function()
                local line = vim.api.nvim_get_current_line()
                local value = line:match("^%s*(.-)%s*$")
                if value and value ~= "" then
                    vim.fn.setreg("+", value)
                    vim.notify("Copied: " .. value)
                end
            end,
            noremap = true,
            silent = true,
        })
    end

    return win, buf
end

function M.hide()
    if M.state.win and vim.api.nvim_win_is_valid(M.state.win) then
        vim.api.nvim_win_close(M.state.win, true)
    end
    M.state.win = nil
    M.state.buf = nil
    M.state.package_name = nil
    M.state.versions = nil
end

---@return boolean
function M.is_open()
    return M.state.win ~= nil and vim.api.nvim_win_is_valid(M.state.win)
end

function M.focus()
    if M.is_open() then
        vim.api.nvim_set_current_win(M.state.win)
    end
end

return M
