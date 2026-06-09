schema FileEntry:
    target?: str
    type?: "template" | "automatic" | "symbolic" | "directory"

schema Profile:
    depends?: [str]
    files?: {str: FileEntry | str}
    variables?: {str: any}

schema ThemeVariables:
    ghostty_theme: str
    ghostty_unfocused_split_fill: str
    ghostty_split_divider_color: str
    nvim_colorscheme_plugin: str
    nvim_colorscheme_config: str
    nvim_lualine_theme: str
    tmux_theme_plugin: str
    tmux_theme_config: str
    nu_prompt_insert_color: str
    nu_prompt_normal_color: str

schema PackageList:
    fedora?: [str]
    brew_taps?: [str]
    brew_formulae?: [str]
    brew_casks?: [str]
    vscode_extensions?: [str]

schema DotterConfig:
    default?: Profile
    personal?: Profile
    work?: Profile
    linux?: Profile
    mac?: Profile
    oda_mcp?: Profile
    themes?: {str: ThemeVariables}
    packages?: PackageList
    settings?: {str: any}

schema EnvConfig:
    editor?: str
    xdg_config_home?: str
    venv_home?: str
    nvm_dir?: str
    pnpm_home?: str
    sf_use_generic_unix_keychain?: str
    sf_beta_track_file_moves?: str
    lua_path?: str
    lua_cpath?: str
    gitlab_url?: str
    gitlab_token?: str
    sonar_token?: str
    slack_token?: str
    slack_d_cookie?: str
    node_extra_ca_certs?: str
    requests_ca_bundle?: str
    p10k_root_dir?: str
    ha_url?: str
    bsky_handle?: str
    plex_url?: str
    proton_user?: str
    tripit_username?: str
    path_prepend?: [str]
    path_append?: [str]
    profile_work?: bool = False
    profile_personal?: bool = False

schema CompletionEntry:
    zsh?: str
    nu?: str

schema CompletionsConfig:
    tools?: {str: CompletionEntry}

schema TemplateField:
    """Marks a field as a dotter template variable."""
    _template: str

schema AtuinConfig:
    enter_accept?: bool = True
    keymap_mode?: str = "vim-normal"
    search_mode?: str = "daemon-fuzzy"
    stats?: {str: any}
    sync?: {str: any}
    daemon?: {str: any}
    dotfiles?: {str: any}
    ai?: {str: any}

schema StarshipSection:
    """A generic TOML section for starship (format, style, symbol, etc)."""
    _ = """dummy"""

schema StarshipConfig:
    add_newline?: bool = True
    format?: str
    right_format?: str
    command_timeout?: int = 750
    package?: {str: any}
    git_commit?: {str: any}
    custom?: {str: {str: any}}
    shell?: {str: any}
    settings?: {str: any}

schema TemplateConfig:
    jj?: {str: any}
    tmux?: {str: any}

schema AerospaceConfig:
    config_version?: int = 2
    after_startup_command?: [str]
    start_at_login?: bool = True
    enable_normalization_flatten_containers?: bool = True
    enable_normalization_opposite_orientation_for_nested_containers?: bool = True
    accordion_padding?: int = 30
    default_root_container_layout?: str = "tiles"
    default_root_container_orientation?: str = "auto"
    on_focused_monitor_changed?: [str]
    automatically_unhide_macos_hidden_apps?: bool = True
    persistent_workspaces?: [str]
    on_mode_changed?: [str]
    key_mapping?: {str: any}
    gaps?: {str: any}
    on_window_detected?: [any]
    mode_main_binding?: {str: any}
    mode_service_binding?: {str: any}
    mode_passthrough_binding?: {str: any}
    workspace_to_monitor_force_assignment?: {str: any}

schema ConfigMap:
    dotter?: DotterConfig
    env?: EnvConfig
    completions?: CompletionsConfig
    atuin?: AtuinConfig
    starship?: StarshipConfig
    templates?: TemplateConfig
    aerospace?: AerospaceConfig
