local wezterm = require 'wezterm'

local config = wezterm.config_builder()

config.initial_cols = 120
config.initial_rows = 28

config.font = wezterm.font 'MesloLGMDZ Nerd Font Mono'
config.font_size = 12
config.color_scheme = "Monokai Remastered"
config.window_background_opacity = 0.9
config.tab_bar_at_bottom = true
config.use_fancy_tab_bar = false

return config
