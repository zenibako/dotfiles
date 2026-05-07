#!/bin/sh
set -eu

# Resolve dotfiles root from the git repo containing this script.
# dotter runs post_deploy.sh from .dotter/cache/, so we use git to find the root.
_dotfiles=$(git -C "$(dirname "$0")" rev-parse --show-toplevel 2>/dev/null) || _dotfiles=""
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
      for _sd in "$_dotfiles/claude-desktop/skills"/*/; do
        [ -d "$_sd" ] || continue
        _sname=$(basename "$_sd")
        mkdir -p "$_skills_dir/$_sname"
        cp "$_sd/SKILL.md" "$_skills_dir/$_sname/SKILL.md"
        echo "  Copied skill: $_sname"
      done
      python3 "$_scripts/deploy_skills.py" "$_manifest" "$_dotfiles/claude-desktop/skills"
    fi
  fi
  unset _claude_app _ops_file _account_id _plugin_dir _plugin_uuid _skills_base _skills_dir _manifest _sd _sname
fi

echo "==> Running post-deploy validation..."

DEPLOYED="$HOME/.config"

# --- OpenCode JSONC validation ---
if [ -f "$DEPLOYED/opencode/opencode.jsonc" ]; then
  echo "Validating OpenCode config..."
  if command -v json5 >/dev/null 2>&1; then
    if ! json5 -v "$DEPLOYED/opencode/opencode.jsonc" >/dev/null 2>&1; then
      echo "ERROR: OpenCode config validation failed (json5)" >&2
      exit 1
    fi
    echo "  OpenCode config OK (json5)"
  elif command -v python3 >/dev/null 2>&1; then
    if ! python3 "$_scripts/validate_jsonc.py" "$DEPLOYED/opencode/opencode.jsonc"; then
      echo "ERROR: OpenCode config validation failed" >&2
      exit 1
    fi
    echo "  OpenCode config OK"
  else
    echo "  Skipping OpenCode validation (no json5 or python3 available)"
  fi
fi

# --- OpenCode MCP health check ---
if command -v opencode >/dev/null 2>&1 && [ -f "$DEPLOYED/opencode/opencode.jsonc" ]; then
  echo "Checking OpenCode MCP servers..."
  mcp_out=$(mktemp)
  mcp_err=$(mktemp)

  if ! opencode mcp list > "$mcp_out" 2> "$mcp_err"; then
    echo "WARNING: opencode mcp list command failed" >&2
    if [ -s "$mcp_err" ]; then
      cat "$mcp_err" >&2
    fi
    rm -f "$mcp_out" "$mcp_err"
  else
    # Strip ANSI escape codes for parsing
    mcp_clean=$(sed 's/\x1b\[[0-9;]*m//g' < "$mcp_out")

    # Count servers by matching server header lines (● ✓ or ● ✗)
    # Use awk to avoid set -e issues: grep -c exits 1 on zero matches
    total=$(echo "$mcp_clean" | awk 'BEGIN{c=0} /^[[:space:]]*●[[:space:]]+[✓✗]/ {c++} END {print c}')
    connected=$(echo "$mcp_clean" | awk 'BEGIN{c=0} /^[[:space:]]*●[[:space:]]+✓/ {c++} END {print c}')
    failed=$(echo "$mcp_clean" | awk 'BEGIN{c=0} /^[[:space:]]*●[[:space:]]+✗/ {c++} END {print c}')

    # awk may print an empty string on zero matches; default to 0 for arithmetic
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
fi

# --- Claude Code settings.json validation ---
_cc_settings="$HOME/.claude/settings.json"
if [ -f "$_cc_settings" ] && command -v python3 >/dev/null 2>&1; then
  echo "Validating Claude Code settings..."
  if ! python3 "$_scripts/validate_cc_settings.py" "$_cc_settings"; then
    echo "ERROR: Claude Code settings validation failed" >&2
    exit 1
  fi
elif [ -f "$_cc_settings" ]; then
  echo "  Skipping Claude Code settings validation (python3 not available)"
fi
unset _cc_settings

# --- TOML validation ---
validate_toml() {
  file="$1"
  if [ ! -f "$file" ]; then return 0; fi
  if ! command -v python3 >/dev/null 2>&1; then
    echo "  Skipping TOML validation (python3 not available)"
    return 0
  fi

  rc=0
  python3 "$_scripts/validate_toml.py" "$file" >/dev/null 2>&1 || rc=$?

  if [ "$rc" -eq 2 ]; then
    echo "  Skipping TOML validation (no toml module)"
    return 0
  elif [ "$rc" -ne 0 ]; then
    echo "ERROR: TOML validation failed: $file" >&2
    return 1
  fi
  echo "  TOML OK: $file"
}

for toml_file in \
  "$DEPLOYED/atuin/config.toml" \
  "$DEPLOYED/jj/config.toml" \
  "$DEPLOYED/iamb/config.toml" \
  "$DEPLOYED/starship.toml"
do
  validate_toml "$toml_file" || exit 1
done

# --- Lua validation ---
if [ -d "$DEPLOYED/nvim" ]; then
  if command -v luac >/dev/null 2>&1; then
    echo "Validating Lua files..."
    failed=0
    find "$DEPLOYED/nvim" -name '*.lua' -type f | while IFS= read -r lua_file; do
      if ! luac -p "$lua_file" >/dev/null 2>&1; then
        echo "ERROR: Lua syntax error in $lua_file" >&2
        failed=1
      fi
    done || true
    if [ "$failed" -eq 1 ]; then
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

  if grep -E '^E[0-9]+:|Error while calling lua chunk|Error loading plugin config' /tmp/nvim-startup.log >/dev/null 2>&1; then
    echo "ERROR: Neovim startup errors detected:" >&2
    cat /tmp/nvim-startup.log >&2
    exit 1
  fi
  echo "  Neovim startup OK"
fi

echo "==> Post-deploy validation complete."
