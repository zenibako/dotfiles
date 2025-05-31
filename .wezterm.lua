local wezterm = require 'wezterm'

local config = wezterm.config_builder()

config.initial_cols = 120
config.initial_rows = 28

config.font = wezterm.font 'MesloLGMDZ Nerd Font Mono'
config.font_size = 12
config.color_scheme = "Monokai Remastered"

return config
