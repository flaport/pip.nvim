local M = {}

function M.check()
    vim.health.start("pip.nvim")

    -- Check for uv
    local uv_path = vim.fn.exepath("uv")
    if uv_path ~= "" then
        vim.health.ok("uv found: " .. uv_path)

        -- Check uv version
        local handle = io.popen("uv --version 2>&1")
        if handle then
            local result = handle:read("*a")
            handle:close()
            if result then
                result = result:gsub("%s+$", "")
                vim.health.ok("uv version: " .. result)
            end
        end
    else
        vim.health.error(
            "uv not found in PATH",
            {
                "Install uv: https://docs.astral.sh/uv/getting-started/installation/",
                "Make sure uv is in your PATH",
            }
        )
    end

    -- Check Neovim version
    local nvim_version = vim.version()
    if nvim_version.major > 0 or (nvim_version.major == 0 and nvim_version.minor >= 8) then
        vim.health.ok(string.format("Neovim version: %d.%d.%d", nvim_version.major, nvim_version.minor, nvim_version.patch))
    else
        vim.health.error(
            string.format("Neovim version %d.%d.%d is too old", nvim_version.major, nvim_version.minor, nvim_version.patch),
            { "pip.nvim requires Neovim 0.8.0 or later" }
        )
    end
end

return M
