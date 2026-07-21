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

# ── Regenerate configs from KCL first ─────────────────────────────────────
_STEP "Pre-deploy: environment setup"
resolve_repo_root
resolve_python

# deploy.sh already regenerates before invoking dotter (dotter reads global.toml
# at config-load time, before this hook fires). It exports DOTTER_SKIP_KCL_REGEN
# so we don't redo the same work here. A direct `dotter deploy` leaves the flag
# unset, so this hook regenerates on its own.
if [ "${DOTTER_SKIP_KCL_REGEN:-}" = "1" ]; then
  _SKIP "KCL regeneration (already done by deploy.sh)"
else
  regenerate_from_kcl "$REPO_ROOT"
fi

LOCAL_CONFIG="${DOTTER_LOCAL_CONFIG:-.dotter/local.toml}"

if [ ! -f "$LOCAL_CONFIG" ]; then
  _ERR "Missing local config: $LOCAL_CONFIG"
  exit 1
fi

# Pinentry detection for direct `dotter deploy` runs (deploy.sh already ran it
# pre-load; from inside this hook a new value only takes effect next run).
if [ -n "$REPO_ROOT" ] && [ -f "$REPO_ROOT/scripts/dotter/detect_pinentry.sh" ]; then
  sh "$REPO_ROOT/scripts/dotter/detect_pinentry.sh" || true
fi

get_var() {
  grep -E "^[[:space:]]*$1[[:space:]]*=" "$LOCAL_CONFIG" | tail -n 1 | cut -d '=' -f 2- | tr -d '"' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

require_var() {
  local value
  value=$(get_var "$1")
  case "$value" in
    ""|"Your Name"|"your@email.com")
      _ERR "dotter deploy blocked: set '$1' in $LOCAL_CONFIG before deploying."
      exit 1 ;;
  esac
}

require_var name
require_var email

# Pre-deploy schema validation (validate_schema.sh prints its own header).
# Hard-fail on parse errors so a broken template can't ship and break every
# shell session. The validator returns 0 when tooling is missing (via _SKIP),
# so this only blocks on genuine file validation failures.
if [ -n "$REPO_ROOT" ] && [ -f "$REPO_ROOT/scripts/dotter/validate_schema.sh" ]; then
  cd "$REPO_ROOT"
  if ! "$REPO_ROOT/scripts/dotter/validate_schema.sh" --pre-deploy; then
    _ERR "Pre-deploy validation failed — blocking deploy. Fix the errors above and re-run."
    exit 1
  fi
fi
