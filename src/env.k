import _shared
import _shared.templates as tpl

# ── Env config ─────────────────────────────────────────────────────────
# Core env vars — these are also used for dotter template variables
env = _shared.EnvConfig {
    editor = "nvim"
    xdg_config_home = "$HOME/.config"
    venv_home = "$HOME/.virtualenvs"
    nvm_dir = "$HOME/.nvm"
    pnpm_home = "$HOME/Library/pnpm"
    sf_use_generic_unix_keychain = "true"
    sf_beta_track_file_moves = "true"
    lua_path = "/opt/homebrew/Cellar/luarocks/3.13.0_1/share/lua/5.5/?.lua;/opt/homebrew/Cellar/luarocks/3.12.2/share/lua/5.5/?.lua;/opt/homebrew/share/lua/5.5/?.lua;/opt/homebrew/share/lua/5.5/?/init.lua;/opt/homebrew/lib/lua/5.5/?.lua;/opt/homebrew/lib/lua/5.5/?/init.lua;./?.lua;./?/init.lua;$HOME/.luarocks/share/lua/5.5/?.lua;$HOME/.luarocks/share/lua/5.5/?/init.lua"
    lua_cpath = "/opt/homebrew/lib/lua/5.5/?.so;/opt/homebrew/lib/lua/5.5/loadall.so;./?.so;$HOME/.luarocks/lib/lua/5.5/?.so"
    path_prepend = [
        "{{shell_bin_path}}"
        "$HOME/.luarocks/bin"
        "$HOME/.cargo/bin"
        "$HOME/Library/pnpm/bin"
        "/opt/python27/bin"
        "$HOME/.local/bin"
    ]
    path_append = [
        "$HOME/go/bin"
        "$HOME/bin"
        "$HOME/.atuin/bin"
        "/usr/local/bin"
        "/Applications/Obsidian.app/Contents/MacOS"
    ]
    sections = [
        _shared.EnvSection {
            name = "work"
            condition = "{{#if opencode_profile_work}}"
            vars = {
                "GITLAB_URL": "gitlab_url"
                "GITLAB_TOKEN": ""
                "SONAR_TOKEN": ""
                "SLACK_TOKEN": ""
                "SLACK_D_COOKIE": ""
                "NODE_EXTRA_CA_CERTS": "node_extra_ca_certs"
                "REQUESTS_CA_BUNDLE": "node_extra_ca_certs"
                "P10K_ROOT_DIR": "p10k_root_dir"
            }
        }
        _shared.EnvSection {
            name = "personal"
            condition = "{{#if opencode_profile_personal}}"
            vars = {
                "HA_URL": "home_assistant_url"
                "BSKY_HANDLE": "bluesky_handle"
                "PLEX_URL": "plex_url"
                "PROTON_USER": "proton_user"
            }
        }
    ]
}
