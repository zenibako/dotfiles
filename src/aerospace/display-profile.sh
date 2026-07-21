#!/bin/sh
# aerospace-display-profile — apply per-monitor root layouts to AeroSpace
# workspaces.
#
# Policy (edit layout_for_monitor below to tune):
#   built-in laptop display  -> h_accordion (stacking; small screen)
#   any external monitor     -> h_tiles     (side-by-side tiling)
#
# AeroSpace has no display-connected/disconnected event, so this script is
# fired from aerospace.toml on startup, on focused-monitor change, and on
# every workspace switch. It fingerprints the connected monitor set and
# exits early when nothing changed, so manual per-workspace layout tweaks
# (alt-comma / alt-slash) survive until the monitor set actually changes.
# Pass --force to reapply unconditionally.

set -eu

# AeroSpace exec callbacks run with a minimal PATH; make sure the CLI and
# Homebrew tools resolve.
PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/aerospace"
STATE_FILE="$CACHE_DIR/display-profile.state"

layout_for_monitor() {
    case "$1" in
        *[Bb]uilt-in*) echo "h_accordion" ;;
        *) echo "h_tiles" ;;
    esac
}

monitors="$(aerospace list-monitors --format '%{monitor-id}|%{monitor-name}')"

if [ "${1:-}" != "--force" ]; then
    if [ -f "$STATE_FILE" ] && [ "$(cat "$STATE_FILE")" = "$monitors" ]; then
        exit 0
    fi
fi

printf '%s\n' "$monitors" | while IFS='|' read -r monitor_id monitor_name; do
    [ -n "$monitor_id" ] || continue
    layout="$(layout_for_monitor "$monitor_name")"
    aerospace list-workspaces --monitor "$monitor_id" | while read -r workspace; do
        [ -n "$workspace" ] || continue
        # Empty workspaces have no root container to re-layout; ignore.
        aerospace layout --workspace "$workspace" --root "$layout" 2>/dev/null || true
    done
done

mkdir -p "$CACHE_DIR"
printf '%s' "$monitors" > "$STATE_FILE"
