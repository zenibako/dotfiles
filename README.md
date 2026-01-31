# dotfiles

Personal configuration files for various development tools and shell environments.

## What's Included

- **Shell**: Zsh with Oh My Zsh, Fish, Nushell
- **Terminal**: Alacritty, Ghostty, Wezterm configurations
- **Multiplexer**: Tmux with custom theme support
- **Editor**: Neovim with LSP, plugins, and profile variants (default, work, personal)
- **CLI Tools**: Starship prompt, Atuin (shell history), Carapace (completions), Jujutsu (VCS), iamb (Matrix client)
- **Package Managers**: pnpm, npm, yarn support with shared configuration
- **OpenCode**: Custom commands and plugins for OpenCode AI assistant
- **Claude**: MCP server configurations
- **Window Management**: AeroSpace (macOS), Hyprland (Linux)

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/zenibako/dotfiles.git
cd dotfiles
```

### 2. Create Local Configuration

Copy the example local config and customize it:

```bash
cp .dotter/local.toml.example .dotter/local.toml
```

Edit `.dotter/local.toml` to set your:
- Name and email
- Profile selection (default, work, or personal)
- Color scheme (monokai, nightowl, or tokyonight)
- Platform (mac or linux)
- MCP server settings
- API tokens and credentials

### 3. Run the Initialization Script

```bash
sh init.sh
```

This script will:
- Install Homebrew (macOS) or packages via your Linux package manager
- Install Oh My Zsh
- Install Tmux Plugin Manager (tpm)
- Deploy configurations using dotter

## Configuration Management

This repository uses [dotter](https://github.com/SuperCuber/dotter) for templating and deployment.

### Profiles

Three Neovim profiles are available:
- **default**: Basic setup with common LSPs and plugins
- **work**: Includes Salesforce-specific tooling and enterprise configs
- **personal**: Personal projects setup

Select your profile in `.dotter/local.toml`:
```toml
includes = ["default", "monokai", "mac"]  # or "work", "personal"
```

### Deploy Configuration Changes

After editing source files, deploy them:

```bash
dotter deploy -f
```

**Note**: Always edit files in the repository root (e.g., `nvim/default/`), not in `~/.config/`. The `~/.config/` directory contains deployed configs that will be overwritten.

## Platform Support

- **macOS**: Full support via Homebrew
- **Linux**: Supports Arch (pacman), Debian/Ubuntu (apt), Fedora (dnf), CentOS/RHEL (yum), openSUSE (zypper), and Alpine (apk)

## Package Managers

### pnpm

pnpm is configured as the recommended Node.js package manager with:
- Global store location: `~/Library/pnpm/store` (default)
- Global binaries: `~/Library/pnpm`
- Configuration: `~/.config/pnpm/rc`
- Shell completions for zsh and nushell
- Integrated with Atuin history search

### npm & yarn

npm and yarn are also supported with completion integration.

## Customization

### Color Schemes

Three themes are available with matching terminal, Neovim, and tmux colors:
- Monokai Pro
- Night Owl
- Tokyo Night

Enable by including the corresponding section in `.dotter/local.toml`.

### MCP Servers

Enable optional MCP servers for Claude Desktop:
- Atlassian (Jira)
- GitLab
- Odaseva
- Postman
- Salesforce
- SonarQube

Set to `true` in `.dotter/local.toml` and provide required API tokens.

## Structure

```
.
├── .dotter/           # Dotter configuration and templates
├── nvim/              # Neovim configs (default/work/personal)
├── opencode/          # OpenCode commands and plugins
├── atuin/             # Shell history sync config
├── fish/              # Fish shell config
├── ghostty/           # Ghostty terminal config
├── hypr/              # Hyprland (Linux) config
├── tmux-sessionizer/ # Tmux session management
├── waybar/            # Waybar (Linux) status bar with Go scripts
├── init.sh            # Initial setup script
├── Brewfile           # macOS package definitions
└── README.md          # This file
```

## License

Personal configurations - use at your own discretion.
