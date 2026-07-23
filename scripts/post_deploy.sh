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
# `agent` and `lsp` are rendered completely from the dotfiles (models resolve
# via Handlebars at render time; no post-deploy secret injection), so replace
# them wholesale — otherwise entries removed/renamed in the KCL roster linger
# in the live file forever via the deep-merge (e.g. the stale `lua_ls` key
# that survived the lua_ls -> lua-ls rename).
_merge_config "$HOME/.cache/dotfiles/opencode.rendered.json" \
  "$HOME/.config/opencode/opencode.json" \
  --replace mcp --replace provider --replace agent --replace lsp
unset -f _merge_config
unset _rendered _live

# ── Adrafinil hooks (Claude Code) ─────────────────────────────────────────
# Re-assert adrafinil's acquire/release hooks in ~/.claude/settings.json AFTER
# the merge above. These are not rendered from the dotfiles — adrafinil owns its
# own hook definitions and installs them idempotently (each entry carries an
# `_adrafinil` marker, so re-running never duplicates and leaves other hooks,
# e.g. bartender's, intact). Running here — after the settings merge — is what
# makes them survive: a bartender-enabled merge replaces the shared hook arrays
# (UserPromptSubmit/Stop/Notification) wholesale and would otherwise drop
# adrafinil's entries. Gated on the command being present, mirroring the
# OpenCode adrafinil plugin above; a no-op on machines without adrafinil.
if command -v adrafinil >/dev/null 2>&1; then
  if adrafinil install-hooks --tool claude-code >/dev/null 2>&1; then
    _OK "Ensured adrafinil hooks in Claude Code settings"
  else
    _WARN "Failed to install adrafinil hooks into Claude Code settings"
  fi
fi

_STEP "Post-deploy: injecting secrets"

# ── Secret injection (consume-only) ──────────────────────────────────────
# Deploys never build a secret cache inline — building (with its vault-unlock
# prompts, network fetches, and headless timeouts) lives in
# scripts/secrets/seed-secrets.sh. Here we use whichever cache already exists;
# a stale cache is still used (secrets rarely rotate — stale beats none), it
# just earns a refresh hint. One exception keeps fresh-machine bootstrap
# working: an interactive deploy with NO cache at all delegates to the seed
# script once.
_SECRET_CACHE=""
_SECRET_CACHE_MAX_AGE_HOURS=72

# Check if a cache file is fresh (< _SECRET_CACHE_MAX_AGE_HOURS old).
# Freshness is advisory: it only gates the refresh hint below.
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
  [ "$age" -lt $(( _SECRET_CACHE_MAX_AGE_HOURS * 3600 )) ]
}

# Locate an existing secret cache (Proton Pass preferred, then Keychain).
# Sets _SECRET_CACHE on success. Never builds — except the one-time
# interactive bootstrap when no cache exists at all.
_find_secret_cache() {
  local _pp_cache="$HOME/.cache/proton-pass-secrets.env"
  local _kc_cache="$HOME/.cache/macos-keychain-secrets.env"
  local _seed="$REPO_ROOT/scripts/secrets/seed-secrets.sh"
  local _c
  for _c in "$_pp_cache" "$_kc_cache"; do
    if [ -s "$_c" ]; then
      _SECRET_CACHE="$_c"
      if ! _cache_is_fresh "$_c"; then
        _INFO "Secret cache is older than ${_SECRET_CACHE_MAX_AGE_HOURS}h; refresh with: scripts/secrets/seed-secrets.sh"
      fi
      return 0
    fi
  done

  # Bootstrap: no cache anywhere. Interactive → seed once; headless → skip
  # fast with guidance (no timeouts, no retry loops).
  if [ -t 0 ] && [ -x "$_seed" ]; then
    _INFO "No secret cache found — running one-time seed (interactive)"
    "$_seed" || true
    for _c in "$_pp_cache" "$_kc_cache"; do
      [ -s "$_c" ] && { _SECRET_CACHE="$_c"; return 0; }
    done
  fi

  _WARN "No secret cache available; secrets will not be injected."
  _GUIDE "Seed it with: scripts/secrets/seed-secrets.sh"
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

# OpenCode MCP config — GitHub token injected first (doesn't need secret cache)
_opencode_config="$HOME/.config/opencode/opencode.json"
if [ -f "$_opencode_config" ] && command -v "$PYTHON" >/dev/null 2>&1; then
  _patch_args=""
  _tok=$(_gh_token) && _patch_args="$_patch_args --github-token $_tok"
  if [ -n "$_patch_args" ]; then
    _INFO "Patching OpenCode MCP config (GitHub token)"
    "$PYTHON" "$_scripts/patch_opencode_secrets.py" "$_opencode_config" $_patch_args 2>/dev/null || _WARN "Failed to patch OpenCode config (GitHub)"
  fi
  unset _patch_args _tok
fi

if _find_secret_cache; then
  _inject_obsidian_token "$HOME/Library/Application Support/Claude/claude_desktop_config.json"
  _inject_obsidian_token "$HOME/.claude.json"

  # OpenCode MCP config — remaining secrets (need secret cache)
  if [ -f "$_opencode_config" ] && command -v "$PYTHON" >/dev/null 2>&1; then
    _patch_args=""
    _tok=$(_lookup_secret "GITLAB_TOKEN") && _patch_args="$_patch_args --gitlab-token $_tok"
    _tok=$(_lookup_secret "POSTMAN_API_KEY") && _patch_args="$_patch_args --postman-token $_tok"
    _tok=$(_lookup_secret "SONAR_TOKEN") && _patch_args="$_patch_args --sonar-token $_tok"
    _tok=$(_lookup_secret "HA_TOKEN") && _patch_args="$_patch_args --ha-token $_tok"
    _tok=$(_lookup_secret "MCP_OBSIDIAN_TOKEN") && _patch_args="$_patch_args --obsidian-token $_tok"
    if [ -n "$_patch_args" ]; then
      _INFO "Patching OpenCode MCP config (remaining secrets)"
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
unset -f _find_secret_cache _lookup_secret _inject_github_token _inject_obsidian_token _cache_is_fresh
unset _SECRET_CACHE _SECRET_CACHE_MAX_AGE_HOURS

_STEP "Post-deploy: schema validation"

# ── Post-deploy validation ────────────────────────────────────────────────
if [ -d "$REPO_ROOT" ]; then
  REPO_ROOT="$REPO_ROOT" "$_scripts/validate_schema.sh" --post-deploy || exit 1
fi

# ── MCP health checks (backgrounded) ─────────────────────────────────────
# Both `mcp list` commands only read configs the merge/secret steps above
# already wrote, and share nothing with the Neovim validation below — so they
# run in the background while nvim does its much longer LSP attach pass, and
# their captured output is printed under the "MCP health checks" step at the
# end. COLOR_* was resolved when lib.sh was sourced, so the captured _OK/_WARN
# lines keep their colors. Timeouts are more generous than the old sequential
# ones (30s/90s) because the checks now compete with ~18 LSP server spawns
# (including the jorje JVM) for CPU and network.

_check_opencode_mcps() {
  mcp_out=$(mktemp)
  mcp_err=$(mktemp)

  if ! run_with_timeout 60 opencode mcp list > "$mcp_out" 2> "$mcp_err"; then
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
}

# Mirrors the OpenCode check for the servers we deploy to ~/.claude.json.
# `claude mcp list` health-checks every server and can hang on a slow/broken
# one, so it runs under a hard timeout and a failure/timeout is a non-fatal
# WARNING (never aborts the deploy). It runs from $HOME so only user-global
# servers are checked, not a project's local .mcp.json that might exist in
# the deploy working directory. The timeout is generous: cold `npx`/`docker`
# startups plus remote/OAuth servers can be slow, and a too-short limit
# yields a spurious "timed out" warning.
_check_claude_mcps() {
  cc_mcp_out=$(mktemp)
  cc_mcp_err=$(mktemp)

  if ! ( cd "$HOME" && run_with_timeout 120 claude mcp list ) > "$cc_mcp_out" 2> "$cc_mcp_err"; then
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
}

_oc_mcp_result=""; _oc_mcp_pid=""
_cc_mcp_result=""; _cc_mcp_pid=""
if command -v opencode >/dev/null 2>&1 && [ -f "$DEPLOYED/opencode/opencode.json" ]; then
  _oc_mcp_result=$(mktemp)
  _check_opencode_mcps > "$_oc_mcp_result" 2>&1 &
  _oc_mcp_pid=$!
fi
if command -v claude >/dev/null 2>&1 && [ -f "$HOME/.claude.json" ]; then
  _cc_mcp_result=$(mktemp)
  _check_claude_mcps > "$_cc_mcp_result" 2>&1 &
  _cc_mcp_pid=$!
fi
if [ -n "$_oc_mcp_pid$_cc_mcp_pid" ]; then
  _INFO "MCP health checks running in background — results after Neovim validation"
  # Reap the checks if an earlier validation aborts the deploy with exit 1
  # (their own hard timeouts bound the orphan window regardless).
  trap 'kill $_oc_mcp_pid $_cc_mcp_pid 2>/dev/null || true' EXIT
fi

_STEP "Post-deploy: Neovim validation"

# ── Lua validation ────────────────────────────────────────────────────────
if [ -d "$DEPLOYED/nvim" ] && command -v luac >/dev/null 2>&1; then
  _INFO "Validating Lua files"
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

# ── VSIX-distributed LSP servers ──────────────────────────────────────────
# Apex (jorje), Visualforce, and SonarLint ship only inside VS Code extension
# VSIXes. scripts/lsp_vsix_sync.sh fetches the pinned versions from Open VSX
# (plain zip archives — no VS Code involved) into ~/.local/share/lsp-servers/,
# which is where the Neovim configs point. Run before the LSP attach
# validation below so a broken fetch is visible in the same deploy. Advisory:
# offline with artifacts already present exits 0; a real failure warns here
# and then shows concretely as a missing server in the validation output.
_vsix_sync="$REPO_ROOT/scripts/lsp_vsix_sync.sh"
if [ -x "$_vsix_sync" ]; then
  _vsix_rc=0
  _vsix_out="$("$_vsix_sync" 2>&1)" || _vsix_rc=$?
  if [ "$_vsix_rc" -eq 0 ]; then
    _OK "VSIX LSP servers match the pinned versions"
  else
    printf '%s\n' "$_vsix_out" | grep -E '^  (STALE|FAILED)' | while read -r _l; do
      _WARN "VSIX LSP: $_l"
    done
    _GUIDE "scripts/lsp_vsix_sync.sh"
  fi
fi
unset _vsix_sync _vsix_out _vsix_rc

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

  # ── Neovim LSP attach validation ─────────────────────────────────────────
  # Live headless attach test for every enabled server (validate_lsp.lua);
  # the OpenCode/Claude Code rosters get their own step below.
  if [ -f "$_scripts/validate_lsp.lua" ]; then
    begin_wait "Validating Neovim LSP attachments" "up to 5 min"
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
sf_cache/test_result.json
SonarQube language server is ready
LWC Language Server shutting down
[lspconfig] Unable to find ESLint library.
LSP_FILTERS
    run_with_timeout 300 nvim --headless -c "luafile $_scripts/validate_lsp.lua" -c "qa!" 2>"$lsp_out" >/dev/null || true

    # Keep the full raw output around for troubleshooting — the display below
    # is filtered, so anything suppressed can still be inspected here.
    _lsp_log_dir="$HOME/.cache/dotfiles/logs"
    mkdir -p "$_lsp_log_dir"
    cp "$lsp_out" "$_lsp_log_dir/lsp-validation-raw.log" 2>/dev/null || true
    _lsp_stray="$_lsp_log_dir/lsp-validation-stray.log"
    : > "$_lsp_stray"

    if command -v perl >/dev/null 2>&1; then
      perl -pe 's/\e\[[0-9;]*m//g' < "$lsp_out" > "$lsp_out.clean"
    else
      cp "$lsp_out" "$lsp_out.clean"
    fi

    # Colorize the validation output (lib.sh palette; vars are empty when not
    # a TTY, so this is a no-op in logs/CI). Lines that are neither section
    # headers nor indented result rows are unexpected leakage: show them
    # dimmed, collect them in the stray log, and flag the count afterwards.
    grep -Fv -f "$lsp_ignore" "$lsp_out.clean" | grep -v '^[[:space:]]*$' \
      | awk -v g="$COLOR_GREEN" -v y="$COLOR_YELLOW" -v gy="$COLOR_GRAY" \
            -v b="$COLOR_BOLD" -v u="$COLOR_BLUE" -v r="$COLOR_RESET" \
            -v stray="$_lsp_stray" '
        /^==>/                { printf "%s%s%s%s\n", b, u, $0, r; next }
        index($0, "  ✓") == 1 { sub(/✓/, g "✓" r); print; next }
        index($0, "  ⚠") == 1 { sub(/⚠/, y "⚠" r); print; next }
        index($0, "  ⊘") == 1 { sub(/⊘/, gy "⊘" r); print; next }
        /^  /                 { print; next }
        { printf "%s%s%s\n", gy, $0, r; print > stray }
      ' || true

    if [ -s "$_lsp_stray" ]; then
      _WARN "$(grep -c . "$_lsp_stray") unexpected line(s) during LSP validation — see $_lsp_stray (raw: $_lsp_log_dir/lsp-validation-raw.log)"
    fi
    rm -f "$lsp_out" "$lsp_out.clean" "$lsp_ignore"
    unset _lsp_log_dir _lsp_stray
  fi
fi

_STEP "Post-deploy: agent LSP validation"

# ── Agent LSP validation (OpenCode + Claude Code) ─────────────────────────
# Binary/duplicate checks for the LSP rosters of both agent CLIs, plus a
# language × tool coverage matrix (Neovim column included for contrast).
if [ -f "$_scripts/validate_agent_lsp.py" ] && command -v "$PYTHON" >/dev/null 2>&1; then
  "$PYTHON" "$_scripts/validate_agent_lsp.py" || _WARN "Agent LSP validation failed"
fi

_STEP "Post-deploy: MCP health checks"

# ── MCP health check results ──────────────────────────────────────────────
# The checks were backgrounded before the Neovim validation; by now they have
# almost always finished, so the waits below block at most until the checks'
# own hard timeouts.
[ -n "$_oc_mcp_pid" ] && { wait "$_oc_mcp_pid" 2>/dev/null || true; }
[ -n "$_cc_mcp_pid" ] && { wait "$_cc_mcp_pid" 2>/dev/null || true; }
trap - EXIT
[ -n "$_oc_mcp_result" ] && { cat "$_oc_mcp_result"; rm -f "$_oc_mcp_result"; }
[ -n "$_cc_mcp_result" ] && { cat "$_cc_mcp_result"; rm -f "$_cc_mcp_result"; }
unset _oc_mcp_result _cc_mcp_result _oc_mcp_pid _cc_mcp_pid
unset -f _check_opencode_mcps _check_claude_mcps

_STEP "Post-deploy: GPG signing convergence"

# ── GPG: valid pinentry + warm passphrase cache (TTY-less signing) ────────
# detect_pinentry.sh runs pre-deploy; this validates the deployed result and
# (re)arms the warming trigger so signing never needs a TTY.
_gpg_conf="$HOME/.gnupg/gpg-agent.conf"
if [ -f "$_gpg_conf" ]; then
  _pinentry=$(sed -n 's/^pinentry-program[[:space:]]*//p' "$_gpg_conf" | tail -n 1)
  if [ -n "$_pinentry" ] && [ ! -x "$_pinentry" ]; then
    _WARN "gpg-agent.conf pinentry '$_pinentry' missing — GPG Suite's fixGpgHome will strip it at next login"
  else
    _OK "gpg-agent.conf pinentry is valid"
  fi
  unset _pinentry
  # Pick up conf changes without dropping the agent's passphrase cache.
  command -v gpgconf >/dev/null 2>&1 && gpgconf --reload gpg-agent 2>/dev/null || true
fi
if [ "$(uname)" = "Darwin" ]; then
  _gpg_plist="$HOME/Library/LaunchAgents/com.dotfiles.gpg-warm.plist"
  if [ -f "$_gpg_plist" ]; then
    # RunAtLoad=true → reloading also warms the cache right now.
    launchctl unload "$_gpg_plist" 2>/dev/null || true
    if launchctl load "$_gpg_plist" 2>/dev/null; then
      _OK "Loaded gpg-warm LaunchAgent"
    else
      _WARN "Could not load gpg-warm LaunchAgent (headless session?)"
    fi
  fi
  unset _gpg_plist
elif command -v systemctl >/dev/null 2>&1 \
  && [ -f "$HOME/.config/systemd/user/gpg-warm.timer" ]; then
  systemctl --user daemon-reload 2>/dev/null || true
  if systemctl --user enable --now gpg-warm.timer 2>/dev/null; then
    _OK "Enabled gpg-warm systemd timer"
  else
    _WARN "Could not enable gpg-warm timer (no user session bus?)"
  fi
fi
# Belt-and-suspenders for headless deploys where launchd/systemd is absent.
[ -x "$HOME/.local/bin/gpg-warm-agent" ] && "$HOME/.local/bin/gpg-warm-agent" || true
# CTA: the one manual step per machine — store the passphrase for warming.
gpg_warm_cta

_STEP "Post-deploy: GPU wired-memory limit"

# ── iogpu.wired_limit_mb (Apple Silicon only) ─────────────────────────────
# macOS caps GPU-wired unified memory at ~75% of RAM and resets it every boot.
# A machine running a local model that does not fit under that cap opts in via
# `iogpu_wired_limit_mb` in local.k; KCL renders a launchd daemon and this step
# installs it. Machines at the default render an empty plist and skip.
#
# Requires root, so this NEVER prompts inside a deploy: it applies the change
# only when sudo is already non-interactive, otherwise it prints the exact
# commands and moves on. A deploy must not block on a password.
_iogpu_label="tech.chanderson.iogpu-wired-limit"
_iogpu_src="$REPO_ROOT/out/launchd/$_iogpu_label.plist"
_iogpu_dst="/Library/LaunchDaemons/$_iogpu_label.plist"

if [ "$(uname)" = "Darwin" ] && [ -s "$_iogpu_src" ]; then
  _iogpu_want=$(sed -n 's/.*iogpu\.wired_limit_mb=\([0-9]*\).*/\1/p' "$_iogpu_src" | head -n 1)
  _iogpu_total=$(( $(sysctl -n hw.memsize) / 1024 / 1024 ))
  # Leave macOS at least 4 GiB. Above this the kernel panics rather than
  # degrading, so this is a hard refusal, not a warning.
  _iogpu_max=$(( _iogpu_total - 4096 ))

  if [ -z "$_iogpu_want" ] || [ "$_iogpu_want" -le 0 ] 2>/dev/null; then
    _SKIP "GPU wired limit (no value rendered)"
  elif [ "$_iogpu_want" -gt "$_iogpu_max" ]; then
    _ERR "iogpu_wired_limit_mb=$_iogpu_want exceeds the safe max ${_iogpu_max}MiB for ${_iogpu_total}MiB of RAM"
    _GUIDE "Lower it in src/local.k. Values leaving macOS under 4 GiB panic the machine."
  else
    _iogpu_now=$(sysctl -n iogpu.wired_limit_mb 2>/dev/null || echo 0)
    _iogpu_stale=1
    [ -f "$_iogpu_dst" ] && cmp -s "$_iogpu_src" "$_iogpu_dst" && _iogpu_stale=0

    if [ "$_iogpu_stale" = "0" ] && [ "$_iogpu_now" = "$_iogpu_want" ]; then
      _OK "GPU wired limit ${_iogpu_want}MiB (daemon installed, live)"
    elif sudo -n true 2>/dev/null; then
      sudo install -m 644 -o root -g wheel "$_iogpu_src" "$_iogpu_dst" \
        && sudo launchctl bootout system "$_iogpu_dst" 2>/dev/null
      if sudo launchctl bootstrap system "$_iogpu_dst" 2>/dev/null \
        || sudo sysctl -w "iogpu.wired_limit_mb=$_iogpu_want" >/dev/null 2>&1; then
        _OK "GPU wired limit set to ${_iogpu_want}MiB (persists across reboot)"
      else
        _WARN "Installed the daemon but could not apply ${_iogpu_want}MiB this session"
      fi
    elif [ "$_iogpu_now" = "$_iogpu_want" ]; then
      # Right value, no daemon — the usual state after applying it by hand.
      # Reporting this as a mismatch ("is 20480, want 20480") is nonsense; the
      # only thing actually missing is persistence across reboot.
      _WARN "GPU wired limit ${_iogpu_want}MiB is live but resets at reboot (daemon not installed; needs root)"
      _GUIDE "sudo install -m 644 -o root -g wheel '$_iogpu_src' '$_iogpu_dst'"
      _GUIDE "sudo launchctl bootstrap system '$_iogpu_dst'"
    else
      _WARN "GPU wired limit is ${_iogpu_now}MiB, want ${_iogpu_want}MiB (needs root)"
      _GUIDE "sudo install -m 644 -o root -g wheel '$_iogpu_src' '$_iogpu_dst'"
      _GUIDE "sudo launchctl bootstrap system '$_iogpu_dst'"
    fi
    unset _iogpu_now _iogpu_stale
  fi
  unset _iogpu_want _iogpu_total _iogpu_max
elif [ "$(uname)" = "Darwin" ] && [ -f "$_iogpu_dst" ]; then
  # Opted out after previously opting in — leave nothing stale behind.
  _WARN "GPU wired limit no longer configured, but $_iogpu_dst is still installed"
  _GUIDE "sudo launchctl bootout system '$_iogpu_dst' && sudo rm '$_iogpu_dst'"
fi
unset _iogpu_label _iogpu_src _iogpu_dst

# ── LM Studio model identifiers ───────────────────────────────────────────
# opencode addresses a local model by its LM Studio *identifier*, which is
# assigned at load time and defaults to the model key (e.g.
# "leonsarmiento/qwen3.6-27b-mlx"), NOT to whatever it was called last time.
# Reload without `--identifier` and every agent pinned to it starts returning
# 400 "Invalid model identifier" — the whole local workflow dies at once, with
# the failure surfacing several layers up as an opaque agent error. Observed
# twice on 2026-07-22. Worse when the drift goes the other way: an identifier
# pointed at a *different* model answers happily while opencode budgets the
# session against the wrong context window, which is how a 27B got driven past
# its KV ceiling into a Metal OOM.
#
# scripts/lmstudio_sync.sh owns the actual comparison (and can repair it with
# --fix); this is only the deploy-time report. Advisory: LM Studio not running
# is normal and must never fail a deploy.
_lms_sync="$REPO_ROOT/scripts/lmstudio_sync.sh"
if [ -x "$_lms_sync" ]; then
  _lms_rc=0
  _lms_out="$("$_lms_sync" 2>/dev/null)" || _lms_rc=$?
  if [ "$_lms_rc" -eq 0 ]; then
    _OK "LM Studio model identifiers match the opencode config"
  # Exit 2 is "cannot tell" (no lms, server down, nothing deployed yet) and is
  # not a deploy problem. Only exit 1 means real, actionable drift.
  elif [ "$_lms_rc" -eq 1 ]; then
    printf '%s\n' "$_lms_out" | grep -E '^  (UNMAPPED|MISSING|DRIFTED|CONTEXT)' | while read -r _l; do
      _WARN "LM Studio: $_l"
    done
    _GUIDE "scripts/lmstudio_sync.sh --fix"
  fi
fi
unset _lms_sync _lms_out _lms_rc

_STEP "Post-deploy validation complete"
