#!/bin/bash
# Validate Lua files in deployed config
# Usage: validate-lua.sh [deploy-dir]
# If no deploy-dir specified, uses $HOME/.config/nvim

set -e

# Shared ANSI colors + output helpers (_ERR/_WARN/_OK/_PASS/_FAIL).
# shellcheck source=../dotter/lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../dotter/lib.sh"

DEPLOY_DIR="${1:-$HOME/.config/nvim}"

if [ ! -d "$DEPLOY_DIR" ]; then
  _WARN "No nvim config found in $DEPLOY_DIR, skipping Lua validation"
  exit 0
fi

# Check for luac
if ! command -v luac &> /dev/null; then
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "Installing lua5.4..."
    sudo apt-get update -qq && sudo apt-get install -y -qq lua5.4
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Installing lua..."
    brew install lua
  fi
fi

echo "Validating Lua files in $DEPLOY_DIR..."
FAILED=0

while IFS= read -r file; do
  if ! luac -p "$file" > /dev/null 2>&1; then
    _FAIL "Syntax error in $file"
    luac -p "$file" 2>&1 || true
    FAILED=1
  else
    _PASS "$file"
  fi
done < <(find "$DEPLOY_DIR" -name "*.lua" -type f 2>/dev/null)

if [ $FAILED -eq 1 ]; then
  _ERR "Lua validation failed"
  exit 1
fi

_PASS "All Lua files are valid!"
