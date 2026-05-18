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

DEPLOYED="$HOME/.config"

if [ -d "$_dotfiles" ]; then
  REPO_ROOT="$_dotfiles" "$_scripts/validate_schema.sh" --post-deploy || exit 1
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
    # Neovim headless sends print() output to stderr, capture both
    timeout 300 nvim --headless -c "luafile $_scripts/validate_lsp.lua" -c "qa!" 2>"$lsp_out" >/dev/null || true
    if command -v perl >/dev/null 2>&1; then
      # Suppress:
      # - image.nvim stderr (headless terminal detection)
      # - terraformls single-file recommendation (not an error)
      # - Known Salesforce LSP NPE during init (server-side bug, non-fatal)
      perl -pe 's/\e\[[0-9;]*m//g' < "$lsp_out" | grep -v 'image\.nvim\|image\.lua\|image/backends\|terminal size\|non-terminal\|Error in command line:\|ignoreSingleFileWarning\|Some capabilities may be reduced\|Cannot read properties of null\|vim\.schedule callback\|RPC\[Error\]\|Request initialize failed\|stack traceback:\|\[C\]: in function '\''assert'\''\|vim/lsp/client\.lua:581: in function\|vim/_core/editor\.lua: in function\|\[C\]: at 0x\|\[C\]: in function '\''pcall'\''\|validate_lsp\.lua:[0-9]\+: in function '\''quiet_wait'\''\|validate_lsp\.lua:[0-9]\+: in main chunk' | grep -v '^\s*$' || true
    else
      cat "$lsp_out" | grep -v 'image\.nvim\|image\.lua\|image/backends\|terminal size\|non-terminal\|Error in command line:\|ignoreSingleFileWarning\|Some capabilities may be reduced\|Cannot read properties of null\|vim\.schedule callback\|RPC\[Error\]\|Request initialize failed\|stack traceback:\|\[C\]: in function '\''assert'\''\|vim/lsp/client\.lua:581: in function\|vim/_core/editor\.lua: in function\|\[C\]: at 0x\|\[C\]: in function '\''pcall'\''\|validate_lsp\.lua:[0-9]\+: in function '\''quiet_wait'\''\|validate_lsp\.lua:[0-9]\+: in main chunk' | grep -v '^\s*$' || true
    fi
    rm -f "$lsp_out"
  fi
fi

echo "==> Post-deploy validation complete."
