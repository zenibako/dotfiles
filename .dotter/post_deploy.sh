#!/bin/sh
set -eu

# Resolve dotfiles root from the git repo containing this script.
# dotter runs post_deploy.sh from .dotter/cache/, so we use git to find the root.
_dotfiles=$(git -C "$(dirname "0")" rev-parse --show-toplevel 2>/dev/null) || _dotfiles=""

# Fallback: in CI the repo may be copied without .git; dotter runs from the repo
# root so the current working directory is the correct dotfiles root.
if [ -z "$_dotfiles" ]; then
  _dotfiles=$(pwd)
fi

_scripts="$_dotfiles/.dotter/scripts"

# Symlink shared commands into OpenCode (dotter can't map one source to two targets,
# so we point opencode at the already-deployed ~/.claude/commands/ symlinks)
_oc_cmd="$HOME/.config/opencode/command"
mkdir -p "$_oc_cmd"
for _cmd in go.md fix-pipeline.md coderabbit-review.md; do
  ln -sf "$HOME/.claude/commands/$_cmd" "$_oc_cmd/$_cmd"
done
unset _oc_cmd _cmd

# Deploy skills to Claude Desktop
if [ -n "$_dotfiles" ]; then
  _claude_app="$HOME/Library/Application Support/Claude"
  _ops_file="$_claude_app/cowork-enabled-cli-ops.json"
  if [ -f "$_ops_file" ] && command -v python3 >/dev/null 2>&1; then
    _account_id=$(python3 -c "
import json, sys
try:
    print(json.load(open('$_ops_file'))['ownerAccountId'])
except Exception:
    sys.exit(1)
" 2>/dev/null) || _account_id=""
    _plugin_dir="$_claude_app/local-agent-mode-sessions/skills-plugin"
    _plugin_uuid=$(ls "$_plugin_dir" 2>/dev/null | head -1)

    if [ -n "$_account_id" ] && [ -n "$_plugin_uuid" ]; then
      _skills_base="$_plugin_dir/$_plugin_uuid/$_account_id"
      _skills_dir="$_skills_base/skills"
      _manifest="$_skills_base/manifest.json"
      mkdir -p "$_skills_dir"
      echo "Deploying Claude Desktop skills..."
      for _sd in "$_dotfiles/src/claude-desktop/skills"/*/; do
        [ -d "$_sd" ] || continue
        _sname=$(basename "$_sd")
        mkdir -p "$_skills_dir/$_sname"
        cp "$_sd/SKILL.md" "$_skills_dir/$_sname/SKILL.md"
        echo "  Copied skill: $_sname"
      done
      python3 "$_scripts/deploy_skills.py" "$_manifest" "$_dotfiles/src/claude-desktop/skills"
    fi
  fi
  unset _claude_app _ops_file _account_id _plugin_dir _plugin_uuid _skills_base _skills_dir _manifest _sd _sname
fi

DEPLOYED="$HOME/.config"

# --- Secret injection (Proton Pass or macOS Keychain) ---
# Instead of exporting secrets as shell env vars, we read them from a local
# credential cache and inject them directly into the config files that need
# them. This limits secret exposure to specific processes/config files only.
#
# Backends (tried in order):
#   1. Proton Pass CLI  -> ~/.cache/proton-pass-secrets.env
#   2. macOS Keychain   -> ~/.cache/macos-keychain-secrets.env
#
# Naming convention is now unified between both backends.
_SECRET_CACHE=""

_ensure_secret_cache() {
  local _proton_cache="$HOME/.cache/proton-pass-secrets.env"
  local _keychain_cache="$HOME/.cache/macos-keychain-secrets.env"
  local _backend=""

  # --- Detect which backend is installed ---
  if [ -x "$HOME/.config/opencode/script/proton-pass-env.sh" ] \
      && "$HOME/.config/opencode/script/proton-pass-env.sh" --configured >/dev/null 2>&1; then
    _backend="proton"
  elif [ -x "$HOME/.config/opencode/script/macos-keychain-env.sh" ] \
      && "$HOME/.config/opencode/script/macos-keychain-env.sh" --configured >/dev/null 2>&1; then
    _backend="keychain"
  else
    echo "WARNING: No secret backend installed (Proton Pass or macOS Keychain); secrets will not be injected." >&2
    return 1
  fi

  # --- Use the detected backend only ---
  if [ "$_backend" = "proton" ]; then
    local _needs_build=0
    if [ ! -f "$_proton_cache" ]; then
      _needs_build=1
    else
      local _mtime_epoch
      if [ "$(uname -s)" = "Darwin" ]; then
        _mtime_epoch=$(stat -f %m "$_proton_cache" 2>/dev/null)
      else
        _mtime_epoch=$(stat -c %Y "$_proton_cache" 2>/dev/null)
      fi
      if [ -n "$_mtime_epoch" ]; then
        local _now_epoch _age_sec
        _now_epoch=$(date +%s)
        _age_sec=$(( _now_epoch - _mtime_epoch ))
        [ "$_age_sec" -ge 3600 ] && _needs_build=1
      else
        _needs_build=1
      fi
    fi
    if [ "$_needs_build" -eq 1 ]; then
      "$HOME/.config/opencode/script/proton-pass-env.sh" --build >/dev/null 2>&1 && {
        _SECRET_CACHE="$_proton_cache"
        return 0
      }
    else
      _SECRET_CACHE="$_proton_cache"
      return 0
    fi
  elif [ "$_backend" = "keychain" ]; then
    local _needs_build=0
    if [ ! -f "$_keychain_cache" ]; then
      _needs_build=1
    else
      local _mtime_epoch
      if [ "$(uname -s)" = "Darwin" ]; then
        _mtime_epoch=$(stat -f %m "$_keychain_cache" 2>/dev/null)
      else
        _mtime_epoch=$(stat -c %Y "$_keychain_cache" 2>/dev/null)
      fi
      if [ -n "$_mtime_epoch" ]; then
        local _now_epoch _age_sec
        _now_epoch=$(date +%s)
        _age_sec=$(( _now_epoch - _mtime_epoch ))
        [ "$_age_sec" -ge 3600 ] && _needs_build=1
      else
        _needs_build=1
      fi
    fi
    if [ "$_needs_build" -eq 1 ]; then
      "$HOME/.config/opencode/script/macos-keychain-env.sh" --build >/dev/null 2>&1 && {
        _SECRET_CACHE="$_keychain_cache"
        return 0
      }
    else
      _SECRET_CACHE="$_keychain_cache"
      return 0
    fi
  fi

  return 1
}

_lookup_secret() {
  local target="$1"
  while IFS=$'\t' read -r key value _enc; do
    [ "$key" = "$target" ] && { printf '%s' "$value"; return 0; }
  done < "$_SECRET_CACHE"
  return 1
}

_inject_github_token() {
  local config_file="$1"
  if [ ! -f "$config_file" ]; then return; fi
  local token
  token=$(_lookup_secret "GITHUB_PERSONAL_ACCESS_TOKEN") || return
  echo "  Injecting GitHub token into $(basename "$config_file")..."
  python3 -c "
import json, sys
cfg_path = '$config_file'
with open(cfg_path, 'r') as f:
    cfg = json.load(f)
servers = cfg.get('mcpServers', {})
gh = servers.get('GitHub')
if gh:
    env = gh.setdefault('env', {})
    env['GITHUB_PERSONAL_ACCESS_TOKEN'] = '$token'
    env.setdefault('PATH', '/usr/bin:/bin:/usr/sbin:/sbin')
    with open(cfg_path, 'w') as f:
        json.dump(cfg, f, indent=2)
    print('  OK')
else:
    print('  SKIP: GitHub MCP not found')
" 2>/dev/null || echo "  WARNING: Failed to patch $(basename "$config_file")"
}

if _ensure_secret_cache; then
  echo "Applying secrets to deployed configs..."
  _inject_github_token "$HOME/Library/Application Support/Claude/claude_desktop_config.json"
  _inject_github_token "$HOME/Library/Application Support/Claude/settings.json"
  _inject_github_token "$HOME/.claude/settings.json"

  # --- OpenCode MCP config (JSONC with comments) ---
  _opencode_config="$HOME/.config/opencode/opencode.jsonc"
  if [ -f "$_opencode_config" ] && command -v python3 >/dev/null 2>&1; then
    _patch_args=""
    _tok=$(_lookup_secret "GITHUB_PERSONAL_ACCESS_TOKEN") && _patch_args="$_patch_args --github-token $_tok"
    _tok=$(_lookup_secret "GITLAB_TOKEN") && _patch_args="$_patch_args --gitlab-token $_tok"
    _tok=$(_lookup_secret "POSTMAN_API_KEY") && _patch_args="$_patch_args --postman-token $_tok"
    _tok=$(_lookup_secret "SONAR_TOKEN") && _patch_args="$_patch_args --sonar-token $_tok"
    _tok=$(_lookup_secret "HA_TOKEN") && _patch_args="$_patch_args --ha-token $_tok"
    _tok=$(_lookup_secret "MCP_OBSIDIAN_TOKEN") && _patch_args="$_patch_args --obsidian-token $_tok"
    if [ -n "$_patch_args" ]; then
      echo "  Patching OpenCode MCP config..."
      python3 "$_scripts/patch_opencode_secrets.py" "$_opencode_config" $_patch_args 2>/dev/null || echo "  WARNING: Failed to patch OpenCode config"
    fi
    unset _patch_args _tok
  fi
  unset _opencode_config

  # --- Shared env.toml: directly inject secrets via inline replacement ---
  # Some tools (shell scripts, Neovim) must read secrets from the deployed env.toml.
  # We patch the deployed file after dotter render, avoiding any shell env export.
  _deployed_env="$DEPLOYED/shared/env.toml"
  if [ -f "$_deployed_env" ]; then
    _env_modified=0
    for _mapping in \
      "HA_TOKEN\thome_assistant_token" \
      "BSKY_APP_PASSWORD\tbluesky_app_password" \
      "PLEX_USER_TOKEN\tplex_user_token" \
      "PLEX_SERVER_TOKEN\tplex_server_token" \
      "TMDB_KEY\ttmdb_key" \
      "YOUTUBE_API_KEY\tyoutube_api_key" \
      "GOOGLE_PLACES_API_KEY\tgoogle_places_api_key" \
      "BRAVE_API_KEY\tbrave_search_api_key" \
      "PROTON_PASSWORD\tproton_password" \
      "TELEGRAM_BOT_TOKEN\ttelegram_bot_token" \
      "REDDIT_SESSION\treddit_session" \
      "LAST_FM_API_KEY\tlast_fm_api_key" \
      "ROCKSKY_PASSWORD\trocksky_password" \
      "MCP_OBSIDIAN_TOKEN\tmcp_obsidian_token" \
      "GITLAB_TOKEN\tGITLAB_TOKEN" \
      "SONAR_TOKEN\tSONAR_TOKEN" \
      "SLACK_TOKEN\tSLACK_TOKEN" \
      "SLACK_D_COOKIE\tSLACK_D_COOKIE"; do
      _env_var=$(printf '%s' "$_mapping" | cut -f1)
      _placeholder=$(printf '%s' "$_mapping" | cut -f2)
      _val=$(_lookup_secret "$_env_var") || continue
      # Replace empty placeholder in deployed env.toml
      _tmp="${_deployed_env}.tmp.$$"
      if grep -q "^$_placeholder = \"\"" "$_deployed_env" 2>/dev/null; then
        sed "s/^$_placeholder = \"\"/$_placeholder = \"$_val\"/" "$_deployed_env" > "$_tmp" && mv "$_tmp" "$_deployed_env"
        echo "  Injected $_placeholder into env.toml"
        _env_modified=1
      elif grep -q "^$_placeholder = \"\x7b\x7b.*\"" "$_deployed_env" 2>/dev/null; then
        sed "s|^$_placeholder = \"\x7b\x7b.*\"|$_placeholder = \"$_val\"|" "$_deployed_env" > "$_tmp" && mv "$_tmp" "$_deployed_env"
        echo "  Injected $_placeholder into env.toml"
        _env_modified=1
      fi
      rm -f "$_tmp"
    done
    unset _mapping _env_var _placeholder _val
  fi
  unset _deployed_env _env_modified

else
    echo "WARNING: No secret backend installed (Proton Pass or macOS Keychain); secrets will not be injected." >&2
fi
unset -f _ensure_secret_cache _lookup_secret _inject_github_token
unset _SECRET_CACHE

if [ -d "$_dotfiles" ]; then
  REPO_ROOT="$_dotfiles" "$_scripts/validate_schema.sh" --post-deploy || exit 1
fi

# --- OpenCode MCP health check ---
if command -v opencode >/dev/null 2>&1 && [ -f "$DEPLOYED/opencode/opencode.jsonc" ]; then
  echo "Checking OpenCode MCP servers..."
  mcp_out=$(mktemp)
  mcp_err=$(mktemp)

  # opencode mcp list can hang if the server is starting; add a 30s timeout
  if command -v timeout >/dev/null 2>&1; then
    _mcp_list_cmd="timeout 30 opencode mcp list"
  elif command -v gtimeout >/dev/null 2>&1; then
    _mcp_list_cmd="gtimeout 30 opencode mcp list"
  else
    _mcp_list_cmd="opencode mcp list"
  fi

  if ! eval "$_mcp_list_cmd" > "$mcp_out" 2> "$mcp_err"; then
    echo "WARNING: opencode mcp list command failed or timed out" >&2
    if [ -s "$mcp_err" ]; then
      cat "$mcp_err" >&2
    fi
    rm -f "$mcp_out" "$mcp_err"
  else
    # Strip ANSI escape codes for parsing (use perl for cross-platform support)
    if command -v perl >/dev/null 2>&1; then
      mcp_clean=$(perl -pe 's/\e\[[0-9;]*m//g' < "$mcp_out")
    else
      mcp_clean=$(cat "$mcp_out")
    fi

    # Count servers by matching server header lines (● ✓ or ● ✗)
    total=$(echo "$mcp_clean" | awk 'BEGIN{c=0} /^[[:space:]]*●[[:space:]]+[✓✗]/ {c++} END {print c}')
    connected=$(echo "$mcp_clean" | awk 'BEGIN{c=0} /^[[:space:]]*●[[:space:]]+✓/ {c++} END {print c}')
    failed=$(echo "$mcp_clean" | awk 'BEGIN{c=0} /^[[:space:]]*●[[:space:]]+✗/ {c++} END {print c}')

    : "${total:=0}" "${connected:=0}" "${failed:=0}"

    if [ "$failed" -gt 0 ]; then
      echo "WARNING: $failed MCP server(s) appear failed or disconnected" >&2
      echo "$mcp_clean" | grep -E '^[[:space:]]*●[[:space:]]+✗' >&2 || true
    fi

    if [ "$connected" -eq 0 ] && [ "$total" -gt 0 ]; then
      echo "WARNING: No MCP servers connected ($total configured)" >&2
    elif [ "$total" -gt 0 ]; then
      echo "  OpenCode MCPs: $connected/$total connected"
    else
      echo "  No MCP servers configured"
    fi

    rm -f "$mcp_out" "$mcp_err"
  fi
  unset _mcp_list_cmd
fi

# --- Lua validation ---
if [ -d "$DEPLOYED/nvim" ]; then
  if command -v luac >/dev/null 2>&1; then
    echo "Validating Lua files..."
    _failed=0
    _lua_files=$(mktemp)
    find "$DEPLOYED/nvim" -name '*.lua' -type f 2>/dev/null > "$_lua_files"
    while IFS= read -r _lua_file; do
      if ! luac -p "$_lua_file" >/dev/null 2>&1; then
        echo "ERROR: Lua syntax error in $_lua_file" >&2
        _failed=1
      fi
    done < "$_lua_files"
    rm -f "$_lua_files"

    if [ "$_failed" -eq 1 ]; then
      exit 1
    fi
    echo "  All Lua files OK"
  else
    echo "  Skipping Lua validation (luac not available)"
  fi
fi

# --- Neovim startup test ---
if command -v nvim >/dev/null 2>&1 && [ -d "$DEPLOYED/nvim" ]; then
  echo "Testing Neovim startup..."
  if command -v timeout >/dev/null 2>&1; then
    timeout 60 nvim --headless +qa! 2>/tmp/nvim-startup.log || true
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout 60 nvim --headless +qa! 2>/tmp/nvim-startup.log || true
  else
    nvim --headless +qa! 2>/tmp/nvim-startup.log || true
  fi

  if grep -E '^E[0-9]+:|Error while calling lua chunk|Error loading plugin config' /tmp/nvim-startup.log 2>/dev/null \
       | grep -v 'image\.nvim\|image\.lua\|image/backends\|terminal size\|non-terminal' \
       | grep -q .; then
    echo "ERROR: Neovim startup errors detected:" >&2
    cat /tmp/nvim-startup.log >&2
    exit 1
  fi
  echo "  Neovim startup OK"

  # --- LSP validation ---
  if [ -f "$_scripts/validate_lsp.lua" ]; then
    echo "Validating LSP attachments..."
    lsp_out=$(mktemp)
    # Write suppression patterns to a temp file so we only define them once.
    # These are all known non-fatal stderr noise from headless nvim.
    lsp_ignore=$(mktemp)
    cat > "$lsp_ignore" <<'LSP_FILTERS'
image.nvim
image.lua
image/backends
terminal size
non-terminal
Error in command line:
ignoreSingleFileWarning
Some capabilities may be reduced
Cannot read properties of null
vim.schedule callback
RPC[Error]
Request initialize failed
stack traceback:
[C]: in function 'assert'
[C]: in function 'pcall'
[C]: in function '_with'
[C]: in function 'nvim_exec2'
[C]: at 0x
vim/lsp/client.lua:581: in function
vim/_core/editor.lua: in function
filetype.lua:27:
validate_lsp.lua:
python3_provider
g:loaded_python3_provider
provider: python3: missing
LSP_FILTERS
    # Neovim headless sends print() output to stderr, capture both
    timeout 300 nvim --headless -c "luafile $_scripts/validate_lsp.lua" -c "qa!" 2>"$lsp_out" >/dev/null || true
    if command -v perl >/dev/null 2>&1; then
      perl -pe 's/\e\[[0-9;]*m//g' < "$lsp_out" | grep -Fv -f "$lsp_ignore" | grep -v '^\s*$' || true
    else
      cat "$lsp_out" | grep -Fv -f "$lsp_ignore" | grep -v '^\s*$' || true
    fi
    rm -f "$lsp_out" "$lsp_ignore"
  fi
fi

echo "==> Post-deploy validation complete."
