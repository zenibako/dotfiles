---
name: dotfiles-kcl
description: >
  Maintain KCL configuration files for this dotfiles repository. KCL is the typed
  single source of truth that generates dotter config, static TOML files, and
  Handlebars templates. Use when adding or modifying themes, profiles, packages,
  tool configs (atuin, starship, aerospace), or template configs (jj, tmux, ghostty).
compatibility: Requires KCL CLI v0.12.3+. Python 3 with tomli_w for the converter.
metadata:
  author: chanderson
  version: "1.0"
---

# Dotfiles KCL Configuration

## When to use

- When adding or modifying dotter profiles (default, personal, work, linux, mac)
- When adding or modifying themes (monokai, nightowl, tokyonight)
- When changing package lists (Fedora, Homebrew, VS Code extensions)
- When modifying tool configs: atuin, starship, aerospace
- When modifying template configs: jj, tmux, ghostty
- When adding new KCL schemas for new config domains
- When the KCL → JSON → Python → TOML/text pipeline needs debugging

## Architecture Overview

KCL is the **single source of truth**. The pipeline is:

```
main.k ──→ kcl run main.k ──→ generated/config.json
                                          │
                                          ▼
                               .dotter/scripts/generate_from_kcl.py
                                          │
                                          ▼
     ┌─────────────┬──────────────┬───────┴───────┬──────────────┐
     ▼             ▼              ▼               ▼              ▼
 .dotter/      shared/      packages-      atuin/        jj/
 global.toml   env.toml      fedora.txt     config.toml   config.toml
               completions   Brewfile       starship      tmux.conf
               .toml                         .toml         ghostty/
                                              aerospace     config
                                              .toml
```

1. **KCL** (`main.k` + domain modules) produces `generated/config.json`
2. **Python converter** (`.dotter/scripts/generate_from_kcl.py`) reads JSON and writes TOML/text files
3. **dotter** deploys the generated files

## File Layout

```
.
├── main.k              # orchestration: imports all modules, writes JSON
├── packages.k          # Fedora packages, Homebrew taps/formulae/casks, VS Code extensions
├── themes.k            # Theme variables (colors, plugins, prompts)
├── profiles.k          # dotter profiles: default, personal, work, linux, mac, oda_mcp
├── env.k               # Environment variables (PATH, XDG_CONFIG_HOME, etc.)
├── completions.k       # Shell completion commands per tool
├── starship.k          # Starship prompt config (⚠️ $-interpolation sensitive)
├── templates.k         # Handlebars templates: jj, tmux, ghostty
├── aerospace.k         # macOS window manager config
├── atuin/
│   └── main.k          # Atuin shell history config (directory module)
└── _shared/
    └── schemas.k       # All KCL type schemas
```

- **Root `.k` files** live at repo root (no matching directory)
- **Directory modules** (like `atuin/`) contain `main.k` when a config directory already exists
- **`_shared/`** prefix marks functional folders (not config domains)

## Quick Commands

```bash
# Generate all configs from KCL
kcl run main.k >/dev/null

# Run the full pipeline (generation + validation)
python3 .dotter/scripts/generate_from_kcl.py
python3 .dotter/scripts/validate_generated.py

# Verify output is byte-identical before/after changes
# 1. Save current generated/config.json
# 2. Make edits
# 3. Regenerate
# 4. diff old.json new.json

# Dry-run dotter deploy to preview changes
dotter deploy --dry-run
```

## Adding a New Theme

Edit `themes.k`. A theme defines visual variables used across nvim, tmux, ghostty, and nushell:

```kcl
mytheme = _shared.ThemeVariables {
    ghostty_theme = "My Theme"
    ghostty_unfocused_split_fill = "#1a1b26"
    ghostty_split_divider_color = "#283457"
    nvim_colorscheme_plugin = "author/mytheme.nvim"
    nvim_colorscheme_config = """      require('mytheme').setup()
      vim.cmd.colorscheme('mytheme')"""
    nvim_lualine_theme = "mytheme"
    tmux_theme_plugin = "author/tmux-mytheme"
    tmux_theme_config = """
# Mytheme configuration
set -g @mytheme-show-powerline true
"""
    nu_prompt_insert_color = "cyan_bold"
    nu_prompt_normal_color = "blue_bold"
}
```

Then add it to the `themes` dict at the top of `themes.k`:

```kcl
themes = {
    monokai = ...
    nightowl = ...
    tokyonight = ...
    mytheme = mytheme
}
```

## Adding a New Profile

Edit `profiles.k`. Profile files map repo paths to home paths; variables are dotter template values:

```kcl
myprofile = _shared.Profile {
    depends = ["default"]
    files = {
        "myapp/config" = "~/.config/myapp/config"
    }
    variables = {
        myapp_api_key = ""
    }
}
```

Register it in `main.k`:

```kcl
dotter = _shared.DotterConfig {
    # ... existing profiles ...
    myprofile = profiles.myprofile
}
```

## Adding a New Tool Config

1. **Add a schema** to `_shared/schemas.k` (or reuse `{str: any}` for simple configs)
2. **Create a domain file** (e.g., `mytool.k` at root):

```kcl
import _shared

mytool = _shared.MyToolConfig {
    setting = "value"
}
```

3. **Register in `main.k`**:

```kcl
import mytool

config = _shared.ConfigMap {
    # ... existing fields ...
    mytool = mytool.mytool
}
```

4. **Update the Python converter** (`.dotter/scripts/generate_from_kcl.py`) to handle the new config type if needed
5. **Add validation** to `.dotter/scripts/validate_generated.py` if needed

## Adding a Template Config

Template configs contain Handlebars `{{}}` placeholders resolved by dotter at deploy time. Edit `templates.k`:

```kcl
mytemplate = {
    api_key = { TEMPLATE_MARKER = "my_api_key" }
    endpoint = "https://api.example.com"
}
```

The Python converter detects `TEMPLATE_MARKER` dicts and emits `{{field_name}}` instead of the literal.

For **raw text** templates (like ghostty), use a triple-quoted string with `{{}}` directly:

```kcl
myapp = """setting = "{{ myapp_setting }}"
other = true
"""
```

Register in `templates.k`:

```kcl
templates = {
    jj = ...
    tmux = ...
    ghostty = ...
    myapp = myapp
}
```

## Critical Gotchas

### `$` Interpolation

KCL **interpolates `${...}` in ALL string types** — single quotes, double quotes, triple quotes. This breaks starship format strings (`${custom.jj_change}`) and any shell `$var` syntax.

**Workaround:** Build strings outside schema bodies via concatenation:

```kcl
_dollar = "$"
_brace_open = "{"
_brace_close = "}"

_starship_format = _dollar + "username" + _dollar + _brace_open + "custom.jj_change" + _brace_close

starship = _shared.StarshipConfig {
    format = _starship_format
}
```

### TEMPLATE_MARKER

The Python converter only recognizes the exact dict shape `{TEMPLATE_MARKER: "field_name"}`. Do not add extra keys or change the casing.

### Directory Shadowing

If a `.k` file has the same name as an existing directory (e.g., `atuin.k` vs `atuin/`), KCL resolves `import atuin` to the **directory** and ignores the `.k` file. Put the config inside `atuin/main.k` instead.

### No `kcl.mod` Needed

KCL resolves sibling `.k` files in the same directory automatically. Only `import <filename>` is required — no `kcl.mod` package declaration.

### `_shared/` Prefix

Functional folders (schemas, shared utilities) use `_` prefix to distinguish them from config domains. Import as `import _shared`.

## Validation

The validation script (`.dotter/scripts/validate_generated.py`) runs after generation and checks:

- `generated/config.json` exists and parses as JSON
- `.dotter/global.toml` parses as TOML
- `shared/env.toml` template structure (balanced `{{#if}}`/`{{/if}}`)
- `shared/completions.toml` parses as TOML
- `packages-fedora.txt` and `Brewfile` non-empty
- All tool configs parse as TOML
- All template configs have valid template markers
- `ghostty/config` is non-empty

Run manually:

```bash
python3 .dotter/scripts/validate_generated.py
```

## Schema Reference

All schemas live in `_shared/schemas.k`:

| Schema | Purpose |
|--------|---------|
| `FileEntry` | dotter file mapping (target, type) |
| `Profile` | dotter profile (depends, files, variables) |
| `ThemeVariables` | Visual theme settings across tools |
| `PackageList` | Package lists per platform |
| `DotterConfig` | Root dotter configuration |
| `EnvConfig` | Environment variables |
| `CompletionsConfig` | Shell completion commands |
| `AtuinConfig` | Atuin shell history settings |
| `StarshipConfig` | Starship prompt settings |
| `TemplateConfig` | Template output definitions |
| `AerospaceConfig` | macOS window manager settings |
| `ConfigMap` | Top-level output structure |

## Committing KCL Changes

Always run the full pipeline before committing:

```bash
kcl run main.k >/dev/null
python3 .dotter/scripts/generate_from_kcl.py
python3 .dotter/scripts/validate_generated.py
```

Then deploy to verify dotter handles the generated files correctly:

```bash
dotter deploy -d
```

Include `Co-authored-by` attribution:

```bash
AI_CO_AUTHOR="Kimi <kimi-k2.6:cloud@ai>" jjc "feat: add new theme"
```
