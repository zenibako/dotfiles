#!/bin/bash
# Deploy configuration with dotter to a temp directory
# Usage: deploy-config.sh <profile> [theme]
# Output: Sets DEPLOY_DIR environment variable and prints to stdout
# Note: Caller is responsible for cleaning up DEPLOY_DIR

set -euo pipefail

PROFILE="${1:-default}"
THEME="${2:-monokai}"

# Create deployment directory
DEPLOY_DIR=$(mktemp -d)
export HOME="$DEPLOY_DIR"

echo "Deploying to: $DEPLOY_DIR" >&2

# Create local.toml
"$(dirname "$0")/create-local-toml.sh" "$PROFILE" "$THEME" .dotter/local.toml

echo "Generated local.toml:" >&2
cat .dotter/local.toml >&2

# Deploy with dotter
dotter deploy --force --verbose --noconfirm

# Verify deployment
echo "Verifying deployment..." >&2
ls -la "$DEPLOY_DIR" >&2 || true
find "$DEPLOY_DIR" -type f | head -20 >&2 || true

# Output the deploy directory for other scripts
echo "$DEPLOY_DIR"