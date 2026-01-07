local M = {}

---@class Config
---@field autoload boolean
---@field autoupdate boolean
---@field autoupdate_throttle integer
---@field loading_indicator boolean
---@field enable_update_available_warning boolean
---@field on_attach fun(bufnr: integer)
---@field text TextConfig
---@field highlight HighlightConfig
---@field diagnostic DiagnosticConfig
---@field popup PopupConfig

---@class TextConfig
---@field loading string
---@field version string
---@field prerelease string
---@field yanked string
---@field nomatch string
---@field upgrade string
---@field error string

---@class HighlightConfig
---@field loading string
---@field version string
---@field prerelease string
---@field yanked string
---@field nomatch string
---@field upgrade string
---@field error string

---@class DiagnosticConfig
---@field section_invalid string
---@field section_dup string
---@field section_dup_orig string
---@field pkg_dup string
---@field pkg_dup_orig string
---@field pkg_novers string
---@field pkg_error_fetching string
---@field pkg_name_case string
---@field vers_upgrade string
---@field vers_pre string
---@field vers_yanked string
---@field vers_nomatch string

---@class PopupConfig
---@field autofocus boolean
---@field border string|string[]
---@field max_height integer
---@field min_width integer
---@field padding integer
---@field text PopupTextConfig
---@field highlight PopupHighlightConfig
---@field keys PopupKeyConfig

---@class PopupTextConfig
---@field title string
---@field version string
---@field prerelease string
---@field yanked string

---@class PopupHighlightConfig
---@field title string
---@field version string
---@field prerelease string
---@field yanked string

---@class PopupKeyConfig
---@field hide string[]
---@field select string[]
---@field copy_value string[]

---@type Config
local DEFAULT_CONFIG = {
    autoload = true,
    autoupdate = true,
    autoupdate_throttle = 250,
    loading_indicator = true,
    enable_update_available_warning = true,
    on_attach = function(_) end,
    text = {
        loading = "   Loading",
        version = "   %s",
        prerelease = "   %s",
        yanked = "   %s yanked",
        nomatch = "   No match",
        upgrade = "   %s",
        error = "   Error fetching package",
    },
    highlight = {
        loading = "PipNvimLoading",
        version = "PipNvimVersion",
        prerelease = "PipNvimPreRelease",
        yanked = "PipNvimYanked",
        nomatch = "PipNvimNoMatch",
        upgrade = "PipNvimUpgrade",
        error = "PipNvimError",
    },
    diagnostic = {
        section_invalid = "Invalid dependency section",
        section_dup = "Duplicate dependency section",
        section_dup_orig = "Original dependency section is defined here",
        pkg_dup = "Duplicate package entry",
        pkg_dup_orig = "Original package entry is defined here",
        pkg_novers = "Missing version requirement",
        pkg_error_fetching = "Error fetching package",
        pkg_name_case = "Incorrect package name, perhaps you meant `%s`",
        vers_upgrade = "There is an upgrade available",
        vers_pre = "Requirement only matches a pre-release version",
        vers_yanked = "Requirement only matches a yanked version",
        vers_nomatch = "Requirement doesn't match a version",
    },
    popup = {
        autofocus = false,
        border = "rounded",
        max_height = 30,
        min_width = 20,
        padding = 1,
        text = {
            title = " %s",
            version = "  %s",
            prerelease = " %s",
            yanked = " %s",
        },
        highlight = {
            title = "PipNvimPopupTitle",
            version = "PipNvimPopupVersion",
            prerelease = "PipNvimPopupPreRelease",
            yanked = "PipNvimPopupYanked",
        },
        keys = {
            hide = { "q", "<esc>" },
            select = { "<cr>" },
            copy_value = { "yy" },
        },
    },
}

---@param s string
---@param ... any
local function warn(s, ...)
    vim.notify(s:format(...), vim.log.levels.WARN, { title = "pip.nvim" })
end

---@param default table
---@param user table?
---@return table
local function merge_config(default, user)
    if not user then
        return vim.deepcopy(default)
    end

    local result = vim.deepcopy(default)
    for key, value in pairs(user) do
        if type(value) == "table" and type(result[key]) == "table" then
            result[key] = merge_config(result[key], value)
        elseif result[key] ~= nil then
            result[key] = value
        else
            warn("Ignoring invalid config key `%s`", key)
        end
    end
    return result
end

---@param user_config table<string,any>?
---@return Config
function M.build(user_config)
    user_config = user_config or {}
    local user_config_type = type(user_config)
    if user_config_type ~= "table" then
        warn("Expected config of type `table` found `%s`", user_config_type)
        user_config = {}
    end

    return merge_config(DEFAULT_CONFIG, user_config)
end

return M
