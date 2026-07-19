import json
import file
import _shared
import packages
import themes
import profiles
import env
import completions
import atuin
import starship
import jj
import tmux
import ghostty
import aerospace
import iamb
import gitlogue
import pnpm
import opencode
import claude
import claude_code
import kiro_config as kiro_mod
import zshenv
import gitconfig
import _shared.mcp as mcp_shared

# Effective MCP inclusion list for this machine. local.k's `mcp_included` wins,
# then the active dotter profile (personal/work), then none. This is used to
# generate the exact OpenCode mcp dict at KCL time (so excluded servers are
# literally omitted) and to derive the per-server flags used by Claude/Codex/Kiro
# templates.
_mcp_included = mcp_shared.effective_mcp_included(local_packages, local_variables)

# Force side-effect evaluation of modules with file.write
_kiro_eval = kiro_mod.kiro_config

# ── Assemble config data ──────────────────────────────────────────────
config = _shared.ConfigMap {
    dotter = _shared.DotterConfig {
        default = profiles.default
        personal = profiles.personal
        work = profiles.work
        linux = profiles.linux
        mac = profiles.mac
        oda_mcp = profiles.oda_mcp
        themes = themes.themes
        packages = packages.packages
        settings = { default_target_type = "automatic" }
    }
    env = env.env
    completions = completions.completions
    atuin = atuin.atuin
    starship = starship.starship
    templates = _shared.TemplateConfig {
        jj = jj.jj
        tmux = tmux.tmux
        ghostty = ghostty.ghostty
    }
    aerospace = aerospace.aerospace
    iamb = iamb.iamb
    gitlogue = gitlogue.gitlogue
    pnpm = pnpm.pnpm
    gitconfig = gitconfig.gitconfig
    opencode = opencode_config.build(_mcp_included)
}

# ── Write JSON for Python TOML converter ──────────────────────────────
file.write("out/config.json", json.encode(config, indent=2))

# ── Write text files directly (no Python needed) ──────────────────────
file.write("out/ghostty/config", ghostty.ghostty)
file.write("out/gitconfig", gitconfig.gitconfig)
file.write("out/pnpm/rc", pnpm.pnpm.rc or "")
file.write("out/tmux.conf", tmux.tmux._full_text)

# ── Write env sections metadata for Python ─────────────────────────────
env_meta = {
    "path": "shared/env.toml"
    "core_vars": env.env
    "sections": env.env.sections or []
    "path_prepend": env.env.path_prepend or []
    "path_append": env.env.path_append or []
}
file.write("out/.env_meta.json", json.encode(env_meta, indent=2))

# ── Write completions metadata for Python ──────────────────────────────
completions_meta = {
    "path": "shared/completions.toml"
    "data": completions.completions
}
file.write("out/.completions_meta.json", json.encode(completions_meta, indent=2))

# ── Write package metadata for Python ──────────────────────────────────
packages_meta = {
    "fedora_txt": {
        "path": "packages-fedora.txt"
        "lines": packages.packages.fedora or []
    }
    "brewfile": {
        "path": "Brewfile"
        "data": packages.packages
    }
}
file.write("out/.packages_meta.json", json.encode(packages_meta, indent=2))

# ── Write .dotter/local.toml from local.k ─────────────────────────────
# `local_packages` and `local_variables` are provided as top-level globals by
# the second KCL input file (local.k at the repo root), passed via
# `kcl run src/main.k local.k`.

# If local.k declares `mcp_included`, derive the per-server boolean flags here
# so the dotter templates (opencode.jsonc, claude mcp.json, etc.) see them.
# This mirrors the expansion done for global profiles in src/profiles.k.
_local_variables = mcp_shared.expand_mcp_included(local_variables)

# Simple TOML value formatter. For strings we use JSON encoding so quotes and
# backslashes are escaped; booleans/numbers are emitted directly; arrays are
# emitted as TOML arrays (JSON arrays are valid TOML for simple values).
_format_local_value = lambda v {
    "true" if v == True else "false" if v == False else json.encode(v)
}

_local_lines = ["packages = ["]
_local_lines += ['  "{}",'.format(p) for p in local_packages]
_local_lines += ["]\n", "[variables]"]
_local_lines += ['{} = {}'.format(k, _format_local_value(v)) for k, v in _local_variables]
file.write(".dotter/local.toml", "\n".join(_local_lines) + "\n")
