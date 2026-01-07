local state = require("pip.state")
local types = require("pip.types")
local MatchKind = types.MatchKind

---@class Ui
---@field state table<integer,BufUiState>
local M = {
    state = {},
}

---@class BufUiState
---@field custom_diagnostics vim.Diagnostic[]
---@field diagnostics vim.Diagnostic[]
---@field line_state table<integer,LineState>

---@enum LineState
local LineState = {
    LOADING = 1,
    UPDATE = 2,
}

---@param buf integer
---@return BufUiState
function M.get_or_init(buf)
    local buf_state = M.state[buf] or {
        custom_diagnostics = {},
        diagnostics = {},
        line_state = {},
    }
    M.state[buf] = buf_state
    return buf_state
end

---@type integer
local CUSTOM_NS = vim.api.nvim_create_namespace("pip.nvim")
---@type integer
local DIAGNOSTIC_NS = vim.api.nvim_create_namespace("pip.nvim.diagnostic")

---@param buf integer
---@param d PipDiagnostic
---@return vim.Diagnostic
local function to_vim_diagnostic(buf, d)
    ---@type vim.Diagnostic
    return {
        bufnr = buf,
        lnum = d.lnum,
        end_lnum = d.end_lnum,
        col = d.col,
        end_col = d.end_col,
        severity = d.severity,
        message = d:message(state.cfg.diagnostic[d.kind]),
        source = "pip",
    }
end

---@param buf integer
---@param diagnostics PipDiagnostic[]
---@param custom_diagnostics PipDiagnostic[]
function M.display_diagnostics(buf, diagnostics, custom_diagnostics)
    if not state.visible then
        return
    end

    local buf_state = M.get_or_init(buf)
    for _, d in ipairs(diagnostics) do
        local vim_diagnostic = to_vim_diagnostic(buf, d)
        table.insert(buf_state.diagnostics, vim_diagnostic)
    end
    for _, d in ipairs(custom_diagnostics) do
        local vim_diagnostic = to_vim_diagnostic(buf, d)
        table.insert(buf_state.custom_diagnostics, vim_diagnostic)
    end

    vim.diagnostic.set(DIAGNOSTIC_NS, buf, buf_state.diagnostics, {})
    vim.diagnostic.set(CUSTOM_NS, buf, buf_state.custom_diagnostics, { virtual_text = false })
end

---@param buf integer
---@param info PackageInfo
---@return {text: string, hl: string}[]
local function build_virt_text(buf, info)
    local virt_text = {}
    if info.vers_match then
        table.insert(virt_text, {
            text = string.format(state.cfg.text[info.match_kind], info.vers_match.num),
            hl = state.cfg.highlight[info.match_kind],
        })
    elseif info.match_kind == MatchKind.NOMATCH then
        table.insert(virt_text, {
            text = state.cfg.text.nomatch,
            hl = state.cfg.highlight.nomatch,
        })
    end
    if info.vers_upgrade then
        table.insert(virt_text, {
            text = string.format(state.cfg.text.upgrade, info.vers_upgrade.num),
            hl = state.cfg.highlight.upgrade,
        })
    end

    if not (info.vers_match or info.vers_upgrade) then
        table.insert(virt_text, {
            text = state.cfg.text.error,
            hl = state.cfg.highlight.error,
        })
    end

    return virt_text
end

---@param buf integer
---@param infos PackageInfo[]
function M.display_package_info(buf, infos)
    if not state.visible then
        return
    end

    -- Group infos by section (using lines to identify sections)
    -- Find the max line length for each group of consecutive lines
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

    -- Build virt_text for each info and track line lengths
    ---@type table<integer, {info: PackageInfo, virt_text: {text: string, hl: string}[]}>
    local info_data = {}
    for _, info in ipairs(infos) do
        info_data[info.vers_line] = {
            info = info,
            virt_text = build_virt_text(buf, info),
        }
    end

    -- Find max line length across all package lines in this buffer
    local max_col = 0
    for line_nr, _ in pairs(info_data) do
        local line = lines[line_nr + 1] or ""
        local line_len = vim.fn.strdisplaywidth(line)
        if line_len > max_col then
            max_col = line_len
        end
    end

    -- Display with aligned virtual text
    for line_nr, data in pairs(info_data) do
        local line = lines[line_nr + 1] or ""
        local line_len = vim.fn.strdisplaywidth(line)
        local padding = string.rep(" ", max_col - line_len)

        local virt_text = {}
        -- Add padding first
        if #padding > 0 then
            table.insert(virt_text, { padding, "Normal" })
        end
        -- Add the actual content
        for _, item in ipairs(data.virt_text) do
            table.insert(virt_text, { item.text, item.hl })
        end

        vim.api.nvim_buf_clear_namespace(buf, CUSTOM_NS, data.info.lines.s, data.info.lines.e)
        vim.api.nvim_buf_set_extmark(buf, CUSTOM_NS, line_nr, -1, {
            virt_text = virt_text,
            virt_text_pos = "eol",
            hl_mode = "combine",
        })
    end
end

---@param buf integer
---@param packages TomlPackage[]
function M.display_loading(buf, packages)
    if not state.visible then
        return
    end

    local buf_state = M.get_or_init(buf)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

    -- Find max line length across all loading package lines
    local max_col = 0
    local pkg_lines = {}
    for _, pkg in ipairs(packages) do
        local vers_line = pkg.vers and pkg.vers.line or pkg.lines.s
        pkg_lines[vers_line] = pkg
        local line = lines[vers_line + 1] or ""
        local line_len = vim.fn.strdisplaywidth(line)
        if line_len > max_col then
            max_col = line_len
        end
    end

    -- Display with aligned virtual text
    for vers_line, pkg in pairs(pkg_lines) do
        buf_state.line_state[vers_line] = LineState.LOADING

        local line = lines[vers_line + 1] or ""
        local line_len = vim.fn.strdisplaywidth(line)
        local padding = string.rep(" ", max_col - line_len)

        local virt_text = {}
        if #padding > 0 then
            table.insert(virt_text, { padding, "Normal" })
        end
        table.insert(virt_text, { state.cfg.text.loading, state.cfg.highlight.loading })

        vim.api.nvim_buf_set_extmark(buf, CUSTOM_NS, vers_line, -1, {
            virt_text = virt_text,
            virt_text_pos = "eol",
            hl_mode = "combine",
        })
    end
end

---@param buf integer
function M.clear(buf)
    M.state[buf] = nil

    vim.api.nvim_buf_clear_namespace(buf, CUSTOM_NS, 0, -1)
    vim.diagnostic.reset(CUSTOM_NS, buf)
    vim.diagnostic.reset(DIAGNOSTIC_NS, buf)
end

return M
