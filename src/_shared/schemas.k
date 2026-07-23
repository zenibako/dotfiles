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

schema VsixLspServer:
    namespace: str
    name: str
    version: str
    target_platform?: str
    artifact_check: str

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

schema EnvSection:
    name: str
    condition?: str
    vars?: {str: str}
    path_prepend?: [str]
    path_append?: [str]

schema EnvConfig:
    editor?: str
    visual?: str
    manpager?: str
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
    sections?: [EnvSection]
    profile_work?: bool = False
    profile_personal?: bool = False

schema CompletionEntry:
    zsh?: str
    nu?: str

schema CompletionsConfig:
    tools?: {str: CompletionEntry}

schema AtuinConfig:
    enter_accept?: bool = True
    keymap_mode?: str = "vim-normal"
    search_mode?: str = "daemon-fuzzy"
    stats?: {str: any}
    sync?: {str: any}
    daemon?: {str: any}
    dotfiles?: {str: any}
    ai?: {str: any}

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
    ghostty?: str

schema AerospaceConfig:
    "config-version"?: int = 2
    "after-startup-command"?: [str]
    "exec-on-workspace-change"?: [str]
    "start-at-login"?: bool = True
    "enable-normalization-flatten-containers"?: bool = True
    "enable-normalization-opposite-orientation-for-nested-containers"?: bool = True
    "accordion-padding"?: int = 30
    "default-root-container-layout"?: str = "tiles"
    "default-root-container-orientation"?: str = "auto"
    "on-focused-monitor-changed"?: [str]
    "automatically-unhide-macos-hidden-apps"?: bool = True
    "persistent-workspaces"?: [str]
    "on-mode-changed"?: [str]
    "key-mapping"?: {str: any}
    "gaps"?: {str: any}
    "on-window-detected"?: [any]
    "mode"?: {str: any}
    "workspace-to-monitor-force-assignment"?: {str: any}

schema OutputTextFile:
    path: str
    content: str

schema OutputTomlFile:
    path: str
    data: {str: any}
    header?: str

schema OutputTemplateFile:
    path: str
    data: {str: any}
    header?: str

schema OutputEnvSection:
    type: "table" | "conditional" | "conditional_single"
    name?: str
    vars?: {str: str}
    path_prepend?: [str]
    path_append?: [str]

schema OutputEnvConfig:
    path: str
    sections: [OutputEnvSection]

schema OutputCompletionsConfig:
    path: str
    data: {str: any}

schema OutputPackagesConfig:
    fedora_txt: OutputPackageList
    brewfile: OutputBrewfile

schema OutputPackageList:
    path: str
    lines: [str]

schema OutputBrewfile:
    path: str
    data: PackageList

schema OutputConfig:
    text_files?: [OutputTextFile]
    toml_files?: [OutputTomlFile]
    template_files?: [OutputTemplateFile]
    env?: OutputEnvConfig
    completions?: OutputCompletionsConfig
    packages?: OutputPackagesConfig

schema ConfigMap:
    dotter?: DotterConfig
    env?: EnvConfig
    completions?: CompletionsConfig
    atuin?: AtuinConfig
    starship?: StarshipConfig
    templates?: TemplateConfig
    aerospace?: AerospaceConfig
    iamb?: {str: any}
    gitlogue?: {str: any}
    pnpm?: {str: any}
    gitconfig?: str
    opencode?: str
    claude_desktop?: str
    claude_code?: str
    zshenv?: str
    __output__?: OutputConfig
