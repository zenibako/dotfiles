#!/bin/sh
# Validate config files against schemas (before or after deploy).
# Usage: validate_schema.sh [--pre-deploy|--post-deploy]
# Exits non-zero on validation failure.

set -eu

# ANSI color codes for warnings and errors
COLOR_YELLOW='\033[33m'
COLOR_RED='\033[31m'
COLOR_GREEN='\033[32m'
COLOR_RESET='\033[0m'
_WARN() { printf "${COLOR_YELLOW}WARNING:${COLOR_RESET} %s\n" "$1" >&2; }
_ERR()  { printf "${COLOR_RED}ERROR:${COLOR_RESET} %s\n" "$1" >&2; }
_OK()   { printf "${COLOR_GREEN}OK:${COLOR_RESET} %s\n" "$1"; }

MODE="${1:---pre-deploy}"
REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
_SCRIPTS="$REPO_ROOT/scripts/dotter"
DEPLOYED="$HOME/.config"
LOCAL_CONFIG="${DOTTER_LOCAL_CONFIG:-$REPO_ROOT/.dotter/local.toml}"

if [ ! -d "$_SCRIPTS" ]; then
  echo "Could not locate scripts/dotter at $_SCRIPTS" >&2
  echo "Usage: REPO_ROOT=/path/to/repo validate_schema.sh [--pre-deploy|--post-deploy]" >&2
  exit 1
fi

# --- helpers ---

if [ -s "$_SCRIPTS/.venv/bin/python3" ]; then
  PATH="$_SCRIPTS/.venv/bin:$PATH"
  export PATH
fi

get_profile() {
  if [ ! -f "$LOCAL_CONFIG" ]; then return 0; fi
  # Parse packages array from local.toml (handles multi-line arrays)
  _packages=$(python3 -c "
import re
with open('$LOCAL_CONFIG', 'r') as f:
    content = f.read()
m = re.search(r'^\\s*packages\\s*=\\s*(\\[[^\\]]*\\])', content, re.MULTILINE)
if m:
    arr = m.group(1)
    print(' '.join(re.findall(r'\"([^\"]+)\"', arr)))
" 2>/dev/null)
  case "$_packages" in
    *work*)    echo "work" ;;
    *personal*) echo "personal" ;;
    *)          echo "" ;;
  esac
}

ACTIVE_PROFILE=$(get_profile)

has_taplo() { command -v taplo >/dev/null 2>&1; }
has_python3() { command -v python3 >/dev/null 2>&1; }

# Ensure a local venv exists at scripts/dotter/.venv for missing Python packages
# (self-contained, works with PEP 668 externally-managed environments like Homebrew)
_ensure_venv() {
  if [ -s "$_SCRIPTS/.venv/bin/python3" ]; then
    return 0
  fi
  if ! has_python3; then
    return 1
  fi
  echo "  Creating validation venv at $_SCRIPTS/.venv..." >&2
  python3 -m venv "$_SCRIPTS/.venv" >/dev/null 2>&1
  [ -s "$_SCRIPTS/.venv/bin/python3" ]
}

# Install a package into the local venv if missing
_ensure_pkg() {
  _pkg="$1"
  if [ ! -s "$_SCRIPTS/.venv/bin/python3" ]; then
    _ensure_venv || return 1
  fi
  if "$_SCRIPTS/.venv/bin/python3" -c "import $_pkg" 2>/dev/null; then
    return 0
  fi
  echo "  Installing $_pkg into validation venv..." >&2
  "$_SCRIPTS/.venv/bin/pip" install "$_pkg" >/dev/null 2>&1
}

# Use venv python if available (for packages like pyyaml that may not be on the host)
_python3() {
  if [ -s "$_SCRIPTS/.venv/bin/python3" ]; then
    "$_SCRIPTS/.venv/bin/python3" "$@"
  else
    python3 "$@"
  fi
}

has_aerospace() { command -v aerospace >/dev/null 2>&1; }

# Pip command to recommend for installing missing Python packages
_VENV_PIP="python3 -m pip"
if [ -s "$_SCRIPTS/.venv/bin/pip" ]; then
  _VENV_PIP="$_SCRIPTS/.venv/bin/pip"
elif [ -s "$_SCRIPTS/.venv/bin/pip3" ]; then
  _VENV_PIP="$_SCRIPTS/.venv/bin/pip3"
fi
has_ghostty() { command -v ghostty >/dev/null 2>&1; }
has_starship() { command -v starship >/dev/null 2>&1; }

# Test if a file contains Handlebars template markers
is_template_file() {
  _file="$1"
  if [ ! -f "$_file" ]; then return 1; fi
  grep -qE '\{\{\s*(#|/)[a-zA-Z0-9_\.]+(\s[^}]*)?\}\}' "$_file" 2>/dev/null
}

# Taplo lint — optionally skip schema for source files that are Handlebars templates.
# Strips '#:schema' directives when validating deployed files (corporate proxies
# often block schema fetch URLs).
lint_toml() {
  _file="$1"
  _skip_schema="${2:-}"
  if [ ! -f "$_file" ]; then return 0; fi
  if ! has_taplo; then return 0; fi

  # Remove inline schema directives for validation; some schemas are unreachable
  # behind corporate proxies, and `taplo lint --no-schema` still reads them.
  _tmp=$(mktemp)
  sed '/^[[:space:]]*#:schema/d' "$_file" > "$_tmp"

  if [ -n "$_skip_schema" ]; then
    _taplo_opts="--no-schema"
  else
    _taplo_opts=""
  fi

  if taplo lint $_taplo_opts "$_tmp" >/dev/null 2>&1; then
    echo "  TOML OK: $_file"
    rm -f "$_tmp"
  else
    _WARN "TOML validation failed: $_file (schema may be unreachable; retrying without schema)"
    if taplo lint --no-schema "$_tmp" >/dev/null 2>&1; then
      echo "  TOML OK: $_file (syntax only)"
      rm -f "$_tmp"
    else
      _ERR "TOML validation failed: $_file"
      taplo lint --no-schema "$_tmp" >&2 || true
      rm -f "$_tmp"
      return 1
    fi
  fi
}

# Basic TOML Python fallback when taplo is not available
python_toml() {
  _file="$1"
  if [ ! -f "$_file" ]; then return 0; fi
  if ! has_python3; then
    echo "  Skipping TOML validation (no taplo or python3)"
    return 0
  fi

  rc=0
  _python3 -c "
import sys
try:
    import tomllib
    with open('$_file', 'rb') as f:
        tomllib.load(f)
except ImportError:
    try:
        import toml
        toml.load('$_file')
    except ImportError:
        sys.exit(2)
" >/dev/null 2>&1 || rc=$?

  if [ "$rc" -eq 2 ]; then
    echo "  Skipping TOML validation (no toml module)"
    return 0
  elif [ "$rc" -ne 0 ]; then
    		_ERR "TOML validation failed: $_file" >&2
    _python3 -c "
import sys
try:
    import tomllib
    with open('$_file', 'rb') as f:
        tomllib.load(f)
except ImportError:
    try:
        import toml
        toml.load('$_file')
    except ImportError:
        sys.exit(2)
" >&2 || true
    return 1
  fi
  echo "  TOML OK: $_file"
}

validate_toml_file() {
  _file="$1"
  _skip_schema="${2:-}"
  if has_taplo; then
    lint_toml "$_file" "$_skip_schema"
  else
    python_toml "$_file"
  fi
}

# JSONC validation (basic syntax)
validate_jsonc() {
  _file="$1"
  if [ ! -f "$_file" ]; then return 0; fi
  if ! has_python3; then
    echo "  Skipping JSONC validation (no python3)"
    return 0
  fi

  if _python3 "$_SCRIPTS/validate_jsonc.py" "$_file"; then
    echo "  JSONC OK: $_file"
  else
    		_ERR "JSONC validation failed: $_file" >&2
    return 1
  fi
}

# JSONC schema validation (OpenCode only — post-deploy only, needs network)
validate_jsonc_schema() {
  _file="$1"
  if [ ! -f "$_file" ]; then return 0; fi
  if ! has_python3; then
    echo "  Skipping JSONC schema validation (no python3)"
    return 0
  fi

  if _python3 -c "import jsonschema" 2>/dev/null; then
    if _python3 "$_SCRIPTS/validate_jsonc_schema.py" "$_file" >/dev/null 2>&1; then
      echo "  JSONC schema OK: $_file"
    else
      		_WARN "JSONC schema validation failed: $_file (schema may be outdated)" >&2
      # Fall through to basic validation
    fi
  else
    _ensure_pkg jsonschema || {
      echo "  Skipping JSONC schema validation (no jsonschema module; tried to auto-install into $_SCRIPTS/.venv)"
    }
  fi
  validate_jsonc "$_file"
}

# AeroSpace TOML validation — needs deployed config
validate_aerospace() {
  _file="$1"
  if [ ! -f "$_file" ]; then return 0; fi
  if ! has_aerospace; then
    echo "  Skipping AeroSpace validation (cli not available)"
    return 0
  fi

  # `aerospace list-modes` queries the running AeroSpace.app server (not the
  # file), so it cannot validate a config offline. Treat a "server not running"
  # failure as a skip; only a genuine config rejection is an error.
  if _modes=$(AEROSPACE_CONFIG="$_file" aerospace list-modes 2>&1); then
    echo "  AeroSpace OK ($_file): detected modes"
    return 0
  fi
  case "$_modes" in
    *"connect to AeroSpace"*|*"not running"*)
      echo "  Skipping AeroSpace validation (AeroSpace.app not running)"
      return 0 ;;
    *)
      _ERR "AeroSpace config validation failed: $_file" >&2
      printf '%s\n' "$_modes" | sed 's/^/    /' >&2
      return 1 ;;
  esac
}

# Ghostty TOML validation — needs deployed config
validate_ghostty() {
  _dir="$1"
  _file="$_dir/config"
  if [ ! -f "$_file" ]; then return 0; fi
  if ! has_ghostty; then
    echo "  Skipping Ghostty validation (cli not available)"
    return 0
  fi

  if ! ghostty +validate-config --config-file="$_file" 2>&1 >/dev/null; then
    		_ERR "Ghostty config validation failed: $_file" >&2
    return 1
  fi
  echo "  Ghostty OK: $_file"
}

# Cross-reference Handlebars placeholders against local.toml variables.
# Only warns about placeholders that:
#   1. Are in the ACTIVE profile scope (or outside conditionals)
#   2. Are NOT defined in local.toml, OR are defined but empty
# Placeholders with non-empty values in local.toml are silently OK.
validate_handlebars_placeholders() {
  _file="$1"
  if [ ! -f "$_file" ]; then return 0; fi
  if [ ! -f "$LOCAL_CONFIG" ]; then return 0; fi

  if ! has_python3; then
    # Fallback: naive grep for all placeholders (no local.toml cross-reference)
    if grep -nE '\{\{\s*[#/]?[a-zA-Z0-9_\.]+(\s[^}]*)?\}\}' "$_file" >/dev/null 2>/dev/null; then
      		_WARN "Possible unreplaced Handlebars in $_file:" >&2
      grep -nE '\{\{\s*[#/]?[a-zA-Z0-9_\.]+(\s[^}]*)?\}\}' "$_file" >&2
    fi
    return 0
  fi

  _profile_aware=$(_python3 -c "
import re, sys
file_path = '$_file'
local_config = '$LOCAL_CONFIG'

# Active profile from local.toml
profile = '$ACTIVE_PROFILE'
if profile == '':
    profile = None

# Parse variables from local.toml [variables] section
local_vars = {}
in_vars = False
with open(local_config, 'r') as f:
    for line in f:
        stripped = line.strip()
        if stripped == '[variables]':
            in_vars = True
            continue
        if in_vars and stripped.startswith('['):
            break
        if in_vars:
            # key = 'value' or key = \"value\"
            m = re.match(r'^([a-zA-Z_][a-zA-Z0-9_]*)\\s*=\\s*\"(.*?)\"\\s*$', stripped)
            if m:
                local_vars[m.group(1)] = m.group(2)
            # key = true / false / number
            m = re.match(r'^([a-zA-Z_][a-zA-Z0-9_]*)\\s*=\\s*(true|false|[0-9]+)\\s*$', stripped)
            if m:
                local_vars[m.group(1)] = m.group(2)

with open(file_path, 'r') as f:
    lines = f.readlines()

optional_vars = {
    'reddit_token_v2', 'brave_search_api_key',
    'proton_user', 'proton_password',
    'telegram_bot_token', 'youtube_api_key', 'google_places_api_key',
    'slack_d_cookie', 'slack_token',
    'home_assistant_token', 'bluesky_app_password',
    'plex_user_token', 'plex_server_token', 'tmdb_key',
    'reddit_session', 'tripit_password',
    'last_fm_api_key', 'rocksky_password',
    'mcp_obsidian_token', 'github_personal_access_token',
    'gitlab_personal_access_token', 'sonarqube_token',
    'postman_api_key',
}

def condition_is_active(condition_name):
    if condition_name.startswith('opencode_profile_'):
        expected_profile = condition_name[len('opencode_profile_'):]
        return profile is None or profile == expected_profile

    value = local_vars.get(condition_name)
    if value is None:
        return False

    if isinstance(value, str):
        lowered = value.strip().lower()
        return lowered not in ('', 'false', '0', 'none', 'null')

    return bool(value)


def stack_is_active(stack):
    return all(frame['active'] for frame in stack)


token_re = re.compile(r'\{\{\s*(.*?)\s*\}\}')
issues = []
stack = []
for i, line in enumerate(lines, 1):
    for m in token_re.finditer(line):
        token = m.group(1).strip()

        if not token or token.startswith('!'):
            continue

        if token.startswith('#if '):
            condition_name = token[4:].strip()
            condition_result = condition_is_active(condition_name)
            stack.append({
                'condition_name': condition_name,
                'condition_result': condition_result,
                'active': condition_result,
            })
            continue

        if token == 'else':
            if stack:
                stack[-1]['active'] = not stack[-1]['condition_result']
            continue

        if token.startswith('/if'):
            if stack:
                stack.pop()
            continue

        if token.startswith('#') or token.startswith('/'):
            continue

        if not stack_is_active(stack):
            continue

        placeholder = token
        val = local_vars.get(placeholder)
        if val is None:
            issues.append((i, placeholder, 'NOT SET in local.toml'))
        elif val == '' and placeholder not in optional_vars:
            issues.append((i, placeholder, 'EMPTY in local.toml (set a value or omit line)'))
        # elif val == '' and placeholder in optional_vars -> OK, no warning
        # elif val != '' -> OK, no warning

if issues:
    print('WARNING: Possible unreplaced Handlebars in %s:' % file_path, file=sys.stderr)
    for line_no, placeholder, reason in issues:
        print('  Line %d: {{%s}}  (%s)' % (line_no, placeholder, reason), file=sys.stderr)
" 2>&1) || _profile_aware=""

  if [ -n "$_profile_aware" ]; then
    echo "$_profile_aware" >&2
  fi
}

# --- pre-deploy: validate source files ---

if [ "$MODE" = "--pre-deploy" ]; then
  echo "==> Running pre-deploy schema validation..."

  FAILED=0

  # TOML files (source; skip schema because templates use Handlebars)
  for _file in \
    "$REPO_ROOT/out/atuin/config.toml" \
    "$REPO_ROOT/iamb/config.toml" \
    "$REPO_ROOT/gitlogue/config.toml" \
    "$REPO_ROOT/out/aerospace.toml" \
    "$REPO_ROOT/out/starship.toml" \
    "$REPO_ROOT/out/shared/completions.toml"
  do
    validate_toml_file "$_file" "skip-schema" || FAILED=1
  done

  # Template files — skip taplo/python syntax validation, just warn about placeholders
  for _file in \
    "$REPO_ROOT/out/jj/config.toml" \
    "$REPO_ROOT/out/shared/env.toml"
  do
    if [ -f "$_file" ]; then
      echo "  Skipping TOML syntax validation (template file): $_file"
      validate_handlebars_placeholders "$_file" || true
    fi
  done

  # Basic JSONC syntax (OpenCode — now generated by KCL, still template-type for dotter)
  if [ -f "$REPO_ROOT/out/opencode.jsonc" ]; then
    echo "  Skipping source JSONC validation (template file; will validate after deploy)"
  fi

  # Basic JSON syntax (Claude Desktop config — now generated by KCL).
  # This is a dotter template: some Handlebars tokens render as bare booleans
  # (e.g. coworkScheduledTasksEnabled), so the raw file is not valid JSON until
  # rendered. Block tags ({{#if ...}}, {{/if}}, {{else}}) must be stripped
  # entirely so they don't leave stray "true" tokens that break JSON structure.
  # Then substitute remaining {{...}} variable placeholders with a bare literal.
  if [ -f "$REPO_ROOT/out/claude_desktop_config.json" ] && has_python3; then
    if _python3 -c "
import json, re
s = open('$REPO_ROOT/out/claude_desktop_config.json').read()
# Strip block tags: {{#...}}, {{/...}}, {{else}}
s = re.sub(r'\{\{[#/].*?\}\}', '', s)
# Replace remaining variable placeholders with a valid JSON literal
s = re.sub(r'\{\{[^}]*\}\}', 'true', s)
json.loads(s)
" >/dev/null 2>&1; then
      echo "  Claude Desktop config source OK"
    else
      _ERR "Claude Desktop config source validation failed" >&2
      FAILED=1
    fi
  fi

  # YAML (basic syntax check via Python)
  _has_yaml=""
  if has_python3; then
    if _python3 -c "import yaml" 2>/dev/null; then
      _has_yaml=1
    else
      # Auto-install into local venv (handles PEP 668 externally-managed environments)
      _ensure_pkg pyyaml >/dev/null 2>&1 || true
      if _python3 -c "import yaml" 2>/dev/null; then
        _has_yaml=1
      fi
    fi
  fi

  for _file in \
    "$REPO_ROOT/src/carapace/bridges.yaml" \
    "$REPO_ROOT/src/carapace/specs/gog.yaml" \
    "$REPO_ROOT/src/carapace/specs/sf.yaml" \
    "$REPO_ROOT/workmux/config.yaml"
  do
    if [ ! -f "$_file" ]; then continue; fi
    if ! has_python3; then
      echo "  Skipping YAML validation (no python3)"
      continue
    fi

    if [ -z "$_has_yaml" ]; then
      echo "  Skipping YAML validation (no yaml module; tried auto-install into $_SCRIPTS/.venv but failed)"
      continue
    fi

    rc=0
    _python3 -c "
import sys
try:
    import yaml
    yaml.safe_load(open('$_file'))
except ImportError:
    sys.exit(2)
" 2>/dev/null || rc=$?

    if [ "$rc" -eq 2 ]; then
      echo "  Skipping YAML validation (no yaml module)"
      continue
    elif [ "$rc" -ne 0 ]; then
      		_ERR "YAML validation failed: $_file" >&2
      _python3 -c "import yaml; yaml.safe_load(open('$_file'))" >&2 || true
      FAILED=1
    else
      echo "  YAML OK: $_file"
    fi
  done

  echo "==> Pre-deploy validation finished."
  exit "$FAILED"

# --- post-deploy: validate rendered/deployed configs ---

elif [ "$MODE" = "--post-deploy" ]; then
  echo "==> Running post-deploy schema validation..."

  FAILED=0

  # TOML (deployed — enforce schemas via taplo when available)
  for _file in \
    "$DEPLOYED/atuin/config.toml" \
    "$DEPLOYED/iamb/config.toml" \
    "$DEPLOYED/jj/config.toml" \
    "$DEPLOYED/starship.toml"
  do
    if [ ! -f "$_file" ]; then continue; fi
    lint_toml "$_file" "" || FAILED=1
  done

  # OpenCode JSONC + schema
  if [ -f "$DEPLOYED/opencode/opencode.jsonc" ]; then
    validate_jsonc_schema "$DEPLOYED/opencode/opencode.jsonc" || FAILED=1
  fi

  # AeroSpace (mac-specific)
  if [ -f "$HOME/.aerospace.toml" ]; then
    validate_aerospace "$HOME/.aerospace.toml" || FAILED=1
  fi

  # Ghostty
  if [ -d "$DEPLOYED/ghostty" ]; then
    validate_ghostty "$DEPLOYED/ghostty" || FAILED=1
  fi

  # Claude Desktop config
  _claude_config="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
  if [ -f "$_claude_config" ] && has_python3; then
    if _python3 -c "import json; json.load(open('$_claude_config'))" >/dev/null 2>&1; then
      echo "  Claude Desktop config OK"
    else
      		_ERR "Claude Desktop config validation failed" >&2
      FAILED=1
    fi
  fi
  unset _claude_config

  # Claude Code settings.json (MCP servers are reported from ~/.claude.json,
  # which is where Claude Code actually reads user-global mcpServers).
  _cc_settings="$HOME/.claude/settings.json"
  _cc_mcp="$HOME/.claude.json"
  if [ -f "$_cc_settings" ] && has_python3; then
    if _python3 "$_SCRIPTS/validate_cc_settings.py" "$_cc_settings" "$_cc_mcp"; then
      echo "  Claude Code settings OK"
    else
      		_ERR "Claude Code settings validation failed" >&2
      FAILED=1
    fi
  fi
  unset _cc_settings _cc_mcp

  echo "==> Post-deploy validation finished."
  exit "$FAILED"

else
  echo "Usage: validate_schema.sh [--pre-deploy|--post-deploy]" >&2
  exit 2
fi
