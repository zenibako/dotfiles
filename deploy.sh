#!/bin/sh
# Deploy wrapper: ensures KCL generation runs before dotter
# Usage: ./deploy.sh [dotter-args]

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# shellcheck source=scripts/dotter/lib.sh
. scripts/dotter/lib.sh

resolve_repo_root
resolve_python
ensure_dotter_dir "$SCRIPT_DIR"

# Regenerate .dotter/global.toml (+ out/ files) from KCL BEFORE running dotter.
# dotter parses global.toml — its file mappings and settings — at config-load
# time, before any pre_deploy hook fires, so the hook alone cannot refresh the
# config the current deploy actually uses (and on a fresh clone global.toml
# does not exist yet, since it is gitignored). Regenerating here guarantees a
# fresh, present global.toml when dotter reads it.
regenerate_from_kcl "$SCRIPT_DIR"

# Tell the pre_deploy hook to skip its own regeneration — we just did it.
export DOTTER_SKIP_KCL_REGEN=1

_STEP "Running dotter deploy"
_CMD "dotter deploy $*"
exec dotter deploy "$@"
