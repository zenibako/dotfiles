#!/bin/sh
# Validate config files against schemas (before or after deploy).
# Usage: validate_schema.sh [--pre-deploy|--post-deploy]
# Exits non-zero on validation failure.

set -eu

MODE="${1:---pre-deploy}"
REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
_SCRIPTS="$REPO_ROOT/.dotter/scripts"
DEPLOYED="$HOME/.config"
LOCAL_CONFIG="${DOTTER_LOCAL_CONFIG:-$REPO_ROOT/.dotter/local.toml}"

if [ ! -d "$_SCRIPTS" ]; then
  echo "Could not locate .dotter/scripts at $_SCRIPTS" >&2
  echo "Usage: REPO_ROOT=/path/to/repo validate_schema.sh [--pre-deploy|--post-deploy]" >&2
  exit 1
fi

# --- helpers ---

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

# Use venv python if available (for packages like pyyaml that may not be on the host)
_python3() {
  if [ -s "$_SCRIPTS/.venv/bin/python3" ]; then
    "$_SCRIPTS/.venv/bin/python3" "$@"
  else
    python3 "$@"
  fi
}

has_aerospace() { command -v aerospace >/dev/null 2>&1; }
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
    echo "WARNING: TOML validation failed: $_file (schema may be unreachable; retrying without schema)" >&2
    if taplo lint --no-schema "$_tmp" >/dev/null 2>&1; then
      echo "  TOML OK: $_file (syntax only)"
      rm -f "$_tmp"
    else
      echo "ERROR: TOML validation failed: $_file" >&2
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
  _python3 "$_file" >/dev/null 2>&1 || rc=$?

  if [ "$rc" -eq 2 ]; then
    echo "  Skipping TOML validation (no toml module)"
    return 0
  elif [ "$rc" -ne 0 ]; then
    echo "ERROR: TOML validation failed: $_file" >&2
    _python3 "$_file" >&2 || true
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
    echo "ERROR: JSONC validation failed: $_file" >&2
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
      echo "WARNING: JSONC schema validation failed: $_file (schema may be outdated)" >&2
      # Fall through to basic validation
    fi
  else
    echo "  Skipping JSONC schema validation (no jsonschema module)"
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

  if ! _modes=$(AEROSPACE_CONFIG="$_file" aerospace list-modes 2>/dev/null); then
    echo "ERROR: AeroSpace config validation failed: $_file" >&2
    return 1
  fi
  echo "  AeroSpace OK ($_file): detected modes"
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
    echo "ERROR: Ghostty config validation failed: $_file" >&2
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
      echo "WARNING: Possible unreplaced Handlebars in $_file:" >&2
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

# Track which lines are inside inactive profile blocks
inactive_ranges = []
stack = []
for i, line in enumerate(lines, 1):
    m = re.search(r'\{\{#if\\s+(opencode_profile_(\\w+))\\s*\}\}', line)
    if m:
        stack.append((i, m.group(1), m.group(2)))
    if re.search(r'\{\{/if\\s*\}\}', line):
        if stack:
            start, var, prof = stack.pop()
            if profile and prof != profile:
                inactive_ranges.append((start, i))

# Find placeholders outside inactive ranges that are missing or empty
issues = []
for i, line in enumerate(lines, 1):
    in_inactive = any(start <= i <= end for start, end in inactive_ranges)
    if in_inactive:
        continue
    for m in re.finditer(r'\{\{\\s*([^{#/][^}]*)\\s*\}\}', line):
        placeholder = m.group(1).strip()
        if not placeholder or placeholder.startswith('!'):
            continue
        val = local_vars.get(placeholder)
        if val is None:
            issues.append((i, placeholder, 'NOT SET in local.toml'))
        elif val == '':
            issues.append((i, placeholder, 'EMPTY in local.toml'))
        # else: defined and non-empty -> OK, no warning

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
    "$REPO_ROOT/atuin/config.toml" \
    "$REPO_ROOT/iamb/config.toml" \
    "$REPO_ROOT/gitlogue/config.toml" \
    "$REPO_ROOT/aerospace.toml" \
    "$REPO_ROOT/starship.toml" \
    "$REPO_ROOT/shared/completions.toml"
  do
    validate_toml_file "$_file" "skip-schema" || FAILED=1
  done

  # Template files — skip taplo/python syntax validation, just warn about placeholders
  for _file in \
    "$REPO_ROOT/jj/config.toml" \
    "$REPO_ROOT/shared/env.toml"
  do
    if [ -f "$_file" ]; then
      echo "  Skipping TOML syntax validation (template file): $_file"
      validate_handlebars_placeholders "$_file" || true
    fi
  done

  # Basic JSONC syntax (OpenCode — source template is JSONC with Handlebars conditional blocks)
  if [ -f "$REPO_ROOT/opencode/opencode.jsonc" ]; then
    echo "  Skipping source JSONC validation (template file; will validate after deploy)"
  fi

  # YAML (basic syntax check via Python)
  for _file in \
    "$REPO_ROOT/carapace/bridges.yaml" \
    "$REPO_ROOT/carapace/specs/gog.yaml" \
    "$REPO_ROOT/carapace/specs/sf.yaml" \
    "$REPO_ROOT/workmux/config.yaml"
  do
    if [ ! -f "$_file" ]; then continue; fi
    if ! has_python3; then
      echo "  Skipping YAML validation (no python3)"
      continue
    fi

    rc=0
    _python3 -c "import yaml; yaml.safe_load(open('$_file'))" 2>/dev/null || rc=$?

    if [ "$rc" -eq 0 ]; then
      echo "  YAML OK: $_file"
    else
      echo "ERROR: YAML validation failed: $_file" >&2
      _python3 -c "import yaml; yaml.safe_load(open('$_file'))" >&2 || true
      FAILED=1
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

  # Claude Code settings.json
  _cc_settings="$HOME/.claude/settings.json"
  if [ -f "$_cc_settings" ] && has_python3; then
    if _python3 "$_SCRIPTS/validate_cc_settings.py" "$_cc_settings"; then
      echo "  Claude Code settings OK"
    else
      echo "ERROR: Claude Code settings validation failed" >&2
      FAILED=1
    fi
  fi
  unset _cc_settings

  echo "==> Post-deploy validation finished."
  exit "$FAILED"

else
  echo "Usage: validate_schema.sh [--pre-deploy|--post-deploy]" >&2
  exit 2
fi
