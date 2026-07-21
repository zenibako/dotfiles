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

# ── Regenerate .dotter/global.toml + out/ files from the KCL source ───────
# Runs the full generation pipeline: ensure the uv venv + deps, `kcl run`, the
# Python converter, then the generated-config validator. Hard-fails (exit 1) on
# any missing tool or generation error.
#
# This is the single source of truth for KCL regeneration, shared by two
# callers with different needs around dotter's config read-order:
#   • deploy.sh runs it BEFORE `dotter deploy`, because dotter parses
#     .dotter/global.toml (file mappings + settings) at config-load time —
#     before any hook fires. Regenerating only in the pre_deploy hook would
#     leave the current deploy using a stale (or, on a fresh clone, missing)
#     global.toml.
#   • the pre_deploy hook runs it so a direct `dotter deploy` (no wrapper)
#     still regenerates out/ file contents before they are copied.
# To avoid regenerating twice on the deploy.sh path, deploy.sh exports
# DOTTER_SKIP_KCL_REGEN=1 and the hook skips its own call.
#
# Requires REPO_ROOT and PYTHON to be set (call resolve_repo_root /
# resolve_python first), or pass the repo root as $1.
regenerate_from_kcl() {
  local root="${1:-$REPO_ROOT}"

  if [ -z "$root" ]; then
    _ERR "could not locate repo root for KCL regeneration"
    exit 1
  fi

  # Ensure Python venv and dependencies exist (hard-fail if uv is missing —
  # every deploy script depends on the repo .venv being present and current).
  if ! command -v uv >/dev/null 2>&1; then
    _ERR "uv is required but was not found on PATH."
    _GUIDE "Install it with: curl -LsSf https://astral.sh/uv/install.sh | sh"
    exit 1
  fi
  [ -d "$root/.venv" ] || uv venv "$root/.venv" >/dev/null 2>&1 || {
    _ERR "failed to create .venv at $root/.venv"
    exit 1
  }

  local venv_py="$root/.venv/bin/python3"

  # Only reach the network when a required module is actually missing, so a
  # normal deploy still succeeds offline once the venv is populated (and does
  # not hard-fail on a transient network blip). --system-certs makes uv use the
  # OS trust store so corporate TLS interception (e.g. Netskope) doesn't break
  # the PyPI fetch with an UnknownIssuer error. stderr is intentionally NOT
  # suppressed — a failed install should show its real cause.
  if ! "$venv_py" -c 'import tomli_w, tomli' >/dev/null 2>&1; then
    _INFO "Installing Python dependencies"
    uv pip install -q --system-certs --python "$venv_py" -r "$root/requirements.txt" || {
      _ERR "uv pip install failed (requirements.txt)"
      exit 1
    }
  fi

  # KCL is mandatory for this repository.
  if ! command -v kcl >/dev/null 2>&1 || [ ! -f "$root/src/main.k" ]; then
    _ERR "KCL is required for this repository but was not found."
    _GUIDE "Install it with: brew install kcl-lang/tap/kcl"
    exit 1
  fi

  _STEP "Regenerating configs from KCL"
  cd "$root"
  mkdir -p generated out out/shared out/ghostty out/atuin out/jj out/iamb out/gitlogue out/pnpm out/claude-code out/kiro

  # Resolve the per-machine overrides file. It is gitignored and lives next to
  # main.k inside the KCL package; src/main.k pulls it in via `import local`.
  if [ ! -f "$root/src/local.k" ]; then
    _ERR "src/local.k not found. Copy src/local.k.example to src/local.k and fill in values."
    exit 1
  fi

  _INFO "Running kcl run src/main.k"
  _CMD "kcl run src/main.k"
  kcl run src/main.k >/dev/null || { _ERR "KCL generation failed"; exit 1; }
  _INFO "Converting KCL output to dotter config"
  "$venv_py" scripts/dotter/generate_from_kcl.py || { _ERR "Python conversion failed"; exit 1; }
  _INFO "Validating generated configs"
  "$venv_py" scripts/dotter/validate_generated.py || { _ERR "Generated config validation failed"; exit 1; }
  _OK "Configs regenerated"
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
# Usage: begin_wait "Validating Neovim LSP attachments" "up to 5 min"
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

# Surface the one manual step per machine for TTY-less GPG signing: warn (with
# the exact store command) when a signing key is configured but the OS secret
# store has no GPG passphrase for gpg-warm-agent to preset. Silent when there
# is nothing actionable (no signing key, or no secret-store backend).
# Usage: gpg_warm_cta
gpg_warm_cta() {
  _gpg_key=$(git config --get user.signingkey 2>/dev/null || true)
  [ -n "$_gpg_key" ] || return 0
  if command -v security >/dev/null 2>&1; then
    security find-generic-password -s GPG_PASSPHRASE -a dotfiles >/dev/null 2>&1 && return 0
    _store_cmd="security add-generic-password -s GPG_PASSPHRASE -a dotfiles -w 'YOUR_PASSPHRASE' -U login.keychain"
  elif command -v secret-tool >/dev/null 2>&1; then
    [ -n "$(secret-tool lookup service GPG_PASSPHRASE account dotfiles 2>/dev/null)" ] && return 0
    _store_cmd="secret-tool store --label='GPG passphrase' service GPG_PASSPHRASE account dotfiles"
  else
    return 0
  fi
  _WARN "GPG passphrase not in the OS secret store (or the keychain is locked) — TTY-less signing will fail once the agent cache goes cold"
  _GUIDE "One-time setup for this machine (signing key $_gpg_key):"
  _GUIDE "  $_store_cmd"
  unset _gpg_key _store_cmd
}
