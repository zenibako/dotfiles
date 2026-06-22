#!/bin/sh
# Deploy wrapper: ensures KCL generation runs before dotter
# Usage: ./deploy.sh [dotter-args]

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# shellcheck source=scripts/dotter/lib.sh
. scripts/dotter/lib.sh

ensure_dotter_dir "$SCRIPT_DIR"

# Run pre-deploy (KCL generation + validation)
echo "==> Running pre-deploy (KCL generation + validation)..."
bash scripts/pre_deploy.sh

# Run dotter with any passed arguments
echo "==> Running dotter deploy..."
exec dotter deploy "$@"
