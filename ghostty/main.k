# ── Constants ───────────────────────────────────────────────────────────
_font_mono = "MesloLGMDZ Nerd Font Mono"
_bg_color = "#000000"
_bg_opacity = 0.85
_scrollback_limit = 1000000
_macos_titlebar = "transparent"

# ── ghostty config (raw text template) ──────────────────────────────────
ghostty = """font-family = "${_font_mono}"

theme = "{{ ghostty_theme }}"

background-opacity  = ${_bg_opacity}
background-blur     = true
background          = "${_bg_color}"

macos-titlebar-style = "${_macos_titlebar}"

mouse-hide-while-typing = true
scrollback-limit = ${_scrollback_limit}
copy-on-select = true
window-save-state = always

keybind = super+r=reload_config

# Split navigation with vim-style hjkl
keybind = super+h=goto_split:left
keybind = super+j=goto_split:bottom
keybind = super+k=goto_split:top
keybind = super+l=goto_split:right

# Split pane visual distinction
unfocused-split-opacity = 0.7
unfocused-split-fill = {{ ghostty_unfocused_split_fill }}
split-divider-color = {{ ghostty_split_divider_color }}

# Default shell: Nushell (via sh to set XDG_CONFIG_HOME before exec)
command = /bin/sh -c 'XDG_CONFIG_HOME=$HOME/.config exec {{ shell_bin_path }}/nu -l'

# Allow tmux to set window title
window-title-font-family = "${_font_mono}"
"""
