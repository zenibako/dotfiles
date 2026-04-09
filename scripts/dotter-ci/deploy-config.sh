#!/bin/bash
# Deploy configuration with dotter to a temp directory
# Usage: deploy-config.sh <profile> [theme]
# Output: Sets DEPLOY_DIR environment variable and prints to stdout

set -e

PROFILE="${1:-default}"
THEME="${2:-monokai}"

# Create deployment directory
DEPLOY_DIR=$(mktemp -d)
export HOME="$DEPLOY_DIR"

echo "Deploying to: $DEPLOY_DIR"

# Create local.toml
"$(dirname "$0")/create-local-toml.sh" "$PROFILE" "$THEME" .dotter/local.toml

echo "Generated local.toml:"
cat .dotter/local.toml

# Deploy with dotter
dotter deploy --force --verbose --noconfirm

# Verify deployment
echo "Verifying deployment..."
ls -la "$DEPLOY_DIR" || true
find "$DEPLOY_DIR" -type f | head -20 || true

# Output the deploy directory for other scripts
echo "$DEPLOY_DIR"
