#!/bin/sh
# detect_pinentry.sh — record this machine's best pinentry in local.toml.
#
# gpg-agent.conf is templated with {{gpg_pinentry_program}}. A path that does
# not exist on a given machine gets stripped by GPG Suite's fixGpgHome
# LaunchAgent at every login, leaving the live file permanently diverged from
# dotter's cache (deploys then skip it with "target contents were changed").
# Detecting a valid binary per machine at deploy time keeps every host
# convergent without hand-maintained local overrides.
#
# The managed line carries a marker comment; a gpg_pinentry_program line
# WITHOUT the marker is treated as a manual pin and never touched.
#
# Must run BEFORE dotter starts: dotter reads local.toml at config-load time,
# so a value written from inside a pre_deploy hook only lands next run.
set -eu

LOCAL_CONFIG="${DOTTER_LOCAL_CONFIG:-.dotter/local.toml}"
MARKER="# managed by detect_pinentry.sh"

[ -f "$LOCAL_CONFIG" ] || exit 0

found=""
for candidate in \
    /opt/homebrew/bin/pinentry-mac \
    /usr/local/bin/pinentry-mac \
    "/usr/local/MacGPG2/libexec/pinentry-mac.app/Contents/MacOS/pinentry-mac" \
    /usr/bin/pinentry-gnome3 \
    /usr/bin/pinentry-qt \
    /usr/bin/pinentry-gtk-2 \
    /opt/homebrew/bin/pinentry-curses \
    /usr/local/bin/pinentry-curses \
    /usr/bin/pinentry-curses \
    /opt/homebrew/bin/pinentry \
    /usr/local/bin/pinentry \
    /usr/bin/pinentry
do
    if [ -x "$candidate" ]; then
        found="$candidate"
        break
    fi
done

if [ -z "$found" ]; then
    echo "detect_pinentry: no pinentry binary found; leaving $LOCAL_CONFIG unchanged" >&2
    exit 0
fi

existing="$(grep -E '^[[:space:]]*gpg_pinentry_program[[:space:]]*=' "$LOCAL_CONFIG" || true)"

if [ -n "$existing" ]; then
    case "$existing" in
        *"$MARKER"*) ;;
        *) exit 0 ;;
    esac
    case "$existing" in
        *"\"$found\""*) exit 0 ;;
    esac
fi

if ! grep -q '^\[variables\]' "$LOCAL_CONFIG"; then
    printf '\n[variables]\ngpg_pinentry_program = "%s" %s\n' "$found" "$MARKER" >> "$LOCAL_CONFIG"
    echo "detect_pinentry: gpg_pinentry_program -> $found"
    exit 0
fi

tmp="$(mktemp)"
awk -v line="gpg_pinentry_program = \"$found\" $MARKER" '
    /^[[:space:]]*gpg_pinentry_program[[:space:]]*=/ { next }
    { print }
    /^\[variables\]/ { print line }
' "$LOCAL_CONFIG" > "$tmp"
# cat (not mv) preserves local.toml permissions — it holds secrets.
cat "$tmp" > "$LOCAL_CONFIG"
rm -f "$tmp"
echo "detect_pinentry: gpg_pinentry_program -> $found"
