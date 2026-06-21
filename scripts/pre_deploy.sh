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

LOCAL_CONFIG="${DOTTER_LOCAL_CONFIG:-.dotter/local.toml}"

if [ ! -f "$LOCAL_CONFIG" ]; then
  echo "Missing local config: $LOCAL_CONFIG" >&2
  exit 1
fi

get_var() {
  grep -E "^[[:space:]]*$1[[:space:]]*=" "$LOCAL_CONFIG" | tail -n 1 | cut -d '=' -f 2- | tr -d '"' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

require_var() {
  local value
  value=$(get_var "$1")
  case "$value" in
    ""|"Your Name"|"your@email.com")
      echo "dotter deploy blocked: set '$1' in $LOCAL_CONFIG before deploying." >&2
      exit 1 ;;
  esac
}

require_var name
require_var email

# ── Regenerate configs from KCL ──────────────────────────────────────────
resolve_repo_root
resolve_python

if [ -z "$REPO_ROOT" ]; then
  echo "WARNING: could not locate repo root for KCL regeneration" >&2
elif command -v kcl >/dev/null 2>&1 && [ -f "$REPO_ROOT/src/main.k" ]; then
  echo "Regenerating configs from KCL..."
  cd "$REPO_ROOT"
  mkdir -p generated out out/shared out/ghostty out/atuin out/jj out/iamb out/gitlogue out/pnpm out/claude-code out/kiro
  kcl run src/main.k >/dev/null || { echo "ERROR: KCL generation failed" >&2; exit 1; }
  "$PYTHON" scripts/dotter/generate_from_kcl.py || { echo "ERROR: Python conversion failed" >&2; exit 1; }
  "$PYTHON" scripts/dotter/validate_generated.py || { echo "ERROR: Generated config validation failed" >&2; exit 1; }
  echo "  Configs regenerated."
else
  echo "ERROR: KCL is required for this repository but was not found." >&2
  echo "       Install it with: brew install kcl-lang/tap/kcl" >&2
  exit 1
fi

# Pre-deploy schema validation
if [ -n "$REPO_ROOT" ] && [ -f "$REPO_ROOT/scripts/dotter/validate_schema.sh" ]; then
  cd "$REPO_ROOT"
  "$REPO_ROOT/scripts/dotter/validate_schema.sh" --pre-deploy || true
fi
