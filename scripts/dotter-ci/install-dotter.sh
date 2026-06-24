#!/bin/bash
# Install dotter if not already installed
# Usage: install-dotter.sh

set -e

# Shared ANSI colors + output helpers (_ERR/_WARN/_OK/_PASS/_FAIL).
# shellcheck source=../dotter/lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../dotter/lib.sh"

if command -v dotter &> /dev/null; then
  echo "dotter already installed: $(dotter --version)"
  exit 0
fi

echo "Installing dotter..."

case "$OSTYPE" in
  linux-gnu*)
    wget -q https://github.com/SuperCuber/dotter/releases/latest/download/dotter-linux-x64-musl -O /tmp/dotter
    chmod +x /tmp/dotter
    sudo mv /tmp/dotter /usr/local/bin/
    ;;
  darwin*)
    brew install dotter
    ;;
  *)
    _ERR "Unknown platform: $OSTYPE"
    exit 1
    ;;
esac

echo "dotter installed: $(dotter --version)"
