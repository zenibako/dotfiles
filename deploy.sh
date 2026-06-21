#!/bin/sh
# Deploy wrapper: ensures KCL generation runs before dotter
# Usage: ./deploy.sh [dotter-args]

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Ensure .dotter/ output directory and symlinks exist
mkdir -p .dotter
ln -sf ../scripts/pre_deploy.sh .dotter/pre_deploy.sh
ln -sf ../scripts/post_deploy.sh .dotter/post_deploy.sh

# Run pre-deploy (KCL generation + validation)
echo "==> Running pre-deploy (KCL generation)..."
bash scripts/pre_deploy.sh

# Run dotter with any passed arguments
echo "==> Running dotter deploy..."
exec dotter deploy "$@"
