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
import ghostty_config
import aerospace

# ── Assemble and export ───────────────────────────────────────────────
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
        ghostty = ghostty_config.ghostty
    }
    aerospace = aerospace.aerospace
}

# Write JSON for the Python converter
file.write("generated/config.json", json.encode(config, indent=2))
