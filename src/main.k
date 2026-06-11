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
import gitconfig

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
}

# ── Write JSON for Python TOML converter ──────────────────────────────
file.write("out/config.json", json.encode(config, indent=2))

# ── Write text files directly (no Python needed) ──────────────────────
file.write("out/ghostty/config", ghostty.ghostty)
file.write("out/gitconfig", gitconfig.gitconfig)
file.write("out/pnpm/rc", pnpm.pnpm.rc or "")
file.write("out/tmux.conf", tmux.tmux._full_text)
file.write("out/packages-fedora.txt", packages.packages_txt)
file.write("out/Brewfile", packages.brewfile)
file.write("out/shared/completions.toml", completions.completions_toml)

# ── Write env metadata for Python ────────────────────────────────────
# env.toml has complex Handlebars conditionals; metadata drives Python
env_meta = {
    "path": "shared/env.toml"
    "core_vars": env.env
    "sections": env.env.sections or []
    "path_prepend": env.env.path_prepend or []
    "path_append": env.env.path_append or []
}
file.write("out/.env_meta.json", json.encode(env_meta, indent=2))
