local M = {}

function M.define()
    -- Virtual text highlights
    vim.api.nvim_set_hl(0, "PipNvimLoading", { default = true, link = "Comment" })
    vim.api.nvim_set_hl(0, "PipNvimVersion", { default = true, link = "String" })
    vim.api.nvim_set_hl(0, "PipNvimPreRelease", { default = true, link = "Constant" })
    vim.api.nvim_set_hl(0, "PipNvimYanked", { default = true, link = "Error" })
    vim.api.nvim_set_hl(0, "PipNvimNoMatch", { default = true, link = "Error" })
    vim.api.nvim_set_hl(0, "PipNvimUpgrade", { default = true, link = "DiagnosticVirtualTextWarn" })
    vim.api.nvim_set_hl(0, "PipNvimError", { default = true, link = "Error" })

    -- Popup highlights
    vim.api.nvim_set_hl(0, "PipNvimPopupTitle", { default = true, link = "Title" })
    vim.api.nvim_set_hl(0, "PipNvimPopupVersion", { default = true, link = "String" })
    vim.api.nvim_set_hl(0, "PipNvimPopupPreRelease", { default = true, link = "Constant" })
    vim.api.nvim_set_hl(0, "PipNvimPopupYanked", { default = true, link = "Error" })
    vim.api.nvim_set_hl(0, "PipNvimPopupLabel", { default = true, link = "Identifier" })
    vim.api.nvim_set_hl(0, "PipNvimPopupValue", { default = true, link = "String" })
    vim.api.nvim_set_hl(0, "PipNvimPopupUrl", { default = true, link = "Underlined" })
end

return M
