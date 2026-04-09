#!/bin/bash
# Cleanup temporary files and directories
# Usage: cleanup.sh [deploy-dir]

DEPLOY_DIR="${1:-$(cat /tmp/dotter_deploy_dir 2>/dev/null)}"

if [ -n "$DEPLOY_DIR" ] && [ -d "$DEPLOY_DIR" ]; then
  rm -rf "$DEPLOY_DIR"
  echo "Cleaned up deployment directory: $DEPLOY_DIR"
fi

# Cleanup temp files
rm -f /tmp/dotter_deploy_dir /tmp/nvim-*.txt /tmp/theme-*.log /tmp/dotter-*.log /tmp/unexpected-errors.txt 2>/dev/null || true

echo "Cleanup complete"
