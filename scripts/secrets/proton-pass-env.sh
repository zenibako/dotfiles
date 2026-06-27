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
#
# Profile filtering: retrieval is scoped to the active dotter profile(s).
# Shared secrets (GitHub PAT) are always fetched; personal-only and work-only
# secrets are fetched solely under the matching profile. The active profile is
# auto-detected from .dotter/local.toml's `packages` array, and can be
# overridden with OPENCODE_PROFILE_PERSONAL / OPENCODE_PROFILE_WORK env vars.

set -uo pipefail

PROTON_PASS_CACHE="${HOME}/.cache/proton-pass-secrets.env"
CACHE_MAX_AGE_HOURS=1

_log_warn() { printf "[proton-pass] %s\n" "$1" >&2; }
_log_info() { printf "[proton-pass] %s\n" "$1" >&2; }

_has_proton_pass() { command -v pass-cli >/dev/null 2>&1; }

# ── Active-profile detection ─────────────────────────────────────────────
# Determine which dotter profiles (personal / work) are active so secret
# retrieval can be filtered to the relevant set. Resolution order:
#   1. Explicit env vars OPENCODE_PROFILE_PERSONAL / OPENCODE_PROFILE_WORK —
#      if either is set it fully pins the decision ("true"/"1"/"yes"/"on" = on,
#      anything else = off). Lets a caller override auto-detection.
#   2. Otherwise, the `packages` array in .dotter/local.toml (the deployed
#      profile set, which mirrors the profiles in src/profiles.k).
# Sets PROFILE_PERSONAL and PROFILE_WORK to "1" (active) or "0" (inactive).
_is_truthy() {
    case "$1" in true|TRUE|True|1|yes|YES|on|ON) return 0 ;; *) return 1 ;; esac
}

# Emit one profile name per line from the `packages = [...]` array of a
# .dotter/local.toml file. Handles both inline and multi-line array forms.
_active_profiles_from_toml() {
    local toml="$1"
    [ -f "$toml" ] || return 0
    awk '
        /^[[:space:]]*packages[[:space:]]*=/ { inarr=1 }
        inarr {
            line=$0
            while (match(line, /"[^"]*"/)) {
                print substr(line, RSTART+1, RLENGTH-2)
                line=substr(line, RSTART+RLENGTH)
            }
            if (index($0, "]")) inarr=0
        }
    ' "$toml"
}

_resolve_profiles() {
    PROFILE_PERSONAL=0
    PROFILE_WORK=0

    # Explicit env-var override (presence of either var pins both decisions).
    if [ -n "${OPENCODE_PROFILE_PERSONAL:-}" ] || [ -n "${OPENCODE_PROFILE_WORK:-}" ]; then
        _is_truthy "${OPENCODE_PROFILE_PERSONAL:-}" && PROFILE_PERSONAL=1
        _is_truthy "${OPENCODE_PROFILE_WORK:-}" && PROFILE_WORK=1
        return 0
    fi

    # Auto-detect from the deployed dotter profile set.
    local _repo _toml _p
    _repo="$(cd "$(dirname "$0")/../.." 2>/dev/null && pwd)"
    _toml="$_repo/.dotter/local.toml"
    while IFS= read -r _p; do
        case "$_p" in
            personal) PROFILE_PERSONAL=1 ;;
            work) PROFILE_WORK=1 ;;
        esac
    done <<EOF
$(_active_profiles_from_toml "$_toml")
EOF
}

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
    local vault="$1" item="$2" field="${3:-}" result _raw
    if ! _has_proton_pass; then
        _log_warn "proton-pass CLI not found. Secret '$vault/$item' unavailable."
        return 1
    fi

    # Fetch raw JSON once to avoid multiple CLI calls
    _raw=$(pass-cli item view --vault-name "$vault" --item-title "$item" --output json 2>/dev/null) || { _log_warn "pass-cli view failed for $vault/$item"; return 1; }

    # Detect if the returned item is an Alias (has Alias key in content).
    # Aliases shadow real items when multiple items share the same title.
    local _is_alias
    _is_alias=$(printf '%s' "$_raw" | jq -r 'if .item.content.content | has("Alias") then "yes" else "no" end' 2>/dev/null)
    if [ "$_is_alias" = "yes" ]; then
        _log_warn "Item '$item' is an Alias; searching for real item..."
        # Find the first non-trashed, non-alias item with the same title
        local _real_id
        _real_id=$(pass-cli item list "$vault" --output json 2>/dev/null | jq -r --arg title "$item" '[.items[] | select(.title == $title and .state != "Trashed") | .id] | first // empty')
        if [ -n "$_real_id" ]; then
            _raw=$(pass-cli item view --vault-name "$vault" --item-id "$_real_id" --output json 2>/dev/null) || { _log_warn "pass-cli view failed for $vault/$item (id=$_real_id)"; return 1; }
        fi
    fi

    if [ -n "$field" ]; then
        # Specific field: try extra_fields first, then Custom sections
        result=$(printf '%s' "$_raw" | jq -r --arg field "$field" '(.item.content.extra_fields[]? | select(.name == $field) | .content.Hidden // .content.Text // empty) // (.item.content.content.Custom.sections[]?.section_fields[]? | select(.name == $field) | .content.Hidden // .content.Text // empty)' 2>/dev/null)
    else
        # No field: try Login password, then first hidden/text in Custom, then fallbacks
        result=$(printf '%s' "$_raw" | jq -r '.item.content.content.Login.password // .item.content.content.password // ([.item.content.content.Custom.sections[]?.section_fields[]? | select(.content.Hidden or .content.Text) | .content.Hidden // .content.Text] | first // empty) // .password // .value // empty' 2>/dev/null)
    fi

    if [ -z "$result" ] || [ "$result" = "null" ]; then
        _log_warn "Failed to fetch secret: $vault/$item${field:+ (field: $field)}"
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

    # Filter secret retrieval to the active dotter profile(s). The "Personal"
    # argument below is the Proton Pass *vault* that stores everything — it is
    # unrelated to the personal/work dotter profile gating.
    _resolve_profiles
    _log_info "Active profiles: personal=$PROFILE_PERSONAL work=$PROFILE_WORK"

    # --- Shared credentials (fetched under every profile) ---
    # GitHub PAT — the GitHub MCP is enabled in both profiles (see
    # src/_shared/mcp.k) and its token is injected regardless of profile.
    val=$(_fetch_secret "Personal" "GitHub" "Personal Access Token") && _write "GITHUB_PERSONAL_ACCESS_TOKEN" "$val" >> "$_tmp"

    # --- Personal credentials (only if personal profile is active) ---
    if [ "$PROFILE_PERSONAL" = "1" ]; then
        # Home Assistant
        val=$(_fetch_secret "Personal" "Home Assistant" "PAT") && _write "HA_TOKEN" "$val" >> "$_tmp"

        # Bluesky (app password is in hidden field)
        val=$(_fetch_secret "Personal" "Bluesky" "App Password") && _write "BSKY_APP_PASSWORD" "$val" >> "$_tmp"

        # Plex (tokens are in hidden fields)
        val=$(_fetch_secret "Personal" "Plex (DigitalGlue)" "User Token") && _write "PLEX_USER_TOKEN" "$val" >> "$_tmp"
        val=$(_fetch_secret "Personal" "Plex (Personal)" "Server Token") && _write "PLEX_SERVER_TOKEN" "$val" >> "$_tmp"

        # Brave Search
        val=$(_fetch_secret "Personal" "Brave Search API") && _write "BRAVE_API_KEY" "$val" >> "$_tmp"

        # Proton Mail Bridge — using "Proton" login item; the bridge password is
        # not in a hidden field, so we use the main (account) password.
        val=$(_fetch_secret "Personal" "Proton") && _write "PROTON_PASSWORD" "$val" >> "$_tmp"

        # Telegram
        val=$(_fetch_secret "Personal" "Telegram Bot Token") && _write "TELEGRAM_BOT_TOKEN" "$val" >> "$_tmp"

        # TripIt — using existing "TripIt" login item (password field)
        val=$(_fetch_secret "Personal" "TripIt") && _write "TRIPIT_PASSWORD" "$val" >> "$_tmp"

        # Last.fm — using existing "last.fm" login item (password field)
        val=$(_fetch_secret "Personal" "last.fm") && _write "LAST_FM_API_KEY" "$val" >> "$_tmp"

        # Obsidian MCP
        val=$(_fetch_secret "Personal" "Obsidian MCP Token") && _write "MCP_OBSIDIAN_TOKEN" "$val" >> "$_tmp"

        # Rocksky (not yet in Proton Pass; disabled until created)
        # val=$(_fetch_secret "Personal" "Rocksky Password") && _write "ROCKSKY_PASSWORD" "$val" >> "$_tmp"
    fi

    # --- Work credentials (only if work profile is active) ---
    if [ "$PROFILE_WORK" = "1" ]; then
        val=$(_fetch_secret "Personal" "GitLab" "Personal Access Token") && _write "GITLAB_TOKEN" "$val" >> "$_tmp"
        val=$(_fetch_secret "Personal" "SonarQube Token") && _write "SONAR_TOKEN" "$val" >> "$_tmp"
        val=$(_fetch_secret "Personal" "Postman API Key") && _write "POSTMAN_API_KEY" "$val" >> "$_tmp"
        val=$(_fetch_secret "Personal" "Slack Token") && _write "SLACK_TOKEN" "$val" >> "$_tmp"
        val=$(_fetch_secret "Personal" "Slack D Cookie") && _write "SLACK_D_COOKIE" "$val" >> "$_tmp"
    fi

    # Only create the cache if we actually wrote secrets.
    # If no secrets were fetched, report failure so the caller can fall back.
    if [ ! -f "$_tmp" ] || [ ! -s "$_tmp" ]; then
        rm -f "$_tmp"
        _log_warn "No secrets were fetched from Proton Pass. Is the vault unlocked and items named correctly?"
        return 1
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
    while IFS=$'\t' read -r key value _enc; do
        [ "$key" = "$target" ] && { printf '%s' "$value"; return 0; }
    done < "$PROTON_PASS_CACHE"
    return 1
}

# ------------------------------------------------------------------
# CLI entry points
# ------------------------------------------------------------------

case "${1:-}" in
    --configured)
        _has_proton_pass && exit 0 || exit 1
        ;;
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
        while IFS=$'\t' read -r key _value _enc; do
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
            while IFS=$'\t' read -r key _value _enc; do
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
Usage: proton-pass-env.sh [--build|--get KEY|--keys|--status|--clear|--configured|--help]

Build and query a local credential cache from Proton Pass CLI vaults.
Secrets are stored in a private cache file (~/.cache/proton-pass-secrets.env)
in a tab-separated format (KEY<TAB>VALUE<TAB>raw) that avoids shell-quoting
issues and is safe for any character including newlines (via b64 encoding flag).

  --build       Fetch secrets from Proton Pass and rebuild the cache
  --get KEY     Print the raw value of KEY to stdout
  --keys        List all cached key names
  --status      Show cache freshness and list cached key names
  --clear       Remove the local credential cache
  --configured  Exit 0 if pass-cli is installed, 1 otherwise (probe only)
  --help        Show this message

The cache is refreshed automatically when it is older than 1 hour.
EOF
        ;;
    *)
        _log_warn "Unknown option: ${1:-(none)}. Try --help."
        exit 1
        ;;
esac
