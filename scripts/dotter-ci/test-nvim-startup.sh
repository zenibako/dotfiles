#!/bin/bash
# Test Neovim startup and LSP subsystem
# Usage: test-nvim-startup.sh <deploy-dir>
# Returns: 0 if successful, 1 if errors found

set -o pipefail

# Shared ANSI colors + output helpers (_ERR/_WARN/_OK/_PASS/_FAIL).
# shellcheck source=../dotter/lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../dotter/lib.sh"

DEPLOY_DIR="${1:-$(cat /tmp/dotter_deploy_dir 2>/dev/null)}"

if [ -z "$DEPLOY_DIR" ] || [ ! -d "$DEPLOY_DIR" ]; then
  _ERR "Deploy directory not found"
  echo "Usage: test-nvim-startup.sh <deploy-dir>"
  exit 1
fi

export HOME="$DEPLOY_DIR"

# Test 1: Basic Neovim startup
echo "=== Test 1: Basic startup ==="
timeout 60 nvim --headless +"qa!" 2>&1 | tee /tmp/nvim-output.txt
NVIM_EXIT=${PIPESTATUS[0]}

if [ $NVIM_EXIT -ne 0 ]; then
  _ERR "Neovim exited with code $NVIM_EXIT"
  exit 1
fi

if grep -E "^E[0-9]+:|Error while calling lua chunk|Error loading plugin config" /tmp/nvim-output.txt > /tmp/unexpected-errors.txt 2>/dev/null; then
  if [ -s /tmp/unexpected-errors.txt ]; then
    _ERR "Unexpected errors during Neovim startup:"
    cat /tmp/unexpected-errors.txt
    exit 1
  fi
fi

echo "Neovim started successfully!"

# Test 2: LSP subsystem health check
echo ""
echo "=== Test 2: LSP subsystem check ==="
timeout 60 nvim --headless \
  -c "lua vim.cmd('checkhealth vim.lsp')" \
  -c "qa!" 2>&1 | tee /tmp/nvim-lsp-output.txt

LSP_EXIT=${PIPESTATUS[0]}
if [ $LSP_EXIT -ne 0 ]; then
  _ERR "LSP health check failed with exit code $LSP_EXIT"
  exit 1
fi

if grep -E "^E[0-9]+:|ERROR" /tmp/nvim-lsp-output.txt > /tmp/lsp-errors.txt 2>/dev/null; then
  if [ -s /tmp/lsp-errors.txt ]; then
    _ERR "LSP subsystem reported errors:"
    cat /tmp/lsp-errors.txt
    exit 1
  fi
fi

echo "LSP subsystem OK!"

# Test 3: nvim-lint (PMD) loads without errors
echo ""
echo "=== Test 3: nvim-lint (PMD) plugin load ==="
timeout 60 nvim --headless \
  -c "lua require('lint')" \
  -c "qa!" 2>&1 | tee /tmp/nvim-lint-output.txt

LINT_EXIT=${PIPESTATUS[0]}
if [ $LINT_EXIT -ne 0 ]; then
  _ERR "nvim-lint failed to load with exit code $LINT_EXIT"
  exit 1
fi

if grep -E "^E[0-9]+:|Error" /tmp/nvim-lint-output.txt > /tmp/lint-errors.txt 2>/dev/null; then
  if [ -s /tmp/lint-errors.txt ]; then
    _ERR "nvim-lint reported errors:"
    cat /tmp/lint-errors.txt
    exit 1
  fi
fi

echo "nvim-lint (PMD) loads successfully!"
echo ""
echo "All Neovim tests passed."
