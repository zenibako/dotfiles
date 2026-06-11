#!/bin/sh

set -eu

LOCAL_CONFIG="${DOTTER_LOCAL_CONFIG:-.dotter/local.toml}"

if [ ! -f "$LOCAL_CONFIG" ]; then
  echo "Missing local config: $LOCAL_CONFIG" >&2
  exit 1
fi

get_var() {
  key="$1"
  value=$(grep -E "^[[:space:]]*$key[[:space:]]*=" "$LOCAL_CONFIG" | tail -n 1 | cut -d '=' -f 2- | tr -d '"' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  printf '%s' "$value"
}

require_var() {
  key="$1"
  value=$(get_var "$key")

  case "$value" in
    ""|"Your Name"|"your@email.com")
      echo "dotter deploy blocked: set '$key' in $LOCAL_CONFIG before deploying." >&2
      exit 1
      ;;
  esac
}

require_var name
require_var email

# ── Regenerate configs from KCL ──────────────────────────────────────────
# KCL is the source of truth; always rebuild before deploying.
_repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"

if [ -z "$_repo_root" ]; then
  # dotter caches scripts in .dotter/cache/.dotter/, so dirname "$0" is unreliable.
  _cdir="$(cd "$(dirname "$0")" && pwd)"
  while [ "$_cdir" != "/" ]; do
    if [ -f "$_cdir/.dotter/scripts/generate_from_kcl.py" ]; then
      _repo_root="$_cdir"
      break
    fi
    _cdir="$(dirname "$_cdir")"
  done
fi

if [ -n "$_repo_root" ]; then
  # Detect project virtualenv (uv or standard venv)
  PYTHON="python3"
  if [ -f "$_repo_root/.venv/bin/python3" ]; then
    PYTHON="$_repo_root/.venv/bin/python3"
  elif [ -f "$_repo_root/venv/bin/python3" ]; then
    PYTHON="$_repo_root/venv/bin/python3"
  fi
  if command -v kcl >/dev/null 2>&1 && [ -f "$_repo_root/src/main.k" ]; then
    echo "Regenerating configs from KCL..."
    cd "$_repo_root"
    mkdir -p generated
    kcl run src/main.k >/dev/null || { echo "ERROR: KCL generation failed" >&2; exit 1; }
    "$PYTHON" .dotter/scripts/generate_from_kcl.py || { echo "ERROR: Python conversion failed" >&2; exit 1; }
    "$PYTHON" .dotter/scripts/validate_generated.py || { echo "ERROR: Generated config validation failed" >&2; exit 1; }
    echo "  Configs regenerated."
  else
    echo "ERROR: KCL is required for this repository but was not found." >&2
    echo "       Install it with: brew install kcl-lang/tap/kcl" >&2
    echo "       Or visit: https://kcl-lang.io/docs/user_docs/getting-started/install" >&2
    exit 1
  fi
else
  echo "WARNING: could not locate repo root for KCL regeneration" >&2
fi

# Pre-deploy schema validation
if [ -n "$_repo_root" ] && [ -f "$_repo_root/.dotter/scripts/validate_schema.sh" ]; then
  cd "$_repo_root"
  "$_repo_root/.dotter/scripts/validate_schema.sh" --pre-deploy || true
else
  echo "WARNING: could not locate validate_schema.sh for pre-deploy validation" >&2
fi
unset _cdir
