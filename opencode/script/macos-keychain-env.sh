#!/bin/bash
# macOS Keychain Secret Fetcher
# Fetches secrets from macOS Keychain and caches them locally.
#
# Naming convention: service name (-s flag) matches the output key name exactly.
# Example: security add-generic-password -s HA_TOKEN ... produces key HA_TOKEN
#
# Uses the same CLI interface as proton-pass-env.sh so the two backends
# are interchangeable.
#
# Usage:
#   macos-keychain-env.sh --build           # Fetch secrets and update cache
#   macos-keychain-env.sh --get KEY         # Print single secret value to stdout
#   macos-keychain-env.sh --keys            # List cached key names
#   macos-keychain-env.sh --status          # Show cache freshness
#   macos-keychain-env.sh --clear           # Remove the cache
#
# Setup:
#   Store a secret with: security add-generic-password -s KEY_NAME -a dotfiles \
#                        -w SECRET_VALUE -U login.keychain
#   -s (service)  -> the env var / lookup key (e.g. GITLAB_TOKEN)
#   -a (account)  -> "dotfiles" (used to namespace; can be anything)
#   -U            -> update existing if present
#
# Design principle: secrets are injected into specific config files only
# (e.g. during `dotter deploy`) and never exported as shell env vars.

set -uo pipefail

KEYCHAIN_CACHE="${HOME}/.cache/macos-keychain-secrets.env"
CACHE_MAX_AGE_HOURS=1

_log_warn() { printf "[keychain] %s\n" "$1" >&2; }
_log_info() { printf "[keychain] %s\n" "$1" >&2; }

# Check if security CLI is available (macOS only)
_has_security() { command -v security >/dev/null 2>&1; }

_cache_is_fresh() {
    if [ ! -f "$KEYCHAIN_CACHE" ]; then return 1; fi
    local mtime_epoch
    if [ "$(uname -s)" = "Darwin" ]; then
        mtime_epoch=$(stat -f %m "$KEYCHAIN_CACHE" 2>/dev/null)
    else
        mtime_epoch=$(stat -c %Y "$KEYCHAIN_CACHE" 2>/dev/null)
    fi
    if [ -z "$mtime_epoch" ]; then return 1; fi
    local now_epoch age_seconds max_age_seconds
    now_epoch=$(date +%s)
    age_seconds=$(( now_epoch - mtime_epoch ))
    max_age_seconds=$(( CACHE_MAX_AGE_HOURS * 3600 ))
    [ "$age_seconds" -lt "$max_age_seconds" ]
}

# Fetch a single secret from macOS Keychain by service name.
# Usage: _fetch_secret "SERVICE_NAME"
_fetch_secret() {
    local service="$1"
    if ! _has_security; then
        _log_warn "security CLI not found. Secret '$service' unavailable."
        return 1
    fi
    local result
    result=$(security find-generic-password -s "$service" -w 2>/dev/null)
    if [ -z "$result" ]; then
        _log_warn "Failed to fetch secret from keychain: $service"
        return 1
    fi
    printf '%s' "$result"
}

# Write a key/value line to the cache using tab-separated format.
_write() {
    local key="$1" value="$2"
    printf '%s\t%s\traw\n' "$key" "$value"
}

# ------------------------------------------------------------------
# Core functions
# ------------------------------------------------------------------

_build_cache() {
    if ! _has_security; then
        _log_warn "security CLI not available. Secrets will not be built."
        return 1
    fi

    _log_info "Fetching secrets from macOS Keychain..."

    local _tmp="${KEYCHAIN_CACHE}.tmp.$$"
    mkdir -p "$(dirname "$KEYCHAIN_CACHE")"

    # Define your secrets here: service-name -> key-name
    # The service name is whatever you used with `security add-generic-password -s ...`
    local val

    # --- GitHub ---
    val=$(_fetch_secret "GITHUB_PERSONAL_ACCESS_TOKEN") && _write "GITHUB_PERSONAL_ACCESS_TOKEN" "$val" >> "$_tmp"

    # --- Home Assistant ---
    val=$(_fetch_secret "HA_TOKEN") && _write "HA_TOKEN" "$val" >> "$_tmp"
    val=$(_fetch_secret "HA_WEBHOOK_ID") && _write "HA_WEBHOOK_ID" "$val" >> "$_tmp"

    # --- Bluesky ---
    val=$(_fetch_secret "BSKY_APP_PASSWORD") && _write "BSKY_APP_PASSWORD" "$val" >> "$_tmp"

    # --- Plex ---
    val=$(_fetch_secret "PLEX_USER_TOKEN") && _write "PLEX_USER_TOKEN" "$val" >> "$_tmp"
    val=$(_fetch_secret "PLEX_SERVER_TOKEN") && _write "PLEX_SERVER_TOKEN" "$val" >> "$_tmp"

    # --- TMDB ---
    val=$(_fetch_secret "TMDB_KEY") && _write "TMDB_KEY" "$val" >> "$_tmp"

    # --- Google ---
    val=$(_fetch_secret "GOOGLE_PLACES_API_KEY") && _write "GOOGLE_PLACES_API_KEY" "$val" >> "$_tmp"
    val=$(_fetch_secret "YOUTUBE_API_KEY") && _write "YOUTUBE_API_KEY" "$val" >> "$_tmp"

    # --- Reddit ---
    val=$(_fetch_secret "REDDIT_SESSION") && _write "REDDIT_SESSION" "$val" >> "$_tmp"
    val=$(_fetch_secret "TOKEN_V2") && _write "TOKEN_V2" "$val" >> "$_tmp"

    # --- Brave Search ---
    val=$(_fetch_secret "BRAVE_API_KEY") && _write "BRAVE_API_KEY" "$val" >> "$_tmp"

    # --- Proton Mail Bridge ---
    val=$(_fetch_secret "PROTON_PASSWORD") && _write "PROTON_PASSWORD" "$val" >> "$_tmp"

    # --- Telegram ---
    val=$(_fetch_secret "TELEGRAM_BOT_TOKEN") && _write "TELEGRAM_BOT_TOKEN" "$val" >> "$_tmp"

    # --- TripIt ---
    val=$(_fetch_secret "TRIPIT_PASSWORD") && _write "TRIPIT_PASSWORD" "$val" >> "$_tmp"

    # --- Last.fm ---
    val=$(_fetch_secret "LAST_FM_API_KEY") && _write "LAST_FM_API_KEY" "$val" >> "$_tmp"

    # --- Obsidian MCP ---
    val=$(_fetch_secret "MCP_OBSIDIAN_TOKEN") && _write "MCP_OBSIDIAN_TOKEN" "$val" >> "$_tmp"

    # --- Rocksky ---
    val=$(_fetch_secret "ROCKSKY_PASSWORD") && _write "ROCKSKY_PASSWORD" "$val" >> "$_tmp"

    # --- Work credentials (only if work profile is active) ---
    if [ "${OPENCODE_PROFILE_WORK:-}" = "true" ] || [ "${OPENCODE_PROFILE_WORK:-}" = "1" ]; then
        val=$(_fetch_secret "GITLAB_TOKEN") && _write "GITLAB_TOKEN" "$val" >> "$_tmp"
        val=$(_fetch_secret "SONAR_TOKEN") && _write "SONAR_TOKEN" "$val" >> "$_tmp"
        val=$(_fetch_secret "POSTMAN_API_KEY") && _write "POSTMAN_API_KEY" "$val" >> "$_tmp"
        val=$(_fetch_secret "SLACK_TOKEN") && _write "SLACK_TOKEN" "$val" >> "$_tmp"
        val=$(_fetch_secret "SLACK_D_COOKIE") && _write "SLACK_D_COOKIE" "$val" >> "$_tmp"
    fi

    if [ ! -f "$_tmp" ] || [ ! -s "$_tmp" ]; then
        rm -f "$_tmp"
        _log_warn "No secrets were fetched from macOS Keychain. Have the items been created with the correct service names?"
        return 1
    fi

    chmod 600 "$_tmp"
    mv "$_tmp" "$KEYCHAIN_CACHE"
    _log_info "Cache built at ${KEYCHAIN_CACHE} ($(wc -l < "$KEYCHAIN_CACHE" | tr -d ' ') entries)"
}

_ensure_cache() {
    if [ ! -f "$KEYCHAIN_CACHE" ]; then
        _build_cache || return 1
    fi
    if ! _cache_is_fresh; then
        _log_info "Cache expired, rebuilding..."
        _build_cache || return 1
    fi
}

_look_up() {
    local target="$1" key value _enc
    while IFS=$'\t' read -r key value _enc; do
        [ "$key" = "$target" ] && { printf '%s' "$value"; return 0; }
    done < "$KEYCHAIN_CACHE"
    return 1
}

# ------------------------------------------------------------------
# CLI entry points
# ------------------------------------------------------------------

case "${1:-}" in
    --build)
        _build_cache
        ;;
    --get)
        if [ -z "${2:-}" ]; then
            _log_warn "Usage: $0 --get KEY"
            exit 1
        fi
        _ensure_cache || exit 1
        if ! _look_up "$2"; then
            _log_warn "Key not found in cache: $2"
            exit 1
        fi
        ;;
    --keys)
        _ensure_cache || exit 1
        while IFS='\t' read -r key _value _enc; do
            printf '%s\n' "$key"
        done < "$KEYCHAIN_CACHE"
        ;;
    --status)
        if [ ! -f "$KEYCHAIN_CACHE" ]; then
            _log_info "Cache: NOT BUILT"
        elif _cache_is_fresh; then
            local mtime
            if [ "$(uname -s)" = "Darwin" ]; then
                mtime=$(stat -f %Sm "$KEYCHAIN_CACHE")
            else
                mtime=$(stat -c %y "$KEYCHAIN_CACHE")
            fi
            _log_info "Cache: FRESH (built: $mtime, ${CACHE_MAX_AGE_HOURS}h TTL)"
            _log_info "Cached keys:"
            while IFS='\t' read -r key _value _enc; do
                printf '  %s=***\n' "$key"
            done < "$KEYCHAIN_CACHE"
        else
            _log_info "Cache: EXPIRED"
        fi
        ;;
    --clear)
        if [ -f "$KEYCHAIN_CACHE" ]; then
            rm -f "$KEYCHAIN_CACHE"
            _log_info "Cache cleared."
        else
            _log_info "No cache to clear."
        fi
        ;;
    --help|-h)
        cat <<'EOF'
Usage: macos-keychain-env.sh [--build|--get KEY|--keys|--status|--clear|--help]

Build and query a local credential cache from the macOS Keychain.
Secrets are stored in a private cache file (~/.cache/macos-keychain-secrets.env)
in a tab-separated format (KEY<TAB>VALUE<TAB>raw) that avoids shell-quoting
issues and is safe for any character including newlines (via b64 encoding flag).

Setup: store each secret with the macOS security command:

  security add-generic-password -s KEY_NAME -a dotfiles -w SECRET_VALUE \
      -U login.keychain

  -s (service)  -> the env var / lookup key (e.g. GITLAB_TOKEN)
  -a (account)  -> "dotfiles" (used to namespace)
  -U             -> update existing if present

  --build    Fetch secrets from Keychain and rebuild the cache
  --get KEY  Print the raw value of KEY to stdout
  --keys     List all cached key names
  --status   Show cache freshness and list cached key names
  --clear    Remove the local credential cache
  --help     Show this message

The cache is refreshed automatically when it is older than 1 hour.
EOF
        ;;
    *)
        _log_warn "Unknown option: ${1:-(none)}. Try --help."
        exit 1
        ;;
esac
