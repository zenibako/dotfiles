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

schema ConfigMap:
    dotter?: DotterConfig
    env?: EnvConfig
    completions?: CompletionsConfig
