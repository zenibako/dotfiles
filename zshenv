# ~/.zshenv — sourced for ALL zsh invocations (interactive, login, non-interactive)
# This file ensures PATH and environment variables are set even for
# non-interactive shells (e.g., MCP servers launched by OpenCode).
#
# Completions, prompts, and interactive-only features stay in ~/.zshrc.
#
# The _ZSHENV_LOADED guard prevents double-loading when ~/.zshrc also
# calls _load_shared_env.

if [ -z "$_ZSHENV_LOADED" ]; then
  _ZSHENV_LOADED=1

  # Ensure homebrew/bin is on PATH (macOS Apple Silicon)
  # Needed early so tomlq/node/etc. are findable below
  if [ -d "/opt/homebrew/bin" ]; then
    case ":$PATH:" in
      *:/opt/homebrew/bin:*) ;;
      *) export PATH="/opt/homebrew/bin:$PATH" ;;
    esac
  fi

  _tomlq() {
      if command -v tomlq >/dev/null 2>&1; then
          command tomlq "$@"
      elif [ -x /opt/homebrew/bin/tomlq ]; then
          /opt/homebrew/bin/tomlq "$@"
      elif [ -x /usr/local/bin/tomlq ]; then
          /usr/local/bin/tomlq "$@"
      else
          return 1
      fi
  }

  _load_shared_env() {
      local env_file="$HOME/.config/shared/env.toml"
      [ -f "$env_file" ] || return
      if ! _tomlq --version >/dev/null 2>&1; then
          if [ -z "$_TOMLQ_MISSING_WARNED" ]; then
              echo "warning: tomlq not found; shared env (env.toml) will not be loaded. Install with: brew install python-yq" >&2
              _TOMLQ_MISSING_WARNED=1
          fi
          return
      fi

      local key value path_entry
      # [env] section: KEY="value" pairs
      while IFS=$'\t' read -r key value; do
          [ -z "$key" ] && continue
          value="${value//\$HOME/$HOME}"
          export "$key"="$value"
      done < <(_tomlq -r '.env // {} | to_entries[] | "\(.key)\t\(.value)"' "$env_file")

      # [path] prepend (reverse so first entry has highest priority)
      while IFS= read -r path_entry; do
          [ -z "$path_entry" ] && continue
          path_entry="${path_entry//\$HOME/$HOME}"
          if [ -d "$path_entry" ]; then
              case ":$PATH:" in
                  *:"$path_entry":*) ;;
                  *) export PATH="$path_entry:$PATH" ;;
              esac
          fi
      done < <(_tomlq -r '.path.prepend // [] | reverse | .[]' "$env_file")

      # [path] append
      while IFS= read -r path_entry; do
          [ -z "$path_entry" ] && continue
          path_entry="${path_entry//\$HOME/$HOME}"
          if [ -d "$path_entry" ]; then
              case ":$PATH:" in
                  *:"$path_entry":*) ;;
                  *) export PATH="$path_entry:$PATH" ;;
              esac
          fi
      done < <(_tomlq -r '.path.append // [] | .[]' "$env_file")
  }
  _load_shared_env
  unset -f _tomlq _load_shared_env

  # opencode
  export PATH="$HOME/.opencode/bin:$PATH"

  {{#if opencode_profile_work}}
  # Netskope CA certificate for Node.js (work profile)
  export NODE_EXTRA_CA_CERTS="{{node_extra_ca_certs}}"
  export REQUESTS_CA_BUNDLE="{{node_extra_ca_certs}}"
  {{/if}}
fi