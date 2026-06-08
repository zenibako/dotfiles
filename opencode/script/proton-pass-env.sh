#!/bin/bash
# Proton Pass Secret Fetcher
# Builds a local credential cache from Proton Pass CLI vaults.
# Does NOT export secrets to the shell environment — instead, writes them
# to a cache file that other tools can read directly.
#
# Usage:
#   proton-pass-env.sh --build           # Fetch secrets and update cache
#   proton-pass-env.sh --get KEY         # Print single secret value to stdout
#   proton-pass-env.sh --keys            # List cached key names
#   proton-pass-env.sh --status          # Show cache freshness
#   proton-pass-env.sh --clear           # Remove the cache
#   proton-pass-env.sh --help            # Show this message
#
# Design principle: secrets are injected into specific config files only
# (e.g. during `dotter deploy`) and never exported as shell env vars.

set -uo pipefail

PROTON_PASS_CACHE="${HOME}/.cache/proton-pass-secrets.env"
CACHE_MAX_AGE_HOURS=1

_log_warn() { printf "[proton-pass] %s\n" "$1" >&2; }
_log_info() { printf "[proton-pass] %s\n" "$1" >&2; }

_has_proton_pass() { command -v proton-pass >/dev/null 2>&1; }

_cache_is_fresh() {
    if [ ! -f "$PROTON_PASS_CACHE" ]; then return 1; fi
    local mtime_epoch
    if [ "$(uname -s)" = "Darwin" ]; then
        mtime_epoch=$(stat -f %m "$PROTON_PASS_CACHE" 2>/dev/null)
    else
        mtime_epoch=$(stat -c %Y "$PROTON_PASS_CACHE" 2>/dev/null)
    fi
    if [ -z "$mtime_epoch" ]; then return 1; fi
    local now_epoch age_seconds max_age_seconds
    now_epoch=$(date +%s)
    age_seconds=$(( now_epoch - mtime_epoch ))
    max_age_seconds=$(( CACHE_MAX_AGE_HOURS * 3600 ))
    [ "$age_seconds" -lt "$max_age_seconds" ]
}

_fetch_secret() {
    local vault="$1" item="$2" result
    if ! _has_proton_pass; then
        _log_warn "proton-pass CLI not found. Secret '$vault/$item' unavailable."
        return 1
    fi
    result=$(proton-pass item get "$vault/$item" 2>/dev/null | jq -r '.password // .value // empty' 2>/dev/null)
    if [ -z "$result" ] || [ "$result" = "null" ]; then
        _log_warn "Failed to fetch secret: $vault/$item"
        return 1
    fi
    printf '%s' "$result"
}

# Write a key/value line to the cache using tab-separated format.
# Three columns: KEY<TAB>VALUE<TAB>raw
_write() {
    local key="$1" value="$2"
    printf '%s\t%s\traw\n' "$key" "$value"
}

# ------------------------------------------------------------------
# Core functions
# ------------------------------------------------------------------

_build_cache() {
    if ! _has_proton_pass; then
        _log_warn "proton-pass CLI not installed. Secrets will not be built."
        _log_warn "Install from: https://github.com/ProtonMail/proton-pass-cli"
        return 1
    fi

    _log_info "Fetching secrets from Proton Pass... (unlock your vault if prompted)"

    local _tmp="${PROTON_PASS_CACHE}.tmp.$$"
    mkdir -p "$(dirname "$PROTON_PASS_CACHE")"

    # Define your secrets here: vault/item-name -> key-name
    # Adjust vault names and item names to match your Proton Pass organization.

    local val

    # --- GitHub ---
    val=$(_fetch_secret "Development" "GitHub PAT") && _write "GITHUB_PERSONAL_ACCESS_TOKEN" "$val" >> "$_tmp"

    # --- Home Assistant ---
    val=$(_fetch_secret "Home" "Home Assistant Token") && _write "HA_TOKEN" "$val" >> "$_tmp"
    val=$(_fetch_secret "Home" "Home Assistant Webhook ID") && _write "HA_WEBHOOK_ID" "$val" >> "$_tmp"

    # --- Bluesky ---
    val=$(_fetch_secret "Social" "Bluesky App Password") && _write "BSKY_APP_PASSWORD" "$val" >> "$_tmp"

    # --- Plex ---
    val=$(_fetch_secret "Media" "Plex User Token") && _write "PLEX_USER_TOKEN" "$val" >> "$_tmp"
    val=$(_fetch_secret "Media" "Plex Server Token") && _write "PLEX_SERVER_TOKEN" "$val" >> "$_tmp"

    # --- TMDB ---
    val=$(_fetch_secret "Media" "TMDB API Key") && _write "TMDB_KEY" "$val" >> "$_tmp"

    # --- Google ---
    val=$(_fetch_secret "Development" "Google Places API Key") && _write "GOOGLE_PLACES_API_KEY" "$val" >> "$_tmp"
    val=$(_fetch_secret "Development" "YouTube API Key") && _write "YOUTUBE_API_KEY" "$val" >> "$_tmp"

    # --- Reddit ---
    val=$(_fetch_secret "Social" "Reddit Session") && _write "REDDIT_SESSION" "$val" >> "$_tmp"
    val=$(_fetch_secret "Social" "Reddit Token v2") && _write "TOKEN_V2" "$val" >> "$_tmp"

    # --- Brave Search ---
    val=$(_fetch_secret "Development" "Brave Search API Key") && _write "BRAVE_API_KEY" "$val" >> "$_tmp"

    # --- Proton Mail Bridge ---
    val=$(_fetch_secret "Email" "Proton Bridge Password") && _write "PROTON_PASSWORD" "$val" >> "$_tmp"

    # --- Telegram ---
    val=$(_fetch_secret "Development" "Telegram Bot Token") && _write "TELEGRAM_BOT_TOKEN" "$val" >> "$_tmp"

    # --- TripIt ---
    val=$(_fetch_secret "Travel" "TripIt Password") && _write "TRIPIT_PASSWORD" "$val" >> "$_tmp"

    # --- Last.fm ---
    val=$(_fetch_secret "Media" "Last.fm API Key") && _write "LAST_FM_API_KEY" "$val" >> "$_tmp"

    # --- Obsidian MCP ---
    val=$(_fetch_secret "Development" "Obsidian MCP Token") && _write "MCP_OBSIDIAN_TOKEN" "$val" >> "$_tmp"

    # --- Rocksky ---
    val=$(_fetch_secret "Media" "Rocksky Password") && _write "ROCKSKY_PASSWORD" "$val" >> "$_tmp"

    # --- Work credentials (only if work profile is active) ---
    if [ "${OPENCODE_PROFILE_WORK:-}" = "true" ] || [ "${OPENCODE_PROFILE_WORK:-}" = "1" ]; then
        val=$(_fetch_secret "Work" "GitLab PAT") && _write "GITLAB_TOKEN" "$val" >> "$_tmp"
        val=$(_fetch_secret "Work" "SonarQube Token") && _write "SONAR_TOKEN" "$val" >> "$_tmp"
        val=$(_fetch_secret "Work" "Postman API Key") && _write "POSTMAN_API_KEY" "$val" >> "$_tmp"
        val=$(_fetch_secret "Work" "Slack Token") && _write "SLACK_TOKEN" "$val" >> "$_tmp"
        val=$(_fetch_secret "Work" "Slack D-Cookie") && _write "SLACK_D_COOKIE" "$val" >> "$_tmp"
    fi

    chmod 600 "$_tmp"
    mv "$_tmp" "$PROTON_PASS_CACHE"
    _log_info "Cache built at ${PROTON_PASS_CACHE} ($(wc -l < "$PROTON_PASS_CACHE" | tr -d ' ') entries)"
}

_ensure_cache() {
    if [ ! -f "$PROTON_PASS_CACHE" ]; then
        _build_cache || return 1
    fi
    if ! _cache_is_fresh; then
        _log_info "Cache expired, rebuilding..."
        _build_cache || return 1
    fi
}

_look_up() {
    local target="$1" key value _enc
    while IFS='\t' read -r key value _enc; do
        [ "$key" = "$target" ] && { printf '%s' "$value"; return 0; }
    done < "$PROTON_PASS_CACHE"
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
        done < "$PROTON_PASS_CACHE"
        ;;
    --status)
        if [ ! -f "$PROTON_PASS_CACHE" ]; then
            _log_info "Cache: NOT BUILT"
        elif _cache_is_fresh; then
            local mtime
            if [ "$(uname -s)" = "Darwin" ]; then
                mtime=$(stat -f %Sm "$PROTON_PASS_CACHE")
            else
                mtime=$(stat -c %y "$PROTON_PASS_CACHE")
            fi
            _log_info "Cache: FRESH (built: $mtime, ${CACHE_MAX_AGE_HOURS}h TTL)"
            _log_info "Cached keys:"
            while IFS='\t' read -r key _value _enc; do
                printf '  %s=***\n' "$key"
            done < "$PROTON_PASS_CACHE"
        else
            _log_info "Cache: EXPIRED"
        fi
        ;;
    --clear)
        if [ -f "$PROTON_PASS_CACHE" ]; then
            rm -f "$PROTON_PASS_CACHE"
            _log_info "Cache cleared."
        else
            _log_info "No cache to clear."
        fi
        ;;
    --help|-h)
        cat <<'EOF'
Usage: proton-pass-env.sh [--build|--get KEY|--keys|--status|--clear|--help]

Build and query a local credential cache from Proton Pass CLI vaults.
Secrets are stored in a private cache file (~/.cache/proton-pass-secrets.env)
in a tab-separated format (KEY<TAB>VALUE<TAB>raw) that avoids shell-quoting
issues and is safe for any character including newlines (via b64 encoding flag).

  --build    Fetch secrets from Proton Pass and rebuild the cache
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
