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

$env.GPG_TTY = (try { tty } catch { "" })
