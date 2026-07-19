import json
import file
import _shared
# Module files expose a top-level binding named the same as the module
# (e.g. packages.k has `packages = _shared.PackageList { ... }`). KCL's linter
# conflates that inner binding with the `import packages` binding here, so we
# alias each colliding import with a `_mod` suffix (matching the existing
# kiro_mod / mcp_shared convention). `kcl run` is unaffected — only the
# static analyzer / LSP sees a difference.
import packages as packages_mod
import themes as themes_mod
import profiles
import env as env_mod
import completions as completions_mod
import atuin as atuin_mod
import starship as starship_mod
import jj as jj_mod
import tmux as tmux_mod
import ghostty as ghostty_mod
import aerospace as aerospace_mod
import iamb as iamb_mod
import gitlogue as gitlogue_mod
import pnpm as pnpm_mod
import opencode.config as opencode
import kiro.config as kiro_mod
import claude
import claude_code
import zshenv
import gitconfig as gitconfig_mod
import local
import _shared.mcp as mcp_shared

# Effective MCP inclusion list for this machine. local.k's `mcp_included` wins,
# then the active dotter profile (personal/work), then none. This is used to
# generate the exact OpenCode mcp dict at KCL time (so excluded servers are
# literally omitted) and to derive the per-server flags used by Claude/Codex/Kiro
# templates.
_mcp_included = mcp_shared.effective_mcp_included(local.packages, local.variables)

# Force side-effect evaluation of modules with file.write
_kiro_eval = kiro_mod.kiro_config
_claude_eval = claude.claude_config
_claude_code_eval = claude_code._settings_json
_zshenv_eval = zshenv._final_zshenv

# ── Assemble config data ──────────────────────────────────────────────
config = _shared.ConfigMap {
    dotter = _shared.DotterConfig {
        default = profiles.default
        personal = profiles.personal
        work = profiles.work
        linux = profiles.linux
        mac = profiles.mac
        oda_mcp = profiles.oda_mcp
        themes = themes_mod.themes
        packages = packages_mod.packages
        settings = { default_target_type = "automatic" }
    }
    env = env_mod.env
    completions = completions_mod.completions
    atuin = atuin_mod.atuin
    starship = starship_mod.starship
    templates = _shared.TemplateConfig {
        jj = jj_mod.jj
        tmux = tmux_mod.tmux
        ghostty = ghostty_mod.ghostty
    }
    aerospace = aerospace_mod.aerospace
    iamb = iamb_mod.iamb
    gitlogue = gitlogue_mod.gitlogue
    pnpm = pnpm_mod.pnpm
    gitconfig = gitconfig_mod.gitconfig
    opencode = opencode.build(_mcp_included)
}

# ── Write JSON for Python TOML converter ──────────────────────────────
file.write("out/config.json", json.encode(config, indent=2))

# ── Write text files directly (no Python needed) ──────────────────────
file.write("out/ghostty/config", ghostty_mod.ghostty)
file.write("out/gitconfig", gitconfig_mod.gitconfig)
file.write("out/pnpm/rc", pnpm_mod.pnpm.rc or "")
file.write("out/tmux.conf", tmux_mod.tmux._full_text)

# ── Write env sections metadata for Python ─────────────────────────────
env_meta = {
    "path": "shared/env.toml"
    "core_vars": env_mod.env
    "sections": env_mod.env.sections or []
    "path_prepend": env_mod.env.path_prepend or []
    "path_append": env_mod.env.path_append or []
}
file.write("out/.env_meta.json", json.encode(env_meta, indent=2))

# ── Write completions metadata for Python ──────────────────────────────
completions_meta = {
    "path": "shared/completions.toml"
    "data": completions_mod.completions
}
file.write("out/.completions_meta.json", json.encode(completions_meta, indent=2))

# ── Write package metadata for Python ──────────────────────────────────
packages_meta = {
    "fedora_txt": {
        "path": "packages-fedora.txt"
        "lines": packages_mod.packages.fedora or []
    }
    "brewfile": {
        "path": "Brewfile"
        "data": packages_mod.packages
    }
}
file.write("out/.packages_meta.json", json.encode(packages_meta, indent=2))

# ── Write .dotter/local.toml from local.k ─────────────────────────────
# `local.packages` and `local.variables` come from src/local.k (gitignored,
# per-machine overrides), pulled in via `import local` at the top of this file.
# Run with `kcl run src/main.k` — local.k is resolved by the package, not as a
# second CLI input.

# If local.k declares `mcp_included`, derive the per-server boolean flags here
# so the dotter templates (opencode.jsonc, claude mcp.json, etc.) see them.
# This mirrors the expansion done for global profiles in src/profiles.k.
_local_variables = mcp_shared.expand_mcp_included(local.variables)

# Simple TOML value formatter. For strings we use JSON encoding so quotes and
# backslashes are escaped; booleans/numbers are emitted directly; arrays are
# emitted as TOML arrays (JSON arrays are valid TOML for simple values).
_format_local_value = lambda v {
    "true" if v == True else "false" if v == False else json.encode(v)
}

_local_lines = ["packages = ["]
_local_lines += ['  "{}",'.format(p) for p in local.packages]
_local_lines += ["]\n", "[variables]"]
_local_lines += ['{} = {}'.format(k, _format_local_value(v)) for k, v in _local_variables]
file.write(".dotter/local.toml", "\n".join(_local_lines) + "\n")
