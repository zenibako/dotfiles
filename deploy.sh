#!/bin/sh
# Deploy wrapper: ensures KCL generation runs before dotter
# Usage: ./deploy.sh [dotter-args]

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Run pre-deploy (KCL generation + validation)
if [ -f ".dotter/pre_deploy.sh" ]; then
    echo "==> Running pre-deploy (KCL generation)..."
    bash .dotter/pre_deploy.sh
else
    echo "ERROR: .dotter/pre_deploy.sh not found" >&2
    exit 1
fi

# Run dotter with any passed arguments
echo "==> Running dotter deploy..."
exec dotter deploy "$@"
