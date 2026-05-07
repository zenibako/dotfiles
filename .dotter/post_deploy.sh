#!/bin/sh
set -eu

# Symlink shared commands into OpenCode (dotter can't map one source to two targets,
# so we point opencode at the already-deployed ~/.claude/commands/ symlinks)
_oc_cmd="$HOME/.config/opencode/command"
mkdir -p "$_oc_cmd"
for _cmd in go.md fix-pipeline.md coderabbit-review.md; do
  ln -sf "$HOME/.claude/commands/$_cmd" "$_oc_cmd/$_cmd"
done
unset _oc_cmd _cmd

# Deploy skills to Claude Desktop
# Use git to find dotfiles root reliably regardless of where dotter runs this script
_dotfiles=$(git -C "$(dirname "$0")" rev-parse --show-toplevel 2>/dev/null) || _dotfiles=""
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
      python3 - "$_manifest" "$_dotfiles/claude-desktop/skills" <<'PYEOF'
import json, os, sys, datetime

manifest_path, skills_root = sys.argv[1], sys.argv[2]
with open(manifest_path) as f:
    manifest = json.load(f)
existing = {s['skillId'] for s in manifest['skills']}
changed = False
for skill_name in sorted(os.listdir(skills_root)):
    skill_md = os.path.join(skills_root, skill_name, 'SKILL.md')
    if not os.path.isfile(skill_md) or skill_name in existing:
        continue
    desc = skill_name
    with open(skill_md) as f:
        content = f.read()
    if content.startswith('---'):
        for line in content.split('\n')[1:]:
            if line.startswith('---'):
                break
            if line.lower().startswith('description:'):
                desc = line.split(':', 1)[1].strip().strip('"\'')
    manifest['skills'].append({
        'skillId': skill_name,
        'name': skill_name,
        'description': desc,
        'creatorType': 'user',
        'updatedAt': datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.%f')[:-3] + 'Z',
        'enabled': True
    })
    manifest['lastUpdated'] = int(datetime.datetime.now(datetime.timezone.utc).timestamp() * 1000)
    print(f'  Registered skill: {skill_name}')
    changed = True
if changed:
    with open(manifest_path, 'w') as f:
        json.dump(manifest, f, indent=2)
PYEOF
    fi
  fi
fi
unset _dotfiles _claude_app _ops_file _account_id _plugin_dir _plugin_uuid _skills_base _skills_dir _manifest _sd _sname
echo "==> Running post-deploy validation..."

DEPLOYED="$HOME/.config"

# --- OpenCode JSONC validation ---
if [ -f "$DEPLOYED/opencode/opencode.jsonc" ]; then
  echo "Validating OpenCode config..."

  # Prefer json5 CLI (brew install json5 / npm install -g json5) for proper JSON5/JSONC parsing
  if command -v json5 >/dev/null 2>&1; then
    if ! json5 -v "$DEPLOYED/opencode/opencode.jsonc" >/dev/null 2>&1; then
      echo "ERROR: OpenCode config validation failed (json5)" >&2
      exit 1
    fi
    echo "  OpenCode config OK (json5)"
  elif command -v python3 >/dev/null 2>&1; then
    # Fallback: write Python script to a temp file to avoid shell-quoting hell
    _pytmp=$(mktemp)
    cat > "$_pytmp" <<'PYEOF'
import json, re, sys
path = sys.argv[1]
with open(path, 'r') as f:
    content = f.read()

def strip_comments(text):
    text = re.sub(r'/\*.*?\*/', '', text, flags=re.DOTALL)
    result = []
    in_string = False
    i = 0
    while i < len(text):
        ch = text[i]
        if not in_string and ch == '"':
            in_string = True
            result.append(ch)
        elif in_string and ch == '"':
            # check for escaped
            slashes = 0
            j = len(result) - 1
            while j >= 0 and result[j] == '\\':
                slashes += 1
                j -= 1
            if slashes % 2 == 1:
                result.append(ch)
            else:
                in_string = False
                result.append(ch)
        elif not in_string and ch == '/' and i + 1 < len(text) and text[i + 1] == '/':
            while i < len(text) and text[i] not in '\r\n':
                i += 1
            continue
        else:
            result.append(ch)
        i += 1
    return ''.join(result)

content = strip_comments(content)
content = re.sub(r',(\s*[}\]])', r'\1', content)
try:
    json.loads(content)
except json.JSONDecodeError as e:
    print(f'Invalid JSONC in {path}: {e}', file=sys.stderr)
    sys.exit(1)
PYEOF
    if ! python3 "$_pytmp" "$DEPLOYED/opencode/opencode.jsonc"; then
      rm -f "$_pytmp"
      echo "ERROR: OpenCode config validation failed (python fallback)" >&2
      exit 1
    fi
    rm -f "$_pytmp"
    echo "  OpenCode config OK (python fallback)"
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
      echo "$mcp_clean" | grep -E '^[[:space:]]*\u25cf[[:space:]]+\u2717' >&2 || true
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

# --- TOML validation ---
validate_toml() {
  file="$1"
  if [ ! -f "$file" ]; then return 0; fi
  if ! command -v python3 >/dev/null 2>&1; then
    echo "  Skipping TOML validation (python3 not available)"
    return 0
  fi

  rc=0
  python3 -c "
import sys
try:
    import tomllib
    with open('$file', 'rb') as f:
        tomllib.load(f)
except ImportError:
    try:
        import toml
        with open('$file', 'r') as f:
            toml.load(f)
    except ImportError:
        sys.exit(2)
sys.exit(0)
  " >/dev/null 2>&1 || rc=$?

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
