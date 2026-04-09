#!/bin/bash
# Test Neovim startup
# Usage: test-nvim-startup.sh <deploy-dir>
# Returns: 0 if successful, 1 if errors found

set -o pipefail

DEPLOY_DIR="${1:-$(cat /tmp/dotter_deploy_dir 2>/dev/null)}"

if [ -z "$DEPLOY_DIR" ] || [ ! -d "$DEPLOY_DIR" ]; then
  echo "Error: Deploy directory not found"
  echo "Usage: test-nvim-startup.sh <deploy-dir>"
  exit 1
fi

export HOME="$DEPLOY_DIR"

# Test Neovim startup
timeout 60 nvim --headless +"qa!" 2>&1 | tee /tmp/nvim-output.txt
NVIM_EXIT=${PIPESTATUS[0]}

echo "Neovim output:"
cat /tmp/nvim-output.txt

if [ $NVIM_EXIT -ne 0 ]; then
  echo "ERROR: Neovim exited with code $NVIM_EXIT"
  exit 1
fi

# Check for errors
if grep -E "^E[0-9]+:|Error while calling lua chunk|Error loading plugin config" /tmp/nvim-output.txt > /tmp/unexpected-errors.txt 2>/dev/null; then
  if [ -s /tmp/unexpected-errors.txt ]; then
    echo "ERROR: Unexpected errors during Neovim startup:"
    cat /tmp/unexpected-errors.txt
    exit 1
  fi
fi

echo "Neovim started successfully!"
