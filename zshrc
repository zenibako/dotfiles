# If you come from bash you might have to change your $PATH.
export PATH=$HOME/bin:/usr/local/bin:$PATH

# Load shared environment variables from env.toml
# This is the single source of truth for env vars shared with nushell
_load_shared_env() {
    local env_file="$HOME/.config/shared/env.toml"
    [[ -f "$env_file" ]] || return

    local in_env=0 in_prepend=0 in_append=0
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue

        # Track sections
        if [[ "$line" == "[env]" ]]; then
            in_env=1; in_prepend=0; in_append=0; continue
        elif [[ "$line" == "[path]" ]]; then
            in_env=0; in_prepend=0; in_append=0; continue
        elif [[ "$line" =~ ^prepend[[:space:]]*= ]]; then
            in_prepend=1; in_append=0; in_env=0; continue
        elif [[ "$line" =~ ^append[[:space:]]*= ]]; then
            in_append=1; in_prepend=0; in_env=0; continue
        elif [[ "$line" == "["* ]]; then
            in_env=0; in_prepend=0; in_append=0; continue
        fi

        # Parse env vars
        if (( in_env )) && [[ "$line" =~ ^([A-Z_]+)[[:space:]]*=[[:space:]]*\"(.*)\"$ ]]; then
            local key="${match[1]}"
            local value="${match[2]}"
            value="${value//\$HOME/$HOME}"
            export "$key"="$value"
        fi

        # Parse path entries
        if (( in_prepend )) && [[ "$line" =~ \"(.+)\" ]]; then
            local p="${match[1]}"
            p="${p//\$HOME/$HOME}"
            [[ -d "$p" ]] && export PATH="$p:$PATH"
        fi
        if (( in_append )) && [[ "$line" =~ \"(.+)\" ]]; then
            local p="${match[1]}"
            p="${p//\$HOME/$HOME}"
            [[ -d "$p" ]] && export PATH="$PATH:$p"
        fi
    done < "$env_file"
}
_load_shared_env

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
# ZSH_THEME="robbyrussell"
# ZSH_THEME="agnoster"
# prompt_context() {}

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(extract git git-extras jira tmux git-commit nmap nvm gitignore encode64 brew rsync)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"

# Note: Most PATH entries are now loaded from shared/env.toml
# Shell-specific additions can still be added here

set -o vi

# Load pyenv automatically by appending
# the following to
# ~/.zprofile (for login shells)
# and ~/.zshrc (for interactive shells) :
if [ -e pyenv ]; then
  export PYENV_ROOT="$HOME/.pyenv"
  [[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
  eval "$(pyenv init -)"
fi

export VENV_HOME="$HOME/.virtualenvs"
[[ -d $VENV_HOME ]] || mkdir $VENV_HOME

lsvenv() {
  ls -1 $VENV_HOME
}

venv() {
  if [ $# -eq 0 ]
    then
      echo "Please provide venv name"
    else
      source "$VENV_HOME/$1/bin/activate"
  fi
}

mkvenv() {
  if [ $# -eq 0 ]
    then
      echo "Please provide venv name"
    else
      python3 -m venv $VENV_HOME/$1
  fi
}

rmvenv() {
  if [ $# -eq 0 ]
    then
      echo "Please provide venv name"
    else
      rm -r $VENV_HOME/$1
  fi
}


# Generated for envman. Do not edit.
[ -s "$HOME/.config/envman/load.sh" ] && source "$HOME/.config/envman/load.sh"

# Note: SF_USE_GENERIC_UNIX_KEYCHAIN and SF_BETA_TRACK_FILE_MOVES
# are now loaded from shared/env.toml
export SF_AC_ZSH_SETUP_PATH=$HOME/Library/Caches/sf/autocomplete/zsh_setup && test -f $SF_AC_ZSH_SETUP_PATH && source $SF_AC_ZSH_SETUP_PATH; # sf autocomplete setup 

export SF_USE_GENERIC_UNIX_KEYCHAIN=true

zstyle :omz:plugins:ssh-agent agent-forwarding on

if [[ -f ~/.ssh/ssh_auth_sock && -S "$SSH_AUTH_SOCK" ]]; then
    ln -sf $SSH_AUTH_SOCK ~/.ssh/ssh_auth_sock
fi

# if type brew &>/dev/null; then
#     FPATH=$(brew --prefix)/share/zsh-completions:$FPATH
# 
#     autoload -Uz compinit
#     compinit
# fi
# autoload -U compinit; compinit
# source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
#
 
if (( ${+commands[nvim]} ))
then
  export EDITOR="nvim"
  export MANPAGER="nvim +Man!"
fi
 
if (( ${+commands[brew]} ))
then
  export DYLD_FALLBACK_LIBRARY_PATH="$(brew --prefix)/lib:$DYLD_FALLBACK_LIBRARY_PATH"
fi

if (( ${+commands[deno]} ))
then
  [ -f "$HOME/.deno/env" ] && . "$HOME/.deno/env"
fi

# Load shared completions from completions.toml
# This is the single source of truth for CLI tool completions shared with nushell
_load_shared_completions() {
    local comp_file="$HOME/.config/shared/completions.toml"
    [[ -f "$comp_file" ]] || return
    
    [[ -d ~/.zsh/completion ]] || mkdir -p ~/.zsh/completion
    
    local current_tool="" zsh_cmd=""
    local in_tool=0
    
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        
        # Detect tool section [toolname]
        if [[ "$line" =~ "^\[([a-z_-]+)\]$" ]]; then
            current_tool="${match[1]}"
            in_tool=1
            zsh_cmd=""
            continue
        fi
        
        # Exit tool section when hitting another section
        if [[ "$line" == "["* ]]; then
            in_tool=0
            current_tool=""
            continue
        fi
        
        # Parse zsh command
        if (( in_tool )) && [[ "$line" =~ '^zsh[[:space:]]*=[[:space:]]*"(.*)"$' ]]; then
            zsh_cmd="${match[1]}"
            
            # Generate completion if tool exists and has a command
            if [[ -n "$zsh_cmd" ]] && (( ${+commands[$current_tool]} )); then
                eval "$zsh_cmd" > ~/.zsh/completion/_${current_tool} 2>/dev/null
            fi
        fi
    done < "$comp_file"
}

_load_shared_completions
fpath=(~/.zsh/completion $fpath)
autoload -U compinit
compinit

eval "$(starship init zsh)"

GHCUP_DIR="${HOME}/.ghcup"
if [[ -d $GHCUP_DIR ]]
then
  source "${GHCUP_DIR}/env"
fi

# Rust/Cargo environment
CARGO_ENV="${HOME}/.cargo/env"
if [[ -f $CARGO_ENV ]]
then
  source "$CARGO_ENV"
fi

BREW_NVM_DIR="/opt/homebrew/opt/nvm/"
if [[ -d $GHCUP_DIR ]]
then
  export NVM_DIR="$HOME/.nvm"
  [ -s "$BREW_NVM_DIR/nvm.sh" ] && \. "$BREW_NVM_DIR/nvm.sh"  # This loads nvm
  [ -s "$BREW_NVM_DIR/etc/bash_completion.d/nvm" ] && \. "$BREW_NVM_DIR/etc/bash_completion.d/nvm"  # This loads nvm bash_completion
fi

# Note: Most PATH entries are now loaded from shared/env.toml
# Created by `pipx` on 2025-06-27 18:19:27
# Shell-specific PATH additions below:

eval "$(zoxide init zsh)"

. "$HOME/.atuin/bin/env"

eval "$(atuin init zsh)"

# Note: XDG_CONFIG_HOME is now loaded from shared/env.toml

# Updates the gpg-agent TTY before every command since
# there's no way to detect this info in the ssh-agent protocol
function _gpg-agent-update-tty {
  gpg-connect-agent UPDATESTARTUPTTY /bye &>/dev/null
}

autoload -Uz add-zsh-hook
add-zsh-hook preexec _gpg-agent-update-tty


{{#if opencode_profile_work}}
# Netskope CA certificate for Node.js (work profile)
export NODE_EXTRA_CA_CERTS="{{node_extra_ca_certs}}"
export REQUESTS_CA_BUNDLE="{{node_extra_ca_certs}}"
{{/if}}

# opencode
export PATH=/Users/{{ username }}/.opencode/bin:$PATH
