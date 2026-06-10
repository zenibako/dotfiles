import _shared

# ── Env config ─────────────────────────────────────────────────────────
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
        "{{shell_bin_path}}",
        "$HOME/.luarocks/bin",
        "$HOME/.cargo/bin",
        "$HOME/Library/pnpm/bin",
        "/opt/python27/bin",
        "$HOME/.local/bin",
    ]
    path_append = [
        "$HOME/go/bin",
        "$HOME/bin",
        "$HOME/.atuin/bin",
        "/usr/local/bin",
        "/Applications/Obsidian.app/Contents/MacOS",
    ]
}
