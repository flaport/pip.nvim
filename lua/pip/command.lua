local M = {}

function M.register()
    vim.api.nvim_create_user_command("Pip", function(opts)
        local args = opts.fargs

        if #args == 0 then
            vim.notify("pip.nvim: No subcommand provided", vim.log.levels.ERROR)
            return
        end

        local subcommand = args[1]

        if subcommand == "show" then
            require("pip").show()
        elseif subcommand == "hide" then
            require("pip").hide()
        elseif subcommand == "toggle" then
            require("pip").toggle()
        elseif subcommand == "update" then
            require("pip").update()
        elseif subcommand == "reload" then
            require("pip").reload()
        elseif subcommand == "upgrade" then
            require("pip").upgrade_package()
        elseif subcommand == "upgrade_all" then
            require("pip").upgrade_all_packages()
        elseif subcommand == "open_pypi" then
            require("pip").open_pypi()
        elseif subcommand == "open_homepage" then
            require("pip").open_homepage()
        elseif subcommand == "open_documentation" then
            require("pip").open_documentation()
        elseif subcommand == "open_repository" then
            require("pip").open_repository()
        elseif subcommand == "show_popup" then
            require("pip").show_popup()
        elseif subcommand == "show_versions_popup" then
            require("pip").show_versions_popup()
        else
            vim.notify("pip.nvim: Unknown subcommand: " .. subcommand, vim.log.levels.ERROR)
        end
    end, {
        nargs = "*",
        complete = function(_, line, _)
            local subcommands = {
                "show",
                "hide",
                "toggle",
                "update",
                "reload",
                "upgrade",
                "upgrade_all",
                "open_pypi",
                "open_homepage",
                "open_documentation",
                "open_repository",
                "show_popup",
                "show_versions_popup",
            }

            local args = vim.split(line, "%s+")
            if #args <= 2 then
                return vim.tbl_filter(function(cmd)
                    return cmd:find(args[2] or "", 1, true) == 1
                end, subcommands)
            end

            return {}
        end,
    })
end

return M
