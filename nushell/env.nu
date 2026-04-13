# env.nu
#
# Installed by:
# version = "0.106.1"
#
# Previously, environment variables were typically configured in `env.nu`.
# In general, most configuration can and should be performed in `config.nu`
# or one of the autoload directories.
#
# This file is generated for backwards compatibility for now.
# It is loaded before config.nu and login.nu
#
# See https://www.nushell.sh/book/configuration.html
#
# Also see `help config env` for more options.
#
# You can remove these comments if you want or leave
# them for future reference.

# Load shared environment variables from env.toml
# This is the single source of truth for env vars shared with zsh
let shared_env_path = ($env.HOME | path join ".config/shared/env.toml")
if ($shared_env_path | path exists) {
    let shared = (open $shared_env_path)

    # Load environment variables (expanding $HOME)
    for item in ($shared.env | transpose key value) {
        let expanded_value = ($item.value | str replace --all '$HOME' $env.HOME)
        load-env { ($item.key): $expanded_value }
    }

    # Prepend paths (in reverse order so first in list = highest priority)
    for p in ($shared.path.prepend | reverse) {
        let expanded_path = ($p | str replace --all '$HOME' $env.HOME)
        if ($expanded_path | path exists) {
            $env.PATH = ($env.PATH | prepend $expanded_path)
        }
    }

    # Append paths
    for p in ($shared.path.append) {
        let expanded_path = ($p | str replace --all '$HOME' $env.HOME)
        if ($expanded_path | path exists) {
            $env.PATH = ($env.PATH | append $expanded_path)
        }
    }
}

# NVM Setup (uses the official-installer location ~/.nvm; nvm is no longer
# managed by Homebrew). Must run before tool init commands since it replaces $env.PATH.
$env.NVM_DIR = ($env.HOME | path join ".nvm")
let nvm_sh = ($env.NVM_DIR | path join "nvm.sh")
if ($nvm_sh | path exists) {
    let cmd = $"export NVM_DIR='($env.NVM_DIR)'; source \"($nvm_sh)\"; jq -n --arg nvm_dir \"\$NVM_DIR\" --arg nvm_bin \"\$NVM_BIN\" --arg nvm_inc \"\$NVM_INC\" --arg path \"\$PATH\" '{NVM_DIR: \$nvm_dir, NVM_BIN: \$nvm_bin, NVM_INC: \$nvm_inc, PATH: \$path}'"
    let nvm_vars = (bash -c $cmd | from json)

    load-env {
        NVM_DIR: $nvm_vars.NVM_DIR
        NVM_BIN: $nvm_vars.NVM_BIN
        NVM_INC: $nvm_vars.NVM_INC
    }

    $env.PATH = ($nvm_vars.PATH | split row (char esep))
}

# Generate shell integration files once and cache them. Regenerating these on
# every shell startup adds noticeable latency; the cached files only need to be
# refreshed when the underlying tool is upgraded (run `refresh-shell-init` to
# rebuild).
def --env refresh-shell-init [] {
    try { zoxide init nushell | save -f ~/.zoxide.nu }
    try { starship init nu | save -f ~/.starship.nu }
    try { mkdir ~/.cache/carapace }
    try { carapace _carapace nushell | save --force ~/.cache/carapace/init.nu }
    try { mkdir ~/.local/share/atuin }
    try { atuin init nu | save --force ~/.local/share/atuin/init.nu }
}

$env.CARAPACE_BRIDGES = 'zsh,fish,bash,inshellisense' # optional
let _shell_init_missing = (
    (not ("~/.zoxide.nu" | path expand | path exists))
    or (not ("~/.starship.nu" | path expand | path exists))
    or (not ("~/.cache/carapace/init.nu" | path expand | path exists))
    or (not ("~/.local/share/atuin/init.nu" | path expand | path exists))
)
if $_shell_init_missing { refresh-shell-init }

# Load shared completions from completions.toml. Generation is expensive, so
# results are cached in ~/.cache/completions and only rebuilt when the source
# TOML is newer than the cached init file (or via `refresh-completions`).
let completions_path = ($env.HOME | path join ".config/shared/completions.toml")
let completions_init = ($env.HOME | path join ".cache/completions/init.nu")

def --env refresh-completions [] {
    let completions_path = ($env.HOME | path join ".config/shared/completions.toml")
    if not ($completions_path | path exists) { return }
    mkdir ~/.cache/completions
    let completions = (open $completions_path)
    mut init_lines = []
    for tool in ($completions | transpose name config) {
        let nu_cmd = ($tool.config | get -o nu | default "")
        if $nu_cmd != "" and (which $tool.name | is-not-empty) {
            try {
                nu -c $nu_cmd | save -f $"~/.cache/completions/($tool.name).nu"
                $init_lines = ($init_lines | append $"source ~/.cache/completions/($tool.name).nu")
            }
        }
    }
    $init_lines | str join (char newline) | save -f ~/.cache/completions/init.nu
}

if ($completions_path | path exists) {
    let needs_rebuild = if not ($completions_init | path exists) {
        true
    } else {
        let src_mtime = (ls $completions_path | get modified.0)
        let cache_mtime = (ls $completions_init | get modified.0)
        $src_mtime > $cache_mtime
    }
    if $needs_rebuild { refresh-completions }
}

# $env.JAVA_HOME = "/opt/homebrew/opt/openjdk"
# $env.PATH = ($env.PATH | prepend $"($env.JAVA_HOME)/bin/")

# Note: Most PATH and env vars are now loaded from shared/env.toml above
# Shell-specific additions can still be added here:
$env.PATH = ($env.PATH | append $"($env.HOME)/.opencode/bin/")

{{#if playdate_sdk_enabled}}
# Playdate SDK
$env.PLAYDATE_SDK_PATH = $"($env.HOME)/Developer/PlaydateSDK"
$env.PATH = ($env.PATH | append $"($env.PLAYDATE_SDK_PATH)/bin/")
{{/if}}

{{#if opencode_profile_work}}
# Netskope CA certificate for Node.js (work profile)
$env.NODE_EXTRA_CA_CERTS = "{{node_extra_ca_certs}}"
$env.REQUESTS_CA_BUNDLE = "{{node_extra_ca_certs}}"
{{/if}}

# Rust/Cargo environment
let cargo_env = ($env.HOME | path join ".cargo/env")
if ($cargo_env | path exists) {
    # Source the cargo env by executing it through bash
    let cargo_vars = (bash -c $"source ($cargo_env) && env" | lines | parse "{key}={value}")
    for var in $cargo_vars {
        if $var.key starts-with "PATH" {
            $env.PATH = ($var.value | split row (char esep))
        } else if $var.key starts-with "CARGO" or $var.key starts-with "RUST" {
            load-env { ($var.key): $var.value }
        }
    }
}

$env.GPG_TTY = (try { tty } catch { "" })
