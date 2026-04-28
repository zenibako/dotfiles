# Agent Guidelines for Dotfiles Repository

## Build/Deploy Commands
- **Deploy configs**: `dotter deploy -f` (templates from .dotter/global.toml, uses `depends` for profile inheritance)
- **Go scripts**: `cd waybar/scripts/{docker-stats,weather-stats} && go run main.go`
- **Init setup**: `sh init.sh` (cross-distro package install, oh-my-zsh, tpm, carapace, zoxide, atuin, starship, dotter deploy)
- **OpenCode plugins**: `cd ~/.config/opencode && npm install`

## Version Control
- Config in `jj/config.toml`
- **Merge tool**: `jj-diffconflicts` via nvim (`merge-tools.diffconflicts`)
- **GPG Signing**: ALL commits must be GPG signed. Never bypass signing.
- **Agent Commits**: Agents may commit directly when signing works non-interactively. If signing would block on a GPG/pinentry prompt, stop and prompt the user to make the commit manually with `jj commit -m "message"` so the GPG agent cache is warmed first.

## Repository Structure
- Profiles: `nvim/{default,work,personal}` deployed via dotter (don't edit `~/.config/nvim` directly!)
- Packages: Select ONE profile (personal/work), ONE platform (mac/linux), ONE theme (monokai/nightowl/tokyonight)
- Profile inheritance: `work` and `personal` depend on `default` via `depends = ["default"]`
- Secrets: Never commit `local.toml` (use `local.toml.example` as template)

## Platform-Specific Init

- **`./init.sh`** bootstraps a new machine: cross-distro package install (from `packages-<distro>.txt`), oh-my-zsh, tpm, zsh-completions, carapace (via Gemfury on RPM distros or direct binary), zoxide, atuin, starship, then `dotter deploy -f`
- Distro detection: reads `/etc/os-release` and selects the appropriate `packages-<ID>.txt`
- macOS uses Homebrew (`Brewfile`) instead of package lists
- zshrc guards tool-specific `eval "$(...)"` with `(( ${+commands[tool]} ))` to prevent errors when tools are not yet installed
- zshenv is POSIX-compatible for non-interactive shells (MCP servers); zshrc is zsh-only

## Shell Design Conventions
- `~/.zshenv`: POSIX-compatible env loading for ALL shells (non-interactive safe)
- `~/.zshrc`: interactive-only, zsh-specific syntax (arithmetic expansion, `autoload`, `zstyle`)
- `~/.bashrc` (if any): NEVER source `~/.zshrc` from bash — they are incompatible
- Tools with init scripts (`zoxide init`, `atuin init`, `starship init`) must be guarded with `command -v` or `(( ${+commands[...]} ))` checks to avoid errors on missing binaries
