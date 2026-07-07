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

# ── Regenerate configs from KCL first (includes .dotter/local.toml) ─────
resolve_repo_root
resolve_python

# Ensure Python venv and dependencies exist (hard-fail if uv is missing —
# every deploy script depends on the repo .venv being present and up to date).
if ! command -v uv >/dev/null 2>&1; then
  _ERR "uv is required but was not found on PATH."
  echo "       Install it with: curl -LsSf https://astral.sh/uv/install.sh | sh" >&2
  exit 1
fi
if [ -z "$REPO_ROOT" ]; then
  _ERR "could not locate repo root for uv venv creation"
  exit 1
fi
[ -d "$REPO_ROOT/.venv" ] || uv venv "$REPO_ROOT/.venv" >/dev/null 2>&1 || {
  _ERR "failed to create .venv at $REPO_ROOT/.venv"
  exit 1
}
uv pip install -q -r "$REPO_ROOT/requirements.txt" 2>/dev/null || {
  _ERR "uv pip install failed (requirements.txt)"
  exit 1
}

if [ -z "$REPO_ROOT" ]; then
  _WARN "could not locate repo root for KCL regeneration"
elif command -v kcl >/dev/null 2>&1 && [ -f "$REPO_ROOT/src/main.k" ]; then
  _STEP "Regenerating configs from KCL"
  cd "$REPO_ROOT"
  mkdir -p generated out out/shared out/ghostty out/atuin out/jj out/iamb out/gitlogue out/pnpm out/claude-code out/kiro
  # Resolve local.k at the repo root
  if [ -f "$REPO_ROOT/local.k" ]; then
    LOCAL_K="$REPO_ROOT/local.k"
  else
    _ERR "local.k not found at repo root. Copy local.k.example to local.k and fill in values."
    exit 1
  fi
  _INFO "Running kcl run src/main.k"
  _CMD "kcl run src/main.k <local.k>"
  kcl run src/main.k "$LOCAL_K" >/dev/null || { _ERR "KCL generation failed"; exit 1; }
  _INFO "Converting KCL output to dotter config"
  "$PYTHON" scripts/dotter/generate_from_kcl.py || { _ERR "Python conversion failed"; exit 1; }
  _INFO "Validating generated configs"
  "$PYTHON" scripts/dotter/validate_generated.py || { _ERR "Generated config validation failed"; exit 1; }
  _OK "Configs regenerated"
else
  _ERR "KCL is required for this repository but was not found."
  echo "       Install it with: brew install kcl-lang/tap/kcl" >&2
  exit 1
fi

LOCAL_CONFIG="${DOTTER_LOCAL_CONFIG:-.dotter/local.toml}"

if [ ! -f "$LOCAL_CONFIG" ]; then
  _ERR "Missing local config: $LOCAL_CONFIG"
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

# Pre-deploy schema validation (validate_schema.sh prints its own header)
if [ -n "$REPO_ROOT" ] && [ -f "$REPO_ROOT/scripts/dotter/validate_schema.sh" ]; then
  cd "$REPO_ROOT"
  "$REPO_ROOT/scripts/dotter/validate_schema.sh" --pre-deploy || true
fi
