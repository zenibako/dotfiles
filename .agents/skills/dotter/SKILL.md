---
name: dotter
description: >
  Deploy and manage dotfiles using dotter with profile inheritance, Handlebars templating,
  and theme support. Use when deploying configs, adding new dotfiles, modifying profiles,
  or troubleshooting deployment issues.
compatibility: Requires dotter CLI installed.
metadata:
  author: chanderson
  version: "1.0"
---

# Dotter Dotfiles Management

## When to use

- When deploying configuration changes
- When adding new config files to the dotfiles repo
- When modifying profiles or theme variables
- When troubleshooting template rendering or deployment
- When bootstrapping a new machine with `./init.sh`

## Bootstrapping a New Machine

```bash
./init.sh
```

This script is **cross-distro** and handles:

1. **Installing packages** from distro-specific `packages-<ID>.txt`:
   - `packages-fedora.txt` for Fedora/RHEL/CentOS/Rocky/Alma
   - `packages-arch.txt` for Arch/Manjaro
   - `packages-debian.txt` for Debian/Ubuntu/Linux Mint/Pop!_OS
   - `packages-alpine.txt` for Alpine
   - `packages-opensuse.txt` for openSUSE/SUSE
2. **Installing carapace** via Gemfury yum repo on RPM distros, else downloading the binary
3. **Installing shells/tools**: `oh-my-zsh`, `zsh-completions`, `tpm` (tmux plugin manager), `zoxide`, `atuin`, `starship`
4. **Dotter deploy**: `dotter deploy -f`

### macOS

Uses Homebrew and `Brewfile` instead of package lists.

```bash
brew bundle install
```

## Deploying Configs

```bash
# Deploy all configs (force overwrites)
dotter deploy -f

# Dry-run to preview changes
dotter deploy --dry-run

# Verbose output for debugging
dotter deploy -f --verbose
```

## Cross-Distro Package Management

Package lists are stored as `packages-<distro>.txt` in the repo root:

| File | Distros |
|------|---------|
| `packages-fedora.txt` | Fedora, RHEL, CentOS, Rocky, Alma |
| `packages-arch.txt` | Arch, Manjaro |
| `packages-debian.txt` | Debian, Ubuntu, Linux Mint, Pop!_OS |
| `packages-alpine.txt` | Alpine |
| `packages-opensuse.txt` | openSUSE, SUSE |

Format: one package per line, `#` for comments, blank lines ignored.

```
# Example packages-fedora.txt
fzf
fd-find
neovim
ripgrep
zsh
tmux
git
gh
jq
curl
wget
```

## Repository Structure

```
dotfiles/
├── .dotter/
│   ├── global.toml      # Profiles, files, variables, themes
│   ├── local.toml        # Machine-specific overrides (NEVER commit)
│   └── local.toml.example
├── nvim/
│   ├── default/          # Base Neovim config (shared)
│   ├── personal/         # Personal profile overlay
│   └── work/             # Work profile overlay
├── jj/                   # Jujutsu config (templated)
├── ghostty/              # Ghostty terminal config
├── zshrc                 # Zsh config (templated)
└── ...
```

## Profiles

Three profile types — select ONE from each category:

| Category | Options |
|----------|---------|
| Profile  | `personal`, `work` |
| Platform | `mac`, `linux` |
| Theme    | `monokai`, `nightowl`, `tokyonight` |

Both `personal` and `work` inherit from `default` via `depends = ["default"]`.

### Profile Inheritance

```
default (base files + variables)
├── personal (adds personal nvim, MCP configs)
└── work (adds work nvim, Slack plugin, LWC LSP)
```

## Adding a New Config File

1. Add the source file to the repo
2. Map it in `.dotter/global.toml` under the appropriate profile's `[<profile>.files]`:

```toml
# Simple file copy
"myapp/config" = "~/.config/myapp/config"

# With templating
"myapp/config" = { target = "~/.config/myapp/config", type = "template" }

# Symbolic link
"myapp/config" = { target = "~/.config/myapp/config", type = "symbolic" }
```

3. Add any required variables to `[<profile>.variables]`
4. Deploy: `dotter deploy -f`

## File Types

| Type | Behavior |
|------|----------|
| `automatic` | Dotter auto-detects (default) |
| `template` | Handlebars processing — `{{ variable }}` replaced |
| `symbolic` | Creates a symlink to the source file |

## Templating

Templates use Handlebars syntax:

```
# Simple variable
{{ email }}

# Conditional block
{{#if opencode_profile_work}}
work-specific content
{{/if}}

# Multi-line variable (triple braces for raw)
{{{ nvim_colorscheme_config }}}
```

## Configuration Files

- **`global.toml`** — Defines all profiles, file mappings, and default variables. Committed to the repo.
- **`local.toml`** — Machine-specific overrides: selected packages and secret values. **Never commit this file.** Use `local.toml.example` as a template.

## Secret Safety

- Never overwrite an existing `.dotter/local.toml` unless you are certain the current secrets are backed up elsewhere.
- Prefer generating sample or CI configs to a temporary path like `/tmp/local.toml` instead of `.dotter/local.toml`.
- `scripts/dotter-ci/create-local-toml.sh` refuses to overwrite an existing output file unless `--force` is passed explicitly.

## Gotchas

- Never edit files directly in `~/.config/` — dotter will overwrite them on next deploy. Edit the source in the dotfiles repo instead.
- `local.toml` must define ALL variables referenced in templates, even if empty strings
- Treat `.dotter/local.toml` as a secrets file. Avoid replacing it with generated test data during validation.
- Profile names in `local.toml` packages must match `global.toml` sections exactly
- Template files with syntax errors will fail silently in some cases — use `--verbose` to debug
- Nvim configs use overlay: `nvim/default` is deployed first, then `nvim/personal` or `nvim/work` merges on top
