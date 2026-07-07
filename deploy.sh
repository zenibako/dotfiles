#!/bin/sh
# Deploy wrapper: ensures KCL generation runs before dotter
# Usage: ./deploy.sh [dotter-args]

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# shellcheck source=scripts/dotter/lib.sh
. scripts/dotter/lib.sh

ensure_dotter_dir "$SCRIPT_DIR"

# dotter's pre_deploy hook (configured in .dotter/global.toml) runs KCL
# generation and validation automatically before deploying files, so we just
# invoke dotter directly and let the hooks do the rest.
_STEP "Running dotter deploy"
_CMD "dotter deploy $*"
exec dotter deploy "$@"
