# Agent Guidelines for Dotfiles Repository

## Build/Test Commands
- **Deploy configs**: `dotter deploy -f` (templates from .dotter/global.toml)
- **Go scripts**: `cd waybar/scripts/{docker-stats,weather-stats} && go run main.go`
- **Init setup**: `sh init.sh` (installs packages, oh-my-zsh, tpm)

## Code Style

**Lua (Neovim):**
- 2-space indentation, spaces not tabs
- Plugin files return table with lazy.nvim spec: `return { "plugin/name", config = function() ... end }`
- LSP configs in `lsp/*.lua`, require via `require("lsp.server_name")`
- Use `vim.keymap.set()` for keymaps, `vim.opt` for options
- Leader key is space: `vim.g.mapleader = " "`

**Go:**
- Standard Go formatting (gofmt)
- Struct-based JSON output for scripts
- Error handling with early returns

**Shell:**
- POSIX-compliant sh scripts
- Platform detection via `uname -s`
- Check command existence before use

## Repository Structure
- `nvim/default/`, `nvim/work/`, `nvim/personal/` are profile variants deployed via dotter
- `.config/nvim/` is the active deployed config (don't edit directly)
- Edit source files in profile directories, then run `dotter deploy -f`
