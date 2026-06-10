import _shared.templates as tpl

# ── tmux config (tmux.conf template) ────────────────────────────────────
tmux = {
    theme_plugin = tpl.hb("tmux_theme_plugin")
    theme_config = tpl.hb("tmux_theme_config")
}
