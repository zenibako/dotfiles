#!/bin/sh
set -eu

# Resolve lib.sh whether run directly from scripts/ or from dotter's hook cache
# (dotter copies hooks into .dotter/cache/.dotter/ before executing them).
# shellcheck source=dotter/lib.sh
_self="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
if [ -f "$_self/dotter/lib.sh" ]; then
  . "$_self/dotter/lib.sh"
else
  . "$(git rev-parse --show-toplevel 2>/dev/null || pwd)/scripts/dotter/lib.sh"
fi

resolve_repo_root
resolve_python
_scripts="$REPO_ROOT/scripts/dotter"

DEPLOYED="$HOME/.config"

# ── OpenCode command symlinks ─────────────────────────────────────────────
_oc_cmd="$HOME/.config/opencode/command"
mkdir -p "$_oc_cmd"
for _cmd in go.md fix-pipeline.md coderabbit-review.md; do
  ln -sf "$HOME/.claude/commands/$_cmd" "$_oc_cmd/$_cmd"
done
unset _oc_cmd _cmd

# ── Deploy skills to Claude Desktop ──────────────────────────────────────
if [ -n "$REPO_ROOT" ]; then
  _claude_app="$HOME/Library/Application Support/Claude"
  _ops_file="$_claude_app/cowork-enabled-cli-ops.json"
  if [ -f "$_ops_file" ] && command -v "$PYTHON" >/dev/null 2>&1; then
    _account_id=$("$PYTHON" -c "
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
      for _sd in "$REPO_ROOT/src/claude-desktop/skills"/*/; do
        [ -d "$_sd" ] || continue
        _sname=$(basename "$_sd")
        mkdir -p "$_skills_dir/$_sname"
        cp "$_sd/SKILL.md" "$_skills_dir/$_sname/SKILL.md"
        echo "  Copied skill: $_sname"
      done
      "$PYTHON" "$_scripts/deploy_skills.py" "$_manifest" "$REPO_ROOT/src/claude-desktop/skills"
    fi
  fi
  unset _claude_app _ops_file _account_id _plugin_dir _plugin_uuid _skills_base _skills_dir _manifest _sd _sname
fi

# ── Merge dotfiles-managed configs into app-owned live files ─────────────
# dotter renders these to private staging files because it can't own the live
# files: the apps rewrite them at runtime and/or post_deploy injects secrets,
# so dotter always sees them as externally modified and skips. Merge the
# dotfiles content in, preserving runtime state and post-deploy-injected
# secrets (those live only in keys absent from the rendered template).
# Only Claude Desktop's mcpServers is fully replaced (--replace) so removed
# servers disappear; it carries no post-deploy secret (its only token is
# rendered from a Handlebars variable). The others must NOT use --replace or a
# deploy without secret access would blank their injected tokens.
_merge_config() {
  _rendered="$1"
  _live="$2"
  shift 2
  [ -f "$_rendered" ] && command -v "$PYTHON" >/dev/null 2>&1 || return 0
  "$PYTHON" "$_scripts/merge_json_config.py" "$_rendered" "$_live" "$@" \
    || echo "  WARNING: Failed to merge $(basename "$_live")"
}
echo "Merging dotfiles-managed app configs..."
_merge_config "$HOME/.cache/dotfiles/claude_desktop_config.rendered.json" \
  "$HOME/Library/Application Support/Claude/claude_desktop_config.json" \
  --replace mcpServers
_merge_config "$HOME/.cache/dotfiles/claude_code_settings.rendered.json" \
  "$HOME/.claude/settings.json"
_merge_config "$HOME/.cache/dotfiles/opencode.rendered.jsonc" \
  "$HOME/.config/opencode/opencode.jsonc"
unset -f _merge_config
unset _rendered _live

# ── Secret injection ─────────────────────────────────────────────────────
_SECRET_CACHE=""

# Check if a cache file is fresh (< 1 hour old)
_cache_is_fresh() {
  local file="$1"
  [ -f "$file" ] || return 1
  local mtime_epoch
  if [ "$(uname -s)" = "Darwin" ]; then
    mtime_epoch=$(stat -f %m "$file" 2>/dev/null)
  else
    mtime_epoch=$(stat -c %Y "$file" 2>/dev/null)
  fi
  [ -n "$mtime_epoch" ] || return 1
  local age=$(( $(date +%s) - mtime_epoch ))
  [ "$age" -lt 3600 ]
}

# Try to ensure a backend's cache is ready. Sets _SECRET_CACHE on success.
_try_backend() {
  local script="$1" cache="$2"
  [ -x "$script" ] && "$script" --configured >/dev/null 2>&1 || return 1
  if _cache_is_fresh "$cache"; then
    _SECRET_CACHE="$cache"
    return 0
  fi
  "$script" --build >/dev/null 2>&1 && { _SECRET_CACHE="$cache"; return 0; }
  return 1
}

_ensure_secret_cache() {
  _try_backend "$HOME/.config/opencode/script/proton-pass-env.sh" "$HOME/.cache/proton-pass-secrets.env" && return 0
  _try_backend "$HOME/.config/opencode/script/macos-keychain-env.sh" "$HOME/.cache/macos-keychain-secrets.env" && return 0
  echo "WARNING: No secret backend available; secrets will not be injected." >&2
  return 1
}

_lookup_secret() {
  local target="$1"
  while IFS=$(printf '\t') read -r key value _enc; do
    [ "$key" = "$target" ] && { printf '%s' "$value"; return 0; }
  done < "$_SECRET_CACHE"
  return 1
}

_inject_github_token() {
  local config_file="$1"
  # Missing file or absent token means "nothing to inject here" — not an error.
  # A bare `return` would propagate the failing test's status (1) and, because
  # this function is called as a bare statement under `set -e`, abort the hook.
  [ -f "$config_file" ] || return 0
  local token
  token=$(_lookup_secret "GITHUB_PERSONAL_ACCESS_TOKEN") || return 0
  echo "  Injecting GitHub token into $(basename "$config_file")..."
  "$PYTHON" -c "
import json, sys
cfg_path = '$config_file'
with open(cfg_path, 'r') as f:
    cfg = json.load(f)
gh = cfg.get('mcpServers', {}).get('GitHub')
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

  # OpenCode MCP config
  _opencode_config="$HOME/.config/opencode/opencode.jsonc"
  if [ -f "$_opencode_config" ] && command -v "$PYTHON" >/dev/null 2>&1; then
    _patch_args=""
    _tok=$(_lookup_secret "GITHUB_PERSONAL_ACCESS_TOKEN") && _patch_args="$_patch_args --github-token $_tok"
    _tok=$(_lookup_secret "GITLAB_TOKEN") && _patch_args="$_patch_args --gitlab-token $_tok"
    _tok=$(_lookup_secret "POSTMAN_API_KEY") && _patch_args="$_patch_args --postman-token $_tok"
    _tok=$(_lookup_secret "SONAR_TOKEN") && _patch_args="$_patch_args --sonar-token $_tok"
    _tok=$(_lookup_secret "HA_TOKEN") && _patch_args="$_patch_args --ha-token $_tok"
    _tok=$(_lookup_secret "MCP_OBSIDIAN_TOKEN") && _patch_args="$_patch_args --obsidian-token $_tok"
    if [ -n "$_patch_args" ]; then
      echo "  Patching OpenCode MCP config..."
      "$PYTHON" "$_scripts/patch_opencode_secrets.py" "$_opencode_config" $_patch_args 2>/dev/null || echo "  WARNING: Failed to patch OpenCode config"
    fi
    unset _patch_args _tok
  fi
  unset _opencode_config

  # Shared env.toml secret injection
  _deployed_env="$DEPLOYED/shared/env.toml"
  if [ -f "$_deployed_env" ]; then
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
      _tmp="${_deployed_env}.tmp.$$"
      if grep -q "^$_placeholder = \"\"" "$_deployed_env" 2>/dev/null; then
        sed "s/^$_placeholder = \"\"/$_placeholder = \"$_val\"/" "$_deployed_env" > "$_tmp" && mv "$_tmp" "$_deployed_env"
        echo "  Injected $_placeholder into env.toml"
      elif grep -q "^$_placeholder = \"\x7b\x7b.*\"" "$_deployed_env" 2>/dev/null; then
        sed "s|^$_placeholder = \"\x7b\x7b.*\"|$_placeholder = \"$_val\"|" "$_deployed_env" > "$_tmp" && mv "$_tmp" "$_deployed_env"
        echo "  Injected $_placeholder into env.toml"
      fi
      rm -f "$_tmp"
    done
    unset _mapping _env_var _placeholder _val
  fi
  unset _deployed_env
fi
unset -f _ensure_secret_cache _lookup_secret _inject_github_token _try_backend _cache_is_fresh
unset _SECRET_CACHE

# ── Post-deploy validation ────────────────────────────────────────────────
if [ -d "$REPO_ROOT" ]; then
  REPO_ROOT="$REPO_ROOT" "$_scripts/validate_schema.sh" --post-deploy || exit 1
fi

# ── OpenCode MCP health check ────────────────────────────────────────────
if command -v opencode >/dev/null 2>&1 && [ -f "$DEPLOYED/opencode/opencode.jsonc" ]; then
  echo "Checking OpenCode MCP servers..."
  mcp_out=$(mktemp)
  mcp_err=$(mktemp)

  if ! run_with_timeout 30 opencode mcp list > "$mcp_out" 2> "$mcp_err"; then
    echo "WARNING: opencode mcp list command failed or timed out" >&2
    [ -s "$mcp_err" ] && cat "$mcp_err" >&2
  else
    if command -v perl >/dev/null 2>&1; then
      mcp_clean=$(perl -pe 's/\e\[[0-9;]*m//g' < "$mcp_out")
    else
      mcp_clean=$(cat "$mcp_out")
    fi

    total=$(echo "$mcp_clean" | awk 'BEGIN{c=0} /^[[:space:]]*●[[:space:]]+[✓✗]/ {c++} END {print c}')
    connected=$(echo "$mcp_clean" | awk 'BEGIN{c=0} /^[[:space:]]*●[[:space:]]+✓/ {c++} END {print c}')
    failed=$(echo "$mcp_clean" | awk 'BEGIN{c=0} /^[[:space:]]*●[[:space:]]+✗/ {c++} END {print c}')
    : "${total:=0}" "${connected:=0}" "${failed:=0}"

    [ "$failed" -gt 0 ] && echo "WARNING: $failed MCP server(s) failed" >&2
    if [ "$total" -gt 0 ]; then
      echo "  OpenCode MCPs: $connected/$total connected"
    fi
  fi
  rm -f "$mcp_out" "$mcp_err"
fi

# ── Lua validation ────────────────────────────────────────────────────────
if [ -d "$DEPLOYED/nvim" ] && command -v luac >/dev/null 2>&1; then
  echo "Validating Lua files..."
  _failed=0
  find "$DEPLOYED/nvim" -name '*.lua' -type f 2>/dev/null | while IFS= read -r _lua_file; do
    if ! luac -p "$_lua_file" >/dev/null 2>&1; then
      echo "ERROR: Lua syntax error in $_lua_file" >&2
      _failed=1
    fi
  done
  # Note: subshell pipe means _failed won't propagate; use explicit check
  if find "$DEPLOYED/nvim" -name '*.lua' -type f -exec luac -p {} \; 2>&1 | grep -q "error"; then
    exit 1
  fi
  echo "  All Lua files OK"
fi

# ── Neovim startup test ──────────────────────────────────────────────────
if command -v nvim >/dev/null 2>&1 && [ -d "$DEPLOYED/nvim" ]; then
  echo "Testing Neovim startup..."
  run_with_timeout 60 nvim --headless +qa! 2>/tmp/nvim-startup.log || true

  if grep -E '^E[0-9]+:|Error while calling lua chunk|Error loading plugin config' /tmp/nvim-startup.log 2>/dev/null \
       | grep -v 'image\.nvim\|image\.lua\|image/backends\|terminal size\|non-terminal' \
       | grep -q .; then
    echo "ERROR: Neovim startup errors detected:" >&2
    cat /tmp/nvim-startup.log >&2
    exit 1
  fi
  echo "  Neovim startup OK"

  # LSP validation
  if [ -f "$_scripts/validate_lsp.lua" ]; then
    echo "Validating LSP attachments..."
    lsp_out=$(mktemp)
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
vim/lsp/client.lua:
vim/_core/editor.lua: in function
filetype.lua:27:
validate_lsp.lua:
python3_provider
g:loaded_python3_provider
provider: python3: missing
LSP_FILTERS
    run_with_timeout 300 nvim --headless -c "luafile $_scripts/validate_lsp.lua" -c "qa!" 2>"$lsp_out" >/dev/null || true
    if command -v perl >/dev/null 2>&1; then
      perl -pe 's/\e\[[0-9;]*m//g' < "$lsp_out" | grep -Fv -f "$lsp_ignore" | grep -v '^\s*$' || true
    else
      cat "$lsp_out" | grep -Fv -f "$lsp_ignore" | grep -v '^\s*$' || true
    fi
    rm -f "$lsp_out" "$lsp_ignore"
  fi
fi

echo "==> Post-deploy validation complete."
