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

_STEP "Post-deploy: linking commands and deploying skills"

# ── OpenCode command symlinks ─────────────────────────────────────────────
_oc_cmd="$HOME/.config/opencode/command"
mkdir -p "$_oc_cmd"
for _cmd in go.md fix-pipeline.md coderabbit-review.md; do
  ln -sf "$HOME/.claude/commands/$_cmd" "$_oc_cmd/$_cmd"
done
unset _oc_cmd _cmd
_OK "Linked OpenCode command symlinks"

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
      _INFO "Deploying Claude Desktop skills"
      for _sd in "$REPO_ROOT/src/claude-desktop/skills"/*/; do
        [ -d "$_sd" ] || continue
        _sname=$(basename "$_sd")
        mkdir -p "$_skills_dir/$_sname"
        cp "$_sd/SKILL.md" "$_skills_dir/$_sname/SKILL.md"
        _INFO "Copied skill: $_sname"
      done
      "$PYTHON" "$_scripts/deploy_skills.py" "$_manifest" "$REPO_ROOT/src/claude-desktop/skills"
    fi
  fi
  unset _claude_app _ops_file _account_id _plugin_dir _plugin_uuid _skills_base _skills_dir _manifest _sd _sname
fi

# ── OpenCode plugins (conditional on installed commands) ─────────────────
# Deploy adrafinil plugin only when the `adrafinil` command is present on PATH.
_oc_plugins="$HOME/.config/opencode/plugins"
mkdir -p "$_oc_plugins"
if command -v adrafinil >/dev/null 2>&1; then
  ln -sf "$REPO_ROOT/src/opencode/plugins/adrafinil.ts" "$_oc_plugins/adrafinil.ts"
else
  rm -f "$_oc_plugins/adrafinil.ts"
fi
unset _oc_plugins

_STEP "Post-deploy: merging app configs"

# ── Merge dotfiles-managed configs into app-owned live files ─────────────
# dotter renders these to private staging files because it can't own the live
# files: the apps rewrite them at runtime and/or post_deploy injects secrets,
# so dotter always sees them as externally modified and skips. Merge the
# dotfiles content in, preserving runtime state and post-deploy-injected
# secrets (those live only in keys absent from the rendered template).
# Claude Desktop's and Claude Code's mcpServers are fully replaced (--replace)
# so servers removed upstream disappear; both render every value from Handlebars
# variables (no post-deploy secret lives only in the live file), which is what
# makes --replace safe. OpenCode's mcp key is also fully rendered with
# Handlebars-conditional servers (disabled servers are literally omitted), and
# patch_opencode_secrets.py re-injects tokens afterward, so --replace mcp is
# safe and required for "exclude means omit". The others must NOT use --replace
# or a deploy without secret access would blank their injected tokens.
# Claude Code reads user-global MCP servers from ~/.claude.json, NOT from
# settings.json, so the rendered mcp.json is merged into ~/.claude.json.
_merge_config() {
  _rendered="$1"
  _live="$2"
  shift 2
  [ -f "$_rendered" ] && command -v "$PYTHON" >/dev/null 2>&1 || return 0
  "$PYTHON" "$_scripts/merge_json_config.py" "$_rendered" "$_live" "$@" \
    || _WARN "Failed to merge $(basename "$_live")"
}
_merge_config "$HOME/.cache/dotfiles/claude_desktop_config.rendered.json" \
  "$HOME/Library/Application Support/Claude/claude_desktop_config.json" \
  --replace mcpServers
_merge_config "$HOME/.cache/dotfiles/claude_code_settings.rendered.json" \
  "$HOME/.claude/settings.json"
_merge_config "$HOME/.cache/dotfiles/claude_code_mcp.rendered.json" \
  "$HOME/.claude.json" \
  --replace mcpServers
_merge_config "$HOME/.cache/dotfiles/opencode.rendered.jsonc" \
  "$HOME/.config/opencode/opencode.jsonc" \
  --replace mcp
unset -f _merge_config
unset _rendered _live

_STEP "Post-deploy: injecting secrets"

# ── Secret injection ─────────────────────────────────────────────────────
_SECRET_CACHE=""
_LAST_BACKEND_ERR=""

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

# Check if the macOS login keychain is locked. Returns 0 if unlocked, 1 if locked.
# `security show-keychain-info` fails with rc=36 when the keychain is locked
# and succeeds (rc=0) when unlocked — this is the most reliable probe.
_keychain_is_unlocked() {
  [ "$(uname -s)" = "Darwin" ] || return 0
  security show-keychain-info ~/Library/Keychains/login.keychain-db >/dev/null 2>&1
}

# Attempt to unlock the keychain non-interactively (works if the keychain
# password is cached in the system). Returns 0 on success.
# Uses a short timeout to avoid hanging on a password prompt in headless contexts.
_try_unlock_keychain() {
  [ "$(uname -s)" = "Darwin" ] || return 0
  # `security unlock-keychain` without -p prompts for the password. On macOS
  # with TouchID/Keychain cached, this can succeed without user input. In a
  # headless context it would hang — the 5s timeout prevents that.
  if run_with_timeout 5 security unlock-keychain >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

# Run a secret backend's --build, adapting to interactive vs headless context.
# - Interactive (stdin is a TTY): no timeout, no capture — let the vault unlock
#   prompt reach the user so they can type their password.
# - Headless (stdin not a TTY, e.g. CI/cron): 15s timeout + capture stderr for
#   diagnostics, so a hanging prompt fails fast with actionable guidance.
# Sets _SECRET_CACHE on success, _LAST_BACKEND_ERR on failure.
_build_backend() {
  local script="$1" cache="$2"
  if [ -t 0 ]; then
    "$script" --build && { _SECRET_CACHE="$cache"; return 0; }
    _LAST_BACKEND_ERR="build failed (see output above)"
    return 1
  fi
  local _err
  _err=$(run_with_timeout 15 "$script" --build 2>&1 >/dev/null) && { _SECRET_CACHE="$cache"; return 0; }
  _LAST_BACKEND_ERR="$_err"
  return 1
}

# Try to ensure a backend's cache is ready. Sets _SECRET_CACHE on success.
# On failure, captures stderr and returns 1 (caller decides what to do).
_try_backend() {
  local script="$1" cache="$2"
  [ -x "$script" ] && "$script" --configured >/dev/null 2>&1 || return 1
  if _cache_is_fresh "$cache"; then
    _SECRET_CACHE="$cache"
    return 0
  fi

  # Proton Pass needs the macOS keychain unlocked to access its encryption key.
  # Detect this before calling --build so we get a clear, actionable message
  # instead of a cascade of "pass-cli view failed" warnings.
  local _backend_name
  _backend_name="$(basename "$script" .sh)"
  if [ "$_backend_name" = "proton-pass-env" ] && [ "$(uname -s)" = "Darwin" ]; then
    if ! _keychain_is_unlocked; then
      _LAST_BACKEND_ERR="KEYCHAIN_LOCKED"
      begin_wait "Building secret cache ($_backend_name)" "up to 1 min; may prompt to unlock"
      if _try_unlock_keychain && _keychain_is_unlocked; then
        _build_backend "$script" "$cache" && return 0
      else
        return 1
      fi
    fi
  fi

  begin_wait "Building secret cache ($_backend_name)" "up to 1 min; may prompt to unlock"
  _build_backend "$script" "$cache"
}

# Diagnose a backend failure and print actionable guidance.
# Args: $1 = display name (e.g. "Proton Pass"), $2 = full script path.
# Returns 0 if the user resolved the issue (caller should retry), 1 if not.
_diagnose_backend_failure() {
  local display_name="$1" script_path="$2" err="${_LAST_BACKEND_ERR:-}"

  # Keychain was locked and we couldn't unlock it non-interactively
  if [ "$err" = "KEYCHAIN_LOCKED" ]; then
    echo "" >&2
    _WARN "The macOS keychain is locked, blocking $display_name from accessing its encryption key."
    # Try to unlock (non-interactive; works if keychain password is cached)
    if _try_unlock_keychain && _keychain_is_unlocked; then
      _INFO "Keychain unlocked. Retrying..." >&2
      return 0
    fi
    _ERR "Could not unlock keychain automatically."
    _GUIDE "Run this in a terminal, then re-deploy: security unlock-keychain"
    return 1
  fi

  # Keychain backend: no secrets found (check this before the generic "No secrets" pattern)
  if printf '%s' "$err" | grep -q "No secrets were fetched from macOS Keychain"; then
    _WARN "$display_name found no secrets in macOS Keychain."
    _GUIDE "Secrets may not have been stored yet, or the keychain is locked."
    _GUIDE "Check: security unlock-keychain && $script_path --build"
    return 1
  fi

  # Proton Pass: vault locked / no secrets fetched
  if printf '%s' "$err" | grep -q "No secrets were fetched"; then
    _WARN "$display_name could not fetch any secrets from the vault."
    _GUIDE "The vault may be locked or items are missing/misnamed. To fix:"
    _GUIDE "1. Run: $script_path --build"
    _GUIDE "2. Unlock the vault when prompted"
    _GUIDE "3. Re-run deploy"
    return 1
  fi

  # Timeout: --build was killed (likely waiting for vault unlock prompt)
  if printf '%s' "$err" | grep -q "Fetching secrets from Proton Pass"; then
    _WARN "$display_name timed out waiting for the Proton Pass vault to unlock."
    _GUIDE "To fix:"
    _GUIDE "1. Run: $script_path --build"
    _GUIDE "2. Enter your Proton Pass password when prompted"
    _GUIDE "3. Re-run deploy (the cache will be fresh for 1 hour)"
    return 1
  fi

  # Generic fallback
  _WARN "$display_name failed to build its secret cache."
  [ -n "$err" ] && printf '%s\n' "$err" | sed 's/^/    /' >&2
  return 1
}

_ensure_secret_cache() {
  local _pp_script="$REPO_ROOT/scripts/secrets/proton-pass-env.sh"
  local _kc_script="$REPO_ROOT/scripts/secrets/macos-keychain-env.sh"
  _try_backend "$_pp_script" "$HOME/.cache/proton-pass-secrets.env" && return 0
  if _diagnose_backend_failure "Proton Pass" "$_pp_script"; then
    # Keychain was unlocked; retry once
    _try_backend "$_pp_script" "$HOME/.cache/proton-pass-secrets.env" && return 0
  fi
  _try_backend "$_kc_script" "$HOME/.cache/macos-keychain-secrets.env" && return 0
  _diagnose_backend_failure "macOS Keychain" "$_kc_script" || true
  _WARN "No secret backend available; secrets will not be injected."
  return 1
}

_lookup_secret() {
  local target="$1"
  while IFS=$(printf '\t') read -r key value _enc; do
    [ "$key" = "$target" ] && { printf '%s' "$value"; return 0; }
  done < "$_SECRET_CACHE"
  return 1
}

# GitHub token from gh CLI (preferred over secrets store)
_gh_token() {
  command -v gh >/dev/null 2>&1 || return 1
  gh auth token 2>/dev/null
}

_inject_github_token() {
  local config_file="$1"
  # Missing file or absent token means "nothing to inject here" — not an error.
  # A bare `return` would propagate the failing test's status (1) and, because
  # this function is called as a bare statement under `set -e`, abort the hook.
  [ -f "$config_file" ] || return 0
  local token
  token=$(_gh_token) || return 0
  _INFO "Injecting GitHub token into $(basename "$config_file")"
  _NO_COLOR=""
  [ -z "${NO_COLOR:-}" ] || _NO_COLOR=1
  NO_COLOR="$_NO_COLOR" "$PYTHON" -c "
import json, os, sys
_G = '\033[32m' if sys.stdout.isatty() and not os.environ.get('NO_COLOR') else ''
_Y = '\033[33m' if sys.stdout.isatty() and not os.environ.get('NO_COLOR') else ''
_X = '\033[0m' if _G or _Y else ''
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
    print(f'  {_G}✓{_X} GitHub token injected')
else:
    print(f'  {_Y}⊘{_X} SKIP: GitHub MCP not found')
" 2>/dev/null || _WARN "Failed to patch $(basename "$config_file")"
  unset _NO_COLOR
}

# Patch the Obsidian MCP bearer token into a Claude config's env. The template
# renders env.MCP_OBSIDIAN_AUTH as "Bearer " (token kept out of the repo), so the
# real value is injected here from the secret cache.
_inject_obsidian_token() {
  local config_file="$1"
  [ -f "$config_file" ] || return 0
  local token
  token=$(_lookup_secret "MCP_OBSIDIAN_TOKEN") || return 0
  _INFO "Injecting Obsidian token into $(basename "$config_file")"
  _NO_COLOR=""
  [ -z "${NO_COLOR:-}" ] || _NO_COLOR=1
  NO_COLOR="$_NO_COLOR" "$PYTHON" -c "
import json, os, sys
_G = '\033[32m' if sys.stdout.isatty() and not os.environ.get('NO_COLOR') else ''
_Y = '\033[33m' if sys.stdout.isatty() and not os.environ.get('NO_COLOR') else ''
_X = '\033[0m' if _G or _Y else ''
cfg_path = '$config_file'
with open(cfg_path, 'r') as f:
    cfg = json.load(f)
obs = cfg.get('mcpServers', {}).get('Obsidian')
if obs:
    env = obs.setdefault('env', {})
    env['MCP_OBSIDIAN_AUTH'] = 'Bearer $token'
    with open(cfg_path, 'w') as f:
        json.dump(cfg, f, indent=2)
    print(f'  {_G}✓{_X} Obsidian token injected')
else:
    print(f'  {_Y}⊘{_X} SKIP: Obsidian MCP not found')
" 2>/dev/null || _WARN "Failed to patch $(basename "$config_file")"
  unset _NO_COLOR
}

# GitHub token injection — uses `gh auth token` directly (no secrets store needed)
_inject_github_token "$HOME/Library/Application Support/Claude/claude_desktop_config.json"
_inject_github_token "$HOME/Library/Application Support/Claude/settings.json"

if _ensure_secret_cache; then
  _inject_obsidian_token "$HOME/Library/Application Support/Claude/claude_desktop_config.json"
  _inject_obsidian_token "$HOME/.claude.json"

  # OpenCode MCP config
  _opencode_config="$HOME/.config/opencode/opencode.jsonc"
  if [ -f "$_opencode_config" ] && command -v "$PYTHON" >/dev/null 2>&1; then
    _patch_args=""
    _tok=$(_gh_token) && _patch_args="$_patch_args --github-token $_tok"
    _tok=$(_lookup_secret "GITLAB_TOKEN") && _patch_args="$_patch_args --gitlab-token $_tok"
    _tok=$(_lookup_secret "POSTMAN_API_KEY") && _patch_args="$_patch_args --postman-token $_tok"
    _tok=$(_lookup_secret "SONAR_TOKEN") && _patch_args="$_patch_args --sonar-token $_tok"
    _tok=$(_lookup_secret "HA_TOKEN") && _patch_args="$_patch_args --ha-token $_tok"
    _tok=$(_lookup_secret "MCP_OBSIDIAN_TOKEN") && _patch_args="$_patch_args --obsidian-token $_tok"
    if [ -n "$_patch_args" ]; then
      _INFO "Patching OpenCode MCP config"
      "$PYTHON" "$_scripts/patch_opencode_secrets.py" "$_opencode_config" $_patch_args 2>/dev/null || _WARN "Failed to patch OpenCode config"
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
        _INFO "Injected $_placeholder into env.toml"
      elif grep -q "^$_placeholder = \"\x7b\x7b.*\"" "$_deployed_env" 2>/dev/null; then
        sed "s|^$_placeholder = \"\x7b\x7b.*\"|$_placeholder = \"$_val\"|" "$_deployed_env" > "$_tmp" && mv "$_tmp" "$_deployed_env"
        _INFO "Injected $_placeholder into env.toml"
      fi
      rm -f "$_tmp"
    done
    unset _mapping _env_var _placeholder _val
  fi
  unset _deployed_env
fi
unset -f _ensure_secret_cache _lookup_secret _inject_github_token _inject_obsidian_token _try_backend _cache_is_fresh _keychain_is_unlocked _try_unlock_keychain _diagnose_backend_failure
unset _SECRET_CACHE

_STEP "Post-deploy: schema validation"

# ── Post-deploy validation ────────────────────────────────────────────────
if [ -d "$REPO_ROOT" ]; then
  REPO_ROOT="$REPO_ROOT" "$_scripts/validate_schema.sh" --post-deploy || exit 1
fi

_STEP "Post-deploy: MCP health checks"

# ── OpenCode MCP health check ────────────────────────────────────────────
if command -v opencode >/dev/null 2>&1 && [ -f "$DEPLOYED/opencode/opencode.jsonc" ]; then
  begin_wait "Checking OpenCode MCP servers" "up to 30s"
  mcp_out=$(mktemp)
  mcp_err=$(mktemp)

  if ! run_with_timeout 30 opencode mcp list > "$mcp_out" 2> "$mcp_err"; then
    _WARN "opencode mcp list command failed or timed out"
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

    [ "$failed" -gt 0 ] && _WARN "$failed MCP server(s) failed"
    if [ "$total" -gt 0 ]; then
      _OK "OpenCode MCPs: $connected/$total connected"
    fi
  fi
  rm -f "$mcp_out" "$mcp_err"
fi

# ── Claude Code MCP health check ─────────────────────────────────────────
# Mirrors the OpenCode check above for the servers we deploy to ~/.claude.json.
# `claude mcp list` health-checks every server and can hang on a slow/broken
# one, so it runs under a hard timeout and a failure/timeout is a non-fatal
# WARNING (never aborts the deploy).
if command -v claude >/dev/null 2>&1 && [ -f "$HOME/.claude.json" ]; then
  begin_wait "Checking Claude Code MCP servers" "up to 90s"
  cc_mcp_out=$(mktemp)
  cc_mcp_err=$(mktemp)

  # Run from $HOME so only user-global servers are checked, not a project's
  # local .mcp.json that might exist in the deploy working directory. The
  # timeout is generous: cold `npx`/`docker` startups plus remote/OAuth servers
  # can be slow, and a too-short limit yields a spurious "timed out" warning.
  if ! ( cd "$HOME" && run_with_timeout 90 claude mcp list ) > "$cc_mcp_out" 2> "$cc_mcp_err"; then
    _WARN "claude mcp list command failed or timed out"
    [ -s "$cc_mcp_err" ] && cat "$cc_mcp_err" >&2
  else
    if command -v perl >/dev/null 2>&1; then
      cc_mcp_clean=$(perl -pe 's/\e\[[0-9;]*m//g' < "$cc_mcp_out")
    else
      cc_mcp_clean=$(cat "$cc_mcp_out")
    fi

    # Match on the status words, not the glyphs: `claude mcp list` renders the
    # status as "Connected", "Failed to connect", or "Needs authentication"
    # (an expected state for OAuth servers the user has not logged into), and
    # the exact ✔/✘/! glyphs vary by version.
    cc_connected=$(echo "$cc_mcp_clean" | awk 'BEGIN{c=0} /Connected/ {c++} END {print c}')
    cc_failed=$(echo "$cc_mcp_clean" | awk 'BEGIN{c=0} /Failed to connect/ {c++} END {print c}')
    cc_auth=$(echo "$cc_mcp_clean" | awk 'BEGIN{c=0} /Needs authentication/ {c++} END {print c}')
    : "${cc_connected:=0}" "${cc_failed:=0}" "${cc_auth:=0}"
    cc_total=$((cc_connected + cc_failed + cc_auth))

    [ "$cc_failed" -gt 0 ] && _WARN "$cc_failed Claude Code MCP server(s) failed"
    if [ "$cc_total" -gt 0 ]; then
      if [ "$cc_auth" -gt 0 ]; then
        _OK "Claude Code MCPs: $cc_connected/$cc_total connected ($cc_auth need auth)"
      else
        _OK "Claude Code MCPs: $cc_connected/$cc_total connected"
      fi
    fi
  fi
  rm -f "$cc_mcp_out" "$cc_mcp_err"
fi

_STEP "Post-deploy: Neovim validation"

# ── Lua validation ────────────────────────────────────────────────────────
if [ -d "$DEPLOYED/nvim" ] && command -v luac >/dev/null 2>&1; then
  _STEP "Validating Lua files"
  # Single pass: collect failures via a temp marker (the while loop runs in a
  # subshell, so a plain variable wouldn't survive the pipe).
  _lua_errs=$(mktemp)
  find "$DEPLOYED/nvim" -name '*.lua' -type f 2>/dev/null | while IFS= read -r _lua_file; do
    if ! luac -p "$_lua_file" >/dev/null 2>&1; then
      _ERR "Lua syntax error in $_lua_file"
      echo x >> "$_lua_errs"
    fi
  done
  if [ -s "$_lua_errs" ]; then
    rm -f "$_lua_errs"
    exit 1
  fi
  rm -f "$_lua_errs"
  _OK "All Lua files valid"
fi

# ── Neovim startup test ──────────────────────────────────────────────────
if command -v nvim >/dev/null 2>&1 && [ -d "$DEPLOYED/nvim" ]; then
  begin_wait "Testing Neovim startup" "up to 1 min"
  run_with_timeout 60 nvim --headless +qa! 2>/tmp/nvim-startup.log || true

  if grep -E '^E[0-9]+:|Error while calling lua chunk|Error loading plugin config' /tmp/nvim-startup.log 2>/dev/null \
       | grep -v 'image\.nvim\|image\.lua\|image/backends\|terminal size\|non-terminal' \
       | grep -q .; then
    _ERR "Neovim startup errors detected:"
    cat /tmp/nvim-startup.log >&2
    exit 1
  fi
  _OK "Neovim startup"

  # LSP validation
  if [ -f "$_scripts/validate_lsp.lua" ]; then
    begin_wait "Validating LSP attachments" "up to 5 min"
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
vim/lsp/client
vim/_core/editor
[string "vim/_core/editor"]
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

_STEP "Post-deploy validation complete"
