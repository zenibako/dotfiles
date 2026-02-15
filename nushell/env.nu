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

# NVM Setup
# Must run before tool init commands since it replaces $env.PATH
$env.NVM_DIR = ($env.HOME | path join ".nvm")
# Load nvm environment variables (if nvm exists)
if ("/opt/homebrew/opt/nvm/nvm.sh" | path exists) {
    let cmd = $"export NVM_DIR='($env.NVM_DIR)'; source \"/opt/homebrew/opt/nvm/nvm.sh\"; jq -n --arg nvm_dir \"\$NVM_DIR\" --arg nvm_bin \"\$NVM_BIN\" --arg nvm_inc \"\$NVM_INC\" --arg path \"\$PATH\" '{NVM_DIR: \$nvm_dir, NVM_BIN: \$nvm_bin, NVM_INC: \$nvm_inc, PATH: \$path}'"
    let nvm_vars = (bash -c $cmd | from json)

    load-env {
        NVM_DIR: $nvm_vars.NVM_DIR
        NVM_BIN: $nvm_vars.NVM_BIN
        NVM_INC: $nvm_vars.NVM_INC
    }

    $env.PATH = ($nvm_vars.PATH | split row (char esep))
}

# Generate shell integration files with error handling
try { zoxide init nushell | save -f ~/.zoxide.nu } catch { }
try { starship init nu | save -f ~/.starship.nu } catch { }

$env.CARAPACE_BRIDGES = 'zsh,fish,bash,inshellisense' # optional
try { mkdir ~/.cache/carapace } catch { }  # May already exist
try { carapace _carapace nushell | save --force ~/.cache/carapace/init.nu } catch { }

# Load shared completions from completions.toml
# This is the single source of truth for CLI tool completions shared with zsh
let completions_path = ($env.HOME | path join ".config/shared/completions.toml")
if ($completions_path | path exists) {
    try { mkdir ~/.cache/completions } catch { }  # May already exist
    
    let completions = (open $completions_path)
    mut init_lines = []
    
    for tool in ($completions | transpose name config) {
        let nu_cmd = ($tool.config | get -o nu | default "")
        if $nu_cmd != "" and (which $tool.name | is-not-empty) {
            # Generate completion file
            try { 
                nu -c $nu_cmd | save -f $"~/.cache/completions/($tool.name).nu"
                $init_lines = ($init_lines | append $"source ~/.cache/completions/($tool.name).nu")
            } catch { }
        }
    }
    
    # Write init file with all source commands
    $init_lines | str join (char newline) | save -f ~/.cache/completions/init.nu
}

# $env.JAVA_HOME = "/opt/homebrew/opt/openjdk"
# $env.PATH = ($env.PATH | prepend $"($env.JAVA_HOME)/bin/")

# Note: Most PATH and env vars are now loaded from shared/env.toml above
# Shell-specific additions can still be added here:
$env.PATH = ($env.PATH | append $"($env.HOME)/.opencode/bin/")

$env.OLLAMA_HOST = "http://10.0.7.73:11434"

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
