local M = {}

function M.define()
    -- Virtual text highlights (same as crates.nvim)
    vim.api.nvim_set_hl(0, "PipNvimLoading", { default = true, link = "DiagnosticVirtualTextInfo" })
    vim.api.nvim_set_hl(0, "PipNvimVersion", { default = true, link = "DiagnosticVirtualTextInfo" })
    vim.api.nvim_set_hl(0, "PipNvimPreRelease", { default = true, link = "DiagnosticVirtualTextError" })
    vim.api.nvim_set_hl(0, "PipNvimYanked", { default = true, link = "DiagnosticVirtualTextError" })
    vim.api.nvim_set_hl(0, "PipNvimNoMatch", { default = true, link = "DiagnosticVirtualTextError" })
    vim.api.nvim_set_hl(0, "PipNvimUpgrade", { default = true, link = "DiagnosticVirtualTextWarn" })
    vim.api.nvim_set_hl(0, "PipNvimError", { default = true, link = "DiagnosticVirtualTextError" })

    -- Popup highlights (same as crates.nvim)
    vim.api.nvim_set_hl(0, "PipNvimPopupTitle", { default = true, link = "Title" })
    vim.api.nvim_set_hl(0, "PipNvimPopupVersion", { default = true, link = "None" })
    vim.api.nvim_set_hl(0, "PipNvimPopupPreRelease", { default = true, link = "DiagnosticVirtualTextWarn" })
    vim.api.nvim_set_hl(0, "PipNvimPopupYanked", { default = true, link = "DiagnosticVirtualTextError" })
    vim.api.nvim_set_hl(0, "PipNvimPopupLabel", { default = true, link = "Identifier" })
    vim.api.nvim_set_hl(0, "PipNvimPopupValue", { default = true, link = "String" })
    vim.api.nvim_set_hl(0, "PipNvimPopupUrl", { default = true, link = "Underlined" })
end

return M
