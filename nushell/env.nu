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
$env.EDITOR = "nvim"

zoxide init nushell | save -f ~/.zoxide.nu
starship init nu | save -f ~/.starship.nu

$env.CARAPACE_BRIDGES = 'zsh,fish,bash,inshellisense' # optional
mkdir ~/.cache/carapace
carapace _carapace nushell | save --force ~/.cache/carapace/init.nu

# $env.JAVA_HOME = "/opt/homebrew/opt/openjdk"
# $env.PATH = ($env.PATH | prepend $"($env.JAVA_HOME)/bin/")

$env.PATH = ($env.PATH | append $"($env.HOME)/.atuin/bin/")
$env.PATH = ($env.PATH | append $"($env.HOME)/go/bin/")

$env.OLLAMA_HOST = "http://10.0.7.73:11434"

$env.XDG_CONFIG_HOME = $"($env.HOME)/.config"

$env.GPG_TTY = (tty)
