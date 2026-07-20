#!/bin/sh
# Seed the local secret caches consumed by post_deploy.sh.
#
# Deploys are consume-only: post_deploy injects secrets from whichever cache
# file already exists (~/.cache/proton-pass-secrets.env, falling back to
# ~/.cache/macos-keychain-secrets.env) and never builds one inline. This
# script owns building — run it explicitly after rotating a secret, when a
# deploy warns the cache is missing/stale, or on a fresh machine.
#
# Usage:
#   scripts/secrets/seed-secrets.sh            # build whichever backend is configured
#   scripts/secrets/seed-secrets.sh --force    # rebuild even if the cache is fresh
#   scripts/secrets/seed-secrets.sh --status   # show cache freshness per backend
#
# Backend preference: Proton Pass (pass-cli) first, macOS Keychain fallback —
# the same order post_deploy uses when consuming.
set -eu

# Resolve lib.sh whether run from the repo or from a copied hook context.
# shellcheck source=../dotter/lib.sh
_self="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
if [ -f "$_self/../dotter/lib.sh" ]; then
  . "$_self/../dotter/lib.sh"
else
  . "$(git rev-parse --show-toplevel 2>/dev/null || pwd)/scripts/dotter/lib.sh"
fi

resolve_repo_root

_PP_SCRIPT="$REPO_ROOT/scripts/secrets/proton-pass-env.sh"
_KC_SCRIPT="$REPO_ROOT/scripts/secrets/macos-keychain-env.sh"
_PP_CACHE="$HOME/.cache/proton-pass-secrets.env"
_KC_CACHE="$HOME/.cache/macos-keychain-secrets.env"

_FORCE=0
case "${1:-}" in
  --force) _FORCE=1 ;;
  --status)
    for _s in "$_PP_SCRIPT" "$_KC_SCRIPT"; do
      [ -x "$_s" ] && "$_s" --status || true
    done
    exit 0
    ;;
  "") ;;
  *) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac

_LAST_BACKEND_ERR=""

# Check if a cache file is fresh (< 72 hours old — matches the backends'
# CACHE_MAX_AGE_HOURS; secrets rarely rotate, so freshness is advisory).
_cache_is_fresh() {
  _file="$1"
  [ -f "$_file" ] || return 1
  if [ "$(uname -s)" = "Darwin" ]; then
    _mtime=$(stat -f %m "$_file" 2>/dev/null)
  else
    _mtime=$(stat -c %Y "$_file" 2>/dev/null)
  fi
  [ -n "$_mtime" ] || return 1
  [ $(( $(date +%s) - _mtime )) -lt $(( 72 * 3600 )) ]
}

# Check if the macOS login keychain is locked. Returns 0 if unlocked.
# `security show-keychain-info` fails with rc=36 when locked.
_keychain_is_unlocked() {
  [ "$(uname -s)" = "Darwin" ] || return 0
  security show-keychain-info ~/Library/Keychains/login.keychain-db >/dev/null 2>&1
}

# Attempt to unlock the keychain non-interactively (works if the keychain
# password is cached). Short timeout so a headless run cannot hang on a prompt.
_try_unlock_keychain() {
  [ "$(uname -s)" = "Darwin" ] || return 0
  run_with_timeout 5 security unlock-keychain >/dev/null 2>&1
}

# Run a backend's --build, adapting to interactive vs headless context.
# Interactive: no timeout, so vault-unlock prompts reach the user.
# Headless: 15s timeout + stderr capture so a hanging prompt fails fast.
_build_backend() {
  _script="$1"
  if [ -t 0 ]; then
    "$_script" --build && return 0
    _LAST_BACKEND_ERR="build failed (see output above)"
    return 1
  fi
  _err=$(run_with_timeout 15 "$_script" --build 2>&1 >/dev/null) && return 0
  _LAST_BACKEND_ERR="$_err"
  return 1
}

# Ensure one backend's cache is ready. Returns 0 with a usable cache.
_try_backend() {
  _script="$1" _cache="$2"
  [ -x "$_script" ] && "$_script" --configured >/dev/null 2>&1 || return 1
  if [ "$_FORCE" = "0" ] && _cache_is_fresh "$_cache"; then
    _OK "$(basename "$_cache") is fresh (use --force to rebuild)"
    return 0
  fi

  _backend_name="$(basename "$_script" .sh)"
  # Proton Pass needs the macOS keychain unlocked to reach its encryption key.
  if [ "$_backend_name" = "proton-pass-env" ] && ! _keychain_is_unlocked; then
    _LAST_BACKEND_ERR="KEYCHAIN_LOCKED"
    begin_wait "Building secret cache ($_backend_name)" "up to 1 min; may prompt to unlock"
    if _try_unlock_keychain && _keychain_is_unlocked; then
      _build_backend "$_script" && return 0
    fi
    return 1
  fi

  begin_wait "Building secret cache ($_backend_name)" "up to 1 min; may prompt to unlock"
  _build_backend "$_script"
}

# Diagnose a backend failure and print actionable guidance.
# Returns 0 if the user's issue was resolved (caller should retry), 1 if not.
_diagnose_backend_failure() {
  _display_name="$1" _script_path="$2" _derr="${_LAST_BACKEND_ERR:-}"

  if [ "$_derr" = "KEYCHAIN_LOCKED" ]; then
    echo "" >&2
    _WARN "The macOS keychain is locked, blocking $_display_name from accessing its encryption key."
    if _try_unlock_keychain && _keychain_is_unlocked; then
      _INFO "Keychain unlocked. Retrying..." >&2
      return 0
    fi
    _ERR "Could not unlock keychain automatically."
    _GUIDE "Run this in a terminal, then re-run: security unlock-keychain"
    return 1
  fi

  if printf '%s' "$_derr" | grep -q "No secrets were fetched from macOS Keychain"; then
    _WARN "$_display_name found no secrets in macOS Keychain."
    _GUIDE "Secrets may not have been stored yet, or the keychain is locked."
    _GUIDE "Check: security unlock-keychain && $_script_path --build"
    return 1
  fi

  if printf '%s' "$_derr" | grep -q "No secrets were fetched"; then
    _WARN "$_display_name could not fetch any secrets from the vault."
    _GUIDE "The vault may be locked or items are missing/misnamed. To fix:"
    _GUIDE "1. Run: $_script_path --build"
    _GUIDE "2. Unlock the vault when prompted"
    return 1
  fi

  if printf '%s' "$_derr" | grep -q "Fetching secrets from Proton Pass"; then
    _WARN "$_display_name timed out waiting for the Proton Pass vault to unlock."
    _GUIDE "Run interactively so the unlock prompt is reachable: $0"
    return 1
  fi

  _WARN "$_display_name failed to build its secret cache."
  [ -n "$_derr" ] && printf '%s\n' "$_derr" | sed 's/^/    /' >&2
  return 1
}

_STEP "Seeding secret caches"

if _try_backend "$_PP_SCRIPT" "$_PP_CACHE"; then
  _OK "Proton Pass cache ready: $_PP_CACHE"
  exit 0
fi
if [ -x "$_PP_SCRIPT" ] && "$_PP_SCRIPT" --configured >/dev/null 2>&1; then
  if _diagnose_backend_failure "Proton Pass" "$_PP_SCRIPT"; then
    # Keychain was unlocked; retry once.
    if _try_backend "$_PP_SCRIPT" "$_PP_CACHE"; then
      _OK "Proton Pass cache ready: $_PP_CACHE"
      exit 0
    fi
  fi
else
  _INFO "Proton Pass (pass-cli) not installed; trying macOS Keychain"
fi

if _try_backend "$_KC_SCRIPT" "$_KC_CACHE"; then
  _OK "macOS Keychain cache ready: $_KC_CACHE"
  exit 0
fi
_diagnose_backend_failure "macOS Keychain" "$_KC_SCRIPT" || true
_ERR "No secret backend produced a cache."
exit 1
