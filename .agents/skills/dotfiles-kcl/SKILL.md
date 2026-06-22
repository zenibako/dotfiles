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
  version: "2.1"
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
src/main.k + local.k ──→ kcl run src/main.k local.k ──→ out/config.json
                                              │
                                              ├──→ file.write() ──→ out/ghostty/config
                                              ├──→ file.write() ──→ out/gitconfig
                                              ├──→ file.write() ──→ out/pnpm/rc
                                              ├──→ file.write() ──→ out/tmux.conf
                                              │
                                              ├──→ file.write() ──→ out/ghostty/config
                                              ├──→ file.write() ──→ out/gitconfig
                                              ├──→ file.write() ──→ out/pnpm/rc
                                              ├──→ file.write() ──→ out/tmux.conf
                                              │
                                              ▼
                                   scripts/dotter/generate_from_kcl.py
                                              │
                                              ▼
         ┌─────────────┬──────────────┬───────┴───────┬──────────────┐
         ▼             ▼              ▼               ▼              ▼
     .dotter/      out/shared/    out/packages-    out/atuin/      out/jj/
     global.toml   env.toml        fedora.txt       config.toml     config.toml
                   completions     out/Brewfile     out/starship    out/tmux.conf
                   .toml                           .toml             out/ghostty/
                                                   out/aerospace      config
                                                   .toml              out/iamb/
                                                                       config.toml
                                                                       out/gitlogue/
                                                                       config.toml
                                                                       out/pnpm/
                                                                       rc
```

1. **KCL** (`src/main.k` + domain modules) writes text files directly via `file.write()` and produces `out/config.json` for structured data
2. **Python converter** (`scripts/dotter/generate_from_kcl.py`) reads JSON and writes TOML/structured text files to `out/`
3. **dotter** deploys the generated files from `out/` to `~/.config/`

## File Layout

```
.
├── local.k.example         # Template for local.k (committed, at repo root)
├── src/
│   ├── main.k              # orchestration: imports all modules, writes JSON
│   ├── packages.k          # Fedora packages, Homebrew taps/formulae/casks, VS Code extensions
│   ├── themes.k            # Theme variables (colors, plugins, prompts)
│   ├── profiles.k          # dotter profiles: default, personal, work, linux, mac, oda_mcp
│   ├── env.k               # Environment variables (PATH, XDG_CONFIG_HOME, etc.)
│   ├── completions.k       # Shell completion commands per tool
│   ├── starship.k          # Starship prompt config (⚠️ $-interpolation sensitive)
│   ├── jj.k                # jj config (TOML template with Handlebars)
│   ├── tmux.k              # tmux theme plugin/config markers
│   ├── aerospace.k         # macOS window manager config
│   ├── atuin/
│   │   ├── main.k          # Atuin shell history config
│   │   └── bin/              # Shell integration scripts (deployed from src/)
│   ├── ghostty/
│   │   ├── main.k            # ghostty raw text template
│   │   └── shaders/          # GLSL cursor effects (deployed from src/)
│   ├── iamb/
│   │   └── main.k          # Matrix client config
│   ├── gitlogue/
│   │   └── main.k          # Git log TUI config
│   ├── pnpm/
│   │   └── main.k          # pnpm rc config
│   └── _shared/
│       ├── schemas.k       # All KCL type schemas
│       └── templates.k     # Shared template helpers (hb, etc.)
├── out/                    # Generated configs (gitignored)
└── .dotter/
    └── global.toml         # dotter entry point
```

- **`src/`** — All KCL source code and static assets for config domains live here. Nothing in `src/` is deployed directly.
- **`src/main.k`** — Orchestration. Imports all modules, assembles `ConfigMap`, writes `out/config.json`.
- **`src/_shared/`** — Shared schemas and helpers (imported as `import _shared`).
- **Directory modules** (`src/foo/main.k`) — KCL resolves `import foo` to `src/foo/main.k`. Static assets for the same domain live inside `src/foo/` (e.g., `src/atuin/bin/`, `src/ghostty/shaders/`).
- **Bare `.k` files** (`src/aerospace.k`, `src/jj.k`) — Single-file configs with no directory structure.
- **`local.k`** (repo root) — Machine-specific secrets and overrides (gitignored). Generates `.dotter/local.toml`. Copy from `local.k.example` on new machines. Passed as a second `kcl run` input: `kcl run src/main.k local.k`.

## Quick Commands

```bash
# Generate all configs from KCL (run from repo root)
# local.k is passed as a second input so its top-level values become globals
kcl run src/main.k local.k >/dev/null

# Run the full pipeline (generation + validation)
python3 scripts/dotter/generate_from_kcl.py
python3 scripts/dotter/validate_generated.py

# Verify output is byte-identical before/after changes
# 1. Save current out/config.json
# 2. Make edits
# 3. Regenerate
# 4. diff old.json new.json

# Dry-run dotter deploy to preview changes
dotter deploy --dry-run
```

## Adding a New Theme

Edit `src/themes.k`. A theme defines visual variables used across nvim, tmux, ghostty, and nushell:

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

Then add it to the `themes` dict at the top of `src/themes.k`:

```kcl
themes = {
    monokai = ...
    nightowl = ...
    tokyonight = ...
    mytheme = mytheme
}
```

## Adding a New Profile

Edit `src/profiles.k`. Profile files map repo paths to home paths; variables are dotter template values:

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

Register it in `src/main.k`:

```kcl
dotter = _shared.DotterConfig {
    # ... existing profiles ...
    myprofile = profiles.myprofile
}
```

## Adding a New Tool Config

1. **Create the module:**
   - If config deploys to a directory → `mkdir src/mytool && src/mytool/main.k`
   - If it's a single file → `src/mytool.k`

2. **Add a schema** to `src/_shared/schemas.k` (or reuse `{str: any}` for simple configs)

3. **Write the domain file:**

```kcl
# For directory module: src/mytool/main.k
import _shared

mytool = _shared.MyToolConfig {
    setting = "value"
}
```

4. **Register in `src/main.k`:**

```kcl
import mytool

config = _shared.ConfigMap {
    # ... existing fields ...
    mytool = mytool.mytool
}
```

5. **Update `src/profiles.k`** to reference the generated file:

```kcl
files = {
    "out/mytool/config.toml" = "~/.config/mytool/config.toml"
}
```

6. **Update the Python converter** (`scripts/dotter/generate_from_kcl.py`) to handle the new config type if needed
7. **Add validation** to `scripts/dotter/validate_generated.py` if needed

## Template Configs

Template configs contain Handlebars `{{}}` placeholders resolved by dotter at deploy time.

### Using the Shared Template Helper

Use `src/_shared/templates.k` instead of raw `{TEMPLATE_MARKER = "field"}` dicts:

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

Each template domain lives in its own file under `src/`:

| File | Output | Format |
|---|---|---|
| `src/jj.k` | `out/jj/config.toml` | TOML with `tpl.hb()` markers |
| `src/tmux.k` | `out/tmux.conf` | Custom tmux script with markers |
| `src/ghostty/main.k` | `out/ghostty/config` | Raw text with `{{}}` placeholders |

Register in `src/main.k` under `TemplateConfig`:

```kcl
templates = _shared.TemplateConfig {
    jj = jj.jj
    tmux = tmux.tmux
    ghostty = ghostty.ghostty
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

KCL resolves `import foo` to `src/foo/` directory over `src/foo.k` file. If both exist, the directory wins.

**Solution:** Put KCL inside `src/foo/main.k`. Static assets for the same domain go inside `src/foo/` (e.g., `src/atuin/bin/`, `src/ghostty/shaders/`) so the entire config domain is self-contained.

### No `kcl.mod` Needed

KCL resolves sibling `.k` files in the same directory automatically. Only `import <filename>` is required — no `kcl.mod` package declaration.

### Generated Files Go to `out/`

All generated configs live in `out/` (gitignored). Only `.dotter/global.toml` stays at root (dotter entry point).

When adding a new generated file, update `src/profiles.k` to use the `out/` prefix:

```kcl
# Correct (generated file in out/)
"out/mytool/config.toml" = "~/.config/mytool/config.toml"
```

## Validation

The validation script (`scripts/dotter/validate_generated.py`) runs after generation and checks:

- `out/config.json` exists and parses as JSON
- `.dotter/global.toml` parses as TOML
- `out/shared/env.toml` template structure (balanced `{{#if}}`/`{{/if}}`)
- `out/shared/completions.toml` parses as TOML
- `out/packages-fedora.txt` and `out/Brewfile` non-empty
- All tool configs parse as TOML
- All template configs have valid template markers
- `out/ghostty/config` is non-empty

Run manually:

```bash
python3 scripts/dotter/validate_generated.py
```

## Schema Reference

All schemas live in `src/_shared/schemas.k`:

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
kcl run src/main.k local.k >/dev/null
python3 scripts/dotter/generate_from_kcl.py
python3 scripts/dotter/validate_generated.py
```

Then deploy to verify dotter handles the generated files correctly:

```bash
dotter deploy -d
```

Include `Co-authored-by` attribution:

```bash
AI_CO_AUTHOR="Kimi <kimi-k2.6:cloud@ai>" jjc "feat: add new theme"
```
