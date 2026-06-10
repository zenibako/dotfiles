import _shared

# ── Atuin config ────────────────────────────────────────────────────────
atuin = _shared.AtuinConfig {
    enter_accept = True
    keymap_mode = "vim-normal"
    search_mode = "daemon-fuzzy"
    stats = {
        common_prefix = ["sudo", "pnpm", "npm", "yarn"]
    }
    sync = {
        records = True
    }
    daemon = {
        enabled = True
        autostart = True
    }
    dotfiles = {
        enabled = True
    }
    ai = {
        enabled = True
    }
}
