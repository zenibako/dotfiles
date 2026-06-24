#!/bin/sh
# Shared helpers for deploy scripts. Source this file, do not execute it.
# Usage: . "$(dirname "$0")/dotter/lib.sh"  (from scripts/)
#        . "$_scripts/lib.sh"               (when $_scripts is set)

# ── ANSI colors + output helpers ─────────────────────────────────────────
# Single source of truth for every deploy script. Colors are emitted only when
# stdout is a terminal and NO_COLOR is unset, so piped/CI output and captured
# logs stay free of escape sequences. _ERR/_WARN go to stderr, _OK to stdout.
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  COLOR_RED='\033[31m'
  COLOR_YELLOW='\033[33m'
  COLOR_GREEN='\033[32m'
  COLOR_RESET='\033[0m'
else
  COLOR_RED=''
  COLOR_YELLOW=''
  COLOR_GREEN=''
  COLOR_RESET=''
fi

_ERR()  { printf "${COLOR_RED}ERROR:${COLOR_RESET} %s\n" "$1" >&2; }
_WARN() { printf "${COLOR_YELLOW}WARNING:${COLOR_RESET} %s\n" "$1" >&2; }
_OK()   { printf "${COLOR_GREEN}OK:${COLOR_RESET} %s\n" "$1"; }

# Per-item check results (used in validation loops). _PASS to stdout, _FAIL to
# stderr; both keep the ✓/✗ glyph idiom but pull their color from above.
_PASS() { printf "${COLOR_GREEN}✓${COLOR_RESET} %s\n" "$1"; }
_FAIL() { printf "${COLOR_RED}✗${COLOR_RESET} %s\n" "$1" >&2; }

# ── Repo root resolution ─────────────────────────────────────────────────
# Sets REPO_ROOT. Tries git first, then walks up from the caller's location.
resolve_repo_root() {
  REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" && return
  local _dir
  _dir="$(cd "$(dirname "$0")" && pwd)"
  while [ "$_dir" != "/" ]; do
    if [ -f "$_dir/scripts/dotter/generate_from_kcl.py" ]; then
      REPO_ROOT="$_dir"
      return
    fi
    _dir="$(dirname "$_dir")"
  done
  echo "WARNING: could not locate repo root" >&2
  REPO_ROOT=""
}

# ── Python interpreter detection ─────────────────────────────────────────
# Sets PYTHON to the best available interpreter (project venv > system).
resolve_python() {
  local root="${1:-$REPO_ROOT}"
  PYTHON="python3"
  if [ -f "$root/.venv/bin/python3" ]; then
    PYTHON="$root/.venv/bin/python3"
  elif [ -f "$root/venv/bin/python3" ]; then
    PYTHON="$root/venv/bin/python3"
  fi
}

# ── Ensure .dotter/ output dir + hook symlinks ────────────────────────────
ensure_dotter_dir() {
  local root="${1:-$REPO_ROOT}"
  mkdir -p "$root/.dotter"
  ln -sf ../scripts/pre_deploy.sh "$root/.dotter/pre_deploy.sh"
  ln -sf ../scripts/post_deploy.sh "$root/.dotter/post_deploy.sh"
}

# ── Cross-platform timeout wrapper ───────────────────────────────────────
# Usage: run_with_timeout SECONDS command [args...]
run_with_timeout() {
  local secs="$1"; shift
  if command -v timeout >/dev/null 2>&1; then
    timeout "$secs" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$secs" "$@"
  else
    "$@"
  fi
}

# ── Announce a step that may pause for a while ───────────────────────────
# Prints a clear "waiting expected" indicator so a long pause does not look
# like a hang. Highlights in yellow on a TTY; plain text otherwise.
# Usage: begin_wait "Validating LSP attachments" "up to 5 min"
begin_wait() {
  if [ -t 1 ]; then
    printf "${COLOR_YELLOW}⏳ %s — this can take %s, please wait...${COLOR_RESET}\n" "$1" "$2"
  else
    printf '==> %s — this can take %s, please wait...\n' "$1" "$2"
  fi
}
