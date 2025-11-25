# Agent Guidelines for Dotfiles Repository

## Build/Deploy Commands
- **Deploy configs**: `dotter deploy -f` (templates from .dotter/global.toml, uses `depends` for profile inheritance)
- **Go scripts**: `cd waybar/scripts/{docker-stats,weather-stats} && go run main.go`
- **Init setup**: `sh init.sh` (installs packages, oh-my-zsh, tpm)
- **OpenCode plugins**: `cd ~/.config/opencode && npm install`

## Version Control
- Config in `jj/config.toml`
- **Merge tool**: `jj-diffconflicts` via nvim (`merge-tools.diffconflicts`)

## Repository Structure
- Profiles: `nvim/{default,work,personal}` deployed via dotter (don't edit `~/.config/nvim` directly!)
- Packages: Select ONE profile (personal/work), ONE platform (mac/linux), ONE theme (monokai/nightowl/tokyonight)
- Profile inheritance: `work` and `personal` depend on `default` via `depends = ["default"]`
- Secrets: Never commit `local.toml` (use `local.toml.example` as template)
