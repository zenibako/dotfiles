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

# Pre-deploy schema validation
echo "==> Running pre-deploy schema validation..."
_repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$_repo_root" ]; then
  _repo_root="$(cd "$(dirname "$0")/.." && pwd)"
fi
"$_repo_root/.dotter/scripts/validate_schema.sh" --pre-deploy || true
