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
  version: "2.0"
---

# Dotfiles KCL Configuration

## When to use

- When adding or modifying dotter profiles (default, personal, work, linux, mac)
- When adding or modifying themes (monokai, nightowl, tokyonight)
- When changing package lists (Fedora, Homebrew, VS Code extensions)
- When modifying tool configs: atuin, starship, aerospace, iamb, gitlogue, pnpm
- When modifying template configs: jj, tmux, ghostty
- When adding new KCL schemas or modules for new config domains
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
 .dotter/      out/shared/    out/packages-    out/atuin/      out/jj/
 global.toml   env.toml        fedora.txt       config.toml     config.toml
               completions     out/Brewfile     out/starship    out/tmux.conf
               .toml                          .toml             out/ghostty/
                                               out/aerospace     config
                                               .toml             out/iamb/
                                                                 config.toml
                                                                 out/gitlogue/
                                                                 config.toml
                                                                 out/pnpm/
                                                                 rc
```

1. **KCL** (`main.k` + domain modules) produces `generated/config.json`
2. **Python converter** (`.dotter/scripts/generate_from_kcl.py`) reads JSON and writes TOML/text files to `out/`
3. **dotter** deploys the generated files from `out/` to `~/.config/`

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
├── jj.k                # jj config (TOML template with Handlebars)
├── tmux.k              # tmux theme plugin/config markers
├── ghostty_config.k    # ghostty raw text template (renamed to avoid ghostty/ collision)
├── aerospace.k         # macOS window manager config
├── atuin/
│   └── main.k          # Atuin shell history config (directory module)
├── iamb/
│   └── main.k          # Matrix client config (directory module)
├── gitlogue/
│   └── main.k          # Git log TUI config (directory module)
├── pnpm/
│   └── main.k          # pnpm rc config (directory module)
└── _shared/
    ├── schemas.k       # All KCL type schemas
    └── templates.k     # Shared template helpers (hb, etc.)
```

### Module Naming Convention

| Pattern | When to use | Example |
|---|---|---|
| **Bare `.k` at root** | No directory name collision; single file output | `aerospace.k` → `out/aerospace.toml` |
| **`foo/main.k` directory** | Config naturally deploys to a directory; directory doesn't conflict | `atuin/main.k` → `out/atuin/config.toml` |
| **`foo_config.k` at root** | Directory `foo/` exists but is for other assets (not KCL) | `ghostty_config.k` → `out/ghostty/config` |
| **`_shared/*.k`** | Shared schemas, helpers, utilities | `_shared/schemas.k`, `_shared/templates.k` |

**Rule:** Prefer `foo/main.k` when the config domain maps to a directory. Only use `_config` suffix when the directory exists for non-KCL assets (e.g., `ghostty/` contains GLSL shaders).

**Important:** KCL resolves `import foo` to `foo/` directory over `foo.k` file. If both exist, the directory wins.

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

1. **Choose module naming:**
   - If config deploys to a directory and the directory name is free → `mkdir mytool && mytool/main.k`
   - If it's a single file or directory exists for other assets → `mytool.k` or `mytool_config.k` at root

2. **Add a schema** to `_shared/schemas.k` (or reuse `{str: any}` for simple configs)

3. **Create the domain file:**

```kcl
# For directory module: mytool/main.k
import _shared

mytool = _shared.MyToolConfig {
    setting = "value"
}
```

4. **Register in `main.k`:**

```kcl
import mytool

config = _shared.ConfigMap {
    # ... existing fields ...
    mytool = mytool.mytool
}
```

5. **Update `profiles.k`** to reference the generated file:

```kcl
files = {
    "out/mytool/config.toml" = "~/.config/mytool/config.toml"
}
```

6. **Update the Python converter** (`.dotter/scripts/generate_from_kcl.py`) to handle the new config type
7. **Add validation** to `.dotter/scripts/validate_generated.py` if needed

## Template Configs

Template configs contain Handlebars `{{}}` placeholders resolved by dotter at deploy time.

### Using the Shared Template Helper

Use `_shared/templates.k` instead of raw `{TEMPLATE_MARKER = "field"}` dicts:

```kcl
import _shared.templates as tpl

myconfig = {
    api_key = tpl.hb("my_api_key")
    endpoint = "https://api.example.com"
}
```

`tpl.hb("field")` returns `{TEMPLATE_MARKER = "field"}` which the Python converter turns into `{{field}}`.

### Raw Text Templates

For non-TOML formats, use triple-quoted strings with `{{}}` directly:

```kcl
myapp = """setting = "{{ myapp_setting }}"
other = true
"""
```

### Template Domains

Each template domain lives in its own `.k` file:

| File | Output | Format |
|---|---|---|
| `jj.k` | `out/jj/config.toml` | TOML with `tpl.hb()` markers |
| `tmux.k` | `out/tmux.conf` | Custom tmux script with markers |
| `ghostty_config.k` | `out/ghostty/config` | Raw text with `{{}}` placeholders |

Register in `main.k` under `TemplateConfig`:

```kcl
templates = _shared.TemplateConfig {
    jj = jj.jj
    tmux = tmux.tmux
    ghostty = ghostty_config.ghostty
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

### Directory Shadowing

If a `.k` file has the same name as an existing directory (e.g., `ghostty.k` vs `ghostty/`), KCL resolves `import ghostty` to the **directory** and ignores the `.k` file.

**Solutions:**
- Put KCL inside `ghostty/main.k` if `ghostty/` is for KCL config
- Use `ghostty_config.k` at root if `ghostty/` is for non-KCL assets (e.g., GLSL shaders)

### No `kcl.mod` Needed

KCL resolves sibling `.k` files in the same directory automatically. Only `import <filename>` is required — no `kcl.mod` package declaration.

### `_shared/` Prefix

Functional folders (schemas, shared utilities) use `_` prefix to distinguish them from config domains. Import as `import _shared`.

### Generated Files Go to `out/`

All generated configs live in `out/` (gitignored). Only `.dotter/global.toml` stays at root (dotter entry point).

When adding a new generated file, update `profiles.k` to use the `out/` prefix:

```kcl
# Before (stale, at root)
"mytool/config.toml" = "~/.config/mytool/config.toml"

# After (correct, in out/)
"out/mytool/config.toml" = "~/.config/mytool/config.toml"
```

## Validation

The validation script (`.dotter/scripts/validate_generated.py`) runs after generation and checks:

- `generated/config.json` exists and parses as JSON
- `.dotter/global.toml` parses as TOML
- `out/shared/env.toml` template structure (balanced `{{#if}}`/`{{/if}}`)
- `out/shared/completions.toml` parses as TOML
- `out/packages-fedora.txt` and `out/Brewfile` non-empty
- All tool configs parse as TOML
- All template configs have valid template markers
- `out/ghostty/config` is non-empty

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
| `TemplateConfig` | Template output definitions (jj, tmux, ghostty) |
| `AerospaceConfig` | macOS window manager settings |
| `ConfigMap` | Top-level output structure (includes all domains) |

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
