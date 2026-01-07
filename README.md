# pip.nvim

A Neovim plugin to help manage Python dependencies in `pyproject.toml` files. Inspired by [crates.nvim](https://github.com/Saecki/crates.nvim).

## Features

- Display latest package versions as virtual text
- Show upgrade available warnings (when requirement doesn't match latest)
- Diagnostics for version mismatches and errors
- Open PyPI pages for packages

## Requirements

- Neovim >= 0.8.0
- `curl` (for fetching package info from PyPI)
- A [Nerd Font](https://www.nerdfonts.com/) (for icons)

## Installation

### lazy.nvim

```lua
{
    "flaport/pip.nvim",
    event = "BufRead pyproject.toml",
    config = function()
        require("pip").setup()
    end,
}
```

## Configuration

```lua
require("pip").setup({
    autoload = true,
    autoupdate = true,
    autoupdate_throttle = 250,
    loading_indicator = true,
    enable_update_available_warning = true,
    on_attach = function(bufnr) end,

    text = {
        loading = " Loading",
        version = " %s",
        prerelease = " %s",
        yanked = " %s (yanked)",
        nomatch = " No match",
        upgrade = " %s",
        error = " Error fetching package",
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
})
```

## Commands

| Command | Description |
|---------|-------------|
| `:Pip show` | Show virtual text and diagnostics |
| `:Pip hide` | Hide virtual text and diagnostics |
| `:Pip toggle` | Toggle virtual text and diagnostics |
| `:Pip update` | Update package information |
| `:Pip reload` | Reload package information (clears cache) |
| `:Pip upgrade` | Upgrade package on current line |
| `:Pip upgrade_all` | Upgrade all packages in buffer |
| `:Pip open_pypi` | Open PyPI page for package under cursor |

## Lua API

```lua
local pip = require("pip")

pip.show()
pip.hide()
pip.toggle()
pip.update()
pip.reload()
pip.upgrade_package()
pip.upgrade_all_packages()
pip.open_pypi()
```

## Supported pyproject.toml sections

- `[project]` with `dependencies = [...]`
- `[project.dependencies]`
- `[project.optional-dependencies]`
- `[project.optional-dependencies.<group>]`
- `[dependency-groups.<group>]` (PEP 735)
- `[tool.uv.dev-dependencies]`

## Health check

Run `:checkhealth pip` to verify your setup.

## Note

This plugin was 100% AI-generated using crates.nvim as a reference. It's not feature
complete but it does what I need it to do.

## License

MIT
