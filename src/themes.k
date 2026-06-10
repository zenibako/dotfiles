import _shared

# ── Themes ─────────────────────────────────────────────────────────────
themes = {
    monokai = _shared.ThemeVariables {
        ghostty_theme = "Monokai Pro"
        ghostty_unfocused_split_fill = "#221f22"
        ghostty_split_divider_color = "#727072"
        nvim_colorscheme_plugin = "sainnhe/sonokai"
        nvim_colorscheme_config = """      vim.g.sonokai_enable_italic = true
      vim.g.sonokai_transparent_background = 1
      vim.cmd.colorscheme('sonokai')"""
        nvim_lualine_theme = "sonokai"
        tmux_theme_plugin = "zenibako/tmux-monokai-pro"
        tmux_theme_config = """
# Monokai theme configuration
set -g @monokai-plugins 'time battery cpu-usage ram-usage'
set -g @monokai-show-powerline true
set -g @monokai-show-left-sep ''
set -g @monokai-show-right-sep ''
"""
        nu_prompt_insert_color = "green_bold"
        nu_prompt_normal_color = "yellow_bold"
    }
    nightowl = _shared.ThemeVariables {
        ghostty_theme = "Night Owl"
        ghostty_unfocused_split_fill = "#011627"
        ghostty_split_divider_color = "#5f7e97"
        nvim_colorscheme_plugin = "oxfist/night-owl.nvim"
        nvim_colorscheme_config = """      require('night-owl').setup()
      vim.cmd.colorscheme('night-owl')"""
        nvim_lualine_theme = "night-owl"
        tmux_theme_plugin = "kylepeeler/tmux-nightowl"
        tmux_theme_config = """
# Nightowl theme configuration
set -g @nightowl-show-powerline true
set -g @nightowl-show-left-icon session
set -g @nightowl-show-left-sep ''
set -g @nightowl-show-right-sep ''
set -g @nightowl-military-time false
set -g @nightowl-cpu-usage true
set -g @nightowl-ram-usage true
set -g @nightowl-show-timezone true
set -g @nightowl-border-contrast true
"""
        nu_prompt_insert_color = "light_blue_bold"
        nu_prompt_normal_color = "light_purple_bold"
    }
    tokyonight = _shared.ThemeVariables {
        ghostty_theme = "TokyoNight Night"
        ghostty_unfocused_split_fill = "#1a1b26"
        ghostty_split_divider_color = "#283457"
        nvim_colorscheme_plugin = "folke/tokyonight.nvim"
        nvim_colorscheme_config = """      require('tokyonight').setup({
        style = 'night',
        transparent = true,
        terminal_colors = true,
        styles = {
          comments = { italic = true },
          keywords = { italic = true },
          sidebars = 'transparent',
          floats = 'transparent',
        },
      })
      vim.cmd.colorscheme('tokyonight')"""
        nvim_lualine_theme = "tokyonight"
        tmux_theme_plugin = "janoamaral/tokyo-night-tmux"
        tmux_theme_config = """
# Tokyo Night theme configuration
set -g @tokyo-night-tmux_theme night
set -g @tokyo-night-tmux_transparent 0
set -g @tokyo-night-tmux_window_id_style fsquare
set -g @tokyo-night-tmux_pane_id_style hsquare
set -g @tokyo-night-tmux_zoom_id_style dsquare
set -g @tokyo-night-tmux_show_datetime 1
set -g @tokyo-night-tmux_date_format MYD
set -g @tokyo-night-tmux_time_format 12H
set -g @tokyo-night-tmux_show_path 1
set -g @tokyo-night-tmux_path_format relative
set -g @tokyo-night-tmux_show_battery_widget 0
set -g @tokyo-night-tmux_show_netspeed 0
set -g @tokyo-night-tmux_show_music 0
set -g @tokyo-night-tmux_show_hostname 0
"""
        nu_prompt_insert_color = "cyan_bold"
        nu_prompt_normal_color = "blue_bold"
    }
}
