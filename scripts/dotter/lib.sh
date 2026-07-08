#!/bin/sh
# Shared helpers for deploy scripts. Source this file, do not execute it.
# Usage: . "$(dirname "$0")/dotter/lib.sh"  (from scripts/)
#        . "$_scripts/lib.sh"               (when $_scripts is set)

# ── ANSI colors + output helpers ─────────────────────────────────────────
# Single source of truth for every deploy script. Colors are emitted only when
# stdout is a terminal and NO_COLOR is unset, so piped/CI output and captured
# logs stay free of escape sequences. _ERR/_WARN go to stderr, _OK/_STEP/_INFO
# to stdout.
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  COLOR_RED='\033[31m'
  COLOR_GREEN='\033[32m'
  COLOR_YELLOW='\033[33m'
  COLOR_BLUE='\033[34m'
  COLOR_CYAN='\033[36m'
  COLOR_GRAY='\033[90m'
  COLOR_BOLD='\033[1m'
  COLOR_RESET='\033[0m'
else
  COLOR_RED=''
  COLOR_GREEN=''
  COLOR_YELLOW=''
  COLOR_BLUE=''
  COLOR_CYAN=''
  COLOR_GRAY=''
  COLOR_BOLD=''
  COLOR_RESET=''
fi

_ERR()  { printf "  ${COLOR_RED}ERROR:${COLOR_RESET} %s\n" "$1" >&2; }
_WARN() { printf "  ${COLOR_YELLOW}WARNING:${COLOR_RESET} %s\n" "$1" >&2; }
_OK()   { printf "  ${COLOR_GREEN}OK:${COLOR_RESET} %s\n" "$1"; }

# Per-item check results (used in validation loops). _PASS to stdout, _FAIL to
# stderr; both use a 2-space indent + ✓/✗ glyph to align with the Python
# validators (validate_generated.py, validate_opencode_models.py) which emit
# `  ✓ message` via their own _ok() helper.
_PASS() { printf "  ${COLOR_GREEN}✓${COLOR_RESET} %s\n" "$1"; }
_FAIL() { printf "  ${COLOR_RED}✗${COLOR_RESET} %s\n" "$1" >&2; }

# Major phase header. Bold blue arrow stands out from the body lines so the
# high-level pipeline stages (pre-deploy, dotter, post-deploy) are scannable.
# Usage: _STEP "Running pre-deploy validation"
_STEP() { printf "${COLOR_BOLD}${COLOR_BLUE}==>${COLOR_RESET} ${COLOR_BOLD}%s${COLOR_RESET}\n" "$1"; }

# Neutral informational line (a nested action inside a step). Cyan keeps it
# distinct from _STEP headers and from the green/red status lines.
# Usage: _INFO "Regenerating configs from KCL..."
_INFO() { printf "  ${COLOR_CYAN}• %s${COLOR_RESET}\n" "$1"; }

# A command being run on the user's behalf. Gray prefix marks it as a quoted
# command rather than narrative output. Goes to stderr so it doesn't pollute
# stdout when scripts are piped.
# Usage: _CMD "dotter deploy --force"
_CMD()  { printf "  ${COLOR_GRAY}$ %s${COLOR_RESET}\n" "$1" >&2; }

# Skip notice: the step was intentionally bypassed (tool missing, file absent,
# not applicable on this platform). Yellow so it's visible but not alarming.
# Usage: _SKIP "Skipping Lua validation (luac not installed)"
_SKIP() { printf "  ${COLOR_YELLOW}⊘ %s${COLOR_RESET}\n" "$1"; }

# Guidance step (indented, gray) — for actionable "to fix:" lines that follow
# a _WARN or _ERR. Keeps the recovery instructions visually quiet so the
# headline warning stays the focus. Goes to stderr.
# Usage: _GUIDE "Run: scripts/secrets/proton-pass-env.sh --build"
_GUIDE() { printf "    ${COLOR_GRAY}%s${COLOR_RESET}\n" "$1" >&2; }

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
  _WARN "could not locate repo root"
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
  if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    printf "  ${COLOR_YELLOW}⏳ %s — this can take %s, please wait...${COLOR_RESET}\n" "$1" "$2"
  else
    printf '  ⏳ %s — this can take %s, please wait...\n' "$1" "$2"
  fi
}

# Convenience for the common "announce + run" pattern. Prints the step header
# then runs a command. Echoes the command first (via _CMD) so the user can see
# exactly what is being executed.
# Usage: _RUN "Deploying with dotter" dotter deploy --force
_RUN() {
  local _msg="$1"; shift
  _STEP "$_msg"
  _CMD "$*"
  "$@"
}
